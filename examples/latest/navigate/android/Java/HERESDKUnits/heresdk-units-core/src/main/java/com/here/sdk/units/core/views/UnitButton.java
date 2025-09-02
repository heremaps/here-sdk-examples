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

package com.here.sdk.units.core.views;

import android.content.Context;
import android.util.AttributeSet;
import android.view.View;
import android.view.ViewGroup;

import androidx.annotation.NonNull;
import androidx.appcompat.widget.AppCompatButton;

import com.here.sdk.units.core.R;
import com.here.sdk.units.core.animation.UnitAnimations;

public class UnitButton  extends AppCompatButton {
    public UnitButton(@NonNull Context context) {
        super(context);
        init();
    }

    public UnitButton(Context context, AttributeSet attrs) {
        super(context, attrs);
        init();
    }

    public UnitButton(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        init();
    }

    private void init() {
        // Apply click animation to this button.
        UnitAnimations.applyClickAnimation(this, new float[]{0.92f,0.85f}, new float[]{1.0f,1.0f}, 150);

        // Generate and set a unique ID for this button.
        setId(View.generateViewId());

        // Set default styling.
        setBackgroundColor(getResources().getColor(R.color.default_units_button_color, null));

        setLayoutParams(new ViewGroup.LayoutParams(
                // Width is match parent to fill the parent view width.
                ViewGroup.LayoutParams.MATCH_PARENT,
                // Height is wrap content to fit the button text.
                ViewGroup.LayoutParams.WRAP_CONTENT
        ));
    }

    // Method to set custom animation parameters.
    // scaleActionDown: [scaleX, scaleY] when button is pressed down.
    // scaleActionNormal: [scaleX, scaleY] when button is released.
    // durationMs: duration of the animation in milliseconds.
    public void setCustomAnimationScaleValues(float[] scaleActionDown, float[] scaleActionNormal, int durationMs) {
        UnitAnimations.applyClickAnimation(this, scaleActionDown, scaleActionNormal, durationMs);
    }
}
