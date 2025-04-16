The "truck_guidance_app" example shows how the HERE SDK can be used to calculate routes specific for trucks and to start navigation.
Additional features:

- Start simulated turn-by-turn-guidance with the possibility to switch to tracking mode.
- Calculated route is based on the truck specifications - violations are logged (if any).
- Show a simple UI building block to render the current truck speed limit in km/h.
- Show a simple UI building block to render the current car speed limit in km/h.
- Show a simple UI building block to render the current driving speed in km/h (simulated driving speed with two preconfigured speed factors).
- Show a simple UI building block to render the next truck restriction. Note that all restrictions are shown, regardless of current truck specs (can be adjusted in the code).
- Search along the route for truck amenities.
- Avoid routes that are not suitable for trucks.
- Shows how to pick Carto POIs to get information on POIs, traffic incidents and vehicle restrictions shown on the map.
- Shows how to use a global `TransportProfile`.
- Shows how to get `EnvironmentalZoneWarning` events.

Build instructions:
-------------------

1) Set your HERE SDK credentials programmatically in `lib/main.dart`.

2) Unzip the HERE SDK plugin to the plugins folder inside this project. Name the folder 'here_sdk': `plugins/here_sdk`.

3) Start an emulator or simulator and execute `flutter run` from the app's directory - or run the app from within your IDE.

More information can be found in the _Get Started_ section of the _Developer Guide_.
