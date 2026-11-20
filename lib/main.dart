import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const AdventureApp());
}

class AdventureApp extends StatelessWidget {
  const AdventureApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'مغامرات ليث',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFFFFB52E)),
        home: const AdventureScreen(),
      );
}

class AdventureScreen extends StatefulWidget {
  const AdventureScreen({super.key});
  @override
  State<AdventureScreen> createState() => _AdventureScreenState();
}

class _AdventureScreenState extends State<AdventureScreen> {
  late final AdventureGame game;

  @override
  void initState() {
    super.initState();
    game = AdventureGame();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            GameWidget(game: game),
            Positioned(
              top: 12,
              left: 14,
              child: ValueListenableBuilder<int>(
                valueListenable: game.coins,
                builder: (_, value, __) => _hud('◆  $value', const Color(0xFFFFD84D)),
              ),
            ),
            Positioned(
              top: 12,
              right: 14,
              child: ValueListenableBuilder<int>(
                valueListenable: game.lives,
                builder: (_, value, __) => _hud('♥  $value', const Color(0xFFFF7777)),
              ),
            ),
            Positioned(
              left: 18,
              bottom: 18,
              child: Row(
                children: [
                  _control(Icons.arrow_back_rounded, onDown: () => game.left = true, onUp: () => game.left = false),
                  const SizedBox(width: 12),
                  _control(Icons.arrow_forward_rounded, onDown: () => game.right = true, onUp: () => game.right = false),
                ],
              ),
            ),
            Positioned(
              right: 24,
              bottom: 18,
              child: _control(Icons.arrow_upward_rounded, large: true,
                  onDown: game.pressJump, onUp: () {}),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: game.finished,
              builder: (_, done, __) => done
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: const Color(0xEE17334A), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFFFD45C), width: 3)),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Text('أحسنت يا بطل!', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          const Text('وصلت إلى نهاية المرحلة', style: TextStyle(color: Colors.white70, fontSize: 16)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(onPressed: game.restart, icon: const Icon(Icons.replay), label: const Text('العب مرة أخرى')),
                        ]),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: game.gameOver,
              builder: (_, over, __) => over
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: const Color(0xEE17334A), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFFF7777), width: 3)),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Text('انتهت المحاولة!', style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(onPressed: game.restart, icon: const Icon(Icons.refresh), label: const Text('حاول من جديد')),
                        ]),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );

  Widget _hud(String value, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xD91A3447), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white24)),
        child: Text(value, style: TextStyle(color: color, fontSize: 19, fontWeight: FontWeight.w900)),
      );

  Widget _control(IconData icon, {bool large = false, required VoidCallback onDown, required VoidCallback onUp}) => Listener(
        onPointerDown: (_) => onDown(),
        onPointerUp: (_) => onUp(),
        onPointerCancel: (_) => onUp(),
        child: Container(
          width: large ? 76 : 66,
          height: large ? 76 : 66,
          decoration: BoxDecoration(color: const Color(0xBB17334A), shape: BoxShape.circle, border: Border.all(color: Colors.white70, width: 2), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))]),
          child: Icon(icon, color: Colors.white, size: large ? 42 : 34),
        ),
      );
}

class _Platform {
  const _Platform(this.x, this.y, this.width, this.height, this.image);
  final double x, y, width, height;
  final String image;
}

class _Coin {
  _Coin(this.x, this.y);
  final double x, y;
  bool taken = false;
}

class _Enemy {
  _Enemy(this.x, this.y, this.minX, this.maxX, this.image);
  double x, y;
  final double minX, maxX;
  final String image;
  double direction = 1;
  bool defeated = false;
}

class AdventureGame extends FlameGame {
  static const double worldWidth = 4300;
  static const double groundY = 390;
  static const double heroW = 76;
  static const double heroH = 96;

  final ValueNotifier<int> coins = ValueNotifier<int>(0);
  final ValueNotifier<int> lives = ValueNotifier<int>(3);
  final ValueNotifier<bool> finished = ValueNotifier<bool>(false);
  final ValueNotifier<bool> gameOver = ValueNotifier<bool>(false);
  final Map<String, ui.Image> art = {};
  final List<_Platform> platforms = [];
  final List<_Coin> pickups = [];
  final List<_Enemy> enemies = [];

  double playerX = 90, playerY = groundY - heroH, velocityX = 0, velocityY = 0;
  double cameraX = 0, animationClock = 0, invulnerable = 0;
  bool left = false, right = false, onGround = true, facingRight = true;

  final List<String> assetNames = const [
    'hero_idle','hero_run','hero_run2','hero_jump','hero_hurt','hero_crouch',
    'coin','gem','crate_sun','crate','block_moss','enemy_spike','enemy_slime','enemy_butterfly',
    'checkpoint','spring','treasure','tree','pine','bush','flowers','rock','cloud','background_hills',
    'bridge','platform_grass','platform_stone','platform_column',
  ];

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    for (final name in assetNames) {
      art[name] = await images.load('images/$name.png');
    }
    _makeLevel();
  }

  void _makeLevel() {
    platforms.clear(); pickups.clear(); enemies.clear();
    platforms.add(const _Platform(0, groundY, 760, 120, 'platform_grass'));
    platforms.add(const _Platform(820, groundY, 520, 120, 'platform_grass'));
    platforms.add(const _Platform(1400, groundY, 690, 120, 'platform_grass'));
    platforms.add(const _Platform(2150, groundY, 520, 120, 'platform_grass'));
    platforms.add(const _Platform(2730, groundY, 690, 120, 'platform_grass'));
    platforms.add(const _Platform(3480, groundY, 820, 120, 'platform_grass'));
    platforms.add(const _Platform(350, 285, 190, 70, 'platform_stone'));
    platforms.add(const _Platform(610, 220, 180, 70, 'platform_grass'));
    platforms.add(const _Platform(1030, 290, 190, 70, 'platform_stone'));
    platforms.add(const _Platform(1260, 225, 180, 70, 'platform_grass'));
    platforms.add(const _Platform(1660, 285, 200, 70, 'platform_stone'));
    platforms.add(const _Platform(1900, 215, 190, 70, 'platform_grass'));
    platforms.add(const _Platform(2370, 285, 180, 70, 'platform_stone'));
    platforms.add(const _Platform(2580, 220, 190, 70, 'platform_grass'));
    platforms.add(const _Platform(3000, 280, 200, 70, 'platform_stone'));
    platforms.add(const _Platform(3250, 210, 190, 70, 'platform_grass'));
    platforms.add(const _Platform(3700, 290, 180, 70, 'platform_stone'));

    for (final x in [210.0, 390, 445, 650, 700, 910, 1080, 1130, 1320, 1510, 1710, 1770, 1940, 2010, 2250, 2430, 2630, 2820, 3050, 3120, 3290, 3550, 3790, 3890, 4050]) {
      pickups.add(_Coin(x.toDouble(), x % 2 == 0 ? 300.0 : 325.0));
    }
    for (final x in [900.0, 1510, 2260, 2860, 3570]) {
      enemies.add(_Enemy(x.toDouble(), groundY - 68, x.toDouble() - 100, x.toDouble() + 110, 'enemy_slime'));
    }
    enemies.add(_Enemy(1860, 215 - 72, 1650, 2050, 'enemy_spike'));
    enemies.add(_Enemy(3190, 210 - 78, 3000, 3400, 'enemy_butterfly'));
  }

  void pressJump() {
    if (gameOver.value || finished.value) return;
    if (onGround) {
      velocityY = -760;
      onGround = false;
    }
    
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameOver.value || finished.value || art.isEmpty) return;
    final step = dt.clamp(0.0, 0.04).toDouble();
    animationClock += step;
    if (invulnerable > 0) invulnerable -= step;

    final input = (right ? 1.0 : 0.0) - (left ? 1.0 : 0.0);
    if (input != 0) {
      velocityX = input * 330;
      facingRight = input > 0;
    } else {
      velocityX *= math.pow(0.0008, step).toDouble();
      if (velocityX.abs() < 5) velocityX = 0;
    }
    final previousBottom = playerY + heroH;
    playerX = (playerX + velocityX * step).clamp(0, worldWidth - heroW).toDouble();
    velocityY += 1900 * step;
    playerY += velocityY * step;
    onGround = false;

    for (final p in platforms) {
      final horizontal = playerX + heroW - 12 > p.x && playerX + 12 < p.x + p.width;
      if (horizontal && velocityY >= 0 && previousBottom <= p.y + 14 && playerY + heroH >= p.y) {
        playerY = p.y - heroH;
        velocityY = 0;
        onGround = true;
      }
    }
    if (playerY > 650) _hurt();

    for (final enemy in enemies) {
      if (enemy.defeated) continue;
      enemy.x += enemy.direction * 82 * step;
      if (enemy.x < enemy.minX || enemy.x > enemy.maxX) enemy.direction *= -1;
      final hit = Rect.fromLTWH(playerX + 12, playerY + 12, heroW - 24, heroH - 16)
          .overlaps(Rect.fromLTWH(enemy.x + 8, enemy.y + 10, 62, 58));
      if (hit && invulnerable <= 0) {
        if (velocityY > 120 && playerY + heroH - enemy.y < 48) {
          enemy.defeated = true;
          velocityY = -420;
        } else {
          _hurt();
        }
      }
    }
    for (final coin in pickups) {
      if (coin.taken) continue;
      if (Rect.fromLTWH(playerX + 12, playerY + 12, heroW - 24, heroH - 20)
          .overlaps(Rect.fromLTWH(coin.x, coin.y, 42, 48))) {
        coin.taken = true;
        coins.value++;
      }
    }
    cameraX = (playerX - 450).clamp(0, worldWidth - 900).toDouble();
    if (playerX > 4120) finished.value = true;
  }

  void _hurt() {
    if (invulnerable > 0) return;
    lives.value--;
    invulnerable = 1.6;
    velocityY = -420;
    if (lives.value <= 0) {
      gameOver.value = true;
    } else {
      playerX = math.max(0.0, playerX - 130).toDouble();
      playerY = groundY - heroH;
    }
  }

  void restart() {
    playerX = 90;
    playerY = groundY - heroH;
    velocityX = 0;
    velocityY = 0;
    cameraX = 0;
    invulnerable = 0;
    onGround = true;
    left = right = false;
    coins.value = 0;
    lives.value = 3;
    finished.value = false;
    gameOver.value = false;
    _makeLevel();
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    if (art.isEmpty) return;
    final sx = size.x / 900;
    final sy = size.y / 480;
    canvas.save();
    canvas.scale(sx, sy);
    _draw(canvas, 'background_hills', Rect.fromLTWH(0, 0, 1100, 480), cameraX * 0.16);
    for (var i = 0; i < 9; i++) {
      _draw(canvas, 'cloud', Rect.fromLTWH(i * 520.0, 30 + (i % 3) * 30.0, 170, 105), cameraX * 0.28);
    }
    for (final x in [120.0, 520, 950, 1450, 2050, 2480, 2950, 3420, 3950]) {
      _draw(canvas, x % 2 == 0 ? 'tree' : 'pine', Rect.fromLTWH(x.toDouble(), groundY - 175, 150, 180), cameraX);
    }
    for (final p in platforms) {
      final tileWidth = 180.0;
      for (double x = p.x; x < p.x + p.width; x += tileWidth) {
        final w = math.min(tileWidth, p.x + p.width - x);
        _draw(canvas, p.image, Rect.fromLTWH(x, p.y, w, p.height), cameraX);
      }
    }
    for (final x in [760.0, 1340, 2090, 2670, 3420]) {
      _draw(canvas, 'rock', Rect.fromLTWH(x.toDouble(), groundY - 58, 55, 58), cameraX);
      _draw(canvas, 'bush', Rect.fromLTWH(x.toDouble() + 90, groundY - 82, 100, 82), cameraX);
    }
    for (final coin in pickups) {
      if (!coin.taken) _draw(canvas, 'coin', Rect.fromLTWH(coin.x, coin.y, 42, 48), cameraX);
    }
    for (final enemy in enemies) {
      if (!enemy.defeated) _draw(canvas, enemy.image, Rect.fromLTWH(enemy.x, enemy.y, 76, 70), cameraX, flip: enemy.direction < 0);
    }
    _draw(canvas, 'checkpoint', Rect.fromLTWH(4140, groundY - 190, 110, 190), cameraX);
    final hero = invulnerable > 0 ? 'hero_hurt' : (!onGround ? 'hero_jump' : velocityX.abs() > 35 ? (animationClock % 0.24 < 0.12 ? 'hero_run' : 'hero_run2') : 'hero_idle');
    if (invulnerable <= 0 || (animationClock * 12).floor().isEven) {
      _draw(canvas, hero, Rect.fromLTWH(playerX, playerY, heroW, heroH), cameraX, flip: !facingRight);
    }
    canvas.restore();
  }

  void _draw(ui.Canvas canvas, String name, Rect destination, double camera, {bool flip = false}) {
    final image = art[name];
    if (image == null) return;
    final left = destination.left - camera;
    if (left > 1000 || left + destination.width < -120) return;
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromLTWH(left, destination.top, destination.width, destination.height);
    if (flip) {
      canvas.save();
      canvas.translate(dst.left * 2 + dst.width, 0);
      canvas.scale(-1, 1);
      canvas.drawImageRect(image, src, dst, ui.Paint()..filterQuality = ui.FilterQuality.medium);
      canvas.restore();
    } else {
      canvas.drawImageRect(image, src, dst, ui.Paint()..filterQuality = ui.FilterQuality.medium);
    }
  }
}