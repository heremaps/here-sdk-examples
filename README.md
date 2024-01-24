# HERE SDK 4.x (Lite, Explore & Navigate Edition) - Examples for Android, iOS and Flutter

![License](https://img.shields.io/badge/license-Apache%202-blue)
![Platform](https://img.shields.io/badge/platform-Android-green.svg)
![Language](https://img.shields.io/badge/language-Java%208-orange.svg)
![Platform](https://img.shields.io/badge/platform-iOS-green.svg)
![Language](https://img.shields.io/badge/language-Swift%205.3.2-orange.svg)

In this repository you can find the [latest example apps](examples/latest) that show key features of the HERE SDK in ready-to-use applications.

## About the HERE SDK

The [HERE SDK](https://developer.here.com/products/here-sdk) enables you to build powerful location-aware applications. Explore maps that are fast and smooth to interact with, pan/zoom across map views of varying resolutions, and enable the display of various elements such as routes and POIs on highly customizable map views.

<center><p>
  <img src="images/here_sdk.jpg" width="500" />
</p></center>

The HERE SDK consumes data from the [HERE Platform](https://www.here.com/products/platform) and follows modern design principles incorporating microservices and modularized components. Currently, the HERE SDK supports three platforms: Android, iOS and Flutter.

For an overview of the existing features, please check the _Developer Guide_ for the platform of your choice. Here you will also find numerous code snippets, detailed tutorials, the _API Reference_ and the latest _Release Notes_:

- Documentation for the HERE SDK for Android ([Lite Edition](https://www.here.com/docs/bundle/sdk-for-android-lite-developer-guide/page/README.html), [Explore Edition](https://www.here.com/docs/bundle/sdk-for-android-explore-developer-guide/page/README.html), [Navigate Edition](https://www.here.com/docs/bundle/sdk-for-android-navigate-developer-guide/page/README.html))
- Documentation for the HERE SDK for iOS ([Explore Edition](https://www.here.com/docs/bundle/sdk-for-ios-explore-developer-guide/page/README.html), [Navigate Edition](https://www.here.com/docs/bundle/sdk-for-ios-navigate-developer-guide/page/README.html))
- Documentation for the HERE SDK for Flutter ([Explore Edition](https://www.here.com/docs/bundle/sdk-for-flutter-explore-developer-guide/page/README.html), [Navigate Edition](https://www.here.com/docs/bundle/sdk-for-flutter-navigate-developer-guide/page/README.html))

> For now, the _Navigate Edition_ is only available upon request. Please contact your HERE representative to receive access including a set of evaluation credentials.

## List of Available Example Apps (Version 4.17.1.0)

- **HelloMap**: Shows the classic 'Hello World'.
- **HelloMapKotlin**: Shows the classic 'Hello World' using Kotlin language (Android only).
- **HelloMapWithStoryboard**: Shows the classic 'Hello World' using a Storyboard (iOS only).
- **HelloMapAndroidAuto**: Shows how to integrate Android Auto into the _HelloMap_ app to show a map on an in-car head unit display (Android only). Exclusively available for the _Explore Edition_ and the _Navigate Edition_.
- **HelloMapCarPlay**: Shows how CarPlay can be integrated into the _HelloMap_ app to display a map on an in-car head unit display (iOS only). Exclusively available for the _Explore Edition_ and the _Navigate Edition_.
- **HelloMapSurface**: Shows how to use the MapSurface class to render low-level graphic elements with OpenGL ES on top of the map. (Android only). Exclusively available for the _Explore Edition_ and the _Navigate Edition_.
- **Camera**: Shows how to change the target and the target anchor point and how to move to another location using custom map animations.
- **CameraKeyframeTracks**: Shows how to do custom camera animations with keyframe tracks.
- **CustomMapStyles**: Shows how to load custom map schemes made with the _HERE Style Editor_. Exclusively available for the _Explore Edition_ and the _Navigate Edition_.
- **CustomRasterLayers**: Shows how to load custom raster layers. Exclusively available for the _Explore Edition_ and the _Navigate Edition_.
- **Gestures**: Shows how to handle gestures.
- **OfflineMaps**: Shows how the HERE SDK can work fully offline and how offline map data can be downloaded for continents and countries. Exclusively available for the _Navigate Edition_.
- **MapItems**: Shows how to add circles, polygons and polylines, native views, 2D and 3D map markers to locate POIs (and more) on the map. 3D map markers are exclusively available for the _Explore and Navigate Editions_.
- **MultiDisplays**: Shows how a HERE SDK map can be shown on two separate displays using Android's Multi-Display API. Exclusively available for the _Explore Edition_ and the _Navigate Edition_.
- **OffscreenMapSurface**: Shows how the HERE SDK can be used to generate images of the map, without the need to put a map view on screen. Exclusively available for the _Explore Edition_ and the _Navigate Edition_ (Android only). 
- **CartoPOIPicking**: Shows how to pick embedded map markers with extended place details. Embedded map markers are already visible on every map, by default. Exclusively available for the _Explore and Navigate Editions_.
- **Routing**: Shows how to calculate routes and add them to the map.
- **RoutingHybrid**: Shows how to calculate routes and add them to the map. Also shows how to calculate routes offline, when no internet connection is available. Exclusively available for the _Navigate Edition_.
- **EVRouting**: Shows how to calculate routes for _electric vehicles_ and how to calculate the area of reach with _isoline routing_. Also shows how to search along a route.
- **Public Transit**: Shows how to calculate routes for public transportation vehicles such as subways, trains, or buses.
- **Search**: Shows how to search POIs and add them to the map. Shows also geocoding and reverse geocoding.
- **SearchHybrid**: Shows how to search for places including auto suggestions, for the address that belongs to certain geographic coordinates (reverse geocoding) and for the geographic coordinates that belong to an address (geocoding). It also shows how to search offline, when no internet connection is available. Exclusively available for the _Navigate Edition_.
- **NavigationQuickStart**: Shows how to get started with turn-by-turn navigation. Exclusively available for the _Navigate Edition_.
- **Navigation**: Gives an overview of how to implement many of the available turn-by-turn navigation and tracking features. Exclusively available for the _Navigate Edition_.
- **NavigationCustom**: Shows how the guidance view can be customized. Exclusively available for the _Navigate Edition_.
- **SpatialAudioNavigation**: Shows how to make use of spatial audio notifications for TTS voices during guidance. Exclusively available for the _Navigate Edition_.
- **Rerouting**: Shows how the HERE SDK can be used to handle rerouting during guidance. Exclusively available for the _Navigate Edition_ (Android and iOS only).
- **Positioning**: Shows how to integrate HERE Positioning. Exclusively available for the _Navigate Edition_.
- **PositioningWithBackgroundUpdates**: Shows how to integrate HERE Positioning with background location updates on Android using a foreground service. Exclusively available for the _Navigate Edition_.
- **HikingDiary**: Shows how to record GPX traces with HERE Positioning. Exclusively available for the _Navigate Edition_.
- **Traffic**: Shows how to search for real-time traffic and how to visualize it on the map.
- **TruckGuidance**: Shows how the HERE SDK can be used to calculate routes specific for trucks. In addition, it shows many more truck-related features. Exclusively available for the _Navigate Edition_ (Android only).
- **StandAloneEngine**: Shows how to use an engine without a map view.
- **IndoorMap**: Shows how to integrate private venues. Exclusively available for the _Navigate Edition_.
- **UnitTesting**: Shows how to mock HERE SDK classes when writing unit tests (the example app is available for the _Explore Edition_ and the _Navigate Edition_).

Most example apps contain a class named "XY-Example" where XY stands for the feature, which is in most cases equal to the name of the app. If you are looking for example code that shows how to use a certain HERE SDK feature, then please look for this class as it contains the most interesting parts. Note that the overall app architecture is kept as simple as possible to not shadow the parts in focus.

> Not all examples are available for all editions and platforms.

Find the [latest examples](examples/latest) for the edition and platform of your choice:

- Examples for the HERE SDK for Android ([Lite Edition](examples/latest/lite/android/), [Explore Edition](examples/latest/explore/android/), [Navigate Edition](examples/latest/navigate/android/))
- Examples for the HERE SDK for iOS ([Explore Edition](examples/latest/explore/ios/), [Navigate Edition](examples/latest/navigate/ios/))
- Examples for the HERE SDK for Flutter ([Explore Edition](examples/latest/explore/flutter/), [Navigate Edition](examples/latest/navigate/flutter/))

## Example Apps for Older Versions
Above you can find the example app links for the _latest_ HERE SDK version. If you are looking for an older version, please check our [release page](https://github.com/heremaps/here-sdk-examples/releases) where you can download tagged older releases.

## What You Need to Execute the Example Apps
1. Acquire a set of credentials: Follow the steps from the [Developer Guide](https://www.here.com/docs/category/here-sdk) for your HERE SDK edition.
2. Download the latest HERE SDK package for your desired platform as shown in the _Developer Guide_.
3. Please refer to the minimum requirements and supported devices as listed in our _Developer Guide_.

### Get Started for Android
1. Copy the AAR file of the HERE SDK for Android to the example app's `app/libs` folder.
2. Open _Android Studio_ and sync the project.
3. To run the app, insert your HERE credentials (`accessKeyId` and `accessKeySecret`) in the `MainActivity.java` file.

### Get Started for iOS
1. Copy the `heresdk.framework` file of the HERE SDK for iOS to the example app's root folder.
2. To run the app, you need to add your HERE credentials (`accessKeyId` and `accessKeySecret`) to the `AppDelegate.swift` file of the project.
### Get Started for Flutter
1. Unzip the downloaded HERE SDK for Flutter _package_. This folder contains various files including documentation assets.
2. Inside you will also find a TAR file that contains the HERE SDK for Flutter _plugin_. It contains the iOS and Android native frameworks.
3. Now unzip the TAR file and rename the folder to 'here_sdk' and place it to the `plugins` folder inside the example app's directory. The folder structure should look like this: `hello_map/plugins/here_sdk`.
4. Set your HERE SDK credentials (accessKeyId and accessKeySecret) to the `main.dart` file of the project.
5. Start an Android emulator or an iOS simulator and execute `flutter run` from the app's directory - or run the app from within your IDE.

## Get in Touch
- Information on how to contribute to this project can be found [here](CONTRIBUTING.md).
- If you have questions about billing, your account, or anything else [Contact Us](https://developer.here.com/help).

Thank you for using the HERE SDK.

## License
Copyright (C) 2019-2023 HERE Europe B.V.

See the [LICENSE](LICENSE) file in the root of this repository for license details.
