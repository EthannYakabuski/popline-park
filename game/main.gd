extends Node3D
const Profile = preload("res://game/profile.gd")
const Run = preload("res://game/run.gd")
const Park = preload("res://game/park.gd")
const INK := Color("193b48")
const CREAM := Color("fff4de")
const CORAL := Color("f37763")
var profile: RefCounted
var run: RefCounted
var park: Node3D
var ui: Control
var page := "home"
var paused := false
var reward_pending := false
var reward_earned := false
var earned_retry_id := 0
var ad_was_active := false
var banked := false
var payout := {}
var save_clock := 0.0
var hud_score: Label
var hud_combo: Label
var hud_hearts: Control
var hud_progress: ProgressBar
var toast: Label
var toast_time := 0.0
var catalog: Dictionary
var pointer_start := Vector2.ZERO
var pointer_down := false
var music: AudioStreamPlayer
var sfx: AudioStreamPlayer
var ui_rebuild_queued := false

func _ready() -> void:
	get_tree().auto_accept_quit = false
	profile = Profile.new()
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://game/catalog.json"))
	park = Park.new()
	add_child(park)
	park.set_skater(int(profile.data.skater))
	var canvas := CanvasLayer.new()
	add_child(canvas)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui)
	var theme := Theme.new()
	theme.default_font_size = 22
	ui.theme = theme
	music = AudioStreamPlayer.new()
	music.stream = load("res://assets/audio/park-loop.wav")
	music.volume_db = -16
	add_child(music)
	var stream: AudioStreamWAV = music.stream
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = stream.data.size()/4
	if bool(profile.data.music): music.play()
	sfx = AudioStreamPlayer.new()
	sfx.volume_db = -8
	add_child(sfx)
	Services._round_count = int(profile.data.totals.rounds)
	Services.menu_bottom_reserve_changed.connect(_request_ui)
	Services.availability_changed.connect(_service_changed)
	Services.play_games_notice.connect(func(message: String) -> void: _message(message))
	Services.service_notice.connect(func(message: String) -> void:
		if page=="settings": _message(message)
	)
	get_viewport().size_changed.connect(_request_ui)
	show_page("home")
	if not profile.recovery.is_empty(): _message(profile.recovery)
	_check_achievements()
	if OS.is_debug_build() and OS.has_feature("acceptance"):
		var probe=load("res://game/native_acceptance.gd").new()
		add_child(probe)
		probe.start.call_deferred(self)

func _request_ui() -> void:
	if ui_rebuild_queued: return
	ui_rebuild_queued = true
	_rebuild.call_deferred()

func _rebuild() -> void:
	ui_rebuild_queued = false
	show_page(page)

func _service_changed() -> void:
	if page == "result" and not reward_pending: _request_ui()

func _process(delta: float) -> void:
	if park == null: return
	var ad_active: bool = Services.fullscreen_ad_active()
	if ad_active and not ad_was_active:
		if page == "ride":
			paused = true
			_store_active()
			_request_ui()
	if ad_was_active and not ad_active:
		if reward_pending:
			reward_pending = false
			if reward_earned:
				reward_earned = false
				paused = true
				show_page("ride")
			else:
				show_page("result")
				_message("Reward earned. Retry saving your continue." if earned_retry_id>0 else "No reward earned. Retry whenever you like.")
	ad_was_active = ad_active
	var moving := page == "ride" and not paused and not ad_active
	if moving and run != null:
		run.step(delta)
		_handle_events()
		save_clock += delta
		if save_clock > 5.0:
			save_clock = 0.0
			if not _store_active():
				paused = true
				show_page("ride")
				_message(profile.last_error)
		if run.done:
			_store_active()
			show_page("result")
			if run.won: _bank_result()
	park.animate_view(run if page in ["ride","result"] else null,delta,moving or page == "home")
	if page == "ride" and is_instance_valid(hud_score):
		hud_score.text = "%04d" % run.score
		hud_combo.text = "x%d  •  %d tokens" % [mini(6,1+run.combo/3),run.tokens]
		for i in range(hud_hearts.get_child_count()):
			hud_hearts.get_child(i).modulate=CORAL if i<run.hearts else Color("546b72")
		hud_progress.value = fmod(run.distance,400.0)/4.0 if run.mode=="endless" else run.distance/run.length*100
	if toast_time>0:
		toast_time-=delta
		if is_instance_valid(toast): toast.visible = toast_time>0

func _handle_events() -> void:
	for event in run.notices:
		match event:
			"pop": _sound("pop")
			"land":
				_sound("land")
				if run.combo%3==0: _message("CLEAN LINE  ×%d" % mini(6,1+run.combo/3))
			"token": _sound("token")
			"hit":
				_sound("hit")
				_message("BUMP!  Find a clear lane")
			"rail":
				_sound("success")
				_message("BOARDSLIDE!  +90 × combo")
			"clear": _message("NICE POP!")
			"ramp":
				_sound("pop")
				_message("AIR TIME!")
	run.notices.clear()

func _sound(key: String) -> void:
	if not bool(profile.data.sfx): return
	sfx.stream = load("res://assets/audio/"+key+".ogg")
	sfx.pitch_scale = 1.0+minf(0.35,float(run.combo)*0.015) if run!=null and key=="token" else 1.0
	sfx.play()

func _can_act() -> bool:
	return not Services.fullscreen_ad_active() and not reward_pending

func _unhandled_input(event: InputEvent) -> void:
	if page != "ride" or paused or not _can_act(): return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT,KEY_A: run.steer(-1)
			KEY_RIGHT,KEY_D: run.steer(1)
			KEY_SPACE,KEY_UP: run.ollie()
			KEY_ESCAPE: _pause()
	if event is InputEventScreenTouch:
		if event.pressed:
			pointer_start = event.position
			pointer_down = true
		elif pointer_down:
			var movement: Vector2 = event.position-pointer_start
			if absf(movement.x)>35: run.steer(1 if movement.x>0 else -1)
			else: run.ollie()
			pointer_down = false
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			pointer_start=event.position
			pointer_down=true
		elif pointer_down:
			var movement: Vector2 = event.position-pointer_start
			if absf(movement.x)>35: run.steer(1 if movement.x>0 else -1)
			else: run.ollie()
			pointer_down=false

func _notification(what: int) -> void:
	if profile == null: return
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT]:
		if page=="ride": _pause()
	elif what==NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()
	elif what==NOTIFICATION_WM_CLOSE_REQUEST:
		_store_active()
		get_tree().quit()

func _back() -> void:
	if not _can_act(): return
	if page=="ride": _pause()
	elif page=="result": _finish_to("home")
	elif page!="home": show_page("home")
	else: _message("Your park is saved. Use Home to leave.")

func _pause() -> void:
	if run==null or page!="ride": return
	paused=true
	pointer_down=false
	_store_active()
	show_page("ride")

func _resume() -> void:
	if not _can_act(): return
	if not _store_active():
		_message(profile.last_error)
		return
	paused=false
	show_page("ride")

func _store_active() -> bool:
	if run==null or banked: return true
	return profile.store_run(run.snapshot())

func start_run(mode: String, index: int) -> void:
	if not _can_act(): return
	if mode=="campaign" and index>profile.unlocked_route(): return
	if not profile.data.active.is_empty():
		run = Run.new()
		if run.restore(profile.data.active):
			banked=false
			paused=true
			park.reset_events()
			park.set_district(run.route/10 if run.mode=="campaign" else run.seed_value%3)
			show_page("result" if run.done else "ride")
			return
	var id: int = profile.new_run()
	if id==0:
		_message(profile.last_error)
		return
	run=Run.new()
	run.setup(mode,index,Profile.today(),profile.data.gear,id)
	banked=false
	payout={}
	paused=false
	save_clock=0
	if not _store_active():
		_message(profile.last_error)
		return
	park.reset_events()
	park.set_district(index/10 if mode=="campaign" else Profile.today()%3)
	show_page("ride")
	if id<=2: _message("Swipe to steer • Tap to ollie")

func _bank_result() -> bool:
	if banked: return true
	payout=profile.settle(run,Profile.today())
	if payout.is_empty():
		_message("Couldn't save this run. Please try again.")
		return false
	banked=true
	_check_achievements()
	Services.round_finished()
	_request_ui()
	return true

func _finish_to(next_page: String) -> void:
	if not _can_act() or not _bank_result(): return
	show_page(next_page)

func _retry() -> void:
	if not _can_act() or not _bank_result(): return
	var mode: String=run.mode
	var index: int=run.route
	start_run(mode,index)

func _next() -> void:
	if not _can_act() or not _bank_result(): return
	start_run("campaign",mini(29,run.route+1))

func _continue() -> void:
	if not _can_act() or banked or run.continued: return
	if earned_retry_id==run.run_id:
		if _apply_earned_continue(run.run_id):
			paused=true
			show_page("ride")
		else: _message("Storage is still unavailable. Your earned continue is waiting.")
		return
	reward_pending=true
	reward_earned=false
	var expected_id: int=run.run_id
	Services.reward_requested("continue_run_"+str(expected_id),func(earned: bool) -> void:
		if run==null or run.run_id!=expected_id: return
		if earned: reward_earned=_apply_earned_continue(expected_id)
		if not Services.fullscreen_ad_active():
			reward_pending=false
			show_page("ride" if reward_earned else "result")
			if not reward_earned: _message("No ad is available. Retry is always free.")
	)

func _apply_earned_continue(expected_id: int) -> bool:
	if run==null or run.run_id!=expected_id or banked: return false
	var before: Dictionary=run.snapshot()
	if not run.revive(true): return false
	paused=true
	if _store_active():
		earned_retry_id=0
		return true
	run.restore(before)
	earned_retry_id=expected_id
	return false

func _ride_action(direction: int) -> void:
	if page!="ride" or paused or not _can_act() or run==null: return
	if direction==0: run.ollie()
	else: run.steer(direction)

func _end_ride() -> void:
	if run==null or not _can_act(): return
	var before: Dictionary=run.snapshot()
	run.done=true
	run.won=false
	if not _store_active():
		run.restore(before)
		_message(profile.last_error)
		return
	if _bank_result(): show_page("home")

func show_page(next_page: String) -> void:
	page=next_page
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	Services.set_menu_visible(page in ["home","result"])
	var w := ui.size.x
	var h := ui.size.y
	if w<1: w=540
	if h<1: h=960
	var reserve := maxf(20.0,Services.menu_bottom_reserve(ui)) if page in ["home","result"] else 20.0
	match page:
		"home": _home(w,h,reserve)
		"ride": _ride_ui(w,h)
		"result": _result_ui(w,h,reserve)
		"campaign": _campaign(w,h)
		"locker": _locker(w,h)
		"daily": _daily(w,h)
		"journal": _journal(w,h)
		"settings": _settings(w,h)
	toast=label("",24,CREAM)
	toast.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	toast.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	place(toast,Vector2(30,h*0.32),Vector2(w-60,90))
	toast.add_theme_color_override("font_shadow_color",INK)
	toast.add_theme_constant_override("shadow_offset_x",2)
	toast.add_theme_constant_override("shadow_offset_y",2)
	toast.visible=false

func label(text: String,size: int=22,color: Color=INK) -> Label:
	var n:=Label.new()
	n.text=text
	n.add_theme_font_size_override("font_size",size)
	n.add_theme_color_override("font_color",color)
	n.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return n

func place(node: Control,pos: Vector2,dimensions: Vector2,parent: Node=ui) -> Control:
	parent.add_child(node)
	node.position=pos
	node.size=dimensions
	return node

func panel(pos: Vector2,dimensions: Vector2,color: Color=Color("fff4deef"),parent: Node=ui) -> Panel:
	var n:=Panel.new()
	var style:=StyleBoxFlat.new()
	style.bg_color=color
	style.set_corner_radius_all(22)
	style.shadow_color=Color(0.08,0.14,0.19,0.16)
	style.shadow_size=6
	n.add_theme_stylebox_override("panel",style)
	place(n,pos,dimensions,parent)
	return n

func button(text: String,action: Callable,primary: bool=false) -> Button:
	var n:=Button.new()
	n.text=text
	n.custom_minimum_size=Vector2(0,62)
	n.add_theme_font_size_override("font_size",24 if primary else 21)
	n.add_theme_color_override("font_color",INK)
	n.add_theme_color_override("font_hover_color",INK)
	n.add_theme_color_override("font_pressed_color",INK)
	var style:=StyleBoxTexture.new()
	style.texture=load("res://assets/ui/button-gold.png" if primary else "res://assets/ui/button-cream.png")
	style.texture_margin_left=12
	style.texture_margin_right=12
	style.texture_margin_top=12
	style.texture_margin_bottom=12
	n.add_theme_stylebox_override("normal",style)
	n.add_theme_stylebox_override("hover",style)
	n.add_theme_stylebox_override("pressed",style)
	n.pressed.connect(func() -> void:
		if _can_act():
			_sound("click")
			action.call()
	)
	return n

func _header(title: String,subtitle: String,w: float) -> void:
	panel(Vector2(18,18),Vector2(w-36,118))
	place(label(title,34),Vector2(36,31),Vector2(w-140,48))
	place(label(subtitle,18),Vector2(36,85),Vector2(w-72,36))
	place(button("<",_back),Vector2(w-98,35),Vector2(62,62))

func _home(w: float,h: float,reserve: float) -> void:
	place(label("POPLINE\nPARK",60,CREAM),Vector2(30,50),Vector2(w-60,164))
	place(label("Find your line.",26,INK),Vector2(34,210),Vector2(w-68,40))
	place(button("...",func() -> void: show_page("settings")),Vector2(w-92,50),Vector2(60,62))
	var top:=h-reserve-300
	panel(Vector2(20,top),Vector2(w-40,286))
	place(label("SKATER LV %d    •    %d coins"%[profile.level(),profile.data.coins],20),Vector2(36,top+17),Vector2(w-72,32))
	var title: String="Continue your ride" if not profile.data.active.is_empty() else "Ride line %02d"%(profile.unlocked_route()+1)
	place(button(title,func() -> void: start_run("campaign",profile.unlocked_route()),true),Vector2(36,top+61),Vector2(w-72,68))
	var bw: float=(w-84)/2
	place(button("Park lines",func() -> void: show_page("campaign")),Vector2(36,top+141),Vector2(bw,56))
	place(button("Endless ride",func() -> void: start_run("endless",0)),Vector2(48+bw,top+141),Vector2(bw,56))
	var small: float=(w-96)/3
	for i in range(3):
		var dest: String=["locker","daily","journal"][i]
		place(button(["Locker","Daily","Journal"][i],func() -> void: show_page(dest)),Vector2(36+i*(small+12),top+209),Vector2(small,54))

func _ride_ui(w: float,h: float) -> void:
	panel(Vector2(18,18),Vector2(w-36,128),Color("193b48e8"))
	hud_score=label("0000",44,CREAM)
	place(hud_score,Vector2(35,26),Vector2(220,55))
	hud_combo=label("x1",19,Color("ffd481"))
	place(hud_combo,Vector2(35,83),Vector2(w-150,32))
	hud_hearts=Control.new()
	place(hud_hearts,Vector2(w-202,34),Vector2(128,40))
	for i in range(3):
		var heart:=TextureRect.new()
		heart.texture=load("res://assets/ui/heart.png")
		heart.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.mouse_filter=Control.MOUSE_FILTER_IGNORE
		heart.modulate=CORAL
		place(heart,Vector2(i*42,0),Vector2(38,38),hud_hearts)
	place(button("II",_pause),Vector2(w-83,83),Vector2(48,48))
	hud_progress=ProgressBar.new()
	hud_progress.show_percentage=false
	place(hud_progress,Vector2(36,120),Vector2(w-135,7))
	place(button("<",func() -> void: _ride_action(-1)),Vector2(24,h-112),Vector2(90,82))
	place(button("OLLIE",func() -> void: _ride_action(0),true),Vector2(128,h-112),Vector2(w-256,82))
	place(button(">",func() -> void: _ride_action(1)),Vector2(w-114,h-112),Vector2(90,82))
	var hint:=label("HOP ON RAILS  •  KEEP YOUR LINE",16,CREAM)
	hint.add_theme_color_override("font_color",INK)
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	place(hint,Vector2(20,h-154),Vector2(w-40,30))
	if paused:
		panel(Vector2(28,h*0.39),Vector2(w-56,340))
		place(label("Catch your breath",30),Vector2(48,h*0.39+22),Vector2(w-96,50))
		place(button("Keep rolling",_resume,true),Vector2(48,h*0.39+86),Vector2(w-96,65))
		place(button("Save & return to park",func() -> void:
			if _store_active(): show_page("home")
		),Vector2(48,h*0.39+167),Vector2(w-96,62))
		place(button("End ride & bank",_end_ride),Vector2(48,h*0.39+245),Vector2(w-96,62))

func _stars(count: int,parent: Node,pos: Vector2,size: float=48) -> void:
	for i in range(3):
		var n:=TextureRect.new()
		n.texture=load("res://assets/ui/star.png" if i<count else "res://assets/ui/star-empty.png")
		n.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		n.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		n.mouse_filter=Control.MOUSE_FILTER_IGNORE
		place(n,pos+Vector2(i*(size+6),0),Vector2(size,size),parent)

func _result_ui(w: float,h: float,reserve: float) -> void:
	var top:=maxf(155,h-reserve-530)
	panel(Vector2(24,top),Vector2(w-48,514))
	place(label("LINE LANDED!" if run.won else "ONE MORE TRY?",34),Vector2(45,top+22),Vector2(w-90,55))
	_stars(run.stars(),ui,Vector2(w/2-81,top+83))
	place(label("%d  POINTS"%run.score,36),Vector2(45,top+146),Vector2(w-90,50))
	place(label("%d tricks  •  %d rails  •  combo %d"%[run.tricks,run.rails,run.best_combo],19),Vector2(45,top+205),Vector2(w-90,40))
	var detail: String="+%d coins   +%d XP"%[payout.get("coins",0),payout.get("xp",0)] if banked else "Your ride will be saved when you finish."
	place(label(detail,18),Vector2(45,top+247),Vector2(w-90,30))
	if not run.won and not run.continued and not banked:
		place(button("Save earned continue" if earned_retry_id==run.run_id else "Watch ad • 2 hearts & continue",_continue,true),Vector2(42,top+290),Vector2(w-84,65))
		if not Services.can_reward(): place(label("Ad unavailable right now • Retry is free",16),Vector2(46,top+358),Vector2(w-92,27))
	else:
		place(button("Next line" if run.mode=="campaign" and run.won else "Ride again",_next if run.mode=="campaign" and run.won else _retry,true),Vector2(42,top+290),Vector2(w-84,65))
	place(button("Retry",_retry),Vector2(42,top+399),Vector2((w-96)/2,64))
	place(button("Back to park",func() -> void: _finish_to("home")),Vector2(w/2+6,top+399),Vector2((w-96)/2,64))

func _scroll(w: float,h: float) -> VBoxContainer:
	var s:=ScrollContainer.new()
	place(s,Vector2(24,158),Vector2(w-48,h-184))
	s.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	var box:=VBoxContainer.new()
	box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",12)
	s.add_child(box)
	return box

func _campaign(w: float,h: float) -> void:
	_header("Park lines","30 lines • 3 neighborhoods • Find your flow",w)
	var list:=_scroll(w,h)
	for group in range(3):
		list.add_child(label(["01  /  PALM PROMENADE","02  /  BRICKYARD GROOVE","03  /  BLUE HOUR PIER"][group],22,CREAM))
		for row in range(4):
			var line:=HBoxContainer.new()
			line.add_theme_constant_override("separation",8)
			list.add_child(line)
			for col in range(3):
				var index:=group*10+row*3+col
				if index>=group*10+10: continue
				var card:=VBoxContainer.new()
				card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
				line.add_child(card)
				var b:=button("%02d"%(index+1) if index<=profile.unlocked_route() else "Locked",func() -> void: start_run("campaign",index),index==profile.unlocked_route())
				b.disabled=index>profile.unlocked_route()
				card.add_child(b)
				var stars_node:=Control.new()
				stars_node.custom_minimum_size=Vector2(100,35)
				card.add_child(stars_node)
				_stars(int(profile.data.stars[index]) if index<profile.data.stars.size() else 0,stars_node,Vector2(12,0),26)

func _locker(w: float,h: float) -> void:
	_header("The locker","Level %d • %d coins • Permanent gear"%[profile.level(),profile.data.coins],w)
	var list:=_scroll(w,h)
	for key in ["pop","grip","style"]:
		var rank:=int(profile.data.gear[key])
		var title: String={"pop":"Pop / longer airtime","grip":"Grip / quicker lane changes","style":"Style / extra token coins"}[key]
		var card:=_list_card(list,150)
		place(label(title,24),Vector2(18,12),Vector2(w-120,40),card)
		place(label("Level %d / 4"%rank,18),Vector2(18,55),Vector2(130,30),card)
		var b:=button("Maxed" if rank==4 else "Upgrade • %d"%(150+rank*220),func() -> void:
			if profile.upgrade(key):
				_check_achievements()
				show_page("locker")
			else: _message("Keep riding to earn more coins.")
		,true)
		b.disabled=rank>=4
		place(b,Vector2(18,89),Vector2(w-120,52),card)
	list.add_child(button("Change skater • "+("Mika" if profile.data.skater==0 else "Jules"),func() -> void:
		var next: Dictionary=profile.data.duplicate(true)
		next.skater=1-int(next.skater)
		if profile.commit(next): park.set_skater(int(next.skater))
		show_page("locker")
	))

func _list_card(parent: Node,height: float) -> Panel:
	var card:=panel(Vector2.ZERO,Vector2(ui.size.x-48,height),Color("fff4deef"),parent)
	card.custom_minimum_size.y=height
	return card

func _daily(w: float,h: float) -> void:
	_header("Daily drop","A fresh line and a little reason to ride",w)
	var list:=_scroll(w,h)
	list.add_child(button("Claim today's gift • day %d"%(int(profile.data.streak)%7+1),func() -> void:
		var amount: int=profile.login(Profile.today())
		show_page("daily")
		_message("+%d coins. See you tomorrow!"%amount if amount>0 else "Today's gift is already collected.")
		_check_achievements()
	,true))
	list.add_child(label("7-day streak • Gifts grow from 50 to 140 coins",17,CREAM))
	list.add_child(button("Today's park line",func() -> void: start_run("daily",0),true))
	list.add_child(label("Finish for +80 coins & +45 XP once each UTC day",17,CREAM))
	for key in ["tokens","tricks","wins"]:
		var target: int={"tokens":25,"tricks":12,"wins":3}[key]
		var amount:=int(profile.data.quest[key]) if int(profile.data.quest_day)==Profile.today() else 0
		var claimed: bool=profile.data.quest_claims.has(key) and int(profile.data.quest_day)==Profile.today()
		list.add_child(label("%s   %d / %d"%[key.capitalize(),mini(amount,target),target],26,CREAM))
		var b:=button("Collected" if claimed else "Claim • 65 coins + 30 XP",func() -> void:
			if profile.claim_quest(key,Profile.today()):
				show_page("daily")
				_check_achievements()
			else: _message("Keep riding to finish this goal.")
		)
		b.disabled=claimed or amount<target
		list.add_child(b)

func _journal(w: float,h: float) -> void:
	_header("Skater journal","%d / 20 achievements • Level %d"%[profile.data.achievements.size(),profile.level()],w)
	var list:=_scroll(w,h)
	for board_info in catalog.leaderboards:
		var value: int=int(profile.data.xp) if board_info.key=="xp" else int(profile.data.records[board_info.key])
		list.add_child(button(board_info.name+"  •  "+str(value),func() -> void: Services.open_leaderboards(board_info.key)))
	list.add_child(button("Google Play achievements",func() -> void: Services.open_achievements()))
	for achievement in catalog.achievements:
		var unlocked: bool=profile.data.achievements.has(achievement.key)
		var card:=_list_card(list,110)
		var icon:=TextureRect.new()
		icon.texture=load("res://assets/ui/badges/"+achievement.key+".png")
		icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate=Color.WHITE if unlocked else Color(0.7,0.7,0.7,0.6)
		place(icon,Vector2(12,18),Vector2(70,70),card)
		place(label(achievement.name+(" *" if unlocked else ""),23),Vector2(96,13),Vector2(w-180,37),card)
		var desc:=label(achievement.description,16)
		desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		place(desc,Vector2(96,54),Vector2(w-180,46),card)

func _settings(w: float,h: float) -> void:
	_header("Your park","Sound, privacy and play services",w)
	var list:=_scroll(w,h)
	for key in ["music","sfx"]:
		list.add_child(button(key.capitalize()+": "+("on" if profile.data[key] else "off"),func() -> void:
			var next: Dictionary=profile.data.duplicate(true)
			next[key]=not bool(next[key])
			if profile.commit(next):
				if profile.data.music: music.play()
				else: music.stop()
			show_page("settings")
		))
	list.add_child(button("Connect Google Play Games",func() -> void: Services.sign_in()))
	list.add_child(button("Advertising privacy choices",func() -> void: Services.privacy_options()))
	var info:=label("Swipe left or right to change lanes. Tap the park or OLLIE to hop. Land on an orange rail for a boardslide. Avoid the low blocks or jump over them.\n\nKeyboard: arrows / A-D and Space.\n\nProgress saves on this device. Android services need a connection; Web keeps local records.\n\nKenney assets • CC0\nGodot and native plugins • MIT\nOriginal game • Apache 2.0\nIllustrated branding • AI generated",20,CREAM)
	info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	list.add_child(info)

func _message(message: String) -> void:
	if not is_instance_valid(toast): return
	toast.text=message
	toast.visible=true
	toast_time=2.8

func _check_achievements() -> void:
	var next: Dictionary=profile.data.duplicate(true)
	var changed:=false
	for item in catalog.achievements:
		var value:=0
		match str(item.metric):
			"level": value=profile.level()
			"stars":
				for amount in profile.data.stars: value+=int(amount)
			"gear":
				for amount in profile.data.gear.values(): value+=int(amount)
			"streak": value=int(profile.data.streak)
			"score","combo": value=int(profile.data.records[item.metric])
			_: value=int(profile.data.totals.get(item.metric,0))
		if value>=int(item.target):
			if not next.achievements.has(item.key):
				next.achievements[item.key]=true
				changed=true
	if changed and not profile.commit(next): return
	for key in profile.data.achievements: Services.unlock(key)
	Services.submit("score",int(profile.data.records.score))
	Services.submit("combo",int(profile.data.records.combo))
	Services.submit("xp",int(profile.data.xp))
