The Navigation Headless example app shows how the HERE SDK can be set up to navigate without following a route in the simplest way - and without showing a map view. The app uses the `Navigator` class. It loads a hardcoded GPX trace in Berlin area to start tracking along that trace using the `LocationSimulator`. It does _not_ include Positioning and does _no_ route calculation. Instead, the app provides basic notifications while driving in car mode.

Build instructions:
-------------------

1) Copy the `heresdk.xcframework` folder (as found in the HERE SDK package) to your app's root folder.

Note: If your framework version is different than the version shown in the _Developer Guide_, you may need to adapt the source code of the example app.

2) Open Xcode by double-clicking the `*.xcodeproj` file.

Note: In Xcode, open the _General_ settings of the _App target_ and make sure that the HERE SDK framework appears under _Embedded Binaries_. If it does not appear, add the `heresdk.framework` to the _Embedded Binaries_ section ("Add other..." -> "Create folder references").

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `NavigationHeadlessApp.swift` file of your project. More information can be found in the _Get Started_ section of the _Developer Guide_.
