This example app demonstrates how to load custom point layers using a custom point tile source. This allows you to display custom point tiles loaded from the local file system or from a custom backend hosting a format that does not need to be known by the HERE SDK. In this example app, custom points are fed into the HERE SDK based on the requested `TileKey`. For each tile, the geodetic center is provided as custom point to HERE SDK. You can adapt the code to load locally stored point data sets or retrieved from a web service instead. You can find how this is done in [CustomPointTileSourceExample.java](app/src/main/java/com/here/sdk/custompointtilesource/CustomPointTileSourceExample.java).

Build instructions:
-------------------

1) Copy the AAR file of the HERE SDK for Android to your app's `app/libs` folder.

Note: If your AAR version is different than the version shown in the _Developer Guide_, you may need to adapt the source code of the example app.

2) Open Android Studio and sync the project.

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `MainActivity.java` file. More information can be found in the _Get Started_ section of the _Developer Guide_.
