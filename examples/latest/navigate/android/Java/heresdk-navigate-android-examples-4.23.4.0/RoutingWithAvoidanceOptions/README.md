The Routing example app shows how to calculate routes with `AvoidanceOptions` and how to 
use the `SegmentDataLoader` to retrieve data from the map.
It also allows to pick segments from the map to avoid certain areas or roads.
You can find how this is done in [RoutingExample.java](app/src/main/java/com/here/routing/RoutingExample.java).

Build instructions:
-------------------

1) Copy the AAR file of the HERE SDK for Android to your app's `app/libs` folder.

Note: If your AAR version is different than the version shown in the _Developer Guide_, you may need to adapt the source code of the example app.

2) Open Android Studio and sync the project.

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `MainActivity.java` file. More information can be found in the _Get Started_ section of the _Developer Guide_.
