# تقرير إصلاح جودة كاميرا iPhone

## ملخص المشكلة

النسخة السابقة كانت تعرض الرقم `4032 × 3024`، لكن هذا الرقم لم يكن دليلاً على جودة معاينة الفيديو. كان ملحق Flutter يختار أعلى صيغة من حيث عدد البكسلات (`ResolutionPreset.max`) وهي صيغة 4:3 أقرب لمسار الصور الثابتة، ثم يحوّل الصورة إلى Flutter Texture ويكبّرها لتملأ شاشة iPhone الطويلة. نتيجة ذلك:

- تكبير قوي وقص كبير من 4:3 إلى شاشة 9:19.5.
- إعادة أخذ عينات داخل Flutter Texture بدلاً من مسار عرض iOS الأصلي.
- اختيار صيغة ذات بكسلات أكثر، لكنها ليست أفضل صيغة فيديو معالجة.
- رسائل `FigCaptureSourceRemote` متكررة في السجل عند تهيئة مصدر الالتقاط.
- عدم وجود تحكم حقيقي في HDR أو اختيار pixel format أو HEVC من طبقة التطبيق.

تيك توك لا يعرض أعلى رقم خام فقط؛ بل يستخدم مسار فيديو أصلياً مناسباً للمعاينة، عادة بنسبة 16:9، مع معالجة Apple والتثبيت والتركيز والتعريض المستمرين.

## الحل المنفذ

تم إنشاء محرك iOS مخصص بالكامل داخل `ios/Runner/AppDelegate.swift` باستخدام AVFoundation، ولم يعد iOS ينشئ `CameraController` أو Texture من حزمة Flutter للمعاينة أو الالتقاط.

المسار الجديد:

```text
Flutter CameraPage
→ GetX Controller
→ Use Cases / Repository
→ MethodChannel
→ NativeCameraEngine (Swift)
→ AVCaptureSession
→ AVCaptureVideoPreviewLayer
```

### 1. معاينة أصلية مباشرة

تم تسجيل Platform View باسم `apex_camera_preview`. هذه الواجهة تستخدم `AVCaptureVideoPreviewLayer` مع `resizeAspectFill`، لذلك يعرض iOS إطارات الكاميرا مباشرة عبر مسار GPU الأصلي، من دون تحويل BGRA Texture أو تكبير Flutter السابق.

### 2. فصل جودة الفيديو عن جودة الصورة

- الفيديو يبدأ بأعلى صيغة 16:9 حقيقية يدعمها الجهاز، مثل `3840 × 2160` على iPhone 15 Pro.
- صيغة `4032 × 3024` تبقى متاحة كـ `4K MAX` للصور أو الالتقاط 4:3، لكنها لم تعد الاختيار الافتراضي للفيديو.
- عند الانتقال إلى Photo يستخدم التطبيق أكبر صيغة مستشعر متاحة.
- عند الرجوع إلى Video يعيد التطبيق الصيغة 16:9 المناسبة تلقائياً.

### 3. اختيار صيغة AVFoundation بدقة

المحرك يطابق `AVCaptureDevice.Format` وفقاً إلى:

- العرض والارتفاع المطلوبين بالضبط.
- FPS الموجود فعلياً ضمن `videoSupportedFrameRateRanges`.
- 10-bit HLG عند تشغيل HDR.
- 8-bit full-range عند إيقاف HDR.
- دعم cinematic أو standard stabilization.
- دعم global tone mapping.

إذا لم توجد الصيغة المطلوبة لا يدّعي التطبيق تشغيلها ولا يختار رقماً وهمياً؛ يرجع خطأ typed failure ثم يجرب fallback معلناً من الجهاز.

### 4. تحسينات جودة Apple المفعلة

المحرك يفعّل عند دعم الجهاز:

- `continuousAutoFocus`
- `continuousAutoExposure`
- `continuousAutoWhiteBalance`
- Smooth autofocus
- Automatic low-light boost
- Geometric distortion correction
- Global tone mapping
- Cinematic Extended / Cinematic / Standard stabilization حسب الصيغة
- HEVC، وMain10 عند HDR
- Bitrate مناسب للدقة وFPS
- High-quality photo prioritization
- Content-aware distortion correction للصور
- أعلى `maxPhotoDimensions` للصيغة النشطة

### 5. HDR حقيقي

زر HDR أصبح عاملاً على iOS:

- يختار صيغة HLG/10-bit عند توفرها.
- يضبط `activeColorSpace` إلى `HLG_BT2020`.
- يستخدم HEVC Main10 للتسجيل.
- تعرض الواجهة `HDR ON` فقط إذا أكدت الجلسة الأصلية أنه نشط.

على أي backend لا يستطيع تشغيل HDR، لا يظهر التطبيق حالة ON مزيفة.

### 6. الالتقاط والتسجيل الأصليان

- الصور تلتقط عبر `AVCapturePhotoOutput` بصيغة HEIF عند توفرها، مع أولوية الجودة القصوى.
- الفيديو يسجل عبر `AVCaptureMovieFileOutput` إلى HEVC مع bitrate وFPS المطلوبين.
- لا توجد إعادة ضغط بعد الالتقاط.
- فحص الأبعاد النهائية وحجم الملف يحدث من الملف الحقيقي قبل الحفظ في Photos.

## الملفات الرئيسية المعدلة

- `ios/Runner/AppDelegate.swift`: محرك AVFoundation، Platform View، HDR، HEVC، focus/exposure/zoom/flash، الصور والفيديو.
- `lib/features/camera/data/datasources/camera_local_data_source.dart`: اختيار المحرك الأصلي على iOS والإبقاء على CameraX في Android.
- `lib/core/services/resolution_selection_service.dart`: تفضيل أعلى فيديو 16:9 بدلاً من أعلى صيغة 4:3 الخام.
- `lib/features/camera/presentation/widgets/camera_preview_surface.dart`: عرض Platform View الأصلي على iOS.
- `lib/features/camera/presentation/controllers/camera_controller_getx.dart`: HDR حقيقي، اختيار multi-lens، واستعادة صيغة الفيديو عند تغيير الوضع.

## التحقق

- `flutter analyze`: بدون أخطاء.
- جميع الاختبارات الأربعة ناجحة؛ واختبار اختيار الدقة يتأكد صراحةً أن `3840×2160` يسبق `4032×3024` للفيديو.
- بناء iOS Simulator: ناجح.
- بناء iOS Release للجهاز والتوقيع: ناجح.
- تثبيت النسخة على iPhone 15 Pro: ناجح.
- بناء Android Debug APK: ناجح.

### نتيجة التشغيل الفعلية على iPhone 15 Pro

تم تشغيل نسخة Release الموقعة على الجهاز نفسه، وسجّل المحرك الأصلي القيم التالية:

```text
device=Back Dual Camera
format=3840x2160
fps=30
pixel=x420 (10-bit)
hdr=ON
codec=HEVC
photoMax=4224x2376
```

هذه قيم AVFoundation الفعلية بعد بدء الجلسة، وليست قيماً ثابتة مكتوبة في الواجهة. وهي تؤكد تشغيل معاينة/تسجيل 4K 16:9 مع HDR وHEVC على الجهاز، واستخدام دقة منفصلة أعلى للصورة الثابتة.

## ملاحظة واقعية

الجودة النهائية تعتمد أيضاً على الإضاءة، العدسة المختارة، حرارة الجهاز، FPS وHDR. الهدف الصحيح ليس عرض أكبر رقم، بل اختيار أعلى مسار فيديو يعالجه الجهاز بصورة مستقرة. الحل الجديد يفعل ذلك ويترك صيغة المستشعر الأكبر للصور بدلاً من استخدامها كمعاينة فيديو غير مناسبة.
