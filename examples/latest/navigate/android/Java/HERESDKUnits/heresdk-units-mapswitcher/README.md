# HERE SDK Units - MapSwitcher

A reusable unit that switches map schemes when the user taps a button.

## Integrate the unit into your app

1. Find the latest units in the [units folder](`../units/`)  or compile them yourself.

- Copy `heresdk-units-core-release-v[version].aar` into your example app's lib folder.
- Copy `heresdk-units-mapswitcher-release-v[version].aar` into your example app's lib folder.

2. Add the unit to your layout file. To position it in the bottom-left corner, use:

```       
    <com.here.sdk.units.mapswitcher.MapSwitcherView
        android:id="@+id/map_switcher"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        app:layout_constraintBottom_toBottomOf="parent"
        app:layout_constraintStart_toStartOf="parent"
        android:layout_margin="8dp" />
```

3. Use the unit in your `Activity` or `Fragment`. Example:

```
    private void setupMapSwitcher() {
        MapSwitcherView mapSwitcherView = findViewById(R.id.map_switcher);
        MapSwitcherUnit mapSwitcherUnit = mapSwitcherView.mapSwitcherUnit;
        mapSwitcherUnit.setup(mapView, getSupportFragmentManager());
    }
```

4. Sync with Gradle and run the app.

5. Clone the repo with the HERE SDK Units project and adapt the unit to your needs.
