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
    <com.here.sdk.units.core.views.UnitButton
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="Custom Text"
        android:layout_margin="1dp"
        app:layout_constraintTop_toBottomOf="@id/popup_menu_button2"
        app:layout_constraintStart_toStartOf="parent"
        app:layout_constraintEnd_toEndOf="parent" />
```

3. Sync with Gradle and run the app.

4. Clone the repo with the HERE SDK Units project and adapt the unit to your needs.

## How to use the UnitDialog in your app

Add the following code to create and show a `UnitDialog` in your app:

```java
// Create an instance of UnitDialog.
UnitDialog unitDialog = new UnitDialog(MainActivity.this);
// reuse as manytimes in the class where it is defined.
unitDialog.showDialog("Note: Title", "This is scrollable long description message.");
```

For Kotlin, see below code snippet to show a `UnitDialog`:

```kotlin
val unitDialog = UnitDialog(this)
unitDialog.showDialog("Note: Title", "This is a scrollable long description message.")
```

## How to use the PermissionsRequestor

Add the following code to your `Activity` (Java):

```java
private PermissionsRequestor permissionsRequestor;

private void handleAndroidPermissions() {
    permissionsRequestor = new PermissionsRequestor(this);
    permissionsRequestor.request(new PermissionsRequestor.ResultListener(){

        @Override
        public void permissionsGranted() {
            loadMapScene();
        }

        @Override
        public void permissionsDenied() {
            Log.e(TAG, "Permissions denied by user.");
        }
    });
}

@Override
public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
    super.onRequestPermissionsResult(requestCode, permissions, grantResults);
    permissionsRequestor.onRequestPermissionsResult(requestCode, grantResults);
}
```

For Kotlin it looks like this:

```kotlin
private var permissionsRequestor: PermissionsRequestor? = null

private fun handleAndroidPermissions() {
    permissionsRequestor = PermissionsRequestor(this)
    permissionsRequestor?.request(object : PermissionsRequestor.ResultListener {
        override fun permissionsGranted() {
            loadMapScene()
        }

        override fun permissionsDenied() {
            Log.e(TAG, "Permissions denied by user.")
        }
    })
}

override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
    super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    permissionsRequestor?.onRequestPermissionsResult(requestCode, grantResults)
}
```

Make sure to call `handleAndroidPermissions()`, for example, in the `onCreate()` method.
