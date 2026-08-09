import AVFoundation
import Flutter
import ImageIO
import Photos
import UIKit
import VideoToolbox

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let channelName = "com.highest.camera.apex_camera/capabilities"
  private var capabilityChannel: FlutterMethodChannel?
  private let nativeCamera = NativeCameraEngine()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    capabilityChannel = channel
    engineBridge.applicationRegistrar.register(
      NativeCameraPreviewFactory(engine: nativeCamera),
      withId: "apex_camera_preview"
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      do {
        switch call.method {
        case "getCameraCapabilities": result(self.getCameraCapabilities())
        case "initializeNativeCamera": self.nativeCamera.initialize(call, result: result)
        case "disposeNativeCamera": self.nativeCamera.dispose(result: result)
        case "captureNativePhoto": self.nativeCamera.capturePhoto(result: result)
        case "startNativeVideo": self.nativeCamera.startVideo(result: result)
        case "stopNativeVideo": self.nativeCamera.stopVideo(result: result)
        case "pauseNativeVideo": self.nativeCamera.pauseVideo(result: result)
        case "resumeNativeVideo": self.nativeCamera.resumeVideo(result: result)
        case "setNativeFlashMode": self.nativeCamera.setFlashMode(call, result: result)
        case "setNativeZoom": self.nativeCamera.setZoom(call, result: result)
        case "setNativeFocusPoint": self.nativeCamera.setFocus(call, exposure: false, result: result)
        case "setNativeExposurePoint": self.nativeCamera.setFocus(call, exposure: true, result: result)
        case "setNativeExposureOffset": self.nativeCamera.setExposureOffset(call, result: result)
        case "inspectMedia": result(try self.inspectMedia(call))
        case "saveMedia": try self.saveMedia(call, result: result)
        case "getAvailableStorageBytes": result(self.availableStorageBytes())
        case "getThermalState": result(self.thermalState())
        default: result(FlutterMethodNotImplemented)
        }
      } catch {
        result(FlutterError(
          code: "NATIVE_CAMERA_ERROR",
          message: error.localizedDescription,
          details: String(describing: error)
        ))
      }
    }
  }

  private func getCameraCapabilities() -> [[String: Any]] {
    let discovery = AVCaptureDevice.DiscoverySession(
      deviceTypes: [
        .builtInWideAngleCamera,
        .builtInUltraWideCamera,
        .builtInTelephotoCamera,
        .builtInDualCamera,
        .builtInDualWideCamera,
        .builtInTripleCamera,
        .builtInTrueDepthCamera,
      ],
      mediaType: .video,
      position: .unspecified
    )
    return discovery.devices.map { device in
      var modes: [String: [String: Any]] = [:]
      var photoWidth: Int32 = 0
      var photoHeight: Int32 = 0
      var stabilizationSupported = false

      for format in device.formats {
        let description = format.formatDescription
        // Match camera_avfoundation's safe maximum-mode filter.
        if CMFormatDescriptionGetMediaSubType(description) == 1_651_798_066 { continue }
        let dimensions = CMVideoFormatDescriptionGetDimensions(description)
        if dimensions.width == dimensions.height { continue }
        let maxFps = Int(format.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 1)
        var supportedFps = [24, 25, 30, 48, 50, 60, 120, 240].filter { fps in
          format.videoSupportedFrameRateRanges.contains { range in
            Double(fps) >= range.minFrameRate && Double(fps) <= range.maxFrameRate
          }
        }
        if supportedFps.isEmpty { supportedFps = [max(1, maxFps)] }
        var hdrSupported = format.isVideoHDRSupported
        if #available(iOS 14.1, *) {
          hdrSupported = hdrSupported || format.supportedColorSpaces.contains(.HLG_BT2020)
        }
        stabilizationSupported = stabilizationSupported ||
          format.isVideoStabilizationModeSupported(.standard)
        let key = "\(dimensions.width)x\(dimensions.height)"
        if let existing = modes[key] {
          let existingFps = existing["supportedFps"] as? [Int] ?? []
          modes[key] = [
            "width": Int(dimensions.width),
            "height": Int(dimensions.height),
            "maxFps": max(existing["maxFps"] as? Int ?? 1, maxFps),
            "supportedFps": Array(Set(existingFps + supportedFps)).sorted(),
            "hdrSupported": (existing["hdrSupported"] as? Bool ?? false) || hdrSupported,
          ]
        } else {
          modes[key] = [
            "width": Int(dimensions.width),
            "height": Int(dimensions.height),
            "maxFps": max(1, maxFps),
            "supportedFps": supportedFps,
            "hdrSupported": hdrSupported,
          ]
        }

        if #available(iOS 16.0, *) {
          for photoDimensions in format.supportedMaxPhotoDimensions {
            if Int64(photoDimensions.width) * Int64(photoDimensions.height) >
              Int64(photoWidth) * Int64(photoHeight) {
              photoWidth = photoDimensions.width
              photoHeight = photoDimensions.height
            }
          }
        } else {
          let photoDimensions = format.highResolutionStillImageDimensions
          if Int64(photoDimensions.width) * Int64(photoDimensions.height) >
            Int64(photoWidth) * Int64(photoHeight) {
            photoWidth = photoDimensions.width
            photoHeight = photoDimensions.height
          }
        }
      }

      let sortedModes = modes.values.sorted {
        let left = ($0["width"] as? Int ?? 0) * ($0["height"] as? Int ?? 0)
        let right = ($1["width"] as? Int ?? 0) * ($1["height"] as? Int ?? 0)
        return left > right
      }
      return [
        "id": device.uniqueID,
        "name": device.localizedName,
        "lensDirection": lensDirection(device.position),
        "lensType": lensType(device.deviceType),
        "sensorOrientation": 90,
        "focalLengths": [device.activeFormat.videoFieldOfView],
        "flashSupported": device.hasFlash || device.hasTorch,
        "videoStabilizationSupported": stabilizationSupported,
        "opticalStabilizationSupported": false,
        "photoWidth": Int(photoWidth),
        "photoHeight": Int(photoHeight),
        "resolutions": sortedModes,
      ]
    }
  }

  private func lensDirection(_ position: AVCaptureDevice.Position) -> String {
    switch position {
    case .front: return "front"
    case .back: return "back"
    default: return "external"
    }
  }

  private func lensType(_ type: AVCaptureDevice.DeviceType) -> String {
    switch type {
    case .builtInUltraWideCamera: return "Ultra-wide"
    case .builtInTelephotoCamera: return "Telephoto"
    case .builtInTripleCamera, .builtInDualCamera, .builtInDualWideCamera: return "Multi-lens"
    case .builtInTrueDepthCamera: return "TrueDepth"
    default: return "Wide"
    }
  }

  private func arguments(_ call: FlutterMethodCall) throws -> [String: Any] {
    guard let arguments = call.arguments as? [String: Any] else {
      throw NSError(domain: "ApexCamera", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing arguments"])
    }
    return arguments
  }

  private func inspectMedia(_ call: FlutterMethodCall) throws -> [String: Int] {
    let args = try arguments(call)
    guard let path = args["path"] as? String, let type = args["type"] as? String else {
      throw NSError(domain: "ApexCamera", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing media path or type"])
    }
    let url = URL(fileURLWithPath: path)
    if type == "photo" {
      guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
      else { return ["width": 0, "height": 0] }
      return [
        "width": (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0,
        "height": (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0,
      ]
    }
    let asset = AVURLAsset(url: url)
    guard let track = asset.tracks(withMediaType: .video).first else {
      return ["width": 0, "height": 0]
    }
    let transformed = track.naturalSize.applying(track.preferredTransform)
    return [
      "width": Int(abs(transformed.width).rounded()),
      "height": Int(abs(transformed.height).rounded()),
    ]
  }

  private func saveMedia(_ call: FlutterMethodCall, result: @escaping FlutterResult) throws {
    let args = try arguments(call)
    guard let path = args["path"] as? String, let type = args["type"] as? String else {
      throw NSError(domain: "ApexCamera", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing media path or type"])
    }
    let url = URL(fileURLWithPath: path)
    var localIdentifier: String?
    PHPhotoLibrary.shared().performChanges {
      let request: PHAssetChangeRequest?
      if type == "video" {
        request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
      } else {
        request = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
      }
      localIdentifier = request?.placeholderForCreatedAsset?.localIdentifier
    } completionHandler: { success, error in
      DispatchQueue.main.async {
        if success, let identifier = localIdentifier {
          result(identifier)
        } else {
          result(FlutterError(
            code: "GALLERY_SAVE_FAILED",
            message: error?.localizedDescription ?? "The media could not be saved.",
            details: nil
          ))
        }
      }
    }
  }

  private func availableStorageBytes() -> Int64 {
    let home = URL(fileURLWithPath: NSHomeDirectory())
    let values = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
    return values?.volumeAvailableCapacityForImportantUsage ?? 0
  }

  private func thermalState() -> String {
    switch ProcessInfo.processInfo.thermalState {
    case .nominal: return "nominal"
    case .fair: return "fair"
    case .serious: return "serious"
    case .critical: return "critical"
    @unknown default: return "unknown"
    }
  }
}

private enum NativeCameraError: LocalizedError {
  case invalidArguments
  case cameraUnavailable
  case formatUnavailable(Int, Int, Int)
  case inputUnavailable(String)
  case outputUnavailable(String)
  case sessionUnavailable
  case captureInProgress
  case recordingUnavailable
  case pauseUnavailable

  var errorDescription: String? {
    switch self {
    case .invalidArguments: return "The native camera received invalid arguments."
    case .cameraUnavailable: return "The selected AVCaptureDevice is unavailable."
    case let .formatUnavailable(width, height, fps):
      return "The exact native format \(width)×\(height) at \(fps) FPS is unavailable."
    case let .inputUnavailable(name): return "The \(name) camera input could not be added."
    case let .outputUnavailable(name): return "The \(name) camera output could not be added."
    case .sessionUnavailable: return "The native camera session is not running."
    case .captureInProgress: return "Another native capture is already in progress."
    case .recordingUnavailable: return "The native movie output is not recording."
    case .pauseUnavailable: return "Native pause and resume require iOS 18 or newer."
    }
  }
}

private final class NativeCameraPreviewView: UIView {
  override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

  var previewLayer: AVCaptureVideoPreviewLayer {
    layer as! AVCaptureVideoPreviewLayer
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .black
    previewLayer.videoGravity = .resizeAspectFill
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    backgroundColor = .black
    previewLayer.videoGravity = .resizeAspectFill
  }

  func attach(session: AVCaptureSession, frontFacing: Bool) {
    previewLayer.session = session
    previewLayer.videoGravity = .resizeAspectFill
    guard let connection = previewLayer.connection else { return }
    if #available(iOS 17.0, *) {
      if connection.isVideoRotationAngleSupported(90) {
        connection.videoRotationAngle = 90
      }
    } else if connection.isVideoOrientationSupported {
      connection.videoOrientation = .portrait
    }
    if connection.isVideoMirroringSupported {
      connection.automaticallyAdjustsVideoMirroring = false
      connection.isVideoMirrored = frontFacing
    }
  }

  func devicePoint(x: CGFloat, y: CGFloat) -> CGPoint {
    previewLayer.captureDevicePointConverted(
      fromLayerPoint: CGPoint(x: bounds.width * x, y: bounds.height * y)
    )
  }
}

private final class NativeCameraPlatformView: NSObject, FlutterPlatformView {
  private let preview: NativeCameraPreviewView

  init(frame: CGRect, engine: NativeCameraEngine) {
    preview = NativeCameraPreviewView(frame: frame)
    super.init()
    engine.attachPreview(preview)
  }

  func view() -> UIView { preview }
}

private final class NativeCameraPreviewFactory: NSObject, FlutterPlatformViewFactory {
  private let engine: NativeCameraEngine

  init(engine: NativeCameraEngine) {
    self.engine = engine
    super.init()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    NativeCameraPlatformView(frame: frame, engine: engine)
  }
}

private final class NativeCameraEngine: NSObject,
  AVCapturePhotoCaptureDelegate,
  AVCaptureFileOutputRecordingDelegate
{
  let session = AVCaptureSession()
  private let sessionQueue = DispatchQueue(label: "com.highest.camera.apex.native-session")
  private let photoOutput = AVCapturePhotoOutput()
  private let movieOutput = AVCaptureMovieFileOutput()
  private weak var previewView: NativeCameraPreviewView?
  private var videoDevice: AVCaptureDevice?
  private var activeDimensions = CMVideoDimensions(width: 0, height: 0)
  private var isFrontFacing = false
  private var hdrActive = false
  private var activeCodec = "unknown"
  private var flashMode: AVCaptureDevice.FlashMode = .off
  private var photoResult: FlutterResult?
  private var stopVideoResult: FlutterResult?
  private var photoURL: URL?

  func attachPreview(_ preview: NativeCameraPreviewView) {
    previewView = preview
    preview.attach(session: session, frontFacing: isFrontFacing)
  }

  func initialize(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let cameraId = args["cameraId"] as? String,
      let width = args["width"] as? Int,
      let height = args["height"] as? Int,
      let fps = args["fps"] as? Int
    else {
      finish(result, error: NativeCameraError.invalidArguments)
      return
    }
    let enableAudio = args["enableAudio"] as? Bool ?? false
    let enableHdr = args["enableHdr"] as? Bool ?? false
    let videoBitrate = args["videoBitrate"] as? Int ?? 48_000_000

    sessionQueue.async { [weak self] in
      guard let self else { return }
      do {
        let info = try self.configure(
          cameraId: cameraId,
          width: width,
          height: height,
          fps: fps,
          enableAudio: enableAudio,
          enableHdr: enableHdr,
          videoBitrate: videoBitrate
        )
        if !self.session.isRunning { self.session.startRunning() }
        DispatchQueue.main.async {
          self.previewView?.attach(session: self.session, frontFacing: self.isFrontFacing)
          result(info)
        }
      } catch {
        self.finish(result, error: error)
      }
    }
  }

  private func configure(
    cameraId: String,
    width: Int,
    height: Int,
    fps: Int,
    enableAudio: Bool,
    enableHdr: Bool,
    videoBitrate: Int
  ) throws -> [String: Any] {
    if session.isRunning { session.stopRunning() }
    session.beginConfiguration()
    defer { session.commitConfiguration() }
    session.inputs.forEach(session.removeInput)
    session.outputs.forEach(session.removeOutput)

    guard let device = AVCaptureDevice(uniqueID: cameraId) else {
      throw NativeCameraError.cameraUnavailable
    }
    let videoInput = try AVCaptureDeviceInput(device: device)
    guard session.canAddInput(videoInput) else {
      throw NativeCameraError.inputUnavailable("video")
    }
    session.addInput(videoInput)
    session.sessionPreset = .inputPriority

    if enableAudio,
       let microphone = AVCaptureDevice.default(for: .audio) {
      let audioInput = try AVCaptureDeviceInput(device: microphone)
      if session.canAddInput(audioInput) { session.addInput(audioInput) }
    }

    guard session.canAddOutput(photoOutput) else {
      throw NativeCameraError.outputUnavailable("photo")
    }
    session.addOutput(photoOutput)
    guard session.canAddOutput(movieOutput) else {
      throw NativeCameraError.outputUnavailable("movie")
    }
    session.addOutput(movieOutput)

    guard let format = bestFormat(
      for: device,
      width: width,
      height: height,
      fps: fps,
      hdrRequested: enableHdr
    ) else {
      throw NativeCameraError.formatUnavailable(width, height, fps)
    }

    try device.lockForConfiguration()
    session.automaticallyConfiguresCaptureDeviceForWideColor = false
    device.activeFormat = format
    let frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
    device.activeVideoMinFrameDuration = frameDuration
    device.activeVideoMaxFrameDuration = frameDuration

    if device.isFocusModeSupported(.continuousAutoFocus) {
      device.focusMode = .continuousAutoFocus
    }
    if device.isSmoothAutoFocusSupported { device.isSmoothAutoFocusEnabled = true }
    if device.isExposureModeSupported(.continuousAutoExposure) {
      device.exposureMode = .continuousAutoExposure
    }
    if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
      device.whiteBalanceMode = .continuousAutoWhiteBalance
    }
    device.isSubjectAreaChangeMonitoringEnabled = true
    if device.isLowLightBoostSupported {
      device.automaticallyEnablesLowLightBoostWhenAvailable = true
    }
    if device.isGeometricDistortionCorrectionSupported {
      device.isGeometricDistortionCorrectionEnabled = true
    }
    if format.isGlobalToneMappingSupported {
      device.isGlobalToneMappingEnabled = true
    }

    hdrActive = false
    if enableHdr {
      if #available(iOS 14.1, *), format.supportedColorSpaces.contains(.HLG_BT2020) {
        device.activeColorSpace = .HLG_BT2020
        hdrActive = true
      } else if format.isVideoHDRSupported {
        device.automaticallyAdjustsVideoHDREnabled = false
        device.isVideoHDREnabled = true
        hdrActive = true
      }
    } else {
      if format.isVideoHDRSupported {
        device.automaticallyAdjustsVideoHDREnabled = false
        device.isVideoHDREnabled = false
      }
      if format.supportedColorSpaces.contains(.sRGB) {
        device.activeColorSpace = .sRGB
      }
    }
    device.unlockForConfiguration()

    videoDevice = device
    isFrontFacing = device.position == .front
    activeDimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
    configurePhotoOutput(for: format)
    configureMovieOutput(
      format: format,
      fps: fps,
      bitrate: videoBitrate,
      hdr: hdrActive
    )
    let subtype = fourCC(CMFormatDescriptionGetMediaSubType(format.formatDescription))
    let photoDimensions: String
    if #available(iOS 16.0, *) {
      photoDimensions = "\(photoOutput.maxPhotoDimensions.width)x\(photoOutput.maxPhotoDimensions.height)"
    } else {
      let dimensions = format.highResolutionStillImageDimensions
      photoDimensions = "\(dimensions.width)x\(dimensions.height)"
    }
    NSLog(
      "[ApexNativeCamera] device=%@ format=%dx%d fps=%d pixel=%@ hdr=%@ codec=%@ photoMax=%@",
      device.localizedName,
      activeDimensions.width,
      activeDimensions.height,
      fps,
      subtype,
      hdrActive ? "ON" : "OFF",
      activeCodec,
      photoDimensions
    )

    return [
      "previewWidth": Int(activeDimensions.width),
      "previewHeight": Int(activeDimensions.height),
      "minZoom": Double(device.minAvailableVideoZoomFactor),
      "maxZoom": Double(min(device.maxAvailableVideoZoomFactor, 15)),
      "minExposure": Double(device.minExposureTargetBias),
      "maxExposure": Double(device.maxExposureTargetBias),
      "hdrActive": hdrActive,
      "nativePreview": true,
    ]
  }

  private func bestFormat(
    for device: AVCaptureDevice,
    width: Int,
    height: Int,
    fps: Int,
    hdrRequested: Bool
  ) -> AVCaptureDevice.Format? {
    let candidates = device.formats.filter { format in
      let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
      let exactDimensions = Int(dimensions.width) == width && Int(dimensions.height) == height
      let supportsFps = format.videoSupportedFrameRateRanges.contains {
        Double(fps) >= $0.minFrameRate && Double(fps) <= $0.maxFrameRate
      }
      return exactDimensions && supportsFps
    }
    return candidates.max { left, right in
      formatScore(left, hdrRequested: hdrRequested) <
        formatScore(right, hdrRequested: hdrRequested)
    }
  }

  private func formatScore(
    _ format: AVCaptureDevice.Format,
    hdrRequested: Bool
  ) -> Int {
    let subtype = CMFormatDescriptionGetMediaSubType(format.formatDescription)
    let hdr = isHdrCapable(format)
    var score = 0
    if hdrRequested {
      if hdr { score += 1_000 }
      if subtype == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange { score += 500 }
    } else {
      if !hdr { score += 1_000 }
      if subtype == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange { score += 500 }
      if subtype == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange { score += 400 }
    }
    if format.isVideoStabilizationModeSupported(.cinematicExtended) { score += 80 }
    else if format.isVideoStabilizationModeSupported(.cinematic) { score += 60 }
    else if format.isVideoStabilizationModeSupported(.standard) { score += 40 }
    if format.isGlobalToneMappingSupported { score += 20 }
    return score
  }

  private func isHdrCapable(_ format: AVCaptureDevice.Format) -> Bool {
    if format.isVideoHDRSupported { return true }
    if #available(iOS 14.1, *) {
      return format.supportedColorSpaces.contains(.HLG_BT2020)
    }
    return false
  }

  private func configurePhotoOutput(for format: AVCaptureDevice.Format) {
    photoOutput.maxPhotoQualityPrioritization = .quality
    if #available(iOS 16.0, *) {
      if let largest = format.supportedMaxPhotoDimensions.max(by: {
        Int64($0.width) * Int64($0.height) < Int64($1.width) * Int64($1.height)
      }) {
        photoOutput.maxPhotoDimensions = largest
      }
    } else {
      photoOutput.isHighResolutionCaptureEnabled = true
    }
    if #available(iOS 14.1, *), photoOutput.isContentAwareDistortionCorrectionSupported {
      photoOutput.isContentAwareDistortionCorrectionEnabled = true
    }
    configureOrientation(photoOutput.connection(with: .video), mirror: false)
  }

  private func configureMovieOutput(
    format: AVCaptureDevice.Format,
    fps: Int,
    bitrate: Int,
    hdr: Bool
  ) {
    movieOutput.movieFragmentInterval = CMTime(seconds: 1, preferredTimescale: 600)
    guard let connection = movieOutput.connection(with: .video) else { return }
    configureOrientation(connection, mirror: false)
    if format.isVideoStabilizationModeSupported(.cinematicExtended) {
      connection.preferredVideoStabilizationMode = .cinematicExtended
    } else if format.isVideoStabilizationModeSupported(.cinematic) {
      connection.preferredVideoStabilizationMode = .cinematic
    } else if format.isVideoStabilizationModeSupported(.standard) {
      connection.preferredVideoStabilizationMode = .standard
    }

    let codec: AVVideoCodecType = movieOutput.availableVideoCodecTypes.contains(.hevc)
      ? .hevc
      : .h264
    activeCodec = codec == .hevc ? "HEVC" : "H.264"
    var settings: [String: Any] = [AVVideoCodecKey: codec]
    let supportedKeys = Set(movieOutput.supportedOutputSettingsKeys(for: connection))
    if supportedKeys.contains(AVVideoCompressionPropertiesKey) {
      var compression: [String: Any] = [
        AVVideoAverageBitRateKey: bitrate,
        AVVideoExpectedSourceFrameRateKey: fps,
        AVVideoMaxKeyFrameIntervalKey: fps,
      ]
      if codec == .hevc {
        compression[AVVideoProfileLevelKey] = hdr
          ? kVTProfileLevel_HEVC_Main10_AutoLevel
          : kVTProfileLevel_HEVC_Main_AutoLevel
      } else {
        compression[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel
      }
      settings[AVVideoCompressionPropertiesKey] = compression
    }
    movieOutput.setOutputSettings(settings, for: connection)
  }

  private func fourCC(_ value: FourCharCode) -> String {
    let bytes: [UInt8] = [
      UInt8((value >> 24) & 0xff),
      UInt8((value >> 16) & 0xff),
      UInt8((value >> 8) & 0xff),
      UInt8(value & 0xff),
    ]
    return String(bytes: bytes, encoding: .ascii) ?? String(format: "0x%08x", value)
  }

  private func configureOrientation(_ connection: AVCaptureConnection?, mirror: Bool) {
    guard let connection else { return }
    if #available(iOS 17.0, *) {
      if connection.isVideoRotationAngleSupported(90) {
        connection.videoRotationAngle = 90
      }
    } else if connection.isVideoOrientationSupported {
      connection.videoOrientation = .portrait
    }
    if connection.isVideoMirroringSupported {
      connection.automaticallyAdjustsVideoMirroring = false
      connection.isVideoMirrored = mirror
    }
  }

  func dispose(result: @escaping FlutterResult) {
    sessionQueue.async { [weak self] in
      guard let self else { return }
      if self.movieOutput.isRecording { self.movieOutput.stopRecording() }
      if self.session.isRunning { self.session.stopRunning() }
      self.finish(result, value: nil)
    }
  }

  func capturePhoto(result: @escaping FlutterResult) {
    sessionQueue.async { [weak self] in
      guard let self else { return }
      guard self.session.isRunning else {
        self.finish(result, error: NativeCameraError.sessionUnavailable)
        return
      }
      guard self.photoResult == nil else {
        self.finish(result, error: NativeCameraError.captureInProgress)
        return
      }
      let settings: AVCapturePhotoSettings
      if self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
        settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
      } else {
        settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
      }
      settings.photoQualityPrioritization = .quality
      if #available(iOS 16.0, *) {
        settings.maxPhotoDimensions = self.photoOutput.maxPhotoDimensions
      } else {
        settings.isHighResolutionPhotoEnabled = true
      }
      if #available(iOS 14.1, *) {
        settings.isAutoContentAwareDistortionCorrectionEnabled = true
      }
      if self.videoDevice?.hasFlash == true {
        settings.flashMode = self.flashMode
      }
      self.configureOrientation(self.photoOutput.connection(with: .video), mirror: false)
      let ext = self.photoOutput.availablePhotoCodecTypes.contains(.hevc) ? "heic" : "jpg"
      self.photoURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("Bashar_\(UUID().uuidString).\(ext)")
      self.photoResult = result
      self.photoOutput.capturePhoto(with: settings, delegate: self)
    }
  }

  func photoOutput(
    _ output: AVCapturePhotoOutput,
    didFinishProcessingPhoto photo: AVCapturePhoto,
    error: Error?
  ) {
    guard let result = photoResult else { return }
    photoResult = nil
    if let error {
      finish(result, error: error)
      return
    }
    guard let data = photo.fileDataRepresentation(), let url = photoURL else {
      finish(result, error: NativeCameraError.outputUnavailable("photo file"))
      return
    }
    do {
      try data.write(to: url, options: .atomic)
      finish(result, value: url.path)
    } catch {
      finish(result, error: error)
    }
  }

  func startVideo(result: @escaping FlutterResult) {
    sessionQueue.async { [weak self] in
      guard let self else { return }
      guard self.session.isRunning, !self.movieOutput.isRecording else {
        self.finish(result, error: NativeCameraError.captureInProgress)
        return
      }
      let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("Bashar_\(UUID().uuidString).mov")
      try? FileManager.default.removeItem(at: url)
      self.configureOrientation(self.movieOutput.connection(with: .video), mirror: false)
      self.movieOutput.startRecording(to: url, recordingDelegate: self)
      self.finish(result, value: nil)
    }
  }

  func stopVideo(result: @escaping FlutterResult) {
    sessionQueue.async { [weak self] in
      guard let self else { return }
      guard self.movieOutput.isRecording else {
        self.finish(result, error: NativeCameraError.recordingUnavailable)
        return
      }
      guard self.stopVideoResult == nil else {
        self.finish(result, error: NativeCameraError.captureInProgress)
        return
      }
      self.stopVideoResult = result
      self.movieOutput.stopRecording()
    }
  }

  func fileOutput(
    _ output: AVCaptureFileOutput,
    didFinishRecordingTo outputFileURL: URL,
    from connections: [AVCaptureConnection],
    error: Error?
  ) {
    guard let result = stopVideoResult else { return }
    stopVideoResult = nil
    if let error = error as NSError? {
      let completed = error.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool ?? false
      if !completed {
        finish(result, error: error)
        return
      }
    }
    finish(result, value: outputFileURL.path)
  }

  func pauseVideo(result: @escaping FlutterResult) {
    sessionQueue.async { [weak self] in
      guard let self else { return }
      guard self.movieOutput.isRecording else {
        self.finish(result, error: NativeCameraError.recordingUnavailable)
        return
      }
      if #available(iOS 18.0, *) {
        self.movieOutput.pauseRecording()
        self.finish(result, value: nil)
      } else {
        self.finish(result, error: NativeCameraError.pauseUnavailable)
      }
    }
  }

  func resumeVideo(result: @escaping FlutterResult) {
    sessionQueue.async { [weak self] in
      guard let self else { return }
      if #available(iOS 18.0, *) {
        guard self.movieOutput.isRecordingPaused else {
          self.finish(result, error: NativeCameraError.recordingUnavailable)
          return
        }
        self.movieOutput.resumeRecording()
        self.finish(result, value: nil)
      } else {
        self.finish(result, error: NativeCameraError.pauseUnavailable)
      }
    }
  }

  func setFlashMode(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any], let mode = args["mode"] as? String else {
      finish(result, error: NativeCameraError.invalidArguments)
      return
    }
    flashMode = mode == "auto" ? .auto : mode == "always" ? .on : .off
    sessionQueue.async { [weak self] in
      guard let self, let device = self.videoDevice else { return }
      do {
        try device.lockForConfiguration()
        if mode == "torch", device.hasTorch {
          try device.setTorchModeOn(level: min(1, AVCaptureDevice.maxAvailableTorchLevel))
        } else if device.hasTorch {
          device.torchMode = .off
        }
        device.unlockForConfiguration()
        self.finish(result, value: nil)
      } catch {
        self.finish(result, error: error)
      }
    }
  }

  func setZoom(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any], let zoom = args["zoom"] as? Double else {
      finish(result, error: NativeCameraError.invalidArguments)
      return
    }
    sessionQueue.async { [weak self] in
      guard let self, let device = self.videoDevice else { return }
      do {
        try device.lockForConfiguration()
        device.videoZoomFactor = min(max(zoom, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
        device.unlockForConfiguration()
        self.finish(result, value: nil)
      } catch {
        self.finish(result, error: error)
      }
    }
  }

  func setFocus(
    _ call: FlutterMethodCall,
    exposure: Bool,
    result: @escaping FlutterResult
  ) {
    guard
      let args = call.arguments as? [String: Any],
      let x = args["x"] as? Double,
      let y = args["y"] as? Double
    else {
      finish(result, error: NativeCameraError.invalidArguments)
      return
    }
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      let point = self.previewView?.devicePoint(x: x, y: y) ?? CGPoint(x: x, y: y)
      self.sessionQueue.async {
        guard let device = self.videoDevice else { return }
        do {
          try device.lockForConfiguration()
          if exposure, device.isExposurePointOfInterestSupported {
            device.exposurePointOfInterest = point
            if device.isExposureModeSupported(.continuousAutoExposure) {
              device.exposureMode = .continuousAutoExposure
            }
          } else if !exposure, device.isFocusPointOfInterestSupported {
            device.focusPointOfInterest = point
            if device.isFocusModeSupported(.continuousAutoFocus) {
              device.focusMode = .continuousAutoFocus
            }
          }
          device.unlockForConfiguration()
          self.finish(result, value: nil)
        } catch {
          self.finish(result, error: error)
        }
      }
    }
  }

  func setExposureOffset(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any], let offset = args["offset"] as? Double else {
      finish(result, error: NativeCameraError.invalidArguments)
      return
    }
    sessionQueue.async { [weak self] in
      guard let self, let device = self.videoDevice else { return }
      do {
        try device.lockForConfiguration()
        let value = min(max(Float(offset), device.minExposureTargetBias), device.maxExposureTargetBias)
        device.setExposureTargetBias(value)
        device.unlockForConfiguration()
        self.finish(result, value: nil)
      } catch {
        self.finish(result, error: error)
      }
    }
  }

  private func finish(_ result: @escaping FlutterResult, value: Any?) {
    DispatchQueue.main.async { result(value) }
  }

  private func finish(_ result: @escaping FlutterResult, error: Error) {
    NSLog("[ApexNativeCamera] error=%@", error.localizedDescription)
    DispatchQueue.main.async {
      result(FlutterError(
        code: "NATIVE_CAMERA_ERROR",
        message: error.localizedDescription,
        details: String(describing: error)
      ))
    }
  }
}
