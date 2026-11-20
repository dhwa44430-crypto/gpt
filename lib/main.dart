import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const HeroQuestApp());
}

class HeroQuestApp extends StatelessWidget {
  const HeroQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'مغامرات البطل',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF101827),
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  final Stopwatch _clock = Stopwatch();
  final Set<String> _held = <String>{};
  final List<LevelData> _levels = LevelData.all;
  int _levelIndex = 0;
  int _coins = 0;
  int _lives = 3;
  double _playerX = 90;
  double _playerY = 320;
  double _velocityX = 0;
  double _velocityY = 0;
  double _cameraX = 0;
  double _previousTime = 0;
  bool _grounded = false;
  bool _started = false;
  bool _won = false;
  bool _lost = false;
  bool _jumpQueued = false;
  final Set<int> _collected = <int>{};
  final Set<int> _defeated = <int>{};
  ui.Image? _heroAtlas;

  Future<void> _loadHeroAtlas() async {
    final data = await DefaultAssetBundle.of(context).load('assets/images/hero/hero_spritesheet.webp');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    if (!mounted) { frame.image.dispose(); return; }
    setState(() => _heroAtlas = frame.image);
  }

  LevelData get _level => _levels[_levelIndex];

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(_tick);
    _ticker.repeat();
    _clock.start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHeroAtlas());
  }

  @override
  void dispose() {
    _heroAtlas?.dispose();
    _ticker.dispose();
    _clock.stop();
    super.dispose();
  }

  void _start() {
    setState(() {
      _started = true;
      _won = false;
      _lost = false;
    });
    _previousTime = _clock.elapsedMicroseconds / 1000000;
  }

  void _resetLevel() {
    _playerX = 90;
    _playerY = 320;
    _velocityX = 0;
    _velocityY = 0;
    _cameraX = 0;
    _grounded = false;
    _collected.clear();
    _defeated.clear();
    _jumpQueued = false;
  }

  void _restart() {
    setState(() {
      _levelIndex = 0;
      _coins = 0;
      _lives = 3;
      _resetLevel();
      _started = true;
      _won = false;
      _lost = false;
    });
  }

  void _tick() {
    final now = _clock.elapsedMicroseconds / 1000000;
    var dt = now - _previousTime;
    _previousTime = now;
    dt = dt.clamp(0.0, 0.035).toDouble();
    if (!_started || _won || _lost || dt <= 0) return;

    final direction = (_held.contains('right') ? 1.0 : 0.0) -
        (_held.contains('left') ? 1.0 : 0.0);
    _velocityX = direction * 220;
    _playerX += _velocityX * dt;

    if (_jumpQueued && _grounded) {
      _velocityY = -475;
      _grounded = false;
    }
    _jumpQueued = false;
    _velocityY += 1050 * dt;
    _playerY += _velocityY * dt;

    _playerX = _playerX.clamp(0.0, _level.length - 45).toDouble();
    _grounded = false;

    // أرضية العالم والمنصات، مع ترك الحفر مفتوحة.
    for (final platform in _level.platforms) {
      final overlaps = _playerX + 30 > platform.x &&
          _playerX + 10 < platform.x + platform.width;
      final wasAbove = _playerY + 42 - _velocityY * dt <= platform.y + 8;
      if (overlaps && _velocityY >= 0 && wasAbove &&
          _playerY + 42 >= platform.y && _playerY + 42 <= platform.y + 28) {
        _playerY = platform.y - 42;
        _velocityY = 0;
        _grounded = true;
      }
    }

    for (var i = 0; i < _level.coins.length; i++) {
      if (_collected.contains(i)) continue;
      final coin = _level.coins[i];
      if ((_playerX + 20 - coin.dx).abs() < 28 &&
          (_playerY + 20 - coin.dy).abs() < 32) {
        _collected.add(i);
        _coins++;
      }
    }

    for (var i = 0; i < _level.enemies.length; i++) {
      if (_defeated.contains(i)) continue;
      final enemy = _level.enemies[i];
      final ex = enemy.x + math.sin(now * 1.7 + i) * enemy.range;
      final near = (_playerX + 20 - ex).abs() < 34 &&
          (_playerY + 35 - enemy.y).abs() < 35;
      if (near && _velocityY > 80 && _playerY + 40 < enemy.y + 18) {
        _defeated.add(i);
        _velocityY = -270;
      } else if (near) {
        _hurt();
      }
    }

    if (_playerY > 510) _hurt();
    if (_playerX >= _level.length - 100) {
      if (_levelIndex < _levels.length - 1) {
        setState(() {
          _levelIndex++;
          _resetLevel();
        });
      } else {
        setState(() => _won = true);
      }
    }

    final screenWorldWidth = (MediaQuery.maybeOf(context)?.size.width ?? 800) *
        450 / (MediaQuery.maybeOf(context)?.size.height ?? 450);
    _cameraX = (_playerX - screenWorldWidth * 0.38)
        .clamp(0.0, math.max(0.0, _level.length - screenWorldWidth)).toDouble();
    if (mounted) setState(() {});
  }

  void _hurt() {
    _lives--;
    if (_lives <= 0) {
      setState(() {
        _lost = true;
        _started = false;
      });
    } else {
      _playerX = math.max(40.0, _playerX - 100).toDouble();
      _playerY = 260;
      _velocityY = 0;
      _velocityX = 0;
    }
  }

  void _press(String key) {
    if (!_started) return;
    _held.add(key);
    if (key == 'jump') _jumpQueued = true;
  }

  void _release(String key) => _held.remove(key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _ticker,
              builder: (context, _) => CustomPaint(
                painter: GamePainter(
                  level: _level,
                  playerX: _playerX,
                  playerY: _playerY,
                  cameraX: _cameraX,
                  coins: _collected,
                  defeated: _defeated,
                  time: _clock.elapsedMilliseconds / 1000,
                  facingRight: _velocityX >= 0,
                  heroAtlas: _heroAtlas,
                  heroFrame: !_grounded ? 4 : (_held.contains('right') || _held.contains('left') ? 1 + ((_clock.elapsedMilliseconds ~/ 130) % 3) : 0),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _hud('المرحلة ${_levelIndex + 1}', Icons.flag_rounded),
                    const SizedBox(width: 8),
                    _hud('$_coins', Icons.monetization_on_rounded),
                    const Spacer(),
                    _hud('♥ $_lives', Icons.favorite_rounded),
                  ],
                ),
              ),
            ),
            if (_started && !_won && !_lost)
              Positioned(
                left: 18,
                bottom: 22,
                child: Row(
                  children: [
                    _control(Icons.arrow_back_rounded, 'left'),
                    const SizedBox(width: 12),
                    _control(Icons.arrow_forward_rounded, 'right'),
                  ],
                ),
              ),
            if (_started && !_won && !_lost)
              Positioned(
                right: 24,
                bottom: 24,
                child: _control(Icons.arrow_upward_rounded, 'jump', large: true),
              ),
            if (!_started || _won || _lost)
              Container(
                color: const Color(0xB9000000),
                alignment: Alignment.center,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 360),
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: const Color(0xFF17243A),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: const Color(0xFFFFC857), width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 12))
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('⚔️', style: TextStyle(fontSize: 54)),
                      const SizedBox(height: 8),
                      Text(
                        _won ? 'أحسنت يا بطل!' : _lost ? 'انتهت المحاولة' : 'مغامرات البطل',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFFFFD166)),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _won
                            ? 'أنهيت المراحل الثلاث وجمعت $_coins عملة!'
                            : _lost
                                ? 'لا تستسلم! حاول من جديد.'
                                : 'اجمع العملات، اقفز فوق الأعداء، واعبر المراحل!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.white70),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _won || _lost ? _restart : _start,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFC857),
                            foregroundColor: const Color(0xFF182238),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(_won || _lost ? 'العب من جديد' : 'ابدأ المغامرة',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _hud(String text, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xD9162438),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: const Color(0xFFFFD166)),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
      );

  Widget _control(IconData icon, String key, {bool large = false}) {
    return GestureDetector(
      onTapDown: (_) => _press(key),
      onTapUp: (_) => _release(key),
      onTapCancel: () => _release(key),
      child: Container(
        width: large ? 76 : 64,
        height: large ? 76 : 64,
        decoration: BoxDecoration(
          color: const Color(0xD9233855),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFFFD166), width: 2),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 5))],
        ),
        child: Icon(icon, size: large ? 38 : 32, color: Colors.white),
      ),
    );
  }
}

class PlatformData {
  const PlatformData(this.x, this.y, this.width);
  final double x, y, width;
}

class CoinData {
  const CoinData(this.dx, this.dy);
  final double dx, dy;
}

class EnemyData {
  const EnemyData(this.x, this.y, this.range);
  final double x, y, range;
}

class LevelData {
  const LevelData({
    required this.name,
    required this.length,
    required this.sky,
    required this.ground,
    required this.platforms,
    required this.coins,
    required this.enemies,
    required this.decor,
  });

  final String name;
  final double length;
  final Color sky;
  final Color ground;
  final List<PlatformData> platforms;
  final List<CoinData> coins;
  final List<EnemyData> enemies;
  final int decor;

  static final List<LevelData> all = [
    LevelData(
      name: 'السهول الخضراء', length: 2200,
      sky: const Color(0xFF72D6F2), ground: const Color(0xFF39965B), decor: 0,
      platforms: const [
        PlatformData(0, 390, 500), PlatformData(590, 390, 370),
        PlatformData(1050, 390, 420), PlatformData(1570, 390, 630),
        PlatformData(300, 300, 110), PlatformData(720, 315, 130),
        PlatformData(1190, 300, 130), PlatformData(1760, 310, 140),
      ],
      coins: const [
        CoinData(330, 260), CoinData(375, 260), CoinData(760, 275),
        CoinData(810, 275), CoinData(1100, 345), CoinData(1230, 260),
        CoinData(1280, 260), CoinData(1650, 345), CoinData(1800, 270),
        CoinData(1850, 270), CoinData(2040, 345),
      ],
      enemies: const [EnemyData(480, 350, 45), EnemyData(900, 350, 55),
        EnemyData(1390, 350, 45), EnemyData(1940, 350, 60)],
    ),
    LevelData(
      name: 'صحراء الأسرار', length: 2400,
      sky: const Color(0xFFFFC078), ground: const Color(0xFFB87536), decor: 1,
      platforms: const [
        PlatformData(0, 390, 380), PlatformData(480, 390, 380),
        PlatformData(950, 390, 420), PlatformData(1460, 390, 360),
        PlatformData(1910, 390, 490), PlatformData(270, 300, 120),
        PlatformData(650, 290, 120), PlatformData(1100, 305, 130),
        PlatformData(1580, 285, 130), PlatformData(2040, 300, 130),
      ],
      coins: const [
        CoinData(300, 260), CoinData(345, 260), CoinData(690, 250),
        CoinData(740, 250), CoinData(1000, 345), CoinData(1140, 265),
        CoinData(1190, 265), CoinData(1615, 245), CoinData(1660, 245),
        CoinData(2070, 260), CoinData(2120, 260), CoinData(2300, 345),
      ],
      enemies: const [EnemyData(540, 350, 55), EnemyData(810, 350, 35),
        EnemyData(1270, 350, 45), EnemyData(1730, 350, 35),
        EnemyData(2180, 350, 60)],
    ),
    LevelData(
      name: 'قمم الثلج', length: 2500,
      sky: const Color(0xFF536DAB), ground: const Color(0xFFB9E5F4), decor: 2,
      platforms: const [
        PlatformData(0, 390, 430), PlatformData(530, 390, 330),
        PlatformData(970, 390, 350), PlatformData(1430, 390, 400),
        PlatformData(1940, 390, 560), PlatformData(290, 295, 120),
        PlatformData(670, 280, 130), PlatformData(1080, 285, 120),
        PlatformData(1550, 275, 130), PlatformData(2070, 285, 150),
      ],
      coins: const [
        CoinData(320, 255), CoinData(365, 255), CoinData(710, 240),
        CoinData(755, 240), CoinData(1040, 345), CoinData(1120, 245),
        CoinData(1165, 245), CoinData(1590, 235), CoinData(1640, 235),
        CoinData(2110, 245), CoinData(2160, 245), CoinData(2360, 345),
      ],
      enemies: const [EnemyData(580, 350, 45), EnemyData(790, 350, 30),
        EnemyData(1220, 350, 40), EnemyData(1740, 350, 45),
        EnemyData(2260, 350, 55)],
    ),
  ];
}

class GamePainter extends CustomPainter {
  GamePainter({
    required this.level,
    required this.playerX,
    required this.playerY,
    required this.cameraX,
    required this.coins,
    required this.defeated,
    required this.time,
    required this.facingRight,
    required this.heroAtlas,
    required this.heroFrame,
  });

  final LevelData level;
  final double playerX, playerY, cameraX, time;
  final bool facingRight;
  final ui.Image? heroAtlas;
  final int heroFrame;
  final Set<int> coins, defeated;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.height / 450;
    canvas.save();
    canvas.scale(scale);
    final viewWidth = size.width / scale;
    _rect(canvas, 0, 0, viewWidth, 450, level.sky);
    _background(canvas, viewWidth);
    canvas.save();
    canvas.translate(-cameraX, 0);

    for (final p in level.platforms) {
      _platform(canvas, p);
    }
    for (var i = 0; i < level.coins.length; i++) {
      if (!coins.contains(i)) _coin(canvas, level.coins[i], time);
    }
    for (var i = 0; i < level.enemies.length; i++) {
      if (defeated.contains(i)) continue;
      final e = level.enemies[i];
      final x = e.x + math.sin(time * 1.7 + i) * e.range;
      _enemy(canvas, x, e.y, time);
    }
    _goal(canvas, level.length - 75);
    _drawHeroSprite(canvas);
    canvas.restore();
    _rect(canvas, 0, 426, viewWidth, 24, const Color(0xFF182A38));
    canvas.restore();
  }

  void _background(Canvas c, double width) {
    final paint = Paint();
    for (var x = -((cameraX * .22) % 360) - 100; x < width + 360; x += 360) {
      if (level.decor == 0) {
        paint.color = const Color(0xFFDAF4D5).withValues(alpha: .8);
        c.drawCircle(Offset(x + 90, 105), 42, paint);
        c.drawCircle(Offset(x + 130, 110), 32, paint);
        paint.color = const Color(0xFF4EAA73);
        c.drawOval(Rect.fromLTWH(x + 20, 330, 210, 100), paint);
        _tree(c, x + 230, 330, const Color(0xFF237D52));
      } else if (level.decor == 1) {
        paint.color = const Color(0xFFFFE2A5);
        c.drawCircle(Offset(x + 220, 100), 45, paint);
        paint.color = const Color(0xFFD69B55);
        final path = Path()..moveTo(x, 385)..lineTo(x + 160, 220)..lineTo(x + 320, 385)..close();
        c.drawPath(path, paint);
        paint.color = const Color(0xFFE6B56D);
        final p2 = Path()..moveTo(x + 180, 390)..lineTo(x + 300, 270)..lineTo(x + 420, 390)..close();
        c.drawPath(p2, paint);
        _cactus(c, x + 90, 340);
      } else {
        paint.color = const Color(0xFFDDEEFF);
        final path = Path()..moveTo(x, 390)..lineTo(x + 170, 150)..lineTo(x + 340, 390)..close();
        c.drawPath(path, paint);
        paint.color = Colors.white;
        final cap = Path()..moveTo(x + 130, 208)..lineTo(x + 170, 150)..lineTo(x + 210, 208)..lineTo(x + 170, 195)..close();
        c.drawPath(cap, paint);
        for (var j = 0; j < 5; j++) {
          final sx = x + 40 + j * 67;
          c.drawCircle(Offset(sx, 70 + (j % 2) * 80), 2.5, Paint()..color = Colors.white70);
        }
      }
    }
  }

  void _platform(Canvas c, PlatformData p) {
    _rect(c, p.x, p.y, p.width, 60, level.ground);
    _rect(c, p.x, p.y, p.width, 10, level.decor == 2 ? Colors.white : const Color(0xFF75D66B));
    final paint = Paint()..color = Colors.black.withValues(alpha: .10);
    for (double x = p.x + 12; x < p.x + p.width; x += 34) {
      c.drawRect(Rect.fromLTWH(x, p.y + 24, 17, 8), paint);
    }
  }

  void _drawHeroSprite(Canvas c) {
    final atlas = heroAtlas;
    if (atlas == null) return;
    const frameW = 48.0;
    const frameH = 60.0;
    final frame = heroFrame.clamp(0, 7);
    final col = frame % 4;
    final row = frame ~/ 4;
    final src = Rect.fromLTWH(col * frameW, row * frameH, frameW, frameH);
    final dst = Rect.fromLTWH(playerX - 15, playerY - 35, 78, 96);
    final paint = Paint()..filterQuality = FilterQuality.high;
    c.save();
    if (!facingRight) {
      c.translate(playerX * 2 + 40, 0);
      c.scale(-1, 1);
    }
    c.drawImageRect(atlas, src, dst, paint);
    c.restore();
  }

  void _enemy(Canvas c, double x, double y, double t) {
    final shell = Paint()..color = const Color(0xFF8A4BC2);
    final white = Paint()..color = Colors.white;
    final black = Paint()..color = const Color(0xFF25223C);
    c.drawOval(Rect.fromLTWH(x, y + 4, 34, 27), shell);
    c.drawCircle(Offset(x + 11, y + 14), 5, white);
    c.drawCircle(Offset(x + 24, y + 14), 5, white);
    c.drawCircle(Offset(x + 12, y + 15), 2, black);
    c.drawCircle(Offset(x + 23, y + 15), 2, black);
    c.drawOval(Rect.fromLTWH(x + 5, y + 27, 9, 5), black);
    c.drawOval(Rect.fromLTWH(x + 22, y + 27, 9, 5), black);
  }

  void _coin(Canvas c, CoinData coin, double t) {
    final pulse = .75 + .25 * math.sin(t * 6 + coin.dx);
    c.drawOval(Rect.fromCenter(center: Offset(coin.dx, coin.dy), width: 17 * pulse, height: 23),
        Paint()..color = const Color(0xFFFFD447));
    c.drawOval(Rect.fromCenter(center: Offset(coin.dx - 2, coin.dy - 1), width: 5 * pulse, height: 15),
        Paint()..color = const Color(0xFFFFF0A6));
  }

  void _goal(Canvas c, double x) {
    _rect(c, x, 220, 5, 170, const Color(0xFFEEF4F8));
    final flag = Path()..moveTo(x + 5, 222)..lineTo(x + 55, 240)..lineTo(x + 5, 260)..close();
    c.drawPath(flag, Paint()..color = const Color(0xFFFFD166));
    c.drawCircle(Offset(x + 2, 218), 7, Paint()..color = const Color(0xFFFFD166));
  }

  void _tree(Canvas c, double x, double y, Color color) {
    _rect(c, x + 20, y - 65, 12, 65, const Color(0xFF80502D));
    c.drawCircle(Offset(x + 26, y - 72), 32, Paint()..color = color);
    c.drawCircle(Offset(x + 7, y - 57), 20, Paint()..color = color);
    c.drawCircle(Offset(x + 44, y - 55), 21, Paint()..color = color);
  }

  void _cactus(Canvas c, double x, double y) {
    final p = Paint()..color = const Color(0xFF3C8D54);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y - 65, 18, 65), const Radius.circular(8)), p);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - 14, y - 42, 15, 10), const Radius.circular(5)), p);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - 14, y - 55, 10, 24), const Radius.circular(5)), p);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 16, y - 34, 15, 10), const Radius.circular(5)), p);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 21, y - 48, 10, 24), const Radius.circular(5)), p);
  }

  void _rect(Canvas c, double x, double y, double w, double h, Color color) {
    c.drawRect(Rect.fromLTWH(x, y, w, h), Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}
