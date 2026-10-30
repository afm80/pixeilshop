import 'adjust.dart';
import 'layer.dart';

/// نوع الخلفية: 0 لون، 1 تدرج، 2 صورة، 3 شفافة
class Doc {
  Doc({
    required this.id,
    required this.name,
    required this.w,
    required this.h,
    this.bgKind = 0,
    this.bgColor1 = 0xFFFFFFFF,
    this.bgColor2 = 0xFF000000,
    this.bgAngle = 90,
    this.bgPath,
    List<Layer>? layers,
    Adjust? adjust,
  })  : layers = layers ?? <Layer>[],
        adjust = adjust ?? Adjust();

  factory Doc.blank({String name = 'تصميم جديد', double w = 1080, double h = 1080}) => Doc(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        w: w,
        h: h,
      );

  final String id;
  String name;
  double w, h;
  int bgKind;
  int bgColor1, bgColor2;
  double bgAngle;
  String? bgPath;
  List<Layer> layers;
  Adjust adjust; // تعديل لوني شامل على التصميم كله

  int indexOf(String id) => layers.indexWhere((l) => l.id == id);

  Layer? byId(String? id) {
    if (id == null) return null;
    final i = indexOf(id);
    return i < 0 ? null : layers[i];
  }

  Doc clone() => Doc.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'w': w,
        'h': h,
        'bk': bgKind,
        'b1': bgColor1,
        'b2': bgColor2,
        'ba': bgAngle,
        'bp': bgPath,
        'ls': layers.map((l) => l.toJson()).toList(),
        'adj': adjust.toJson(),
      };

  factory Doc.fromJson(Map<String, dynamic> m) => Doc(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? 'تصميم',
        w: (m['w'] as num).toDouble(),
        h: (m['h'] as num).toDouble(),
        bgKind: (m['bk'] as num?)?.toInt() ?? 0,
        bgColor1: (m['b1'] as num?)?.toInt() ?? 0xFFFFFFFF,
        bgColor2: (m['b2'] as num?)?.toInt() ?? 0xFF000000,
        bgAngle: (m['ba'] as num?)?.toDouble() ?? 90,
        bgPath: m['bp'] as String?,
        layers: ((m['ls'] as List?) ?? const [])
            .map((e) => Layer.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        adjust: Adjust.fromJson(m['adj'] == null ? null : Map<String, dynamic>.from(m['adj'] as Map)),
      );
}

/// نتيجة معالجة صورة (إزالة خلفية / أنمي) تُستبدل بها صورة طبقة.
/// [normLeft..normHeight] هي المنطقة التي تغطيها النتيجة من الصورة الأصلية (0..1).
class ImageResult {
  const ImageResult({
    required this.path,
    required this.width,
    required this.height,
    this.normLeft = 0,
    this.normTop = 0,
    this.normWidth = 1,
    this.normHeight = 1,
    this.note = '',
  });
  final String path;
  final int width, height;
  final double normLeft, normTop, normWidth, normHeight;
  final String note;
}
