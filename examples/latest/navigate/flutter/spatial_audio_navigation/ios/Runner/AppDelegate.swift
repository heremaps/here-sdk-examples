import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate, BufferCompletionDelegate {
    var flutterChannel: FlutterMethodChannel? = nil
    // Create an object of AVAudioPlayerNodeManager to avoid creating multiple delegates, and send it as a parameter
    // To scalate the project, it is better to create multiple delegations
    let avAudioPlayerNodeManager: AVAudioPlayerNodeManager = AVAudioPlayerNodeManager(())!

    func onDone(_ avAudioPlayerNodeManager: AVAudioPlayerNodeManager, bufferLengthIsSeconds: Double) {
        print("buffer length \(Int(bufferLengthIsSeconds*1000))")
        // Start getting notifications about the new panning values
        flutterChannel?.invokeMethod("onSynthesizatorDone", arguments: Int(bufferLengthIsSeconds*1000))
    }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
      let METHOD_CHANNEL_NAME = "com.here.sdk.examples/spatialAudioExample"
       let flutterViewController : FlutterViewController = window?.rootViewController as! FlutterViewController
       flutterChannel = FlutterMethodChannel.init(name: METHOD_CHANNEL_NAME, binaryMessenger: flutterViewController.binaryMessenger)

      // Init delegation of buffer completion
      avAudioPlayerNodeManager.bufferCompletionDelegate = self

       prepareMethodHandler()

      GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

    private func prepareMethodHandler() {
        let spatialAudioHandler: SpatialAudioHandler = SpatialAudioHandler()

        flutterChannel?.setMethodCallHandler {(call: FlutterMethodCall, flutterResult: @escaping FlutterResult) -> Void in
          switch call.method {
            case "synthesizeAudioCueAndPlay":
                guard let args = call.arguments as? [String: Any] else {return}
                let maneuverText = args["audioCue"] as! String
                let initialAzimuth = args["initialAzimuth"] as! Double

              spatialAudioHandler.playSpatialAudioCue(audioCue: maneuverText, avAudioPlayerNodeManager: self.avAudioPlayerNodeManager, initialAzimuth: Float(initialAzimuth))
                flutterResult(true)
            case "azimuthNotification":

              guard let args = call.arguments as? [String: Any] else {return}
              let completedTrajectory = args["completedTrajectory"]!
              let azimuth = args["azimuth"] as! Double
              spatialAudioHandler.updatePanning(azimuthInDegrees: Float(azimuth), avAudioPlayerNodeManager: self.avAudioPlayerNodeManager)
              flutterResult(true)
            case "dispose":
              spatialAudioHandler.onDispose(avAudioPlayerNodeManager: self.avAudioPlayerNodeManager)
                flutterResult(true)
            default:
                flutterResult(FlutterMethodNotImplemented)
            }
        }
    }
}
