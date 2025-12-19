# HERE SDK Units - MapRuler

A reusable unit that displays the scale of the map.

## Integrate the unit into your app

1. Find the latest units in the [units folder](`../units/`)  or compile them yourself.

- Copy `here-sdk-units-core-release-v[version].aar` into your example app's lib folder.
- Copy `here-sdk-units-mapruler-release-v[version].aar` into your example app's lib folder.

2. Add the unit to your layout file. To position it in the bottom-left corner, use:

```       
MapScaleView(unit = mapScaleUnit)
```

3. Use the unit in your `Activity` or `Fragment`. Example:

```
private val mapScaleUnit = MapScaleUnit()
...
mapScaleUnit.setUp(mapViewNonNull)
```

4. Sync with Gradle and run the app.

5. Clone the repo with the HERE SDK Units project and adapt the unit to your needs.
