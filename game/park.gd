extends Node3D
var camera: Camera3D
var environment: WorldEnvironment
var player: Node3D
var rider: Node3D
var board: Node3D
var anim: AnimationPlayer
var scenery: Array[Dictionary] = []
var obstacles: Dictionary = {}
var materials: Dictionary = {}
var meshes: Dictionary = {}
var district := -1
var time := 0.0
var last_anim := ""
var ground: MeshInstance3D
var sun: DirectionalLight3D
var home_props: Node3D
var water: MeshInstance3D
var verge: MeshInstance3D
var promenade: MeshInstance3D

func _ready() -> void:
	environment = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.background_color = Color("8bd4dc")
	var sky:=Sky.new()
	var sky_material:=ProceduralSkyMaterial.new()
	sky_material.sky_top_color=Color("74b9cd")
	sky_material.sky_horizon_color=Color("e9e4cb")
	sky_material.ground_bottom_color=Color("72aca1")
	sky_material.ground_horizon_color=Color("d9d8c3")
	sky_material.sun_angle_max=8
	sky.sky_material=sky_material
	env.sky=sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("eff4ff")
	env.ambient_light_energy = 0.18
	env.ambient_light_sky_contribution = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled=true
	env.fog_light_color=Color("8db8c5")
	env.fog_density=0.0015
	environment.environment = env
	add_child(environment)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-32,0)
	sun.light_color = Color("ffe3b1")
	sun.light_energy = 0.6
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 85
	add_child(sun)
	camera = Camera3D.new()
	camera.position = Vector3(0,9.5,13.8)
	camera.fov = 58
	camera.far = 220
	add_child(camera)
	camera.look_at(Vector3(0,0,-14))
	ground = box(Vector3(11,0.24,200),Vector3(0,-0.25,-65),Color("9382b2"))
	water = box(Vector3(240,0.2,360),Vector3(0,-0.55,-110),Color("197f91"))
	verge = box(Vector3(23,0.22,200),Vector3(-16,-0.3,-65),Color("527946"))
	promenade = box(Vector3(11,0.23,200),Vector3(11,-0.3,-65),Color("bba889"))
	# A fixed far shore gives the moving promenade a waterfront setting.
	for i in range(13):
		var rock := model("nature/rock_smallA",Vector3(-95+i*17,-1,-175-abs(i-6)*3),Vector3(30,20+i%4*7,25))
		rock.rotation.y=float(i)*0.8
	for i in range(8):
		box(Vector3(13,1,0.15),Vector3(32+i%3*12,-0.28,-15-i*19),Color("79bbc3"))
	for x in [-5.65,5.65]:
		box(Vector3(0.25,0.35,200),Vector3(x,0,-65),Color("f4debe"))
	for x in [-1.18,1.18]:
		for z in range(0,32):
			var line := box(Vector3(0.055,0.015,1.1),Vector3(x,0.015,-z*5),Color("e8dfd4"))
			scenery.append({"node":line,"z":float(-z*5),"period":160.0})
	for i in range(18):
		var z := -float(i)*9.0
		var tree_name := "tree_palmTall" if i % 3 == 0 else "tree_oak"
		var tree := model("nature/"+tree_name,Vector3(-9-(i%3)*2,0,z),Vector3.ONE*(2.2 if i%3==0 else 1.8))
		scenery.append({"node":tree,"z":z,"period":162.0,"palm":true})
		if i % 2 == 0:
			var planter := box(Vector3(2.7,0.4,3.4),Vector3(-7.5,0,z),Color("f0c6b5"))
			scenery.append({"node":planter,"z":z,"period":162.0})
			var bush := model("nature/plant_bush",Vector3(-7.5,0.2,z),Vector3.ONE*2.8)
			scenery.append({"node":bush,"z":z,"period":162.0})
		var lamp := Node3D.new()
		add_child(lamp)
		lamp.position = Vector3(6.3,0,z)
		box(Vector3(0.12,3.3,0.12),Vector3(0,1.65,0),Color("365268"),lamp)
		box(Vector3(0.8,0.16,0.8),Vector3(0,3.3,0),Color("ffe9ae"),lamp)
		scenery.append({"node":lamp,"z":z,"period":162.0})
	for i in range(9):
		var z := -float(i)*19.0
		var house := model("city/building-"+char(97+i%5),Vector3(-23,0,z),Vector3.ONE*3.8)
		scenery.append({"node":house,"z":z,"period":171.0})
		var bowl := model("skate/"+(["half-pipe","bowl-side","structure-platform"][i%3]),Vector3(10,0,z),Vector3.ONE*3.6)
		bowl.rotation.y = PI/2
		scenery.append({"node":bowl,"z":z,"period":171.0})
		var fence := box(Vector3(0.12,1.0,17),Vector3(17,0.5,z),Color("538b90"))
		scenery.append({"node":fence,"z":z,"period":171.0})
		# Waterfront pilings frame an open vista beyond the skating surface.
		var piling := box(Vector3(0.3,1.4,0.3),Vector3(17,0.65,z+6),Color("eef0cf"))
		scenery.append({"node":piling,"z":z+6,"period":171.0})
	player = Node3D.new()
	add_child(player)
	board = model("skate/skateboard",Vector3(0,0.12,0),Vector3.ONE*3.5,player)
	board.rotation.y=0
	home_props=Node3D.new()
	add_child(home_props)
	var rail:=model("skate/rail-low",Vector3(2.4,0,-9),Vector3.ONE*4,home_props)
	rail.rotation.y=0
	model("skate/obstacle-end",Vector3(-2,0,-15),Vector3.ONE*4,home_props)
	model("skate/half-pipe",Vector3(-0.5,0,-25),Vector3.ONE*5,home_props)
	_neighborhood_scenery()
	set_skater(0)
	set_district(0)

func set_skater(index: int) -> void:
	if rider != null:
		player.remove_child(rider)
		rider.queue_free()
	rider = model("skate/character-skate-"+("girl" if index == 1 else "boy"),Vector3(0,0.18,0),Vector3.ONE*3.5,player)
	# Feet in the supplied skate pose are separated on local X. Turn the
	# rider sideways so both feet follow the board's longitudinal Z axis.
	rider.rotation.y = PI/2
	anim = find_animation(rider)
	last_anim = ""

func find_animation(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node
	for child in node.get_children():
		var found := find_animation(child)
		if found != null: return found
	return null

func material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if materials.has(key): return materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.88
	materials[key] = mat
	return mat

func box(size: Vector3,pos: Vector3,color: Color,parent: Node3D = self) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.material_override = material(color)
	n.position = pos
	parent.add_child(n)
	return n

func model(path: String,pos: Vector3,scale_value: Vector3,parent: Node3D = self) -> Node3D:
	if not meshes.has(path): meshes[path] = load("res://assets/"+path+".glb")
	var n: Node3D = meshes[path].instantiate()
	n.position = pos
	n.scale = scale_value
	parent.add_child(n)
	return n

func _neighborhood_scenery() -> void:
	for i in range(12):
		var z:float=-i*14.0
		var pine:=model("nature/tree_pineDefaultA",Vector3(-8-i%3*3,0,z),Vector3.ONE*(2.5+i%3*0.5))
		scenery.append({"node":pine,"z":z,"period":168.0,"district":4})
		var rock:=model("nature/rock_smallB",Vector3(8+i%2*3,0,z),Vector3.ONE*3)
		scenery.append({"node":rock,"z":z,"period":168.0,"district":4})
	for i in range(6):
		var z:float=-i*28.0
		var court:=Node3D.new()
		add_child(court)
		court.position=Vector3(-14,0,z)
		box(Vector3(11,0.08,18),Vector3.ZERO,Color("9e627e"),court)
		for edge in [-4.8,4.8]: box(Vector3(0.10,0.03,16),Vector3(edge,0.06,0),Color("ffdbad"),court)
		box(Vector3(9.7,0.03,0.1),Vector3(0,0.06,0),Color("ffdbad"),court)
		model("skate/structure-wood",Vector3(0,0,-7),Vector3(4,2,4),court)
		scenery.append({"node":court,"z":z,"period":168.0,"district":3})
		var dock:=Node3D.new()
		add_child(dock)
		dock.position=Vector3(20,0,z)
		model("skate/floor-wood",Vector3.ZERO,Vector3(10,1,10),dock)
		for offset in [-3,3]:
			box(Vector3(0.5,3,0.5),Vector3(offset,0,-3),Color("577d99"),dock)
			box(Vector3(0.8,0.3,0.8),Vector3(offset,1.6,-3),Color("ffe2a1"),dock)
		model("city/building-c",Vector3(5,0,-5),Vector3.ONE*3,dock)
		scenery.append({"node":dock,"z":z,"period":168.0,"district":5})

func set_district(index: int) -> void:
	index=clampi(index,0,5)
	if index == district: return
	district = index
	ground.material_override = material(Color(["9382b2","b78c67","677fa5","be827c","7a9782","657b9b"][index]))
	water.material_override = material(Color(["197f91","578b94","345e82","7f838e","447d77","274f73"][index]))
	verge.material_override = material(Color(["527946","7c8058","516c68","b68b70","425f49","49666b"][index]))
	promenade.material_override = material(Color(["bba889","bca58d","8796ad","c7a78b","a1a38a","7b8d9e"][index]))
	var sky_material: ProceduralSkyMaterial=environment.environment.sky.sky_material
	sky_material.sky_top_color=Color(["74b9cd","c2939a","435879","ca8f9d","83acaa","344663"][index])
	sky_material.sky_horizon_color=Color(["8bc4d0","e0b7a5","8c9dbf","efc1a2","c7d4b6","839ab6"][index])
	environment.environment.fog_light_color=sky_material.sky_horizon_color
	sun.light_color = Color(["fff3e1","ffdbb6","c4d8ff","ffdcad","e5f2d7","bbd4ff"][index])
	for prop in scenery:
		prop.node.visible = int(prop.get("district",index))==index and not (bool(prop.get("palm",false)) and index in [4,5])

func animate_view(run: RefCounted, delta: float, active: bool) -> void:
	time += delta if active else 0.0
	var d: float = run.distance if run != null else 0.0
	for prop in scenery:
		prop.node.position.z = fposmod(float(prop.z)+d+135.0,float(prop.period))-135.0
	if run != null:
		home_props.visible=false
		camera.position=Vector3(0,9.5,13.8)
		camera.look_at(Vector3(0,0,-14))
		player.position = Vector3(run.x,run.height,0)
		player.rotation.z = lerpf(player.rotation.z,(float(run.LANES[run.lane])-run.x)*-0.12,0.2)
		player.visible = run.invincible <= 0.0 or int(time*12)%2 == 0
		board.rotation.z = (1.0-run.flip_time/run.flip_duration)*TAU if run.flip_time>0.0 else 0.0
		board.rotation.y = PI/2 if run.grind>0.0 else 0.0
		rider.rotation.y = PI if run.grind>0.0 or run.push_time>0.0 else PI/2
		var motion:String="skate-grab" if run.grind>0 else ("skate-air" if run.jump>0.0 or run.drop_time>0.0 else ("skate" if run.push_time>0.0 else "skate-stand"))
		_set_animation(motion,active and motion!="skate-stand")
		if motion=="skate" and anim!=null:
			anim.seek((1.0-run.push_time/run.PUSH_TIME)*anim.current_animation_length,true)
		_update_events(run,active)
	else:
		home_props.visible=true
		camera.position=Vector3(4,7.7,11)
		camera.look_at(Vector3(0,0,-11))
		player.position = Vector3(0,0,-2)
		player.rotation=Vector3.ZERO
		board.rotation=Vector3.ZERO
		rider.rotation.y=PI/2
		player.visible = true
		_set_animation("skate-stand",true)
		for obj in obstacles.values(): obj.visible = false

func _set_animation(name_value: String, active: bool) -> void:
	if anim == null: return
	if last_anim != name_value and anim.has_animation(name_value):
		anim.get_animation(name_value).loop_mode = Animation.LOOP_LINEAR
		anim.play(name_value,0.0)
		anim.advance(0)
		last_anim = name_value
	anim.speed_scale = 1.0 if active else 0.0

func reset_events() -> void:
	for obj in obstacles.values(): obj.queue_free()
	obstacles.clear()

func _update_events(run: RefCounted,active: bool) -> void:
	var visible_keys := {}
	for event in run.events:
		var relative: float = run.event_position(event) - run.distance
		if relative > 95 or relative < -8: continue
		var key := str(event.d)+"/"+str(event.lane)+str(event.kind)
		visible_keys[key] = true
		if not obstacles.has(key):
			var obj: Node3D
			match str(event.kind):
				"block": obj = model("skate/obstacle-box",Vector3.ZERO,Vector3(2.4,1.6,2.4))
				"rail":
					obj = model("skate/rail-low",Vector3.ZERO,Vector3(3.0,3.0,float(event.get("rail_length",3.0))))
					obj.rotation.y = 0
				"ramp":
					obj = model("skate/obstacle-end",Vector3.ZERO,Vector3.ONE*2.8)
					obj.rotation.y = 0
				"skater":
					obj = Node3D.new()
					add_child(obj)
					model("skate/skateboard",Vector3(0,0.12,0),Vector3.ONE*3.5,obj)
					var other:=model("skate/character-skate-"+("girl" if int(event.variant)==0 else "boy"),Vector3(0,0.18,0),Vector3.ONE*3.5,obj)
					other.rotation.y=PI/2
					var other_anim:=find_animation(other)
					if other_anim!=null and other_anim.has_animation("skate-stand"):
						other_anim.play("skate-stand")
						other_anim.advance(0)
						other_anim.pause()
					# A warm safety ring makes slower traffic distinct from the player.
					box(Vector3(1.7,0.025,2.8),Vector3(0,0.02,0),Color("dc9b64"),obj)
				_:
					obj = MeshInstance3D.new()
					var mesh := CylinderMesh.new()
					mesh.top_radius = 0.23
					mesh.bottom_radius = 0.23
					mesh.height = 0.09
					obj.mesh = mesh
					obj.material_override = material(Color("ffca58"))
					obj.rotation_degrees.x = 90
					add_child(obj)
			obstacles[key] = obj
		var n: Node3D = obstacles[key]
		n.position = Vector3(float(run.LANES[int(event.lane)]),0.0,-relative)
		n.visible = not (event.kind=="token" and bool(event.used))
		if event.kind == "token":
			n.position.y = 0.8+sin(time*3.0+float(event.d))*0.15
			n.rotation.y = time*2
	for key in obstacles.keys():
		if not visible_keys.has(key):
			obstacles[key].queue_free()
			obstacles.erase(key)
