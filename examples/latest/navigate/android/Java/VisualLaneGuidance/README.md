The "VisualLaneGuidance" example app brings navigation to life with clear lane-level guidance, an on-map route carpet that highlights the lanes to follow, and flexible camera behaviors. You can find how this is done in `VisualLaneGuidanceExample.java` and `CameraBehaviors.java`.

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

This example uses **HERE SDK Units** to support functionality such as permission handling or buttons that are not essential to the code snippets shown in this app, as the focus is on demonstrating how to use the APIs provided by the HERE SDK. The HERE SDK Units are included as AARs in the app's `libs` folder. For more details, see the "HERESDKUnits" app to customize or create your own unit libraries. Note that this app is intended exclusively for the HERE SDK (Navigate). You can find it in the `navigate` folder. However, it can be easily adapted for the HERE SDK (Explore) by removing any code that is not supported there. At present, most components are compatible and will compile without issues.

Build instructions:
-------------------

1) Copy the AAR file of the HERE SDK for Android to your app's `app/libs` folder.

Note: If your AAR version is different than the version shown in the _Developer Guide_, you may need to adapt the source code of the example app.

2) Open Android Studio and sync the project.

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `MainActivity.java` file. More information can be found in the _Get Started_ section of the _Developer Guide_.
