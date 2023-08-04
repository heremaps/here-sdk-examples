The _HelloMapSurface_ example app shows how to use the `MapSurface` class to render low-level graphic elements with OpenGL ES on top of the map. Using a surface can be also useful to extend the rendering limitations known from Android Auto. 
Note that gestures are not supported, so the shown map view will only show rendered content on top of the mp view, but it cannot be panned, for example. 
The app renders two triangles via OpenGL ES that make up a red square, placed over the map at the bottom center.

**Note:** Check the _HelloMapAndroidAuto_ example app to see how to enable gestures.

By default, with Android Auto you do not get access to the view hierarchy. Instead you get only a `Surface`. Natively, the HERE SDK holds this surface, so it is not possibly to render anything else on top of the map. By exposing the `MapSurface`, the HERE SDK now overcomes this limitation and it is now possible to render custom elements on top of the Android Auto window.  

With the `MapSurface` class, at the end of every frame, an app can use the OpenGL context and surface from the HERE SDK to render custom geometries. This example app shows this in isolation, but the same techniques can be also used together with Android Auto.

Build instructions:
-------------------

1) Copy the AAR file of the HERE SDK for Android to your app's `app/libs` folder.

Note: If your AAR version is different than the version shown in the _Developer Guide_, you may need to adapt the source code of the example app.

2) Open Android Studio and sync the project.

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `MainActivity.java` file. More information can be found in the _Get Started_ section of the _Developer Guide_.
