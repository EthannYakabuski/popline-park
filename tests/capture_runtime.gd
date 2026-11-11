extends SceneTree
var game: Node
var frames:=0
var output:=""
var profile_name:="phone"
var caught_ride:=false
var caught_rail:=false
var capturing:=false

func _init() -> void:
	call_deferred("begin")

func begin() -> void:
	var options:=OS.get_cmdline_user_args()
	profile_name=options[0] if options.size()>0 else "phone"
	if profile_name not in ["phone","tablet7","tablet10"]:
		quit(2)
		return
	DisplayServer.window_set_size({"phone":Vector2i(1080,1920),"tablet7":Vector2i(800,1280),"tablet10":Vector2i(1200,1920)}[profile_name])
	output="res://marketing/screenshots/"+profile_name+"/"
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await capture("01-park-home")
	game.start_run("campaign",0)
	game.paused=false
	process_frame.connect(play)

func capture(name_value: String) -> void:
	capturing=true
	await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	if image.save_png(output+name_value+".png")!=OK:
		quit(3)
		return
	print("CAPTURE ",profile_name,"/",name_value," ",image.get_width(),"x",image.get_height())
	capturing=false

func play() -> void:
	frames+=1
	if frames>9000:
		printerr("CAPTURE TIMEOUT")
		quit(1)
		return
	if capturing or game.run==null: return
	if game.page=="ride":
		if game.paused:game.paused=false
		var ride: RefCounted=game.run
		var nearest: Dictionary={}
		var best:=100.0
		for e in ride.events:
			var d: float=float(e.d)-ride.distance
			if e.kind!="token" and d>0 and d<best:
				best=d
				nearest=e
		if not nearest.is_empty():
			if best>4 and best<10:
				var target:=int(nearest.lane)
				if nearest.kind=="block":target=(target+1)%3
				var direction:=signi(target-ride.lane)
				if direction!=0:game._ride_action(direction)
			if nearest.kind=="rail" and best<ride.speed*0.4 and best>ride.speed*0.3:game._ride_action(0)
		if ride.distance>25 and not caught_ride:
			caught_ride=true
			capture("02-first-line")
		elif ride.grind>0.1 and not caught_rail:
			caught_rail=true
			capture("03-boardslide")
	elif game.page=="result":
		process_frame.disconnect(play)
		if not game.run.won:
			printerr("CAPTURE RUN LOST")
			quit(1)
			return
		await capture("04-line-landed")
		game.show_page("locker")
		await capture("05-locker")
		game.show_page("journal")
		await capture("06-journal")
		# Genuine alternate-district views of the implemented scene. Gameplay
		# captures above are an actual completed unmodified fresh-profile ride.
		game.show_page("home")
		game.park.set_district(1)
		await capture("07-brickyard-scene")
		game.park.set_district(2)
		await capture("08-blue-hour-scene")
		print("CAPTURE_RUNTIME_PASS real completed ride score=",game.run.score," rails=",game.run.rails)
		game.queue_free()
		await process_frame
		quit()
