The OffscreenMap example app shows how the HERE SDK can be used to render an image of the map
without adding a `MapView` to view hierarchy.

The app displays four image views and every time a `Refresh` button is pressed,
it generates new images of the map off-screen. The image views are updated
with new image once it finishes rendering.

See `OffscreenMapViewWrapper.swift` for details of how offscreen map rendering
can be implemented using `MapView` instance that is not rendered on the screen.


Build instructions:
-------------------

1) Copy the `heresdk.xcframework` folder (as found in the HERE SDK package) to your app's root folder.

Note: If your framework version is different than the version shown in the _Developer Guide_, you may need to adapt the source code of the example app.

2) Open Xcode by double-clicking the `*.xcodeproj` file.

Note: In Xcode, open the _General_ settings of the _App target_ and make sure that the HERE SDK framework appears under _Embedded Binaries_. If it does not appear, add the `heresdk.framework` to the _Embedded Binaries_ section ("Add other..." -> "Create folder references").

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `exampleApp.swift` file of your project. More information can be found in the _Get Started_ section of the _Developer Guide_.