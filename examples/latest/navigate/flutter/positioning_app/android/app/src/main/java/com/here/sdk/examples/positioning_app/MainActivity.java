package com.here.sdk.examples.positioning_app;

import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
  private static final String CHANNEL = "com.here.sdk.examples.positioning_app";

  @Override
  public void configureFlutterEngine(FlutterEngine flutterEngine) {
    super.configureFlutterEngine(flutterEngine);
    new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(),
                      CHANNEL)
        .setMethodCallHandler((call, result) -> {
          if (call.method.equals("openWebLink")) {
            String url = call.arguments.toString();
            openWebLink(url);
            result.success(null);
          } else {
            result.notImplemented();
          }
        });
  }

  private void openWebLink(String url) {
    Intent intent = new Intent(Intent.ACTION_VIEW);
    intent.setData(Uri.parse(url));
    startActivity(intent);
  }
}
