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

import androidx.annotation.Nullable;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;

/**
 * Static bridge that shares the Flutter {@link BinaryMessenger} and {@link MethodChannel}
 * between {@link MainActivity} (where the Flutter engine lives) and
 * {@link HelloMapAutoScreen} (which runs inside the Android Auto {@link HelloMapAutoCarAppService}).
 *
 * <p>Both components run in the same Android process, so sharing static state is safe.
 * {@link MainActivity#configureFlutterEngine} initialises this bridge once the Flutter engine
 * is ready. {@link HelloMapAutoScreen} then uses it to create a
 * {@link com.here.sdk.mapview.MapSurfaceHost} and to notify Dart when the car head unit's
 * rendering surface becomes available.
 */
public final class AndroidAutoMapBridge {

    /** Flutter method channel name – must match the constant in {@code hello_map_example.dart}. */
    public static final String CHANNEL_NAME =
            "com.here.sdk.examples.hello_map_auto_carplay_app/channel";

    /**
     * Map ID used to link the native {@link com.here.sdk.mapview.MapSurface} registered via
     * {@link com.here.sdk.mapview.MapSurfaceHost} to the Dart {@code HereMapController}.
     * Must match the value of {@code _androidAutoMapId} in {@code hello_map_example.dart}.
     */
    public static final int ANDROID_AUTO_MAP_ID = 1;

    /**
     * Typed event names used over the Flutter method channel.
     *
     * <p>Using an enum keeps native call names centralized and avoids string duplication.
     */
    public enum NativeAndroidCall {
        ON_MAP_SURFACE_READY("onMapSurfaceReady"),
        ON_SURFACE_DESTROYED("onSurfaceDestroyed"),
        ON_SCALE("androidAutoOnScale");

        private final String methodName;

        NativeAndroidCall(String methodName) {
            this.methodName = methodName;
        }

        public String methodName() {
            return methodName;
        }
    }

    @Nullable
    private static BinaryMessenger messenger;

    @Nullable
    private static MethodChannel channel;

    private AndroidAutoMapBridge() {}

    /**
     * Called from {@link MainActivity#configureFlutterEngine} once the Flutter engine is ready.
     *
     * @param messenger the Flutter binary messenger for platform channel communication.
     * @param channel   the pre-configured method channel pointing to Dart.
     */
    public static synchronized void init(BinaryMessenger messenger, MethodChannel channel) {
        AndroidAutoMapBridge.messenger = messenger;
        AndroidAutoMapBridge.channel = channel;
    }

    /**
     * @return the Flutter {@link BinaryMessenger}, or {@code null} if the Flutter engine has not
     *         started yet (i.e. the phone companion app has not been opened).
     */
    @Nullable
    public static synchronized BinaryMessenger getMessenger() {
        return messenger;
    }

    /**
     * @return the Flutter {@link MethodChannel}, or {@code null} if the Flutter engine has not
     *         started yet.
     */
    @Nullable
    public static synchronized MethodChannel getChannel() {
        return channel;
    }
}
