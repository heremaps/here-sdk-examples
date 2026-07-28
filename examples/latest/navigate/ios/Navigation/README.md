The Navigation example app shows how to calculate a route from A to B and how to start **turn-by-turn navigation** with voice commands. You can find how this is done in [NavigationExample.swift](Navigation/NavigationExample.swift). It also shows how to set a tracking view when navigation is stopped.

![Turn-by-turn navigation with route, location indicator and maneuver updates](images/navigation.png)

Features demonstrated:
----------------------

- **Route calculation**: Calculates a car route between two waypoints using the `RoutingEngine`.
- **Turn-by-turn navigation**: Uses the `VisualNavigator` with `startRendering()` to display a navigation arrow and guide the user along the route.
- **Voice guidance**: Provides localized maneuver instructions via the `EventTextDelegate` and a built-in TTS engine (`VoiceAssistant`). The preferred device language is automatically detected and matched against available voice skins.
- **Maneuver notifications**: Delivers `RouteProgressDelegate` updates including next maneuver action, remaining distance, ETA, and traffic delay. Supports turn angle and roundabout angle information.
- **Dynamic camera behavior**: Enables auto-zoom during guidance via `DynamicCameraBehavior` (or alternatively `SpeedBasedCameraBehavior`). The guidance frame rate is set to 60 fps for smooth rendering.
- **Location simulation**: Supports both real GPS positioning (`HEREPositioningProvider` with `LocationAccuracy.navigation`) and simulated route playback (`HEREPositioningSimulator`) for testing.
- **Map-matched location**: The `NavigableLocationDelegate` provides map-matched coordinates, wrong-way driving detection, and current speed information.
- **Map data prefetching**: Uses `RoutePrefetcher` (corridor-based) and `PolygonPrefetcher` (area-based) to download map data into the cache in advance for a smoother offline experience.
- **Dynamic routing**: Periodically searches for better traffic-optimized routes during guidance using the `DynamicRoutingEngine`. Configurable poll intervals and time-difference thresholds control how often alternatives are checked.
- **Live traffic updates**: Calls `calculateTrafficOnRoute` periodically to update traffic information displayed on the route polyline.
- **Electronic Horizon**: Retrieves road-ahead information based on the most probable paths. Note that ADASIS is not natively supported by the HERE SDK; this example shows how to use the Electronic Horizon features without conversion to the ADASIS data format.
- **Lane recommendation**: Optionally includes lane recommendation in maneuver notifications for supported roads.
- **Camera tracking toggle**: Allows the user to enable/disable camera tracking during guidance.

Build instructions:
-------------------

1) Copy the `heresdk.xcframework` folder (as found in the HERE SDK package) to your app's root folder.

Note: If your framework version is different than the version shown in the _Developer Guide_, you may need to adapt the source code of the example app.

2) Open Xcode by double-clicking the `*.xcodeproj` file.

Note: In Xcode, open the _General_ settings of the _App target_ and make sure that the HERE SDK framework appears under _Embedded Binaries_. If it does not appear, add the `heresdk.framework` to the _Embedded Binaries_ section ("Add other..." -> "Create folder references").

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `NavigationApp.swift` file of your project. More information can be found in the _Get Started_ section of the _Developer Guide_.
