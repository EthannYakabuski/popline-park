extends SceneTree
const Run=preload("res://game/run.gd")
const Profile=preload("res://game/profile.gd")
var checks:=0
var failed:=0
func _init()->void: call_deferred("test_all")
func check(ok:bool,detail:String)->void:
	checks+=1
	if not ok:
		failed+=1
		printerr("FAIL ",detail)
func ride(kind:String="rail",rail_length:float=3.0)->RefCounted:
	var r:=Run.new()
	r.setup("campaign",0,20000,{},1)
	r.distance=10.0
	r.length=10000.0
	r.next_section=1000
	r.events=[{"d":20.0,"lane":1,"kind":kind,"used":false}]
	if kind=="rail": r.events[0].rail_length=rail_length
	if kind=="skater":r.events[0].merge({"spawn":0.0,"npc_speed":1.5,"variant":0})
	return r
func advance(r:RefCounted,seconds:float,dt:float=1.0/60.0)->void:
	for i in range(ceili(seconds/dt)): r.step(dt)
func buttons(node:Node)->Array[Button]:
	var found:Array[Button]=[]
	for child in node.get_children():
		if child is Button:found.append(child)
		found.append_array(buttons(child))
	return found
func test_all()->void:
	var isolated:=OS.get_environment("POPLINE_TEST_ROOT").replace("\\","/")
	if isolated.is_empty() or not ProjectSettings.globalize_path("user://").begins_with(isolated):quit(2);return
	for span in [3.0,6.0,9.0,12.0]:
		for dt in [1.0/30.0,1.0/60.0,1.0/120.0]:
			var r:=ride("rail",span)
			r.distance=20-span/2-0.3
			r.ollie()
			r.step(dt)
			r.step(dt)
			check(r.rails==1 and r.grind>0 and r.hits==0,"leading-edge catch span/dt %s/%s"%[span,dt])
			var end:float=20+span/2
			while r.distance<end-0.3: r.step(dt)
			check(r.grind>0,"grind covers visible length %s"%span)
			while r.distance<end+0.2: r.step(dt)
			check(r.grind==0 and r.rails==1,"trailing-edge exit once %s"%span)
		var late:=ride("rail",span)
		late.distance=20+span/2-0.2
		late.ollie()
		late.step(0.02)
		check(late.rails==1 and late.hits==0,"late side-entry catches rail")
		var hit:=ride("rail",span)
		hit.distance=20-span/2-0.3
		hit.step(0.08)
		check(hit.hearts==2 and hit.hits==1 and hit.rails==0,"grounded front rail is a hit")
		advance(hit,2)
		check(hit.hits==1,"one rail cannot repeatedly damage")
	var grace:=ride()
	grace.distance=18.2
	grace.jump=0.01
	grace.step(0.02)
	check(grace.rails==1,"recent landing grace catches rail")
	var off:=ride("rail",12)
	off.distance=13.8
	off.ollie();off.step(0.02)
	check(off.grind>0 and off.ollie(),"ollie exits active long rail")
	check(off.kickflip() and not off.kickflip(),"one kickflip per rail ollie")
	var rail_score:int=off.score
	advance(off,1.1)
	check(off.grind==0 and off.rails==1 and off.flips==1,"exit cannot recapture rail or duplicate its award")
	check(off.score>=rail_score+150,"landed obstacle flip bonus")
	var side:=ride("rail",12)
	side.distance=13.8;side.ollie();side.step(0.02)
	var departure:float=side.height
	side.steer(-1);side.step(0.02)
	check(side.height<departure and side.height>departure-0.15,"sideways rail exit descends continuously")
	check(not side.obstacle_air and not side.kickflip() and not side.ollie(),"stepping off is not an intentional obstacle ollie")
	var tricks_before:int=side.tricks
	advance(side,0.3)
	check(side.height==0 and side.tricks==tricks_before,"side exit falls without a free trick award")
	var flat:=ride("token")
	flat.events=[]
	check(not flat.kickflip(),"ground kickflip denied")
	flat.ollie()
	check(flat.kickflip(),"active ollie accepts kickflip")
	check(flat.score==0,"flip score is not granted before landing")
	advance(flat,1)
	check(flat.flips==1 and flat.score==90,"flat flip pays once on landing")
	flat.ollie();flat.kickflip();flat._hit();advance(flat,1)
	check(flat.flips==1,"collision cancels pending flip bonus")
	for kind in ["block","ramp"]:
		var bump:=ride(kind)
		bump.distance=18.0
		bump.ollie()
		advance(bump,0.4)
		check(bump.score>=60 and bump.hits==0 and bump.notices.has("clear"),"ollie bonus over actual "+kind+" model")
	var ramp_landing:=ride("ramp")
	ramp_landing.events=[];ramp_landing.ollie();ramp_landing.kickflip();advance(ramp_landing,0.76)
	ramp_landing.events=[{"d":ramp_landing.distance+0.02,"lane":1,"kind":"ramp","used":false}]
	ramp_landing.step(0.02)
	check(ramp_landing.flips==1 and ramp_landing.obstacle_air and ramp_landing.jump>0.7,"low flip landing on ramp settles bonus before fresh launch")
	var p:=ride("token")
	p.events=[]
	var base:float=p.speed
	check(p.push() and p.speed>base,"push accelerates")
	for i in range(30):p.push()
	check(p.push_count==1,"same-frame push spam bounded")
	advance(p,0.23)
	var before:float=p.speed
	check(p.push() and p.speed>before,"separated repeated pushes build speed")
	for i in range(30):advance(p,0.23);p.push()
	check(p.boost<=Run.MAX_BOOST and p.speed<=base+Run.MAX_BOOST,"boost has hard cap")
	before=p.speed
	advance(p,1)
	check(p.speed<before and p.push_time==0,"coasting slows and ends push pose")
	before=p.speed;p._hit()
	check(p.speed<before,"hit removes momentum")
	advance(p,15)
	check(is_equal_approx(p.speed,base),"coasting returns to cruise")
	before=p.speed;p.invincible=0;p._hit()
	check(p.speed<before and p.impact_slow>0,"zero-boost collision slows below cruise")
	advance(p,4)
	check(is_equal_approx(p.speed,base),"collision slowdown recovers gradually")
	p.ollie()
	check(not p.push(),"no pushing in air")
	var crowd:=ride("skater")
	crowd.distance=19.9;crowd.step(0.04)
	check(crowd.hearts==2 and crowd.hits==1,"slower skater collision loses one heart")
	for route in [0,1,2,4,5,15,35,59]:
		var r:=Run.new();r.setup("campaign",route,20000,{},1)
		var count:=0
		for event in r.events:
			if event.kind=="skater":count+=1
		check(count==0 if route<2 else (count==1 if route<5 else count>0),"traffic ramp route "+str(route+1))
		for event in r.events:
			if event.kind=="rail":check(event.rail_length>=3 and event.rail_length<=12,"generated rail bounds")
	# Fixtures are emitted by the exact committed 1.0.0 model, not real player saves.
	for state in ["rail","air"]:
		var old:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v1-active-"+state+".json"))
		var restored:=Run.new()
		check(not old.has("physics_version") and restored.restore(old),"actual v1 active "+state+" loads")
		check(restored.route==29 and restored.score==850,"v1 active progress preserved")
		if state=="rail":check(restored.grind_end>restored.distance,"legacy grind migrates to distance endpoint")
		advance(restored,0.1)
		check(Run.valid_snapshot(restored.snapshot()),"migrated active snapshot valid")
		var profile:=Profile.new("user://legacy-"+state+".json")
		var seed:=Profile.defaults();seed.stars.resize(30);seed.stars.fill(3)
		seed.xp=1234;seed.coins=678;seed.next_run=82;seed.last_paid_run=80;seed.active=old
		check(profile.commit(seed),"30-level legacy profile accepted")
		var cold:=Profile.new(profile.path)
		check(cold.unlocked_route()==30 and cold.data.coins==678 and cold.data.xp==1234,"legacy progress opens line31 without reset")
	var profile:=Profile.new("user://sixty.json")
	var all:=Profile.defaults();all.stars.resize(60);all.stars.fill(3)
	check(profile.commit(all) and profile.unlocked_route()==59,"60 completed lines persist")
	var loaded:=Profile.new(profile.path)
	check(loaded.data.stars.size()==60,"cold load keeps all60 stars")
	var air:=ride();air.events=[];air.push();air.ollie();air.kickflip();air.step(0.12)
	var copy:=Run.new()
	check(copy.restore(air.snapshot()),"midflip/push snapshot restores")
	advance(air,1);advance(copy,1)
	check(copy.snapshot()==air.snapshot(),"midair reload preserves exact continuation and single award")
	for key in ["rail_length","npc_speed","spawn","variant"]:
		var corrupt:Dictionary=ride("skater").snapshot()
		corrupt.events[0][key]="bad"
		check(not Run.valid_snapshot(corrupt),"malformed event extension rejected "+key)
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game);game.set_process(false);await process_frame
	game.start_run("campaign",0)
	var control_map:Dictionary={}
	for b in buttons(game.ui):control_map[b.text]=b
	check(control_map.has_all(["OLLIE","KICKFLIP","PUSH"]),"all three real controls visible")
	check(control_map.OLLIE.position.x<control_map.KICKFLIP.position.x and control_map.KICKFLIP.position.x<control_map.PUSH.position.x,"requested left/middle/right order")
	control_map.PUSH.emit_signal("pressed")
	check(game.run.push_count==1,"real push button callback works")
	game.park.animate_view(game.run,0.02,true)
	check(game.park.last_anim=="skate" and is_equal_approx(game.park.rider.rotation.y,PI),"push uses forward-facing supplied push animation")
	game.run.step(0.2);game.run.step(0.2);game.run.step(0.2);game.run.step(0.02)
	game.park.animate_view(game.run,0.02,true)
	check(game.park.last_anim=="skate-stand" and is_equal_approx(game.park.rider.rotation.y,PI/2),"coast returns to sideways standing pose")
	control_map.OLLIE.emit_signal("pressed");control_map.KICKFLIP.emit_signal("pressed")
	check(game.run.flip_used,"real ollie then kickflip button callbacks")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var frozen:Dictionary=game.run.snapshot()
	for i in range(25):
		game._trick_action("push");game._trick_action("kickflip");game._ride_action(0);game._process(0.05)
	check(game.run.snapshot()==frozen,"interrupted midflip rejects repeated all-three input")
	game._resume();game._process(0.05)
	check(game.run.jump<frozen.jump,"explicit resume continues airborne motion")
	game.run.jump=0;game.run.grind=0;game.run.push_cooldown=0
	var push_key:=InputEventKey.new();push_key.keycode=KEY_P;push_key.pressed=true
	var count:int=game.run.push_count
	push_key.echo=true;game._unhandled_input(push_key)
	check(game.run.push_count==count,"held keyboard auto-repeat cannot spam push")
	push_key.echo=false;game._unhandled_input(push_key)
	check(game.run.push_count==count+1,"keyboard push mapping works")
	var touch:=InputEventScreenTouch.new();touch.index=0;touch.pressed=true;touch.position=Vector2(200,400)
	game._unhandled_input(touch)
	var other:=InputEventScreenTouch.new();other.index=1;other.pressed=true;other.position=Vector2(400,400)
	game._unhandled_input(other);other.pressed=false;game._unhandled_input(other)
	check(game.pointer_down and game.touch_index==0 and game.run.jump==0,"second touch cannot release first gesture")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game._unhandled_input(push_key)
	check(not game.pointer_down and game.touch_index==-1,"focus loss clears outstanding gesture")
	game._resume();touch.pressed=false;game._unhandled_input(touch)
	check(game.run.jump==0,"stale release after interruption cannot ollie")
	game.show_page("campaign")
	var level_count:=0
	for b in buttons(game.ui):
		if b.text=="Locked" or b.text.is_valid_int():level_count+=1
	check(level_count==60,"campaign exposes 60 level buttons")
	for district in range(6):game.park.set_district(district);check(game.park.district==district,"neighborhood selects "+Run.DISTRICTS[district])
	game.queue_free();await process_frame
	print("EXPANSION_TESTS ",checks," checks / ",failed," failures")
	quit(1 if failed else 0)
