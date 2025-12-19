# HERE SDK Units - Core

A reusable unit providing essential core functionalities such as buttons, animations and common color values. Every other unit is dependent on this core unit for their functionality.

## Core Components

- **UnitButton**: A customizable button view.
- **UnitDialog**: A customizable dialog view that displays title and scrollable text with rounded corners and pop-in animation.
- **UnitAnimations**: Utility methods for applying touch and click animations to views.
- **PermissionsRequestor**: A helper class to check for Android permissions.

## Integrate the unit into your app

1. Find the latest units in the [units folder](`../units/`)  or compile them yourself. Copy `here-sdk-units-core-release-v[version].aar` into your example app's lib folder.

2. Add the unit to your layout file:

```
var showDialog by remember { mutableStateOf(false) }
UnitButton(
    text = "Show Dialog",
    onClick = { showDialog = true })
if (showDialog) {
    // Unit Dialog with title and description only.
    UnitDialog(
        title = "Note: Title",
        message = "This is scrollable long description message.",
        onDismiss = {
            showDialog = false
            Log.d("Test", "UnitDialog closed")
        }
    )
}
```

3. Sync with Gradle and run the app.

4. Clone the repo with the HERE SDK Units project and adapt the unit to your needs.

## How to use the PermissionsRequestor

Add the following code to your `Activity`:

```java
private lateinit var permissionsRequestor: PermissionsRequestor
```

For Kotlin it looks like this:

```kotlin
private var permissionsRequestor: PermissionsRequestor? = null

...

// Convenience method to check all permissions that have been added to the AndroidManifest.
private fun handleAndroidPermissions() {
    permissionsRequestor.request(object :
        PermissionsRequestor.ResultListener {
        override fun permissionsGranted() {
            loadMapScene()
        }

        override fun permissionsDenied() {
            Log.e(TAG, "Permissions denied by user.")
        }
    })
}
```

Make sure to call `handleAndroidPermissions()`, for example, when creating the `HereMapView`.
