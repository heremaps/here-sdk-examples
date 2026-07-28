import CarPlay
import Flutter
import heresdk
import SwiftUI
import UIKit

enum NativeIOSCall: String {
	case onCarPlayConnected
	case onCarPlayDisconnected
}

enum NativeDartCall: String {
	case onDartHereSdkReady
}

class SceneDelegate: FlutterSceneDelegate {
	static let channelName = "com.here.sdk.examples.hello_map_auto_carplay_app/channel"
	private static var methodChannel: FlutterMethodChannel?
	fileprivate static var isHereSdkReadyFromDart = false
	fileprivate static weak var activeCarPlaySceneDelegate: CarPlaySceneDelegate?

	override func scene(
		_ scene: UIScene,
		willConnectTo session: UISceneSession,
		options connectionOptions: UIScene.ConnectionOptions
	) {
		super.scene(scene, willConnectTo: session, options: connectionOptions)

		guard let flutterViewController = window?.rootViewController as? FlutterViewController else {
			return
		}

		SceneDelegate.methodChannel = FlutterMethodChannel(
			name: SceneDelegate.channelName,
			binaryMessenger: flutterViewController.binaryMessenger
		)

		SceneDelegate.methodChannel?.setMethodCallHandler { call, result in
			switch call.method {
			case NativeDartCall.onDartHereSdkReady.rawValue:
				SceneDelegate.isHereSdkReadyFromDart = true
				SceneDelegate.activeCarPlaySceneDelegate?.tryInitializeCarPlayMapIfReady()
				result(nil)
			default:
				result(FlutterMethodNotImplemented)
			}
		}
	}

	static func notifyFlutter(_ call: NativeIOSCall) {
		DispatchQueue.main.async {
			methodChannel?.invokeMethod(call.rawValue, arguments: nil)
		}
	}
}

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
	private let carPlayMapTemplate = CPMapTemplate()
	private var helloMapCarPlayExample: HelloMapCarPlayExample?
	private weak var carPlayWindow: CPWindow?
	private var isCarPlayMapInitialized = false

	func templateApplicationScene(
		_ templateApplicationScene: CPTemplateApplicationScene,
		didConnect interfaceController: CPInterfaceController,
		to window: CPWindow
	) {
		SceneDelegate.activeCarPlaySceneDelegate = self
		carPlayWindow = window
		isCarPlayMapInitialized = false

		carPlayMapTemplate.leadingNavigationBarButtons = [
			createButton(title: "Zoom +"),
			createButton(title: "Zoom -"),
		]

		interfaceController.setRootTemplate(carPlayMapTemplate, animated: true)
		tryInitializeCarPlayMapIfReady()

		SceneDelegate.notifyFlutter(.onCarPlayConnected)
	}

	func templateApplicationScene(
		_ templateApplicationScene: CPTemplateApplicationScene,
		didDisconnect interfaceController: CPInterfaceController,
		from window: CPWindow
	) {
		helloMapCarPlayExample = nil
		carPlayWindow = nil
		isCarPlayMapInitialized = false
		if SceneDelegate.activeCarPlaySceneDelegate === self {
			SceneDelegate.activeCarPlaySceneDelegate = nil
		}
		SceneDelegate.notifyFlutter(.onCarPlayDisconnected)
	}

	func tryInitializeCarPlayMapIfReady() {
		guard !isCarPlayMapInitialized else {
			return
		}

		guard SceneDelegate.isHereSdkReadyFromDart else {
			print("CarPlay waiting for Dart HERE SDK initialization signal.")
			return
		}

		guard let carPlayWindow else {
			return
		}

		let mapView = MapView()
		helloMapCarPlayExample = HelloMapCarPlayExample(mapView)
		carPlayWindow.rootViewController = UIHostingController(
			rootView: WrappedMapView(mapView: mapView).edgesIgnoringSafeArea(.all)
		)
		isCarPlayMapInitialized = true
	}

	private func createButton(title: String) -> CPBarButton {
		let barButton = CPBarButton(type: .text) { _ in
			if title == "Zoom +" {
				self.helloMapCarPlayExample?.zoomIn()
			} else if title == "Zoom -" {
				self.helloMapCarPlayExample?.zoomOut()
			}
		}
		barButton.title = title
		return barButton
	}

	private struct WrappedMapView: UIViewRepresentable {
		let mapView: MapView

		func makeUIView(context: Context) -> MapView {
			return mapView
		}

		func updateUIView(_ uiView: MapView, context: Context) {}
	}
}

private class HelloMapCarPlayExample {
	private let mapView: MapView

	init(_ mapView: MapView) {
		self.mapView = mapView

		let camera = mapView.camera
		let distanceInMeters = MapMeasure(kind: .distanceInMeters, value: 1000 * 10)
		camera.lookAt(
			point: GeoCoordinates(latitude: 52.520798, longitude: 13.409408),
			zoom: distanceInMeters
		)

		mapView.mapScene.loadScene(mapScheme: .normalDay, completion: onLoadScene)
	}

	func zoomIn() {
		mapView.camera.zoomBy(2, around: mapView.camera.principalPoint)
	}

	func zoomOut() {
		mapView.camera.zoomBy(0.5, around: mapView.camera.principalPoint)
	}

	private func onLoadScene(mapError: MapError?) {
		if let mapError {
			print("Error: CarPlay map scene not loaded: \(mapError)")
		}
	}
}
