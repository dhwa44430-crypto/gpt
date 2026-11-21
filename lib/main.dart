import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

void main() => runApp(const WormArenaApp());

class WormArenaApp extends StatelessWidget {
  const WormArenaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Arial',
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff69d64d)),
        ),
        home: const WormGamePage(),
      );
}

class SnakeSkin {
  const SnakeSkin(this.name, this.primary, this.secondary, this.accent);
  final String name;
  final Color primary;
  final Color secondary;
  final Color accent;
}

const skins = <SnakeSkin>[
  SnakeSkin('Lime', Color(0xffa7f04b), Color(0xff35a83e), Color(0xffeaff9c)),
  SnakeSkin('Ocean', Color(0xff52e6ef), Color(0xff1679c5), Color(0xffd4ffff)),
  SnakeSkin('Berry', Color(0xffff77bd), Color(0xffb52f86), Color(0xffffd8ed)),
  SnakeSkin('Flame', Color(0xffffc04c), Color(0xffed5b2e), Color(0xffffffb0)),
  SnakeSkin('Violet', Color(0xffbd8aff), Color(0xff6843c7), Color(0xfff0dcff)),
  SnakeSkin('Shadow', Color(0xff596579), Color(0xff202b3b), Color(0xffc6d5e8)),
];

class WormGamePage extends StatefulWidget {
  const WormGamePage({super.key});
  @override
  State<WormGamePage> createState() => _WormGamePageState();
}

class _WormGamePageState extends State<WormGamePage>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  final math.Random _random = math.Random();
  final List<Offset> _trail = <Offset>[];
  final List<Offset> _foods = <Offset>[];
  Offset _head = const Offset(.50, .52);
  Offset _direction = const Offset(1, 0);
  Offset _wantedDirection = const Offset(1, 0);
  int _score = 0;
  int _best = 0;
  int _skinIndex = 0;
  double _growth = .19;
  bool _started = false;
  bool _gameOver = false;
  Size _boardSize = Size.zero;

  SnakeSkin get _skin => skins[_skinIndex];

  @override
  void initState() {
    super.initState();
    _resetGame();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _resetGame() {
    _head = const Offset(.50, .52);
    _direction = const Offset(1, 0);
    _wantedDirection = const Offset(1, 0);
    _trail
      ..clear()
      ..addAll(List<Offset>.generate(90, (i) => Offset(.50 - i * .0024, .52)));
    _foods.clear();
    for (var i = 0; i < 22; i++) {
      _foods.add(_randomFood());
    }
    _score = 0;
    _growth = .19;
    _started = false;
    _gameOver = false;
    _lastTick = Duration.zero;
  }

  Offset _randomFood() => Offset(
        .07 + _random.nextDouble() * .86,
        .09 + _random.nextDouble() * .82,
      );

  void _onTick(Duration elapsed) {
    if (!mounted || !_started || _gameOver || _boardSize.isEmpty) return;
    final previous = _lastTick;
    _lastTick = elapsed;
    if (previous == Duration.zero) return;
    final dt = ((elapsed - previous).inMicroseconds / 1000000).clamp(0.0, .04).toDouble();
    if (dt <= 0) return;

    final wantedAngle = math.atan2(_wantedDirection.dy, _wantedDirection.dx);
    final currentAngle = math.atan2(_direction.dy, _direction.dx);
    var difference = (wantedAngle - currentAngle + math.pi * 3) % (math.pi * 2) - math.pi;
    final maxTurn = 3.15 * dt;
    difference = difference.clamp(-maxTurn, maxTurn).toDouble();
    final angle = currentAngle + difference;
    _direction = Offset(math.cos(angle), math.sin(angle));
    final speed = (.255 + math.min(_score, 100) * .00055).toDouble();
    _head = _head + _direction * (speed * dt);
    _trail.insert(0, _head);
    _trimTrail();

    if (_head.dx < .035 || _head.dx > .965 || _head.dy < .045 || _head.dy > .955) {
      _finishGame();
      return;
    }

    final hitRadius = .028;
    for (var i = _foods.length - 1; i >= 0; i--) {
      if ((_foods[i] - _head).distance < hitRadius) {
        _foods.removeAt(i);
        _score += 10;
        _growth += .022;
        _foods.add(_randomFood());
      }
    }

    var hitOwnBody = false;
    for (var i = 18; i < _trail.length; i += 2) {
      if ((_head - _trail[i]).distance < .027) {
        hitOwnBody = true;
        break;
      }
    }
    if (hitOwnBody && _trail.length > 35) {
      _finishGame();
      return;
    }
    setState(() {});
  }

  void _trimTrail() {
    var distance = 0.0;
    var keep = 2;
    for (var i = 1; i < _trail.length; i++) {
      distance += (_trail[i - 1] - _trail[i]).distance;
      keep = i + 1;
      if (distance > _growth + .10) break;
    }
    if (keep < _trail.length) _trail.removeRange(keep, _trail.length);
  }

  void _finishGame() {
    _gameOver = true;
    _best = math.max(_best, _score);
    setState(() {});
  }

  void _steer(Offset local) {
    if (_gameOver) return;
    if (!_started) {
      _started = true;
      _lastTick = Duration.zero;
    }
    final target = Offset(local.dx / _boardSize.width, local.dy / _boardSize.height);
    final delta = target - _head;
    if (delta.distance > .015) {
      _wantedDirection = delta / delta.distance;
    }
    setState(() {});
  }


  void _chooseSkin(int index) => setState(() => _skinIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xff153d31), Color(0xff09251f), Color(0xff071b19)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final boardSide = math.min(
              constraints.maxWidth - 24,
              constraints.maxHeight * .66,
            ).toDouble();
            _boardSize = Size.square(boardSide);
            return Column(
              children: [
                const SizedBox(height: 8),
                _topBar(),
                const SizedBox(height: 12),
                _scoreBar(),
                const SizedBox(height: 12),
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: boardSide,
                      height: boardSide,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (d) => _steer(d.localPosition),
                        onPanUpdate: (d) => _steer(d.localPosition),
                        onTapDown: (d) => _steer(d.localPosition),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: CustomPaint(
                            painter: ArenaPainter(
                              trail: _trail,
                              foods: _foods,
                              skin: _skin,
                              score: _score,
                              gameOver: _gameOver,
                              started: _started,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _skinPicker(),
                const SizedBox(height: 8),
                _bottomHint(),
                const SizedBox(height: 6),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _topBar() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _circleButton(Icons.menu_rounded, () => _showMenu()),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'WORM ARENA',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xffeaffd8),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.2,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3))],
                ),
              ),
            ),
            _circleButton(Icons.refresh_rounded, () => setState(_resetGame)),
          ],
        ),
      );

  Widget _scoreBar() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Row(
          children: [
            Expanded(child: _statPill('SCORE', '$_score', Icons.stars_rounded)),
            const SizedBox(width: 10),
            Expanded(child: _statPill('BEST', '$_best', Icons.emoji_events_rounded)),
          ],
        ),
      );

  Widget _statPill(String label, String value, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xff214b3b).withValues(alpha: .9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xff8bcf70).withValues(alpha: .35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xffffd66b), size: 19),
            const SizedBox(width: 7),
            Text(label, style: const TextStyle(color: Color(0xffa8c8ad), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
            const SizedBox(width: 8),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
          ],
        ),
      );

  Widget _skinPicker() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const Text('CHOOSE YOUR WORM', style: TextStyle(color: Color(0xffb8d5bb), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.6)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(skins.length, (index) {
                final skin = skins[index];
                final selected = index == _skinIndex;
                return GestureDetector(
                  onTap: () => _chooseSkin(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: selected ? 43 : 37,
                    height: selected ? 43 : 37,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [skin.primary, skin.secondary]),
                      border: Border.all(color: selected ? Colors.white : Colors.white24, width: selected ? 3 : 1),
                      boxShadow: selected ? [BoxShadow(color: skin.primary.withValues(alpha: .5), blurRadius: 13, spreadRadius: 2)] : [],
                    ),
                    child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 22) : null,
                  ),
                );
              }),
            ),
            const SizedBox(height: 5),
            Text(_skin.name, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _bottomHint() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'اسحب إصبعك داخل الساحة لتوجيه الأفعى واجمع الطعام حتى تكبر!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xffa8c5ad), fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );

  Widget _circleButton(IconData icon, VoidCallback onTap) => Material(
        color: const Color(0xff28523f),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 43,
            height: 43,
            child: Icon(icon, color: const Color(0xffe5f8df), size: 23),
          ),
        ),
      );

  void _showMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff173c30),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('WORM ARENA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 2)),
            const SizedBox(height: 12),
            const Text('تحكم بالأفعى، اجمع الطعام، وابتعد عن حواف الساحة وعن جسمك.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, height: 1.5)),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () { Navigator.pop(context); setState(_resetGame); },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('ابدأ من جديد'),
            ),
          ],
        ),
      ),
    );
  }
}

class ArenaPainter extends CustomPainter {
  ArenaPainter({
    required this.trail,
    required this.foods,
    required this.skin,
    required this.score,
    required this.gameOver,
    required this.started,
  });

  final List<Offset> trail;
  final List<Offset> foods;
  final SnakeSkin skin;
  final int score;
  final bool gameOver;
  final bool started;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff367b48), Color(0xff225b3c), Color(0xff174832)],
      ).createShader(rect);
    canvas.drawRect(rect, background);

    final gridPaint = Paint()
      ..color = const Color(0x18d9f4b7)
      ..strokeWidth = 1;
    const gridCount = 14;
    for (var i = 1; i < gridCount; i++) {
      final p = size.width * i / gridCount;
      canvas.drawLine(Offset(p, 0), Offset(p, size.height), gridPaint);
      canvas.drawLine(Offset(0, p), Offset(size.width, p), gridPaint);
    }

    final random = math.Random(24);
    final grassPaint = Paint()..color = const Color(0x2779b65b);
    for (var i = 0; i < 90; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), 1.1 + random.nextDouble() * 1.6, grassPaint);
    }

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = const Color(0xffa9d879);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(2.5), const Radius.circular(22)),
      border,
    );

    _drawFood(canvas, size);
    _drawSnake(canvas, size);

    if (!gameOver && !started) {
      final shade = Paint()..color = const Color(0x22000000);
      canvas.drawRect(rect, shade);
      _drawCenterLabel(canvas, size, 'TOUCH & STEER', 'اسحب داخل الساحة للبدء');
    }
    if (gameOver) {
      canvas.drawRect(rect, Paint()..color = const Color(0xaa061b14));
      _drawCenterLabel(canvas, size, 'GAME OVER', 'اضغط زر التحديث للعب مرة ثانية');
    }
  }

  void _drawFood(Canvas canvas, Size size) {
    for (var i = 0; i < foods.length; i++) {
      final p = Offset(foods[i].dx * size.width, foods[i].dy * size.height);
      final radius = size.width * (.010 + (i % 3) * .0015);
      canvas.drawCircle(p, radius * 2.3, Paint()..color = const Color(0x22ffe57a)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xfffff5ad), i.isEven ? const Color(0xffffb52f) : const Color(0xfff46d3d), const Color(0xffbd3d28)],
          stops: const [0, .55, 1],
        ).createShader(Rect.fromCircle(center: p, radius: radius * 1.5));
      canvas.drawCircle(p, radius * 1.5, paint);
      canvas.drawCircle(p.translate(-radius * .35, -radius * .4), radius * .28, Paint()..color = Colors.white70);
      final leaf = Path()
        ..moveTo(p.dx + radius * .15, p.dy - radius * 1.2)
        ..quadraticBezierTo(p.dx + radius * 1.4, p.dy - radius * 2, p.dx + radius * 1.2, p.dy - radius * .65)
        ..quadraticBezierTo(p.dx + radius * .55, p.dy - radius * .55, p.dx + radius * .15, p.dy - radius * 1.2);
      canvas.drawPath(leaf, Paint()..color = const Color(0xffb7ef65));
    }
  }

  void _drawSnake(Canvas canvas, Size size) {
    if (trail.isEmpty) return;
    final points = trail.map((p) => Offset(p.dx * size.width, p.dy * size.height)).toList();
    final radius = size.width * .023;
    if (points.length > 1) {
      final bodyPath = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        bodyPath.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(
        bodyPath,
        Paint()
          ..color = const Color(0x66000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 2.25
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      canvas.drawPath(
        bodyPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [skin.accent, skin.primary, skin.secondary, skin.primary],
          ).createShader(Offset.zero & size)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 1.95
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true,
      );
      canvas.drawPath(
        bodyPath,
        Paint()
          ..color = skin.accent.withValues(alpha: .58)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * .34
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

      for (var i = 4; i < points.length; i += 8) {
        final p = points[i];
        final scale = 1 - (i / points.length) * .25;
        canvas.drawCircle(
          p.translate(-radius * .12, -radius * .22),
          radius * .17 * scale,
          Paint()..color = skin.accent.withValues(alpha: .5),
        );
      }
    }

    final head = points.first;
    final direction = points.length > 1 ? (points[0] - points[1]) : const Offset(1, 0);
    final angle = math.atan2(direction.dy, direction.dx);
    canvas.save();
    canvas.translate(head.dx, head.dy);
    canvas.rotate(angle);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: radius * 2.5, height: radius * 2.15),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [skin.accent, skin.primary, skin.secondary],
        ).createShader(Rect.fromCenter(center: Offset.zero, width: radius * 2.5, height: radius * 2.15)),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(-radius * .1, -radius * .48), width: radius * 1.45, height: radius * .45),
      Paint()..color = Colors.white.withValues(alpha: .28),
    );
    for (final side in [-1.0, 1.0]) {
      final eye = Offset(radius * .55, radius * side * .58);
      canvas.drawCircle(eye, radius * .34, Paint()..color = Colors.white);
      canvas.drawCircle(eye.translate(radius * .08, 0), radius * .19, Paint()..color = const Color(0xff172a22));
      canvas.drawCircle(eye.translate(radius * .13, -radius * .07), radius * .065, Paint()..color = Colors.white);
    }
    final smile = Path()
      ..moveTo(radius * 1.0, radius * .05)
      ..quadraticBezierTo(radius * 1.28, radius * .22, radius * .98, radius * .38);
    canvas.drawPath(smile, Paint()..color = const Color(0xff5c2924)..style = PaintingStyle.stroke..strokeWidth = radius * .10..strokeCap = StrokeCap.round);
    canvas.restore();
  }

  void _drawCenterLabel(Canvas canvas, Size size, String title, String subtitle) {
    final titlePainter = TextPainter(
      text: TextSpan(text: title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2, shadows: [Shadow(color: Colors.black54, blurRadius: 8)])),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size.width - 20);
    final subPainter = TextPainter(
      text: TextSpan(text: subtitle, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, shadows: [Shadow(color: Colors.black54, blurRadius: 5)])),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size.width - 20);
    titlePainter.paint(canvas, Offset((size.width - titlePainter.width) / 2, size.height * .43));
    subPainter.paint(canvas, Offset((size.width - subPainter.width) / 2, size.height * .43 + 34));
  }

  @override
  bool shouldRepaint(covariant ArenaPainter oldDelegate) => true;
}
