# HERE SDK Units - Compass

A reusable unit that can decorate the map view with a compass. When the map rotates, the button shows the current orientation and allows the user to reset the map orientation to north when tapped.

## Icon sizes

A recommended icon size for the compass button is **48dp** in the layout file. The following table shows the recommended pixel sizes for different screen densities:

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
- Copy `here-sdk-units-compass-release-v[version].aar` into your example app's lib folder.

Make sure to sync the project now with your Gradle files.

2. Add the unit to your app's layout, modifiers are optional:

```       
    CompassView(unit = compassUnit)
```

3. Use the unit in your `Activity` or `Fragment`. Example:

```
    private val compassUnit = CompassUnit()
    ...
    compassUnit.setUp(mapViewNonNull)
```

4. Sync with Gradle and run the app.

5. Clone the repo with the HERE SDK Units project and adapt the unit to your needs.
