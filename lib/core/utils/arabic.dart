/// أدوات نصوص عربية.
bool isRtlText(String s) {
  for (final r in s.runes) {
    if ((r >= 0x0590 && r <= 0x08FF) || (r >= 0xFB1D && r <= 0xFDFF) || (r >= 0xFE70 && r <= 0xFEFF)) {
      return true;
    }
    if ((r >= 0x41 && r <= 0x5A) || (r >= 0x61 && r <= 0x7A)) return false;
  }
  return false;
}

/// تطبيع يحافظ على الطول حرفاً بحرف (حتى تبقى الفهارس صالحة على النص الأصلي).
String normalizeKeepLength(String s) {
  final sb = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    switch (ch) {
      case 'أ':
      case 'إ':
      case 'آ':
      case 'ٱ':
        sb.write('ا');
        break;
      case 'ى':
        sb.write('ي');
        break;
      case 'ة':
        sb.write('ه');
        break;
      case 'ؤ':
        sb.write('و');
        break;
      case 'ئ':
        sb.write('ي');
        break;
      case '٠':
      case '۰':
        sb.write('0');
        break;
      case '١':
      case '۱':
        sb.write('1');
        break;
      case '٢':
      case '۲':
        sb.write('2');
        break;
      case '٣':
      case '۳':
        sb.write('3');
        break;
      case '٤':
      case '۴':
        sb.write('4');
        break;
      case '٥':
      case '۵':
        sb.write('5');
        break;
      case '٦':
      case '۶':
        sb.write('6');
        break;
      case '٧':
      case '۷':
        sb.write('7');
        break;
      case '٨':
      case '۸':
        sb.write('8');
        break;
      case '٩':
      case '۹':
        sb.write('9');
        break;
      default:
        final code = r;
        if (code >= 0x41 && code <= 0x5A) {
          sb.writeCharCode(code + 32);
        } else {
          sb.write(ch);
        }
    }
  }
  return sb.toString();
}
