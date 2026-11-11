extends SceneTree
func _init()->void:call_deferred("begin")
func begin()->void:
	var isolated:=OS.get_environment("POPLINE_TEST_ROOT").replace("\\","/")
	if isolated.is_empty() or not ProjectSettings.globalize_path("user://").begins_with(isolated):quit(2);return
	DisplayServer.window_set_size(Vector2i(540,960))
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var probe=load("res://game/native_acceptance.gd").new()
	root.add_child(probe)
	probe.start(game)
