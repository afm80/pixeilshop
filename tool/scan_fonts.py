#!/usr/bin/env python3
"""يمسح assets/user_fonts ويسجّل الخطوط في pubspec.yaml ويولّد lib/core/services/user_fonts.g.dart.

- كل مجلد فرعي = تصنيف. ملفات الجذر = «أخرى».
- الخط الذي ليس فيه حرف عربي (ا) يُصنَّف إنجليزياً.
- اسم الخط يُقرأ من داخل الملف (fontTools)، ويُستعمل اسم الملف إن تعذر.
لا يفشل البناء إن لم توجد خطوط.
"""
import hashlib
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
FONTS = ROOT / 'assets' / 'user_fonts'
PUB = ROOT / 'pubspec.yaml'
GEN = ROOT / 'lib' / 'core' / 'services' / 'user_fonts.g.dart'
BEGIN, END = '  # >>> user_fonts', '  # <<< user_fonts'
LATIN_DIRS = {'english', 'en', 'latin', 'إنجليزي', 'انجليزي', 'إنجليزية'}

try:
    from fontTools.ttLib import TTFont
except Exception:  # noqa: BLE001
    TTFont = None


def dstr(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$') + "'"


RULES = [
    ('ديواني وكوفي', ('kufi', 'kufic', 'diwani', 'deewani', 'كوفي', 'ديواني')),
    ('رقعة وفارسي', ('ruqa', 'riqa', 'nastaliq', 'nastaleeq', 'farsi', 'persian', 'رقعة', 'نستعليق', 'فارسي')),
    ('نسخ وثلث', ('naskh', 'nasakh', 'naskhi', 'thuluth', 'thulth', 'scheherazade', 'amiri', 'نسخ', 'ثلث')),
    ('إعلانية', ('bold', 'black', 'heavy', 'display', 'extrabold', 'عريض', 'ثقيل')),
]
CHUNK = 40


def guess(name, filename, weight):
    t = (name + ' ' + filename).lower()
    for cat, words in RULES:
        if any(w in t for w in words):
            return cat
    return 'إعلانية' if weight >= 700 else 'أخرى'


def info(path):
    name, arabic, weight = path.stem, True, 400
    if TTFont is not None:
        try:
            f = TTFont(str(path), lazy=True, fontNumber=0)
            n = f['name']
            for nid in (4, 1):
                r = n.getName(nid, 3, 1, 0x409) or n.getName(nid, 1, 0, 0)
                if r:
                    name = r.toUnicode().strip() or name
                    break
            cmap = f.getBestCmap() or {}
            arabic = 0x0627 in cmap
            weight = int(f['OS/2'].usWeightClass) if 'OS/2' in f else 400
            if len(cmap) < 5:
                return None  # خط فارغ/تالف
        except Exception as e:  # noqa: BLE001
            print('تالف (تم تجاهله):', path.name, e)
            return None
    return name, arabic, weight


files = sorted(p for p in FONTS.rglob('*') if p.suffix.lower() in ('.ttf', '.otf')) if FONTS.exists() else []
ar, la, seen, entries = {}, [], set(), []
hashes, names, skipped = {}, {}, []
for p in files:
    rel = p.relative_to(ROOT).as_posix()
    parts = p.relative_to(FONTS).parts
    if p.stat().st_size < 1024:
        skipped.append((p.name, 'ملف صغير جداً/تالف'))
        continue
    h = hashlib.sha1(p.read_bytes()).hexdigest()
    if h in hashes:
        skipped.append((p.name, 'نسخة مطابقة تماماً لـ ' + hashes[h]))
        continue
    r = info(p)
    if r is None:
        skipped.append((p.name, 'تالف'))
        continue
    hashes[h] = p.name
    name, is_ar, weight = r
    key = (name, p.suffix.lower())
    if name in names:
        # نفس اسم الخط في ملف آخر: نبقي الأول ونتجاهل المكرر
        skipped.append((p.name, 'نفس اسم الخط (%s) موجود في %s' % (name, names[name])))
        continue
    names[name] = p.name
    cat = parts[0] if len(parts) > 1 else guess(name, p.name, weight)
    seen.add(name)
    entries.append((name, rel))
    if cat.lower() in LATIN_DIRS or not is_ar:
        la.append(name)
    else:
        ar.setdefault(cat, []).append(name)

# تقسيم التصنيف الكبير إلى صفحات صغيرة (40 خطاً) كي تبقى القوائم سريعة
for c in list(ar):
    ns = ar[c]
    if len(ns) > CHUNK:
        del ar[c]
        for i in range(0, len(ns), CHUNK):
            ar[c if i == 0 else '%s %d' % (c, i // CHUNK + 1)] = ns[i:i + CHUNK]

for c, ns in ar.items():
    print('[%s] %d خطاً: %s' % (c, len(ns), '، '.join(ns[:6]) + (' ...' if len(ns) > 6 else '')))

# pubspec
text = PUB.read_text(encoding='utf-8')
text = re.sub(r'\n?%s.*?%s\n?' % (re.escape(BEGIN), re.escape(END)), '\n', text, flags=re.S)
if entries:
    block = [BEGIN, '  fonts:']
    for name, rel in entries:
        block += ['    - family: ' + json.dumps(name, ensure_ascii=False), '      fonts:', '        - asset: ' + json.dumps(rel, ensure_ascii=False)]
    block.append(END)
    text = re.sub(r'(\nflutter:[^\n]*\n)', lambda m: m.group(1) + '\n'.join(block) + '\n', text, count=1)
PUB.write_text(text, encoding='utf-8')

# dart
lines = ['// ملف مولَّد تلقائياً بواسطة tool/scan_fonts.py — لا تعدّله يدوياً.', '', 'const Map<String, List<String>> kUserArabic = {']
for c, ns in ar.items():
    lines.append('  %s: [%s],' % (dstr(c), ', '.join(dstr(n) for n in ns)))
lines += ['};', '', 'const List<String> kUserLatin = [%s];' % ', '.join(dstr(n) for n in la), '']
GEN.write_text('\n'.join(lines), encoding='utf-8')
if skipped:
    print('--- تم تجاهل %d ملفاً ---' % len(skipped))
    for n, why in skipped:
        print('  ', n, '←', why)
print('خطوط مسجّلة:', len(entries), '| عربي:', sum(len(v) for v in ar.values()), '| إنجليزي:', len(la))
