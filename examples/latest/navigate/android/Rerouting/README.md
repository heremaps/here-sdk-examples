The _Rerouting_ example app shows how the HERE SDK can be used to how to handle rerouting during guidance. 

- Rerouting is done automatically using the return-to-route feature of the `RoutingEngine`.
- This app is meant for in-house testing and therefore used simulated location events.
- The location events are taken from a route that can be the same as the main route shown in blue. Or it can be an 
- alternative route based on the original route with inserted stopover waypoints.
- The app features a maneuver panel with optional road shield icons.
- Road shield icons are shown as on the map view using the `IconProvider` from HERE SDK.
- Note that for this example, the maneuver icons are loaded at app start from the HERE icon library.
- The app allows to toggle the simulation speed of the driver between 1 (default speed) and 8x faster. 
- The app also shows how to reach an off-road destination with the `OffRoadProgressListener`.

Build instructions:
-------------------

1) Copy the AAR file of the HERE SDK for Android to your app's `app/libs` folder.

Note: If your AAR version is different than the version shown in the _Developer's Guide_, you may need to adapt the source code of the example app.

2) Open Android Studio and sync the project.

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `MainActivity.java` file. More information can be found in the _Get Started_ section of the _Developer's Guide_.
