The UnitTesting example app shows how the HERE SDK can be mocked in unit tests.

This example uses **HERE SDK Units** to support functionality such as permission handling or buttons that are not essential to the code snippets shown in this app, as the focus is on demonstrating how to use the APIs provided by the HERE SDK. The HERE SDK Units are included as AARs in the app’s `libs` folder. For more details, see the "HERESDKUnits" app to customize or create your own unit libraries. Note that this app is intended exclusively for the HERE SDK (Navigate). You can find it in the `navigate` folder. However, it can be easily adapted for the HERE SDK (Explore) by removing any code that is not supported there. At present, most components are compatible and will compile without issues.

Build instructions:
-------------------

1) Copy the AAR and "heresdk-xxx.jar" mock JAR file of the HERE SDK for Android to your app's `app/libs` folder.

Note: If your AAR/JAR version are different than the version shown in the _Developer Guide_, you may need to adapt the source code of the example app.

2) Open Android Studio and sync the project.
3) Open file TestBasicTypes.java and run unit tests from it.
