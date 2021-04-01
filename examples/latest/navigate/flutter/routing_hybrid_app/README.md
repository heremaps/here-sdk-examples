The Routing Hybrid example app shows how to calculate a route from A to B with a number of waypoints in between that is visualized on the map. It also shows how to calculate routes in offline mode, when there is no connectivity available. You can find how this is done in [RoutingExample.dart](lib/RoutingExample.dart).

Build instructions:
-------------------

1) Set your HERE SDK credentials to
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`

2) Unzip the HERE SDK plugin to the plugins folder inside this project. Name the folder 'here_sdk': `plugins/here_sdk`.

3) Start an emulator or simulator and execute `flutter run` from the app's directory - or run the app from within your IDE.

More information can be found in the _Get Started_ section of the _Developer's Guide_.
