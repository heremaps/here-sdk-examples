The HelloMapAndroidAuto example app shows how [Android Auto](https://www.android.com/auto/) can be integrated into your app using the HERE SDK to display a map view on Android's DHU.

Android Auto is only compatible with phones running Android 6.0 (API level 23) or higher.

This example uses **HERE SDK Units** to support functionality such as permission handling or buttons that are not essential to the code snippets shown in this app, as the focus is on demonstrating how to use the APIs provided by the HERE SDK. The HERE SDK Units are included as AARs in the app’s `libs` folder. For more details, see the "HERESDKUnits" app to customize or create your own unit libraries.

Build instructions:
-------------------

1) Copy the AAR file of the HERE SDK for Android to your app's `app/libs` folder.

Note: If your AAR version is different than the version shown in the _Developer Guide_, you may need to adapt the source code of the example app.

2) Open Android Studio and sync the project.

3) Check the _Android Auto_ section in the _Developer Guide_ on how to start Android's DHU.

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `HERESDKLifecycle.java` file. More information can be found in the _Get Started_ section of the _Developer Guide_.
