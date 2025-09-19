# HERE SDK Units - Core

A reusable unit providing essential core functionalities such as buttons, animations and common color values. Every other unit is dependent on this core unit for their functionality.

## Core Components

- **UnitButton**: A customizable button view.
- **UnitAnimations**: Utility methods for applying touch and click animations to views.

## Integrate the unit into your app

1. Find the latest units in the [units folder](`../units/`)  or compile them yourself. Copy `heresdk-units-core-release-v[version].aar` into your example app's lib folder.

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
