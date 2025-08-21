import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController
        // A method channel, as defined in the GPXManager class.
        let methodChannel = FlutterMethodChannel(name: "com.example.filepath", binaryMessenger: controller.binaryMessenger)

        // Implement the method channel to retrieve a native file path on iOS.
        methodChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            if call.method == "getFilePath", let args = call.arguments as? [String: Any], let fileName = args["fileName"] as? String {
                if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    let fileURL = documentsDirectory.appendingPathComponent(fileName).relativePath
                    result(fileURL)
                } else {
                    result(FlutterError(code: "UNAVAILABLE", message: "Documents directory unavailable", details: nil))
                }
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
