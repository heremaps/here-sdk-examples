package com.here.sdk.examples.hiking_diary_app;

import android.os.Bundle;
import android.os.Environment;
import java.io.File;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {

    // A method channel, as defined in the GPXManager class.
    private static final String METHOD_CHANNEL = "com.example.filepath";

    @Override
    public void configureFlutterEngine(io.flutter.embedding.engine.FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        // Implement the method channel to retrieve a native file path on Android.
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), METHOD_CHANNEL)
                .setMethodCallHandler(
                        (call, result) -> {
                            if (call.method.equals("getFilePath")) {
                                // Get the filename from the arguments.
                                String fileName = call.argument("fileName");

                                // Get the app's internal storage directory using getFilesDir().
                                File internalStorageDir = getFilesDir();

                                if (internalStorageDir != null && fileName != null) {
                                    // Create a new File object with the directory and the filename to retrieve the path.
                                    File file = new File(internalStorageDir, fileName);

                                    // Return the absolute path of the file.
                                    result.success(file.getAbsolutePath());
                                } else {
                                    result.error("UNAVAILABLE", "Internal storage directory not available or invalid file name", null);
                                }
                            } else {
                                result.notImplemented();
                            }
                        }
                );
    }
}
