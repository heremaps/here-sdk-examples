The Navigation Headless example app shows how the HERE SDK can be set up to navigate without following a route in the simplest way - and without showing a map view. The app uses the `Navigator` class. It loads a hardcoded GPX trace in Berlin area to start tracking along that trace using the `LocationSimulator`. It does _not_ include Positioning and does _no_ route calculation.

Build instructions:
-------------------

1) Copy the AAR file of the HERE SDK for Android to your app's `app/libs` folder.

Note: If your AAR version is different than the version shown in the _Developer Guide_, you may need to adapt the source code of the example app.

2) Open Android Studio and sync the project.

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `MainActivity.java` file. More information can be found in the _Get Started_ section of the _Developer Guide_.
