import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() => runApp(const ArrowEscapeApp());

class ArrowEscapeApp extends StatelessWidget {
  const ArrowEscapeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ArrowGamePage(),
    );
  }
}

class ArrowPath {
  ArrowPath(this.cells);
  final List<Point<int>> cells;
  bool alive = true;
  Point<int> get direction {
    final a = cells[cells.length - 2];
    final b = cells.last;
    return Point(b.x - a.x, b.y - a.y);
  }
}

class ArrowGamePage extends StatefulWidget {
  const ArrowGamePage({super.key});
  @override
  State<ArrowGamePage> createState() => _ArrowGamePageState();
}

class _ArrowGamePageState extends State<ArrowGamePage> {
  static const int grid = 17;
  int level = 1;
  int removed = 0;
  int hintIndex = -1;
  bool won = false;
  String message = 'اضغط على سهم طريقه مفتوح للخروج';
  final List<ArrowPath> arrows = [];
  final List<int> undo = [];

  @override
  void initState() {
    super.initState();
    _newLevel();
  }

  void _newLevel() {
    arrows.clear();
    undo.clear();
    removed = 0;
    hintIndex = -1;
    won = false;
    message = 'اضغط على سهم طريقه مفتوح للخروج';
    final random = math.Random(31991 + level * 7919);
    final occupied = <Point<int>>{};
    final target = math.min(24 + level * 2, 48);
    var tries = 0;
    while (arrows.length < target && tries < target * 100) {
      tries++;
      final start = Point(random.nextInt(grid - 2) + 1, random.nextInt(grid - 2) + 1);
      if (occupied.contains(start)) continue;
      final path = <Point<int>>[start];
      final local = <Point<int>>{start};
      var last = const Point<int>(0, 0);
      final steps = 4 + random.nextInt(6);
      for (var step = 0; step < steps; step++) {
        final dirs = <Point<int>>[
          const Point(0, -1), const Point(0, 1),
          const Point(-1, 0), const Point(1, 0),
        ];
        if (last.x != 0 || last.y != 0) {
          if (random.nextBool()) dirs.remove(Point(-last.x, -last.y));
        }
        dirs.shuffle(random);
        var advanced = false;
        for (final d in dirs) {
          final q = Point(path.last.x + d.x, path.last.y + d.y);
          if (q.x < 0 || q.x >= grid || q.y < 0 || q.y >= grid ||
              occupied.contains(q) || local.contains(q)) continue;
          path.add(q);
          local.add(q);
          last = d;
          advanced = true;
          break;
        }
        if (!advanced) break;
      }
      if (path.length < 4) continue;
      arrows.add(ArrowPath(path));
      occupied.addAll(path);
    }
    setState(() {});
  }

  bool _isClear(int index) {
    final arrow = arrows[index];
    final d = arrow.direction;
    var x = arrow.cells.last.x + d.x;
    var y = arrow.cells.last.y + d.y;
    while (x >= 0 && x < grid && y >= 0 && y < grid) {
      for (var j = 0; j < arrows.length; j++) {
        if (j == index || !arrows[j].alive) continue;
        if (arrows[j].cells.any((p) => p.x == x && p.y == y)) return false;
      }
      x += d.x;
      y += d.y;
    }
    return true;
  }

  void _tapArrow(Offset local, Size size) {
    final cell = size.width / grid;
    final x = (local.dx / cell).floor();
    final y = (local.dy / cell).floor();
    if (x < 0 || x >= grid || y < 0 || y >= grid) return;
    var selected = -1;
    var best = 999999;
    for (var i = 0; i < arrows.length; i++) {
      if (!arrows[i].alive) continue;
      for (final p in arrows[i].cells) {
        final distance = (p.x - x).abs() + (p.y - y).abs();
        if (distance < best) { best = distance; selected = i; }
      }
    }
    if (selected < 0 || best > 1) return;
    setState(() {
      if (_isClear(selected)) {
        undo.add(selected);
        arrows[selected].alive = false;
        removed++;
        hintIndex = -1;
        won = arrows.every((a) => !a.alive);
        message = won ? 'أحسنت! أكملت المرحلة' : 'خرج السهم بنجاح';
      } else {
        message = 'المسار مسدود، أزل السهم الذي يعترضه أولاً';
      }
    });
  }

  void _hint() {
    setState(() {
      for (var i = 0; i < arrows.length; i++) {
        if (arrows[i].alive && _isClear(i)) {
          hintIndex = i;
          message = 'هذا السهم يمكنه الخروج الآن';
          return;
        }
      }
      message = 'حاول فتح الطريق من الأسهم الخارجية';
    });
  }

  void _undo() {
    setState(() {
      if (undo.isEmpty) {
        message = 'لا توجد حركة للتراجع';
        return;
      }
      final index = undo.removeLast();
      arrows[index].alive = true;
      removed = removed > 0 ? removed - 1 : 0;
      won = false;
      message = 'تم التراجع عن آخر حركة';
    });
  }

  @override
  Widget build(BuildContext context) {
    final percent = arrows.isEmpty ? 0 : (removed * 100 / arrows.length).round();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final boardSide = math.min(constraints.maxWidth - 34, constraints.maxHeight * .55).toDouble();
          return Column(
            children: [
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _roundIcon(Icons.chevron_left, () {}),
                    const SizedBox(width: 10),
                    Expanded(child: _infoBox('Level', '$level')),
                    const SizedBox(width: 8),
                    Expanded(child: _infoBox('↑   ↑   ↑', '')),
                    const SizedBox(width: 8),
                    Expanded(child: _infoBox('$percent%', '')),
                    const SizedBox(width: 10),
                    _roundIcon(Icons.refresh, _newLevel),
                  ],
                ),
              ),
              const Spacer(),
              Center(
                child: SizedBox(
                  width: boardSide,
                  height: boardSide,
                  child: GestureDetector(
                    onTapDown: (details) => _tapArrow(details.localPosition, Size(boardSide, boardSide)),
                    child: CustomPaint(
                      painter: ArrowBoardPainter(arrows, hintIndex),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(message, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, color: Color(0xff30303a))),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _roundIcon(Icons.palette_outlined, () {}),
                  const SizedBox(width: 34),
                  _roundIcon(Icons.lightbulb_outline, _hint),
                ],
              ),
              const SizedBox(height: 22),
              GestureDetector(
                onTap: () {
                  if (won) level++;
                  _newLevel();
                },
                child: Container(
                  width: double.infinity,
                  height: 76,
                  alignment: Alignment.center,
                  color: const Color(0xff777589),
                  child: Text(won ? 'NEXT LEVEL' : 'CLEAR IT!',
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _roundIcon(IconData icon, VoidCallback onTap) => Material(
    color: const Color(0xfff1f2f7),
    shape: const CircleBorder(),
    child: InkWell(onTap: onTap, customBorder: const CircleBorder(),
      child: SizedBox(width: 48, height: 48, child: Icon(icon, color: const Color(0xff777789), size: 27))),
  );

  Widget _infoBox(String top, String bottom) => Container(
    height: 54,
    decoration: BoxDecoration(color: const Color(0xfff1f2f7), borderRadius: BorderRadius.circular(15)),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(top, style: const TextStyle(color: Color(0xff858594), fontSize: 15, fontWeight: FontWeight.w600)),
      if (bottom.isNotEmpty) Text(bottom, style: const TextStyle(color: Color(0xff41414e), fontSize: 21, height: 1)),
    ]),
  );
}

class ArrowBoardPainter extends CustomPainter {
  ArrowBoardPainter(this.arrows, this.hintIndex);
  final List<ArrowPath> arrows;
  final int hintIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 17;
    final line = Paint()..color = const Color(0xff111111)..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.8, cell * .17)..strokeCap = StrokeCap.square..strokeJoin = StrokeJoin.miter;
    for (var i = 0; i < arrows.length; i++) {
      if (!arrows[i].alive) continue;
      final path = Path();
      final points = arrows[i].cells.map((p) => Offset((p.x + .5) * cell, (p.y + .5) * cell)).toList();
      path.moveTo(points.first.dx, points.first.dy);
      for (var j = 1; j < points.length; j++) {
        path.lineTo(points[j].dx, points[j].dy);
      }
      canvas.drawPath(path, line);
      final tip = points.last;
      final d = arrows[i].direction;
      final direction = Offset(d.x.toDouble(), d.y.toDouble());
      final side = Offset(-direction.dy, direction.dx);
      final len = cell * .48;
      final width = cell * .30;
      final head = Path()
        ..moveTo(tip.dx - direction.dx * len + side.dx * width, tip.dy - direction.dy * len + side.dy * width)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(tip.dx - direction.dx * len - side.dx * width, tip.dy - direction.dy * len - side.dy * width);
      canvas.drawPath(head, line);
      if (i == hintIndex) {
        canvas.drawCircle(tip, cell * .38, Paint()..color = const Color(0x44ffbf00));
      }
    }
  }

  @override
  bool shouldRepaint(covariant ArrowBoardPainter oldDelegate) =>
      oldDelegate.arrows != arrows || oldDelegate.hintIndex != hintIndex;
}
