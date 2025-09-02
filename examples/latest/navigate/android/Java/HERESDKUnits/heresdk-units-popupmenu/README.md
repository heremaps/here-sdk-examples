# HERE SDK Units - PopupMenu

A reusable pop-up menu unit that opens when the user taps a button. You can add multiple clickable entries, and multiple instances of the unit are supported.

The list of entries is not limited. Each item’s name must be unique. If the items don’t fit on the screen, the menu becomes scrollable automatically.

This unit has no dependency to the HERE SDK AAR.

## Integrate the unit into your app

1. Copy `heresdk-units-popupmenu-release.aar` into your example app's lib folder.

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

4. Sync with Gradle and run the app.

5. Clone the repo with the HERE SDK Units project and adapt the unit to your needs.
