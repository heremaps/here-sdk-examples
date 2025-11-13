The Navigation example app shows how to calculate a route from A to B and how to start turn-by-turn navigation with voice commands. You can find how this is done in [NavigationExample.java](app/src/main/java/com/here/navigation/NavigationExample.java). It also shows how to set a tracking view when navigation is stopped.

In addition, this apps contains also an example of how to use the Electronic Horizon features provided by the HERE SDK. Note that ADASIS is not natively supported by the HERE SDK. Therefore, this example app shows how to use the Electronic Horizon features without a conversion to the ADASIS data format.

This example uses **HERE SDK Units** to support functionality such as permission handling or buttons that are not essential to the code snippets shown in this app, as the focus is on demonstrating how to use the APIs provided by the HERE SDK. The HERE SDK Units are included as AARs in the app’s `libs` folder. For more details, see the "HERESDKUnits" app to customize or create your own unit libraries.

Build instructions:
-------------------

1) Copy the AAR file of the HERE SDK for Android to your app's `app/libs` folder.

Note: If your AAR version is different than the version shown in the _Developer Guide_, you may need to adapt the source code of the example app.

2) Open Android Studio and sync the project.

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `MainActivity.java` file. More information can be found in the _Get Started_ section of the _Developer Guide_.
