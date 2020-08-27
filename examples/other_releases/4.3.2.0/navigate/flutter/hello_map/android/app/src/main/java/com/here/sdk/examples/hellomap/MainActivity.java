package com.here.sdk.examples.hellomap;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;

public class MainActivity extends FlutterActivity {

    @Override
    public void onDestroy() {
        // Workaround to prevent a crash on back press.
        // See https://github.com/flutter/flutter/issues/33511#issuecomment-584726636 for details.
        FlutterEngine flutterEngine = getFlutterEngine();
        if (flutterEngine != null) {
            flutterEngine.getPlatformViewsController().onFlutterViewDestroyed();
        }

        super.onDestroy();
    }
}
