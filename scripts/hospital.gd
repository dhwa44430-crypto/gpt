extends Node3D

var money := 12000
var patients := 3
var treated := 0
var beds := 6
var nurses := 2
var day := 1
var patient_nodes: Array[Node3D] = []
var staff_nodes: Array[Node3D] = []
var hud: CanvasLayer
var status_label: Label
var money_label: Label
var bed_label: Label
var nurse_label: Label
var camera: Camera3D
var world_root: Node3D
var selected_action := ""

func _ready() -> void:
	_build_world()
	_build_camera()
	_build_hud()
	_spawn_patients()
	_spawn_staff()
	_update_hud()

func _process(delta: float) -> void:
	for i in range(staff_nodes.size()):
		var staff := staff_nodes[i]
		staff.position.z += delta * (0.35 + float(i % 2) * 0.12)
		if staff.position.z > 4.0:
			staff.position.z = -2.0

func _mat(color: Color, roughness := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

func _box(parent: Node3D, name: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = _mat(color)
	parent.add_child(node)
	return node

func _cylinder(parent: Node3D, name: String, pos: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	node.mesh = mesh
	node.position = pos
	node.material_override = _mat(color)
	parent.add_child(node)
	return node

func _add_model(file_name: String, model_position: Vector3, model_scale := Vector3.ONE, yaw := 0.0) -> Node3D:
	var model_path := "res://assets/models/" + file_name
	var packed := load(model_path) as PackedScene
	if packed == null:
		push_error("Missing imported 3D model: " + model_path)
		return null
	var instance := packed.instantiate() as Node3D
	instance.position = model_position
	instance.scale = model_scale
	instance.rotation.y = yaw
	world_root.add_child(instance)
	return instance

func _add_character(file_name: String, character_position: Vector3, character_scale := 1.0, animation_name := "idle") -> Node3D:
	var character := _add_model(file_name, character_position, Vector3.ONE * character_scale)
	if character == null:
		return null
	var players := character.find_children("*", "AnimationPlayer", true, false)
	if players.size() > 0:
		var animation_player := players[0] as AnimationPlayer
		for animation in animation_player.get_animation_list():
			if String(animation).to_lower().contains(animation_name.to_lower()):
				animation_player.play(animation)
				break
	return character

func _spawn_staff() -> void:
	for i in range(nurses):
		var nurse := _add_character("nurse.glb", Vector3(-4.0 + float(i) * 1.3, 0.0, -1.0), 1.0, "walk")
		if nurse != null:
			nurse.name = "Nurse_%d" % i
			staff_nodes.append(nurse)
	var doctor := _add_character("doctor.glb", Vector3(5.0, 0.0, -0.5), 1.0, "walk")
	if doctor != null:
		doctor.name = "Doctor"
		staff_nodes.append(doctor)

func _build_world() -> void:
	world_root = Node3D.new()
	world_root.name = "DetailedHospital"
	add_child(world_root)

	# Real textured CC0 GLB environments, not procedural box substitutes.
	_add_model("hospital_ward.glb", Vector3(-5.0, 0.0, -3.0))
	_add_model("operating_theatre.glb", Vector3(5.0, 0.0, -3.0))
	_add_model("hospital_corridor.glb", Vector3(0.0, 0.0, 3.2), Vector3(1.25, 1.0, 1.0), PI / 2.0)
	_add_model("ambulance.glb", Vector3(9.0, 0.0, 8.0), Vector3(0.65, 0.65, 0.65), PI / 2.0)
	_add_model("hospital_exterior.glb", Vector3(-12.0, 0.0, 7.0), Vector3(0.34, 0.34, 0.34))

	var ground := _box(world_root, "HospitalGround", Vector3(0, -0.35, 2.0), Vector3(32, 0.5, 25), Color("aab7b1"))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	light.light_energy = 1.4
	world_root.add_child(light)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d8e4ed")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.ssil_enabled = true
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.18
	env.glow_strength = 0.35
	env.glow_bloom = 0.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	environment.environment = env
	world_root.add_child(environment)

func _make_bed(pos: Vector3) -> void:
	_box(world_root, "BedFrame", pos + Vector3(0, 0.32, 0), Vector3(1.45, 0.48, 2.15), Color("f7f8fa"))
	_box(world_root, "Mattress", pos + Vector3(0, 0.59, 0), Vector3(1.32, 0.12, 1.98), Color("b8d8e8"))
	_box(world_root, "Pillow", pos + Vector3(0, 0.7, -0.72), Vector3(0.85, 0.13, 0.42), Color("ffffff"))
	_box(world_root, "BedLeg", pos + Vector3(0, 0.12, 0), Vector3(1.2, 0.18, 1.9), Color("9caab2"))

func _make_sign(label_text: String, pos: Vector3, color: Color) -> void:
	_box(world_root, label_text + "_Sign", pos, Vector3(3.2, 0.55, 0.16), color)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.position = Vector3(13, 25, 22)
	camera.look_at(Vector3(0, 0, 0), Vector3.UP)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 29
	add_child(camera)
	camera.current = true

func _spawn_patients() -> void:
	_spawn_new_patient_nodes(patients)

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 16)
	panel.size = Vector2(370, 128)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.075, 0.11, 0.94)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	panel.add_theme_stylebox_override("panel", style)
	hud.add_child(panel)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 5)
	panel.add_child(info)
	var title := Label.new()
	title.text = "CITY HOSPITAL  |  DAY 1"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("ffffff"))
	info.add_child(title)
	money_label = _new_label(info)
	bed_label = _new_label(info)
	nurse_label = _new_label(info)
	var actions := HBoxContainer.new()
	actions.position = Vector2(18, 590)
	actions.add_theme_constant_override("separation", 10)
	hud.add_child(actions)
	_add_button(actions, "علاج مريض  +$250", _treat_patient)
	_add_button(actions, "شراء سرير  -$500", _buy_bed)
	_add_button(actions, "توظيف ممرض  -$800", _hire_nurse)
	_add_button(actions, "اليوم التالي", _next_day)
	status_label = Label.new()
	status_label.position = Vector2(420, 22)
	status_label.size = Vector2(700, 42)
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color("183c4b"))
	hud.add_child(status_label)
	var hint := Label.new()
	hint.text = "اسحب بإصبعك لتحريك الكاميرا • استخدم زري + و - للتقريب"
	hint.position = Vector2(18, 685)
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color("243b46"))
	hud.add_child(hint)
	var zoom_in := Button.new()
	zoom_in.text = "+"
	zoom_in.position = Vector2(1190, 530)
	zoom_in.size = Vector2(58, 54)
	zoom_in.pressed.connect(func(): camera.size = maxf(16, camera.size - 2))
	hud.add_child(zoom_in)
	var zoom_out := Button.new()
	zoom_out.text = "-"
	zoom_out.position = Vector2(1190, 590)
	zoom_out.size = Vector2(58, 54)
	zoom_out.pressed.connect(func(): camera.size = minf(38, camera.size + 2))
	hud.add_child(zoom_out)

func _new_label(parent: Node) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", Color("e9f4f7"))
	parent.add_child(l)
	return l

func _add_button(parent: Node, caption: String, callback: Callable) -> void:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size = Vector2(190, 54)
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(callback)
	parent.add_child(b)

func _update_hud() -> void:
	if money_label == null:
		return
	money_label.text = "💰 الميزانية: $%d" % money
	bed_label.text = "🛏 الأسرّة: %d   |   المرضى: %d" % [beds, patients]
	nurse_label.text = "👩‍⚕️ الممرضون: %d   |   الحالات المعالجة: %d" % [nurses, treated]

func _treat_patient() -> void:
	if patients <= 0:
		status_label.text = "لا يوجد مرضى يحتاجون العلاج حالياً."
		return
	patients -= 1
	treated += 1
	money += 250
	if patient_nodes.size() > 0:
		var p = patient_nodes.pop_front()
		p.queue_free()
	status_label.text = "تم علاج مريض بنجاح! حصلت على 250 دولار."
	_update_hud()

func _buy_bed() -> void:
	if money < 500:
		status_label.text = "الميزانية لا تكفي لشراء سرير."
		return
	money -= 500
	beds += 1
	_make_bed(Vector3(3.4 + float((beds - 7) % 2) * 3.2, 0, -6.4 + float((beds - 7) / 2) * 3.0))
	status_label.text = "تمت إضافة سرير جديد إلى جناح الرقود."
	_update_hud()

func _hire_nurse() -> void:
	if money < 800:
		status_label.text = "الميزانية لا تكفي لتوظيف ممرض."
		return
	money -= 800
	nurses += 1
	var nurse := _add_character("nurse.glb", Vector3(-4.0 + float(nurses - 1) * 1.3, 0.0, -1.0), 1.0, "walk")
	if nurse != null:
		nurse.name = "Nurse_%d" % nurses
		staff_nodes.append(nurse)
	status_label.text = "تم توظيف ممرض جديد. كفاءة المستشفى ارتفعت."
	_update_hud()

func _next_day() -> void:
	day += 1
	var income := treated * 100 + nurses * 40
	money += income
	var new_patients := mini(3 + day, beds - patients)
	patients += maxi(0, new_patients)
	_spawn_new_patient_nodes(maxi(0, new_patients))
	status_label.text = "بدأ اليوم %d. دخل المستشفى اليومي: $%d" % [day, income]
	_update_hud()

func _spawn_new_patient_nodes(amount: int) -> void:
	for i in range(amount):
		var patient_index := patient_nodes.size()
		var model_file := "patient_male.glb" if patient_index % 2 == 0 else "patient_female.glb"
		var x_position := -8.0 + float(patient_index % 5) * 1.7
		var z_position := 2.2 + float(patient_index / 5) * 1.5
		var patient := _add_character(model_file, Vector3(x_position, 0.0, z_position), 1.0, "idle")
		if patient != null:
			patient.name = "Patient_%d" % patient_index
			patient_nodes.append(patient)

var drag_start := Vector2.ZERO
var dragging := false

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			drag_start = event.position
			dragging = true
		else:
			dragging = false
	elif event is InputEventScreenDrag and dragging:
		camera.position.x -= event.relative.x * 0.025
		camera.position.z -= event.relative.y * 0.025
		camera.look_at(Vector3(camera.position.x - 0.7, 0, camera.position.z - 0.7), Vector3.UP)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = maxf(16, camera.size - 1.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(38, camera.size + 1.5)
