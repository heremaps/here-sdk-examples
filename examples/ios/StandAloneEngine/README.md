The StandAloneEngine example app shows how to use an engine without a map view while building your app. You can find how this is done in [ViewController.swift](guides/ios/markdown/en-US/examples/StandAloneEngine/StandAloneEngine/ViewController.swift).

Build instructions:
-------------------

1) Copy the heresdk.framework file to your app's root folder.

2) In Xcode, open the General settings of the App target and make sure that the HERE SDK framework appears under Embedded Binaries. If it does not appear, add the heresdk.framework to the Embedded Binaries section ("Add other..." -> "Create folder references").
