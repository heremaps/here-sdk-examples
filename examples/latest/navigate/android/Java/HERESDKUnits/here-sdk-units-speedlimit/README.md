# HERE SDK Units - Speed limit

A reusable unit that can decorate the map view with a speed limit view. It can be used to show the current speed limit. With the HERE SDK (Navigate) you can access the speed limit from the `Navigator` or the `VisualNavigator` and then pass it to this unit. This is not shown in the examples below.

## Integrate the unit into your app

1. Find the latest units in the [units folder](`../units/`)  or compile them yourself.

- Copy `here-sdk-units-core-release-v[version].aar` into your example app's lib folder.
- Copy `here-sdk-units-speedlimit-release-v[version].aar` into your example app's lib folder.

Make sure to sync the project now with your Gradle files.

2. Add the unit to your app's layout file. To position it in the bottom-left corner, use:

```       
    <com.here.sdk.units.speedlimits.SpeedLimitView
        android:id="@+id/speed_limit"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        app:layout_constraintBottom_toBottomOf="parent"
        app:layout_constraintStart_toStartOf="parent"
        android:layout_margin="8dp" />
```

3. Use the unit in your `Activity` or `Fragment`. Example:

```
    private void setupSpeedLimit() {
        SpeedLimitView speedLimitView = findViewById(R.id.speed_limit);
        speedLimitView.setLabel("Truck");
        speedLimitView.setSpeedLimit("90");
    }
```

Then call this method, e.g. from the `MainActivity`'s `onCreate()`. This will make the unit visible, by default, based on where the unit is placed in the app's layout file.

4. Sync with Gradle and run the app.

5. Clone the repo with the HERE SDK Units project and adapt the unit to your needs.