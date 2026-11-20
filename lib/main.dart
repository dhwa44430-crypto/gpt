
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:three_js/three_js.dart' as three;

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
    debugShowCheckedModeBanner: false,
    title: 'مدينتي 3D',
    theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF101B25), colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF36C7A0), brightness: Brightness.dark), useMaterial3: true),
    home: const CityScreen(),
  );
}

enum Tool { select, road, home, shop, factory, power, park, bulldoze }

class CityTile {
  CityTile({this.kind = Tool.select, this.level = 0});
  Tool kind;
  int level;
  late three.Mesh ground;
  three.Group? structure;
}

class CityScreen extends StatefulWidget {
  const CityScreen({super.key});
  @override
  State<CityScreen> createState() => _CityScreenState();
}

class _CityScreenState extends State<CityScreen> {
  static const int gridSize = 18;
  late final List<List<CityTile>> city;
  late final Timer simulationTimer;
  late three.ThreeJS threeJs;
  late three.MapControls cameraControls;
  final three.Raycaster raycaster = three.Raycaster();
  final three.Vector2 pointer = three.Vector2();
  final List<three.Object3D> groundTiles = [];
  final Map<int, dynamic> materials = {};
  three.BoxGeometry? groundGeometry;

  Tool selectedTool = Tool.home;
  int money = 18000, population = 12, jobs = 8, happiness = 76, day = 1, roads = 27, buildings = 5, growth = 0;
  String message = 'اختر نوع البناء ثم اضغط على قطعة أرض في المدينة';
  bool ready = false, showHelp = true;

  final Map<Tool, int> prices = const {
    Tool.road: 45, Tool.home: 130, Tool.shop: 210, Tool.factory: 190,
    Tool.power: 650, Tool.park: 160, Tool.bulldoze: 0, Tool.select: 0,
  };

  @override
  void initState() {
    super.initState();
    city = List.generate(gridSize, (_) => List.generate(gridSize, (_) => CityTile()));
    threeJs = three.ThreeJS(
      onSetupComplete: () { if (mounted) setState(() => ready = true); },
      setup: setup3D,
    );
    simulationTimer = Timer.periodic(const Duration(seconds: 5), (_) => simulateCity());
  }

  @override
  void dispose() {
    simulationTimer.cancel();
    if (ready) cameraControls.dispose();
    threeJs.dispose();
    three.loading.clear();
    super.dispose();
  }

  Future<void> setup3D() async {
    threeJs.scene = three.Scene();
    threeJs.scene.background = three.Color.fromHex32(0x9CC9D7);
    threeJs.scene.fog = three.Fog(0x9CC9D7, 26, 65);
    threeJs.camera = three.PerspectiveCamera(48, threeJs.width / threeJs.height, 0.1, 120);
    threeJs.camera.position.setValues(21, 24, 25);
    threeJs.camera.lookAt(0, 0, 0);

    threeJs.scene.add(three.AmbientLight(0xffffff, 0.72));
    final sunlight = three.DirectionalLight(0xfff2d8, 1.35)..position.setValues(-12, 25, 15);
    threeJs.scene.add(sunlight);
    final fill = three.DirectionalLight(0x9ecfff, 0.35)..position.setValues(12, 10, -15);
    threeJs.scene.add(fill);

    cameraControls = three.MapControls(threeJs.camera, threeJs.globalKey);
    cameraControls.enableDamping = true;
    cameraControls.dampingFactor = 0.07;
    cameraControls.screenSpacePanning = false;
    cameraControls.minDistance = 9;
    cameraControls.maxDistance = 48;
    cameraControls.maxPolarAngle = 1.48;
    cameraControls.target.setValues(0, 0, 0);
    cameraControls.update();

    groundGeometry = three.BoxGeometry(0.98, 0.12, 0.98);
    createCityGround();
    createStartingCity();
    threeJs.domElement.addEventListener(three.PeripheralType.pointerDown, onCityPointerDown);
    threeJs.addAnimationEvent((dt) { cameraControls.update(); });
  }

  dynamic material(int color) => materials.putIfAbsent(
    color,
    () => three.MeshPhongMaterial.fromMap({'color': color, 'shininess': 22, 'flatShading': true}),
  );

  void addBox(three.Object3D parent, double width, double height, double depth, double x, double y, double z, int color) {
    final mesh = three.Mesh(three.BoxGeometry(width, height, depth), material(color));
    mesh.position.setValues(x, y, z);
    parent.add(mesh);
  }

  void addCylinder(three.Object3D parent, double radiusTop, double radiusBottom, double height, double x, double y, double z, int color) {
    final mesh = three.Mesh(three.CylinderGeometry(radiusTop, radiusBottom, height, 8), material(color));
    mesh.position.setValues(x, y, z);
    parent.add(mesh);
  }

  void addTree(three.Object3D parent, double x, double z, {double scale = 1}) {
    addCylinder(parent, 0.055 * scale, 0.075 * scale, 0.48 * scale, x, 0.34 * scale, z, 0x795338);
    final crown = three.Mesh(three.ConeGeometry(0.34 * scale, 0.82 * scale, 7), material(0x27824C));
    crown.position.setValues(x, 0.91 * scale, z);
    parent.add(crown);
    final crownTop = three.Mesh(three.SphereGeometry(0.22 * scale, 8, 6), material(0x49A85F));
    crownTop.position.setValues(x - 0.06 * scale, 1.18 * scale, z);
    parent.add(crownTop);
  }

  void createCityGround() {
    final groundBase = three.Mesh(three.BoxGeometry(gridSize + 1.0, 0.35, gridSize + 1.0), material(0x587B52));
    groundBase.position.setValues(0, -0.24, 0);
    threeJs.scene.add(groundBase);

    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        final mesh = three.Mesh(groundGeometry!, material(tileColor(row, col)));
        mesh.position.setValues(col - 8.5, 0, row - 8.5);
        mesh.name = 'tile_' + row.toString() + '_' + col.toString();
        city[row][col].ground = mesh;
        threeJs.scene.add(mesh);
        groundTiles.add(mesh);
      }
    }

    for (int i = 0; i < 22; i++) {
      final x = (i - 11) * 2.8;
      final h = 1.8 + (i % 5) * 0.65;
      final block = three.Mesh(three.BoxGeometry(1.8, h, 1.8), material(i.isEven ? 0x78939A : 0x6F8993));
      block.position.setValues(x, h / 2 - 0.1, -13.2);
      threeJs.scene.add(block);
    }
  }

  int tileColor(int row, int col) => (row + col).isEven ? 0x82AD69 : 0x78A45F;

  void updateTileAppearance(int row, int col) {
    final tile = city[row][col];
    tile.ground.material = material(tile.kind == Tool.road ? 0x414B53 : tileColor(row, col));
    if (tile.kind == Tool.road) {
      final marker = three.Group();
      addBox(marker, 0.07, 0.025, 0.42, 0, 0.085, 0, 0xF4D77B);
      marker.position.setValues(col - 8.5, 0, row - 8.5);
      tile.structure = marker;
      threeJs.scene.add(marker);
    }
  }

  void setTile(int row, int col, Tool kind, int level, {bool updateCounters = true}) {
    final tile = city[row][col];
    if (tile.structure != null) {
      threeJs.scene.remove(tile.structure!);
      tile.structure = null;
    }
    tile.kind = kind;
    tile.level = level;
    updateTileAppearance(row, col);
    if (kind != Tool.select && kind != Tool.road) {
      final group = createBuilding(kind, level);
      group.position.setValues(col - 8.5, 0.08, row - 8.5);
      tile.structure = group;
      threeJs.scene.add(group);
    }
    if (updateCounters) {
      if (kind == Tool.road) {
        roads++;
      } else if (kind != Tool.select) {
        buildings++;
      }
    }
  }

  three.Group createBuilding(Tool kind, int level) {
    final group = three.Group();
    final floors = math.max(1, level).toInt();
    switch (kind) {
      case Tool.home:
        addBox(group, 0.68, 0.48 + floors * 0.28, 0.68, 0, 0.24 + floors * 0.14, 0, 0xD8B58C);
        addBox(group, 0.76, 0.12, 0.76, 0, 0.52 + floors * 0.28, 0, 0xA94F43);
        for (int floor = 0; floor < floors; floor++) {
          final y = 0.16 + floor * 0.28;
          for (final x in [-0.19, 0.19]) {
            addBox(group, 0.105, 0.12, 0.025, x, y, 0.35, 0x7ED7E8);
            addBox(group, 0.105, 0.12, 0.025, x, y, -0.35, 0x7ED7E8);
          }
        }
        addBox(group, 0.16, 0.28, 0.035, 0, 0.15, 0.355, 0x654331);
        break;
      case Tool.shop:
        addBox(group, 0.76, 0.7 + floors * 0.24, 0.72, 0, 0.35 + floors * 0.12, 0, 0x5A91BD);
        addBox(group, 0.82, 0.13, 0.78, 0, 0.76 + floors * 0.24, 0, 0xDCE8EF);
        addBox(group, 0.8, 0.2, 0.08, 0, 0.18, 0.39, 0xF2C45D);
        for (final x in [-0.24, 0.0, 0.24]) {
          addBox(group, 0.13, 0.25, 0.025, x, 0.43, 0.37, 0xA9E7F0);
        }
        break;
      case Tool.factory:
        addBox(group, 0.82, 0.56, 0.78, 0, 0.28, 0, 0xA77B53);
        addBox(group, 0.86, 0.16, 0.82, 0, 0.64, 0, 0xC8A477);
        addBox(group, 0.17, 0.85, 0.17, 0.22, 1.0, -0.18, 0x737E83);
        addBox(group, 0.12, 0.12, 0.12, 0.22, 1.48, -0.18, 0xD1D5D4);
        for (final x in [-0.24, 0.22]) {
          addBox(group, 0.14, 0.13, 0.025, x, 0.3, 0.4, 0xF5D78C);
        }
        break;
      case Tool.power:
        addBox(group, 0.78, 0.68, 0.78, 0, 0.34, 0, 0x899BA5);
        addBox(group, 0.25, 1.0, 0.25, -0.22, 0.86, -0.18, 0x606F79);
        addBox(group, 0.2, 0.76, 0.2, 0.22, 0.74, 0.18, 0x74848D);
        addBox(group, 0.18, 0.22, 0.035, 0, 0.33, 0.4, 0xFFD36B);
        break;
      case Tool.park:
        final lawn = three.Mesh(three.BoxGeometry(0.86, 0.035, 0.86), material(0x69A85C));
        lawn.position.setValues(0, 0.02, 0);
        group.add(lawn);
        addTree(group, -0.22, -0.2, scale: 0.8);
        addTree(group, 0.2, -0.18, scale: 0.72);
        addTree(group, 0, 0.2, scale: 0.75);
        addBox(group, 0.12, 0.06, 0.42, 0, 0.08, 0, 0xD5C18C);
        break;
      case Tool.road:
      case Tool.select:
      case Tool.bulldoze:
        break;
    }
    return group;
  }

  bool get hasPower => city.expand((row) => row).any((tile) => tile.kind == Tool.power);

  bool hasAdjacentRoad(int row, int col) {
    const directions = [[0, 1], [0, -1], [1, 0], [-1, 0]];
    for (final direction in directions) {
      final r = row + direction[0], c = col + direction[1];
      if (r >= 0 && r < gridSize && c >= 0 && c < gridSize && city[r][c].kind == Tool.road) return true;
    }
    return false;
  }

  void onCityPointerDown(three.WebPointerEvent event) {
    if (!ready || !mounted) return;
    pointer.x = (event.clientX / threeJs.width) * 2 - 1;
    pointer.y = -(event.clientY / threeJs.height) * 2 + 1;
    raycaster.setFromCamera(pointer, threeJs.camera);
    final hits = raycaster.intersectObjects(groundTiles, false);
    if (hits.isEmpty) return;
    final name = hits.first.object!.name;
    final parts = name.split('_');
    if (parts.length != 3) return;
    final row = int.tryParse(parts[1]), col = int.tryParse(parts[2]);
    if (row != null && col != null) handleTileTap(row, col);
  }

  void handleTileTap(int row, int col) {
    if (row < 0 || row >= gridSize || col < 0 || col >= gridSize) return;
    final tile = city[row][col];
    if (selectedTool == Tool.select) {
      setState(() {
        message = tile.kind == Tool.select ? 'أرض فارغة' : toolName(tile.kind) + ' • المستوى ' + tile.level.toString();
      });
      return;
    }
    if (selectedTool == Tool.bulldoze) {
      if (tile.kind == Tool.select) {
        setState(() => message = 'لا يوجد بناء لإزالته هنا');
        return;
      }
      setState(() {
        if (tile.kind == Tool.road) {
          roads = math.max(0, roads - 1).toInt();
        } else {
          buildings = math.max(0, buildings - 1).toInt();
        }
        if (tile.kind == Tool.home) population = math.max(0, population - 4).toInt();
        if (tile.kind == Tool.shop || tile.kind == Tool.factory) jobs = math.max(0, jobs - 3).toInt();
        setTile(row, col, Tool.select, 0, updateCounters: false);
        message = 'تمت إزالة البناء';
      });
      return;
    }
    if (tile.kind != Tool.select) {
      setState(() => message = 'هذه القطعة مشغولة، أزل البناء أولاً');
      return;
    }
    if (selectedTool != Tool.road && !hasAdjacentRoad(row, col)) {
      setState(() => message = 'يجب بناء المبنى بجانب طريق');
      return;
    }
    if (selectedTool == Tool.power && hasPower) {
      setState(() => message = 'لديك محطة كهرباء بالفعل');
      return;
    }
    final cost = prices[selectedTool]!;
    if (money < cost) {
      setState(() => message = 'الأموال غير كافية • تحتاج إلى ' + cost.toString());
      return;
    }
    setState(() {
      money -= cost;
      setTile(row, col, selectedTool, selectedTool == Tool.road ? 0 : 1);
      message = 'تم إنشاء ' + toolName(selectedTool) + ' بنجاح';
      showHelp = false;
    });
  }

  void simulateCity() {
    if (!mounted || !ready) return;
    setState(() {
      day++;
      var homes = 0, businesses = 0, parks = 0;
      for (int row = 0; row < gridSize; row++) {
        for (int col = 0; col < gridSize; col++) {
          final tile = city[row][col];
          if (tile.kind == Tool.home) {
            homes++;
            if (hasPower && hasAdjacentRoad(row, col) && tile.level < 4 && growth % 3 == 0) {
              tile.level++;
              population += 3;
              refreshBuilding(row, col);
            }
          } else if (tile.kind == Tool.shop || tile.kind == Tool.factory) {
            businesses++;
            if (hasPower && hasAdjacentRoad(row, col) && tile.level < 4 && growth % 4 == 0) {
              tile.level++;
              refreshBuilding(row, col);
            }
          } else if (tile.kind == Tool.park) {
            parks++;
          }
        }
      }
      growth++;
      jobs = businesses * 5 + 8;
      money += homes * 18 + businesses * 38 + parks * 5 - roads * 2 - (hasPower ? 35 : 0) - businesses * 8;
      happiness = (70 + parks * 3 + (hasPower ? 8 : -25) - math.max(0, population ~/ 70)).clamp(15, 99).toInt();
      if (!hasPower && homes > 0) message = 'تنبيه: المدينة تحتاج إلى محطة كهرباء';
    });
  }

  void refreshBuilding(int row, int col) {
    final tile = city[row][col];
    if (tile.structure != null) threeJs.scene.remove(tile.structure!);
    final group = createBuilding(tile.kind, tile.level);
    group.position.setValues(col - 8.5, 0.08, row - 8.5);
    tile.structure = group;
    threeJs.scene.add(group);
  }

  String toolName(Tool tool) {
    switch (tool) {
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

  Color toolColor(Tool tool) {
    switch (tool) {
      case Tool.road: return const Color(0xFFB9C4CC);
      case Tool.home: return const Color(0xFF54C6A4);
      case Tool.shop: return const Color(0xFF55A7F2);
      case Tool.factory: return const Color(0xFFE6A75B);
      case Tool.power: return const Color(0xFFFFD166);
      case Tool.park: return const Color(0xFF7ED36D);
      case Tool.bulldoze: return const Color(0xFFFF7272);
      case Tool.select: return const Color(0xFFE9F0F5);
    }
  }

  String priceLabel(Tool tool) {
    if (tool == Tool.bulldoze) return 'مجاني';
    if (tool == Tool.select) return 'اختر';
    return '\$' + prices[tool].toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            SizedBox(
              width: 190,
              child: Container(
                decoration: const BoxDecoration(color: Color(0xFF172633), border: Border(right: BorderSide(color: Color(0xFF2D4655)))),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.location_city, color: Color(0xFF54D6B0), size: 26),
                      SizedBox(width: 6),
                      Text('مدينتي 3D', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    ]),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('لوحة البناء', style: TextStyle(color: Colors.white54, fontSize: 12))),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        children: [
                          toolButton(Tool.select, Icons.touch_app, 'تحديد'),
                          toolButton(Tool.road, Icons.add_road, 'الطرق'),
                          toolButton(Tool.home, Icons.house, 'منازل'),
                          toolButton(Tool.shop, Icons.storefront, 'متاجر'),
                          toolButton(Tool.factory, Icons.factory, 'مصانع'),
                          toolButton(Tool.power, Icons.electric_bolt, 'كهرباء'),
                          toolButton(Tool.park, Icons.park, 'حدائق'),
                          toolButton(Tool.bulldoze, Icons.delete_sweep, 'إزالة'),
                        ],
                      ),
                    ),
                    Padding(padding: const EdgeInsets.all(7), child: TextButton.icon(onPressed: resetCity, icon: const Icon(Icons.restart_alt, size: 18), label: const Text('مدينة جديدة'))),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  topBar(),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        threeJs.build(),
                        if (!ready) const Center(child: CircularProgressIndicator()),
                        if (showHelp && ready)
                          Positioned(
                            left: 12, right: 12, bottom: 10,
                            child: IgnorePointer(
                              child: Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(color: const Color(0xE8172633), borderRadius: BorderRadius.circular(12)),
                                child: const Text(
                                  'اسحب بإصبعك لتدوير المدينة • استخدم إصبعين للتقريب والإبعاد • اختر البناء ثم المس الأرض',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  bottomBar(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget toolButton(Tool tool, IconData icon, String label) {
    final selected = selectedTool == tool;
    final color = toolColor(tool);
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: selected ? color.withOpacity(0.2) : const Color(0xFF203441),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() {
            selectedTool = tool;
            message = 'اختر موقع ' + toolName(tool) + ' على المدينة';
            showHelp = false;
          }),
          child: Container(
            height: 41,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: selected ? color : Colors.white10, width: selected ? 1.5 : 1)),
            child: Row(
              children: [
                Icon(icon, color: color, size: 19),
                const SizedBox(width: 7),
                Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                Text(priceLabel(tool), style: TextStyle(fontSize: 10, color: selected ? color : Colors.white54)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget stat(IconData icon, String label, String value, Color color) => Padding(
    padding: const EdgeInsets.only(right: 12),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 17, color: color),
      const SizedBox(width: 4),
      Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.white54)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
      ]),
    ]),
  );

  Widget topBar() => Container(
    height: 54,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    color: const Color(0xFF1C303D),
    child: Row(children: [
      stat(Icons.attach_money, 'الميزانية', money.toString(), const Color(0xFF75D6A1)),
      stat(Icons.people_alt, 'السكان', population.toString(), const Color(0xFF73C9F2)),
      stat(Icons.work, 'الوظائف', jobs.toString(), const Color(0xFFF0BB71)),
      stat(Icons.mood, 'السعادة', happiness.toString() + '%', const Color(0xFFFFD166)),
      const Spacer(),
      Text('اليوم ' + day.toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    ]),
  );

  Widget bottomBar() => Container(
    height: 31,
    padding: const EdgeInsets.symmetric(horizontal: 9),
    color: const Color(0xFF172633),
    child: Row(children: [
      const Icon(Icons.info_outline, size: 15, color: Color(0xFF54D6B0)),
      const SizedBox(width: 6),
      Expanded(child: Text(message, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.white70))),
      Text('طرق ' + roads.toString() + ' • مبانٍ ' + buildings.toString(), style: const TextStyle(fontSize: 10, color: Colors.white38)),
    ]),
  );

  void resetCity() {
    if (!ready) return;
    setState(() {
      for (int row = 0; row < gridSize; row++) {
        for (int col = 0; col < gridSize; col++) {
          final tile = city[row][col];
          if (tile.structure != null) {
            threeJs.scene.remove(tile.structure!);
            tile.structure = null;
          }
          tile.kind = Tool.select;
          tile.level = 0;
          tile.ground.material = material(tileColor(row, col));
        }
      }
      money = 18000;
      population = 0;
      jobs = 0;
      happiness = 70;
      day = 1;
      growth = 0;
      roads = 0;
      buildings = 0;
      for (int col = 1; col < 17; col++) setTile(9, col, Tool.road, 0);
      for (int row = 3; row < 15; row++) {
        if (row != 9) setTile(row, 9, Tool.road, 0);
      }
      selectedTool = Tool.power;
      message = 'مدينة جديدة: ابنِ محطة كهرباء ومنازل ومتاجر';
      showHelp = true;
    });
  }
}
