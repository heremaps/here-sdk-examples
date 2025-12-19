# HERE SDK Units

HERE SDK Units are small, reusable building blocks packaged as Android libraries (AARs). They demonstrate ways to modularize your UI and use the HERE SDK - for example, for switching map schemes or showing simple overlays.

HERE SDK Units help you add functionality with minimal effort and keep your app code lean. They are intended as examples and starting points, not drop-in production components. Adapt the code to your needs and test any unit you plan to use in a production app.

In this repository, units primarily extract boilerplate so that the HERE SDK example apps can focus on core HERE SDK features. For example, a unit might provide a simple menu or a map scheme switcher, while the main app demonstrates routing or rendering.

Current sample units include:

- **Core**: A basic component that is required by other units.
- **MapSwitcher**: A component that switches between map schemes.
- **MapRuler**: A component that displays the scale of the map.
- **PopupMenu**: A menu component without HERE SDK dependencies.
- **CitySelector**: A component that provides a dropdown menu for selecting predefined cities with their coordinates.
- **Compass**: A component that displays the map’s orientation and allows users to reorient the map to north with a single tap.
- **SpeedLimit**: A component that displays the current speed limit as an overlay on the map.

See each module’s README for details.

## Purpose of the HERESDKUnits app

This host app lets you develop and test HERE SDK Units. The project uses Android, Java, and XML layouts to build units into AARs that you can include in other apps alongside the HERE SDK.

In `app/src/`, you can integrate and test units on the fly. A unit is a separate library in the form of an AAR, which you can copy into your app’s `libs/` folder and use as described in the unit’s README.

Note: Units may depend on the HERE SDK, but they should not include it in their AAR. Use `compileOnly` in unit modules so that consumer apps control which HERE SDK AAR they ship. A consumer app should include the HERE SDK AAR with `implementation` so it is available at runtime.

## Before you begin

Make sure you have the following:

- A recent version of Android Studio.
- The HERE SDK for Android (Navigate) as an AAR. Note: The HERE SDK for Android (Explore) also works if you remove or disable Navigate-only features.
- HERE SDK credentials for your chosen license.
- A device or emulator for testing.

## Understand the project structure

The repository contains a host app and one or more library modules (the units):

```
HERESDKUnits/
  app/                              # Host app used to develop and test units
  heresdk-units-mapswitcher/        # Example unit (Android Library)
  ...
```

Each unit is an Android Library module that compiles to an AAR.

## Build the HERESDKUnits project

Building the project requires the same steps as any other example app that uses the HERE SDK. Follow these steps to run the host app with the included units:

1. Add your HERE SDK credentials to
   `HERESDKUnits/app/src/main/java/com/here/sdk/heresdkunits/MainActivity.java`.
2. Copy the HERE SDK `.aar` to the host app’s library folder:
   `HERESDKUnits/app/libs/`.
3. Sync the project with Gradle files.
4. Run the app on a device or emulator to confirm that the integrated units load.

Like the other example apps in this repository, this project always uses the latest HERE SDK version.

If you use the Explore license instead of Navigate, remove or adapt any unit code that relies on Navigate-only APIs.

## Create a new unit module

Use these conventions to keep modules consistent and discoverable.

- **Module name**: Prefix with `here-sdk-units-`, for example `here-sdk-units-mapswitcher` (lowercase).
- **Package name**: Use `com.here.sdk.units.<yourunit>`.

Create the module:

1. In Android Studio, select **File > New > Module**, then choose **Android Library**.
2. Set the namespace to `com.here.sdk.units.<yourunit>`.
3. Keep the generated `test/` and `androidTest/` folders for future unit and UI tests.
4. If your unit has layouts, add XML under
   `HERESDKUnits/<your-module>/src/main/res/`.
   You can copy the structure from an existing unit, but make sure to use a unique name.
5. Add your view or logic classes under
   `HERESDKUnits/<your-module>/src/main/java/com/here/sdk/units/<yourunit>/`.

Configure the module via the module’s `build.gradle` file:

- Add a compile-time reference to the HERE SDK AAR (units should not bundle the HERE SDK in their AAR) and depend on the core unit:

  ```gradle
  dependencies {
      // Pick the HERE SDK AAR matching the pattern found in HERESDKUnits/app/libs/.
      // Note: compileOnly ensures that the AAR is not exported together with the resulting unit AAR.
      compileOnly fileTree(dir: file("${project(':app').projectDir}/libs"), include: ['heresdk-navigate-*.aar'])

      // Depend on the core unit to reuse common functionality.
      api api(project(path: ':here-sdk-units-core'))
  }
  ```

- Set Java compatibility and versioning, and name the output AAR with the version (if not already present in your module's `build.gradle` file):

  ```gradle
  android {
      compileOptions {
          sourceCompatibility JavaVersion.VERSION_1_8
          targetCompatibility JavaVersion.VERSION_1_8
      }
      defaultConfig {
          versionName "1.0"
      }
      // Append versionName to the output artifact name.
      libraryVariants.all { variant ->
          variant.outputs.all { output ->
              def baseName = "${project.name}-${variant.name}-v${defaultConfig.versionName}.aar"
              output.outputFileName = baseName
          }
      }
  }
  ```

- Add a `README.md` to the module that explains how to use the unit from another app.

## Develop and test a unit in this host app

To test a unit without building an AAR for the unit, add a project dependency in the host app's `build.gradle` file:

```gradle
dependencies {
    implementation project(path: ':here-sdk-units-mapswitcher') // Replace with your module name.
}
```

Run the app on a device or emulator and iterate on the unit code. You do not need to assemble the unit's AAR for this workflow.

## Compile a unit to a reusable AAR

When you are ready to consume a unit from another project, build its AAR.

1. Place the HERE SDK `.aar` in this host app's `HERESDKUnits/app/libs/` folder.
2. Sync Gradle.
3. In **Build > Select Build Variant**, select the unit and choose the **release** variant (recommended for distribution).
4. Select **Build > Assemble Project**.
5. Find the resulting AAR at
   `HERESDKUnits/<your-module>/build/outputs/aar/<your-module>-release-v1.0.aar`.

## Use the AAR of the new unit in an example app

You can add the unit AAR to another app in two ways.

**Include all unit AARs in the `libs/` folder of another app:**

This works for all example apps in this repository, which already include this in their `build.gradle`:

```gradle
dependencies {
    implementation fileTree(
        dir: 'libs',
        include: ['*.aar', '*.jar'],
        exclude: ['*mock*.jar']
    )
}
```

For example, copy the unit AAR `heresdk-units-mapswitcher-release-v1.0.aar` into the example app’s `libs/` folder, along with the HERE SDK AAR.

**Alternatively, reference the AAR explicitly:**

```gradle
dependencies {
    implementation files('libs/heresdk-units-mapswitcher-release-v1.0.aar')
    implementation files('libs/heresdk-explore-android-4.21.2.0.164754.aar')
}
```

If you want to put HERE SDK units under version control, but exclude other AARs such as the HERE SDK AAR, you can add a selective ignore rule to your app's `.gitignore`. This is already done for all example apps in this repository:

```gitignore
# Ignore all AARs in libs.
libs/*.aar

# Keep HERE SDK Units AARs that contain 'heresdk-units' in the filename. See HERESDKUnits/README.md for details.
!libs/*heresdk-units*.aar
```

Finally, make sure to sync the project now with your Gradle files.

## Increase the version of units

When you make meaningful changes to a unit, increase its version in the unit module’s `build.gradle`:

```gradle
defaultConfig {
    versionName "1.1"
}
```

The build script above includes the `versionName` in the output AAR filename so you can track which version is in use.

## Remove a unit from this project

You can remove a module with the IDE or manually.

- **Android Studio**: Select **File > Project Structure… > Modules**, choose the module, click **– Remove**, sync the project, then delete the module directory from disk.
- **Manual**: Remove the module from `settings.gradle` (`include(":<module>")`), remove any `project(":<module>")` dependencies from other modules, sync Gradle, and delete the module directory.

## Use assets from the core module

HERE SDK Units share drawable assets via the `heresdk-units-core` module. Use these identifiers:

- Point of interest: `R.drawable.poi`  
- Route start marker: `R.drawable.poi_start`  
- Route destination marker: `R.drawable.poi_destination`

Add the core module as a dependency to access these shared assets.
