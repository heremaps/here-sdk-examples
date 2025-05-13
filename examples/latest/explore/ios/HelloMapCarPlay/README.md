The HelloMapCarPlay example app shows how [CarPlay](https://www.apple.com/de/ios/carplay/) can be integrated into your project to display a map on an in-car's head unit display.

Build instructions:
-------------------

1) Edit `HelloMapCarPlay/HelloMapCarPlay/Entitlements.plist` to uncomment the key for testing purposes. For a production-ready app, [contact Apple](https://developer.apple.com/documentation/carplay/requesting_carplay_entitlements) to include the required entitlements in your provisioning profile for signing the app. Until then, this app cannot be tested on a real device. Use an iOS simulator instead (>= min supported iOS version of HERE SDK). From the simulator menu bar, choose _I/O -> External Displays -> CarPlay_ to show the CarPlay head unit simulator on your development machine.

2) Copy the `heresdk.xcframework` folder (as found in the HERE SDK package) to your app's root folder.

Note: If your framework version is different than the version shown in the _Developer Guide_, you may need to adapt the source code of the example app.

3) Open Xcode by double-clicking the `*.xcodeproj` file.

Note: In Xcode, open the _General_ settings of the _App target_ and make sure that the HERE SDK framework appears under _Embedded Binaries_. If it does not appear, add the `heresdk.framework` to the _Embedded Binaries_ section ("Add other..." -> "Create folder references").

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `HelloMapCarPlayApp.swift` file of your project. More information can be found in the _Get Started_ section of the _Developer Guide_.
