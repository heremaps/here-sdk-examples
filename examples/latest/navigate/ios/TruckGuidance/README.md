The _TruckGuidance_ example app shows how the HERE SDK can be used to calculate routes specific for trucks.
Additional features:

- Start simulated turn-by-turn-guidance with the possibility to switch to tracking mode.
- Calculated route is based on the truck specifications - violations are logged (if any).
- Show a simple UI building block to render the current truck speed limit in km/h.
- Show a simple UI building block to render the current car speed limit in km/h.
- Show a simple UI building block to render the current driving speed in km/h (simulated driving speed with two preconfigured speed factors).
- Show a simple UI building block to render the next truck restriction. Note that all restrictions are shown, regardless of current truck specs (can be adjusted in the code).
- Search along the route for truck amenities.
- Avoid routes that are not suitable for trucks.
- Shows how to pick carto POIs to get information on POIs, traffic incidents and vehicle restrictions shown on the map.
- Shows how to use a global `TransportProfile`.
- Shows how to get `EnvironmentalZoneWarning` events.

Build instructions:
-------------------

1) Copy the `heresdk.xcframework` folder (as found in the HERE SDK package) to your app's root folder.

Note: If your framework version is different than the version shown in the _Developer Guide_, you may need to adapt the source code of the example app.

2) Open Xcode by double-clicking the `*.xcodeproj` file.

Note: In Xcode, open the _General_ settings of the _App target_ and make sure that the HERE SDK framework appears under _Embedded Binaries_. If it does not appear, add the `heresdk.framework` to the _Embedded Binaries_ section ("Add other..." -> "Create folder references").

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `AppDelegate.swift` file of your project. More information can be found in the _Get Started_ section of the _Developer Guide_.
