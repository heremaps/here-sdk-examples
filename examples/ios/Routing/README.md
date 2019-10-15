The Routing example app shows how to calculate a route from A to B with a number of waypoints in between that is visualized on the map. You can find how this is done in [RoutingExample.swift](guides/ios/markdown/en-US/examples/Routing/Routing/RoutingExample.swift).

Build instructions:
-------------------

1) Copy the heresdk.framework file to your app's root folder.

2) In Xcode, open the General settings of the App target and make sure that the HERE SDK framework appears under Embedded Binaries. If it does not appear, add the heresdk.framework to the Embedded Binaries section ("Add other..." -> "Create folder references").
