The OfflineMaps example app shows how the HERE SDK can work fully offline and how offline map data can be downloaded for regions. As an example, the app shows how to download one region (Switzerland) and how to search for 'restaurants'. You can find how this is done in [OfflineMapsExample.java](app/src/main/java/com/here/offlinemaps/OfflineMapsExample.java).

Build instructions:
-------------------

1) Copy the AAR file of the HERE SDK for Android to your app's `app/libs` folder.

Note: If your AAR version is different than the version shown in the _Developer's Guide_, you may need to adapt the source code of the example app.

2) Open Android Studio and sync the project.

Please do not forget: To run the app, you need to add your HERE SDK credentials to the `MainActivity.java` file. More information can be found in the _Get Started_ section of the _Developer's Guide_.
