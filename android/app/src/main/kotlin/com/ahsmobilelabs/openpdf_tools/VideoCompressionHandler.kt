package com.abdielzikri.abdsukapdf

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.nio.ByteBuffer
import kotlin.math.max
import kotlin.math.min

class VideoCompressionHandler(private val context: Context) {
    fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "compressVideoToGallery" -> compressVideoToGallery(call, result)
            else -> result.notImplemented()
        }
    }

    private fun compressVideoToGallery(call: MethodCall, result: MethodChannel.Result) {
        val inputPath = call.argument<String>("inputPath")
        if (inputPath.isNullOrBlank()) {
            result.error("INVALID_INPUT", "Video path is missing.", null)
            return
        }

        val width = normalizeEven(call.argument<Int>("width") ?: 1280)
        val height = normalizeEven(call.argument<Int>("height") ?: 720)
        val fps = (call.argument<Int>("fps") ?: 24).coerceIn(8, 60)
        val quality = (call.argument<Int>("quality") ?: 55).coerceIn(10, 90)
        val maxDurationSeconds = (call.argument<Int>("durationSeconds") ?: 60).coerceIn(1, 600)
        val gopSize = (call.argument<Int>("gopSize") ?: 12).coerceIn(6, 60)

        Thread {
            try {
                val output = compressToTempFile(
                    inputPath = inputPath,
                    width = width,
                    height = height,
                    fps = fps,
                    quality = quality,
                    maxDurationSeconds = maxDurationSeconds,
                    gopSize = gopSize
                )
                val savedUri = saveVideoToGallery(output.file, output.displayName)
                val response = mapOf(
                    "uri" to savedUri.toString(),
                    "displayName" to output.displayName,
                    "inputBytes" to output.inputBytes,
                    "outputBytes" to output.outputBytes,
                    "durationMs" to output.durationMs,
                    "width" to width,
                    "height" to height,
                    "fps" to fps,
                    "audioIncluded" to false
                )
                output.file.delete()
                runOnMain { result.success(response) }
            } catch (e: Exception) {
                runOnMain {
                    result.error("VIDEO_COMPRESSION_FAILED", e.message ?: "Video compression failed.", null)
                }
            }
        }.start()
    }

    private fun compressToTempFile(
        inputPath: String,
        width: Int,
        height: Int,
        fps: Int,
        quality: Int,
        maxDurationSeconds: Int,
        gopSize: Int
    ): EncodedVideo {
        val inputFile = File(inputPath)
        if (!inputFile.exists()) {
            throw IllegalArgumentException("Selected video file does not exist.")
        }

        val retriever = MediaMetadataRetriever()
        retriever.setDataSource(inputPath)

        val sourceDurationMs = retriever
            .extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
            ?.toLongOrNull()
            ?: (maxDurationSeconds * 1000L)
        val durationMs = min(sourceDurationMs, maxDurationSeconds * 1000L)
        val frameCount = max(1, ((durationMs / 1000.0) * fps).toInt())
        val bitRate = estimateBitRate(width, height, fps, quality)
        val colorFormat = selectColorFormat()

        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height)
        format.setInteger(MediaFormat.KEY_COLOR_FORMAT, colorFormat)
        format.setInteger(MediaFormat.KEY_BIT_RATE, bitRate)
        format.setInteger(MediaFormat.KEY_FRAME_RATE, fps)
        format.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, max(1, gopSize / fps))

        val encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        val outputFile = File(context.cacheDir, "mpeg_compressed_${System.currentTimeMillis()}.mp4")
        val muxer = MediaMuxer(outputFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

        var muxerStarted = false
        var videoTrackIndex = -1
        val bufferInfo = MediaCodec.BufferInfo()

        try {
            encoder.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            encoder.start()

            for (index in 0 until frameCount) {
                drainEncoder(encoder, muxer, bufferInfo, false) { trackIndex ->
                    videoTrackIndex = trackIndex
                    muxerStarted = true
                }

                val inputIndex = encoder.dequeueInputBuffer(10_000)
                if (inputIndex >= 0) {
                    val presentationTimeUs = (index * 1_000_000L) / fps
                    val sourceTimeUs = min(presentationTimeUs, durationMs * 1000L)
                    val bitmap = retriever.getFrameAtTime(sourceTimeUs, MediaMetadataRetriever.OPTION_CLOSEST)
                    val inputBuffer = encoder.getInputBuffer(inputIndex)
                        ?: throw IllegalStateException("Encoder input buffer is unavailable.")
                    inputBuffer.clear()
                    writeBitmapToYuvBuffer(bitmap, width, height, inputBuffer, colorFormat)
                    bitmap?.recycle()
                    encoder.queueInputBuffer(inputIndex, 0, inputBuffer.position(), presentationTimeUs, 0)
                }
            }

            val eosInputIndex = encoder.dequeueInputBuffer(10_000)
            if (eosInputIndex >= 0) {
                val eosPresentationTimeUs = (frameCount * 1_000_000L) / fps
                encoder.queueInputBuffer(
                    eosInputIndex,
                    0,
                    0,
                    eosPresentationTimeUs,
                    MediaCodec.BUFFER_FLAG_END_OF_STREAM
                )
            }

            drainEncoder(encoder, muxer, bufferInfo, true) { trackIndex ->
                videoTrackIndex = trackIndex
                muxerStarted = true
            }
        } finally {
            try {
                encoder.stop()
            } catch (_: Exception) {
            }
            encoder.release()
            if (muxerStarted && videoTrackIndex >= 0) {
                try {
                    muxer.stop()
                } catch (_: Exception) {
                }
            }
            muxer.release()
            retriever.release()
        }

        return EncodedVideo(
            file = outputFile,
            displayName = "ABdSukaPDF_MPEG_${System.currentTimeMillis()}.mp4",
            inputBytes = inputFile.length(),
            outputBytes = outputFile.length(),
            durationMs = durationMs
        )
    }

    private fun drainEncoder(
        encoder: MediaCodec,
        muxer: MediaMuxer,
        bufferInfo: MediaCodec.BufferInfo,
        endOfStream: Boolean,
        onTrackReady: (Int) -> Unit
    ) {
        while (true) {
            val outputIndex = encoder.dequeueOutputBuffer(bufferInfo, 10_000)
            when {
                outputIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    if (!endOfStream) return
                }
                outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    val trackIndex = muxer.addTrack(encoder.outputFormat)
                    muxer.start()
                    onTrackReady(trackIndex)
                }
                outputIndex >= 0 -> {
                    val encodedData = encoder.getOutputBuffer(outputIndex)
                        ?: throw IllegalStateException("Encoder output buffer is unavailable.")
                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
                        bufferInfo.size = 0
                    }
                    if (bufferInfo.size > 0) {
                        encodedData.position(bufferInfo.offset)
                        encodedData.limit(bufferInfo.offset + bufferInfo.size)
                        muxer.writeSampleData(0, encodedData, bufferInfo)
                    }
                    val flags = bufferInfo.flags
                    encoder.releaseOutputBuffer(outputIndex, false)
                    if (flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return
                }
            }
        }
    }

    private fun writeBitmapToYuvBuffer(
        bitmap: Bitmap?,
        width: Int,
        height: Int,
        buffer: ByteBuffer,
        colorFormat: Int
    ) {
        val scaled = if (bitmap == null) {
            Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        } else {
            Bitmap.createScaledBitmap(bitmap, width, height, true)
        }
        val pixels = IntArray(width * height)
        scaled.getPixels(pixels, 0, width, 0, 0, width, height)

        if (colorFormat == MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar) {
            writeNv12(pixels, width, height, buffer)
        } else {
            writeI420(pixels, width, height, buffer)
        }

        if (scaled !== bitmap) {
            scaled.recycle()
        }
    }

    private fun writeI420(pixels: IntArray, width: Int, height: Int, buffer: ByteBuffer) {
        val frameSize = width * height
        val yuv = ByteArray(frameSize * 3 / 2)
        var yIndex = 0
        var uIndex = frameSize
        var vIndex = frameSize + frameSize / 4

        for (j in 0 until height) {
            for (i in 0 until width) {
                val argb = pixels[j * width + i]
                val r = (argb shr 16) and 0xff
                val g = (argb shr 8) and 0xff
                val b = argb and 0xff
                val y = ((66 * r + 129 * g + 25 * b + 128) shr 8) + 16
                val u = ((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128
                val v = ((112 * r - 94 * g - 18 * b + 128) shr 8) + 128
                yuv[yIndex++] = y.coerceIn(0, 255).toByte()
                if (j % 2 == 0 && i % 2 == 0) {
                    yuv[uIndex++] = u.coerceIn(0, 255).toByte()
                    yuv[vIndex++] = v.coerceIn(0, 255).toByte()
                }
            }
        }
        buffer.put(yuv)
    }

    private fun writeNv12(pixels: IntArray, width: Int, height: Int, buffer: ByteBuffer) {
        val frameSize = width * height
        val yuv = ByteArray(frameSize * 3 / 2)
        var yIndex = 0
        var uvIndex = frameSize

        for (j in 0 until height) {
            for (i in 0 until width) {
                val argb = pixels[j * width + i]
                val r = (argb shr 16) and 0xff
                val g = (argb shr 8) and 0xff
                val b = argb and 0xff
                val y = ((66 * r + 129 * g + 25 * b + 128) shr 8) + 16
                val u = ((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128
                val v = ((112 * r - 94 * g - 18 * b + 128) shr 8) + 128
                yuv[yIndex++] = y.coerceIn(0, 255).toByte()
                if (j % 2 == 0 && i % 2 == 0) {
                    yuv[uvIndex++] = u.coerceIn(0, 255).toByte()
                    yuv[uvIndex++] = v.coerceIn(0, 255).toByte()
                }
            }
        }
        buffer.put(yuv)
    }

    private fun selectColorFormat(): Int {
        val codecList = MediaCodecList(MediaCodecList.REGULAR_CODECS)
        val encoder = codecList.codecInfos.firstOrNull { codecInfo ->
            codecInfo.isEncoder && codecInfo.supportedTypes.any {
                it.equals(MediaFormat.MIMETYPE_VIDEO_AVC, ignoreCase = true)
            }
        } ?: return MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible

        val capabilities = encoder.getCapabilitiesForType(MediaFormat.MIMETYPE_VIDEO_AVC)
        val formats = capabilities.colorFormats.toSet()
        return when {
            formats.contains(MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar) ->
                MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar
            formats.contains(MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Planar) ->
                MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Planar
            else -> MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible
        }
    }

    private fun estimateBitRate(width: Int, height: Int, fps: Int, quality: Int): Int {
        val pixels = width * height
        val bitsPerPixel = 0.035 + (quality / 100.0) * 0.095
        return (pixels * fps * bitsPerPixel).toInt().coerceIn(250_000, 18_000_000)
    }

    private fun saveVideoToGallery(file: File, displayName: String): Uri {
        val resolver = context.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Video.Media.DISPLAY_NAME, displayName)
            put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Video.Media.RELATIVE_PATH, "${Environment.DIRECTORY_MOVIES}/ABdSukaPDF")
                put(MediaStore.Video.Media.IS_PENDING, 1)
            }
        }

        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        }

        val uri = resolver.insert(collection, values)
            ?: throw IllegalStateException("Could not create gallery video entry.")

        resolver.openOutputStream(uri)?.use { output ->
            FileInputStream(file).use { input -> input.copyTo(output) }
        } ?: throw IllegalStateException("Could not write compressed video to gallery.")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.clear()
            values.put(MediaStore.Video.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        } else {
            @Suppress("DEPRECATION")
            val moviesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES)
            FileOutputStream(File(moviesDir, displayName)).use { output ->
                FileInputStream(file).use { input -> input.copyTo(output) }
            }
        }

        return uri
    }

    private fun normalizeEven(value: Int): Int = if (value % 2 == 0) value else value - 1

    private fun runOnMain(action: () -> Unit) {
        android.os.Handler(android.os.Looper.getMainLooper()).post(action)
    }

    private data class EncodedVideo(
        val file: File,
        val displayName: String,
        val inputBytes: Long,
        val outputBytes: Long,
        val durationMs: Long
    )
}
