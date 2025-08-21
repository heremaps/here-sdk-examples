The Traffic example app shows how to toggle traffic flow and traffic incidents visualization on a map and how to use the TrafficEngine to query such data in realtime, for example, along a route. You can find how this is done in [TrafficExample.kt](app/src/main/java/com/here/traffic/TrafficExample.kt) and [RoutingExample.kt](app/src/main/java/com/here/traffic/RoutingExample.kt).

**Note**: This is the same app as the "**Traffic**" app, but implemented in Kotlin instead of Java.

Build instructions:
-------------------

1) Copy the AAR file of the HERE SDK for Android to your app's `app/libs` folder.

Note: If your AAR version is different than the version shown in the _Developer Guide_, you may need to adapt the source code of the example app.

2) Open Android Studio and sync the project.

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `MainActivity.kt` file. More information can be found in the _Get Started_ section of the _Developer Guide_.
