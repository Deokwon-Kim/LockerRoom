import Flutter
import UIKit
import Vision
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
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

func registerPlugins(registry: FlutterPluginRegistry) {
  GeneratedPluginRegistrant.register(with: registry)
  if let registrar = registry.registrar(forPlugin: "VisionOcrPlugin") {
    VisionOcrPlugin.register(with: registrar)
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
      request.recognitionLanguages = ["ko-KR", "en-US"]
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
