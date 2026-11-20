extends Node3D

const FLOOR_SIZE := Vector2(34.0, 26.0)
const MODEL_DIR := "res://assets/models/"

var money := 15000
var patients := 4
var treated := 0
var beds := 8
var nurses := 2
var doctors := 1
var day := 1
var patient_models: Array[Node3D] = []
var staff_models: Array[Node3D] = []
var camera: Camera3D
var world: Node3D
var hud: CanvasLayer
var money_text: Label
var patient_text: Label
var staff_text: Label
var message_text: Label
var camera_dragging := false

func _ready() -> void:
	_build_hospital()
	_build_camera()
	_build_interface()
	_spawn_people()
	_refresh_ui()

func _process(delta: float) -> void:
	for i in range(staff_models.size()):
		var actor := staff_models[i]
		if is_instance_valid(actor):
			actor.position.x = sin(Time.get_ticks_msec() * 0.00035 + i) * 0.7 + float(i) * 0.8 - 1.0

func _material(color: Color, roughness := 0.82, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func _box(parent: Node3D, node_name: String, position_3d: Vector3, dimensions: Vector3, color: Color, roughness := 0.82) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	item.mesh = mesh
	item.position = position_3d
	item.material_override = _material(color, roughness)
	parent.add_child(item)
	return item

func _cylinder(parent: Node3D, node_name: String, position_3d: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	item.mesh = mesh
	item.position = position_3d
	item.material_override = _material(color)
	parent.add_child(item)
	return item

func _add_model(file_name: String, at: Vector3, scale_value := Vector3.ONE, yaw := 0.0) -> Node3D:
	var path := MODEL_DIR + file_name
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var instance := packed.instantiate() as Node3D
	if instance == null:
		return null
	instance.position = at
	instance.scale = scale_value
	instance.rotation.y = yaw
	world.add_child(instance)
	return instance

func _build_hospital() -> void:
	world = Node3D.new()
	world.name = "HospitalWorld"
	add_child(world)

	_box(world, "HospitalCampus", Vector3(0, -0.42, 0), Vector3(FLOOR_SIZE.x, 0.8, FLOOR_SIZE.y), Color("aeb9b2"))
	_box(world, "MainBuildingFloor", Vector3(0, 0.04, -1.0), Vector3(25, 0.16, 17), Color("dce3e4"))
	_box(world, "EmergencyFloor", Vector3(-10.4, 0.05, 8.0), Vector3(7.5, 0.18, 7.0), Color("c9d9d8"))
	_box(world, "ParkingFloor", Vector3(11.0, 0.05, 8.0), Vector3(8.0, 0.18, 7.0), Color("646f76"))

	# Room dividers and architectural shell.
	_box(world, "RearWall", Vector3(0, 1.5, -9.4), Vector3(25, 3.0, 0.3), Color("e8eeee"))
	_box(world, "LeftWall", Vector3(-12.4, 1.5, -1.0), Vector3(0.3, 3.0, 17), Color("e8eeee"))
	_box(world, "RightWall", Vector3(12.4, 1.5, -1.0), Vector3(0.3, 3.0, 17), Color("e8eeee"))
	_box(world, "WardDivider", Vector3(-4.2, 1.1, -3.5), Vector3(0.16, 2.2, 7.0), Color("b8c8ca"))
	_box(world, "SurgeryDivider", Vector3(4.0, 1.1, -3.5), Vector3(0.16, 2.2, 7.0), Color("b8c8ca"))
	_box(world, "FrontReceptionWall", Vector3(0, 1.25, 7.2), Vector3(24.8, 2.5, 0.22), Color("edf1ef"))
	_box(world, "ReceptionDesk", Vector3(0, 0.72, 5.9), Vector3(7.0, 1.25, 1.0), Color("426b79"))
	_box(world, "DeskTop", Vector3(0, 1.38, 5.9), Vector3(7.2, 0.12, 1.12), Color("d8e0df"))

	# Eight fully modelled beds, bedside tables, monitors and lights.
	for i in range(8):
		var col := i % 4
		var row := int(i / 4)
		var p := Vector3(-9.2 + float(col) * 2.25, 0.0, -6.6 + float(row) * 3.5)
		_make_bed(p, i + 1)

	# Operating room table and equipment.
	_box(world, "SurgeryTableBase", Vector3(7.7, 0.55, -4.2), Vector3(1.0, 1.0, 2.8), Color("8c999c"))
	_box(world, "SurgeryMattress", Vector3(7.7, 1.12, -4.2), Vector3(1.5, 0.22, 3.0), Color("d9e7e8"))
	_cylinder(world, "SurgicalLamp", Vector3(7.7, 3.0, -5.6), 0.75, 0.12, Color("f5f6e9"))
	_box(world, "MedicalMonitor", Vector3(10.4, 1.5, -5.4), Vector3(0.18, 1.2, 0.9), Color("273d48"))
	_box(world, "MonitorScreen", Vector3(10.28, 1.55, -5.4), Vector3(0.04, 0.72, 0.65), Color("3dba9b"))

	# Emergency bay, ambulance and exterior hospital model if imported.
	_box(world, "AmbulanceBay", Vector3(-10.4, 0.16, 8.0), Vector3(6.7, 0.12, 5.5), Color("e8eeee"))
	_box(world, "AmbulanceStripe", Vector3(-10.4, 0.25, 8.0), Vector3(6.7, 0.04, 0.22), Color("d64e48"))
	_add_model("ambulance.glb", Vector3(-10.4, 0.2, 8.0), Vector3(0.7, 0.7, 0.7), PI)
	_add_model("hospital_exterior.glb", Vector3(0, 0.0, -12.0), Vector3(0.22, 0.22, 0.22))
	_add_model("hospital_ward.glb", Vector3(-8.2, 0.0, -4.8), Vector3(0.42, 0.42, 0.42))
	_add_model("operating_theatre.glb", Vector3(7.8, 0.0, -4.5), Vector3(0.42, 0.42, 0.42))
	_add_model("hospital_corridor.glb", Vector3(0, 0.0, 1.8), Vector3(0.65, 0.65, 0.65), PI / 2.0)

	_make_sign("WARD_SIGN", Vector3(-8.0, 2.5, -8.8), Color("2d8b80"))
	_make_sign("SURGERY_SIGN", Vector3(7.7, 2.5, -8.8), Color("3676a1"))
	_make_sign("EMERGENCY_SIGN", Vector3(-10.4, 2.2, 4.2), Color("d94f49"))

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_energy = 1.25
	world.add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 8, 2)
	fill.omni_range = 30
	fill.light_energy = 1.0
	world.add_child(fill)
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("8fa4aa")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("dce7e8")
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env_node.environment = env
	world.add_child(env_node)

func _make_bed(at: Vector3, number: int) -> void:
	_box(world, "BedFrame_%d" % number, at + Vector3(0, 0.32, 0), Vector3(1.35, 0.42, 2.15), Color("8b989e"))
	_box(world, "Mattress_%d" % number, at + Vector3(0, 0.58, 0), Vector3(1.27, 0.16, 2.02), Color("c5e0e7"))
	_box(world, "Pillow_%d" % number, at + Vector3(0, 0.72, -0.72), Vector3(0.86, 0.12, 0.4), Color("f7f8f7"))
	_box(world, "BedHead_%d" % number, at + Vector3(0, 0.92, -1.08), Vector3(1.35, 0.9, 0.12), Color("dce4e5"))
	_box(world, "BedsideTable_%d" % number, at + Vector3(0.98, 0.42, -0.6), Vector3(0.52, 0.8, 0.55), Color("d6dedb"))
	_box(world, "MonitorStand_%d" % number, at + Vector3(0.98, 1.25, -1.0), Vector3(0.08, 0.9, 0.08), Color("71858b"))
	_box(world, "Monitor_%d" % number, at + Vector3(0.98, 1.75, -1.0), Vector3(0.12, 0.58, 0.72), Color("29424b"))
	_box(world, "MonitorGlow_%d" % number, at + Vector3(0.9, 1.76, -1.0), Vector3(0.025, 0.38, 0.52), Color("48bfa4"))

func _make_sign(sign_name: String, at: Vector3, color: Color) -> void:
	_box(world, sign_name, at, Vector3(3.2, 0.6, 0.16), color)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "TopDownCamera"
	camera.position = Vector3(0, 28, 25)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 34
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0, 0, 0), Vector3.UP)

func _spawn_people() -> void:
	for i in range(patients):
		_spawn_patient(i)
	for i in range(nurses):
		_spawn_staff("nurse.glb", Vector3(-2.0 + i * 1.5, 0, 3.7), i)
	_spawn_staff("doctor.glb", Vector3(4.5, 0, 2.8), 9)

func _spawn_patient(index: int) -> void:
	var model_name := "patient_male.glb" if index % 2 == 0 else "patient_female.glb"
	var at := Vector3(-8.5 + float(index % 4) * 2.2, 0, 2.2 + float(int(index / 4)) * 1.3)
	var person := _add_model(model_name, at, Vector3(0.78, 0.78, 0.78))
	if person == null:
		person = _make_placeholder_person(at, Color("d5a77d") if index % 2 == 0 else Color("b98572"))
	if person != null:
		person.name = "Patient_%d" % index
		patient_models.append(person)

func _spawn_staff(model_name: String, at: Vector3, index: int) -> void:
	var person := _add_model(model_name, at, Vector3(0.8, 0.8, 0.8))
	if person == null:
		person = _make_placeholder_person(at, Color("e9eeee"))
	if person != null:
		person.name = "Staff_%d" % index
		staff_models.append(person)

func _make_placeholder_person(at: Vector3, uniform_color: Color) -> Node3D:
	var person := Node3D.new()
	person.position = at
	world.add_child(person)
	_box(person, "Body", Vector3(0, 0.95, 0), Vector3(0.58, 1.15, 0.34), uniform_color)
	_cylinder(person, "Head", Vector3(0, 1.72, 0), 0.23, 0.42, Color("c99575"))
	return person

func _build_interface() -> void:
	hud = CanvasLayer.new()
	add_child(hud)

	var top := PanelContainer.new()
	top.position = Vector2(14, 12)
	top.size = Vector2(430, 142)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.075, 0.095, 0.94)
	panel_style.set_corner_radius_all(14)
	panel_style.set_content_margin_all(12)
	top.add_theme_stylebox_override("panel", panel_style)
	hud.add_child(top)

	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 5)
	top.add_child(stats)
	var heading := Label.new()
	heading.text = "مستشفى المدينة  |  اليوم 1"
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", Color("ffffff"))
	stats.add_child(heading)
	money_text = _label(stats)
	patient_text = _label(stats)
	staff_text = _label(stats)

	message_text = Label.new()
	message_text.position = Vector2(470, 22)
	message_text.size = Vector2(760, 45)
	message_text.add_theme_font_size_override("font_size", 18)
	message_text.add_theme_color_override("font_color", Color("173e48"))
	hud.add_child(message_text)

	var actions := HBoxContainer.new()
	actions.position = Vector2(14, 585)
	actions.add_theme_constant_override("separation", 8)
	hud.add_child(actions)
	_button(actions, "علاج مريض", _treat_patient)
	_button(actions, "شراء سرير", _buy_bed)
	_button(actions, "توظيف ممرض", _hire_nurse)
	_button(actions, "اليوم التالي", _next_day)

	var zoom_plus := Button.new()
	zoom_plus.text = "+"
	zoom_plus.position = Vector2(1190, 510)
	zoom_plus.size = Vector2(64, 58)
	zoom_plus.pressed.connect(func(): camera.size = maxf(19.0, camera.size - 2.0))
	hud.add_child(zoom_plus)
	var zoom_minus := Button.new()
	zoom_minus.text = "−"
	zoom_minus.position = Vector2(1190, 574)
	zoom_minus.size = Vector2(64, 58)
	zoom_minus.pressed.connect(func(): camera.size = minf(46.0, camera.size + 2.0))
	hud.add_child(zoom_minus)

	var hint := Label.new()
	hint.text = "اسحب الشاشة لتحريك الكاميرا  •  استخدم + و − للتقريب"
	hint.position = Vector2(16, 690)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color("183b45"))
	hud.add_child(hint)

func _label(parent: Node) -> Label:
	var item := Label.new()
	item.add_theme_font_size_override("font_size", 17)
	item.add_theme_color_override("font_color", Color("eaf3f3"))
	parent.add_child(item)
	return item

func _button(parent: Node, caption: String, action: Callable) -> void:
	var item := Button.new()
	item.text = caption
	item.custom_minimum_size = Vector2(160, 58)
	item.add_theme_font_size_override("font_size", 17)
	item.pressed.connect(action)
	parent.add_child(item)

func _refresh_ui() -> void:
	if money_text == null:
		return
	money_text.text = "الميزانية: $%d" % money
	patient_text.text = "المرضى: %d / الأسرّة: %d  |  المعالَجون: %d" % [patients, beds, treated]
	staff_text.text = "الممرضون: %d  |  الأطباء: %d" % [nurses, doctors]

func _notify(message: String) -> void:
	message_text.text = message

func _treat_patient() -> void:
	if patients <= 0:
		_notify("لا يوجد مريض ينتظر العلاج حالياً.")
		return
	patients -= 1
	treated += 1
	money += 250
	if patient_models.size() > 0:
		var patient = patient_models.pop_front()
		if is_instance_valid(patient):
			patient.queue_free()
	_notify("تم علاج المريض بنجاح! أضيفت 250 دولار إلى الميزانية.")
	_refresh_ui()

func _buy_bed() -> void:
	if money < 500:
		_notify("الميزانية لا تكفي لشراء سرير.")
		return
	money -= 500
	beds += 1
	var slot := beds - 1
	var at := Vector3(-9.2 + float(slot % 4) * 2.25, 0, -6.6 + float(int(slot / 4)) * 3.5)
	_make_bed(at, beds)
	_notify("تم تجهيز سرير جديد في جناح الرقود.")
	_refresh_ui()

func _hire_nurse() -> void:
	if money < 800:
		_notify("الميزانية لا تكفي لتوظيف ممرض.")
		return
	money -= 800
	nurses += 1
	_spawn_staff("nurse.glb", Vector3(-2.0 + nurses * 1.4, 0, 3.7), nurses)
	_notify("تم تعيين ممرض جديد.")
	_refresh_ui()

func _next_day() -> void:
	day += 1
	var income := treated * 100 + nurses * 60 + doctors * 100
	money += income
	var arrivals := mini(2 + day % 3, maxi(0, beds - patients))
	for i in range(arrivals):
		_spawn_patient(patient_models.size() + treated + i)
	patients += arrivals
	_notify("بدأ اليوم %d. دخل المستشفى اليومي: $%d." % [day, income])
	_refresh_ui()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		camera_dragging = event.pressed
	elif event is InputEventScreenDrag and camera_dragging:
		_pan_camera(event.relative)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = maxf(19.0, camera.size - 1.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(46.0, camera.size + 1.5)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_pan_camera(event.relative)

func _pan_camera(relative: Vector2) -> void:
	camera.position.x -= relative.x * 0.035
	camera.position.z -= relative.y * 0.035
	camera.position.x = clampf(camera.position.x, -15.0, 15.0)
	camera.position.z = clampf(camera.position.z, 12.0, 38.0)
	camera.look_at(Vector3(camera.position.x, 0, camera.position.z - 25), Vector3.UP)
