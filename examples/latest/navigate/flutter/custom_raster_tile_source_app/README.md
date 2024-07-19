This example app demonstrates how to load custom raster layers using a custom raster tile source. This allows you to display custom raster tiles loaded from the local file system or from a custom backend hosting a format that does not need to be known by the HERE SDK. In this example app, images of different colors are created at runtime and delivered as tiles. You can adapt the code to load locally stored images or images retrieved from a web service instead. The images are fed into the HERE SDK based on the requested `TileKey`. You can find how this is done in [CustomRasterTileSourceExample.dart](lib/CustomRasterTileSourceExample.dart).

Build instructions:
-------------------

1) Set your HERE SDK credentials programmatically in `lib/main.dart`.

2) Unzip the HERE SDK plugin to the plugins folder inside this project. Name the folder 'here_sdk': `plugins/here_sdk`.

3) Start an emulator or simulator and execute `flutter run` from the app's directory - or run the app from within your IDE.

More information can be found in the _Get Started_ section of the _Developer Guide_.
