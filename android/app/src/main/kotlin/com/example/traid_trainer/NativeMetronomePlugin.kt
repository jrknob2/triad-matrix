package com.example.traid_trainer

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.max
import kotlin.math.roundToInt

class NativeMetronomePlugin(
  private val applicationContext: Context
) : MethodChannel.MethodCallHandler {
  private val engine = AndroidScheduledMetronomeEngine(applicationContext)

  fun register(channel: MethodChannel) {
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    try {
      when (call.method) {
        "prepare" -> {
          val assetPath = call.argument<String>("assetPath")
          requireNotNull(assetPath) { "assetPath is required." }
          engine.prepare(assetPath)
          result.success(null)
        }
        "start" -> {
          val bpm = call.argument<Int>("bpm") ?: 120
          engine.start(bpm)
          result.success(null)
        }
        "stop" -> {
          engine.stop()
          result.success(null)
        }
        "setBpm" -> {
          val bpm = call.argument<Int>("bpm") ?: 120
          engine.setBpm(bpm)
          result.success(null)
        }
        "playCompletionChime" -> {
          engine.playCompletionChime()
          result.success(null)
        }
        else -> result.notImplemented()
      }
    } catch (error: Exception) {
      result.error("metronome_error", error.message, null)
    }
  }
}

private data class WavPcmData(
  val sampleRate: Int,
  val pcmBytes: ByteArray,
  val frameCount: Int
)

private class AndroidScheduledMetronomeEngine(
  private val applicationContext: Context
) {
  private val releaseHandler = Handler(Looper.getMainLooper())

  private var wavData: WavPcmData? = null
  private var loopTrack: AudioTrack? = null
  private var completionTrack: AudioTrack? = null

  @Synchronized
  fun prepare(assetPath: String) {
    if (wavData != null) return
    wavData = loadWav(assetPath)
  }

  @Synchronized
  fun start(bpm: Int) {
    val wav = requireNotNull(wavData) { "Metronome audio is not prepared." }
    val loopBytes = buildLoopBuffer(wav, bpm)
    val track = buildTrack(
      sampleRate = wav.sampleRate,
      bufferBytes = loopBytes,
      loopFrameCount = loopBytes.size / 2,
      infiniteLoop = true
    )
    releaseTrack(loopTrack)
    loopTrack = track
    track.play()
  }

  @Synchronized
  fun stop() {
    releaseTrack(loopTrack)
    loopTrack = null
  }

  @Synchronized
  fun setBpm(bpm: Int) {
    start(bpm)
  }

  @Synchronized
  fun playCompletionChime() {
    val wav = requireNotNull(wavData) { "Metronome audio is not prepared." }
    val chimeBytes = buildDoubleClickBuffer(wav, 150)
    val track = buildTrack(
      sampleRate = wav.sampleRate,
      bufferBytes = chimeBytes,
      loopFrameCount = 0,
      infiniteLoop = false
    )
    releaseTrack(completionTrack)
    completionTrack = track
    track.play()
    val durationMs = ((chimeBytes.size / 2).toDouble() / wav.sampleRate * 1000.0)
      .roundToInt()
      .toLong() + 50L
    releaseHandler.postDelayed({
      synchronized(this) {
        if (completionTrack === track) {
          releaseTrack(completionTrack)
          completionTrack = null
        }
      }
    }, durationMs)
  }

  private fun buildTrack(
    sampleRate: Int,
    bufferBytes: ByteArray,
    loopFrameCount: Int,
    infiniteLoop: Boolean
  ): AudioTrack {
    val minBufferSize = AudioTrack.getMinBufferSize(
      sampleRate,
      AudioFormat.CHANNEL_OUT_MONO,
      AudioFormat.ENCODING_PCM_16BIT
    )
    val track = AudioTrack(
      AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build(),
      AudioFormat.Builder()
        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
        .setSampleRate(sampleRate)
        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
        .build(),
      max(minBufferSize, bufferBytes.size),
      AudioTrack.MODE_STATIC,
      AudioManager.AUDIO_SESSION_ID_GENERATE
    )
    track.write(bufferBytes, 0, bufferBytes.size)
    if (infiniteLoop) {
      track.setLoopPoints(0, loopFrameCount, -1)
    }
    return track
  }

  private fun loadWav(assetPath: String): WavPcmData {
    val lookupKey = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(assetPath)
    val bytes = applicationContext.assets.open(lookupKey).use { it.readBytes() }
    require(bytes.size > 44) { "Invalid WAV file." }
    require(String(bytes, 0, 4) == "RIFF") { "Invalid WAV header." }
    require(String(bytes, 8, 4) == "WAVE") { "Invalid WAV format." }

    var offset = 12
    var sampleRate = 44100
    var channels = 1
    var bitsPerSample = 16
    var audioFormat = 1
    var dataOffset = -1
    var dataSize = 0

    while (offset + 8 <= bytes.size) {
      val chunkId = String(bytes, offset, 4)
      val chunkSize = ByteBuffer.wrap(bytes, offset + 4, 4)
        .order(ByteOrder.LITTLE_ENDIAN)
        .int
      val chunkDataOffset = offset + 8
      when (chunkId) {
        "fmt " -> {
          val fmt = ByteBuffer.wrap(bytes, chunkDataOffset, chunkSize)
            .order(ByteOrder.LITTLE_ENDIAN)
          audioFormat = fmt.short.toInt() and 0xFFFF
          channels = fmt.short.toInt() and 0xFFFF
          sampleRate = fmt.int
          fmt.int
          fmt.short
          bitsPerSample = fmt.short.toInt() and 0xFFFF
        }
        "data" -> {
          dataOffset = chunkDataOffset
          dataSize = chunkSize
        }
      }
      offset = chunkDataOffset + chunkSize + (chunkSize and 1)
    }

    require(audioFormat == 1) { "Only PCM WAV assets are supported." }
    require(channels == 1) { "Only mono WAV assets are supported." }
    require(bitsPerSample == 16) { "Only 16-bit WAV assets are supported." }
    require(dataOffset >= 0 && dataOffset + dataSize <= bytes.size) { "WAV data chunk missing." }

    val pcmBytes = bytes.copyOfRange(dataOffset, dataOffset + dataSize)
    return WavPcmData(
      sampleRate = sampleRate,
      pcmBytes = pcmBytes,
      frameCount = pcmBytes.size / 2
    )
  }

  private fun buildLoopBuffer(wav: WavPcmData, bpm: Int): ByteArray {
    val beatFrames = max(
      ((60.0 / max(30, bpm).toDouble()) * wav.sampleRate).roundToInt(),
      wav.frameCount + 1
    )
    val loopBytes = ByteArray(beatFrames * 2)
    System.arraycopy(wav.pcmBytes, 0, loopBytes, 0, wav.pcmBytes.size)
    return loopBytes
  }

  private fun buildDoubleClickBuffer(wav: WavPcmData, delayMs: Int): ByteArray {
    val delayFrames = ((delayMs / 1000.0) * wav.sampleRate).roundToInt()
    val totalFrames = wav.frameCount * 2 + delayFrames
    val chimeBytes = ByteArray(totalFrames * 2)
    System.arraycopy(wav.pcmBytes, 0, chimeBytes, 0, wav.pcmBytes.size)
    System.arraycopy(
      wav.pcmBytes,
      0,
      chimeBytes,
      (wav.frameCount + delayFrames) * 2,
      wav.pcmBytes.size
    )
    return chimeBytes
  }

  private fun releaseTrack(track: AudioTrack?) {
    track ?: return
    try {
      track.pause()
      track.flush()
    } catch (_: IllegalStateException) {
      // Ignore teardown races for static tracks.
    }
    track.release()
  }
}
