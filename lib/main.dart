import 'dart:math' as math;
// ignore: deprecated_member_use
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
  final List<math.Point<int>> cells;
  bool alive = true;
  math.Point<int> get direction {
    final a = cells[cells.length - 2];
    final b = cells.last;
    return math.Point<int>(b.x - a.x, b.y - a.y);
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
    final occupied = <math.Point<int>>{};
    final target = math.min(25 + level ~/ 3, 32);
    var attempts = 0;

    // Grow many separate, continuous, right-angled arrow paths.
    // Shorter controlled walks make the board dense instead of producing
    // only a handful of huge paths that stop after colliding.
    while (arrows.length < target && attempts < target * 500) {
      attempts++;
      final start = math.Point<int>(
        random.nextInt(grid),
        random.nextInt(grid),
      );
      if (occupied.contains(start)) continue;

      final path = <math.Point<int>>[start];
      final local = <math.Point<int>>{start};
      var previous = const math.Point<int>(0, 0);
      final desiredLength = 7 + random.nextInt(9);

      for (var step = 1; step < desiredLength; step++) {
        final directions = <math.Point<int>>[
          const math.Point<int>(0, -1),
          const math.Point<int>(0, 1),
          const math.Point<int>(-1, 0),
          const math.Point<int>(1, 0),
        ]..shuffle(random);

        var advanced = false;
        for (final direction in directions) {
          // Avoid immediate U-turns; turns remain square like the reference.
          if (direction.x == -previous.x &&
              direction.y == -previous.y) {
            continue;
          }
          final next = math.Point<int>(
            path.last.x + direction.x,
            path.last.y + direction.y,
          );
          if (next.x < 0 || next.x >= grid ||
              next.y < 0 || next.y >= grid ||
              occupied.contains(next) || local.contains(next)) {
            continue;
          }
          path.add(next);
          local.add(next);
          previous = direction;
          advanced = true;
          break;
        }
        if (!advanced) break;
      }

      if (path.length < 6) continue;
      arrows.add(ArrowPath(path));
      occupied.addAll(path);
    }

    // If a rare random layout is too sparse, fill remaining open space
    // with short straight arrows so every level starts with a full board.
    if (arrows.length < 12) {
      for (var y = 0; y < grid; y++) {
        for (var x = 0; x < grid; x++) {
          if (arrows.length >= 16) break;
          final start = math.Point<int>(x, y);
          if (occupied.contains(start)) continue;
          final candidates = <List<math.Point<int>>>[
            [start, math.Point<int>(x + 1, y), math.Point<int>(x + 2, y)],
            [start, math.Point<int>(x, y + 1), math.Point<int>(x, y + 2)],
          ];
          for (final path in candidates) {
            if (path.any((p) =>
                p.x < 0 || p.x >= grid || p.y < 0 || p.y >= grid ||
                occupied.contains(p))) {
              continue;
            }
            arrows.add(ArrowPath(path));
            occupied.addAll(path);
            break;
          }
        }
      }
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
                  _roundIcon(Icons.undo, _undo),
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
    final strokeWidth = math.max(2.0, cell * .12).toDouble();
    final linePaint = Paint()
      ..color = const Color(0xff080808)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final arrowPaint = Paint()
      ..color = const Color(0xff080808)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (var i = 0; i < arrows.length; i++) {
      if (!arrows[i].alive) continue;
      final points = arrows[i].cells
          .map((p) => Offset((p.x + .5) * cell, (p.y + .5) * cell))
          .toList(growable: false);
      if (points.length < 2) continue;

      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var j = 1; j < points.length; j++) {
        path.lineTo(points[j].dx, points[j].dy);
      }
      canvas.drawPath(path, linePaint);

      final tip = points.last;
      final d = arrows[i].direction;
      final direction = Offset(d.x.toDouble(), d.y.toDouble());
      final side = Offset(-direction.dy, direction.dx);
      final headLength = cell * .34;
      final headHalfWidth = cell * .23;
      final triangle = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(
          tip.dx - direction.dx * headLength + side.dx * headHalfWidth,
          tip.dy - direction.dy * headLength + side.dy * headHalfWidth,
        )
        ..lineTo(
          tip.dx - direction.dx * headLength - side.dx * headHalfWidth,
          tip.dy - direction.dy * headLength - side.dy * headHalfWidth,
        )
        ..close();
      canvas.drawPath(triangle, arrowPaint);

      if (i == hintIndex) {
        canvas.drawCircle(
          tip,
          cell * .42,
          Paint()..color = const Color(0x33ffbf00)..isAntiAlias = true,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant ArrowBoardPainter oldDelegate) =>
      oldDelegate.arrows != arrows || oldDelegate.hintIndex != hintIndex;
}
