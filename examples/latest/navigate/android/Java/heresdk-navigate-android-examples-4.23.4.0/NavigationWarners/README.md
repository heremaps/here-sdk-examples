The "NavigationWarners" example app shows how various events such as for speed limits and lane assistance
can be set up and used during navigation. The received events information is logged.
Note that the app does not show all available listeners. Take a look also at the "Navigation" app to
see how to enhance applications with traffic information, dynamic routing or real location updates.
This app uses only simulated location events.

Build instructions:
-------------------

1) Copy the AAR file of the HERE SDK for Android to your app's `app/libs` folder.

Note: If your AAR version is different than the version shown in the _Developer Guide_, you may need to adapt the source code of the example app.

2) Open Android Studio and sync the project.

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `MainActivity.java` file. More information can be found in the _Get Started_ section of the _Developer Guide_.
