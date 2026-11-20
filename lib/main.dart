import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const CityBuilderApp());
}

class CityBuilderApp extends StatelessWidget {
  const CityBuilderApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false, title: 'مدينتي',
    theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF101B25), colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF36C7A0), brightness: Brightness.dark), useMaterial3: true),
    home: const CityScreen(),
  );
}

enum Tool { select, road, home, shop, factory, power, park, bulldoze }
class Tile {
  Tile({this.kind = Tool.select, this.level = 0});
  Tool kind;
  int level;
}

class CityScreen extends StatefulWidget {
  const CityScreen({super.key});
  @override
  State<CityScreen> createState() => _CityScreenState();
}

class _CityScreenState extends State<CityScreen> {
  static const n = 18;
  late final List<List<Tile>> map;
  late final Timer timer;
  Tool tool = Tool.home;
  int money = 18000, population = 12, jobs = 8, happiness = 76, day = 1, growth = 0, roads = 28, buildings = 5;
  String message = 'اختر البناء ثم اضغط على أرض المدينة';
  bool help = true;
  final prices = const {Tool.road:45, Tool.home:130, Tool.shop:210, Tool.factory:190, Tool.power:650, Tool.park:160, Tool.bulldoze:0, Tool.select:0};

  @override
  void initState() {
    super.initState();
    map = List.generate(n, (_) => List.generate(n, (_) => Tile()));
    for (int c=1;c<17;c++) { map[9][c].kind=Tool.road; }
    for (int r=3;r<15;r++) { if(r!=9) map[r][9].kind=Tool.road; }
    map[8][8] = Tile(kind:Tool.power,level:1);
    map[8][7] = Tile(kind:Tool.home,level:2);
    map[8][10] = Tile(kind:Tool.shop,level:1);
    map[10][8] = Tile(kind:Tool.home,level:1);
    map[10][10] = Tile(kind:Tool.park,level:1);
    timer = Timer.periodic(const Duration(seconds:3), (_) => simulate());
  }

  @override
  void dispose() { timer.cancel(); super.dispose(); }

  String nameOf(Tool t) {
    switch(t) {
      case Tool.road: return 'طريق';
      case Tool.home: return 'منطقة سكنية';
      case Tool.shop: return 'منطقة تجارية';
      case Tool.factory: return 'منطقة صناعية';
      case Tool.power: return 'محطة كهرباء';
      case Tool.park: return 'حديقة';
      case Tool.bulldoze: return 'إزالة';
      case Tool.select: return 'تحديد';
    }
  }
  bool get powered => map.expand((r)=>r).any((t)=>t.kind==Tool.power);
  bool hasRoad(int r,int c) {
    for(final d in const [[0,1],[0,-1],[1,0],[-1,0]]) {
      final y=r+d[0], x=c+d[1];
      if(y>=0&&y<n&&x>=0&&x<n&&map[y][x].kind==Tool.road) return true;
    }
    return false;
  }

  void place(int r,int c) {
    if(r<0||r>=n||c<0||c>=n) return;
    final t=map[r][c];
    if(tool==Tool.select) { setState(()=>message=t.kind==Tool.select?'أرض فارغة':nameOf(t.kind)+' • المستوى '+t.level.toString()); return; }
    if(tool==Tool.bulldoze) {
      if(t.kind==Tool.select) { setState(()=>message='لا يوجد شيء لإزالته هنا'); return; }
      setState(() {
        if(t.kind==Tool.road) roads--; else buildings--;
        if(t.kind==Tool.home) population=math.max(0,population-4).toInt();
        if(t.kind==Tool.shop||t.kind==Tool.factory) jobs=math.max(0,jobs-3).toInt();
        t.kind=Tool.select; t.level=0; message='تمت إزالة البناء';
      });
      return;
    }
    if(t.kind!=Tool.select) { setState(()=>message='هذه القطعة مشغولة، أزل البناء أولاً'); return; }
    if(tool!=Tool.road&&!hasRoad(r,c)) { setState(()=>message='يجب أن يكون المبنى بجانب طريق'); return; }
    if(tool==Tool.power&&powered) { setState(()=>message='لديك محطة كهرباء بالفعل'); return; }
    final cost=prices[tool]!;
    if(money<cost) { setState(()=>message='الأموال غير كافية! تحتاج إلى \$'+cost.toString()); return; }
    setState(() {
      money-=cost; t.kind=tool; t.level=tool==Tool.road?0:1;
      if(tool==Tool.road) roads++; else buildings++;
      message='تم إنشاء '+nameOf(tool)+' بنجاح'; help=false;
    });
  }

  void simulate() {
    if(!mounted) return;
    setState(() {
      day++;
      int homes=0,business=0,parks=0;
      for(int r=0;r<n;r++) for(int c=0;c<n;c++) {
        final t=map[r][c];
        if(t.kind==Tool.home) {
          homes++;
          if(powered&&hasRoad(r,c)&&t.level<4&&growth%3==0) { t.level++; population+=3; }
        } else if(t.kind==Tool.shop||t.kind==Tool.factory) {
          business++;
          if(powered&&hasRoad(r,c)&&t.level<4&&growth%4==0) t.level++;
        } else if(t.kind==Tool.park) parks++;
      }
      growth++;
      jobs=business*5+8;
      money+=homes*18+business*38+parks*5-roads*2-(powered?35:0)-business*8;
      happiness=(70+parks*3+(powered?8:-25)-math.max(0,population~/70)).clamp(15,99).toInt();
      if(!powered&&homes>0) message='تنبيه: مدينتك تحتاج إلى محطة كهرباء';
    });
  }

  Color toolColor(Tool t) {
    switch(t) {
      case Tool.road:return const Color(0xFFB9C4CC);
      case Tool.home:return const Color(0xFF54C6A4);
      case Tool.shop:return const Color(0xFF55A7F2);
      case Tool.factory:return const Color(0xFFE6A75B);
      case Tool.power:return const Color(0xFFFFD166);
      case Tool.park:return const Color(0xFF7ED36D);
      case Tool.bulldoze:return const Color(0xFFFF7272);
      case Tool.select:return const Color(0xFFE9F0F5);
    }
  }
  String price(Tool t)=>t==Tool.bulldoze?'مجاني':(t==Tool.select?'اختر':'\$'+prices[t].toString());

  @override
  Widget build(BuildContext context)=>Scaffold(body:SafeArea(child:Row(children:[
    SizedBox(width:205,child:Container(
      decoration:const BoxDecoration(color:Color(0xFF172633),border:Border(right:BorderSide(color:Color(0xFF2D4655)))),
      child:Column(children:[
        const SizedBox(height:8),
        const Row(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(Icons.location_city,color:Color(0xFF54D6B0),size:27),SizedBox(width:7),Text('مدينتي',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900))]),
        const Padding(padding:EdgeInsets.symmetric(vertical:8),child:Text('لوحة البناء',style:TextStyle(color:Colors.white54,fontSize:12))),
        Expanded(child:ListView(padding:const EdgeInsets.symmetric(horizontal:8),children:[
          toolButton(Tool.select,Icons.touch_app,'تحديد'),toolButton(Tool.road,Icons.add_road,'الطرق'),
          toolButton(Tool.home,Icons.house,'منازل'),toolButton(Tool.shop,Icons.storefront,'متاجر'),
          toolButton(Tool.factory,Icons.factory,'مصانع'),toolButton(Tool.power,Icons.electric_bolt,'كهرباء'),
          toolButton(Tool.park,Icons.park,'حدائق'),toolButton(Tool.bulldoze,Icons.delete_sweep,'إزالة'),
        ])),
        Padding(padding:const EdgeInsets.all(7),child:TextButton.icon(onPressed:resetCity,icon:const Icon(Icons.restart_alt,size:18),label:const Text('مدينة جديدة'))),
      ]),
    )),
    Expanded(child:Column(children:[
      topBar(),
      Expanded(child:LayoutBuilder(builder:(context,box)=>Stack(fit:StackFit.expand,children:[
        GestureDetector(behavior:HitTestBehavior.opaque,onTapDown:(d){final p=screenToTile(d.localPosition,box.biggest);place(p.$1,p.$2);},child:CustomPaint(painter:CityPainter(map:map),child:const SizedBox.expand())),
        if(help) Positioned(left:10,right:10,bottom:8,child:IgnorePointer(child:Container(padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:const Color(0xE8172633),borderRadius:BorderRadius.circular(12)),child:const Text('اختر نوع البناء من اليسار ثم اضغط على قطعة أرض بجانب الطريق.',textAlign:TextAlign.center,style:TextStyle(fontSize:12))))),
      ]))),
      bottomBar(),
    ]))),
  ])));

  Widget toolButton(Tool t,IconData icon,String label) {
    final selected=tool==t, color=toolColor(t);
    return Padding(padding:const EdgeInsets.only(bottom:5),child:Material(color:selected?color.withOpacity(.2):const Color(0xFF203441),borderRadius:BorderRadius.circular(10),child:InkWell(borderRadius:BorderRadius.circular(10),onTap:()=>setState(() { tool=t; message='اختر موقع '+nameOf(t)+' على الخريطة'; help=false; }),child:Container(height:42,padding:const EdgeInsets.symmetric(horizontal:9),decoration:BoxDecoration(borderRadius:BorderRadius.circular(10),border:Border.all(color:selected?color:Colors.white10,width:selected?1.5:1)),child:Row(children:[Icon(icon,color:color,size:20),const SizedBox(width:8),Expanded(child:Text(label,style:const TextStyle(fontSize:13,fontWeight:FontWeight.bold))),Text(price(t),style:TextStyle(fontSize:10,color:selected?color:Colors.white54))])))));
  }

  (int,int) screenToTile(Offset p,Size s) {
    const hw=CityPainter.tileW/2,hh=CityPainter.tileH/2;
    final scale=math.min((s.width-20)/(n*CityPainter.tileW),(s.height-24)/(n*CityPainter.tileH)).clamp(.1,1.0).toDouble();
    final offsetY=(s.height-n*CityPainter.tileH*scale)/2;
    final x=(p.dx-s.width/2)/scale,y=(p.dy-offsetY)/scale;
    final col=((x/hw+y/hh)/2).round(),row=((y/hh-x/hw)/2).round();
    return (row,col);
  }

  Widget stat(IconData icon,String label,String value,Color color)=>Padding(padding:const EdgeInsets.only(right:14),child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:18,color:color),const SizedBox(width:5),Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(fontSize:10,color:Colors.white54)),Text(value,style:TextStyle(fontSize:13,fontWeight:FontWeight.w900,color:color))])] ));
  Widget topBar()=>Container(height:56,padding:const EdgeInsets.symmetric(horizontal:12),color:const Color(0xFF1C303D),child:Row(children:[
    stat(Icons.attach_money,'الميزانية','\$'+money.toString(),const Color(0xFF75D6A1)),
    stat(Icons.people_alt,'السكان',population.toString(),const Color(0xFF73C9F2)),
    stat(Icons.work,'الوظائف',jobs.toString(),const Color(0xFFF0BB71)),
    stat(Icons.mood,'السعادة',happiness.toString()+'%',const Color(0xFFFFD166)),
    const Spacer(),Text('اليوم '+day.toString(),style:const TextStyle(fontWeight:FontWeight.bold)),
  ]));
  Widget bottomBar()=>Container(height:32,padding:const EdgeInsets.symmetric(horizontal:10),color:const Color(0xFF172633),child:Row(children:[
    const Icon(Icons.info_outline,size:15,color:Color(0xFF54D6B0)),const SizedBox(width:6),
    Expanded(child:Text(message,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11,color:Colors.white70))),
    Text('طرق '+roads.toString()+' • مبانٍ '+buildings.toString(),style:const TextStyle(fontSize:10,color:Colors.white38)),
  ]));

  void resetCity() {
    setState((){
      for(final row in map) for(final t in row){t.kind=Tool.select;t.level=0;}
      roads=0;buildings=0;money=18000;population=0;jobs=0;happiness=70;day=1;growth=0;
      for(int c=1;c<17;c++){map[9][c].kind=Tool.road;roads++;}
      for(int r=3;r<15;r++){if(r!=9){map[r][9].kind=Tool.road;roads++;}}
      tool=Tool.power;message='مدينة جديدة: ابنِ محطة كهرباء ومنازل ومتاجر';help=true;
    });
  }
}

class CityPainter extends CustomPainter {
  CityPainter({required this.map});
  final List<List<Tile>> map;
  static const double tileW=64,tileH=32;
  @override
  void paint(Canvas c,Size s) {
    c.drawRect(Offset.zero&s,Paint()..shader=const LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Color(0xFF7CB7C2),Color(0xFF527E75),Color(0xFF294B43)]).createShader(Offset.zero&s));
    for(int i=0;i<13;i++){final x=i*s.width/12-20,h=35.0+(i*29%70);c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x,80-h,32+(i%3)*12,h),const Radius.circular(3)),Paint()..color=const Color(0x2440525A));}
    final scale=math.min((s.width-20)/(18*tileW),(s.height-24)/(18*tileH)).clamp(.1,1.0).toDouble();
    final offsetY=(s.height-18*tileH*scale)/2;
    c.save();c.translate(s.width/2,offsetY);c.scale(scale);
    for(int sum=0;sum<=34;sum++)for(int r=0;r<18;r++){final col=sum-r;if(col>=0&&col<18)drawTile(c,r,col,map[r][col]);}
    c.restore();
  }
  Offset center(int r,int col)=>Offset((col-r)*tileW/2,(col+r)*tileH/2);
  void drawTile(Canvas c,int r,int col,Tile t) {
    final p=center(r,col);
    final diamond=Path()..moveTo(p.dx,p.dy-tileH/2)..lineTo(p.dx+tileW/2,p.dy)..lineTo(p.dx,p.dy+tileH/2)..lineTo(p.dx-tileW/2,p.dy)..close();
    c.drawPath(diamond,Paint()..color=(r+col).isEven?const Color(0xFF719B68):const Color(0xFF789F6D));
    c.drawPath(diamond,Paint()..color=const Color(0x1CFFFFFF)..style=PaintingStyle.stroke..strokeWidth=.7);
    switch(t.kind){
      case Tool.road:road(c,p);break;
      case Tool.home:building(c,p,t.level,const Color(0xFF4A9D83),const Color(0xFFB9E7D7),0);break;
      case Tool.shop:building(c,p,t.level,const Color(0xFF367EB4),const Color(0xFFB8E2F8),1);break;
      case Tool.factory:building(c,p,t.level,const Color(0xFF9B7650),const Color(0xFFE8C58E),2);break;
      case Tool.power:powerPlant(c,p);break;
      case Tool.park:park(c,p);break;
      case Tool.select:break;
      case Tool.bulldoze:break;
    }
  }
  void road(Canvas c,Offset p){
    final path=Path()..moveTo(p.dx,p.dy-13)..lineTo(p.dx+27,p.dy)..lineTo(p.dx,p.dy+13)..lineTo(p.dx-27,p.dy)..close();
    c.drawPath(path,Paint()..color=const Color(0xFF4D5960));
    c.drawPath(path,Paint()..color=const Color(0xFF899397)..style=PaintingStyle.stroke..strokeWidth=1);
    c.drawLine(Offset(p.dx-20,p.dy),Offset(p.dx+20,p.dy),Paint()..color=const Color(0xFFFFD66B)..strokeWidth=1.5);
  }
  void building(Canvas c,Offset p,int level,Color front,Color roof,int style){
    final floors=math.max(1,level).toDouble(),height=22.0+math.max(1,level)*10.0,w=style==2?39.0:31.0,d=style==2?23.0:21.0;
    final top=p.dy-height,left=p.dx-w/2,right=p.dx+w/2,side=Color.lerp(front,Colors.black,.25)!;
    final roofPath=Path()..moveTo(p.dx,top-9)..lineTo(right+d/2,top+1)..lineTo(p.dx,top+11)..lineTo(left-d/2,top+1)..close();
    final frontPath=Path()..moveTo(left-d/2,top+1)..lineTo(p.dx,top+11)..lineTo(p.dx,p.dy-3)..lineTo(left-d/2,p.dy-13)..close();
    final sidePath=Path()..moveTo(p.dx,top+11)..lineTo(right+d/2,top+1)..lineTo(right+d/2,p.dy-13)..lineTo(p.dx,p.dy-3)..close();
    c.drawPath(frontPath,Paint()..color=front);c.drawPath(sidePath,Paint()..color=side);c.drawPath(roofPath,Paint()..color=roof);
    if(style==2)c.drawRect(Rect.fromLTWH(p.dx+8,top-16,7,17),Paint()..color=const Color(0xFF727D80));
    final win=Paint()..color=const Color(0xFFFFE7A4);
    for(int f=0;f<floors;f++){final y=top+15+f*10.0;c.drawRect(Rect.fromLTWH(left-8,y,5,5),win);c.drawRect(Rect.fromLTWH(p.dx-3,y+3,5,5),win);c.drawRect(Rect.fromLTWH(p.dx+7,y-2,5,5),win);}
    if(style==0)c.drawCircle(Offset(p.dx,top-12),5,Paint()..color=const Color(0xFF66B96C));
  }
  void powerPlant(Canvas c,Offset p){
    final base=Path()..moveTo(p.dx-24,p.dy-13)..lineTo(p.dx,p.dy-1)..lineTo(p.dx+24,p.dy-13)..lineTo(p.dx,p.dy-25)..close();
    c.drawPath(base,Paint()..color=const Color(0xFFB88C55));
    c.drawRect(Rect.fromLTWH(p.dx-14,p.dy-54,28,35),Paint()..color=const Color(0xFF8A9BA2));
    c.drawRect(Rect.fromLTWH(p.dx-10,p.dy-60,8,10),Paint()..color=const Color(0xFF65747B));
    c.drawRect(Rect.fromLTWH(p.dx+3,p.dy-63,8,13),Paint()..color=const Color(0xFF65747B));
    c.drawRect(Rect.fromLTWH(p.dx-4,p.dy-43,8,11),Paint()..color=const Color(0xFFFFD166));
  }
  void park(Canvas c,Offset p){
    c.drawPath(Path()..moveTo(p.dx,p.dy-8)..lineTo(p.dx+24,p.dy)..lineTo(p.dx,p.dy+9)..lineTo(p.dx-24,p.dy)..close(),Paint()..color=const Color(0xFFB7A66D));
    for(int i=0;i<3;i++){final x=p.dx+(i-1)*13.0;c.drawRect(Rect.fromLTWH(x-2,p.dy-24,4,19),Paint()..color=const Color(0xFF765A3D));c.drawCircle(Offset(x,p.dy-28-(i%2)*4),10,Paint()..color=i.isEven?const Color(0xFF2E8A58):const Color(0xFF45A96B));c.drawCircle(Offset(x-3,p.dy-31),4,Paint()..color=const Color(0xFF78C77B));}
  }
  @override
  bool shouldRepaint(covariant CityPainter oldDelegate)=>true;
}
