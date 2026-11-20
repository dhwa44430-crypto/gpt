import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
  Widget build(BuildContext context) => const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: AdventureScreen(),
  );
}

const double groundY = 390;
const double gameHeroW = 76;
const double gameHeroH = 96;
const double gameWorldW = 4300;
const List<Rect> gamePlatforms = [
  Rect.fromLTWH(0,390,760,120), Rect.fromLTWH(820,390,520,120),
  Rect.fromLTWH(1400,390,690,120), Rect.fromLTWH(2150,390,520,120),
  Rect.fromLTWH(2730,390,690,120), Rect.fromLTWH(3480,390,820,120),
  Rect.fromLTWH(350,285,190,70), Rect.fromLTWH(610,220,180,70),
  Rect.fromLTWH(1030,290,190,70), Rect.fromLTWH(1260,225,180,70),
  Rect.fromLTWH(1660,285,200,70), Rect.fromLTWH(1900,215,190,70),
  Rect.fromLTWH(2370,285,180,70), Rect.fromLTWH(2580,220,190,70),
  Rect.fromLTWH(3000,280,200,70), Rect.fromLTWH(3250,210,190,70),
  Rect.fromLTWH(3700,290,180,70),
];
const List<double> coinXs = [
  210,390,445,650,700,910,1080,1130,1320,1510,1710,1770,1940,2010,
  2250,2430,2630,2820,3050,3120,3290,3550,3790,3890,4050,
];
const List<double> enemyXs = [900,1510,1860,2260,2860,3190,3570];

class AdventureScreen extends StatefulWidget {
  const AdventureScreen({super.key});
  @override
  State<AdventureScreen> createState() => _AdventureScreenState();
}

class _AdventureScreenState extends State<AdventureScreen>
    with SingleTickerProviderStateMixin {
  final Map<String, ui.Image> art = {};
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  int coins = 0, lives = 3;
  double playerX = 90, playerY = 294, vx = 0, vy = 0, camera = 0;
  double elapsed = 0, invulnerable = 0;
  bool left = false, right = false, onGround = true, facingRight = true;
  bool gameOver = false, finished = false;
  final Set<int> collected = {};
  final Set<int> defeated = {};

  static const double ground = groundY, heroW = gameHeroW, heroH = gameHeroH, worldW = gameWorldW;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    _loadArt();
  }

  Future<void> _loadArt() async {
    const names = [
      'hero_idle','hero_run','hero_run2','hero_jump','hero_hurt',
      'enemy_slime','enemy_spike','enemy_butterfly','coin','checkpoint',
      'tree','pine','bush','rock','cloud','background_hills',
      'platform_grass','platform_stone',
    ];
    for (final name in names) {
      try {
        final data = await rootBundle.load('assets/images/$name.png');
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        art[name] = frame.image;
      } catch (_) {
        // Keep the painted sky and fallback character visible if one image is missing.
      }
    }
    if (mounted) setState(() {});
  }

  void _tick(Duration now) {
    if (!mounted) return;
    final dt = _last == Duration.zero
        ? 0.0
        : ((now - _last).inMicroseconds / 1000000).clamp(0.0, 0.035);
    _last = now;
    if (!gameOver && !finished && dt > 0) _update(dt);
    setState(() {});
  }

  void _update(double dt) {
    elapsed += dt;
    if (invulnerable > 0) invulnerable -= dt;
    final input = (right ? 1.0 : 0.0) - (left ? 1.0 : 0.0);
    if (input != 0) {
      vx = input * 330;
      facingRight = input > 0;
    } else {
      vx *= math.pow(0.0008, dt).toDouble();
      if (vx.abs() < 5) vx = 0;
    }
    final oldBottom = playerY + heroH;
    playerX = (playerX + vx * dt).clamp(0.0, worldW - heroW);
    vy += 1900 * dt;
    playerY += vy * dt;
    onGround = false;
    for (final p in gamePlatforms) {
      if (playerX + heroW - 12 > p.left && playerX + 12 < p.right &&
          vy >= 0 && oldBottom <= p.top + 14 && playerY + heroH >= p.top) {
        playerY = p.top - heroH;
        vy = 0;
        onGround = true;
      }
    }
    if (playerY > 620) _hurt();
    for (var i = 0; i < enemyXs.length; i++) {
      if (defeated.contains(i)) continue;
      final ex = enemyXs[i] + math.sin(elapsed * 1.7 + i) * 62;
      final ey = i == 2 ? 143 : ground - 68;
      final hit = Rect.fromLTWH(playerX+12,playerY+12,heroW-24,heroH-16)
          .overlaps(Rect.fromLTWH(ex+8,ey+10,62,58));
      if (hit && invulnerable <= 0) {
        if (vy > 120 && playerY + heroH - ey < 48) {
          defeated.add(i);
          vy = -420;
        } else {
          _hurt();
        }
      }
    }
    for (var i=0;i<coinXs.length;i++) {
      if (collected.contains(i)) continue;
      if (Rect.fromLTWH(playerX+12,playerY+12,heroW-24,heroH-20)
          .overlaps(Rect.fromLTWH(coinXs[i], i.isEven?300:325,42,48))) {
        collected.add(i); coins++;
      }
    }
    camera = (playerX - 420).clamp(0.0, worldW - 900);
    if (playerX > 4120) finished = true;
  }

  void _hurt() {
    if (invulnerable > 0) return;
    lives--;
    invulnerable = 1.5;
    vy = -420;
    if (lives <= 0) {
      gameOver = true;
    } else {
      playerX = math.max(0.0, playerX - 130);
      playerY = ground - heroH;
    }
  }

  void _jump() {
    if (!gameOver && !finished && onGround) {
      vy = -760;
      onGround = false;
    }
  }

  void _restart() {
    setState(() {
      coins=0; lives=3; playerX=90; playerY=ground-heroH;
      vx=0; vy=0; camera=0; invulnerable=0; elapsed=0;
      onGround=true; left=false; right=false; gameOver=false; finished=false;
      collected.clear(); defeated.clear();
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    for (final image in art.values) { image.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff73c9f4),
    body: Stack(fit: StackFit.expand, children: [
      CustomPaint(painter: AdventurePainter(
        art: art, playerX: playerX, playerY: playerY, camera: camera,
        elapsed: elapsed, vx: vx, onGround: onGround, facingRight: facingRight,
        invulnerable: invulnerable, collected: collected, defeated: defeated,
      )),
      Positioned(top:12,left:14,child:_hud('◆  $coins',const Color(0xffffdc55))),
      Positioned(top:12,right:14,child:_hud('♥  $lives',const Color(0xffff8585))),
      Positioned(left:18,bottom:18,child:Row(children:[
        _button(Icons.arrow_back_rounded,()=>left=true,()=>left=false),
        const SizedBox(width:12),
        _button(Icons.arrow_forward_rounded,()=>right=true,()=>right=false),
      ])),
      Positioned(right:24,bottom:18,child:_button(Icons.arrow_upward_rounded,_jump,()=>{},big:true)),
      if (gameOver || finished) Center(child:Container(
        padding:const EdgeInsets.all(24),
        decoration:BoxDecoration(color:const Color(0xee17334a),borderRadius:BorderRadius.circular(22),border:Border.all(color:const Color(0xffffd45c),width:3)),
        child:Column(mainAxisSize:MainAxisSize.min,children:[
          Text(finished?'أحسنت يا بطل!':'انتهت المحاولة!',style:const TextStyle(color:Colors.white,fontSize:27,fontWeight:FontWeight.w900)),
          const SizedBox(height:14),
          ElevatedButton.icon(onPressed:_restart,icon:const Icon(Icons.refresh),label:const Text('العب مرة أخرى')),
        ]),
      )),
    ]),
  );

  Widget _hud(String text,Color color)=>Container(
    padding:const EdgeInsets.symmetric(horizontal:15,vertical:8),
    decoration:BoxDecoration(color:const Color(0xd91a3447),borderRadius:BorderRadius.circular(18),border:Border.all(color:Colors.white24)),
    child:Text(text,style:TextStyle(color:color,fontSize:19,fontWeight:FontWeight.w900)),
  );

  Widget _button(IconData icon,VoidCallback down,VoidCallback up,{bool big=false})=>Listener(
    onPointerDown:(_){down();},
    onPointerUp:(_){up();},
    onPointerCancel:(_){up();},
    child:Container(width:big?76:66,height:big?76:66,
      decoration:BoxDecoration(color:const Color(0xbb17334a),shape:BoxShape.circle,border:Border.all(color:Colors.white70,width:2),boxShadow:const [BoxShadow(color:Colors.black26,blurRadius:8,offset:Offset(0,4))]),
      child:Icon(icon,color:Colors.white,size:big?42:34)),
  );
}

class AdventurePainter extends CustomPainter {
  AdventurePainter({required this.art,required this.playerX,required this.playerY,
    required this.camera,required this.elapsed,required this.vx,required this.onGround,
    required this.facingRight,required this.invulnerable,required this.collected,required this.defeated});
  final Map<String,ui.Image> art;
  final double playerX,playerY,camera,elapsed,vx,invulnerable;
  final bool onGround,facingRight;
  final Set<int> collected,defeated;

  
  @override
  void paint(Canvas canvas,Size size) {
    final sx=size.width/900, sy=size.height/480;
    canvas.save();
    canvas.scale(sx,sy);
    final sky=Paint()..shader=const LinearGradient(
      begin:Alignment.topCenter,end:Alignment.bottomCenter,
      colors:[Color(0xff65c6f4),Color(0xffc6edff),Color(0xffffe7a8)],
    ).createShader(const Rect.fromLTWH(0,0,900,480));
    canvas.drawRect(const Rect.fromLTWH(0,0,900,480),sky);

    _image(canvas,'background_hills',Rect.fromLTWH(-camera*.15,120,1100,390));
    for(var i=0;i<8;i++) {
      _image(canvas,'cloud',Rect.fromLTWH(i*520.0-camera*.25,25+(i%3)*32,145,95));
    }
    for(final x in [120.0,520,950,1450,2050,2480,2950,3420,3950]) {
      _image(canvas,x.toInt().isEven?'tree':'pine',Rect.fromLTWH(x-camera,groundY-165,145,165));
    }

    for(final p in gamePlatforms) {
      final key=p.top>=380?'platform_grass':'platform_stone';
      for(double x=p.left;x<p.right;x+=128) {
        final w=math.min(128.0,p.right-x);
        _image(canvas,key,Rect.fromLTWH(x-camera,p.top,w,p.height));
      }
    }
    for(final x in [760.0,1340,2090,2670,3420]) {
      _image(canvas,'rock',Rect.fromLTWH(x-camera,groundY-55,55,55));
      _image(canvas,'bush',Rect.fromLTWH(x+90-camera,groundY-72,90,72));
    }
    for(var i=0;i<coinXs.length;i++) {
      if(!collected.contains(i)) _image(canvas,'coin',Rect.fromLTWH(coinXs[i]-camera,i.isEven?300:325,42,48));
    }
    for(var i=0;i<enemyXs.length;i++) {
      if(defeated.contains(i)) continue;
      final x=enemyXs[i]+math.sin(elapsed*1.7+i)*62;
      final key=i==2?'enemy_spike':(i==5?'enemy_butterfly':'enemy_slime');
      _image(canvas,key,Rect.fromLTWH(x-camera,i==2?143:groundY-68,76,70));
    }
    _image(canvas,'checkpoint',Rect.fromLTWH(4140-camera,groundY-190,110,190));

    final hero=invulnerable>0?'hero_hurt':(!onGround?'hero_jump':vx.abs()>35?(elapsed%0.24<0.12?'hero_run':'hero_run2'):'hero_idle');
    if(invulnerable<=0 || (elapsed*12).floor().isEven) {
      _drawAnimeHero(canvas,Rect.fromLTWH(playerX-camera,playerY,gameHeroW,gameHeroH),hero,flip:!facingRight);
    }
    canvas.restore();
  }


  // Original human anime hero, drawn independently from the environment sprites.
  void _drawAnimeHero(Canvas canvas,Rect dst,String pose,{bool flip=false}) {
    canvas.save();
    canvas.translate(dst.left,dst.top);
    canvas.scale(dst.width/100,dst.height/120);
    if(flip) {
      canvas.translate(100,0);
      canvas.scale(-1,1);
    }
    final outline=Paint()..color=const Color(0xff30202a);
    final skin=Paint()..color=const Color(0xffffc58f);
    final hair=Paint()..color=const Color(0xff48251d);
    final hairLight=Paint()..color=const Color(0xff87452b);
    final red=Paint()..color=const Color(0xffe7472f);
    final redShade=Paint()..color=const Color(0xffa92e2a);
    final scarf=Paint()..color=const Color(0xff08aeb5);
    final scarfShade=Paint()..color=const Color(0xff087b88);
    final shirt=Paint()..color=const Color(0xfffff0d5);
    final pants=Paint()..color=const Color(0xff26354b);
    final boot=Paint()..color=const Color(0xff754027);
    final glove=Paint()..color=const Color(0xff543426);
    final stroke=Paint()..color=const Color(0xff30202a)..style=PaintingStyle.stroke..strokeWidth=3.2..strokeJoin=StrokeJoin.round..strokeCap=StrokeCap.round;
    final running=pose=='hero_run' || pose=='hero_run2';
    final jumping=pose=='hero_jump';
    final hurt=pose=='hero_hurt';
    final swing=running ? (pose=='hero_run'?1.0:-1.0) : 0.0;
    // Legs and sturdy adventure boots.
    final legY=jumping?72.0: (running?76.0:78.0);
    final leftLeg=Path()
      ..moveTo(39,legY)..lineTo(34+(running?8*swing:0),98)
      ..lineTo(25+(running?8*swing:0),104)..lineTo(43+(running?8*swing:0),108)
      ..lineTo(52,legY+3)..close();
    final rightLeg=Path()
      ..moveTo(57,legY)..lineTo(65-(running?8*swing:0),96)
      ..lineTo(75-(running?8*swing:0),101)..lineTo(91-(running?8*swing:0),105)
      ..lineTo(88-(running?8*swing:0),111)..lineTo(68,108)..lineTo(51,84)..close();
    canvas.drawPath(leftLeg,outline); canvas.drawPath(leftLeg,Paint()..color=const Color(0xff34445d));
    canvas.drawPath(rightLeg,outline); canvas.drawPath(rightLeg,pants);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(17+(running?8*swing:0),99,28,14),const Radius.circular(6)),outline);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(17+(running?8*swing:0),100,26,11),const Radius.circular(5)),boot);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(68-(running?8*swing:0),101,29,14),outline);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(69-(running?8*swing:0),102,27,11),const Radius.circular(5)),boot);
    // Torso, shirt and short red jacket.
    final body=RRect.fromRectAndRadius(Rect.fromLTWH(27,48,48,38),const Radius.circular(13));
    canvas.drawRRect(body,outline);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(29,49,44,34),const Radius.circular(11)),red);
    canvas.drawPath(Path()..moveTo(46,50)..lineTo(56,50)..lineTo(57,81)..lineTo(46,81)..close(),shirt);
    canvas.drawLine(const Offset(51,53),const Offset(51,80),stroke);
    canvas.drawCircle(const Offset(65,61),2.4,Paint()..color=const Color(0xffffd45c));
    canvas.drawCircle(const Offset(65,72),2.4,Paint()..color=const Color(0xffffd45c));
    // Arms swing with the run cycle.
    final armA=Path()..moveTo(31,55)..quadraticBezierTo(18,62+(running?12*swing:0),18,75+(running?10*swing:0))..lineTo(27,79+(running?10*swing:0))..lineTo(39,64)..close();
    final armB=Path()..moveTo(68,55)..quadraticBezierTo(82,61-(running?12*swing:0),83,73-(running?10*swing:0))..lineTo(74,80-(running?10*swing:0))..lineTo(61,65)..close();
    canvas.drawPath(armA,outline); canvas.drawPath(armA,red);
    canvas.drawPath(armB,outline); canvas.drawPath(armB,red);
    canvas.drawCircle(Offset(22,76+(running?10*swing:0)),7,outline);
    canvas.drawCircle(Offset(22,76+(running?10*swing:0)),5.5,glove);
    canvas.drawCircle(Offset(80,74-(running?10*swing:0)),7,outline);
    canvas.drawCircle(Offset(80,74-(running?10*swing:0)),5.5,glove);
    // Neck and flowing teal scarf.
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(43,39,17,17),const Radius.circular(6)),skin);
    final scarfTail=Path()..moveTo(38,46)..lineTo(7,38)..lineTo(18,53)..lineTo(34,55)..close();
    canvas.drawPath(scarfTail,outline); canvas.drawPath(scarfTail,scarf);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(35,42,34,13),const Radius.circular(7)),outline);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(37,43,30,9),const Radius.circular(5)),scarf);
    canvas.drawPath(Path()..moveTo(62,49)..lineTo(77,62)..lineTo(68,72)..lineTo(58,57)..close(),outline);
    canvas.drawPath(Path()..moveTo(63,50)..lineTo(74,62)..lineTo(68,68)..lineTo(60,55)..close(),scarfShade);
    // Large expressive anime face.
    canvas.drawOval(const Rect.fromLTWH(30,9,43,43),outline);
    canvas.drawOval(const Rect.fromLTWH(32,10,39,39),skin);
    canvas.drawOval(const Rect.fromLTWH(38,25,10,14),outline);
    canvas.drawOval(const Rect.fromLTWH(56,25,10,14),outline);
    canvas.drawOval(const Rect.fromLTWH(40,27,6,10),Paint()..color=const Color(0xff6a351f));
    canvas.drawOval(const Rect.fromLTWH(58,27,6,10),Paint()..color=const Color(0xff6a351f));
    canvas.drawCircle(const Offset(43,29),2,Paint()..color=Colors.white);
    canvas.drawCircle(const Offset(61,29),2,Paint()..color=Colors.white);
    canvas.drawLine(const Offset(37,23),const Offset(48,21),stroke);
    canvas.drawLine(const Offset(55,21),const Offset(67,23),stroke);
    if(hurt) {
      canvas.drawArc(const Rect.fromLTWH(47,37,12,7),0,math.pi, false,stroke);
    } else {
      canvas.drawArc(const Rect.fromLTWH(47,35,12,8),0,math.pi, false,stroke);
    }
    // Distinct spiky anime hair silhouette and highlights.
    final hairShape=Path()..moveTo(31,29)..lineTo(24,20)..lineTo(34,21)
      ..lineTo(29,9)..lineTo(43,17)..lineTo(47,3)..lineTo(54,16)
      ..lineTo(66,6)..lineTo(63,20)..lineTo(78,16)..lineTo(70,29)
      ..lineTo(68,35)..lineTo(63,24)..lineTo(55,20)..lineTo(46,22)
      ..lineTo(37,20)..lineTo(32,34)..close();
    canvas.drawPath(hairShape,outline);
    canvas.drawPath(Path()..moveTo(30,20)..lineTo(40,21)..lineTo(34,12)..close(),hairLight);
    canvas.drawPath(Path()..moveTo(43,17)..lineTo(49,5)..lineTo(53,18)..close(),hairLight);
    canvas.drawPath(Path()..moveTo(57,18)..lineTo(66,9)..lineTo(63,21)..close(),hairLight);
    if(hurt) {
      canvas.drawLine(const Offset(80,8),const Offset(91,0),Paint()..color=const Color(0xffffd34e)..strokeWidth=4);
      canvas.drawLine(const Offset(83,16),const Offset(98,16),Paint()..color=const Color(0xffffd34e)..strokeWidth=3);
    }
    canvas.restore();
  }

  void _image(Canvas canvas,String name,Rect dst,{bool flip=false}) {
    final image=art[name];
    if(image==null) {
      if(name.startsWith('hero')) {
        final r=RRect.fromRectAndRadius(dst.deflate(8),const Radius.circular(16));
        canvas.drawRRect(r,Paint()..color=const Color(0xffe65b38));
        canvas.drawCircle(Offset(dst.center.dx,dst.top+24),15,Paint()..color=const Color(0xffffd3a1));
      } else if(name.startsWith('platform')) {
        canvas.drawRect(dst,Paint()..color=const Color(0xff55a64c));
      }
      return;
    }
    if(dst.right < -100 || dst.left > 1000) return;
    final src=Rect.fromLTWH(0,0,image.width.toDouble(),image.height.toDouble());
    final paint=Paint()..filterQuality=FilterQuality.medium;
    if(flip) {
      canvas.save();
      canvas.translate(dst.left*2+dst.width,0);
      canvas.scale(-1,1);
      canvas.drawImageRect(image,src,dst,paint);
      canvas.restore();
    } else {
      canvas.drawImageRect(image,src,dst,paint);
    }
  }

  @override
  bool shouldRepaint(covariant AdventurePainter old)=>true;
}