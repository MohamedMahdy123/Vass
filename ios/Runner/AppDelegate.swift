import UIKit
import Flutter
import Vision

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // flutter_local_notifications: show alerts while the app is in the
    // foreground on older iOS versions.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    // On-device background removal via Apple Vision subject lifting.
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "vess/bg_removal",
        binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { call, result in
        guard call.method == "removeBackground",
              let args = call.arguments as? [String: Any],
              let data = args["image"] as? FlutterStandardTypedData else {
          result(FlutterMethodNotImplemented)
          return
        }
        // Off the platform thread — Vision is CPU/GPU heavy.
        DispatchQueue.global(qos: .userInitiated).async {
          let png = Self.removeBackground(data.data)
          DispatchQueue.main.async {
            result(png == nil ? nil : FlutterStandardTypedData(bytes: png!))
          }
        }
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Runs Vision's foreground-instance mask (iOS 17+) and returns a transparent
  /// PNG of the lifted subject, or nil when unavailable / no subject found.
  static func removeBackground(_ imageData: Data) -> Data? {
    guard #available(iOS 17.0, *),
          let uiImage = UIImage(data: imageData),
          let cgImage = uiImage.cgImage else { return nil }

    let request = VNGenerateForegroundInstanceMaskRequest()
    let handler = VNImageRequestHandler(cgImage: cgImage, orientation: cgOrientation(uiImage.imageOrientation))
    do {
      try handler.perform([request])
      guard let observation = request.results?.first else { return nil }
      let maskedPixelBuffer = try observation.generateMaskedImage(
        ofInstances: observation.allInstances,
        from: handler,
        croppedToInstancesExtent: false)
      let ciImage = CIImage(cvPixelBuffer: maskedPixelBuffer)
      let ciContext = CIContext()
      guard let outCg = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
      return UIImage(cgImage: outCg).pngData()
    } catch {
      return nil
    }
  }

  /// Map UIImage orientation to the CGImagePropertyOrientation Vision expects.
  static func cgOrientation(_ o: UIImage.Orientation) -> CGImagePropertyOrientation {
    switch o {
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
