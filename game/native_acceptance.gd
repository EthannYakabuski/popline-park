extends Node
## Only attached by an explicit debug-only acceptance export feature.
## Drives genuine game actions and captures the native Godot viewport.
var game:Node
var services:Node
var caught:=false
var caught_rail:=false
var elapsed:=0.0
var ready_to_play:=false
var finished:=false
var failure_run:=false
func start(owner_game:Node)->void:
	game=owner_game
	services=get_node("/root/Services")
	if not OS.is_debug_build() or not OS.has_feature("acceptance"):
		queue_free()
		return
	DirAccess.make_dir_recursive_absolute("user://acceptance")
	game.profile=game.Profile.new("user://acceptance/profile-"+str(Time.get_ticks_msec())+".json")
	game.show_page("home")
	await get_tree().create_timer(15).timeout
	print("NATIVE_ACCEPTANCE_SERVICES ",JSON.stringify({"native_ads":services._native_ads,"ads_ready":services._ads_ready,"pgs_ready":services._pgs_ready,"reward_available":services.can_reward(),"status":services.status()}))
	await capture("01-home")
	game.start_run("campaign",0)
	ready_to_play=true

func capture(name_value:String)->void:
	await RenderingServer.frame_post_draw
	var img:=get_viewport().get_texture().get_image()
	var error:=img.save_png("user://acceptance/"+name_value+".png")
	print("NATIVE_VIEWPORT ",name_value," ",img.get_width(),"x",img.get_height()," save=",error)

func _process(delta:float)->void:
	if not ready_to_play or finished:return
	elapsed+=delta
	if elapsed>100:
		finished=true
		print("NATIVE_ACCEPTANCE_TIMEOUT ",game.page," ",services.status())
		return
	if game.page=="ride":
		if game.paused and not services.fullscreen_ad_active():game._resume()
		var ride:RefCounted=game.run
		var near:Dictionary={}
		var best:=100.0
		for e in ride.events:
			var d:float=float(e.d)-ride.distance
			if e.kind!="token" and d>0 and d<best:best=d;near=e
		if not near.is_empty():
			if best>4 and best<10:
				var target:=int(near.lane)
				if near.kind=="block" and not failure_run:target=(target+1)%3
				var direction:=signi(target-ride.lane)
				if direction!=0:game._ride_action(direction)
			if not failure_run and near.kind=="rail" and best<ride.speed*0.4 and best>ride.speed*0.3:game._ride_action(0)
		if ride.distance>25 and not caught:
			caught=true
			capture("02-ride")
		if ride.grind>0.1 and not caught_rail:
			caught_rail=true
			capture("03-grind")
	elif game.page=="result":
		finished=true
		if failure_run:
			await capture("05-failure")
			print("NATIVE_REWARDED_REQUEST ",JSON.stringify({"available":services.can_reward(),"hearts":game.run.hearts,"continued":game.run.continued,"profile_path":game.profile.path}))
			game._continue()
			return
		await capture("04-result")
		var cold=game.Profile.new(game.profile.path)
		print("NATIVE_ACCEPTANCE_RESULT ",JSON.stringify({"won":game.run.won,"score":game.run.score,"rails":game.run.rails,"coins":cold.data.coins,"saved_rounds":cold.data.totals.rounds,"fps":Engine.get_frames_per_second(),"native_ads":services._native_ads,"ads_ready":services._ads_ready,"reward_available":services.can_reward()}))
		await get_tree().create_timer(2).timeout
		failure_run=true
		elapsed=0
		game._retry()
		finished=false
