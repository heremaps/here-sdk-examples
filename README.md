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

For an overview of the existing features, please check the _Developer's Guide_ for the platform of your choice. Here you will also find numerous code snippets, detailed tutorials, the _API Reference_ and the latest _Release Notes_:

- Documentation for the HERE SDK for Android ([Lite Edition](https://developer.here.com/documentation/android-sdk/dev_guide/index.html), [Explore Edition](https://developer.here.com/documentation/android-sdk-explore), [Navigate Edition]( https://developer.here.com/documentation/android-sdk-navigate))
- Documentation for the HERE SDK for iOS ([Lite Edition](https://developer.here.com/documentation/ios-sdk/dev_guide/index.html), [Explore Edition]( https://developer.here.com/documentation/ios-sdk-explore), [Navigate Edition]( https://developer.here.com/documentation/ios-sdk-navigate))
- Documentation for the HERE SDK for Flutter ([Explore Edition](https://developer.here.com/documentation/flutter-sdk-explore), [Navigate Edition](https://developer.here.com/documentation/flutter-sdk-navigate))

> For now, the _Navigate Edition_ is only available upon request. Please contact your HERE representative to receive access including a set of evaluation credentials.

## List of Available Example Apps (Version 4.12.4.0)

- **HelloMap**: Shows the classic 'Hello World'.
- **HelloMapKotlin**: Shows the classic 'Hello World' using Kotlin language (Android only).
- **HelloMapWithStoryboard**: Shows the classic 'Hello World' using a Storyboard (iOS only).
- **HelloMapAndroidAuto**: Shows how to integrate Android Auto into the _HelloMap_ app to show a map on an in-car head unit display (Android only). Exclusively available for the _Explore Edition_ and the _Navigate Edition_.
- **HelloMapCarPlay**: Shows how CarPlay can be integrated into the _HelloMap_ app to display a map on an in-car head unit display (iOS only). Exclusively available for the _Explore Edition_ and the _Navigate Edition_.
- **Camera**: Shows how to change the target and the target anchor point and how to move to another location using custom map animations.
- **CameraKeyframeTracks**: Shows how to do custom camera animations with keyframe tracks.
- **CustomMapStyles**: Shows how to load custom map schemes made with the _HERE Style Editor_. Exclusively available for the _Explore Edition_ and the _Navigate Edition_.
- **CustomRasterLayers**: Shows how to load custom raster layers. Exclusively available for the _Explore Edition_ and the _Navigate Edition_.
- **Gestures**: Shows how to handle gestures.
- **OfflineMaps**: Shows how the HERE SDK can work fully offline and how offline map data can be downloaded for continents and countries. Exclusively available for the _Navigate Edition_.
- **MapItems**: Shows how to add circles, polygons and polylines, native views, 2D and 3D map markers to locate POIs (and more) on the map. 3D map markers are exclusively available for the _Explore and Navigate Editions_.
- **CartoPOIPicking**: Shows how to pick embedded map markers with extended place details. Embedded map markers are already visible on every map, by default. This app is exclusively available for the _Explore and Navigate Editions_.
- **Routing**: Shows how to calculate routes and add them to the map.
- **RoutingHybrid**: Shows how to calculate routes and add them to the map. Also shows how to calculate routes offline, when no internet connection is available. Exclusively available for the _Navigate Edition_.
- **EVRouting**: Shows how to calculate routes for _electric vehicles_ and how to calculate the area of reach with _isoline routing_. Also shows how to search along a route.
- **Public Transit**: Shows how to calculate routes for public transportation vehicles such as subways, trains, or busses.
- **Search**: Shows how to search POIs and add them to the map. Shows also geocoding and reverse geocoding.
- **SearchHybrid**: Shows how to search POIs and add them to the map. Shows geocoding and reverse geocoding. Also shows how to search offline, when no internet connection is available. Exclusively available for the _Navigate Edition_.
- **NavigationQuickStart**: Shows how to get started with turn-by-turn navigation. Exclusively available for the _Navigate Edition_.
- **Navigation**: Gives an overview of how to implement many of the available turn-by-turn navigation and tracking features. Exclusively available for the _Navigate Edition_.
- **NavigationCustom**: Shows how the guidance view can be customized. Exclusively available for the _Navigate Edition_.
- **Positioning**: Shows how to integrate HERE Positioning. Exclusively available for the _Navigate Edition_.
- **Traffic**: Shows how to search for real-time traffic and how to visualize it on the map.
- **StandAloneEngine**: Shows how to use an engine without a map view.
- **IndoorMap**: Shows how to integrate private venues. Exclusively available for the _Navigate Edition_.
- **UnitTesting**: Shows how to mock HERE SDK classes when writing unit tests (the example app is available for the _Explore Edition_ and the _Navigate Edition_).

Most example apps contain a class named "XY-Example" where XY stands for the feature, which is in most cases equal to the name of the app. If you are looking for example code that shows how to use a certain HERE SDK feature, then please look for this class as it contains the most interesting parts. Note that the overall app architecture is kept as simple as possible to not shadow the parts in focus.

> Not all examples are available for all editions and platforms.

Find the [latest examples](examples/latest) for the edition and platform of your choice:

- Examples for the HERE SDK for Android ([Lite Edition](examples/latest/lite/android/), [Explore Edition](examples/latest/explore/android/), [Navigate Edition](examples/latest/navigate/android/))
- Examples for the HERE SDK for iOS ([Lite Edition](examples/latest/lite/ios/), [Explore Edition](examples/latest/explore/ios/), [Navigate Edition](examples/latest/navigate/ios/))
- Examples for the HERE SDK for Flutter ([Explore Edition](examples/latest/explore/flutter/), [Navigate Edition](examples/latest/navigate/flutter/))

## Example Apps for Older Versions
Above you can find the example app links for the _latest_ HERE SDK version. If you are looking for an older version, please check our [release page](https://github.com/heremaps/here-sdk-examples/releases) where you can download tagged older releases.

## What You Need to Execute the Example Apps
1. Acquire a set of credentials by registering yourself on [developer.here.com](https://developer.here.com/) - or ask your HERE representative.
2. Download the latest HERE SDK artifacts for your desired platform. These can be found on [developer.here.com](https://developer.here.com/) unless otherwise noted.
3. Please refer to the minimum requirements and supported devices as listed in our _Developer's Guide_.

### Get Started for Android
1. Copy the AAR file of the HERE SDK for Android to the example app's `app/libs` folder.
2. Open _Android Studio_ and sync the project.
3. To run the app, you need to add your HERE SDK credentials to the `AndroidManifest.xml` file.

### Get Started for iOS
1. Copy the `heresdk.framework` file of the HERE SDK for iOS to the example app's root folder.
2. To run the app, you need to add your HERE SDK credentials to the `Info.plist` file.

### Get Started for Flutter
1. Unzip the HERE SDK for Flutter plugin to the `plugins` folder that can be found inside the example app project. Renname the folder to 'here_sdk': hello_map/plugins/here_sdk
2. Set your HERE SDK credentials to
  - `hello_map/android/app/src/main/AndroidManifest.xml`
  - `hello_map/ios/Runner/Info.plist`
3. Start an Android emulator or an iOS simulator and execute `flutter run` from the app's directory - or run the app from within your IDE.

## Get in Touch
- If you have more questions, please check [stackoverflow.com/questions/tagged/here-api](http://stackoverflow.com/questions/tagged/here-api).
- Information on how to contribute to this project can be found [here](CONTRIBUTING.md).
- If you have questions about billing, your account, or anything else [Contact Us](https://developer.here.com/help).

Thank you for using the HERE SDK.

## License
Copyright (C) 2019-2022 HERE Europe B.V.

See the [LICENSE](LICENSE) file in the root of this repository for license details.
