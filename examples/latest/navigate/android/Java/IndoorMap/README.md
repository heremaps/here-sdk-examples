The Indoor Map example app shows how to display private venues on a map view and how to interact with them. Venues are tied to your credentials. Talk to your HERE representative to provide your venue data and enable your venue data on the map. By default, no venues are shown on the map, but you can enable your private venues for your set of credentials.

This example uses **HERE SDK Units** to support functionality such as permission handling or buttons that are not essential to the code snippets shown in this app, as the focus is on demonstrating how to use the APIs provided by the HERE SDK. The HERE SDK Units are included as AARs in the app’s `libs` folder. For more details, see the "HERESDKUnits" app to customize or create your own unit libraries.

Build instructions:
-------------------

1) Copy the AAR file of the HERE SDK for Android to your app's `app/libs` folder.

Note: If your AAR version is different than the version shown in the _Developer Guide_, you may need to adapt the source code of the example app.

2) Open Android Studio and sync the project.

Please do not forget: To run the app, you need to follow the below mentioned steps. More information can be found in the _Get Started_ section of the _Developer Guide_.
1) Add your HERE SDK credentials to the `MainActivity.java` file.
2) Setting HRN is optional. If `private final String HRN` in the `com.here.sdk.examples.venues.MainActivity.java` file is not set, then HRN of default collection in realm will be selected automatically. Default collection contains all published indoor venue maps for a realm. If user wants to use a different collection then set the value of your indoor map catalog HRN to the constant `private final String HRN` in the `com.here.sdk.examples.venues.MainActivity.java` file.
3) Enter your indoor map id once the app loads.
