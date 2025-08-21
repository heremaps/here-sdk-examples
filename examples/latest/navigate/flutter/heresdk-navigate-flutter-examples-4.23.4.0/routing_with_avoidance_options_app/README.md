The Routing example app shows how to calculate routes with `AvoidanceOptions` and how to
use the `SegmentDataLoader` to retrieve data from the map.
It also allows to pick segments from the map to avoid certain areas or roads.
You can find how this is done in [routing_with_avoidance_options_example.dart](lib/routing_with_avoidance_options_example.dart).

Build instructions:
-------------------

1) Set your HERE SDK credentials programmatically in `lib/main.dart`.

2) Unzip the HERE SDK plugin to the plugins folder inside this project. Name the folder 'here_sdk': `plugins/here_sdk`.

3) Start an emulator or simulator and execute `flutter run` from the app's directory - or run the app from within your IDE.

More information can be found in the _Get Started_ section of the _Developer Guide_.
