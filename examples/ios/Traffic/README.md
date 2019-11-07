The Traffic example app shows how to toggle traffic flow and traffic incidents visualization on a map and how to log details about traffic incidents nearby. You can find how this is done in [TrafficExample.swift](Traffic/TrafficExample.swift).

Build instructions:
-------------------

1) Copy the heresdk.framework file to your app's root folder.

2) In Xcode, open the General settings of the App target and make sure that the HERE SDK framework appears under Embedded Binaries. If it does not appear, add the heresdk.framework to the Embedded Binaries section ("Add other..." -> "Create folder references").
