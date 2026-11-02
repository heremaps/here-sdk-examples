The "Visual Lane Guidance" example app brings navigation to life with clear lane-level guidance, an on-map route carpet that highlights the lanes to follow, and flexible camera behaviors. You can find how this is done in `VisualLaneGuidanceExample.dart` and `CameraBehaviors.dart`.

The app includes two predefined routes, one in Chicago and one in Berlin. HD lane data is available only on supported highways, and coverage varies by location. You can also try visual lane guidance in other countries where coverage is available.

Before starting guidance, allow the app time to download the required map data. The HERE SDK also supports prefetching offline maps that include lane data, but this app does not demonstrate that workflow.

Features demonstrated:
----------------------

- **Route calculation**: Calculates predefined car routes using the `RoutingEngine`.
- **Turn-by-turn navigation**: Uses the `VisualNavigator` with `startRendering()` to display a navigation arrow and guide the user along the route.
- **Location simulation**: Uses the `LocationSimulator` to replay movement along the calculated route.
- **Transition camera behavior**: Demonstrates automatic HD/SD transitions with `TransitionCameraBehavior` based on HD map data availability.
- **Automotive camera behavior**: Demonstrates `AutomotiveCameraBehavior` configured from the `AutomotiveCameraConfig.json` asset.
- **Map scheme switching**: Lets you switch between `NORMAL_DAY` and `CLUSTER_DAY` map schemes.

Build instructions:
-------------------

1) Set your HERE SDK credentials programmatically in `lib/main.dart`.

2) Unzip the HERE SDK plugin to the plugins folder inside this project. Name the folder `here_sdk`: `plugins/here_sdk`.

Note: If your plugin version is different than the version shown in the _Developer Guide_, you may need to adapt the source code of the example app.

3) Start an emulator or simulator and execute `flutter run` from the app's directory, or run the app from within your IDE.

More information can be found in the _Get Started_ section of the _Developer Guide_.
