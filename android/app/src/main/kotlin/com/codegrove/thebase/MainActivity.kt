package com.codegrove.thebase

import android.graphics.BitmapFactory
import android.graphics.Rect
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Handler
import android.os.Looper
import android.view.Surface
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
  private val channelName = "com.codegrove.thebase/recap_video"
  private val ceremonyChannelName = "com.codegrove.thebase/ceremony_video"
  private val encodeExecutor = Executors.newSingleThreadExecutor()
  private val mainHandler = Handler(Looper.getMainLooper())

  private var mediaCodec: MediaCodec? = null
  private var inputSurface: Surface? = null
  private var mediaMuxer: MediaMuxer? = null
  private var trackIndex = -1
  private var muxerStarted = false
  private var videoWidth = 720
  private var videoHeight = 1280
  private var fps = 18
  private var frameIndex = 0L
  private var outputPath: String? = null
  private var rawVideoPath: String? = null
  private var audioPath: String? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "startEncoding" -> {
            val w = call.argument<Int>("width") ?: 720
            val h = call.argument<Int>("height") ?: 1280
            val f = call.argument<Int>("fps") ?: 18
            val path = call.argument<String>("outputPath")
            val aPath = call.argument<String>("audioPath")
            if (path == null) {
              result.error("INVALID_ARGS", "outputPath가 필요합니다.", null)
            } else {
              startEncoding(w, h, f, path, aPath, result)
            }
          }
          "appendFrame" -> {
            val bytes = call.argument<ByteArray>("bytes")
            if (bytes == null) {
              result.error("INVALID_FRAME", "프레임 데이터가 없습니다.", null)
            } else {
              appendFrame(bytes, result)
            }
          }
          "finishEncoding" -> finishEncoding(result)
          else -> result.notImplemented()
        }
      }

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ceremonyChannelName)
      .setMethodCallHandler { call, result ->
        if (call.method == "encodeCeremonyVideo") {
          val framesDir = call.argument<String>("framesDir")
          val outputPath = call.argument<String>("outputPath")
          val audioPath = call.argument<String>("audioPath")
          val fpsArg = call.argument<Int>("fps") ?: 24
          if (framesDir.isNullOrEmpty() || outputPath.isNullOrEmpty()) {
            result.error("INVALID_ARGS", "framesDir 및 outputPath가 필요합니다.", null)
          } else {
            encodeCeremonyVideo(framesDir, audioPath, fpsArg.coerceAtLeast(1), outputPath, result)
          }
        } else {
          result.notImplemented()
        }
      }
  }

  private fun encodeCeremonyVideo(
    framesDir: String,
    audioPath: String?,
    fpsArg: Int,
    finalPath: String,
    result: MethodChannel.Result
  ) {
    encodeExecutor.execute {
      var codec: MediaCodec? = null
      var surface: Surface? = null
      var muxer: MediaMuxer? = null
      var localMuxerStarted = false
      var localTrackIndex = -1
      var localFrameIndex = 0L

      try {
        val dir = File(framesDir)
        val frameFiles = dir.listFiles { f ->
          f.isFile && f.name.endsWith(".png", ignoreCase = true)
        }?.sortedBy { it.name } ?: emptyList()

        if (frameFiles.isEmpty()) {
          mainHandler.post { result.error("NO_FRAMES", "유효한 PNG 프레임이 없습니다.", null) }
          return@execute
        }

        val boundsOpts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(frameFiles.first().absolutePath, boundsOpts)
        val width = ((boundsOpts.outWidth / 2) * 2).coerceAtLeast(2)
        val height = ((boundsOpts.outHeight / 2) * 2).coerceAtLeast(2)

        val hasAudio = !audioPath.isNullOrEmpty() && File(audioPath).exists()
        val rawPath = if (hasAudio) "$finalPath.raw.mp4" else finalPath

        File(rawPath).takeIf { it.exists() }?.delete()
        File(finalPath).takeIf { it.exists() }?.delete()

        val format = MediaFormat.createVideoFormat("video/avc", width, height).apply {
          setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
          setInteger(MediaFormat.KEY_BIT_RATE, 3_500_000)
          setInteger(MediaFormat.KEY_FRAME_RATE, fpsArg)
          setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }

        codec = MediaCodec.createEncoderByType("video/avc").apply {
          configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        }
        surface = codec.createInputSurface()
        codec.start()

        muxer = MediaMuxer(rawPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        val bufferInfo = MediaCodec.BufferInfo()

        fun drainLocal(endOfStream: Boolean) {
          val activeCodec = codec ?: return
          val activeMuxer = muxer ?: return
          while (true) {
            val outId = activeCodec.dequeueOutputBuffer(bufferInfo, 10_000L)
            if (outId == MediaCodec.INFO_TRY_AGAIN_LATER) {
              if (!endOfStream) break
            } else if (outId == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
              if (!localMuxerStarted) {
                localTrackIndex = activeMuxer.addTrack(activeCodec.outputFormat)
                activeMuxer.start()
                localMuxerStarted = true
              }
            } else if (outId >= 0) {
              val encoded = activeCodec.getOutputBuffer(outId)
              if (encoded != null && bufferInfo.size > 0 &&
                (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == 0 &&
                localMuxerStarted
              ) {
                encoded.position(bufferInfo.offset)
                encoded.limit(bufferInfo.offset + bufferInfo.size)
                bufferInfo.presentationTimeUs = localFrameIndex * (1_000_000L / fpsArg)
                localFrameIndex++
                activeMuxer.writeSampleData(localTrackIndex, encoded, bufferInfo)
              }
              activeCodec.releaseOutputBuffer(outId, false)
              if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) break
            }
          }
        }

        for (file in frameFiles) {
          val bitmap = BitmapFactory.decodeFile(file.absolutePath)
            ?: throw IllegalStateException("비트맵 디코딩 실패: ${file.name}")
          val canvas = surface.lockCanvas(null)
          try {
            canvas.drawBitmap(bitmap, null, Rect(0, 0, width, height), null)
          } finally {
            surface.unlockCanvasAndPost(canvas)
            bitmap.recycle()
          }
          drainLocal(endOfStream = false)
        }

        codec.signalEndOfInputStream()
        drainLocal(endOfStream = true)

        val totalDurationUs = localFrameIndex * (1_000_000L / fpsArg)
        try { codec.stop() } catch (_: Exception) {}
        try { codec.release() } catch (_: Exception) {}
        try { surface.release() } catch (_: Exception) {}
        try { if (localMuxerStarted) muxer.stop() } catch (_: Exception) {}
        try { muxer.release() } catch (_: Exception) {}
        codec = null
        surface = null
        muxer = null

        if (hasAudio && audioPath != null) {
          val merged = mergeAudioWithVideo(rawPath, audioPath, finalPath, totalDurationUs)
          if (!merged) {
            File(rawPath).copyTo(File(finalPath), overwrite = true)
          }
          File(rawPath).takeIf { it.exists() }?.delete()
        }

        mainHandler.post { result.success(finalPath) }
      } catch (e: Exception) {
        try { codec?.stop() } catch (_: Exception) {}
        try { codec?.release() } catch (_: Exception) {}
        try { surface?.release() } catch (_: Exception) {}
        try { if (localMuxerStarted) muxer?.stop() } catch (_: Exception) {}
        try { muxer?.release() } catch (_: Exception) {}
        mainHandler.post { result.error("CEREMONY_ENCODE_ERR", e.message, null) }
      }
    }
  }

  private fun startEncoding(
    width: Int,
    height: Int,
    fpsArg: Int,
    path: String,
    aPath: String?,
    result: MethodChannel.Result
  ) {
    encodeExecutor.execute {
      try {
        releaseEncoder()
        videoWidth = ((width / 2) * 2).coerceAtLeast(2)
        videoHeight = ((height / 2) * 2).coerceAtLeast(2)
        fps = fpsArg.coerceAtLeast(1)
        frameIndex = 0L
        trackIndex = -1
        muxerStarted = false
        outputPath = path
        audioPath = if (!aPath.isNullOrEmpty()) aPath else null

        val writeTarget = if (audioPath != null) "$path.raw.mp4" else path
        rawVideoPath = writeTarget

        File(writeTarget).takeIf { it.exists() }?.delete()
        File(path).takeIf { it.exists() }?.delete()

        val format = MediaFormat.createVideoFormat("video/avc", videoWidth, videoHeight).apply {
          setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
          setInteger(MediaFormat.KEY_BIT_RATE, 3_500_000)
          setInteger(MediaFormat.KEY_FRAME_RATE, fps)
          setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }

        val codec = MediaCodec.createEncoderByType("video/avc")
        codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        val surface = codec.createInputSurface()
        codec.start()

        val muxer = MediaMuxer(writeTarget, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

        mediaCodec = codec
        inputSurface = surface
        mediaMuxer = muxer

        mainHandler.post { result.success(true) }
      } catch (e: Exception) {
        releaseEncoder()
        mainHandler.post { result.error("INIT_ERR", e.message, null) }
      }
    }
  }

  private fun appendFrame(bytes: ByteArray, result: MethodChannel.Result) {
    encodeExecutor.execute {
      try {
        val surface = inputSurface ?: throw IllegalStateException("인코더가 초기화되지 않았습니다.")
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
          ?: throw IllegalStateException("비트맵 디코딩 실패")

        val canvas = surface.lockCanvas(null)
        try {
          canvas.drawBitmap(
            bitmap,
            null,
            Rect(0, 0, videoWidth, videoHeight),
            null
          )
        } finally {
          surface.unlockCanvasAndPost(canvas)
          bitmap.recycle()
        }

        drainEncoder(endOfStream = false)
        mainHandler.post { result.success(true) }
      } catch (e: Exception) {
        mainHandler.post { result.error("APPEND_ERR", e.message, null) }
      }
    }
  }

  private fun finishEncoding(result: MethodChannel.Result) {
    encodeExecutor.execute {
      try {
        mediaCodec?.signalEndOfInputStream()
        drainEncoder(endOfStream = true)
        val finalPath = outputPath ?: throw IllegalStateException("outputPath가 없습니다.")
        val rawPath = rawVideoPath ?: finalPath
        val totalDurationUs = frameIndex * (1_000_000L / fps)
        val aPath = audioPath
        releaseEncoder()

        if (aPath != null && File(aPath).exists()) {
          val merged = mergeAudioWithVideo(rawPath, aPath, finalPath, totalDurationUs)
          if (!merged) {
            File(rawPath).copyTo(File(finalPath), overwrite = true)
          }
          File(rawPath).takeIf { it.exists() }?.delete()
        }

        mainHandler.post { result.success(finalPath) }
      } catch (e: Exception) {
        releaseEncoder()
        mainHandler.post { result.error("FINISH_ERR", e.message, null) }
      }
    }
  }

  private fun mergeAudioWithVideo(
    videoPath: String,
    audioPath: String,
    finalOutputPath: String,
    videoDurationUs: Long
  ): Boolean {
    var videoExtractor: MediaExtractor? = null
    var audioExtractor: MediaExtractor? = null
    var audioDecoder: MediaCodec? = null
    var audioEncoder: MediaCodec? = null
    var muxer: MediaMuxer? = null

    try {
      videoExtractor = MediaExtractor().apply { setDataSource(videoPath) }
      var videoTrackSrc = -1
      var videoFormat: MediaFormat? = null
      for (i in 0 until videoExtractor.trackCount) {
        val fmt = videoExtractor.getTrackFormat(i)
        if (fmt.getString(MediaFormat.KEY_MIME)?.startsWith("video/") == true) {
          videoTrackSrc = i
          videoFormat = fmt
          break
        }
      }
      if (videoTrackSrc < 0 || videoFormat == null) return false
      videoExtractor.selectTrack(videoTrackSrc)

      audioExtractor = MediaExtractor().apply { setDataSource(audioPath) }
      var audioTrackSrc = -1
      var srcAudioFormat: MediaFormat? = null
      for (i in 0 until audioExtractor.trackCount) {
        val fmt = audioExtractor.getTrackFormat(i)
        if (fmt.getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true) {
          audioTrackSrc = i
          srcAudioFormat = fmt
          break
        }
      }
      if (audioTrackSrc < 0 || srcAudioFormat == null) return false
      audioExtractor.selectTrack(audioTrackSrc)

      val srcMime = srcAudioFormat.getString(MediaFormat.KEY_MIME) ?: return false
      val sampleRate = if (srcAudioFormat.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
        srcAudioFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
      } else 44100
      val channelCount = if (srcAudioFormat.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
        srcAudioFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
      } else 2

      audioDecoder = MediaCodec.createDecoderByType(srcMime).apply {
        configure(srcAudioFormat, null, null, 0)
        start()
      }

      val aacFormat = MediaFormat.createAudioFormat(
        MediaFormat.MIMETYPE_AUDIO_AAC,
        sampleRate,
        channelCount
      ).apply {
        setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
        setInteger(MediaFormat.KEY_BIT_RATE, 128_000)
        setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16384)
      }

      audioEncoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC).apply {
        configure(aacFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        start()
      }

      muxer = MediaMuxer(finalOutputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
      val outVideoTrack = muxer.addTrack(videoFormat)
      var outAudioTrack = -1
      var muxerRunning = false

      val decInfo = MediaCodec.BufferInfo()
      val encInfo = MediaCodec.BufferInfo()
      var decoderDone = false
      var encoderDone = false
      var pcmSampleCount = 0L
      val bytesPerFrame = 2 * channelCount

      // 1단계: AAC 오디오 포맷이 나올 때까지 디코딩/인코딩
      val encodedAudioSamples = mutableListOf<Pair<ByteArray, MediaCodec.BufferInfo>>()

      while (!encoderDone) {
        if (!decoderDone) {
          val inIdx = audioDecoder.dequeueInputBuffer(10_000)
          if (inIdx >= 0) {
            val inBuf = audioDecoder.getInputBuffer(inIdx)!!
            var sampleSize = audioExtractor.readSampleData(inBuf, 0)
            if (sampleSize < 0) {
              // 오디오가 비디오보다 짧으면 처음으로 루프
              val currentAudioUs = (pcmSampleCount * 1_000_000L) / sampleRate
              if (currentAudioUs < videoDurationUs) {
                audioExtractor.seekTo(0, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
                sampleSize = audioExtractor.readSampleData(inBuf, 0)
              }
            }
            if (sampleSize < 0 || (pcmSampleCount * 1_000_000L) / sampleRate >= videoDurationUs) {
              audioDecoder.queueInputBuffer(inIdx, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
              decoderDone = true
            } else {
              val pts = audioExtractor.sampleTime
              audioDecoder.queueInputBuffer(inIdx, 0, sampleSize, pts, 0)
              audioExtractor.advance()
            }
          }
        }

        val decOutIdx = audioDecoder.dequeueOutputBuffer(decInfo, 10_000)
        if (decOutIdx >= 0) {
          val decBuf = audioDecoder.getOutputBuffer(decOutIdx)!!
          if (decInfo.size > 0) {
            decBuf.position(decInfo.offset)
            decBuf.limit(decInfo.offset + decInfo.size)
            val pcmBytes = ByteArray(decInfo.size)
            decBuf.get(pcmBytes)

            var offset = 0
            while (offset < pcmBytes.size) {
              val encInIdx = audioEncoder.dequeueInputBuffer(10_000)
              if (encInIdx >= 0) {
                val encInBuf = audioEncoder.getInputBuffer(encInIdx)!!
                encInBuf.clear()
                val chunk = minOf(encInBuf.remaining(), pcmBytes.size - offset)
                encInBuf.put(pcmBytes, offset, chunk)
                val ptsUs = (pcmSampleCount * 1_000_000L) / sampleRate
                pcmSampleCount += (chunk / bytesPerFrame)
                offset += chunk
                audioEncoder.queueInputBuffer(encInIdx, 0, chunk, ptsUs, 0)
              } else {
                drainAudioEncoder(audioEncoder, encInfo, encodedAudioSamples) { fmt ->
                  if (outAudioTrack < 0) outAudioTrack = muxer.addTrack(fmt)
                }
              }
            }
          }
          audioDecoder.releaseOutputBuffer(decOutIdx, false)
          if ((decInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
            val encInIdx = audioEncoder.dequeueInputBuffer(10_000)
            if (encInIdx >= 0) {
              audioEncoder.queueInputBuffer(encInIdx, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
            }
          }
        }

        val reachedEnd = drainAudioEncoder(audioEncoder, encInfo, encodedAudioSamples) { fmt ->
          if (outAudioTrack < 0) outAudioTrack = muxer.addTrack(fmt)
        }
        if (reachedEnd) encoderDone = true
      }

      if (outAudioTrack < 0) return false
      muxer.start()
      muxerRunning = true

      // 비디오 샘플 복사
      val vBuf = ByteBuffer.allocate(1024 * 1024)
      val vInfo = MediaCodec.BufferInfo()
      while (true) {
        val sz = videoExtractor.readSampleData(vBuf, 0)
        if (sz < 0) break
        vInfo.offset = 0
        vInfo.size = sz
        vInfo.presentationTimeUs = videoExtractor.sampleTime
        vInfo.flags = videoExtractor.sampleFlags
        muxer.writeSampleData(outVideoTrack, vBuf, vInfo)
        videoExtractor.advance()
      }

      // AAC 오디오 샘플 쓰기
      for ((bytes, info) in encodedAudioSamples) {
        if (info.presentationTimeUs <= videoDurationUs) {
          muxer.writeSampleData(outAudioTrack, ByteBuffer.wrap(bytes), info)
        }
      }

      if (muxerRunning) muxer.stop()
      return true
    } catch (_: Exception) {
      return false
    } finally {
      try { videoExtractor?.release() } catch (_: Exception) {}
      try { audioExtractor?.release() } catch (_: Exception) {}
      try { audioDecoder?.stop(); audioDecoder?.release() } catch (_: Exception) {}
      try { audioEncoder?.stop(); audioEncoder?.release() } catch (_: Exception) {}
      try { muxer?.release() } catch (_: Exception) {}
    }
  }

  private fun drainAudioEncoder(
    encoder: MediaCodec,
    info: MediaCodec.BufferInfo,
    outSamples: MutableList<Pair<ByteArray, MediaCodec.BufferInfo>>,
    onFormatChanged: (MediaFormat) -> Unit
  ): Boolean {
    while (true) {
      val idx = encoder.dequeueOutputBuffer(info, 5_000)
      if (idx == MediaCodec.INFO_TRY_AGAIN_LATER) {
        return false
      } else if (idx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
        onFormatChanged(encoder.outputFormat)
      } else if (idx >= 0) {
        val buf = encoder.getOutputBuffer(idx)
        if (buf != null && info.size > 0 && (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == 0) {
          buf.position(info.offset)
          buf.limit(info.offset + info.size)
          val copy = ByteArray(info.size)
          buf.get(copy)
          val copyInfo = MediaCodec.BufferInfo().apply {
            set(0, copy.size, info.presentationTimeUs, info.flags)
          }
          outSamples.add(copy to copyInfo)
        }
        encoder.releaseOutputBuffer(idx, false)
        if ((info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
          return true
        }
      }
    }
  }

  private fun drainEncoder(endOfStream: Boolean) {
    val codec = mediaCodec ?: return
    val muxer = mediaMuxer ?: return
    val bufferInfo = MediaCodec.BufferInfo()
    val timeoutUs = 10_000L

    while (true) {
      val outputBufferId = codec.dequeueOutputBuffer(bufferInfo, timeoutUs)
      if (outputBufferId == MediaCodec.INFO_TRY_AGAIN_LATER) {
        if (!endOfStream) break
      } else if (outputBufferId == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
        if (!muxerStarted) {
          trackIndex = muxer.addTrack(codec.outputFormat)
          muxer.start()
          muxerStarted = true
        }
      } else if (outputBufferId >= 0) {
        val encodedData = codec.getOutputBuffer(outputBufferId)
        if (encodedData != null && bufferInfo.size > 0 &&
          (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == 0 &&
          muxerStarted
        ) {
          encodedData.position(bufferInfo.offset)
          encodedData.limit(bufferInfo.offset + bufferInfo.size)
          bufferInfo.presentationTimeUs = frameIndex * (1_000_000L / fps)
          frameIndex++
          muxer.writeSampleData(trackIndex, encodedData, bufferInfo)
        }
        codec.releaseOutputBuffer(outputBufferId, false)
        if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
          break
        }
      }
    }
  }

  private fun releaseEncoder() {
    try {
      mediaCodec?.stop()
    } catch (_: Exception) {}
    try {
      mediaCodec?.release()
    } catch (_: Exception) {}
    try {
      inputSurface?.release()
    } catch (_: Exception) {}
    try {
      if (muxerStarted) mediaMuxer?.stop()
    } catch (_: Exception) {}
    try {
      mediaMuxer?.release()
    } catch (_: Exception) {}
    mediaCodec = null
    inputSurface = null
    mediaMuxer = null
    trackIndex = -1
    muxerStarted = false
  }
}
