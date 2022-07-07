The Indoor Map example app shows how to display private venues on a map view and how to interact with them. Venues are tied to your credentials. Talk to your HERE representative to provide your venue data and enable your venue data on the map. By default, no venues are shown on the map, but you can enable your private venues for your set of credentials.

Build instructions:
-------------------

1) Copy the `heresdk.xcframework` folder (as found in the HERE SDK package) to your app's root folder.

Note: If your framework version is different than the version shown in the _Developer's Guide_, you may need to adapt the source code of the example app.

2) Open Xcode by double-clicking the `*.xcodeproj` file.

Note: In Xcode, open the _General_ settings of the _App target_ and make sure that the HERE SDK framework appears under _Embedded Binaries_. If it does not appear, add the `heresdk.framework` to the _Embedded Binaries_ section ("Add other..." -> "Create folder references").

Please do not forget: To run the app, you need to follow the below mentioned steps. More information can be found in the _Get Started_ section of the _Developer's Guide_.
1) Add your HERE SDK credentials to the `Info.plist` file.
2) Set the value of your indoor map catalog HRN to the constant `let hrn: String` in the `/IndoorMap/ViewController.swift` file.
3) Enter your indoor map id once the app loads.
