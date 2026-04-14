import AVFoundation
import Cocoa
import FlutterMacOS

final class NativeMetronomePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private let registrar: FlutterPluginRegistrar
  private let engine = AppleScheduledMetronomeEngine()
  private var beatSink: FlutterEventSink?

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    super.init()
    engine.beatListener = { [weak self] beatIndex in
      self?.beatSink?(beatIndex)
    }
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let methodChannel = FlutterMethodChannel(
      name: "drumcabulary/metronome",
      binaryMessenger: registrar.messenger)
    let instance = NativeMetronomePlugin(registrar: registrar)
    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    let beatChannel = FlutterEventChannel(
      name: "drumcabulary/metronome_beats",
      binaryMessenger: registrar.messenger)
    beatChannel.setStreamHandler(instance)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    do {
      switch call.method {
      case "prepare":
        let args = call.arguments as? [String: Any]
        guard let assetPath = args?["assetPath"] as? String,
          let assetURL = resolveAssetURL(assetPath: assetPath)
        else {
          result(
            FlutterError(
              code: "metronome_asset_missing",
              message: "Metronome asset path could not be resolved.",
              details: nil))
          return
        }
        try engine.prepare(assetURL: assetURL)
        result(nil)
      case "start":
        let args = call.arguments as? [String: Any]
        let bpm = (args?["bpm"] as? Int) ?? 120
        let clickEnabled = (args?["clickEnabled"] as? Bool) ?? true
        try engine.start(bpm: bpm, clickEnabled: clickEnabled)
        result(nil)
      case "stop":
        engine.stop()
        result(nil)
      case "setBpm":
        let args = call.arguments as? [String: Any]
        let bpm = (args?["bpm"] as? Int) ?? 120
        try engine.setBpm(bpm)
        result(nil)
      case "setClickEnabled":
        let args = call.arguments as? [String: Any]
        let enabled = (args?["enabled"] as? Bool) ?? true
        engine.setClickEnabled(enabled)
        result(nil)
      case "playCompletionChime":
        try engine.playCompletionChime()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    } catch {
      result(
        FlutterError(
          code: "metronome_error",
          message: error.localizedDescription,
          details: nil))
    }
  }

  private func resolveAssetURL(assetPath: String) -> URL? {
    let lookupKey = registrar.lookupKey(forAsset: assetPath)
    let candidates: [URL?] = [
      Bundle.main.resourceURL?.appendingPathComponent(lookupKey),
      Bundle.main.resourceURL?.appendingPathComponent("flutter_assets").appendingPathComponent(assetPath),
      Bundle.main.bundleURL
        .appendingPathComponent("Contents/Frameworks/App.framework/Resources/flutter_assets")
        .appendingPathComponent(assetPath),
    ]
    return candidates.compactMap { $0 }.first(where: { FileManager.default.fileExists(atPath: $0.path) })
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    beatSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    beatSink = nil
    return nil
  }
}

private enum AppleMetronomeError: LocalizedError {
  case clickBufferMissing
  case unsupportedPCMFormat
  case bufferAllocationFailed

  var errorDescription: String? {
    switch self {
    case .clickBufferMissing:
      return "Metronome click buffer is not loaded."
    case .unsupportedPCMFormat:
      return "Metronome click asset uses an unsupported PCM format."
    case .bufferAllocationFailed:
      return "Metronome buffer allocation failed."
    }
  }
}

private final class AppleScheduledMetronomeEngine {
  private let audioEngine = AVAudioEngine()
  private let clickNode = AVAudioPlayerNode()
  private let chimeNode = AVAudioPlayerNode()
  private let queue = DispatchQueue(label: "drumcabulary.metronome.macos")

  private var clickBuffer: AVAudioPCMBuffer?
  private var beatTimer: DispatchSourceTimer?
  private var clickEnabled = true
  private var isPrepared = false
  private var isRunning = false
  private var beatIndex = 0
  var beatListener: ((Int) -> Void)?

  init() {
    audioEngine.attach(clickNode)
    audioEngine.attach(chimeNode)
  }

  func prepare(assetURL: URL) throws {
    try queue.sync {
      if isPrepared { return }
      let file = try AVAudioFile(forReading: assetURL)
      let format = file.processingFormat
      guard let buffer = AVAudioPCMBuffer(
        pcmFormat: format,
        frameCapacity: AVAudioFrameCount(file.length))
      else {
        throw AppleMetronomeError.bufferAllocationFailed
      }
      try file.read(into: buffer)
      clickBuffer = buffer
      audioEngine.connect(clickNode, to: audioEngine.mainMixerNode, format: format)
      audioEngine.connect(chimeNode, to: audioEngine.mainMixerNode, format: format)
      if !audioEngine.isRunning {
        try audioEngine.start()
      }
      isPrepared = true
    }
  }

  func start(bpm: Int, clickEnabled: Bool) throws {
    try queue.sync {
      try ensurePrepared()
      isRunning = true
      self.clickEnabled = clickEnabled
      try scheduleLoop(bpm: bpm)
      scheduleBeatTimer(bpm: bpm)
    }
  }

  func stop() {
    queue.sync {
      isRunning = false
      beatTimer?.cancel()
      beatTimer = nil
      clickNode.stop()
    }
  }

  func setBpm(_ bpm: Int) throws {
    try queue.sync {
      guard isRunning else { return }
      try ensurePrepared()
      try scheduleLoop(bpm: bpm)
      scheduleBeatTimer(bpm: bpm)
    }
  }

  func setClickEnabled(_ enabled: Bool) {
    queue.sync {
      clickEnabled = enabled
      clickNode.volume = enabled ? 1.0 : 0.0
    }
  }

  func playCompletionChime() throws {
    try queue.sync {
      try ensurePrepared()
      guard let clickBuffer else {
        throw AppleMetronomeError.clickBufferMissing
      }
      if !audioEngine.isRunning {
        try audioEngine.start()
      }
      let chimeBuffer = try buildDoubleClickBuffer(
        clickBuffer: clickBuffer,
        delayMilliseconds: 150)
      chimeNode.stop()
      chimeNode.scheduleBuffer(chimeBuffer, at: nil, options: [], completionHandler: nil)
      chimeNode.play()
    }
  }

  private func ensurePrepared() throws {
    guard isPrepared, clickBuffer != nil else {
      throw AppleMetronomeError.clickBufferMissing
    }
  }

  private func scheduleLoop(bpm: Int) throws {
    guard let clickBuffer else {
      throw AppleMetronomeError.clickBufferMissing
    }
    if !audioEngine.isRunning {
      try audioEngine.start()
    }
    let loopBuffer = try buildLoopBuffer(clickBuffer: clickBuffer, bpm: bpm)
    clickNode.stop()
    clickNode.volume = clickEnabled ? 1.0 : 0.0
    clickNode.scheduleBuffer(loopBuffer, at: nil, options: [.loops], completionHandler: nil)
    clickNode.play()
  }

  private func scheduleBeatTimer(bpm: Int) {
    beatTimer?.cancel()
    beatTimer = nil
    let intervalNs = max(
      Int((60_000_000_000.0 / Double(max(30, bpm))).rounded()),
      1
    )
    beatIndex = 0
    let timer = DispatchSource.makeTimerSource(queue: queue)
    timer.schedule(
      deadline: .now(),
      repeating: .nanoseconds(intervalNs),
      leeway: .microseconds(500)
    )
    timer.setEventHandler { [weak self] in
      guard let self, self.isRunning else { return }
      let currentBeat = self.beatIndex
      self.beatIndex += 1
      self.beatListener?(currentBeat)
    }
    beatTimer = timer
    timer.resume()
  }

  private func buildLoopBuffer(clickBuffer: AVAudioPCMBuffer, bpm: Int) throws -> AVAudioPCMBuffer {
    let sampleRate = clickBuffer.format.sampleRate
    let clickFrames = Int(clickBuffer.frameLength)
    let beatFrames = max(
      Int(((60.0 / Double(max(30, bpm))) * sampleRate).rounded()),
      clickFrames + 1)
    guard let loopBuffer = AVAudioPCMBuffer(
      pcmFormat: clickBuffer.format,
      frameCapacity: AVAudioFrameCount(beatFrames))
    else {
      throw AppleMetronomeError.bufferAllocationFailed
    }
    loopBuffer.frameLength = AVAudioFrameCount(beatFrames)
    try clear(buffer: loopBuffer)
    try copy(
      source: clickBuffer,
      destination: loopBuffer,
      destinationFrameOffset: 0)
    return loopBuffer
  }

  private func buildDoubleClickBuffer(
    clickBuffer: AVAudioPCMBuffer,
    delayMilliseconds: Int
  ) throws -> AVAudioPCMBuffer {
    let sampleRate = clickBuffer.format.sampleRate
    let clickFrames = Int(clickBuffer.frameLength)
    let delayFrames = Int((Double(delayMilliseconds) / 1000.0) * sampleRate)
    let totalFrames = clickFrames * 2 + delayFrames
    guard let chimeBuffer = AVAudioPCMBuffer(
      pcmFormat: clickBuffer.format,
      frameCapacity: AVAudioFrameCount(totalFrames))
    else {
      throw AppleMetronomeError.bufferAllocationFailed
    }
    chimeBuffer.frameLength = AVAudioFrameCount(totalFrames)
    try clear(buffer: chimeBuffer)
    try copy(source: clickBuffer, destination: chimeBuffer, destinationFrameOffset: 0)
    try copy(
      source: clickBuffer,
      destination: chimeBuffer,
      destinationFrameOffset: clickFrames + delayFrames)
    return chimeBuffer
  }

  private func clear(buffer: AVAudioPCMBuffer) throws {
    let frameCount = Int(buffer.frameLength)
    let channelCount = Int(buffer.format.channelCount)
    switch buffer.format.commonFormat {
    case .pcmFormatFloat32:
      guard let data = buffer.floatChannelData else {
        throw AppleMetronomeError.unsupportedPCMFormat
      }
      for channel in 0..<channelCount {
        memset(data[channel], 0, frameCount * MemoryLayout<Float>.size)
      }
    case .pcmFormatInt16:
      guard let data = buffer.int16ChannelData else {
        throw AppleMetronomeError.unsupportedPCMFormat
      }
      for channel in 0..<channelCount {
        memset(data[channel], 0, frameCount * MemoryLayout<Int16>.size)
      }
    case .pcmFormatInt32:
      guard let data = buffer.int32ChannelData else {
        throw AppleMetronomeError.unsupportedPCMFormat
      }
      for channel in 0..<channelCount {
        memset(data[channel], 0, frameCount * MemoryLayout<Int32>.size)
      }
    default:
      throw AppleMetronomeError.unsupportedPCMFormat
    }
  }

  private func copy(
    source: AVAudioPCMBuffer,
    destination: AVAudioPCMBuffer,
    destinationFrameOffset: Int
  ) throws {
    let channelCount = Int(source.format.channelCount)
    let sourceFrames = Int(source.frameLength)

    switch source.format.commonFormat {
    case .pcmFormatFloat32:
      guard let sourceData = source.floatChannelData,
        let destinationData = destination.floatChannelData
      else {
        throw AppleMetronomeError.unsupportedPCMFormat
      }
      for channel in 0..<channelCount {
        memcpy(
          destinationData[channel].advanced(by: destinationFrameOffset),
          sourceData[channel],
          sourceFrames * MemoryLayout<Float>.size)
      }
    case .pcmFormatInt16:
      guard let sourceData = source.int16ChannelData,
        let destinationData = destination.int16ChannelData
      else {
        throw AppleMetronomeError.unsupportedPCMFormat
      }
      for channel in 0..<channelCount {
        memcpy(
          destinationData[channel].advanced(by: destinationFrameOffset),
          sourceData[channel],
          sourceFrames * MemoryLayout<Int16>.size)
      }
    case .pcmFormatInt32:
      guard let sourceData = source.int32ChannelData,
        let destinationData = destination.int32ChannelData
      else {
        throw AppleMetronomeError.unsupportedPCMFormat
      }
      for channel in 0..<channelCount {
        memcpy(
          destinationData[channel].advanced(by: destinationFrameOffset),
          sourceData[channel],
          sourceFrames * MemoryLayout<Int32>.size)
      }
    default:
      throw AppleMetronomeError.unsupportedPCMFormat
    }
  }
}
