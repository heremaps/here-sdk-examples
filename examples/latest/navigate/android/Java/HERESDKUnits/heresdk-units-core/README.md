# HERE SDK Units - Core

A reusable unit providing essential core functionalities such as buttons, animations and common color values. Every other unit is dependent on this core unit for their functionality.

## Core Components

- **UnitButton**: A customizable button view.
- **UnitButtonFactory**: Easily create and configure UnitButton instances programmatically.
- **UnitAnimations**: Utility methods for applying touch and click animations to views.

## Integrate the unit into your app

1. Copy `heresdk-units-core-release.aar` into your example app's lib folder.

2. Use the unit in your `Activity` or `Fragment`. Example to create and add a button programmatically:

```
    UnitButton button = UnitButtonFactory.create(context);
    button.setText("Click Me");
    layout.addView(button);
```

3. To apply animations using UnitAnimations:

```
    UnitAnimations.applyClickAnimation(button);
```

4. If you only need a button and want to customize it to your needs, you can do so in your layout XML file as follows::

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
5. Sync with Gradle and run the app.

6. Clone the repo with the HERE SDK Units project and adapt the unit to your needs.
