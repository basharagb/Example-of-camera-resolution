package com.highest.camera.apex_camera

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import android.util.Range
import android.util.Size
import android.view.Surface
import android.view.View
import androidx.camera.camera2.interop.Camera2CameraInfo
import androidx.camera.core.AspectRatio
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.DynamicRange
import androidx.camera.core.FocusMeteringAction
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.Preview
import androidx.camera.core.resolutionselector.AspectRatioStrategy
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.video.FileOutputOptions
import androidx.camera.video.Quality
import androidx.camera.video.QualitySelector
import androidx.camera.video.Recorder
import androidx.camera.video.Recording
import androidx.camera.video.VideoCapture
import androidx.camera.video.VideoRecordEvent
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.common.StandardMessageCodec
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.math.abs
import kotlin.math.roundToInt

internal class NativeCameraPreviewFactory(
    private val context: Context,
    private val engine: NativeCameraEngine,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        NativeCameraPreviewPlatformView(this.context, engine)
}

private class NativeCameraPreviewPlatformView(
    context: Context,
    private val engine: NativeCameraEngine,
) : PlatformView {
    private val previewView = PreviewView(context).apply {
        // Flutter's hybrid composition cannot reliably place its controls over
        // an OEM SurfaceView (notably Honor/MagicOS). COMPATIBLE uses CameraX's
        // native TextureView inside the platform view, preserving the direct
        // camera path while allowing Flutter overlays to remain visible.
        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        scaleType = PreviewView.ScaleType.FILL_CENTER
    }

    init {
        engine.attachPreviewView(previewView)
    }

    override fun getView(): View = previewView

    override fun dispose() {
        engine.detachPreviewView(previewView)
    }
}

internal class NativeCameraEngine(private val activity: MainActivity) {
    companion object {
        private const val TAG = "ApexNativeCamera"
    }

    private val mainExecutor = ContextCompat.getMainExecutor(activity)
    private val cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var provider: ProcessCameraProvider? = null
    private var previewView: PreviewView? = null
    private var preview: Preview? = null
    private var imageCapture: ImageCapture? = null
    private var videoCapture: VideoCapture<Recorder>? = null
    private var camera: Camera? = null
    private var recording: Recording? = null
    private var pendingStopResult: MethodChannel.Result? = null
    private var recordingFile: File? = null
    private var audioEnabled = true

    fun attachPreviewView(view: PreviewView) {
        previewView = view
        preview?.setSurfaceProvider(view.surfaceProvider)
    }

    fun detachPreviewView(view: PreviewView) {
        if (previewView === view) {
            preview?.setSurfaceProvider(null)
            previewView = null
        }
    }

    fun initialize(callArguments: Map<*, *>, result: MethodChannel.Result) {
        val cameraId = callArguments["cameraId"]?.toString() ?: return result.error(
            "ANDROID_CAMERA_ARGUMENT", "Missing cameraId", null,
        )
        val width = (callArguments["width"] as? Number)?.toInt() ?: 1920
        val height = (callArguments["height"] as? Number)?.toInt() ?: 1080
        val fps = (callArguments["fps"] as? Number)?.toInt()?.coerceIn(24, 60) ?: 30
        val bitrate = (callArguments["videoBitrate"] as? Number)?.toInt() ?: 16_000_000
        val photoWidth = (callArguments["photoWidth"] as? Number)?.toInt() ?: width
        val photoHeight = (callArguments["photoHeight"] as? Number)?.toInt() ?: height
        val enableHdr = callArguments["enableHdr"] == true
        val enableVideoStabilization = callArguments["videoStabilizationSupported"] == true
        val preferPhoto = callArguments["preferPhoto"] == true
        audioEnabled = callArguments["enableAudio"] != false

        disposeSession()
        val providerFuture = ProcessCameraProvider.getInstance(activity)
        providerFuture.addListener({
            try {
                val cameraProvider = providerFuture.get()
                provider = cameraProvider
                bindSession(
                    cameraProvider = cameraProvider,
                    cameraId = cameraId,
                    requestedSize = Size(width, height),
                    photoSize = Size(photoWidth, photoHeight),
                    fps = fps,
                    bitrate = bitrate,
                    requestHdr = enableHdr,
                    enableVideoStabilization = enableVideoStabilization,
                    preferPhoto = preferPhoto,
                    result = result,
                )
            } catch (error: Throwable) {
                Log.e(TAG, "Camera provider initialization failed", error)
                result.error("ANDROID_CAMERA_INIT", error.message, Log.getStackTraceString(error))
            }
        }, mainExecutor)
    }

    private fun bindSession(
        cameraProvider: ProcessCameraProvider,
        cameraId: String,
        requestedSize: Size,
        photoSize: Size,
        fps: Int,
        bitrate: Int,
        requestHdr: Boolean,
        enableVideoStabilization: Boolean,
        preferPhoto: Boolean,
        result: MethodChannel.Result,
    ) {
        val selector = CameraSelector.Builder()
            .addCameraFilter { infos ->
                infos.filter { info ->
                    runCatching { Camera2CameraInfo.from(info).cameraId == cameraId }.getOrDefault(false)
                }
            }
            .build()
        val cameraInfo = cameraProvider.availableCameraInfos.firstOrNull { info ->
            runCatching { Camera2CameraInfo.from(info).cameraId == cameraId }.getOrDefault(false)
        } ?: error("Camera $cameraId is not available through CameraX")

        // Several Honor/Huawei devices expose UHD Camera2 streams while their
        // vendor CamcorderProfile table stops at FHD. Codec capabilities reveal
        // the real encoder-backed qualities instead of silently losing 4K.
        val capabilities = Recorder.getVideoCapabilities(
            cameraInfo,
            Recorder.VIDEO_CAPABILITIES_SOURCE_CODEC_CAPABILITIES,
        )
        val hdrQualities = if (
            requestHdr && capabilities.supportedDynamicRanges.contains(DynamicRange.HLG_10_BIT)
        ) {
            capabilities.getSupportedQualities(DynamicRange.HLG_10_BIT)
        } else {
            emptyList()
        }
        val closestHdrQuality = hdrQualities.minByOrNull { candidate ->
            val size = capabilities.getResolution(candidate, DynamicRange.HLG_10_BIT) ?: requestedSize
            resolutionDistance(size, requestedSize)
        }
        val closestHdrSize = closestHdrQuality?.let {
            capabilities.getResolution(it, DynamicRange.HLG_10_BIT)
        }
        // Sharpness has priority: never silently reduce requested 4K to 1080p
        // merely because HLG is available only on a lower profile.
        val hdrActive = closestHdrSize != null && matchesRequestedVideoSize(closestHdrSize, requestedSize)
        val dynamicRange = if (hdrActive) DynamicRange.HLG_10_BIT else DynamicRange.SDR
        val supportedQualities = capabilities.getSupportedQualities(dynamicRange)
        if (supportedQualities.isEmpty()) error("The selected camera exposes no recordable video quality")
        val quality = if (hdrActive && closestHdrQuality != null) {
            closestHdrQuality
        } else {
            supportedQualities.minByOrNull { candidate ->
                val size = capabilities.getResolution(candidate, dynamicRange) ?: requestedSize
                resolutionDistance(size, requestedSize)
            } ?: supportedQualities.first()
        }
        val actualVideoSize = capabilities.getResolution(quality, dynamicRange) ?: requestedSize

        val previewSelector = ResolutionSelector.Builder()
            .setAspectRatioStrategy(AspectRatioStrategy.RATIO_16_9_FALLBACK_AUTO_STRATEGY)
            .setResolutionStrategy(
                ResolutionStrategy(
                    requestedSize,
                    ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER,
                ),
            )
            .build()
        val photoSelector = ResolutionSelector.Builder()
            .setResolutionStrategy(
                ResolutionStrategy(
                    photoSize,
                    ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER,
                ),
            )
            .build()

        preview = Preview.Builder()
            .setResolutionSelector(previewSelector)
            .setTargetRotation(Surface.ROTATION_0)
            .setTargetFrameRate(Range(fps, fps))
            .setDynamicRange(dynamicRange)
            .build()
            .also { useCase -> previewView?.let { useCase.setSurfaceProvider(it.surfaceProvider) } }

        imageCapture = ImageCapture.Builder()
            .setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY)
            .setResolutionSelector(photoSelector)
            .setJpegQuality(100)
            .setTargetRotation(Surface.ROTATION_0)
            .build()

        val recorder = Recorder.Builder()
            .setExecutor(cameraExecutor)
            .setQualitySelector(QualitySelector.from(quality))
            .setVideoCapabilitiesSource(Recorder.VIDEO_CAPABILITIES_SOURCE_CODEC_CAPABILITIES)
            .setTargetVideoEncodingBitRate(bitrate)
            .setAspectRatio(AspectRatio.RATIO_16_9)
            .build()
        videoCapture = VideoCapture.Builder(recorder)
            .setDynamicRange(dynamicRange)
            .setTargetFrameRate(Range(fps, fps))
            .setVideoStabilizationEnabled(enableVideoStabilization)
            .setTargetRotation(Surface.ROTATION_0)
            .build()

        cameraProvider.unbindAll()
        camera = if (preferPhoto) {
            cameraProvider.bindToLifecycle(
                activity,
                selector,
                preview,
                imageCapture,
            )
        } else {
            cameraProvider.bindToLifecycle(
                activity,
                selector,
                preview,
                videoCapture,
            )
        }

        val zoom = camera?.cameraInfo?.zoomState?.value
        val exposure = camera?.cameraInfo?.exposureState
        val exposureStep = exposure?.exposureCompensationStep?.toFloat()?.takeIf { it > 0f } ?: 1f
        val previewResolution = preview?.resolutionInfo?.resolution ?: requestedSize
        val photoResolution = imageCapture?.resolutionInfo?.resolution ?: photoSize
        val boundVideoResolution = videoCapture?.resolutionInfo?.resolution ?: actualVideoSize
        val implementation = camera?.cameraInfo?.implementationType ?: "unknown"
        Log.i(
            TAG,
            "Android device=$cameraId implementation=$implementation preview=${previewResolution.width}x${previewResolution.height} " +
                "video=${boundVideoResolution.width}x${boundVideoResolution.height} fps=$fps hdr=${if (hdrActive) "ON" else "OFF"} " +
                "photo=${photoResolution.width}x${photoResolution.height} view=NativeTextureView",
        )
        result.success(
            mapOf(
                "previewWidth" to previewResolution.width,
                "previewHeight" to previewResolution.height,
                "videoWidth" to boundVideoResolution.width,
                "videoHeight" to boundVideoResolution.height,
                "photoWidth" to photoResolution.width,
                "photoHeight" to photoResolution.height,
                "minZoom" to (zoom?.minZoomRatio ?: 1f).toDouble(),
                "maxZoom" to (zoom?.maxZoomRatio ?: 1f).toDouble(),
                "minExposure" to ((exposure?.exposureCompensationRange?.lower ?: 0) * exposureStep).toDouble(),
                "maxExposure" to ((exposure?.exposureCompensationRange?.upper ?: 0) * exposureStep).toDouble(),
                "hdrActive" to hdrActive,
            ),
        )
    }

    private fun resolutionDistance(candidate: Size, requested: Size): Long {
        val pixelDistance = abs(candidate.width.toLong() * candidate.height - requested.width.toLong() * requested.height)
        val ratioDistance = (abs(candidate.width.toDouble() / candidate.height - requested.width.toDouble() / requested.height) * 1_000_000).toLong()
        return pixelDistance + ratioDistance
    }

    private fun matchesRequestedVideoSize(candidate: Size, requested: Size): Boolean {
        val candidateLong = maxOf(candidate.width, candidate.height)
        val candidateShort = minOf(candidate.width, candidate.height)
        val requestedLong = maxOf(requested.width, requested.height)
        val requestedShort = minOf(requested.width, requested.height)
        return candidateLong >= requestedLong * 0.95 && candidateShort >= requestedShort * 0.95
    }

    fun capturePhoto(result: MethodChannel.Result) {
        val capture = imageCapture ?: return result.error("ANDROID_CAMERA_STATE", "Image capture is not ready", null)
        val file = File(activity.cacheDir, "apex_photo_${System.currentTimeMillis()}.jpg")
        val options = ImageCapture.OutputFileOptions.Builder(file).build()
        capture.takePicture(options, cameraExecutor, object : ImageCapture.OnImageSavedCallback {
            override fun onImageSaved(output: ImageCapture.OutputFileResults) {
                mainExecutor.execute { result.success(file.absolutePath) }
            }

            override fun onError(exception: ImageCaptureException) {
                Log.e(TAG, "Photo capture failed", exception)
                mainExecutor.execute {
                    result.error("ANDROID_PHOTO_CAPTURE", exception.message, Log.getStackTraceString(exception))
                }
            }
        })
    }

    fun startVideo(result: MethodChannel.Result) {
        if (recording != null) return result.error("ANDROID_RECORDING_STATE", "A recording is already active", null)
        val output = videoCapture?.output
            ?: return result.error("ANDROID_CAMERA_STATE", "Video capture is not ready", null)
        val file = File(activity.cacheDir, "apex_video_${System.currentTimeMillis()}.mp4")
        recordingFile = file
        var pending = output.prepareRecording(activity, FileOutputOptions.Builder(file).build())
        if (
            audioEnabled &&
            ContextCompat.checkSelfPermission(activity, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        ) {
            pending = pending.withAudioEnabled()
        }
        recording = pending.start(mainExecutor) { event ->
            if (event is VideoRecordEvent.Finalize) {
                val stopResult = pendingStopResult
                pendingStopResult = null
                recording = null
                if (event.hasError()) {
                    Log.e(TAG, "Video recording failed: ${event.error}", event.cause)
                    stopResult?.error("ANDROID_VIDEO_CAPTURE", event.cause?.message ?: "Recording error ${event.error}", null)
                } else {
                    stopResult?.success(file.absolutePath)
                }
            }
        }
        result.success(null)
    }

    fun stopVideo(result: MethodChannel.Result) {
        val active = recording ?: return result.error("ANDROID_RECORDING_STATE", "No recording is active", null)
        if (pendingStopResult != null) return result.error("ANDROID_RECORDING_STATE", "Recording is already stopping", null)
        pendingStopResult = result
        active.stop()
    }

    fun pauseVideo(result: MethodChannel.Result) {
        val active = recording ?: return result.error("ANDROID_RECORDING_STATE", "No recording is active", null)
        active.pause()
        result.success(null)
    }

    fun resumeVideo(result: MethodChannel.Result) {
        val active = recording ?: return result.error("ANDROID_RECORDING_STATE", "No recording is active", null)
        active.resume()
        result.success(null)
    }

    fun setFlash(mode: String, result: MethodChannel.Result) {
        val activeCamera = camera ?: return result.error("ANDROID_CAMERA_STATE", "Camera is not ready", null)
        imageCapture?.flashMode = when (mode) {
            "auto" -> ImageCapture.FLASH_MODE_AUTO
            "always" -> ImageCapture.FLASH_MODE_ON
            else -> ImageCapture.FLASH_MODE_OFF
        }
        activeCamera.cameraControl.enableTorch(mode == "torch")
        result.success(null)
    }

    fun setZoom(zoom: Double, result: MethodChannel.Result) {
        val activeCamera = camera ?: return result.error("ANDROID_CAMERA_STATE", "Camera is not ready", null)
        val state = activeCamera.cameraInfo.zoomState.value
        val bounded = zoom.toFloat().coerceIn(state?.minZoomRatio ?: 1f, state?.maxZoomRatio ?: 1f)
        activeCamera.cameraControl.setZoomRatio(bounded)
        result.success(null)
    }

    fun setFocusPoint(x: Double, y: Double, result: MethodChannel.Result) {
        val activeCamera = camera ?: return result.error("ANDROID_CAMERA_STATE", "Camera is not ready", null)
        val view = previewView ?: return result.error("ANDROID_CAMERA_STATE", "Preview is not attached", null)
        val point = view.meteringPointFactory.createPoint(
            (x.coerceIn(0.0, 1.0) * view.width).toFloat(),
            (y.coerceIn(0.0, 1.0) * view.height).toFloat(),
        )
        val action = FocusMeteringAction.Builder(
            point,
            FocusMeteringAction.FLAG_AF or FocusMeteringAction.FLAG_AE or FocusMeteringAction.FLAG_AWB,
        ).setAutoCancelDuration(3, TimeUnit.SECONDS).build()
        activeCamera.cameraControl.startFocusAndMetering(action)
        result.success(null)
    }

    fun setExposureOffset(offset: Double, result: MethodChannel.Result) {
        val activeCamera = camera ?: return result.error("ANDROID_CAMERA_STATE", "Camera is not ready", null)
        val state = activeCamera.cameraInfo.exposureState
        if (!state.isExposureCompensationSupported) return result.success(null)
        val step = state.exposureCompensationStep.toDouble().takeIf { it > 0.0 } ?: 1.0
        val index = (offset / step).roundToInt().coerceIn(
            state.exposureCompensationRange.lower,
            state.exposureCompensationRange.upper,
        )
        activeCamera.cameraControl.setExposureCompensationIndex(index)
        result.success(null)
    }

    fun dispose(result: MethodChannel.Result? = null) {
        disposeSession()
        result?.success(null)
    }

    private fun disposeSession() {
        pendingStopResult?.error("ANDROID_RECORDING_CANCELLED", "Camera session was disposed", null)
        pendingStopResult = null
        recording?.close()
        recording = null
        provider?.unbindAll()
        preview?.setSurfaceProvider(null)
        preview = null
        imageCapture = null
        videoCapture = null
        camera = null
    }
}
