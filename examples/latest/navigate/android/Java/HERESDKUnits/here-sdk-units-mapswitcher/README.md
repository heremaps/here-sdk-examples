# HERE SDK Units - MapSwitcher

A reusable unit that switches map schemes when the user taps a button.

## Icon sizes

A recommended icon size for the map-switcher button is **48dp** in the layout file. The following table shows the recommended pixel sizes for different screen densities:

| Density     | Scale | Pixel Size       |
| ----------- | ----- | ---------------- |
| **mdpi**    | 1×    | **48 × 48 px**   |
| **hdpi**    | 1.5×  | **72 × 72 px**   |
| **xhdpi**   | 2×    | **96 × 96 px**   |
| **xxhdpi**  | 3×    | **144 × 144 px** |
| **xxxhdpi** | 4×    | **192 × 192 px** |

## Integrate the unit into your app

1. Find the latest units in the [units folder](`../units/`)  or compile them yourself.

- Copy `here-sdk-units-core-release-v[version].aar` into your example app's lib folder.
- Copy `here-sdk-units-mapswitcher-release-v[version].aar` into your example app's lib folder.

Make sure to sync the project now with your Gradle files.

2. Add the unit to your app's layout file. To position it in the bottom-left corner, use:

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

Then call this method, e.g. from the `MainActivity`'s `onCreate()`. This will make the unit visible, by default, based on where the unit is placed in the app's layout file.

4. Sync with Gradle and run the app.

5. Clone the repo with the HERE SDK Units project and adapt the unit to your needs.
