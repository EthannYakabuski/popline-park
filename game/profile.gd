extends RefCounted
const RunModel = preload("res://game/run.gd")
var path := "user://profile-v1.json"
var data: Dictionary
var recovery := ""
var last_error := ""

func _init(save_path: String = "user://profile-v1.json") -> void:
	path = save_path
	data = defaults()
	load_profile()

static func defaults() -> Dictionary:
	return {"version":1,"sequence":0,"xp":0,"coins":0,"gear":{"pop":0,"grip":0,"style":0},"stars":[],"next_run":1,"last_paid_run":0,"active":{},"totals":{"rounds":0,"wins":0,"tricks":0,"rails":0,"tokens":0,"clean":0,"daily":0},"records":{"score":0,"combo":0},"login_day":-1,"streak":0,"quest_day":-1,"quest":{"tokens":0,"tricks":0,"wins":0},"quest_claims":[],"daily_paid":-1,"achievements":{},"music":true,"sfx":true,"skater":0}

static func today() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)

static func valid(value: Variant) -> bool:
	if not value is Dictionary or not RunModel.number_in(value.get("version"),1,1): return false
	for key in defaults():
		if not value.has(key): return false
	for key in ["xp","coins","sequence","next_run","last_paid_run","streak","skater"]:
		if not RunModel.number_in(value[key],0,1e12) or float(value[key])!=floor(float(value[key])): return false
	for key in ["login_day","quest_day","daily_paid"]:
		if not RunModel.number_in(value[key],-1,1e9) or float(value[key])!=floor(float(value[key])): return false
	for key in ["gear","active","totals","records","quest","achievements"]:
		if not value[key] is Dictionary: return false
	if not value.active.is_empty():
		if not RunModel.valid_snapshot(value.active): return false
		if int(value.active.run_id) <= int(value.last_paid_run) or int(value.active.run_id) >= int(value.next_run): return false
	for key in ["music","sfx"]:
		if not value[key] is bool: return false
	if int(value.skater) not in [0,1]: return false
	if not value.stars is Array or value.stars.size() > RunModel.ROUTE_COUNT or not value.quest_claims is Array: return false
	for key in ["pop","grip","style"]:
		if not value.gear.has(key) or not RunModel.number_in(value.gear[key],0,4) or float(value.gear[key])!=floor(float(value.gear[key])): return false
	for key in defaults().totals:
		if not value.totals.has(key) or not RunModel.number_in(value.totals[key],0,1e12): return false
		if float(value.totals[key])!=floor(float(value.totals[key])): return false
	for key in ["score","combo"]:
		if not value.records.has(key) or not RunModel.number_in(value.records[key],0,1e12): return false
		if float(value.records[key])!=floor(float(value.records[key])): return false
	for key in ["tokens","tricks","wins"]:
		if not value.quest.has(key) or not RunModel.number_in(value.quest[key],0,1e12): return false
		if float(value.quest[key])!=floor(float(value.quest[key])): return false
	if value.quest_claims.size()>3: return false
	for claim in value.quest_claims:
		if not claim is String or claim not in ["tokens","tricks","wins"]: return false
	for key in value.achievements:
		if not key is String or not value.achievements[key] is bool: return false
	for star in value.stars:
		if not RunModel.number_in(star,0,3) or float(star)!=floor(float(star)): return false
	return true

func load_profile() -> void:
	for candidate in [path,path + ".bak"]:
		if not FileAccess.file_exists(candidate): continue
		var parsed: Variant = read_json(candidate)
		if valid(parsed):
			data = parsed
			if candidate.ends_with(".bak"): recovery = "Recovered your last safe save."
			return
	if FileAccess.file_exists(path): recovery = "Save could not be read. A fresh profile is ready; the original file is preserved."

static func read_json(filename: String) -> Variant:
	var parser:=JSON.new()
	return parser.data if parser.parse(FileAccess.get_file_as_string(filename))==OK else null

func commit(next: Dictionary) -> bool:
	if not valid(next):
		last_error = "Progress could not be saved. Please try again."
		return false
	next.sequence = int(data.sequence) + 1
	var file := FileAccess.open(path + ".tmp",FileAccess.WRITE)
	if file == null:
		last_error = "Storage is unavailable. Progress is paused until it can be saved."
		return false
	file.store_string(JSON.stringify(next))
	file.flush()
	var err := file.get_error()
	file.close()
	if err != OK: return false
	if FileAccess.file_exists(path) and valid(read_json(path)):
		if DirAccess.copy_absolute(path,path + ".bak") != OK: return false
	if DirAccess.rename_absolute(path + ".tmp",path) != OK:
		last_error = "Storage is unavailable. Please try again."
		return false
	data = next.duplicate(true)
	last_error = ""
	return true

func level() -> int:
	return 1 + int(sqrt(float(data.xp) / 55.0))

func unlocked_route() -> int:
	var last := 0
	for i in range(data.stars.size()):
		if int(data.stars[i]) > 0: last = maxi(last,i + 1)
	return mini(RunModel.ROUTE_COUNT-1,last)

func new_run() -> int:
	var next := data.duplicate(true)
	var id := int(next.next_run)
	next.next_run = id + 1
	return id if commit(next) else 0

func store_run(run: Dictionary) -> bool:
	var next := data.duplicate(true)
	next.active = run.duplicate(true)
	return commit(next)

func settle(run: RefCounted, day: int) -> Dictionary:
	if not run.done or run.run_id <= int(data.last_paid_run): return {}
	var next := data.duplicate(true)
	var pay: int = run.tokens * (2 + int(next.gear.style)) + run.score / 20 + (25 if run.won else 5)
	var xp: int = run.tricks * 5 + run.tokens + (45 if run.won else 10)
	if run.mode == "daily" and run.won and day > int(next.daily_paid):
		pay += 80
		xp += 45
		next.daily_paid = day
		next.totals.daily += 1
	next.coins += pay
	next.xp += xp
	next.last_paid_run = run.run_id
	next.active = {}
	next.totals.rounds += 1
	next.totals.wins += int(run.won)
	next.totals.clean += int(run.won and run.hits == 0)
	for key in ["tricks","rails","tokens"]: next.totals[key] += run.get(key)
	next.records.score = maxi(int(next.records.score),run.score)
	next.records.combo = maxi(int(next.records.combo),run.best_combo)
	if run.mode == "campaign" and run.won:
		while next.stars.size() <= run.route: next.stars.append(0)
		next.stars[run.route] = maxi(int(next.stars[run.route]),run.stars())
	_roll_day(next,day)
	if int(next.quest_day) == day:
		next.quest.tokens += run.tokens
		next.quest.tricks += run.tricks
		next.quest.wins += int(run.won)
	if not commit(next): return {}
	return {"coins":pay,"xp":xp}

static func _roll_day(next: Dictionary, day: int) -> void:
	if day > int(next.quest_day):
		next.quest_day = day
		next.quest = {"tokens":0,"tricks":0,"wins":0}
		next.quest_claims = []

func login(day: int) -> int:
	if day <= int(data.login_day): return 0
	var next := data.duplicate(true)
	next.streak = (int(next.streak) % 7 + 1) if day == int(next.login_day) + 1 else 1
	next.login_day = day
	var amount := 35 + int(next.streak) * 15
	next.coins += amount
	_roll_day(next,day)
	return amount if commit(next) else 0

func claim_quest(key: String, day: int) -> bool:
	var targets := {"tokens":25,"tricks":12,"wins":3}
	if not targets.has(key) or int(data.quest_day) != day or data.quest_claims.has(key) or int(data.quest[key]) < int(targets[key]): return false
	var next := data.duplicate(true)
	next.quest_claims.append(key)
	next.coins += 65
	next.xp += 30
	return commit(next)

func upgrade(key: String) -> bool:
	if not data.gear.has(key): return false
	var rank := int(data.gear[key])
	var price := 150 + rank * 220
	if rank >= 4 or int(data.coins) < price: return false
	var next := data.duplicate(true)
	next.coins -= price
	next.gear[key] += 1
	return commit(next)
