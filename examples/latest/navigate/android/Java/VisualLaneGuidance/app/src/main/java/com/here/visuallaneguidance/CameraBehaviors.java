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

package com.here.visuallaneguidance;

import android.content.Context;
import android.util.Log;

import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.navigation.AutomotiveCameraBehavior;
import com.here.sdk.navigation.CameraBehavior;
import com.here.sdk.navigation.TransitionCameraBehavior;
import com.here.sdk.navigation.VisualNavigator;

import java.io.IOException;
import java.io.InputStream;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;

// Owns the camera behaviors used by the example and switches between them on demand.
// TransitionCameraBehavior enables automatic switching between HD and SD camera behavior during guidance.
// AutomotiveCameraBehavior uses automotive-style tracking settings and can be configured from JSON.
// Note: Both TransitionCameraBehavior and AutomotiveCameraBehavior are beta features.
// Related APIs are subject to change without a deprecation process.
public class CameraBehaviors {

    private static final String TAG = CameraBehaviors.class.getSimpleName();
    private static final String AUTOMOTIVE_CAMERA_CONFIG_ASSET_NAME = "AutomotiveCameraConfig.json";

    private final TransitionCameraBehavior transitionCameraBehavior;
    private final AutomotiveCameraBehavior automotiveCameraBehavior;
    private final VisualNavigator visualNavigator;
    private CameraBehavior activeCameraBehavior;

    public CameraBehaviors(Context context, VisualNavigator visualNavigator) {
        this.visualNavigator = visualNavigator;
        transitionCameraBehavior = createTransitionCameraBehavior();
        automotiveCameraBehavior = createAutomotiveCameraBehavior(context);
        activeCameraBehavior = automotiveCameraBehavior;
        this.visualNavigator.setCameraBehavior(activeCameraBehavior);
    }

    public void useTransitionCameraBehavior() {
        activeCameraBehavior = transitionCameraBehavior;
        visualNavigator.setCameraBehavior(activeCameraBehavior);
    }

    public void useAutomotiveCameraBehavior() {
        automotiveCameraBehavior.setActiveCameraType(AutomotiveCameraBehavior.ActiveCameraType.TRACKING);
        activeCameraBehavior = automotiveCameraBehavior;
        visualNavigator.setCameraBehavior(activeCameraBehavior);
    }

    // Returns the currently selected camera behavior label for UI status.
    public String getCameraBehaviorStatus() {
        if (activeCameraBehavior == automotiveCameraBehavior) {
            return "AutomotiveCameraBehavior";
        }

        return "TransitionCameraBehavior";
    }

    // Creates the transition camera behavior instance used by this example.
    // Note: TransitionCameraBehavior is a beta feature.
    // Related APIs are subject to change without a deprecation process.
    private TransitionCameraBehavior createTransitionCameraBehavior() {
        TransitionCameraBehavior cameraBehavior = new TransitionCameraBehavior();
        return cameraBehavior;
    }

    // AutomotiveCameraBehavior can be created from a JSON config asset.
    // The JSON defines the automotive camera tuning so the behavior can be adjusted without
    // hardcoding all camera parameters in Java.
    // Note: AutomotiveCameraBehavior is a beta feature.
    // Related APIs are subject to change without a deprecation process.
    private AutomotiveCameraBehavior createAutomotiveCameraBehavior(Context context) {
        String configJson = loadAutomotiveCameraConfig(context);

        try {
            AutomotiveCameraBehavior cameraBehavior = new AutomotiveCameraBehavior(configJson);
            cameraBehavior.setActiveCameraType(AutomotiveCameraBehavior.ActiveCameraType.TRACKING);
            return cameraBehavior;
        } catch (InstantiationErrorException e) {
            Log.e(TAG, "Failed to create automotive camera behavior from config: " + e.error.name());
            throw new RuntimeException("Failed to create AutomotiveCameraBehavior from config", e);
        }
    }

    private String loadAutomotiveCameraConfig(Context context) {
        // The automotive camera JSON asset is loaded as UTF-8 text and then passed to
        // AutomotiveCameraBehavior so the behavior is initialized from the external config.
        try (InputStream inputStream = context.getAssets().open(AUTOMOTIVE_CAMERA_CONFIG_ASSET_NAME);
             BufferedReader bufferedReader = new BufferedReader(new InputStreamReader(inputStream, StandardCharsets.UTF_8))) {
            StringBuilder stringBuilder = new StringBuilder();
            String line;
            while ((line = bufferedReader.readLine()) != null) {
                stringBuilder.append(line).append('\n');
            }
            return stringBuilder.toString();
        } catch (IOException e) {
            throw new RuntimeException("Failed to load automotive camera config: "
                    + AUTOMOTIVE_CAMERA_CONFIG_ASSET_NAME, e);
        }
    }
}
