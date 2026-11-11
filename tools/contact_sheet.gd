extends SceneTree
func _init()->void:
	var paths:Array[String]=[]
	for profile in ["phone","tablet7","tablet10"]:
		for name in ["01-park-home","02-first-line","03-boardslide","04-line-landed","05-locker","06-journal","07-brickyard-scene","08-blue-hour-scene"]:
			paths.append("res://marketing/screenshots/"+profile+"/"+name+".png")
	var sheet:=Image.create(8*216,3*384,false,Image.FORMAT_RGB8)
	sheet.fill(Color("193b48"))
	for i in range(paths.size()):
		if not FileAccess.file_exists(paths[i]):continue
		var img:=Image.load_from_file(paths[i])
		img.convert(Image.FORMAT_RGB8)
		img.resize(216,384,Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(img,Rect2i(0,0,216,384),Vector2i(i%8*216,i/8*384))
	sheet.save_png("res://build/capture-contact-sheet.png")
	quit()
