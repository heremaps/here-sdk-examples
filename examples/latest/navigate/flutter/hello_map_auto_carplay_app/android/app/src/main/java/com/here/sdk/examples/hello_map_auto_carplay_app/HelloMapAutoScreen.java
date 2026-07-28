/*
 * Copyright (C) 2026 HERE Europe B.V.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 * License-Filename: LICENSE
 */

package com.here.sdk.examples.hello_map_auto_carplay_app;

import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.util.Log;
import android.view.Surface;

import java.util.HashMap;
import java.util.Map;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.car.app.AppManager;
import androidx.car.app.CarContext;
import androidx.car.app.Screen;
import androidx.car.app.SurfaceCallback;
import androidx.car.app.SurfaceContainer;
import androidx.car.app.model.Action;
import androidx.car.app.model.ActionStrip;
import androidx.car.app.model.Template;
import androidx.car.app.navigation.model.NavigationTemplate;

import com.here.sdk.mapview.MapSurface;
import com.here.sdk.mapview.MapSurfaceHost;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;

/**
 * Android Auto {@link Screen} that renders a HERE SDK map on the car head unit display.
 *
 * <p>This class keeps the native side as minimal as possible:
 * <ul>
 *   <li>It creates a {@link MapSurface} and attaches it to the surface provided by the car host.</li>
 *   <li>It registers the {@link MapSurface} with a {@link MapSurfaceHost} so that Dart code can
 *       control the map via a {@code HereMapController} using the shared
 *       {@link AndroidAutoMapBridge#ANDROID_AUTO_MAP_ID}.</li>
 *   <li>Once the surface is ready it notifies Flutter via the method channel
 *       ({@code onMapSurfaceReady}), so that Dart loads the map scene and positions the
 *       camera.</li>
 *   <li>Gesture handling (scroll, scale, fling) is forwarded to the HERE SDK natively because
 *       it must be processed synchronously inside {@link SurfaceCallback}.</li>
 * </ul>
 *
 * <p>HERE SDK initialisation is <strong>not</strong> performed here; it happens entirely on the
 * Dart side.
 *
 * <p>See {@link HelloMapAutoCarAppService} for the entry point to the car host.
 */
public class HelloMapAutoScreen extends Screen implements SurfaceCallback {

    private static final String TAG = HelloMapAutoScreen.class.getSimpleName();
    private static final long SCALE_EVENT_MIN_INTERVAL_MS = 33L;
    private static final long MESSENGER_RETRY_DELAY_MS = 500L;

    private final MapSurface mapSurface;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final Runnable ensureMapSurfaceHostRunnable = this::ensureMapSurfaceHostAndNotifyFlutter;
    @Nullable
    private MapSurfaceHost mapSurfaceHost;
    private long lastScaleEventSentAtMs = 0L;

    @Nullable
    private Surface pendingSurface;
    private boolean surfaceReady;

    public HelloMapAutoScreen(@NonNull CarContext carContext) {
        super(carContext);

        // Register this screen as the surface callback so the car host can provide a rendering
        // surface for the map. A car API level of 2+ is required for gesture callbacks.
        carContext.getCarService(AppManager.class).setSurfaceCallback(this);

        // MapSurface implements MapViewBase and renders onto any Android Surface — including the
        // one provided by the Android Auto car host on the DHU / in-car head unit.
        mapSurface = new MapSurface();

        Log.d(TAG, "HelloMapAutoScreen created, waiting for surface from car host.");
    }

    // -----------------------------------------------------------------------------------------
    // Screen template
    // -----------------------------------------------------------------------------------------

    @NonNull
    @Override
    public Template onGetTemplate() {
        // Build the navigation template shown on the car head unit.
        // The PAN action is mandatory to enable gesture / touch support.
        ActionStrip mapActionStrip = new ActionStrip.Builder()
                .addAction(new Action.Builder(Action.PAN).build())
                .build();

    // Android Auto requires at least one ActionStrip on the NavigationTemplate (car API
    // level 2+). Without it the car host rejects the template and crashes the service.
    ActionStrip actionStrip = new ActionStrip.Builder()
        .addAction(new Action.Builder()
            .setTitle("Exit")
            .setOnClickListener(this::exit)
            .build())
        .build();

    return new NavigationTemplate.Builder()
        .setActionStrip(actionStrip)
        .setMapActionStrip(mapActionStrip)
        .build();
    }

    // -----------------------------------------------------------------------------------------
    // SurfaceCallback – called by the car host when the rendering surface changes
    // -----------------------------------------------------------------------------------------

    @Override
    public void onSurfaceAvailable(@NonNull SurfaceContainer surfaceContainer) {
        Log.d(TAG, "Surface available from car host: "
                + surfaceContainer.getWidth() + "x" + surfaceContainer.getHeight());

        // Attach the HERE SDK MapSurface to the Android Surface provided by the car host.
        mapSurface.attachSurface(
                getCarContext(),
                surfaceContainer.getSurface(),
                surfaceContainer.getWidth(),
                surfaceContainer.getHeight());

        pendingSurface = surfaceContainer.getSurface();
        surfaceReady = true;

        // Register the MapSurface with a MapSurfaceHost so Dart can control it via
        // HereMapController(ANDROID_AUTO_MAP_ID). The messenger must come from the Flutter engine
        // that was started when the companion app opened on the phone.
        ensureMapSurfaceHostAndNotifyFlutter();
    }

    @Override
    public void onSurfaceDestroyed(@NonNull SurfaceContainer surfaceContainer) {
        Log.d(TAG, "Surface destroyed.");
        mainHandler.removeCallbacks(ensureMapSurfaceHostRunnable);
        pendingSurface = null;
        surfaceReady = false;
        mapSurface.destroySurface();
        mapSurfaceHost = null;
        notifyMethodChannelOnNativeAndroidCall(
                AndroidAutoMapBridge.NativeAndroidCall.ON_SURFACE_DESTROYED,
                null);
    }

    // -----------------------------------------------------------------------------------------
    // Gesture handling – must stay native because SurfaceCallback runs on the car host thread
    // -----------------------------------------------------------------------------------------

    /** Scroll gesture (car API level 2+). */
    @Override
    public void onScroll(float distanceX, float distanceY) {
        mapSurface.getGestures().getScrollHandler().onScroll(distanceX, distanceY);
    }

    /** Pinch-to-zoom gesture (car API level 2+). */
    @Override
    public void onScale(float focusX, float focusY, float scaleFactor) {
        // Keep map gesture handling immediate to avoid visible input lag on head units.
        mapSurface.getGestures().getScaleHandler().onScale(focusX, focusY, scaleFactor);

        // Limiting scale notifications to Flutter at around 30 FPS to reduce MethodChannel load.
        if (!shouldForwardScaleEventToFlutter()) {
            return;
        }

        // Forward throttled scale details so Flutter can still observe pinch gestures.
        Map<String, Object> args = new HashMap<>();
        args.put("focusX", focusX);
        args.put("focusY", focusY);
        args.put("scaleFactor", scaleFactor);
        notifyMethodChannelOnNativeAndroidCall(AndroidAutoMapBridge.NativeAndroidCall.ON_SCALE, args);
    }

    /**
     * Fling gesture (car API level 2+).
     *
     * <p>On the desktop head unit the fling axis appears inverted relative to the scroll axis,
     * so the velocity components are negated to compensate.
     */
    @Override
    public void onFling(float velocityX, float velocityY) {
        mapSurface.getGestures().getFlingHandler().onFling(-velocityX, -velocityY);
    }

    // -----------------------------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------------------------

    private void exit() {
        getCarContext().finishCarApp();
    }

    // Caps scale notifications to Flutter to reduce MethodChannel load (~30 FPS).
    private boolean shouldForwardScaleEventToFlutter() {
        long nowMs = SystemClock.uptimeMillis();
        if (nowMs - lastScaleEventSentAtMs < SCALE_EVENT_MIN_INTERVAL_MS) {
            return false;
        }
        lastScaleEventSentAtMs = nowMs;
        return true;
    }

    private void ensureMapSurfaceHostAndNotifyFlutter() {
        if (!surfaceReady || pendingSurface == null) {
            return;
        }

        if (mapSurfaceHost != null) {
            return;
        }

        BinaryMessenger messenger = AndroidAutoMapBridge.getMessenger();
        if (messenger == null) {
            Log.w(TAG, "Flutter engine messenger is not available yet; retrying shortly.");
            mainHandler.removeCallbacks(ensureMapSurfaceHostRunnable);
            mainHandler.postDelayed(ensureMapSurfaceHostRunnable, MESSENGER_RETRY_DELAY_MS);
            return;
        }

        mapSurfaceHost = new MapSurfaceHost(
                AndroidAutoMapBridge.ANDROID_AUTO_MAP_ID,
                messenger,
                mapSurface);

        notifyMethodChannelOnNativeAndroidCall(
                AndroidAutoMapBridge.NativeAndroidCall.ON_MAP_SURFACE_READY,
                null);
    }

    /**
     * Invokes a method on the Flutter side on the main thread.
     * Uses the channel stored in {@link AndroidAutoMapBridge}.
     */
    private void notifyMethodChannelOnNativeAndroidCall(
            AndroidAutoMapBridge.NativeAndroidCall nativeAndroidCall,
            @Nullable Object arguments) {
        MethodChannel channel = AndroidAutoMapBridge.getChannel();
        if (channel == null) {
            Log.w(TAG, "Cannot notify Flutter (channel not ready): " + nativeAndroidCall.methodName());
            return;
        }
        // Surface callbacks may not run on the app main thread.
        // Dispatch channel calls to main thread to avoid thread-affinity bugs.
        // Thread-affinity bugs happen when an API is called from a thread it does not expect.
        // Symptoms include random crashes, out-of-order callbacks, or flaky UI behavior.
        mainHandler.post(
                () -> channel.invokeMethod(nativeAndroidCall.methodName(), arguments));
    }
}
