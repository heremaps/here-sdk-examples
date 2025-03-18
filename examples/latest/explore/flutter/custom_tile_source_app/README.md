This example app demonstrates how to load custom point layers, implement clustering functionality using a custom point tile source, integrate custom raster and line layers. It enables the display of custom point, raster, and line tiles with clustering features, with data sourced either from the local file system or a custom backend, regardless of the format being unknown to the HERE SDK. In this implementation, custom points, raster tiles, and line tiles are provided to the HERE SDK based on the requested `TileKey`, with the geodetic center of each tile added as a custom point and line geometries dynamically generated within the tile's geographical bounds. The code is designed to be flexible, allowing you to load point, raster, and line data sets stored locally or retrieved from a web service. You can find how this is done in [CustomPointTileSourceExample.dart](lib/CustomPointTileSourceExample.dart),  [CustomRasterTileSourceExample.dart](lib/CustomRasterTileSourceExample.dart) and [CustomLineTileSourceExample.dart](lib/CustomLineTileSourceExample.dart).

Build instructions:
-------------------

1) Set your HERE SDK credentials programmatically in `lib/main.dart`.

2) Unzip the HERE SDK plugin to the plugins folder inside this project. Name the folder 'here_sdk': `plugins/here_sdk`.

3) Start an emulator or simulator and execute `flutter run` from the app's directory - or run the app from within your IDE.

More information can be found in the _Get Started_ section of the _Developer Guide_.
