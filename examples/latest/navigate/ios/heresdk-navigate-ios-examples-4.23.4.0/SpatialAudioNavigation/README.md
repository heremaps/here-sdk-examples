The SpatialAudioNavigation example app shows how initialize spatial audio guidance after calculating a route from A to B visualized on the map.

Build instructions:
-------------------

1) Copy the `heresdk.xcframework` folder (as found in the HERE SDK package) to your app's root folder.
2) By default, the app shows a simple audio panning algorithm. For a new premium experience, consider using the Mach1 Spatial Engine.
3)  When working with Mach1, (3.1) setup Mach1's 'SDK for iOS following the instructions listed under [Mach1 Github repository](https://github.com/Mach1Studios/Pod-Mach1SpatialAPI) and (3.2) uncomment the file 'Mach1Encoder.swift'. As the last step, (3.3) set `encoder = Mach1Encoder()` on `SpatialAudioNavigation/SpatialAudioExample` (for more information regarding Mach1 spatial audio engine visit their [website](https://www.mach1.tech/developers).


Note: If your framework version is different than the version shown in the _Developer Guide_, you may need to adapt the source code of the example app.

The default implementation makes usage of a really simple spatialization of the audio cues. In order to switch to Mach1 spatial audio engine, the following steps are required:

  - In method 'SpatialAudioExample.init()', set 'encoder = new Mach1Encoder()'.

2) Open Xcode by double-clicking the `*.xcodeproj` file.

Note: In Xcode, open the _General_ settings of the _App target_ and make sure that the HERE SDK framework appears under _Embedded Binaries_. If it does not appear, add the `heresdk.framework` to the _Embedded Binaries_ section ("Add other..." -> "Create folder references").

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `SpatialAudioNavigationApp.file` file of your project. More information can be found in the _Get Started_ section of the _Developer Guide_.
