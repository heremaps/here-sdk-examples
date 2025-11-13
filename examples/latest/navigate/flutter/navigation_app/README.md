The Navigation example app shows how to calculate a route from A to B and how to start turn-by-turn navigation. You can find how this is done in [NavigationExample.dart](lib/NavigationExample.dart).

In addition, this apps contains also an example of how to use the Electronic Horizon features provided by the HERE SDK. Note that ADASIS is not natively supported by the HERE SDK. Therefore, this example app shows how to use the Electronic Horizon features without a conversion to the ADASIS data format.

Build instructions:
-------------------

1) Set your HERE SDK credentials programmatically in `lib/main.dart`.

2) Unzip the HERE SDK plugin to the plugins folder inside this project. Name the folder 'here_sdk': `plugins/here_sdk`.

3) Start an emulator or simulator and execute `flutter run` from the app's directory - or run the app from within your IDE.

More information can be found in the _Get Started_ section of the _Developer Guide_.
