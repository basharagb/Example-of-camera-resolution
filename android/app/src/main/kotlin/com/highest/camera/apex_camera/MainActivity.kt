package com.highest.camera.apex_camera

import android.content.ContentValues
import android.content.Context
import android.graphics.BitmapFactory
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.MediaMetadataRetriever
import android.media.MediaRecorder
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.PowerManager
import android.os.StatFs
import android.provider.MediaStore
import android.util.Size
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import kotlin.math.min
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.highest.camera.apex_camera/capabilities"
    }

    private lateinit var nativeCamera: NativeCameraEngine

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        nativeCamera = NativeCameraEngine(this)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "apex_camera_preview",
            NativeCameraPreviewFactory(this, nativeCamera),
        )
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "getCameraCapabilities" -> result.success(getCameraCapabilities())
                        "initializeNativeAndroidCamera" -> nativeCamera.initialize(call.arguments as? Map<*, *> ?: emptyMap<Any, Any>(), result)
                        "disposeNativeAndroidCamera" -> nativeCamera.dispose(result)
                        "captureNativeAndroidPhoto" -> nativeCamera.capturePhoto(result)
                        "startNativeAndroidVideo" -> nativeCamera.startVideo(result)
                        "stopNativeAndroidVideo" -> nativeCamera.stopVideo(result)
                        "pauseNativeAndroidVideo" -> nativeCamera.pauseVideo(result)
                        "resumeNativeAndroidVideo" -> nativeCamera.resumeVideo(result)
                        "setNativeAndroidFlashMode" -> nativeCamera.setFlash(call.argument<String>("mode") ?: "off", result)
                        "setNativeAndroidZoom" -> nativeCamera.setZoom(call.argument<Double>("zoom") ?: 1.0, result)
                        "setNativeAndroidFocusPoint", "setNativeAndroidExposurePoint" -> nativeCamera.setFocusPoint(
                            call.argument<Double>("x") ?: 0.5,
                            call.argument<Double>("y") ?: 0.5,
                            result,
                        )
                        "setNativeAndroidExposureOffset" -> nativeCamera.setExposureOffset(
                            call.argument<Double>("offset") ?: 0.0,
                            result,
                        )
                        "inspectMedia" -> result.success(inspectMedia(call))
                        "saveMedia" -> result.success(saveMedia(call))
                        "getAvailableStorageBytes" -> result.success(StatFs(filesDir.absolutePath).availableBytes)
                        "getThermalState" -> result.success(getThermalState())
                        else -> result.notImplemented()
                    }
                } catch (error: Throwable) {
                    result.error("NATIVE_CAMERA_ERROR", error.message, error.stackTraceToString())
                }
            }
    }

    override fun onDestroy() {
        if (::nativeCamera.isInitialized) nativeCamera.dispose()
        super.onDestroy()
    }

    private fun getCameraCapabilities(): List<Map<String, Any>> {
        val manager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val result = manager.cameraIdList.mapNotNull { cameraId ->
            try {
                val characteristics = manager.getCameraCharacteristics(cameraId)
                val streamMap = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
                    ?: return@mapNotNull null
                val recorderSizes = streamMap.getOutputSizes(MediaRecorder::class.java)?.toList().orEmpty()
                if (recorderSizes.isEmpty()) return@mapNotNull null
                val fpsRanges = characteristics.get(CameraCharacteristics.CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES)
                    ?: emptyArray()
                val globalMaxFps = fpsRanges.maxOfOrNull { it.upper } ?: 30
                val capabilities = characteristics.get(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES)
                    ?: intArrayOf()
                val hdrSupported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                    capabilities.contains(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_DYNAMIC_RANGE_TEN_BIT)
                val lensFacing = when (characteristics.get(CameraCharacteristics.LENS_FACING)) {
                    CameraCharacteristics.LENS_FACING_FRONT -> "front"
                    CameraCharacteristics.LENS_FACING_BACK -> "back"
                    else -> "external"
                }
                val focalLengths = characteristics.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
                    ?.map { it.toDouble() }.orEmpty()
                val videoStabilizationModes =
                    characteristics.get(CameraCharacteristics.CONTROL_AVAILABLE_VIDEO_STABILIZATION_MODES) ?: intArrayOf()
                val opticalStabilizationModes =
                    characteristics.get(CameraCharacteristics.LENS_INFO_AVAILABLE_OPTICAL_STABILIZATION) ?: intArrayOf()
                val photoSize = streamMap.getOutputSizes(android.graphics.ImageFormat.JPEG)
                    ?.maxByOrNull { it.width.toLong() * it.height.toLong() }
                    ?: Size(0, 0)

                mapOf(
                    "id" to cameraId,
                    "name" to "${lensType(lensFacing, focalLengths)} camera",
                    "lensDirection" to lensFacing,
                    "lensType" to lensType(lensFacing, focalLengths),
                    "sensorOrientation" to (characteristics.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 0),
                    "focalLengths" to focalLengths,
                    "flashSupported" to (characteristics.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true),
                    "videoStabilizationSupported" to videoStabilizationModes.contains(
                        CameraCharacteristics.CONTROL_VIDEO_STABILIZATION_MODE_ON
                    ),
                    "opticalStabilizationSupported" to opticalStabilizationModes.contains(
                        CameraCharacteristics.LENS_OPTICAL_STABILIZATION_MODE_ON
                    ),
                    "physicalCameraIds" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        characteristics.physicalCameraIds.toList()
                    } else emptyList<String>(),
                    "photoWidth" to photoSize.width,
                    "photoHeight" to photoSize.height,
                    "resolutions" to recorderSizes
                        .distinctBy { "${it.width}x${it.height}" }
                        .sortedByDescending { it.width.toLong() * it.height.toLong() }
                        .map { size ->
                            val minFrameDuration = try {
                                streamMap.getOutputMinFrameDuration(MediaRecorder::class.java, size)
                            } catch (_: Throwable) {
                                0L
                            }
                            val durationFps = if (minFrameDuration > 0) {
                                (1_000_000_000.0 / minFrameDuration).roundToInt().coerceAtLeast(1)
                            } else globalMaxFps
                            val supportedFps = fpsRanges
                                .map { range -> range.upper }
                                .filter { fps -> fps <= durationFps }
                                .distinct()
                                .sorted()
                            mapOf(
                                "width" to size.width,
                                "height" to size.height,
                                "maxFps" to min(globalMaxFps, durationFps).coerceIn(1, 240),
                                "supportedFps" to supportedFps,
                                "hdrSupported" to hdrSupported
                            )
                        }
                )
            } catch (error: Throwable) {
                Log.e("ApexNativeCamera", "Capability discovery failed for camera $cameraId", error)
                null
            }
        }
        Log.i(
            "ApexNativeCamera",
            "Android capability table cameras=${result.size}/${manager.cameraIdList.size} ids=${manager.cameraIdList.joinToString()}",
        )
        return result
    }

    private fun lensType(direction: String, focalLengths: List<Double>): String {
        if (direction == "front") return "Front"
        if (focalLengths.size > 1) return "Multi-lens"
        val focal = focalLengths.firstOrNull() ?: return "Wide"
        return when {
            focal <= 2.3 -> "Ultra-wide"
            focal >= 6.0 -> "Telephoto"
            else -> "Wide"
        }
    }

    private fun inspectMedia(call: MethodCall): Map<String, Int> {
        val path = call.argument<String>("path") ?: error("Missing media path")
        val type = call.argument<String>("type") ?: error("Missing media type")
        if (type == "photo") {
            val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(path, options)
            return mapOf("width" to options.outWidth.coerceAtLeast(0), "height" to options.outHeight.coerceAtLeast(0))
        }
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(path)
            var width = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
            var height = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
            val rotation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
            if (rotation == 90 || rotation == 270) {
                val originalWidth = width
                width = height
                height = originalWidth
            }
            mapOf("width" to width, "height" to height)
        } finally {
            retriever.release()
        }
    }

    private fun saveMedia(call: MethodCall): String {
        val source = File(call.argument<String>("path") ?: error("Missing media path"))
        if (!source.exists()) error("Captured media does not exist")
        val type = call.argument<String>("type") ?: error("Missing media type")
        val isVideo = type == "video"
        val extension = source.extension.ifBlank { if (isVideo) "mp4" else "jpg" }
        val displayName = "Bashar_${System.currentTimeMillis()}.$extension"
        val mime = if (isVideo) "video/mp4" else if (extension.lowercase() in listOf("heic", "heif")) {
            "image/heic"
        } else "image/jpeg"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val collection = if (isVideo) {
                MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            } else {
                MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            }
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
                put(MediaStore.MediaColumns.MIME_TYPE, mime)
                put(
                    MediaStore.MediaColumns.RELATIVE_PATH,
                    if (isVideo) "${Environment.DIRECTORY_MOVIES}/Bashar Camera" else "${Environment.DIRECTORY_DCIM}/Bashar Camera"
                )
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(collection, values) ?: error("Could not create MediaStore item")
            try {
                contentResolver.openOutputStream(uri, "w")!!.use { output ->
                    FileInputStream(source).use { input -> input.copyTo(output, 1024 * 1024) }
                }
                values.clear()
                values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                contentResolver.update(uri, values, null, null)
                return uri.toString()
            } catch (error: Throwable) {
                contentResolver.delete(uri, null, null)
                throw error
            }
        }

        @Suppress("DEPRECATION")
        val root = Environment.getExternalStoragePublicDirectory(
            if (isVideo) Environment.DIRECTORY_MOVIES else Environment.DIRECTORY_DCIM
        )
        val destinationDirectory = File(root, "Bashar Camera").apply { mkdirs() }
        val destination = File(destinationDirectory, displayName)
        FileInputStream(source).use { input ->
            FileOutputStream(destination).use { output -> input.copyTo(output, 1024 * 1024) }
        }
        MediaScannerConnection.scanFile(this, arrayOf(destination.absolutePath), arrayOf(mime), null)
        return Uri.fromFile(destination).toString()
    }

    private fun getThermalState(): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return "unavailable"
        val status = (getSystemService(Context.POWER_SERVICE) as PowerManager).currentThermalStatus
        return when (status) {
            PowerManager.THERMAL_STATUS_NONE -> "nominal"
            PowerManager.THERMAL_STATUS_LIGHT -> "fair"
            PowerManager.THERMAL_STATUS_MODERATE -> "serious"
            PowerManager.THERMAL_STATUS_SEVERE -> "critical"
            PowerManager.THERMAL_STATUS_CRITICAL,
            PowerManager.THERMAL_STATUS_EMERGENCY,
            PowerManager.THERMAL_STATUS_SHUTDOWN -> "danger"
            else -> "unknown"
        }
    }
}
