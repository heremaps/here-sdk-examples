The SearchHybrid example app shows how to search for places including autosuggestions, for the address that belongs to certain geographic coordinates (_reverse geocoding_) and for the geographic coordinates that belong to an address (_geocoding_). It also shows how to search offline, when no internet connection is available. You can find how this is done in [SearchExample.dart](lib/SearchExample.dart).

Build instructions:
-------------------

1) Set your HERE SDK credentials to
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`

2) Unzip the HERE SDK plugin to the plugins folder inside this project. Name the folder 'here_sdk': `plugins/here_sdk`.

3) Start an emulator or simulator and execute `flutter run` from the app's directory - or run the app from within your IDE.

More information can be found in the _Get Started_ section of the _Developer's Guide_.
