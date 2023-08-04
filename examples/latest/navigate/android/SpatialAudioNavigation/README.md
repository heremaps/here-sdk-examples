The Spatial Audio Navigation example app shows how the HERE SDK can be set up to navigate to a location in the most simplest way using spatial audio guidance.

The project contains two independent examples:
1. How to retrieve the spatial audio information provided by HERE SDK.
2. How to spatialize the audio cues making use of the data provided by HERE SDK and the spatial audio engine named Mach1.


Build instructions:
-------------------

1) Copy the AAR file of the HERE SDK for Android to your app's `app/libs` folder.
2) By default, the app shows a simple audio panning algorithm. For a new premium experience, consider using the Mach1 Spatial Engine.
3) When working with Mach1, (3.1) setup Mach1's SDK for Android following the instructions listed under [Mach1 Github repository](https://github.com/Mach1Studios/JitPack-Mach1SpatialAPI) and (3.2) uncomment the file `/spatialaudionavigation/mach1example/Mach1Encoder.java`. As the final step, (3.3) set `encoder = new Mach1Encoder();` in  `/spatialaudionavigation/SpatialAudioExample.java` (for more information regarding Mach1 spatial audio engine visit their [website](https://www.mach1.tech/developers).


Note: If your HERE SDK AAR version is different than the version shown in the _Developer Guide_, you may need to adapt the source code of the example app.

3) Open Android Studio and sync the project.

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `AndroidManifest.xml` file. More information can be found in the _Get Started_ section of the _Developer Guide_.
