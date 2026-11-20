extends Node2D

const HERO_TEXTURE = preload("res://assets/images/hero/hero_spritesheet.webp")
const WORLD_TEXTURE = preload("res://assets/images/world/world_atlas.webp")

const GRAVITY := 1500.0
const RUN_SPEED := 340.0
const JUMP_SPEED := -610.0
const LEVEL_LENGTHS := [2300.0, 2500.0, 2700.0]
const LEVEL_COLORS := [Color("#72d6f2"), Color("#ffc078"), Color("#536dab")]

var player: CharacterBody2D
var hero_sprite: Sprite2D
var camera: Camera2D
var hud: Label
var message_panel: Panel
var message_label: Label
var left_button: Button
var right_button: Button
var jump_button: Button
var coins := 0
var lives := 3
var level_index := 0
var started := false
var ended := false
var facing_right := true
var collected := 0
var enemies: Array[Area2D] = []
var coin_nodes: Array[Area2D] = []
var world_root: Node2D
var time_passed := 0.0

func _ready() -> void:
    _make_world()
    _make_player()
    _make_ui()
    _show_message("مغامرات البطل", "اجمع العملات، اقفز فوق الأعداء، واعبر المراحل!", "ابدأ اللعب")
    get_viewport().size_changed.connect(_fit_ui)

func _process(delta: float) -> void:
    time_passed += delta
    if started and not ended:
        _animate_hero()
        _move_enemies()
        _update_camera()
    queue_redraw()

func _physics_process(delta: float) -> void:
    if not started or ended or player == null:
        return
    var direction := Input.get_axis("move_left", "move_right")
    if left_button != null and left_button.is_pressed():
        direction -= 1.0
    if right_button != null and right_button.is_pressed():
        direction += 1.0
    direction = clampf(direction, -1.0, 1.0)
    player.velocity.x = direction * RUN_SPEED
    if direction != 0.0:
        facing_right = direction > 0.0
        hero_sprite.flip_h = not facing_right
    if (Input.is_action_just_pressed("jump") or (jump_button != null and jump_button.is_pressed())) and player.is_on_floor():
        player.velocity.y = JUMP_SPEED
    if not player.is_on_floor():
        player.velocity.y += GRAVITY * delta
    player.move_and_slide()
    player.global_position.x = clampf(player.global_position.x, 24.0, LEVEL_LENGTHS[level_index] - 24.0)
    if player.global_position.y > 900.0:
        _hurt()
    _check_goal()
    _update_hud()

func _draw() -> void:
    var sky := LEVEL_COLORS[level_index]
    draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), sky)
    var w := get_viewport_rect().size.x
    for i in range(-1, 5):
        var x := float(i) * 675.0 - fmod(camera.position.x * 0.22, 675.0)
        var bg_row := level_index
        _atlas_piece(2, bg_row, Rect2(x, 0, 675, 450))
        _atlas_piece(3, 0, Rect2(x + 275, 275, 112, 150))
        _atlas_piece(2, 3, Rect2(x + 35, 355, 95, 65))
    draw_rect(Rect2(0, get_viewport_rect().size.y - 18, w, 18), Color("#182a38"))

func _atlas_piece(col: int, row: int, destination: Rect2) -> void:
    if WORLD_TEXTURE == null:
        return
    var source := Rect2(float(col) * 40.0, float(row) * 22.5, 40.0, 22.5)
    draw_texture_rect_region(WORLD_TEXTURE, destination, source)

func _make_world() -> void:
    world_root = Node2D.new()
    world_root.name = "Level"
    add_child(world_root)
    var platforms: Array = []
    if level_index == 0:
        platforms = [[0, 590, 390], [680, 1070, 390], [1170, 1580, 390], [1680, 2300, 390], [300, 410, 300], [760, 890, 315], [1230, 1360, 300], [1800, 1940, 310]]
    elif level_index == 1:
        platforms = [[0, 400, 390], [500, 900, 390], [1000, 1420, 390], [1510, 1900, 390], [2000, 2500, 390], [280, 410, 300], [690, 820, 290], [1150, 1280, 305], [1630, 1760, 285], [2140, 2270, 300]]
    else:
        platforms = [[0, 450, 390], [550, 900, 390], [1000, 1380, 390], [1480, 1900, 390], [2000, 2700, 390], [300, 430, 295], [700, 840, 280], [1120, 1250, 285], [1600, 1730, 275], [2180, 2330, 285]]
    for p in platforms:
        _add_platform(float(p[0]), float(p[1]), float(p[2]))
    _add_coins()
    _add_enemies()
    _add_goal()

func _add_platform(x: float, end_x: float, y: float) -> void:
    var width := end_x - x
    var body := StaticBody2D.new()
    body.position = Vector2(x + width / 2.0, y + 28.0)
    world_root.add_child(body)
    var shape := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size = Vector2(width, 56.0)
    shape.shape = rect
    body.add_child(shape)
    var sprite := Sprite2D.new()
    sprite.texture = WORLD_TEXTURE
    sprite.region_enabled = true
    sprite.region_rect = Rect2(0, float(level_index) * 22.5, 40, 22.5)
    sprite.position = Vector2(0, -5)
    sprite.scale = Vector2(width / 40.0, 2.65)
    body.add_child(sprite)

func _add_coins() -> void:
    var positions := [Vector2(330, 255), Vector2(380, 255), Vector2(790, 270), Vector2(840, 270), Vector2(1120, 340), Vector2(1260, 255), Vector2(1310, 255), Vector2(1660, 340), Vector2(1840, 265), Vector2(1890, 265), Vector2(2070, 340)]
    for pos in positions:
        var coin := Area2D.new()
        coin.position = pos
        coin.add_to_group("coins")
        var sprite := Sprite2D.new()
        sprite.texture = WORLD_TEXTURE
        sprite.region_enabled = true
        sprite.region_rect = Rect2(0, 0, 40, 22.5)
        sprite.scale = Vector2(0.75, 1.5)
        coin.add_child(sprite)
        var hit := CollisionShape2D.new()
        var circle := CircleShape2D.new()
        circle.radius = 23
        hit.shape = circle
        coin.add_child(hit)
        coin.body_entered.connect(_on_coin_touched.bind(coin))
        world_root.add_child(coin)
        coin_nodes.append(coin)

func _add_enemies() -> void:
    var positions := [Vector2(500, 350), Vector2(940, 350), Vector2(1450, 350), Vector2(1980, 350)]
    for pos in positions:
        var enemy := Area2D.new()
        enemy.position = pos
        enemy.set_meta("origin_x", pos.x)
        enemy.set_meta("phase", randf() * TAU)
        var sprite := Sprite2D.new()
        sprite.texture = WORLD_TEXTURE
        sprite.region_enabled = true
        sprite.region_rect = Rect2(80, 67.5, 40, 22.5)
        sprite.scale = Vector2(1.35, 2.0)
        enemy.add_child(sprite)
        var hit := CollisionShape2D.new()
        var shape := RectangleShape2D.new()
        shape.size = Vector2(42, 34)
        hit.shape = shape
        enemy.add_child(hit)
        enemy.body_entered.connect(_on_enemy_touched.bind(enemy))
        world_root.add_child(enemy)
        enemies.append(enemy)

func _add_goal() -> void:
    var goal := Sprite2D.new()
    goal.texture = WORLD_TEXTURE
    goal.region_enabled = true
    goal.region_rect = Rect2(40, 67.5, 40, 22.5)
    goal.position = Vector2(LEVEL_LENGTHS[level_index] - 70, 330)
    goal.scale = Vector2(1.9, 5.2)
    world_root.add_child(goal)

func _make_player() -> void:
    player = CharacterBody2D.new()
    player.name = "AnimeHero"
    player.position = Vector2(90, 300)
    var collision := CollisionShape2D.new()
    var capsule := CapsuleShape2D.new()
    capsule.radius = 13
    capsule.height = 52
    collision.shape = capsule
    player.add_child(collision)
    hero_sprite = Sprite2D.new()
    hero_sprite.texture = HERO_TEXTURE
    hero_sprite.hframes = 3
    hero_sprite.vframes = 2
    hero_sprite.frame = 0
    player.add_child(hero_sprite)
    add_child(player)
    camera = Camera2D.new()
    camera.position_smoothing_enabled = true
    camera.position_smoothing_speed = 7.0
    camera.limit_left = 0
    camera.limit_right = int(LEVEL_LENGTHS[level_index])
    camera.limit_top = 0
    camera.limit_bottom = 720
    player.add_child(camera)
    camera.make_current()

func _make_ui() -> void:
    var layer := CanvasLayer.new()
    layer.name = "TouchUI"
    add_child(layer)
    hud = Label.new()
    hud.position = Vector2(24, 18)
    hud.add_theme_font_size_override("font_size", 26)
    hud.add_theme_color_override("font_color", Color.WHITE)
    layer.add_child(hud)
    left_button = _make_button(layer, "◀", Vector2(28, 590), Vector2(92, 92), "move_left")
    right_button = _make_button(layer, "▶", Vector2(132, 590), Vector2(92, 92), "move_right")
    jump_button = _make_button(layer, "قفز", Vector2(1120, 575), Vector2(125, 105), "jump")
    message_panel = Panel.new()
    message_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    message_panel.position = Vector2(-250, -150)
    message_panel.size = Vector2(500, 300)
    layer.add_child(message_panel)
    var box := VBoxContainer.new()
    box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    box.add_theme_constant_override("separation", 16)
    message_panel.add_child(box)
    message_label = Label.new()
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    message_label.add_theme_font_size_override("font_size", 25)
    message_label.add_theme_color_override("font_color", Color.WHITE)
    box.add_child(message_label)
    var start_button := Button.new()
    start_button.text = "ابدأ اللعب"
    start_button.custom_minimum_size = Vector2(220, 58)
    start_button.add_theme_font_size_override("font_size", 23)
    start_button.pressed.connect(_start_or_restart)
    box.add_child(start_button)
    _fit_ui()

func _make_button(parent: Node, caption: String, pos: Vector2, size: Vector2, action: String) -> Button:
    var b := Button.new()
    b.text = caption
    b.position = pos
    b.size = size
    b.add_theme_font_size_override("font_size", 30)
    b.button_down.connect(func(): Input.action_press(action))
    b.button_up.connect(func(): Input.action_release(action))
    parent.add_child(b)
    return b

func _fit_ui() -> void:
    if message_panel != null:
        message_panel.position = get_viewport_rect().size / 2.0 - message_panel.size / 2.0
    if jump_button != null:
        jump_button.position.x = get_viewport_rect().size.x - 160

func _show_message(title: String, body: String, button_text: String) -> void:
    message_label.text = title + "\n" + body
    var b := message_panel.get_child(0).get_child(1) as Button
    b.text = button_text
    message_panel.visible = true

func _start_or_restart() -> void:
    if ended:
        level_index = 0
        coins = 0
        lives = 3
        _load_level()
    started = true
    ended = false
    message_panel.visible = false
    _update_hud()

func _load_level() -> void:
    if world_root != null:
        world_root.queue_free()
    for e in enemies:
        if is_instance_valid(e): e.queue_free()
    for c in coin_nodes:
        if is_instance_valid(c): c.queue_free()
    enemies.clear()
    coin_nodes.clear()
    level_index = mini(level_index, LEVEL_LENGTHS.size() - 1)
    _make_world()
    camera.limit_right = int(LEVEL_LENGTHS[level_index])
    player.position = Vector2(90, 300)
    player.velocity = Vector2.ZERO

func _on_coin_touched(body: Node2D, coin: Area2D) -> void:
    if body != player or not is_instance_valid(coin):
        return
    coins += 1
    coin.queue_free()
    coin_nodes.erase(coin)
    _update_hud()

func _on_enemy_touched(body: Node2D, enemy: Area2D) -> void:
    if body != player or not is_instance_valid(enemy) or ended:
        return
    if player.velocity.y > 100 and player.global_position.y < enemy.global_position.y - 8:
        enemy.queue_free()
        enemies.erase(enemy)
        player.velocity.y = JUMP_SPEED * 0.55
        coins += 2
    else:
        _hurt()

func _move_enemies() -> void:
    for enemy in enemies:
        if is_instance_valid(enemy):
            var origin := float(enemy.get_meta("origin_x"))
            var phase := float(enemy.get_meta("phase"))
            enemy.position.x = origin + sin(time_passed * 1.7 + phase) * 48.0

func _animate_hero() -> void:
    if not player.is_on_floor():
        hero_sprite.frame = 4 if player.velocity.y < 0 else 5
    elif absf(player.velocity.x) > 15:
        hero_sprite.frame = 1 + (int(time_passed * 8.0) % 3)
    else:
        hero_sprite.frame = 0

func _update_camera() -> void:
    if camera:
        camera.position.x = clampf(player.position.x, 500.0, LEVEL_LENGTHS[level_index] - 500.0)

func _check_goal() -> void:
    if player.position.x >= LEVEL_LENGTHS[level_index] - 100.0:
        if level_index < LEVEL_LENGTHS.size() - 1:
            level_index += 1
            _load_level()
        else:
            ended = true
            started = false
            _show_message("فزت يا بطل!", "أنهيت المراحل وجمعت %d عملة!" % coins, "العب من جديد")

func _hurt() -> void:
    lives -= 1
    if lives <= 0:
        ended = true
        started = false
        _show_message("انتهت المحاولة", "لا تستسلم! حاول من جديد.", "العب من جديد")
    else:
        player.position = Vector2(maxf(40.0, player.position.x - 110.0), 300)
        player.velocity = Vector2.ZERO
    _update_hud()

func _update_hud() -> void:
    if hud:
        hud.text = "المرحلة %d   🪙 %d   ♥ %d" % [level_index + 1, coins, lives]
