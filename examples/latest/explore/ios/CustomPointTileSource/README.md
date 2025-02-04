This example app demonstrates how to load custom point layers and implement clustering functionality using a custom point tile source. It enables the display of custom point tiles and clustering features, with data sourced either from the local file system or a custom backend, regardless of the format being unknown to the HERE SDK. In this implementation, custom points are provided to the HERE SDK based on the requested `TileKey`, with the geodetic center of each tile added as a custom point. The code is designed to be flexible, allowing you to load point data sets stored locally or retrieved from a web service. You can find how this is done in [CustomPointTileSourceExample.swift](CustomPointTileSource/CustomPointTileSourceExample.swift).

Build instructions:
-------------------

1) Copy the `heresdk.xcframework` folder (as found in the HERE SDK package) to your app's root folder.

Note: If your framework version is different than the version shown in the _Developer Guide_, you may need to adapt the source code of the example app.

2) Open Xcode by double-clicking the `*.xcodeproj` file.

Note: In Xcode, open the _General_ settings of the _App target_ and make sure that the HERE SDK framework appears under _Embedded Binaries_. If it does not appear, add the `heresdk.framework` to the _Embedded Binaries_ section ("Add other..." -> "Create folder references").

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `CustomPointTileSourceApp.swift` file of your project. More information can be found in the _Get Started_ section of the _Developer Guide_.
