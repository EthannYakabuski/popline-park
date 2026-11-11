extends RefCounted
## Shared deterministic simulation. Snapshot v2 remains compatible with v1 active rides.
const LANES := [-2.35, 0.0, 2.35]
const ROUTE_COUNT := 60
const DISTRICTS := ["Palm Promenade", "Brickyard Groove", "Blue Hour Pier", "Sunset Courts", "Pinecrest Commons", "Harbor Lights"]
const MIN_RAIL := 3.0
const MAX_RAIL := 12.0
const MAX_BOOST := 6.0
const PUSH_TIME := 0.6
var mode := "campaign"
var route := 0
var seed_value := 1
var distance := 0.0
var duration := 0.0
var length := 180.0
var speed := 6.8
var lane := 1
var x := 0.0
var jump := 0.0
var jump_length := 0.82
var height := 0.0
var grind := 0.0
var invincible := 0.0
var hearts := 3
var score := 0
var combo := 0
var best_combo := 0
var tokens := 0
var tricks := 0
var rails := 0
var hits := 0
var done := false
var won := false
var continued := false
var pop_level := 0
var grip_level := 0
var events: Array = []
var next_section := 0
var notices: Array[String] = []
var run_id := 0
var physics_version := 2
var boost := 0.0
var impact_slow := 0.0
var drop_time := 0.0
var drop_height := 0.0
var push_time := 0.0
var push_cooldown := 0.0
var push_count := 0
var grind_end := 0.0
var grind_lane := 1
var rail_grace := 0.0
var jump_start_height := 0.0
var obstacle_air := false
var flip_used := false
var flip_time := 0.0
var flips := 0
var flip_duration := 0.38

func setup(kind: String, index: int, day: int, gear: Dictionary, id: int) -> void:
	# Reusing a model must never retain events, entitlements or motion from its old ride.
	var fresh := get_script().new() as RefCounted
	for key in fresh.snapshot(): set(key, fresh.get(key))
	notices.clear()
	mode = kind
	route = clampi(index, 0, ROUTE_COUNT - 1)
	seed_value = day if kind == "daily" else route * 71 + 17
	run_id = id
	pop_level = int(gear.get("pop", 0))
	grip_level = int(gear.get("grip", 0))
	jump_length = 0.82 + pop_level * 0.025
	speed = cruise_speed()
	length = 150.0 + route * 6.0 if kind == "campaign" else 290.0
	if kind == "endless": length = 100000000.0
	for section in range(16): _append_section(section)
	next_section = 16

func cruise_speed() -> float:
	if mode == "endless": return minf(11.8, 7.0 + maxf(0.0, duration - 25.0) * 0.018)
	return minf(10.8, 6.8 + route * 0.085) if mode == "campaign" else 7.5

func _append_section(section: int) -> void:
	var d := 18.0 + section * 12.0
	var r := RandomNumberGenerator.new()
	r.seed = seed_value + section * 199
	var target := r.randi_range(0, 2)
	# Original 30 seeds, feature kinds and centers remain unchanged.
	var kind := "rail" if section % 3 == 2 else "block"
	if section % 5 == 4: kind = "ramp"
	if route == 0 and mode == "campaign" and section < 2: kind = "token"
	var feature := {"d": d, "lane": target, "kind": kind, "used": false}
	if kind == "rail": feature.rail_length = float(r.randi_range(1, 4)) * MIN_RAIL
	events.append(feature)
	var safe := (target + 1 + section % 2) % 3
	for offset in [-4.0, 0.0, 4.0]:
		events.append({"d": d + offset, "lane": safe, "kind": "token", "used": false})
	if (route > 9 or (mode == "endless" and d > 450)) and section % 4 == 1:
		events.append({"d": d + 5.5, "lane": (target + 2) % 3, "kind": "block", "used": false})
	var traffic := false
	if mode == "campaign":
		if route in range(2,5): traffic = section == 7
		elif route >= 5: traffic = section % (10 if route < 10 else (6 if route < 30 else 4)) == 3
	else: traffic = section % 7 == 3
	if traffic:
		events.append({"d":d+6.0,"lane":safe,"kind":"skater","used":false,"spawn":duration,"npc_speed":1.2+float(route%3)*0.25,"variant":section%2})

func event_position(event: Dictionary) -> float:
	return float(event.d) + (maxf(0.0,duration-float(event.spawn))*float(event.npc_speed) if event.kind=="skater" else 0.0)

func event_front(event: Dictionary) -> float:
	return event_position(event) - (float(event.get("rail_length",MIN_RAIL))*0.5 if event.kind=="rail" else 0.0)

func steer(direction: int) -> void:
	if done: return
	var target := clampi(lane + direction, 0, 2)
	if grind > 0.0 and target != lane:
		grind = 0.0
		drop_height = height
		drop_time = 0.18
		jump = 0.0
		obstacle_air = false
		rail_grace = 0.0
		flip_used = false
		flip_time = 0.0
	lane = target

func ollie() -> bool:
	if done or jump > 0.0 or drop_time > 0.0: return false
	obstacle_air = grind > 0.0
	jump_start_height = height if obstacle_air else 0.0
	grind = 0.0
	jump = jump_length
	flip_used = false
	flip_time = 0.0
	push_time = 0.0
	notices.append("pop")
	return true

func kickflip() -> bool:
	if done or jump <= 0.08 or flip_used: return false
	flip_used = true
	flip_duration = minf(0.38,jump)
	flip_time = flip_duration
	notices.append("flip")
	return true

func push() -> bool:
	if done or jump > 0.0 or grind > 0.0 or drop_time > 0.0 or push_cooldown > 0.0: return false
	boost = minf(MAX_BOOST, boost + 1.3)
	speed = maxf(3.2,cruise_speed()+boost-impact_slow)
	push_time = PUSH_TIME
	push_cooldown = 0.22
	push_count += 1
	notices.append("push")
	return true

func step(delta: float) -> void:
	if done: return
	var left := clampf(delta, 0.0, 0.2)
	while left > 0.0 and not done:
		var dt := minf(left, 0.02)
		_tick(dt)
		left -= dt

func _land() -> void:
	tricks += 1
	combo += 1
	best_combo = maxi(best_combo, combo)
	score += 15 * mini(6, 1 + combo / 3)
	if flip_used:
		flips += 1
		score += (150 if obstacle_air else 75) * mini(6, 1 + combo / 3)
		notices.append("obstacle_flip" if obstacle_air else "flat_flip")
	flip_used = false
	flip_time = 0.0
	obstacle_air = false
	notices.append("land")

func _hit() -> void:
	if invincible > 0.0: return
	hearts -= 1
	hits += 1
	combo = 0
	invincible = 1.3
	boost = maxf(0.0,boost-4.0)
	impact_slow = minf(3.0,impact_slow+1.8)
	speed = maxf(3.2,cruise_speed()+boost-impact_slow)
	push_time = 0.0
	flip_used = false
	flip_time = 0.0
	notices.append("hit")
	if hearts <= 0: done = true

func _catch_rail(event: Dictionary, end: float) -> void:
	event.used = true
	if flip_used: _land()
	rails += 1
	tricks += 1
	combo += 2
	best_combo = maxi(best_combo, combo)
	score += 90 * mini(6, 1 + combo / 3)
	grind_end = end
	grind_lane = int(event.lane)
	lane = grind_lane
	x = float(LANES[lane])
	grind = maxf(0.001,(end-distance)/speed)
	jump = 0.0
	height = 0.65
	push_time = 0.0
	rail_grace = 0.0
	flip_used = false
	notices.append("rail")

func _tick(dt: float) -> void:
	duration += dt
	boost = maxf(0.0,boost-dt*0.65)
	impact_slow = maxf(0.0,impact_slow-dt*0.75)
	speed = maxf(3.2,cruise_speed()+boost-impact_slow)
	distance += speed * dt
	x = move_toward(x, float(LANES[lane]), dt * (12.0 + grip_level * 1.2))
	invincible = maxf(0.0, invincible - dt)
	push_time = maxf(0.0,push_time-dt)
	push_cooldown = maxf(0.0,push_cooldown-dt)
	flip_time = maxf(0.0,flip_time-dt)
	rail_grace = maxf(0.0,rail_grace-dt)
	if grind > 0.0:
		grind = maxf(0.0,(grind_end-distance)/speed)
		height = 0.65 if grind > 0.0 else 0.0
	elif drop_time > 0.0:
		drop_time = maxf(0.0,drop_time-dt)
		height = drop_height*drop_time/0.18
	elif jump > 0.0:
		jump = maxf(0.0, jump - dt)
		var progress := 1.0-jump/jump_length
		height = sin(progress*PI)*1.65+jump_start_height*(1.0-progress)
		if jump == 0.0:
			height = 0.0
			rail_grace = 0.18
			_land()
	else: height = 0.0
	while distance + 130.0 > 18.0 + next_section * 12.0:
		_append_section(next_section)
		next_section += 1
	for event in events:
		if bool(event.used): continue
		var center := event_position(event)
		if event.kind=="rail":
			var front := center-float(event.get("rail_length",MIN_RAIL))*0.5
			var end := center+float(event.get("rail_length",MIN_RAIL))*0.5
			if distance > end+0.25:
				event.used = true
				continue
			if distance < front-0.25 or absf(x-float(LANES[int(event.lane)]))>0.95: continue
			if grind > 0.0: continue
			if jump > 0.0 or rail_grace > 0.0:
				_catch_rail(event,end)
			else:
				event.used = true
				_hit()
			if done: break
			continue
		if distance < center: continue
		event.used = true
		if absf(x - float(LANES[int(event.lane)])) > 0.85: continue
		match str(event.kind):
			"token":
				tokens += 1
				score += 10
				notices.append("token")
			"block":
				if height > 0.55:
					score += 60 * mini(6, 1 + combo / 3)
					notices.append("clear")
				else: _hit()
			"ramp":
				if jump > 0.0 and height > 0.4:
					score += 60 * mini(6, 1 + combo / 3)
					notices.append("clear")
				else:
					# A low landing onto the ramp settles its pending flip before launch.
					if flip_used: _land()
					jump = jump_length
					jump_start_height = 0.35
					obstacle_air = true
					flip_used = false
					push_time = 0.0
					score += 40
					notices.append("ramp")
			"skater": _hit()
		if done: break
	if distance >= length and hearts > 0:
		done = true
		won = true
	if events.size() > 150:
		events = events.filter(func(e: Dictionary) -> bool: return event_position(e) > distance - 20.0)

func revive(earned: bool) -> bool:
	if not earned or not done or won or continued: return false
	continued = true
	done = false
	hearts = 2
	invincible = 3.0
	return true

func stars() -> int:
	if not won: return 0
	return 1 + int(score >= 350 + route * 20) + int(hits == 0)

func snapshot() -> Dictionary:
	var data := {}
	for key in ["mode","route","seed_value","distance","duration","length","speed","lane","x","jump","jump_length","height","grind","invincible","hearts","score","combo","best_combo","tokens","tricks","rails","hits","done","won","continued","pop_level","grip_level","events","next_section","run_id","physics_version","boost","impact_slow","drop_time","drop_height","push_time","push_cooldown","push_count","grind_end","grind_lane","rail_grace","jump_start_height","obstacle_air","flip_used","flip_time","flips","flip_duration"]:
		data[key] = get(key)
	return data.duplicate(true)

func restore(data: Dictionary) -> bool:
	if not valid_snapshot(data): return false
	var fresh := get_script().new() as RefCounted
	for key in snapshot(): set(key, data.get(key,fresh.get(key)))
	if not data.has("physics_version"):
		grind_end = distance+grind*speed
		grind_lane = lane
		boost = clampf(speed-cruise_speed(),0.0,MAX_BOOST)
	physics_version = 2
	events = events.duplicate(true)
	notices.clear()
	return true

static func number_in(value: Variant,low: float,high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=low and float(value)<=high

static func valid_snapshot(data: Dictionary) -> bool:
	if not data.get("mode") is String or data.mode not in ["campaign","daily","endless"]: return false
	for key in ["done","won","continued"]:
		if not data.get(key) is bool: return false
	var limits: Dictionary={"route":[0,59],"seed_value":[0,1e9],"distance":[0,1e8],"duration":[0,1e8],"length":[1,1e8],"speed":[0.1,30],"lane":[0,2],"x":[-3,3],"jump":[0,2],"jump_length":[0.1,2],"height":[0,3],"grind":[0,4],"invincible":[0,5],"hearts":[0,3],"score":[0,1e12],"combo":[0,1e9],"best_combo":[0,1e9],"tokens":[0,1e9],"tricks":[0,1e9],"rails":[0,1e9],"hits":[0,1e9],"pop_level":[0,4],"grip_level":[0,4],"next_section":[0,1e8],"run_id":[1,1e12]}
	var integers := ["route","seed_value","lane","hearts","run_id","next_section","pop_level","grip_level","score","combo","best_combo","tokens","tricks","rails","hits"]
	if data.has("physics_version"):
		limits.merge({"physics_version":[2,2],"boost":[0,MAX_BOOST],"impact_slow":[0,3],"drop_time":[0,0.18],"drop_height":[0,1],"push_time":[0,PUSH_TIME],"push_cooldown":[0,0.22],"push_count":[0,1e9],"grind_end":[0,1e8],"grind_lane":[0,2],"rail_grace":[0,0.18],"jump_start_height":[0,1],"flip_time":[0,0.38],"flips":[0,1e9],"flip_duration":[0.08,0.38]})
		integers.append_array(["physics_version","push_count","grind_lane","flips"])
		for key in ["obstacle_air","flip_used"]:
			if not data.get(key) is bool: return false
	for key in limits:
		if not number_in(data.get(key),limits[key][0],limits[key][1]): return false
	for key in integers:
		if float(data[key])!=floor(float(data[key])): return false
	if float(data.distance)>18.0+float(data.next_section)*12.0: return false
	if not data.get("events") is Array or data.events.size()>256: return false
	for event in data.events:
		if not event is Dictionary: return false
		if not number_in(event.get("d"),0,1e8) or not number_in(event.get("lane"),0,2): return false
		if float(event.lane)!=floor(float(event.lane)): return false
		if not event.get("kind") is String or event.kind not in ["token","block","rail","ramp","skater"]: return false
		if not event.get("used") is bool: return false
		if event.has("rail_length") and not number_in(event.rail_length,MIN_RAIL,MAX_RAIL): return false
		if event.kind=="skater":
			if not number_in(event.get("spawn"),0,1e8) or not number_in(event.get("npc_speed"),1,2): return false
			if not number_in(event.get("variant"),0,1) or float(event.variant)!=floor(float(event.variant)): return false
	return true
