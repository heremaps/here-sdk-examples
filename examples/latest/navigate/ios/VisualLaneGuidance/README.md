The "Visual Lane Guidance" example app brings navigation to life with clear lane-level guidance, an on-map route carpet that highlights the lanes to follow, and flexible camera behaviors. You can find how this is done in `VisualLaneGuidanceExample.swift` and `CameraBehaviors.swift`.

![Screenshot: HD visual lane guidance in the iOS VisualLaneGuidance example app.](../../../guides/ios/markdown/en-US/graphics/ios-visual-lane-guidance-hd.png)

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

1) Copy the `heresdk.xcframework` folder (as found in the HERE SDK package) to your app's root folder.

Note: If your framework version is different than the version shown in the _Developer Guide_, you may need to adapt the source code of the example app.

2) Open Xcode by double-clicking the `*.xcodeproj` file.

3) In Xcode, open the _General_ settings of the _App target_ and make sure that the HERE SDK framework appears under _Frameworks, Libraries, and Embedded Content_. If it does not appear, add `heresdk.xcframework`.

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `VisualLaneGuidanceApp.swift` file of your project. More information can be found in the _Get Started_ section of the _Developer Guide_.
