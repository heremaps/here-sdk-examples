The "NavigationWarners" example app shows how various events such as for speed limits and lane 
assistance can be set up and used during navigation. The received events information is logged.
Note that the app does not show all available listeners. Take a look also at the "Navigation" app to
see how to enhance applications with traffic information, dynamic routing or real location updates.
This app uses only simulated location events.

The app includes a toggle button ("Mode: Per-Type Listeners" / "Mode: WarnerEngine (Beta)") that lets you switch between two warning approaches at runtime:
- **Per-Type Listeners**: The previous approach using individual listeners on the VisualNavigator for each warning type (e.g., SafetyCameraWarningListener, TruckRestrictionsWarningListener).
- **WarnerEngine (Beta)**: The new unified approach using a single WarningListener on the WarnerEngine obtained from the VisualNavigator. All warning events are received through one callback and detailed warning data is looked up via the WarningsRegistry.

Toggling while guidance is running will restart the session with the newly selected mode. Check the console output to see which warnings are received.

Build instructions:
-------------------

1) Set your HERE SDK credentials programmatically in `lib/main.dart`.

2) Unzip the HERE SDK plugin to the plugins folder inside this project. Name the folder 'here_sdk': `navigation_warners_app/plugins/here_sdk`.

3) Start an emulator or simulator and execute `flutter run` from the app's directory - or run the app from within your IDE.

More information can be found in the _Get Started_ section of the _Developer Guide_.
