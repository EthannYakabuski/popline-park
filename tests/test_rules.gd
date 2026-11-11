extends SceneTree
const Run = preload("res://game/run.gd")
const Profile = preload("res://game/profile.gd")
var checks:=0
var failed:=0

func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition:
		failed+=1
		printerr("FAIL ",message)

func _init() -> void:
	call_deferred("test_all")

func test_all() -> void:
	var file_root: String=OS.get_environment("POPLINE_TEST_ROOT")
	if file_root.is_empty() or not ProjectSettings.globalize_path("user://").begins_with(file_root.replace("\\","/")):
		printerr("TEST REQUIRES ISOLATED POPLINE_TEST_ROOT and process APPDATA/XDG_DATA_HOME")
		quit(2)
		return
	var p:=Profile.new("user://acceptance.json")
	check(Profile.valid(p.data),"default profile valid")
	var original: Dictionary=p.data.duplicate(true)
	check(p.login(20000)==50,"first gift")
	check(p.login(20000)==0,"duplicate gift denied")
	check(p.login(19999)==0,"clock rollback denied")
	check(p.login(20001)==65,"consecutive gift increases")
	for d in range(20002,20007):p.login(d)
	check(int(p.data.streak)==7,"seven day streak")
	check(p.login(20007)==50,"streak wraps")
	var loaded:=Profile.new("user://acceptance.json")
	check(loaded.data==JSON.parse_string(JSON.stringify(p.data)),"cold save roundtrip")
	var bad:=FileAccess.open("user://acceptance.json",FileAccess.WRITE)
	bad.store_string("{broken")
	bad.close()
	var recovered:=Profile.new("user://acceptance.json")
	check(not recovered.recovery.is_empty() and int(recovered.data.login_day)==20006,"valid backup recovered")
	check(recovered.login(20008)>0,"recovered profile remains writable")
	var invalid: Dictionary=original.duplicate(true)
	invalid.gear.pop="nonsense"
	check(not Profile.valid(invalid),"malformed nested field rejected")
	for bad_version in [{},[],"1",true,null]:
		var bad_schema:Dictionary=original.duplicate(true)
		bad_schema.version=bad_version
		check(not Profile.valid(bad_schema),"wrong schema type rejected without cast")
	for group in ["totals","records","quest"]:
		for key in original[group]:
			var fractional:Dictionary=original.duplicate(true)
			fractional[group][key]=0.5
			check(not Profile.valid(fractional),"fractional metric rejected "+group+"/"+key)
	for key in ["xp","coins","sequence","streak","next_run","last_paid_run"]:
		var corruption: Dictionary=original.duplicate(true)
		corruption[key]=-1
		check(not Profile.valid(corruption),"negative counter rejected "+key)
		corruption[key]=0.5
		check(not Profile.valid(corruption),"fractional counter rejected "+key)
	var failure:=Profile.new("user://missing/directory/profile.json")
	check(failure.login(20000)==0 and int(failure.data.coins)==0,"failed save gives no entitlement")
	var run:=Run.new()
	run.setup("campaign",0,20000,{},p.new_run())
	run.hearts=0
	run.done=true
	check(not run.revive(false),"unearned continue denied")
	check(run.revive(true),"earned continue applied")
	run.done=true
	check(not run.revive(true),"duplicate continue denied")
	var snapshot: Dictionary=run.snapshot()
	var bad_distance:Dictionary=snapshot.duplicate(true)
	bad_distance.distance=1e8
	check(not Run.valid_snapshot(bad_distance),"corrupt generator catch-up distance rejected")
	var resumed:=Run.new()
	check(resumed.restore(snapshot) and resumed.continued,"continue remains consumed across reload")
	for key in snapshot:
		var corrupt_run: Dictionary=snapshot.duplicate(true)
		corrupt_run[key]="corrupt"
		check(not Run.valid_snapshot(corrupt_run),"snapshot field rejects wrong type "+key)
	var corrupt_event: Dictionary=snapshot.duplicate(true)
	corrupt_event.events=[{"d":3,"kind":"block","lane":18,"used":false}]
	check(not Run.valid_snapshot(corrupt_event),"invalid event lane rejected")
	run.done=true
	run.won=true
	run.score=1500
	run.tokens=30
	run.tricks=15
	run.rails=2
	var result: Dictionary=p.settle(run,20008)
	check(not result.is_empty(),"round payout")
	var before: Dictionary=p.data.duplicate(true)
	check(p.settle(run,20008).is_empty() and before==p.data,"payout idempotency")
	check(p.claim_quest("tokens",20008),"goal reward")
	check(not p.claim_quest("tokens",20008),"goal claim idempotency")
	check(p.upgrade("pop"),"gear purchase")
	check(int(p.data.gear.pop)==1,"gear level persists")
	var same_day:=Run.new()
	same_day.setup("daily",0,20008,{},p.new_run())
	same_day.done=true
	same_day.won=true
	var daily_first: Dictionary=p.settle(same_day,20008)
	same_day.run_id=p.new_run()
	var daily_second: Dictionary=p.settle(same_day,20008)
	check(int(daily_first.coins)==int(daily_second.coins)+80,"daily completion bonus once")
	check(int(p.data.totals.daily)==1,"daily unique day total")
	# A baseline policy can finish all 60 routes with stock gear and no ads.
	# It moves toward an approaching feature early, then hops using the real input methods.
	for route in range(Run.ROUTE_COUNT):
		var ride:=Run.new()
		ride.setup("campaign",route,20008,{},route+100)
		for frame in range(7000):
			var action:Dictionary=preload("res://game/acceptance_policy.gd").actions(ride)
			if action.steer:ride.steer(action.steer)
			if action.ollie:ride.ollie()
			ride.step(1.0/60.0)
			if ride.done:break
		check(ride.won,"route %d beatable with stock gear"%(route+1))
		check(ride.score>0 and ride.tricks>0,"route scoring %d"%(route+1))
	var a:=Run.new()
	var b:=Run.new()
	a.setup("daily",0,20008,{},1)
	b.setup("daily",0,20008,{},2)
	check(a.events==b.events,"daily deterministic")
	b.setup("daily",0,20009,{},3)
	check(a.events!=b.events,"daily changes by date")
	a.setup("endless",0,20008,{},4)
	check(a.speed<=7.5,"endless gentle opening")
	var services:=root.get_node("Services")
	check(not services.can_reward(),"desktop Web native reward unavailable")
	var callbacks: Array=[]
	services.reward_requested("test",func(earned: bool) -> void: callbacks.append(earned))
	await process_frame
	check(callbacks==[false],"unsupported service never grants reward")
	check(services._ad_id("banner")=="ca-app-pub-3940256099942544/6300978111","sample ad routing")
	check(not services.settings.play_games.enabled,"blank PGS disabled")
	print("POPLINE_RULES ",checks," checks; ",failed," failures")
	quit(0 if failed==0 else 1)
