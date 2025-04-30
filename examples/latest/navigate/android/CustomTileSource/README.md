This example app demonstrates how to use custom map layers, using a custom point tile source, custom raster, line and polygon layers. It enables the display of custom point, raster, line and polygon tiles with clustering features, with data sourced either from the local file system or a custom backend, regardless of the format being unknown to the HERE SDK. However, in this implementation, custom points, raster, line and polygon tiles are provided to the HERE SDK based on the requested `TileKey`, with the geodetic center of each tile added as a custom point and line geometries dynamically generated within the tile's geographical bounds. The code is designed to be flexible, allowing you to load point, raster, and line data sets stored locally or retrieved from a web service. You can find how this is done in [CustomPointTileSourceExample.java](app/src/main/java/com/here/sdk/customtilesource/CustomPointTileSourceExample.java), [CustomRasterTileSourceExample.java](app/src/main/java/com/here/sdk/customtilesource/CustomRasterTileSourceExample.java), [CustomLineTileSourceExample.java](app/src/main/java/com/here/sdk/customtilesource/CustomLineTileSourceExample.java) and [CustomPolygonTileSourceExample.java](app/src/main/java/com/here/sdk/customtilesource/CustomPolygonTileSourceExample.java).

Build instructions:
-------------------

1) Copy the AAR file of the HERE SDK for Android to your app's `app/libs` folder.

Note: If your AAR version is different than the version shown in the _Developer Guide_, you may need to adapt the source code of the example app.

2) Open Android Studio and sync the project.

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `MainActivity.java` file. More information can be found in the _Get Started_ section of the _Developer Guide_.
