# HERE SDK Units - PopupMenu

A reusable pop-up menu unit that opens when the user taps a button. You can add multiple clickable entries, and multiple instances of the unit are supported.

The list of entries is not limited. Each item’s name must be unique. If the items don’t fit on the screen, the menu becomes scrollable automatically.

This unit has no dependency to the HERE SDK AAR.

## Integrate the unit into your app for XML-based layouts and Java

1. Find the latest units in the [units folder](`../units/`)  or compile them yourself.

- Copy `heresdk-units-core-release-v[version].aar` into your example app's lib folder.
- Copy `heresdk-units-popupmenu-release-v[version].aar` into your example app's lib folder.

2. Add the unit to your layout file. Example:

```       
    <com.here.sdk.units.popupmenu.PopupMenuView
        android:id="@+id/popup_menu_button"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        app:layout_constraintTop_toBottomOf="@id/another_view"
        app:layout_constraintStart_toStartOf="parent"
        app:layout_constraintEnd_toEndOf="parent" />
```

3. Use the unit in your `Activity` or `Fragment`. Example:

```
    private void setupPopupMenuUnit1() {
        // Define menu entries with the code that should be executed when clicking on the item.
        Map<String, Runnable> menuItems = new LinkedHashMap<>();
        menuItems.put("Item 1", () -> Log.d("Menu", "Item 1 clicked"));
        menuItems.put("Item 2", () -> Log.d("Menu", "Item 2 clicked"));

        PopupMenuView popupMenuView = findViewById(R.id.popup_menu_button1);
        PopupMenuUnit popupMenuUnit = popupMenuView.popupMenuUnit;
        popupMenuUnit.setMenuContent("Menu 1", menuItems);
    }
```

## Integrate the unit into your app with Jetpack Compose and Kotlin

1. Find the latest units in the [units folder](`../units/`)  or compile them yourself.

- Copy `heresdk-units-core-release-v[version].aar` into your example app's lib folder.
- Copy `heresdk-units-popupmenu-release-v[version].aar` into your example app's lib folder.

2. Include the `appcompat` AndroidX library, as it is needed by the Core unit. Add the following to your app's `build.gradle.kts` in the `dependencies` closure. Adapt the version as needed:

```
implementation("androidx.appcompat:appcompat:1.7.1")
```

3. Create a wrapper to use the unit in Jetpack Compose:

```
@Composable
fun PopupMenuViewComposable(modifier: Modifier = Modifier) {
    AndroidView(
        modifier = modifier,
        factory = { context ->
            PopupMenuView(context).apply {
                // Set padding once when created using raw pixel values.
                val button = getChildAt(0) as? android.widget.Button
                button?.setPadding(32, 16, 32, 16)
                setupPopupMenu(this)
            }},
    )
}
```

4. Add the unit to your UI block. Example:

```       
Box(modifier = Modifier.padding(paddingValues)) {
    HereMapView(savedInstanceState)
    PopupMenuViewComposable(modifier = Modifier.fillMaxWidth().padding(16.dp))
}
```

Note that you can also use the unit without modifiers like so: `PopupMenuViewComposable()`.

5. Use the unit in your `Activity` or `Fragment`. Example:

```
private fun setupPopupMenu(popupMenuView: PopupMenuView) {
    // Define menu entries with the code that should be executed when clicking on the item.
    val menuItems = mutableMapOf<String?, Runnable?>()
        menuItems["Item 1"] = Runnable { Log.d("Menu", "Item 1 clicked") }
        menuItems["Item 2"] = Runnable { Log.d("Menu", "Item 2 clicked") }

    val popupMenuUnit = popupMenuView.popupMenuUnit
    popupMenuUnit.setMenuContent("Menu 1", menuItems)
}
```

4. Sync with Gradle and run the app.

5. Clone the repo with the HERE SDK Units project and adapt the unit to your needs.
