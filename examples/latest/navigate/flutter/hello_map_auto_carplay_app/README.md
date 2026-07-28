# hello_map_auto_carplay_app

The `hello_map_auto_carplay_app` example shows how the HERE SDK can be used from one Flutter project to support both Android Auto and CarPlay.

The phone app is the Flutter app itself. It initializes the HERE SDK on the Dart side, shows a normal map on the phone, and then notifies the native side when the SDK is ready. That readiness signal is important because CarPlay/Android auto waits for it before creating the native map view.

Platform behavior:
- Android: the app uses the existing Android Auto integration.
- iOS: the app creates a CarPlay scene and shows a HERE map in the car display.
- The credentials stay in `lib/main.dart`, so the SDK is initialized only once from Dart.

Build instructions:
-------------------

1) Set your HERE SDK credentials programmatically in `lib/main.dart`.

2) Unzip the HERE SDK plugin to the `plugins` folder inside this project. Name the folder `here_sdk`: `hello_map_auto_carplay_app/plugins/here_sdk`.

3) For iOS CarPlay testing, enable the CarPlay entitlement in `ios/Runner/Entitlements.plist` after you have the required Apple provisioning setup.

4) Run the app on Android or iOS from your IDE, or use `flutter run` from this folder.

5) For iOS CarPlay testing, start the iOS simulator and open the CarPlay display from the simulator menu.

Notes:
- The iOS CarPlay scene waits until the Dart side confirms that the HERE SDK is ready.
- The native iOS code does not contain HERE SDK credentials.
- Android Auto and CarPlay share the same Flutter code where possible, but each platform uses its own native surface on the car display.

More information can be found in the _Get Started_ section of the _Developer Guide_.
