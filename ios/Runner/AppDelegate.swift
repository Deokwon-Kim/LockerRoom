import Flutter
import UIKit
import Vision
import AVFoundation
import flutter_foreground_task

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    SwiftFlutterForegroundTaskPlugin.setPluginRegistrantCallback(registerPlugins)
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = self.registrar(forPlugin: "VisionOcrPlugin") {
      VisionOcrPlugin.register(with: registrar)
    }
    if let registrar = self.registrar(forPlugin: "RecapVideoEncoderPlugin") {
      RecapVideoEncoderPlugin.register(with: registrar)
    }
    if let registrar = self.registrar(forPlugin: "CeremonyVideoPlugin") {
      CeremonyVideoPlugin.register(with: registrar)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

func registerPlugins(registry: FlutterPluginRegistry) {
  GeneratedPluginRegistrant.register(with: registry)
  if let registrar = registry.registrar(forPlugin: "VisionOcrPlugin") {
    VisionOcrPlugin.register(with: registrar)
  }
  if let registrar = registry.registrar(forPlugin: "RecapVideoEncoderPlugin") {
    RecapVideoEncoderPlugin.register(with: registrar)
  }
  if let registrar = registry.registrar(forPlugin: "CeremonyVideoPlugin") {
    CeremonyVideoPlugin.register(with: registrar)
  }
}

class VisionOcrPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.lockerroom/vision_ocr",
      binaryMessenger: registrar.messenger()
    )
    let instance = VisionOcrPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "recognizeText",
       let args = call.arguments as? [String: Any],
       let path = args["path"] as? String {
      recognizeTextWithVision(imagePath: path, result: result)
    } else {
      result(FlutterMethodNotImplemented)
    }
  }

  private func recognizeTextWithVision(imagePath: String, result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .userInitiated).async {
      guard let image = UIImage(contentsOfFile: imagePath),
            let cgImage = image.cgImage else {
        DispatchQueue.main.async {
          result(FlutterError(code: "INVALID_IMAGE", message: "이미지를 불러올 수 없습니다.", details: nil))
        }
        return
      }

      let request = VNRecognizeTextRequest { req, error in
        if let error = error {
          DispatchQueue.main.async {
            result(FlutterError(code: "VISION_ERROR", message: error.localizedDescription, details: nil))
          }
          return
        }
        let observations = req.results as? [VNRecognizedTextObservation] ?? []
        let lines = observations.compactMap { $0.topCandidates(1).first?.string }
        let fullText = lines.joined(separator: "\n")
        DispatchQueue.main.async {
          result(fullText)
        }
      }

      request.recognitionLevel = .accurate
      request.recognitionLanguages = ["ko-KR", "ja-JP", "en-US"]
      request.usesLanguageCorrection = true

      let orientation = self.cgImageOrientation(from: image.imageOrientation)
      let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
      do {
        try handler.perform([request])
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "VISION_PERFORM_ERROR", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func cgImageOrientation(from orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
    switch orientation {
    case .up: return .up
    case .down: return .down
    case .left: return .left
    case .right: return .right
    case .upMirrored: return .upMirrored
    case .downMirrored: return .downMirrored
    case .leftMirrored: return .leftMirrored
    case .rightMirrored: return .rightMirrored
    @unknown default: return .up
    }
  }
}

class RecapVideoEncoderPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.codegrove.thebase/recap_video",
      binaryMessenger: registrar.messenger()
    )
    let instance = RecapVideoEncoderPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  private let encodeQueue = DispatchQueue(label: "com.codegrove.thebase.recapVideo")
  private var assetWriter: AVAssetWriter?
  private var writerInput: AVAssetWriterInput?
  private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
  private var videoWidth: Int = 720
  private var videoHeight: Int = 1280
  private var fps: Int32 = 24
  private var frameIndex: Int64 = 0
  private var outputPath: String?
  private var rawVideoPath: String?
  private var audioPath: String?

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startEncoding":
      guard let args = call.arguments as? [String: Any],
            let w = args["width"] as? Int,
            let h = args["height"] as? Int,
            let f = args["fps"] as? Int,
            let path = args["outputPath"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "인코딩 인자가 올바르지 않습니다.", details: nil))
        return
      }
      let aPath = args["audioPath"] as? String
      startEncoding(width: w, height: h, fps: f, outputPath: path, audioPath: aPath, result: result)
    case "appendFrame":
      guard let args = call.arguments as? [String: Any],
            let typedData = args["bytes"] as? FlutterStandardTypedData else {
        result(FlutterError(code: "INVALID_FRAME", message: "프레임 데이터가 없습니다.", details: nil))
        return
      }
      appendFrame(data: typedData.data, result: result)
    case "finishEncoding":
      finishEncoding(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func startEncoding(
    width: Int,
    height: Int,
    fps: Int,
    outputPath: String,
    audioPath: String?,
    result: @escaping FlutterResult
  ) {
    encodeQueue.async {
      self.resetWriter()
      let evenW = max(2, (width / 2) * 2)
      let evenH = max(2, (height / 2) * 2)
      self.videoWidth = evenW
      self.videoHeight = evenH
      self.fps = Int32(max(1, fps))
      self.frameIndex = 0
      self.outputPath = outputPath
      self.audioPath = (audioPath != nil && !audioPath!.isEmpty) ? audioPath : nil

      let writeTargetPath = self.audioPath != nil ? "\(outputPath).raw.mp4" : outputPath
      self.rawVideoPath = writeTargetPath

      let url = URL(fileURLWithPath: writeTargetPath)
      try? FileManager.default.removeItem(at: url)
      try? FileManager.default.removeItem(at: URL(fileURLWithPath: outputPath))

      do {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let settings: [String: Any] = [
          AVVideoCodecKey: AVVideoCodecType.h264,
          AVVideoWidthKey: evenW,
          AVVideoHeightKey: evenH,
          AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 3_500_000,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
          ],
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false

        let attrs: [String: Any] = [
          kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
          kCVPixelBufferWidthKey as String: evenW,
          kCVPixelBufferHeightKey as String: evenH,
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
          assetWriterInput: input,
          sourcePixelBufferAttributes: attrs
        )

        guard writer.canAdd(input) else {
          DispatchQueue.main.async {
            result(FlutterError(code: "WRITER_INIT_ERR", message: "AVAssetWriterInput 추가 실패", details: nil))
          }
          return
        }
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        self.assetWriter = writer
        self.writerInput = input
        self.pixelBufferAdaptor = adaptor

        DispatchQueue.main.async { result(true) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "WRITER_ERR", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func appendFrame(data: Data, result: @escaping FlutterResult) {
    encodeQueue.async {
      guard let input = self.writerInput,
            let adaptor = self.pixelBufferAdaptor,
            let writer = self.assetWriter,
            writer.status == .writing else {
        DispatchQueue.main.async {
          result(FlutterError(code: "NOT_WRITING", message: "비디오 인코더가 준비되지 않았습니다.", details: nil))
        }
        return
      }

      guard let image = UIImage(data: data), let cgImage = image.cgImage else {
        DispatchQueue.main.async {
          result(FlutterError(code: "DECODE_ERR", message: "프레임 이미지 디코딩 실패", details: nil))
        }
        return
      }

      var waitCount = 0
      while !input.isReadyForMoreMediaData && waitCount < 200 {
        Thread.sleep(forTimeInterval: 0.005)
        waitCount += 1
      }

      guard let pool = adaptor.pixelBufferPool else {
        DispatchQueue.main.async {
          result(FlutterError(code: "POOL_ERR", message: "PixelBufferPool 생성 실패", details: nil))
        }
        return
      }

      var pixelBufferOut: CVPixelBuffer?
      let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBufferOut)
      guard status == kCVReturnSuccess, let pixelBuffer = pixelBufferOut else {
        DispatchQueue.main.async {
          result(FlutterError(code: "BUFFER_ERR", message: "PixelBuffer 할당 실패", details: nil))
        }
        return
      }

      CVPixelBufferLockBaseAddress(pixelBuffer, [])
      if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) {
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        if let ctx = CGContext(
          data: baseAddress,
          width: self.videoWidth,
          height: self.videoHeight,
          bitsPerComponent: 8,
          bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
          space: rgbColorSpace,
          bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) {
          ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: self.videoWidth, height: self.videoHeight))
        }
      }
      CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

      let pts = CMTime(value: self.frameIndex, timescale: self.fps)
      let ok = adaptor.append(pixelBuffer, withPresentationTime: pts)
      self.frameIndex += 1

      DispatchQueue.main.async {
        if ok {
          result(true)
        } else {
          result(FlutterError(code: "APPEND_ERR", message: writer.error?.localizedDescription ?? "프레임 추가 실패", details: nil))
        }
      }
    }
  }

  private func finishEncoding(result: @escaping FlutterResult) {
    encodeQueue.async {
      guard let writer = self.assetWriter,
            let input = self.writerInput,
            let finalPath = self.outputPath,
            let rawPath = self.rawVideoPath else {
        DispatchQueue.main.async {
          result(FlutterError(code: "NO_WRITER", message: "진행 중인 인코딩이 없습니다.", details: nil))
        }
        return
      }
      let aPath = self.audioPath
      input.markAsFinished()
      writer.finishWriting {
        let error = writer.error
        self.resetWriter()
        if let error = error {
          DispatchQueue.main.async {
            result(FlutterError(code: "FINISH_ERR", message: error.localizedDescription, details: nil))
          }
          return
        }

        if let aPath = aPath, FileManager.default.fileExists(atPath: aPath) {
          self.mergeAudio(videoPath: rawPath, audioPath: aPath, outputPath: finalPath, result: result)
        } else {
          DispatchQueue.main.async { result(finalPath) }
        }
      }
    }
  }

  private func mergeAudio(
    videoPath: String,
    audioPath: String,
    outputPath: String,
    result: @escaping FlutterResult
  ) {
    let composition = AVMutableComposition()
    let videoAsset = AVURLAsset(url: URL(fileURLWithPath: videoPath))
    let audioAsset = AVURLAsset(url: URL(fileURLWithPath: audioPath))

    guard let videoTrack = videoAsset.tracks(withMediaType: .video).first,
          let compVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
          ) else {
      try? FileManager.default.moveItem(atPath: videoPath, toPath: outputPath)
      DispatchQueue.main.async { result(outputPath) }
      return
    }

    let videoDuration = videoAsset.duration
    do {
      try compVideoTrack.insertTimeRange(
        CMTimeRange(start: .zero, duration: videoDuration),
        of: videoTrack,
        at: .zero
      )

      if let audioTrack = audioAsset.tracks(withMediaType: .audio).first,
         let compAudioTrack = composition.addMutableTrack(
           withMediaType: .audio,
           preferredTrackID: kCMPersistentTrackID_Invalid
         ) {
        let audioDuration = audioAsset.duration
        if audioDuration.seconds > 0 {
          var cursor = CMTime.zero
          while CMTimeCompare(cursor, videoDuration) < 0 {
            let remaining = CMTimeSubtract(videoDuration, cursor)
            let chunk = CMTimeCompare(audioDuration, remaining) < 0 ? audioDuration : remaining
            try compAudioTrack.insertTimeRange(
              CMTimeRange(start: .zero, duration: chunk),
              of: audioTrack,
              at: cursor
            )
            cursor = CMTimeAdd(cursor, chunk)
          }
        }
      }
    } catch {
      try? FileManager.default.moveItem(atPath: videoPath, toPath: outputPath)
      DispatchQueue.main.async { result(outputPath) }
      return
    }

    let outUrl = URL(fileURLWithPath: outputPath)
    try? FileManager.default.removeItem(at: outUrl)

    guard let exporter = AVAssetExportSession(
      asset: composition,
      presetName: AVAssetExportPresetHighestQuality
    ) else {
      try? FileManager.default.moveItem(atPath: videoPath, toPath: outputPath)
      DispatchQueue.main.async { result(outputPath) }
      return
    }

    exporter.outputURL = outUrl
    exporter.outputFileType = .mp4
    exporter.shouldOptimizeForNetworkUse = true
    exporter.exportAsynchronously {
      try? FileManager.default.removeItem(atPath: videoPath)
      DispatchQueue.main.async {
        if exporter.status == .completed {
          result(outputPath)
        } else {
          result(FlutterError(
            code: "EXPORT_ERR",
            message: exporter.error?.localizedDescription ?? "오디오 병합 실패",
            details: nil
          ))
        }
      }
    }
  }

  private func resetWriter() {
    assetWriter = nil
    writerInput = nil
    pixelBufferAdaptor = nil
  }
}

class CeremonyVideoPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.codegrove.thebase/ceremony_video",
      binaryMessenger: registrar.messenger()
    )
    let instance = CeremonyVideoPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  private let encodeQueue = DispatchQueue(label: "com.codegrove.thebase.ceremonyVideo")

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "encodeCeremonyVideo" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let args = call.arguments as? [String: Any],
          let framesDir = args["framesDir"] as? String,
          let outputPath = args["outputPath"] as? String else {
      result(FlutterError(code: "INVALID_ARGS", message: "framesDir 및 outputPath가 필요합니다.", details: nil))
      return
    }
    let audioPath = args["audioPath"] as? String
    let fps = max(1, (args["fps"] as? Int) ?? 24)
    encodeCeremonyVideo(
      framesDir: framesDir,
      audioPath: audioPath,
      fps: fps,
      outputPath: outputPath,
      result: result
    )
  }

  private func encodeCeremonyVideo(
    framesDir: String,
    audioPath: String?,
    fps: Int,
    outputPath: String,
    result: @escaping FlutterResult
  ) {
    encodeQueue.async {
      let fm = FileManager.default
      let dirURL = URL(fileURLWithPath: framesDir, isDirectory: true)
      guard let allURLs = try? fm.contentsOfDirectory(
        at: dirURL,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      ) else {
        DispatchQueue.main.async {
          result(FlutterError(code: "FRAMES_DIR_ERR", message: "프레임 디렉토리를 읽을 수 없습니다.", details: nil))
        }
        return
      }

      let frameURLs = allURLs
        .filter { $0.pathExtension.lowercased() == "png" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

      guard let firstURL = frameURLs.first,
            let firstImage = UIImage(contentsOfFile: firstURL.path),
            let firstCG = firstImage.cgImage else {
        DispatchQueue.main.async {
          result(FlutterError(code: "NO_FRAMES", message: "유효한 PNG 프레임이 없습니다.", details: nil))
        }
        return
      }

      let evenW = max(2, (firstCG.width / 2) * 2)
      let evenH = max(2, (firstCG.height / 2) * 2)
      let validAudioPath = (audioPath != nil && !audioPath!.isEmpty && fm.fileExists(atPath: audioPath!))
        ? audioPath!
        : nil
      let rawVideoPath = validAudioPath != nil ? "\(outputPath).raw.mp4" : outputPath

      try? fm.removeItem(atPath: rawVideoPath)
      try? fm.removeItem(atPath: outputPath)

      do {
        let writer = try AVAssetWriter(outputURL: URL(fileURLWithPath: rawVideoPath), fileType: .mp4)
        let settings: [String: Any] = [
          AVVideoCodecKey: AVVideoCodecType.h264,
          AVVideoWidthKey: evenW,
          AVVideoHeightKey: evenH,
          AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 3_500_000,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
          ],
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false

        let attrs: [String: Any] = [
          kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
          kCVPixelBufferWidthKey as String: evenW,
          kCVPixelBufferHeightKey as String: evenH,
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
          assetWriterInput: input,
          sourcePixelBufferAttributes: attrs
        )

        guard writer.canAdd(input) else {
          DispatchQueue.main.async {
            result(FlutterError(code: "WRITER_INIT_ERR", message: "AVAssetWriterInput 추가 실패", details: nil))
          }
          return
        }

        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let timescale = Int32(fps)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()

        for (index, url) in frameURLs.enumerated() {
          var appendError: String?
          autoreleasepool {
            guard let img = UIImage(contentsOfFile: url.path),
                  let cgImage = img.cgImage else {
              appendError = "프레임 디코딩 실패: \(url.lastPathComponent)"
              return
            }

            var waitCount = 0
            while !input.isReadyForMoreMediaData && waitCount < 400 {
              Thread.sleep(forTimeInterval: 0.005)
              waitCount += 1
            }

            guard let pool = adaptor.pixelBufferPool else {
              appendError = "PixelBufferPool 생성 실패"
              return
            }

            var pixelBufferOut: CVPixelBuffer?
            let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBufferOut)
            guard status == kCVReturnSuccess, let pixelBuffer = pixelBufferOut else {
              appendError = "PixelBuffer 할당 실패"
              return
            }

            CVPixelBufferLockBaseAddress(pixelBuffer, [])
            if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer),
               let ctx = CGContext(
                 data: baseAddress,
                 width: evenW,
                 height: evenH,
                 bitsPerComponent: 8,
                 bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                 space: rgbColorSpace,
                 bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
               ) {
              ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: evenW, height: evenH))
            }
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

            let pts = CMTime(value: Int64(index), timescale: timescale)
            if !adaptor.append(pixelBuffer, withPresentationTime: pts) {
              appendError = writer.error?.localizedDescription ?? "프레임 추가 실패"
            }
          }

          if let msg = appendError {
            writer.cancelWriting()
            try? fm.removeItem(atPath: rawVideoPath)
            DispatchQueue.main.async {
              result(FlutterError(code: "APPEND_ERR", message: msg, details: nil))
            }
            return
          }
        }

        input.markAsFinished()
        writer.finishWriting {
          if let error = writer.error {
            try? fm.removeItem(atPath: rawVideoPath)
            DispatchQueue.main.async {
              result(FlutterError(code: "FINISH_ERR", message: error.localizedDescription, details: nil))
            }
            return
          }

          if let aPath = validAudioPath {
            self.mergeAudio(videoPath: rawVideoPath, audioPath: aPath, outputPath: outputPath, result: result)
          } else {
            DispatchQueue.main.async { result(outputPath) }
          }
        }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "WRITER_ERR", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func mergeAudio(
    videoPath: String,
    audioPath: String,
    outputPath: String,
    result: @escaping FlutterResult
  ) {
    let composition = AVMutableComposition()
    let videoAsset = AVURLAsset(url: URL(fileURLWithPath: videoPath))
    let audioAsset = AVURLAsset(url: URL(fileURLWithPath: audioPath))

    guard let videoTrack = videoAsset.tracks(withMediaType: .video).first,
          let compVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
          ) else {
      try? FileManager.default.moveItem(atPath: videoPath, toPath: outputPath)
      DispatchQueue.main.async { result(outputPath) }
      return
    }

    let videoDuration = videoAsset.duration
    do {
      try compVideoTrack.insertTimeRange(
        CMTimeRange(start: .zero, duration: videoDuration),
        of: videoTrack,
        at: .zero
      )

      if let audioTrack = audioAsset.tracks(withMediaType: .audio).first,
         let compAudioTrack = composition.addMutableTrack(
           withMediaType: .audio,
           preferredTrackID: kCMPersistentTrackID_Invalid
         ) {
        let audioDuration = audioAsset.duration
        if audioDuration.seconds > 0 {
          var cursor = CMTime.zero
          while CMTimeCompare(cursor, videoDuration) < 0 {
            let remaining = CMTimeSubtract(videoDuration, cursor)
            let chunk = CMTimeCompare(audioDuration, remaining) < 0 ? audioDuration : remaining
            try compAudioTrack.insertTimeRange(
              CMTimeRange(start: .zero, duration: chunk),
              of: audioTrack,
              at: cursor
            )
            cursor = CMTimeAdd(cursor, chunk)
          }
        }
      }
    } catch {
      try? FileManager.default.moveItem(atPath: videoPath, toPath: outputPath)
      DispatchQueue.main.async { result(outputPath) }
      return
    }

    let outUrl = URL(fileURLWithPath: outputPath)
    try? FileManager.default.removeItem(at: outUrl)

    guard let exporter = AVAssetExportSession(
      asset: composition,
      presetName: AVAssetExportPresetHighestQuality
    ) else {
      try? FileManager.default.moveItem(atPath: videoPath, toPath: outputPath)
      DispatchQueue.main.async { result(outputPath) }
      return
    }

    exporter.outputURL = outUrl
    exporter.outputFileType = .mp4
    exporter.shouldOptimizeForNetworkUse = true
    exporter.exportAsynchronously {
      try? FileManager.default.removeItem(atPath: videoPath)
      DispatchQueue.main.async {
        if exporter.status == .completed {
          result(outputPath)
        } else {
          result(FlutterError(
            code: "EXPORT_ERR",
            message: exporter.error?.localizedDescription ?? "오디오 병합 실패",
            details: nil
          ))
        }
      }
    }
  }
}
