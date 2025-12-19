# HERE SDK Units - Speed limit

A reusable unit that can decorate the map view with a speed limit view. It can be used to show the current speed limit. With the HERE SDK (Navigate) you can access the speed limit from the `Navigator` or the `VisualNavigator` and then pass it to this unit. This is not shown in the examples below.

## Integrate the unit into your app

1. Find the latest units in the [units folder](`../units/`)  or compile them yourself.

- Copy `here-sdk-units-core-release-v[version].aar` into your example app's lib folder.
- Copy `here-sdk-units-speedlimit-release-v[version].aar` into your example app's lib folder.

Make sure to sync the project now with your Gradle files.

2. Add the unit to your app's layout:

```       
SpeedLimitView(unit = speedLimitUnit)
```

3. Use the unit in your `Activity` or `Fragment`. Example:

```
private val speedLimitUnit = SpeedLimitUnit()
...
speedLimitUnit.setLabel("Speed Limit")
speedLimitUnit.setSpeedLimit(50)
```

4. Sync with Gradle and run the app.

5. Clone the repo with the HERE SDK Units project and adapt the unit to your needs.