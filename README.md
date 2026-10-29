# Pixeilshop (Flutter)

## التشغيل
1. ثبّت Flutter (3.22 أو أحدث): https://docs.flutter.dev/get-started/install
2. من داخل مجلد المشروع:
   flutter create --platforms=android,ios --org com.pixeilshop .
   flutter pub get
   dart run flutter_launcher_icons
   flutter run
3. أندرويد: في android/app/src/main/AndroidManifest.xml أضف قبل <application>:
   <uses-permission android:name="android.permission.INTERNET"/>
   (ضروري لتحميل الخطوط وإزالة الخلفية في نسخة release)
   وتأكد أن minSdkVersion = 21 أو أعلى (android/app/build.gradle).
4. iOS: في ios/Runner/Info.plist أضف:
   NSPhotoLibraryUsageDescription  و  NSPhotoLibraryAddUsageDescription

## إزالة الخلفية بالإنترنت
المفتاح من https://www.remove.bg/api ويُدخل مرة واحدة داخل التطبيق ويُحفظ على الجهاز.

## الخطوط
تُحمّل عبر حزمة google_fonts من الإنترنت عند أول استخدام. للعمل بلا إنترنت ضع ملفات الخطوط
في assets/google_fonts/ وأضفها إلى pubspec.yaml (انظر وثائق الحزمة).
