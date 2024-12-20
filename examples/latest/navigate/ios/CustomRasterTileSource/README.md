This example app demonstrates how to load custom raster layers using a custom raster tile source. This allows you to display custom raster tiles loaded from the local file system or from a custom backend hosting a format that does not need to be known by the HERE SDK. In this example app, images of different colors are created at runtime and delivered as tiles. You can adapt the code to load locally stored images or images retrieved from a web service instead. The images are fed into the HERE SDK based on the requested `TileKey`. You can find how this is done in [CustomRasterTileSourceExample.swift](CustomRasterTileSourceExample/CustomRasterTileSourceExample.swift).

Build instructions:
-------------------

1) Copy the `heresdk.xcframework` folder (as found in the HERE SDK package) to your app's root folder.

Note: If your framework version is different than the version shown in the _Developer Guide_, you may need to adapt the source code of the example app.

2) Open Xcode by double-clicking the `*.xcodeproj` file.

Note: In Xcode, open the _General_ settings of the _App target_ and make sure that the HERE SDK framework appears under _Embedded Binaries_. If it does not appear, add the `heresdk.framework` to the _Embedded Binaries_ section ("Add other..." -> "Create folder references").

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `CustomRasterTileSourceApp.swift` file of your project. More information can be found in the _Get Started_ section of the _Developer Guide_.
