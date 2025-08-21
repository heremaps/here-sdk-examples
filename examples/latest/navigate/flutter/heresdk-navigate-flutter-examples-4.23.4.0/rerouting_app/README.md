The _Rerouting_ example app shows how the HERE SDK can be used to how to handle rerouting during guidance.

- Rerouting is done automatically using the return-to-route feature of the `RoutingEngine`.
- This app is meant for in-house testing and therefore it uses simulated location events.
- The location events are taken from a route that can be the same as the main route shown in blue. Or it can be an alternative route based on the original route with inserted stopover waypoints.
- The app also shows a maneuver panel with guidance instructions and with optional road shield icons.
- Road shield icons are shown as on the map view using the `IconProvider` API from HERE SDK.
- The free-to-use maneuver icons are taken from the HERE icon library.
- The app allows to toggle the simulation speed of the driver between 1 (default speed) and 8x faster.
- The app also shows how to reach an off-road destination with the `OffRoadProgressListener`.

Build instructions:
-------------------

1) Set your HERE SDK credentials programmatically in `lib/main.dart`.

2) Unzip the HERE SDK plugin to the plugins folder inside this project. Name the folder 'here_sdk': `plugins/here_sdk`.

3) Start an emulator or simulator and execute `flutter run` from the app's directory - or run the app from within your IDE.

More information can be found in the _Get Started_ section of the _Developer Guide_.
