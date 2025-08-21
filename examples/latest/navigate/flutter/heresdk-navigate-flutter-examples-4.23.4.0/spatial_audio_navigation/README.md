The Spatial Audio Navigation example app shows how the HERE SDK can be set up to navigate to a location in the most simplest way providing the required data for spatial audio.

Note that the app uses native audio capabilities from Android and iOS. Look into the `android` / `ios` source folders. From the main.dart file the code is executed via method channels.
The `DefaultEncoder` and related files are also written in Java / Swift.

Build instructions:
-------------------

1) Set your HERE SDK credentials programmatically in `lib/main.dart`.

2) Unzip the HERE SDK plugin to the plugins folder inside this project. Name the folder 'here_sdk': `spatial_audio_navigation/plugins/here_sdk`.
3) By default, the app shows a simple audio panning algorithm. For a new premium experience, consider using the Mach1 Spatial Engine.
4) When working with Mach1 (for more information regarding Mach1 spatial audio engine visit their [website](https://www.mach1.tech/developers):
    4.1) Android: (4.1.1) setup Mach1's SDK for Android following the instructions listed under [Mach1 Github repository](https://github.com/Mach1Studios/JitPack-Mach1SpatialAPI) and (4.1.2) uncomment the file `/android/app/src/main/java/com/here/sdk/examples/spatial_audio_navigation/mach1example/Mach1Encoder.java`. As the final step, (4.1.3) set `encoder = new Mach1Encoder();` in  `/android/app/src/main/java/com/here/sdk/examples/spatial_audio_navigation/SpatialAudioHandler.java`
    4.2) iOS: (4.2.1) setup Mach1's 'SDK for iOS following the instructions listed under [Mach1 Github repository](https://github.com/Mach1Studios/Pod-Mach1SpatialAPI) and (4.2.2) uncomment the file 'Mach1Encoder.swift'. As the last step, (4.2.3) set `encoder = Mach1Encoder()` on `SpatialAudioHandler.swift` (for more information regarding Mach1 spatial audio engine visit their [website](https://www.mach1.tech/developers).
5) Start an emulator or simulator and execute `flutter run` from the app's directory - or run the app from within your IDE.

More information can be found in the _Get Started_ section of the _Developer Guide_.
