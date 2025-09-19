This app shows how to use positioning to calculate the distance travelled by a user. You can find how this is done in [HikingApp.java](app/src/main/java/com/here/hikingdiary/HikingApp.java).
You can find a complete [tutorial](https://www.here.com/docs/bundle/sdk-for-android-navigate-developer-guide/page/topics/hiking-app-tutorial.html) on building this hiking diary app from scratch, featuring detailed explanations of the algorithms and concepts behind location accuracy and location filters used in building this application.

This example uses HERE SDK Units for supporting functionality that isn’t essential to the code samples in this app. The units are included in the app’s libs folder. For more details, see the "HERESDKUnits" app.

Build instructions:
-------------------

1) Copy the AAR file of the HERE SDK for Android to your app's `app/libs` folder.

Note: If your AAR version is different than the version shown in the _Developer Guide_, you may need to adapt the source code of the example app.

2) Open Android Studio and sync the project.

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `MainActivity.java` file. More information can be found in the _Get Started_ section of the _Developer Guide_.
