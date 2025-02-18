This example app demonstrates how to load custom point layers, implement clustering functionality using a custom point tile source, and integrate custom raster layers. It enables the display of custom point and raster tiles with clustering features, with data sourced either from the local file system or a custom backend, regardless of the format being unknown to the HERE SDK. In this implementation, custom points and raster tiles are provided to the HERE SDK based on the requested `TileKey`, with the geodetic center of each tile added as a custom point. The code is designed to be flexible, allowing you to load both point and raster data sets stored locally or retrieved from a web service. You can find how this is done in [CustomPointTileSourceExample.java](app/src/main/java/com/here/sdk/customtilesource/CustomPointTileSourceExample.java) and [CustomRasterTileSourceExample.java](app/src/main/java/com/here/sdk/customtilesource/CustomRasterTileSourceExample.java).

Build instructions:
-------------------

1) Copy the AAR file of the HERE SDK for Android to your app's `app/libs` folder.

Note: If your AAR version is different than the version shown in the _Developer Guide_, you may need to adapt the source code of the example app.

2) Open Android Studio and sync the project.

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `MainActivity.java` file. More information can be found in the _Get Started_ section of the _Developer Guide_.
