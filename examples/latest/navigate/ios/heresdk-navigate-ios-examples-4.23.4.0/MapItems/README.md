The MapItems example app shows how to pin images and 3D objects to mark specific spots on the map. You can find how this is done in [MapItemsExample.swift](MapItems/MapItemsExample.swift). The app also shows how to add polyline, arrows, polygon and circle instances to the map. You can find how this is done in [MapObjectsExample.swift](MapItems/MapObjectsExample.swift). In addition, the app also shows how a convenient way to show native iOS UIView layouts on the map. You can find how this is done in [MapViewPinsExample.swift](MapItems/MapViewPinsExample.swift).

Build instructions:
-------------------

1) Copy the `heresdk.xcframework` folder (as found in the HERE SDK package) to your app's root folder.

Note: If your framework version is different than the version shown in the _Developer Guide_, you may need to adapt the source code of the example app.

2) Open Xcode by double-clicking the `*.xcodeproj` file.

Note: In Xcode, open the _General_ settings of the _App target_ and make sure that the HERE SDK framework appears under _Embedded Binaries_. If it does not appear, add the `heresdk.framework` to the _Embedded Binaries_ section ("Add other..." -> "Create folder references").

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `MapItemsApp.swift` file of your project. More information can be found in the _Get Started_ section of the _Developer Guide_.
