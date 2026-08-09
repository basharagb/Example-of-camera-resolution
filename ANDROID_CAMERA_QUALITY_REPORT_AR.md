# تقرير إصلاح جودة كاميرا Android

## المشكلة الأصلية

كانت نسخة Android تستخدم `CameraController` من Flutter. حتى عند اختيار 4K للتسجيل، كانت المعاينة تصل إلى Flutter كـTexture ثم يجري تكبيرها وقصها لتملأ الشاشة الطويلة. دقة ملف الفيديو ودقة Surface المعاينة شيئان مختلفان، لذلك ظهور شارة 4K لم يكن يعني أن الصورة المرئية في الشاشة 4K أو حتى بأعلى دقة مناسبة. التكبير وإعادة أخذ العينات داخل Texture كانا السبب الأوضح للغباش الشديد.

## الحل المنفذ

تم إنشاء محرك Android أصلي في:

`android/app/src/main/kotlin/com/highest/camera/apex_camera/NativeCameraEngine.kt`

المسار الجديد:

```text
Flutter UI / GetX
→ Repository / MethodChannel
→ NativeCameraEngine (Kotlin)
→ CameraX 1.6.1
→ PreviewView / SurfaceView مباشر
```

لم تعد معاينة Android تستخدم Flutter Camera Texture. الواجهة تسجل Android Platform View باسم `apex_camera_preview` وتعرض `PreviewView` و`FILL_CENTER`. يستخدم المحرك `NativeTextureView` داخل Platform View لأن `SurfaceView` على MagicOS كان يرسم فوق Flutter ويخفي الأزرار. يبقى هذا مسار CameraX أصلياً، لكنه يسمح بتركيب واجهة Flutter فوق المعاينة بصورة صحيحة.

## اختيار الجودة

- المعاينة تطلب دقة الفيديو المختارة نفسها ونسبة 16:9.
- `ResolutionSelector` يستخدم أقرب دقة أعلى ثم الأقرب الأقل، بدلاً من fallback غامض منخفض الجودة.
- التسجيل يستخدم `Recorder` و`QualitySelector` ويختار أقرب Quality حقيقية تعرضها الكاميرا للدقة المطلوبة.
- bitrate يمر من سياسة التطبيق وفق الدقة وFPS.
- يطلب المحرك FPS المحدد من المستخدم بدلاً من تركه عشوائياً.
- الصور تستخدم `ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY` وJPEG quality 100.
- الصور تطلب أكبر دقة sensor معلنة، مع fallback إلى أكبر stream متوافق إذا رفض مصنع الجهاز جمع أقصى صورة مع UHD video في جلسة واحدة.

## HDR والتثبيت

- عند دعم الجهاز للدقة المطلوبة نفسها، يستخدم الفيديو والمعاينة `HLG_10_BIT` الحقيقي.
- الدقة لها الأولوية: إذا كان HDR متاحاً على 1080p فقط بينما اختار المستخدم 4K، يحافظ المحرك على 4K SDR ولا يخفض التسجيل بصمت إلى 1080p.
- إذا لم يعرض الجهاز HLG، يعمل المسار بـSDR ولا يعرض `HDR ON` بصورة وهمية.
- لا يفرض المحرك preview stabilization؛ هاتف LGN LX2 يعلنه غير مدعوم وكان فرضه يجعل CameraX يرفض الجلسة كلها. Video stabilization يُفعّل فقط عندما تعلنه الكاميرا.
- التكبير يستخدم `CameraControl.setZoomRatio` ضمن الحدود الفعلية للعدسة.
- اللمس على الشاشة ينفذ AF + AE + AWB metering على الإحداثيات الأصلية لـPreviewView.
- التعريض يحوّل قيمة EV إلى compensation index الحقيقي للجهاز.

## التسجيل والتقاط الصور

- الصور تكتب مباشرة من `ImageCapture` إلى JPEG مؤقت دون إعادة ضغط من Flutter.
- الفيديو يكتب مباشرة من CameraX Recorder إلى MP4.
- الصوت يضاف فقط إذا كانت الصلاحية ممنوحة.
- pause/resume/stop تنفذ على Recording الأصلي.
- بعد الالتقاط يفحص التطبيق أبعاد الملف الحقيقي قبل الحفظ في MediaStore.

## تشخيص الجهاز

عند بدء الجلسة يسجل Android سطراً بالوسم `ApexNativeCamera` يتضمن:

```text
camera id
CameraX implementation
actual preview resolution
actual video resolution
FPS
HDR ON/OFF
actual photo resolution
SurfaceView
```

مثال أمر القراءة بعد توصيل الهاتف:

```bash
adb logcat -s ApexNativeCamera
```

### القياس الفعلي على LGN LX2

تم تثبيت النسخة وتشغيلها على الجهاز ذي الرقم `ASUDJV5827H08319`، وكانت النتائج:

```text
Camera2 cameras: 2/2 (IDs 0, 1)
Preview: 1280x720 NativeTextureView
Video encoder: 1920x1080 @ 30fps
Photo capture stream: 3264x2448
Saved JPEG: 2448x3264, approximately 5 MB
HDR: OFF (not exposed for this active public encoder profile)
```

يعرض Camera2 مقاسي `3840×2160 @ 24` و`4000×2252 @ 20` ضمن stream table، لكن جدول ترميز Honor العام يقبل حتى FHD عند الربط الفعلي. التطبيق لم يعد يعرض 4K كأنه يعمل؛ يتحقق من الدقة بعد bind ثم يعود إلى 1080p الحقيقي تلقائياً. عرض شاشة الهاتف 720 بكسل، لذلك معاينة 1280×720 لا تُكبّر من مصدر أصغر من الشاشة.

كذلك يرفض هذا الهاتف أحياناً `ADB Streamed Install` الذي يستخدمه `flutter run`، بينما نجح `adb install --no-streaming` باستمرار. هذه مشكلة تثبيت في MagicOS وليست انهياراً في APK.

## الملفات المعدلة

- `android/app/src/main/kotlin/com/highest/camera/apex_camera/NativeCameraEngine.kt`
- `android/app/src/main/kotlin/com/highest/camera/apex_camera/MainActivity.kt`
- `android/app/build.gradle.kts`
- `lib/features/camera/data/datasources/camera_local_data_source.dart`
- `lib/features/camera/presentation/widgets/camera_preview_surface.dart`

## التحقق

- `flutter analyze`: ناجح دون أخطاء.
- اختبارات Flutter الأربعة: ناجحة.
- Android Debug APK: ناجح.
- Android Release APK: ناجح.
- CameraX/Kotlin compilation: ناجح باستخدام CameraX 1.6.1.
