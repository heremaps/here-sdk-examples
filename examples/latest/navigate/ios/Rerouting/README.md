The _Rerouting_ example app shows how the HERE SDK can be used to how to handle rerouting during guidance.

- Rerouting is done automatically using the return-to-route feature of the `RoutingEngine`.
- This app is meant for in-house testing and therefore used simulated location events.
- The location events are taken from a route that can be the same as the main route shown in blue. Or it can be an
- alternative route based on the original route with inserted stopover waypoints.
- The app features a maneuver panel with optional road shield icons.
- Road shield icons are shown as on the map view using the `IconProvider` from HERE SDK.
- Note that for this example, the maneuver icons are loaded at app start from the HERE icon library.
- The app allows to toggle the simulation speed of the driver between 1 (default speed) and 8x faster.
- The app also shows how to reach an off-road destination with the `OffRoadProgressDelegate`.

Build instructions:
-------------------

1) Copy the `heresdk.xcframework` folder (as found in the HERE SDK package) to your app's root folder.

Note: If your framework version is different than the version shown in the _Developer's Guide_, you may need to adapt the source code of the example app.

2) Open Xcode by double-clicking the `*.xcodeproj` file.

Note: In Xcode, open the _General_ settings of the _App target_ and make sure that the HERE SDK framework appears under _Embedded Binaries_. If it does not appear, add the `heresdk.framework` to the _Embedded Binaries_ section ("Add other..." -> "Create folder references").

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `AppDelegate.swift` file of your project. More information can be found in the _Get Started_ section of the _Developer's Guide_.
