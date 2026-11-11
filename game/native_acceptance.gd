extends Node
## Debug-only acceptance driver. Unlocks are a test fixture; rides use actual inputs/rules.
const Policy=preload("res://game/acceptance_policy.gd")
var game:Node
var services:Node
var output:String
var captures:Dictionary={}
var results:Array=[]
var driving:=false
var failures:=0
var first_rail:=false
var popped_rail:=false
var checked_pause:=false
var current_route:=0
func check(ok:bool,detail:String)->void:
	print("EXPANSION_CHECK ","PASS " if ok else "FAIL ",detail)
	if not ok: failures+=1
func start(owner_game:Node)->void:
	game=owner_game
	services=get_node("/root/Services")
	output="user://expansion-acceptance" if OS.has_feature("android") else "res://build/expansion-v1.1/captures/desktop"
	DirAccess.make_dir_recursive_absolute(output)
	DirAccess.make_dir_recursive_absolute("user://expansion-acceptance")
	game.profile=game.Profile.new("user://expansion-acceptance/profile-"+str(Time.get_ticks_msec())+".json")
	var seed:Dictionary=game.Profile.defaults()
	seed.stars.resize(59);seed.stars.fill(1)
	check(game.profile.commit(seed),"disposable unlock fixture saved")
	game.show_page("home")
	await get_tree().create_timer(15 if OS.has_feature("android") else 1).timeout
	print("EXPANSION_PLATFORM ",JSON.stringify({"native_ads":services._native_ads,"ads_ready":services._ads_ready,"status":services.status(),"profile":game.profile.path,"fixture":"59 prior level unlocks; current rides and payouts are genuine"}))
	for index in [0,30,40,59]:
		current_route=index
		# Isolate each ride's service cadence; the final ride deliberately exercises transition 3.
		services._round_count=2 if index==59 else 0
		game.start_run("campaign",index)
		check(game.page=="ride" and game.run.route==index,"starts line "+str(index+1))
		await capture("line-%02d-start"%(index+1))
		driving=true
		var start_time:=Time.get_ticks_msec()
		while game.page=="ride" and Time.get_ticks_msec()-start_time<120000:
			await get_tree().process_frame
		driving=false
		check(game.page=="result" and game.run.won,"completed line "+str(index+1))
		await capture("line-%02d-result"%(index+1))
		var cold=game.Profile.new(game.profile.path)
		var result:Dictionary={"route":index+1,"won":game.run.won,"score":game.run.score,"rails":game.run.rails,"flips":game.run.flips,"pushes":game.run.push_count,"hits":game.run.hits,"saved_rounds":cold.data.totals.rounds,"saved_coins":cold.data.coins,"fps":Engine.get_frames_per_second()}
		results.append(result)
		print("EXPANSION_RIDE ",JSON.stringify(result))
		if not game.run.won:break
		await get_tree().create_timer(1).timeout
		if index!=59 and not game._can_act():
			check(false,"unexpected fullscreen transition before next test")
			break
	var summary:Dictionary={"checks_failed":failures,"rides":results,"profile":game.profile.path,"engine":Engine.get_version_info().string,"native":OS.has_feature("android"),"screenshot_provenance":"Genuine implemented viewport during automated play; unlocks are a disposable test fixture"}
	var file:=FileAccess.open(output+"/summary.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(summary,"  "));file.close()
	print("EXPANSION_RUNTIME_COMPLETE ",JSON.stringify(summary))
	if not OS.has_feature("android"):get_tree().quit(1 if failures else 0)
func capture(label:String)->void:
	if captures.has(label):return
	captures[label]=true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var frame:=get_viewport().get_texture().get_image()
	check(frame.save_png(output+"/"+label+".png")==OK,"capture "+label)
func _process(_delta:float)->void:
	if not driving or game.page!="ride" or not game._can_act():return
	if game.paused:game._resume()
	var run:RefCounted=game.run
	if current_route==0:
		if run.duration<0.04:
			for i in range(20):game._trick_action("push")
			check(run.push_count==1,"same-frame push spam grants one stroke")
		if run.push_time>0.25 and run.push_time<0.4:capture("push-forward")
		if run.duration>0.65 and run.duration<0.69:game._ride_action(0)
		if run.jump>0.2 and run.jump<0.65:game._trick_action("kickflip")
		if run.flip_time>0.12 and run.flip_time<0.26:
			capture("flat-kickflip")
			if not checked_pause:
				checked_pause=true
				game._pause()
				var before:Dictionary=run.snapshot()
				for i in range(12):
					game._trick_action("push");game._trick_action("kickflip");game._ride_action(0);game._process(0.03)
				check(run.snapshot()==before,"paused airborne repeated controls stay frozen")
				var cold=game.Profile.new(game.profile.path)
				check(cold.data.active.flip_used and is_equal_approx(float(cold.data.active.jump),run.jump),"midflip state saved during interruption")
				game._resume()
		if not first_rail:
			for e in run.events:
				if e.kind=="rail" and not e.used:
					var front:float=run.event_front(e)-run.distance
					if front>0 and front<12:
						var direction:=signi(int(e.lane)-run.lane)
						if direction!=0:game._ride_action(direction)
						if front<run.speed*0.55:game._ride_action(0)
						return
		if run.grind>0 and not popped_rail:
			first_rail=true
			capture("long-rail")
			if run.grind<0.45:
				game._ride_action(0);game._trick_action("kickflip")
				popped_rail=true
			return
		if popped_rail and run.obstacle_air and run.flip_time>0.1 and run.flip_time<0.24 and run.height>0.7:capture("rail-kickflip")
	var action:Dictionary=Policy.actions(run,true)
	if action.steer:game._ride_action(action.steer)
	if action.ollie:game._ride_action(0)
	if action.flip:game._trick_action("kickflip")
	if action.push:game._trick_action("push")
	if current_route>=30:
		if run.distance>50:capture("line-%02d-ride"%(current_route+1))
		for e in run.events:
			if e.kind=="skater" and run.event_position(e)-run.distance<16 and run.event_position(e)-run.distance>6:
				capture("line-%02d-traffic"%(current_route+1));break
