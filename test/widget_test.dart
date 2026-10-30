import 'dart:ui' show Offset;

import 'package:flutter_test/flutter_test.dart';
import 'package:omnistudio_ai/core/services/tflite_service.dart';
import 'package:omnistudio_ai/features/ai_copilot/command_parser.dart';
import 'package:omnistudio_ai/features/poster_builder/model/layer.dart';

void main() {
  group('CommandParser', () {
    test('remove background (ar/en)', () {
      expect(CommandParser.parse('ازل الخلفية'), isA<RemoveBackgroundCmd>());
      expect(CommandParser.parse('أزل الخلفية'), isA<RemoveBackgroundCmd>());
      expect(CommandParser.parse('remove background'), isA<RemoveBackgroundCmd>());
      expect(CommandParser.parse('فرغ الصورة'), isA<RemoveBackgroundCmd>());
    });

    test('add text keeps original text', () {
      final c = CommandParser.parse("اضف نص 'عرض خاص'") as AddTextCmd;
      expect(c.text, 'عرض خاص');
      final d = CommandParser.parse('أضف نص "Big Sale"') as AddTextCmd;
      expect(d.text, 'Big Sale');
      final e = CommandParser.parse('اكتب نص أهلاً وسهلاً') as AddTextCmd;
      expect(e.text, 'أهلاً وسهلاً');
    });

    test('anime / cartoon', () {
      expect((CommandParser.parse('حول الصورة إلى أنمي') as StyleCmd).kind, StyleKind.anime);
      expect((CommandParser.parse('حولها الى كرتون') as StyleCmd).kind, StyleKind.cartoon);
    });

    test('filters and adjustments', () {
      expect((CommandParser.parse('طبق فلتر سينمائي') as FilterCmd).preset, 1);
      expect((CommandParser.parse('اجعلها أبيض وأسود') as FilterCmd).preset, 4);
      final a = CommandParser.parse('زد السطوع 20') as AdjustCmd;
      expect(a.param, AdjustParam.brightness);
      expect(a.relative, isTrue);
      expect(a.amount, closeTo(0.2, 1e-9));
      final b = CommandParser.parse('قلل التباين') as AdjustCmd;
      expect(b.amount, lessThan(0));
    });

    test('shadow, colors, misc', () {
      expect((CommandParser.parse('اضف ظل') as ShadowCmd).on, isTrue);
      expect((CommandParser.parse('ازل الظل') as ShadowCmd).on, isFalse);
      expect(CommandParser.parse('لون الخلفية أحمر'), isA<BgColorCmd>());
      expect(CommandParser.parse('لون النص ذهبي'), isA<TextColorCmd>());
      expect(CommandParser.parse('تراجع'), isA<UndoCmd>());
      expect(CommandParser.parse('احفظ الصورة'), isA<ExportCmd>());
      expect(CommandParser.parse('اضف نجمة'), isA<AddShapeCmd>());
      expect(CommandParser.parse('blah blah'), isA<UnknownCmd>());
    });
  });

  group('Layer geometry', () {
    test('localToDoc and docToLocal are inverse', () {
      final l = Layer.create(LayerType.shape)
        ..x = 300
        ..y = 200
        ..scale = 1.7
        ..rotation = 0.6
        ..flipX = true;
      final d = l.localToDoc(const Offset(40, -25));
      final back = l.docToLocal(d);
      expect(back.dx, closeTo(40, 1e-6));
      expect(back.dy, closeTo(-25, 1e-6));
    });
  });
}
