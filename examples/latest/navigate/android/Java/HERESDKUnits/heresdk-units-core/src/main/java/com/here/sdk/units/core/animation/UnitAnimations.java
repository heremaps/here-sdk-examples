
/*
 * Copyright (C) 2019-2025 HERE Europe B.V.
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

package com.here.sdk.units.core.animation;

import android.util.Log;
import android.view.MotionEvent;
import android.view.View;

public class UnitAnimations {

    // Method to apply a default click animation to any view.
    // The view scales down to 96% of its size when pressed and returns to normal size when released.
    // Duration of the animation is set to 100 milliseconds.
    public static void applyClickAnimation(View view) {
        applyClickAnimation(view, new float[]{0.96f, 0.96f}, new float[]{1.0f, 1.0f}, 100);
    }

    // Method to apply click animation to any view with custom parameters.
    // scaleActionDown: [scaleX, scaleY] when view is pressed down.
    // scaleActionNormal: [scaleX, scaleY] when view is released.
    // durationMs: duration of the animation in milliseconds.
    public static void applyClickAnimation(View view, float[] scaleActionDown, float[] scaleActionNormal, int durationMs) {
        view.setOnTouchListener(new View.OnTouchListener() {
            @Override
            public boolean onTouch(View view, MotionEvent event) {
                Log.d("ClickAnimationHelper", "onTouch event: " + event.getAction());
                switch (event.getAction()) {
                    case MotionEvent.ACTION_DOWN:
                        // Scale down when pressed.
                        view.animate().scaleX(scaleActionDown[0]).scaleY(scaleActionDown[1]).setDuration(durationMs).start();
                        break;
                    case MotionEvent.ACTION_UP:
                        // Scale back to normal when released.
                        view.animate().scaleX(scaleActionNormal[0]).scaleY(scaleActionNormal[1]).setDuration(durationMs).start();
                        break;
                    case MotionEvent.ACTION_CANCEL:
                        // Scale to custom values when cancelled.
                        view.animate().scaleX(scaleActionNormal[0]).scaleY(scaleActionNormal[1]).setDuration(durationMs).start();
                        break;
                }
                // Let the click event still pass through.
                return false;
            }
        });
    }

}
