The "NavigationWarners" example app shows how various events such as for speed limits and lane assistance can be set up and used during navigation. The received events information is logged.
Note that the app does not show all available listeners. Take a look also at the "Navigation" app to
see how to enhance applications with traffic information, dynamic routing or real location updates.
This app uses only simulated location events.

Build instructions:
-------------------

1) Copy the `heresdk.xcframework` folder (as found in the HERE SDK package) to your app's root folder.

Note: If your framework version is different than the version shown in the _Developer Guide_, you may need to adapt the source code of the example app.

2) Open Xcode by double-clicking the `*.xcodeproj` file.

Note: In Xcode, open the _General_ settings of the _App target_ and make sure that the HERE SDK framework appears under _Embedded Binaries_. If it does not appear, add the `heresdk.framework` to the _Embedded Binaries_ section ("Add other..." -> "Create folder references").

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `NavigationWarnersApp.swift` file of your project. More information can be found in the _Get Started_ section of the _Developer Guide_.
