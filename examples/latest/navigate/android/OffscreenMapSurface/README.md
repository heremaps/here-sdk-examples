This example app shows how the HERE SDK can be used to generate images of the map, without the need to put a `MapView` on screen.

- The app screen shows four map images rendered at random zoom levels on each button click.
- A `MapSurface` is used to render the images offscreen. 
- Note that no `MapView` instance is created for this app and hence the `MapView.TakeScreenshotCallback` API is _not_ used for this low-level render example.

Build instructions:
-------------------

1) Copy the AAR file of the HERE SDK for Android to your app's `app/libs` folder.

Note: If your AAR version is different than the version shown in the _Developer Guide_, you may need to adapt the source code of the example app.

2) Open Android Studio and sync the project.

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `MainActivity.java` file. More information can be found in the _Get Started_ section of the _Developer Guide_.
