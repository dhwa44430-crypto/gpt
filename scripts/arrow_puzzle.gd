extends Node2D

const GRID := 7
const CELL := 62.0
const BOARD_ORIGIN := Vector2(0, 0)
const BG := Color("#101827")
const PANEL := Color("#1b2940")
const INK := Color("#f4f7ff")
const COLORS := [Color("#ff647c"), Color("#ffb84d"), Color("#54d6c5"), Color("#8e9cff"), Color("#c58cff"), Color("#f0d45b"), Color("#61b8ff")]

var level := 1
var removed := 0
var moves := 0
var arrows: Array[Dictionary] = []
var board_rect := Rect2()
var status_text := "اضغط على السهم حتى يخرج من اللوحة"
var hint_text := ""
var game_won := false
var touch_start := Vector2.ZERO
var undo_stack: Array = []

func _ready() -> void:
    get_viewport().size_changed.connect(_on_resize)
    _new_level()

func _on_resize() -> void:
    queue_redraw()

func _board_size() -> float:
    return minf(get_viewport_rect().size.x - 28.0, get_viewport_rect().size.y * 0.58)

func _cell_size() -> float:
    return _board_size() / float(GRID)

func _board_origin() -> Vector2:
    var s := _board_size()
    return Vector2((get_viewport_rect().size.x - s) * 0.5, get_viewport_rect().size.y * 0.22)

func _new_level() -> void:
    arrows.clear()
    removed = 0
    moves = 0
    game_won = false
    hint_text = ""
    status_text = "اختر سهماً طريقه خالٍ ليخرج"
    var rng := RandomNumberGenerator.new()
    rng.seed = 8917 + level * 7919
    var density := minf(0.58 + float(level) * 0.018, 0.78)
    var cells: Array[Vector2i] = []
    for y in range(GRID):
        for x in range(GRID):
            if rng.randf() < density:
                cells.append(Vector2i(x, y))
    # Every arrow points toward its nearest board edge, so each level has a valid solution.
    for p in cells:
        var distances := [p.x, GRID - 1 - p.x, p.y, GRID - 1 - p.y]
        var min_d := mini(mini(distances[0], distances[1]), mini(distances[2], distances[3]))
        var choices: Array[Vector2i] = []
        if distances[0] == min_d: choices.append(Vector2i(-1, 0))
        if distances[1] == min_d: choices.append(Vector2i(1, 0))
        if distances[2] == min_d: choices.append(Vector2i(0, -1))
        if distances[3] == min_d: choices.append(Vector2i(0, 1))
        var direction: Vector2i = choices[rng.randi_range(0, choices.size() - 1)]
        arrows.append({"cell": p, "dir": direction, "color": COLORS[rng.randi_range(0, COLORS.size() - 1)], "alive": true})
    undo_stack.clear()
    queue_redraw()

func _process(_delta: float) -> void:
    queue_redraw()

func _draw() -> void:
    var size := get_viewport_rect().size
    draw_rect(Rect2(Vector2.ZERO, size), BG)
    _draw_header(size)
    _draw_board()
    _draw_footer(size)

func _draw_header(size: Vector2) -> void:
    draw_string(ThemeDB.fallback_font, Vector2(20, 42), "ARROW ESCAPE", HORIZONTAL_ALIGNMENT_CENTER, size.x - 40, 25, INK)
    draw_string(ThemeDB.fallback_font, Vector2(20, 76), "المستوى %d     الأسهم المتبقية: %d" % [level, _remaining()], HORIZONTAL_ALIGNMENT_CENTER, size.x - 40, 18, Color("#b9c8df"))
    var bar := Rect2(24, 92, size.x - 48, 7)
    draw_rect(bar, Color("#293851"), true, 5)
    if arrows.size() > 0:
        draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(removed) / float(arrows.size()), 7)), Color("#54d6c5"), true, 5)

func _draw_board() -> void:
    var cell := _cell_size()
    var origin := _board_origin()
    var board := Rect2(origin - Vector2(7, 7), Vector2(cell * GRID + 14, cell * GRID + 14))
    draw_rect(board, PANEL, true, 18)
    for y in range(GRID):
        for x in range(GRID):
            var r := Rect2(origin + Vector2(x, y) * cell + Vector2(2, 2), Vector2(cell - 4, cell - 4))
            draw_rect(r, Color("#25354d"), true, 9)
    for a in arrows:
        if a.alive:
            _draw_arrow(origin + (Vector2(a.cell) + Vector2(0.5, 0.5)) * cell, a.dir, cell * 0.36, a.color)

func _draw_arrow(center: Vector2, direction: Vector2i, length: float, color: Color) -> void:
    var d := Vector2(direction).normalized()
    var side := Vector2(-d.y, d.x)
    var tip := center + d * length
    var base := center - d * length * 0.72
    var head_base := center + d * length * 0.05
    var points := PackedVector2Array([
        base + side * length * 0.22,
        head_base + side * length * 0.22,
        head_base + side * length * 0.52,
        tip,
        head_base - side * length * 0.52,
        head_base - side * length * 0.22,
        base - side * length * 0.22
    ])
    draw_colored_polygon(points, color)
    draw_polyline(points + PackedVector2Array([points[0]]), Color(1, 1, 1, 0.28), 1.5, true)

func _draw_footer(size: Vector2) -> void:
    var y := size.y - 104
    draw_string(ThemeDB.fallback_font, Vector2(18, y), status_text, HORIZONTAL_ALIGNMENT_CENTER, size.x - 36, 17, INK)
    if not hint_text.is_empty():
        draw_string(ThemeDB.fallback_font, Vector2(18, y + 25), hint_text, HORIZONTAL_ALIGNMENT_CENTER, size.x - 36, 15, Color("#ffcf70"))
    _draw_button(Rect2(18, size.y - 65, size.x * 0.28, 46), "تراجع")
    _draw_button(Rect2(size.x * 0.36, size.y - 65, size.x * 0.28, 46), "تلميح")
    _draw_button(Rect2(size.x * 0.68, size.y - 65, size.x * 0.28, 46), "إعادة")

func _draw_button(rect: Rect2, label: String) -> void:
    draw_rect(rect, Color("#304765"), true, 12)
    draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, 29), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 16, INK)

func _remaining() -> int:
    var count := 0
    for a in arrows:
        if a.alive: count += 1
    return count

func _is_clear(index: int) -> bool:
    var a: Dictionary = arrows[index]
    var p: Vector2i = a.cell
    var d: Vector2i = a.dir
    var cursor := p + d
    while cursor.x >= 0 and cursor.x < GRID and cursor.y >= 0 and cursor.y < GRID:
        for other in arrows:
            if other.alive and other.cell == cursor:
                return false
        cursor += d
    return true

func _try_arrow(point: Vector2) -> void:
    var origin := _board_origin()
    var cell := _cell_size()
    var local := point - origin
    if local.x < 0 or local.y < 0 or local.x >= cell * GRID or local.y >= cell * GRID:
        return
    var p := Vector2i(int(local.x / cell), int(local.y / cell))
    for i in range(arrows.size()):
        if arrows[i].alive and arrows[i].cell == p:
            if _is_clear(i):
                undo_stack.append({"index": i, "removed": removed, "moves": moves})
                arrows[i].alive = false
                removed += 1
                moves += 1
                status_text = "ممتاز! السهم خرج بنجاح"
                hint_text = ""
                if _remaining() == 0:
                    game_won = true
                    status_text = "أحسنت! أكملت المستوى"
                    hint_text = "اضغط على اللوحة للانتقال للمستوى التالي"
            else:
                status_text = "الطريق مسدود! أزل السهم الذي أمامه أولاً"
            return

func _handle_tap(point: Vector2) -> void:
    var size := get_viewport_rect().size
    if game_won:
        level += 1
        _new_level()
        return
    if point.y >= size.y - 75:
        if point.x < size.x * 0.34:
            _undo()
        elif point.x < size.x * 0.66:
            _hint()
        else:
            _new_level()
        return
    _try_arrow(point)

func _undo() -> void:
    if undo_stack.is_empty():
        status_text = "ماكو حركة حتى تتراجع عنها"
        return
    var last: Dictionary = undo_stack.pop_back()
    arrows[int(last.index)].alive = true
    removed = int(last.removed)
    moves = int(last.moves)
    game_won = false
    status_text = "تم التراجع عن آخر حركة"

func _hint() -> void:
    for i in range(arrows.size()):
        if arrows[i].alive and _is_clear(i):
            var p: Vector2i = arrows[i].cell
            hint_text = "جرّب السهم عند الصف %d والعمود %d" % [p.y + 1, p.x + 1]
            status_text = "وجدت لك سهماً يمكنه الخروج"
            return
    hint_text = "حاول فتح طريق من الحواف إلى الداخل"

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch and event.pressed:
        _handle_tap(event.position)
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _handle_tap(event.position)
