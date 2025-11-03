package com.here.sdk.examples.spatial_audio_navigation;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.io.File;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity implements SynthesizatorCallbackInterface {
    static final String SYNTHESIZATION_CHANNEL = "com.here.sdk.examples/spatialAudioExample";
    private SpatialAudioHandler spatialAudioHandler;
    private ExecutorService fileCleanUpExecutor;
    private Handler handler = new Handler(Looper.getMainLooper());

    private MethodChannel channel;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        spatialAudioHandler = new SpatialAudioHandler(getApplicationContext());
        spatialAudioHandler.setListener(MainActivity.this);
        fileCleanUpExecutor = Executors.newSingleThreadExecutor();
        executeCleanUpTask(getApplicationContext());

        BinaryMessenger messenger = flutterEngine.getDartExecutor().getBinaryMessenger();
        channel = new MethodChannel(messenger, SYNTHESIZATION_CHANNEL);

        // Receive data from Flutter
        channel.setMethodCallHandler(
                (call, result) -> {
                    if (call.method.equals("synthesizeAudioCueAndPlay")) {
                        String maneuverText = call.argument("audioCue");
                        Double initialAzimuth = call.argument("initialAzimuth");
                        spatialAudioHandler.playSpatialAudioCue(maneuverText, initialAzimuth.floatValue());
                        result.success(true);
                    } else if (call.method.equals("azimuthNotification")) {
                        Double azimuth = call.argument("azimuth");
                        boolean completedTrajectory = call.argument("completedTrajectory");
                        spatialAudioHandler.updatePanning(azimuth.floatValue(), completedTrajectory);
                    } else if (call.method.equals("dispose")) {
                        onDispose();
                    } else {
                        result.notImplemented();
                    }
                }
        );
    }

    private void onDispose() {
        spatialAudioHandler.setListener(null);
        spatialAudioHandler = null;
        channel.setMethodCallHandler(null);
        channel = null;
    }

    private void executeCleanUpTask(@NonNull Context context) {
        fileCleanUpExecutor.execute(() -> {
            File cachesDirectory = context.getCacheDir();
            final String fileNamePrefix = SpatialAudioHandler.FILE_NAME_PREFIX;
            if (!cachesDirectory.exists()) {
                return;
            }
            final File[] allFiles = cachesDirectory.listFiles();
            if (allFiles == null) {
                return;
            }
            for (File file : allFiles) {
                if (file.getName().contains(fileNamePrefix)) {
                    try {
                        file.delete();
                    } catch (Exception e) {
                        Log.d("Here_Audio_Mapper", "Failed to delete cache file");
                    }
                }
            }
            fileCleanUpExecutor.shutdown();
        });
    }

    @Override
    public void onDone(SpatialAudioHandler audioMapper, int audioCueLength) {
        invokeChannelOnMainThread("onSynthesizatorDone", audioCueLength);
    }

    @Override
    public void onStart(SpatialAudioHandler audioMapper) {
        Log.d(MainActivity.class.getSimpleName(), "Synthesization has started");
    }

    @Override
    public void onError(SpatialAudioHandler audioMapper) {
        Log.d(MainActivity.class.getSimpleName(), "There was an error during the synthesization");
        invokeChannelOnMainThread("onSynthesizatorError", null);
    }

    private void invokeChannelOnMainThread(@NonNull String method, @Nullable Object arguments) {
        handler.post(() -> {
            if (channel != null) {
                channel.invokeMethod(method, arguments);
            }
        });
    }
}
