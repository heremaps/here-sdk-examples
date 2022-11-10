The Indoor Map example app shows how to display private venues on a map view and how to interact with them. Venues are tied to your credentials. Talk to your HERE representative to provide your venue data and enable your venue data on the map. By default, no venues are shown on the map, but you can enable your private venues for your set of credentials.

Build instructions:
-------------------

1) Set your HERE SDK credentials programmatically in `lib/main.dart`.

2) Setting HRN is optional. If `final String HRN` in the `/lib/venue_engine_widget.dart` file is not set, then HRN of default collection in realm will be selected automatically. Default collection contains all published indoor venue maps for a realm. If user wants to use a different collection then set the value of your indoor map catalog HRN to the constant `final String HRN` in the `/lib/venue_engine_widget.dart` file.

3) Unzip the HERE SDK plugin to the plugins folder inside this project. Name the folder 'here_sdk': `indoor_map_app/plugins/here_sdk`.

4) Start an emulator or simulator and execute `flutter run` from the app's directory - or run the app from within your IDE.

5) Enter your indoor map id once the app loads.

More information can be found in the _Get Started_ section of the _Developer's Guide_.
