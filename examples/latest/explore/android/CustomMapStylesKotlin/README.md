This example app shows how to load custom maps that have been made with the [HERE Style Editor](https://platform.here.com/style-editor/). Note that this requires HERE SDK 4.12.1.0 or higher. You can find how this is done in [CustomMapStylesExample.kt](app/src/main/java/com/here/CustomMapStyles/CustomMapStylesExample.kt).

**Note**: This is the same app as the "**CustomMapStyles**" app, but implemented in Kotlin instead of Java.

Build instructions:
-------------------

1) Copy the AAR file of the HERE SDK for Android to your app's `app/libs` folder.

Note: If your AAR version is different than the version shown in the _Developer Guide_, you may need to adapt the source code of the example app.

2) Open Android Studio and sync the project.

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `MainActivity.kt` file. More information can be found in the _Get Started_ section of the _Developer Guide_.
