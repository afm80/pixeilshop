#!/usr/bin/env python3
"""يحمّل خطوط جوجل المستخدمة في التطبيق إلى assets/google_fonts ليعمل التطبيق بلا إنترنت.

الحزمة google_fonts تبحث تلقائياً عن ملفات بصيغة  <Family>-<Weight>.ttf  داخل الأصول
(مثال: Cairo-Regular.ttf و Cairo-Bold.ttf) قبل أن تحاول التنزيل من الشبكة.
لا يفشل البناء إذا تعذر تنزيل خط: يبقى التنزيل وقت التشغيل كخطة بديلة.

التشغيل:  python3 tool/fetch_fonts.py
"""
import pathlib
import re
import sys
import urllib.parse
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / 'assets' / 'google_fonts'
SRC = (ROOT / 'lib' / 'core' / 'services' / 'font_service.dart').read_text(encoding='utf-8')

# نقرأ قوائم الخطوط من FontService نفسه كي تبقى متزامنة
families = []
for name in ('arabic', 'latin'):
    m = re.search(r'static const List<String> %s = \[(.*?)\];' % name, SRC, re.S)
    if m:
        families += re.findall(r"'([^']+)'", m.group(1))

WEIGHTS = {400: 'Regular', 700: 'Bold'}
UA = {'User-Agent': 'curl/8.0'}  # أي وكيل غير متصفح يعيد ملفات TTF


def get(url, binary=False):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=60) as r:
        data = r.read()
    return data if binary else data.decode('utf-8', 'replace')


def css_for(family):
    q = urllib.parse.quote(family)
    for spec in ('wght@400;700', 'wght@400', ''):
        url = 'https://fonts.googleapis.com/css2?family=%s%s' % (q, (':' + spec) if spec else '')
        try:
            return get(url)
        except Exception:
            continue
    return ''


ok = missing = 0
OUT.mkdir(parents=True, exist_ok=True)
for fam in families:
    css = css_for(fam)
    blocks = re.findall(r'@font-face\s*{(.*?)}', css, re.S)
    found = {}
    for b in blocks:
        w = re.search(r'font-weight:\s*(\d+)', b)
        u = re.search(r'url\((https://[^)]+)\)', b)
        st = re.search(r'font-style:\s*(\w+)', b)
        if w and u and (not st or st.group(1) == 'normal'):
            found[int(w.group(1))] = u.group(1)
    base = fam.replace(' ', '')
    for weight, label in WEIGHTS.items():
        url = found.get(weight) or found.get(400)  # خط بوزن واحد يُستخدم للوزنين
        if not url:
            print('  [skip]', fam, label)
            missing += 1
            continue
        dst = OUT / ('%s-%s.ttf' % (base, label))
        if dst.exists() and dst.stat().st_size > 1000:
            ok += 1
            continue
        try:
            dst.write_bytes(get(url, binary=True))
            ok += 1
            print('  [ok]  ', dst.name)
        except Exception as e:
            print('  [fail]', fam, label, e)
            missing += 1

print('fonts downloaded: %d, missing: %d' % (ok, missing))
sys.exit(0)
