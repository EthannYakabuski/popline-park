extends RefCounted
## Deterministic game rules shared by the viewport, saves and acceptance fixtures.
const LANES := [-2.35, 0.0, 2.35]
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

func setup(kind: String, index: int, day: int, gear: Dictionary, id: int) -> void:
	mode = kind
	route = clampi(index, 0, 29)
	seed_value = day if kind == "daily" else route * 71 + 17
	run_id = id
	pop_level = int(gear.get("pop", 0))
	grip_level = int(gear.get("grip", 0))
	jump_length = 0.82 + pop_level * 0.025
	speed = 6.8 + route * 0.085 if kind == "campaign" else 7.5
	length = 150.0 + route * 6.0 if kind == "campaign" else 290.0
	if kind == "endless": length = 100000000.0
	for section in range(16): _append_section(section)
	next_section = 16

func _append_section(section: int) -> void:
	var d := 18.0 + section * 12.0
	var r := RandomNumberGenerator.new()
	r.seed = seed_value + section * 199
	var target := r.randi_range(0, 2)
	# The first line introduces tokens, then hops and rails. Every section has a safe lane.
	var kind := "rail" if section % 3 == 2 else "block"
	if section % 5 == 4: kind = "ramp"
	if route == 0 and mode == "campaign" and section < 2: kind = "token"
	events.append({"d": d, "lane": target, "kind": kind, "used": false})
	var safe := (target + 1 + section % 2) % 3
	for offset in [-4.0, 0.0, 4.0]:
		events.append({"d": d + offset, "lane": safe, "kind": "token", "used": false})
	if (route > 9 or (mode == "endless" and d > 450)) and section % 4 == 1:
		events.append({"d": d + 5.5, "lane": (target + 2) % 3, "kind": "block", "used": false})

func steer(direction: int) -> void:
	if not done: lane = clampi(lane + direction, 0, 2)

func ollie() -> bool:
	if done or jump > 0.0 or grind > 0.0: return false
	jump = jump_length
	notices.append("pop")
	return true

func step(delta: float) -> void:
	if done: return
	var left := clampf(delta, 0.0, 0.2)
	while left > 0.0 and not done:
		var dt := minf(left, 0.02)
		_tick(dt)
		left -= dt

func _tick(dt: float) -> void:
	duration += dt
	if mode == "endless": speed = minf(11.8, 7.0 + maxf(0.0, duration - 25.0) * 0.018)
	distance += speed * dt
	x = move_toward(x, float(LANES[lane]), dt * (12.0 + grip_level * 1.2))
	invincible = maxf(0.0, invincible - dt)
	if grind > 0.0:
		grind = maxf(0.0, grind - dt)
		height = 0.65
		if grind == 0.0: height = 0.0
	elif jump > 0.0:
		jump = maxf(0.0, jump - dt)
		height = sin((1.0 - jump / jump_length) * PI) * 1.65
		if jump == 0.0:
			tricks += 1
			combo += 1
			best_combo = maxi(best_combo, combo)
			score += 15 * mini(6, 1 + combo / 3)
			notices.append("land")
	else: height = 0.0
	while distance + 130.0 > 18.0 + next_section * 12.0:
		_append_section(next_section)
		next_section += 1
	for event in events:
		if bool(event.used) or distance < float(event.d): continue
		event.used = true
		if absf(x - float(LANES[int(event.lane)])) > 0.85: continue
		match str(event.kind):
			"token":
				tokens += 1
				score += 10
				notices.append("token")
			"block":
				if height > 0.55:
					score += 30 * mini(6, 1 + combo / 3)
					notices.append("clear")
				elif invincible <= 0.0:
					hearts -= 1
					hits += 1
					combo = 0
					invincible = 1.3
					notices.append("hit")
					if hearts <= 0: done = true
			"rail":
				if height > 0.3:
					rails += 1
					tricks += 1
					combo += 2
					best_combo = maxi(best_combo, combo)
					score += 90 * mini(6, 1 + combo / 3)
					grind = 0.65
					jump = 0.0
					notices.append("rail")
			"ramp":
				jump = jump_length * 0.8
				score += 40
				notices.append("ramp")
	if distance >= length and hearts > 0:
		done = true
		won = true
	if events.size() > 150:
		events = events.filter(func(e: Dictionary) -> bool: return float(e.d) > distance - 20.0)

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
	for key in ["mode","route","seed_value","distance","duration","length","speed","lane","x","jump","jump_length","height","grind","invincible","hearts","score","combo","best_combo","tokens","tricks","rails","hits","done","won","continued","pop_level","grip_level","events","next_section","run_id"]:
		data[key] = get(key)
	return data.duplicate(true)

func restore(data: Dictionary) -> bool:
	if not valid_snapshot(data): return false
	for key in snapshot(): set(key, data[key])
	return true

static func number_in(value: Variant,low: float,high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=low and float(value)<=high

static func valid_snapshot(data: Dictionary) -> bool:
	if not data.get("mode") is String or data.mode not in ["campaign","daily","endless"]: return false
	for key in ["done","won","continued"]:
		if not data.get(key) is bool: return false
	var limits: Dictionary={"route":[0,29],"seed_value":[0,1e9],"distance":[0,1e8],"duration":[0,1e8],"length":[1,1e8],"speed":[0.1,30],"lane":[0,2],"x":[-3,3],"jump":[0,2],"jump_length":[0.1,2],"height":[0,3],"grind":[0,2],"invincible":[0,5],"hearts":[0,3],"score":[0,1e12],"combo":[0,1e9],"best_combo":[0,1e9],"tokens":[0,1e9],"tricks":[0,1e9],"rails":[0,1e9],"hits":[0,100],"pop_level":[0,4],"grip_level":[0,4],"next_section":[0,1e8],"run_id":[1,1e12]}
	for key in limits:
		if not number_in(data.get(key),limits[key][0],limits[key][1]): return false
	for key in ["route","seed_value","lane","hearts","run_id","next_section","pop_level","grip_level","score","combo","best_combo","tokens","tricks","rails","hits"]:
		if float(data[key])!=floor(float(data[key])): return false
	# Prevent a corrupt restored distance from causing millions of generator
	# catch-up iterations in one frame.
	if float(data.distance)>18.0+float(data.next_section)*12.0: return false
	if not data.get("events") is Array or data.events.size()>256: return false
	for event in data.events:
		if not event is Dictionary: return false
		if not number_in(event.get("d"),0,1e8) or not number_in(event.get("lane"),0,2): return false
		if float(event.lane)!=floor(float(event.lane)): return false
		if not event.get("kind") is String or event.kind not in ["token","block","rail","ramp"]: return false
		if not event.get("used") is bool: return false
	return true
