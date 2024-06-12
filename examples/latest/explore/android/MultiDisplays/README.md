The MultiDisplays example app shows how a HERE SDK map can be shown on two separate displays using Android's [Multi-Display API](https://source.android.com/devices/tech/display/multi_display/).

Note that this app requires **Android API 26 or higher**.

You can test this app with the emulator. In emulator options, select "Displays": You can then add up to two more displays. For this app, we only show content on two displays at the same time. Both displays show a map view instance, that can be used independently.

Note that you may need to update to a newer Android Studio version. The secondary screen feature can be used only on devices with Android 8 or higher.

This app is meant for multi-display purposes. Showing multiple map view instances on the same display / activity is not covered here - for this you just need to add two `MapView`'s to your layout and handle them as separate instances. Note that foldable devices are only supported, if they can [show two separate displays at the same time](https://insights.samsung.com/2019/01/14/how-to-optimize-apps-for-folding-devices-developing-for-the-multiscreen-form-factor/). The app requires a 2nd display that is active at the same time as the main display. Otherwise, the app will behave like a single-screen app.

Build instructions:
-------------------

1) Copy the AAR file of the HERE SDK for Android to your app's `app/libs` folder.

Note: If your AAR version is different than the version shown in the _Developer Guide_, you may need to adapt the source code of the example app.

2) Open Android Studio and sync the project.

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `MainActivity.java` file. More information can be found in the _Get Started_ section of the _Developer Guide_.
