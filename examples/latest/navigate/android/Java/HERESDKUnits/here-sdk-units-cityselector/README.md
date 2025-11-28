# HERE SDK Units - CitySelector

A reusable city selector unit that opens when the user taps a button. The unit provides a list of predefined cities with their coordinates, and notifies a listener when a city is selected.

The list includes major cities from around the world. Each city has associated coordinates (latitude and longitude) that can be used to navigate or center a map.

## Integrate the unit into your app for XML-based layouts and Java

1. Find the latest units in the [units folder](`../units/`) or compile them yourself.

- Copy `here-sdk-units-core-release-v[version].aar` into your example app's lib folder.
- Copy `here-sdk-units-cityselector-release-v[version].aar` into your example app's lib folder.

2. Add the unit to your layout file. Example:

```xml
    <com.here.sdk.units.cityselector.CitySelectorView
        android:id="@+id/city_selector"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        app:layout_constraintTop_toBottomOf="@id/another_view"
        app:layout_constraintStart_toStartOf="parent"
        app:layout_constraintEnd_toEndOf="parent" />
```

3. Use the unit in your `Activity` or `Fragment`. Example:

```java
    private void setupCitySelectorUnit() {
        CitySelectorView citySelectorView = findViewById(R.id.city_selector);
        citySelectorView.citySelectorUnit.setOnCitySelectedListener(
            new CitySelectorUnit.OnCitySelectedListener() {
                @Override
                public void onCitySelected(double latitude, double longitude, String cityName) {
                    Log.d("CitySelector", "Selected: " + cityName +
                          " at " + latitude + ", " + longitude);
                    // Use the coordinates to navigate or center the map
                }
            }
        );
    }
```

## Integrate the unit into your app with Jetpack Compose and Kotlin

1. Find the latest units in the [units folder](`../units/`) or compile them yourself.

- Copy `here-sdk-units-core-release-v[version].aar` into your example app's lib folder.
- Copy `here-sdk-units-cityselector-release-v[version].aar` into your example app's lib folder.

2. Include the `appcompat` AndroidX library, as it is needed by the Core unit. Add the following to your app's `build.gradle.kts` in the `dependencies` closure. Adapt the version as needed:

```kotlin
implementation("androidx.appcompat:appcompat:1.7.1")
```

3. Create a wrapper to use the unit in Jetpack Compose:

```kotlin
@Composable
fun CitySelectorViewComposable(modifier: Modifier = Modifier) {
    AndroidView(
        modifier = modifier,
        factory = { context ->
            CitySelectorView(context).apply {
                // Set padding once when created using raw pixel values.
                val button = getChildAt(0) as? android.widget.Button
                button?.setPadding(32, 16, 32, 16)
                setupCitySelector(this)
            }
        },
    )
}
```

4. Add the unit to your UI block. Example:

```kotlin
Box(modifier = Modifier.padding(paddingValues)) {
    HereMapView(savedInstanceState)
    CitySelectorViewComposable(modifier = Modifier.fillMaxWidth().padding(16.dp))
}
```

Note that you can also use the unit without modifiers like so: `CitySelectorViewComposable()`.

5. Use the unit in your `Activity` or `Fragment`. Example:

```kotlin
private fun setupCitySelector(citySelectorView: CitySelectorView) {
    citySelectorView.citySelectorUnit.setOnCitySelectedListener { latitude, longitude, cityName ->
        Log.d("CitySelector", "Selected: $cityName at $latitude, $longitude")
        // Use the coordinates to navigate or center the map
    }
}
```

6. Sync with Gradle and run the app.

7. Clone the repo with the HERE SDK Units project and adapt the unit to your needs.

## Predefined Cities

The unit includes the following cities by default:

- Mumbai, Delhi, Kolkata, Chennai, Bangalore (India)
- Berlin (Germany)
- New York (USA)
- London (UK)
- Paris (France)
- Tokyo (Japan)
- Sydney (Australia)
- Dubai (UAE)
- Singapore
- Rio de Janeiro (Brazil)
- Moscow (Russia)
- Cape Town (South Africa)

You can customize the list of cities by modifying the `CITY_COORDINATES` map in `CitySelectorUnit.java`.
