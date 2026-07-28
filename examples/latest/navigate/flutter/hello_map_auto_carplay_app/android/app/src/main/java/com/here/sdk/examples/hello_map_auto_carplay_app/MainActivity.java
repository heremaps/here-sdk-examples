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

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

/**
 * Main activity for the phone screen. Extends {@link FlutterActivity} so all Flutter UI
 * is handled automatically.
 *
 * <p>The only responsibility of this class on the native side is to store the Flutter
 * {@link io.flutter.plugin.common.BinaryMessenger} and {@link MethodChannel} in
 * {@link AndroidAutoMapBridge} so that the {@link HelloMapAutoCarAppService} (running as a
 * separate Android Auto service) can use them when the car head unit's surface becomes available.
 *
 * <p>HERE SDK initialization is performed entirely on the Dart side.
 */
public class MainActivity extends FlutterActivity {

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        // Register the method channel and store a reference in the static bridge so that
        // HelloMapAutoCarAppService / HelloMapAutoScreen can reach Flutter from a Service context.
        MethodChannel channel = new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                AndroidAutoMapBridge.CHANNEL_NAME);

        AndroidAutoMapBridge.init(flutterEngine.getDartExecutor().getBinaryMessenger(), channel);
    }
}
