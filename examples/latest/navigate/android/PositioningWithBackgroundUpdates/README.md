This app shows how to use a foreground service and fetch location updates in background to visualize your current location on a map. You can find out how this is done in [BackgroundPositioningExample.java](app/src/main/java/com/here/examples/positioningwithbackgroundupdates/BackgroundPositioningExample.java). 
The app shows a status bar notification, so that users are actively aware that the app is fetching location updates until the service is stopped or the app is removed.


Build instructions:
-------------------

1) Copy the AAR file of the HERE SDK for Android to your app's `app/libs` folder.

Note: If your AAR version is different than the version shown in the _Developer's Guide_, you may need to adapt the source code of the example app.

2) Open Android Studio and sync the project.

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `MainActivity.java` file. More information can be found in the _Get Started_ section of the _Developer's Guide_.
