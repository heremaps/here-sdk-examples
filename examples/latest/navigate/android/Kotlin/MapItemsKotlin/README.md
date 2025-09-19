The MapItems example app shows how to pin images, native views and 3D objects to mark specific spots on the map. You can find how this is done in [MapItemsExample.kt](app/src/main/java/com/here/mapitems/MapItemsExample.kt).

**Note**: This is the same app as the "**MapItems**" app, but implemented in Kotlin instead of Java.

This example uses HERE SDK Units for supporting functionality that isn’t essential to the code samples in this app. The units are included in the app’s libs folder. For more details, see the "Java/HERESDKUnits" app.

Build instructions:
-------------------

1) Copy the AAR file of the HERE SDK for Android to your app's `app/libs` folder.

Note: If your AAR version is different than the version shown in the _Developer Guide_, you may need to adapt the source code of the example app.

2) Open Android Studio and sync the project.

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `MainActivity.kt` file. More information can be found in the _Get Started_ section of the _Developer Guide_.
