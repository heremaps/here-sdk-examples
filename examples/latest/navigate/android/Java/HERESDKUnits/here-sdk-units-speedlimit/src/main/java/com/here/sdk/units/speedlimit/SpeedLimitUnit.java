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
package com.here.sdk.units.speedlimit;

import android.view.View;
import android.widget.FrameLayout;
import android.widget.TextView;

import androidx.annotation.NonNull;

// The HERE SDK unit class that defines the logic for the view.
// The logic sets the speed limit and label for the speed limit unit.
public class SpeedLimitUnit {

    private final TextView labelTextView;
    private final TextView speedValueTextView;
    private final FrameLayout outerCircle;

    public SpeedLimitUnit(TextView labelTextView, TextView speedValueTextView, FrameLayout outerCircle) {
        this.labelTextView = labelTextView;
        this.speedValueTextView = speedValueTextView;
        this.outerCircle = outerCircle;
    }

    public void setLabel(@NonNull String text) {
        labelTextView.setText(text);
    }

    public void setSpeedLimit(@NonNull String text) {
        speedValueTextView.setText(text);
    }

    public void show() {
        labelTextView.setVisibility(View.VISIBLE);
        outerCircle.setVisibility(View.VISIBLE);
        speedValueTextView.setVisibility(View.VISIBLE);
    }

    public void hide() {
        labelTextView.setVisibility(View.GONE);
        outerCircle.setVisibility(View.GONE);
        speedValueTextView.setVisibility(View.GONE);
    }
}
