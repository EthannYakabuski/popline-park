extends SceneTree
const Profile=preload("res://game/profile.gd")
var checks:=0
var failed:=0
var game:Node
var services:Node

func check(value:bool,detail:String)->void:
	checks+=1
	if not value:
		failed+=1
		printerr("FAIL ",detail)

func _init()->void:
	call_deferred("run_tests")

func run_tests()->void:
	var isolated:=OS.get_environment("POPLINE_TEST_ROOT").replace("\\","/")
	if isolated.is_empty() or not ProjectSettings.globalize_path("user://").begins_with(isolated):
		quit(2)
		return
	services=root.get_node("Services")
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	await process_frame
	game.start_run("campaign",0)
	game._pause()
	var paused_snapshot:Dictionary=game.run.snapshot()
	for i in range(12):
		game._ride_action(-1)
		game._ride_action(1)
		game._ride_action(0)
		game._process(0.1)
	check(game.run.snapshot()==paused_snapshot,"repeated visible controls and ticks freeze under pause")
	game._resume()
	game._ride_action(-1)
	check(game.run.lane==0,"resume accepts lane input")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.paused and not game.profile.data.active.is_empty(),"background pauses and saves")
	game._resume()
	game._back()
	check(game.paused and game.page=="ride","Back pauses ride")
	game._resume()
	for flag in ["_reward_showing","_interstitial_showing","_consent_showing"]:
		services.set(flag,true)
		var distance:float=game.run.distance
		game._process(0.5)
		game._ride_action(0)
		check(game.paused and game.run.distance==distance and game.run.jump==0,"all ad UI freezes simulation: "+flag)
		services.set(flag,false)
		game._process(0.01)
		check(game.paused,"ad closure requires explicit resume")
		game._resume()
	game._end_ride()
	await process_frame
	check(game.page=="home" and game.profile.data.active.is_empty(),"end-and-bank clears active ride")
	game.start_run("endless",0)
	check(game.run.mode=="endless","another mode reachable without intentional death")
	# A saved, late campaign ride must recover its visual district.
	game.run.route=22
	game.run.mode="campaign"
	game._store_active()
	game.park.set_district(0)
	game.show_page("home")
	game.start_run("campaign",0)
	check(game.park.district==2 and game.paused,"restoring campaign restores district and pause")
	game.run.mode="daily"
	game.run.seed_value=20002
	game._store_active()
	game.show_page("home")
	game.start_run("daily",0)
	check(game.park.district==20002%3,"restoring daily restores seeded district")
	game.run.hearts=0
	game.run.done=true
	game.run.won=false
	game._store_active()
	game.show_page("result")
	var path:String=game.profile.path
	var before:Dictionary=game.run.snapshot()
	game.profile.path="user://missing/never-created/profile.json"
	check(not game._apply_earned_continue(game.run.run_id),"earned continue fails honestly when storage fails")
	check(game.run.snapshot()==before and game.earned_retry_id==game.run.run_id,"failed continue restores full state and retains retry")
	game.profile.path=path
	check(game._apply_earned_continue(game.run.run_id),"earned entitlement can retry once storage returns")
	check(not game._apply_earned_continue(game.run.run_id),"duplicate earned callback denied")
	var cold:=Profile.new(path)
	check(bool(cold.data.active.continued) and int(cold.data.active.hearts)==2,"earned continue durable across cold load")
	game._end_ride()
	game.start_run("campaign",0)
	game.run.hearts=0
	game.run.done=true
	game.show_page("result")
	game._continue()
	await process_frame
	await process_frame
	check(not game.run.continued and not game.reward_pending and game.page=="result","unsupported desktop ads never grant a continue")
	for page in ["home","campaign","locker","daily","journal","settings"]:
		game.show_page(page)
		check(game.ui.get_child_count()>1,"implemented page loads: "+page)
	game.queue_free()
	await process_frame
	print("UI_FLOW_TESTS ",checks," checks / ",failed," failures; callback fixture is not native ad evidence")
	quit(1 if failed else 0)
