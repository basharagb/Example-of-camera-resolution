# Bashar Camera

A one-page, capability-aware Flutter camera for Android and iOS. It uses GetX and a feature-first Clean Architecture boundary around custom native capture engines: CameraX with a direct PreviewView/SurfaceView on Android and AVFoundation with AVCaptureVideoPreviewLayer on iOS.

## Quality behavior

- The app reads real `MediaRecorder` output sizes on Android and `AVCaptureDevice.Format` dimensions on iOS.
- Android no longer sends the live preview through a Flutter camera texture; a native CameraX 1.6.1 `PreviewView` renders directly to a performance-mode SurfaceView.
- Android recording uses the closest real `QualitySelector` profile, maximum-quality JPEG capture, stabilization, tap AF/AE/AWB and HLG 10-bit HDR when the active camera exposes it.
- It never adds an 8K, 4K, HDR, or FPS label that is absent from the selected physical camera's native capability table.
- Video startup requests the highest processed 16:9 mode first. Larger 4:3 sensor modes remain available as MAX/photo modes rather than being misleadingly used for fullscreen video preview.
- Flutter camera 0.12's explicit FPS and video-bitrate settings are used for recording.
- iOS uses an exact `AVCaptureDevice.Format`, a native `AVCaptureVideoPreviewLayer`, HEVC, real HDR/HLG selection and hardware stabilization. It no longer routes preview or capture through a Flutter texture.
- Actual photo/video files are inspected natively after capture, and the UI reports their final pixel dimensions and file size.
- Original camera files are copied directly into MediaStore or Photos. There is no resize or post-recording recompression.
- Still capture temporarily moves to the camera's maximum mode when a lower recording mode was selected.

HDR capability is shown truthfully. The custom iOS engine enables HLG/10-bit HDR and HEVC Main10 when the exact format supports it; unsupported backends never show a fake active state.

## Structure

```text
lib/
  core/                         constants, failures, permissions, services
  features/camera/
    data/                       camera plugin + MethodChannel data source
    domain/                     entities, repository contracts, use cases
    presentation/               GetX binding/controller, page, widgets
  routes/
```

The command flow is:

```text
CameraPage → CameraControllerGetX → use case → repository → local data source
```

Only the small `CameraPreviewSurface` rendering adapter knows about the camera plugin's preview handle; all camera commands remain behind domain use cases.

## Run

```bash
flutter pub get
flutter run
```

Use a physical device for camera testing. Android emulators and the iOS Simulator do not expose a representative high-resolution physical-camera mode table.

The project currently targets Flutter stable 3.44.8 / Dart 3.12.2, Android Java 17 with Flutter's API 24 minimum, and iOS 13 or newer. `compileSdk` is 37 because `permission_handler` 13 requires that SDK while runtime compatibility remains unchanged.

## Verification

```bash
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator --debug
```

Launcher icons are generated from `ic_launcher/1024.png` with `flutter_launcher_icons: 0.14.4`.
