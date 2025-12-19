# HERE SDK Units - PopupMenu

A reusable pop-up menu unit that opens when the user taps a button. You can add multiple clickable entries, and multiple instances of the unit are supported.

This unit has no dependency to the HERE SDK AAR.

1. Find the latest units in the [units folder](`../units/`)  or compile them yourself.

- Copy `here-sdk-units-core-release-v[version].aar` into your example app's lib folder.
- Copy `here-sdk-units-popupmenu-release-v[version].aar` into your example app's lib folder.

2. Add the unit to your UI block. Example:

```       
PopupMenuView(
    buttonText = "Menu", menuItems = mapOf(
        "Item 1" to {
            Log.d("Menu", "Item 1 selected")
        },
        "Item 2" to {
            Log.d("Menu", "Item 2 selected")
        },
        "Item 3" to {
            Log.d("Menu", "Item 3 selected")
        }
    )
)
```
