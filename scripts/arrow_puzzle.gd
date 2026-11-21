extends Node2D

const N := 17
const WHITE := Color("#ffffff")
const BLACK := Color("#111111")
const SOFT := Color("#f1f2f7")
var level := 1
var arrows: Array[Dictionary] = []
var undo_stack: Array[int] = []
var removed := 0
var hint_index := -1
var won := false
var message := "اضغط على سهم طريقه مفتوح للخروج"

func _ready() -> void:
    get_viewport().size_changed.connect(queue_redraw)
    _new_level()

func _board() -> Rect2:
    var s := minf(get_viewport_rect().size.x - 54.0, get_viewport_rect().size.y * 0.55)
    return Rect2(Vector2((get_viewport_rect().size.x - s) * 0.5, get_viewport_rect().size.y * 0.29), Vector2(s, s))

func _cell() -> float:
    return _board().size.x / float(N)

func _pos(p: Vector2i) -> Vector2:
    return _board().position + (Vector2(p) + Vector2(0.5, 0.5)) * _cell()

func _new_level() -> void:
    arrows.clear()
    undo_stack.clear()
    removed = 0
    hint_index = -1
    won = false
    message = "اضغط على سهم طريقه مفتوح للخروج"
    var rng := RandomNumberGenerator.new()
    rng.seed = 31991 + level * 7919
    var used := {}
    var target := mini(24 + level * 2, 48)
    var tries := 0
    while arrows.size() < target and tries < target * 100:
        tries += 1
        var start := Vector2i(rng.randi_range(1, N - 2), rng.randi_range(1, N - 2))
        if used.has(start):
            continue
        var path: Array[Vector2i] = [start]
        var local := {start: true}
        var last := Vector2i.ZERO
        for step in range(rng.randi_range(4, 9)):
            var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
            if last != Vector2i.ZERO and rng.randf() < 0.5:
                dirs.erase(-last)
            dirs.shuffle()
            var advanced := false
            for d in dirs:
                var q: Vector2i = path[-1] + d
                if q.x < 0 or q.x >= N or q.y < 0 or q.y >= N or used.has(q) or local.has(q):
                    continue
                path.append(q)
                local[q] = true
                last = d
                advanced = true
                break
            if not advanced:
                break
        if path.size() < 4:
            continue
        var idx := arrows.size()
        arrows.append({"path": path, "alive": true})
        for p in path:
            used[p] = idx
    queue_redraw()

func _direction(path: Array) -> Vector2i:
    return path[path.size() - 1] - path[path.size() - 2]

func _clear(idx: int) -> bool:
    var path: Array = arrows[idx].path
    var q: Vector2i = path[-1] + _direction(path)
    while q.x >= 0 and q.x < N and q.y >= 0 and q.y < N:
        for j in range(arrows.size()):
            if j == idx or not arrows[j].alive:
                continue
            if q in arrows[j].path:
                return false
        q += _direction(path)
    return true

func _draw() -> void:
    var sz := get_viewport_rect().size
    draw_rect(Rect2(Vector2.ZERO, sz), WHITE)
    _draw_header(sz)
    _draw_paths()
    _draw_footer(sz)

func _draw_header(sz: Vector2) -> void:
    draw_circle(Vector2(43, 145), 24, SOFT)
    draw_string(ThemeDB.fallback_font, Vector2(31, 155), "‹", HORIZONTAL_ALIGNMENT_LEFT, 30, 34, Color("#777789"))
    _chip(Rect2(83, 119, 94, 52), "Level", str(level))
    _chip(Rect2(188, 119, 100, 52), "↑   ↑   ↑", "")
    _chip(Rect2(299, 119, 92, 52), str(int(float(removed) / maxf(1.0, float(arrows.size())) * 100.0)) + "%", "")
    draw_circle(Vector2(sz.x - 42, 145), 24, SOFT)
    draw_arc(Vector2(sz.x - 42, 145), 12, 0.2, 5.8, 24, Color("#777789"), 3.5, true)

func _chip(r: Rect2, a: String, b: String) -> void:
    draw_rect(r, SOFT, true, 15)
    draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.position.y + (b.is_empty() ? 33 : 20)), a, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 17, Color("#858594"))
    if not b.is_empty():
        draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.position.y + 44), b, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 23, Color("#41414e"))

func _draw_paths() -> void:
    var w := maxf(3.0, _cell() * 0.17)
    for i in range(arrows.size()):
        if not arrows[i].alive:
            continue
        var path: Array = arrows[i].path
        var pts := PackedVector2Array()
        for p in path:
            pts.append(_pos(p))
        draw_polyline(pts, BLACK, w, true)
        var tip: Vector2 = pts[-1]
        var d := Vector2(_direction(path)).normalized()
        var side := Vector2(-d.y, d.x)
        var length := _cell() * 0.48
        var width := _cell() * 0.30
        draw_line(tip - d * length + side * width, tip, BLACK, w, true)
        draw_line(tip - d * length - side * width, tip, BLACK, w, true)
        if i == hint_index:
            draw_circle(tip, _cell() * 0.32, Color(1, 0.78, 0.1, 0.25))

func _draw_footer(sz: Vector2) -> void:
    var y := sz.y - 155.0
    draw_string(ThemeDB.fallback_font, Vector2(18, y - 20), message, HORIZONTAL_ALIGNMENT_CENTER, sz.x - 36, 17, Color("#30303a"))
    draw_circle(Vector2(sz.x * 0.39, y + 32), 29, SOFT)
    draw_circle(Vector2(sz.x * 0.39, y + 32), 16, Color("#777789"), false, 4)
    draw_circle(Vector2(sz.x * 0.61, y + 32), 29, SOFT)
    draw_circle(Vector2(sz.x * 0.61, y + 32), 11, Color("#777789"), false, 4)
    draw_line(Vector2(sz.x * 0.61 + 8, y + 43), Vector2(sz.x * 0.61 + 8, y + 51), Color("#777789"), 4, true)
    draw_rect(Rect2(0, sz.y - 92, sz.x, 74), Color("#777589"))
    draw_string(ThemeDB.fallback_font, Vector2(0, sz.y - 43), won ? "NEXT LEVEL" : "CLEAR IT!", HORIZONTAL_ALIGNMENT_CENTER, sz.x, 34, WHITE)

func _hit(point: Vector2) -> int:
    var best := -1
    var distance := 1e20
    for i in range(arrows.size()):
        if not arrows[i].alive:
            continue
        for p in arrows[i].path:
            var d := point.distance_to(_pos(p))
            if d < distance:
                distance = d
                best = i
    return best if distance < _cell() * 0.65 else -1

func _tap(point: Vector2) -> void:
    var sz := get_viewport_rect().size
    if point.y >= sz.y - 92:
        if won:
            level += 1
        _new_level()
        return
    var idx := _hit(point)
    if idx >= 0:
        if _clear(idx):
            undo_stack.append(idx)
            arrows[idx].alive = false
            removed += 1
            hint_index = -1
            won = _remaining() == 0
            message = "أحسنت! أكملت المرحلة" if won else "خرج السهم بنجاح"
        else:
            message = "المسار مسدود، أزل السهم الذي يعترضه أولاً"
    else:
        var y := sz.y - 155.0
        if point.distance_to(Vector2(sz.x * 0.61, y + 32)) < 35:
            _hint()
        elif point.distance_to(Vector2(sz.x * 0.39, y + 32)) < 35:
            _undo()
    queue_redraw()

func _remaining() -> int:
    var n := 0
    for a in arrows:
        if a.alive:
            n += 1
    return n

func _hint() -> void:
    for i in range(arrows.size()):
        if arrows[i].alive and _clear(i):
            hint_index = i
            message = "هذا السهم يمكنه الخروج الآن"
            return
    message = "حاول فتح الطريق من الأسهم الخارجية"

func _undo() -> void:
    if undo_stack.is_empty():
        message = "لا توجد حركة للتراجع"
        return
    var idx: int = undo_stack.pop_back()
    arrows[idx].alive = true
    removed = maxi(0, removed - 1)
    won = false
    message = "تم التراجع عن آخر حركة"

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch and event.pressed:
        _tap(event.position)
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _tap(event.position)
