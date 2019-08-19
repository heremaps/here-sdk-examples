# HERE SDK - Examples
The HERE SDK enables you to build powerful map applications and it is available for _Android_ and _iOS_. Bundled along with it are many of HERE’s assets, available for customers to integrate with their own apps. The HERE SDK consumes data from HERE's Open Location Platform (OLP) and gives you instant access to the freshest map data of the highest quality, consistency and accuracy.

<center><p>
  <img src="here_sdk.jpg" width="500" />
</p></center>

Explore maps that are fast and smooth to interact with, pan/zoom across map views of varying resolutions, and enable the display of various elements such as routes and POIs on highly customizable map views.

## List of Available Example Apps
In this repo you can find the latest example apps accompanying the HERE SDK's _Developer's Guide_:

- **HelloMap** ([Android](examples/android/HelloMap) |[iOS](examples/ios/HelloMap)): Shows the classic 'Hello World'.
- **HelloMapWithStoryboard** ([iOS](examples/ios/HelloMapWithStoryboard)): Shows the classic 'Hello World' using a Storyboard.
- **Gestures** ([Android](examples/android/Gestures) | [iOS](examples/ios/Gestures)): Shows how to handle gestures.
- **MapMarker** ([Android](examples/android/MapMarker) | [iOS](examples/ios/MapMarker)): Shows how to add POI marker to the map.
- **MapObjects** ([Android](examples/android/MapObjects) | [iOS](examples/ios/MapObjects)): Shows how to add circles, polygones and polylines to the map.
- **MapOverlays** ([Android](examples/android/MapOverlays) | [iOS](examples/ios/MapOverlays)): Shows how to add standard platform views to the map.
- **Routing** ([Android](examples/android/Routing) | [iOS](examples/ios/Routing)): Shows how to calculate routes and add them to the map.
- **Search** ([Android](examples/android/Search) | [iOS](examples/ios/Search)): Shows how to search POIs and add them to the map.
- **Traffic** ([Android](examples/android/Traffic) | [iOS](examples/ios/Traffic)): Shows how to search for real-time traffic and how to visualize it on the map.
- **StandAloneEngine** ([Android](examples/android/StandAloneEngine) | [iOS](examples/ios/StandAloneEngine)): Shows how to use the HERE SDK headless without setting hardcoded credentials.

## What You Need
1. Acquire a set of credentials by registering yourself on [developer.here.com](https://developer.here.com/) - or ask your HERE representative.
2. Download the latest HERE SDK framework artifact for your desired platform. It can be found on [developer.here.com](https://developer.here.com/) or bundled on our [S3 bucket](https://s3-eu-west-1.amazonaws.com/here-mobilesdk-distribution/index.html).

### Minium Requirements
Please refer to the minimum requirements for _Android_ and _iOS_ as listed in our _Developer's Guide_.

## Get Started for Android
1. Copy the AAR file of the HERE SDK for Android to your app's `app/libs` folder.
2. Open _Android Studio_ and sync the project.

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `AndroidManifext.xml` file. More information can be found in the _Get Started_-section of the _Developer's Guide_.

## Get Started for iOS
1. Copy the `heresdk.framework` file of the HERE SDK for iOS to your app's root folder.
2. In Xcode, open the _General_ settings of the app target and make sure that the HERE SDK framework appears under _Embedded Binaries_. If it does not appear, add the `heresdk.framework` to the _Embedded Binaries_ section ("Add other..." -> "Create folder references").

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `Info.plist` file. More information can be found in the _Get Started_-section of the _Developer's Guide_.

## Documentation
- The _API Reference_ and the _Developer's Guide_ can be found on [developer.here.com](https://developer.here.com/) or bundled on our [S3 bucket](https://s3-eu-west-1.amazonaws.com/here-mobilesdk-distribution/index.html).
- _Release Notes_: All recent additions, more details about the current release and the differences to previous versions can be found in the included _Release Notes_ on our [S3 bucket](https://s3-eu-west-1.amazonaws.com/here-mobilesdk-distribution/index.html).

## Get in Touch
We are happy to hear your feedback. Please [contact us](https://developer.here.com/contact-us) for any questions, suggestions or improvements. Thank you for your using the HERE SDK.

## License
Copyright (C) 2019 HERE Europe B.V.

See the [LICENSE](LICENSE) file in the root of this repository for license details.
