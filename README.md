# HERE SDK 4.x (Lite Edition, Explore Edition) - Examples for Android and iOS
![License](https://img.shields.io/badge/license-Apache%202-blue)
![Platform](https://img.shields.io/badge/platform-Android-green.svg)
![Language](https://img.shields.io/badge/language-Java%208-orange.svg)
![Platform](https://img.shields.io/badge/platform-iOS-green.svg)
![Language](https://img.shields.io/badge/language-Swift%205.1.2-orange.svg)

The [HERE SDK](https://developer.here.com/products/here-sdk) enables you to build powerful location-aware applications. Explore maps that are fast and smooth to interact with, pan/zoom across map views of varying resolutions, and enable the display of various elements such as routes and POIs on highly customizable map views.

<center><p>
  <img src="images/here_sdk.jpg" width="500" />
</p></center>

The HERE SDK (Lite Edition) consumes data from the [HERE Platform](https://www.here.com/products/platform) and follows modern design principles incorporating microservices and highly modularized components. Currently, the HERE SDK supports two platforms, Android and iOS.

For an overview of the existing features, please check our _Developer's Guide_:
- [HERE SDK for Android (Lite Edition): Developer's Guide](https://developer.here.com/documentation/android-sdk/dev_guide/index.html)
- [HERE SDK for iOS (Lite Edition): Developer's Guide](https://developer.here.com/documentation/ios-sdk/dev_guide/index.html)

## List of Available Example Apps (Lite Edition, Version 4.2.0.0)
In this repository you can find the latest example apps that show key features of the HERE SDK in ready-to-use applications:

- **HelloMap** ([Android](examples/4.2.0.0/lite/android/HelloMapLite) |[iOS](examples/4.2.0.0/lite/ios/HelloMapLite)): Shows the classic 'Hello World'.
- **HelloMapWithStoryboard** ([iOS](examples/4.2.0.0/lite/ios/HelloMapWithStoryboardLite)): Shows the classic 'Hello World' using a Storyboard.
- **Gestures** ([Android](examples/4.2.0.0/lite/android/GesturesLite) | [iOS](examples/4.2.0.0/lite/ios/GesturesLite)): Shows how to handle gestures.
- **MapMarker** ([Android](examples/4.2.0.0/lite/android/MapMarkerLite) | [iOS](examples/4.2.0.0/lite/ios/MapMarkerLite)): Shows how to add POI marker to the map.
- **MapObjects** ([Android](examples/4.2.0.0/lite/android/MapObjectsLite) | [iOS](examples/4.2.0.0/lite/ios/MapObjectsLite)): Shows how to add circles, polygons and polylines to the map.
- **MapOverlays** ([Android](examples/4.2.0.0/lite/android/MapOverlaysLite) | [iOS](examples/4.2.0.0/lite/ios/MapOverlaysLite)): Shows how to add standard platform views to the map.
- **Routing** ([Android](examples/4.2.0.0/lite/android/RoutingLite) | [iOS](examples/4.2.0.0/lite/ios/RoutingLite)): Shows how to calculate routes and add them to the map.
- **Search** ([Android](examples/4.2.0.0/lite/android/SearchLite) | [iOS](examples/4.2.0.0/lite/ios/SearchLite)): Shows how to search POIs and add them to the map.
- **Traffic** ([Android](examples/4.2.0.0/lite/android/TrafficLite) | [iOS](examples/4.2.0.0/lite/ios/TrafficLite)): Shows how to search for real-time traffic and how to visualize it on the map.
- **StandAloneEngine** ([Android](examples/4.2.0.0/lite/android/StandAloneEngineLite) | [iOS](examples/4.2.0.0/lite/ios/StandAloneEngineLite)): Shows how to use the HERE SDK headless without setting hardcoded credentials.

Each example app contains a file named "XY-Example" where XY stands for the feature, which is in most cases equal to the name of the app. If you are looking for example code that shows how to use a certain HERE SDK feature, then please look for this file as it contains all the details.

## What You Need
1. Acquire a set of credentials by registering yourself on [developer.here.com](https://developer.here.com/) - or ask your HERE representative.
2. Download the latest HERE SDK framework artifact for your desired platform. It can be found on [developer.here.com](https://developer.here.com/).
3. Please refer to the minimum requirements as listed in our _Developer's Guide_ for [Android](https://developer.here.com/documentation/android-sdk/dev_guide/#minimum-requirements) and [iOS](https://developer.here.com/documentation/ios-sdk/dev_guide/#minimum-requirements).

> All examples apps listed above work with the HERE SDK for Android and iOS (Lite Edition), **Version 4.2.0.0**.

## Example Apps for Version 4.2.1.0 (Lite Edition, Explore Edition)
In addition to the apps above, this repo also contains example apps for the following HERE SDK editions which are not yet available on [developer.here.com](https://developer.here.com/products/here-sdk):
- Lite Edition, Version 4.2.1.0 ([Android](examples/4.2.1.0/lite/android/), [iOS](examples/4.2.1.0/lite/ios/))
- Explore Edition, Version 4.2.1.0 ([Android](examples/4.2.1.0/explore/android/), [iOS](examples/4.2.1.0/explore/ios/))

## Get Started for Android
1. Copy the AAR file of the HERE SDK for Android to your app's `app/libs` folder.
2. Open _Android Studio_ and sync the project.

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `AndroidManifext.xml` file. More information can be found in the _Get Started_-section of the _Developer's Guide_.

## Get Started for iOS
1. Copy the `heresdk.framework` file of the HERE SDK for iOS to your app's root folder.
2. In Xcode, open the _General_ settings of the app target and make sure that the HERE SDK framework appears under _Embedded Binaries_. If it does not appear, add the `heresdk.framework` to the _Embedded Binaries_ section ("Add other..." -> "Create folder references").

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `Info.plist` file. More information can be found in the _Get Started_-section of the _Developer's Guide_.

## Documentation
- **HERE SDK for Android (Lite Edition)**: [API Reference](https://developer.here.com/documentation/android-sdk/api_reference/index.html), [Developer's Guide](https://developer.here.com/documentation/android-sdk/dev_guide/index.html)
- **HERE SDK for iOS (Lite Edition)**: [API Reference](https://developer.here.com/documentation/ios-sdk/api_reference/index.html), [Developer's Guide](https://developer.here.com/documentation/ios-sdk/dev_guide/index.html)
- Release Notes: All recent additions, more details about the current release and the differences to previous versions can be found in the included _Release Notes_ of your downloaded package.

## Get in Touch
If you have more questions, please check [stackoverflow.com/questions/tagged/here-api](http://stackoverflow.com/questions/tagged/here-api). Information on how to contribute to this project can be found [here](CONTRIBUTING.md). If you have questions about billing or your account, [contact us](https://developer.here.com/contact-us). Thank you for using the HERE SDK.

## License
Copyright (C) 2019-2020 HERE Europe B.V.

See the [LICENSE](LICENSE) file in the root of this repository for license details.
