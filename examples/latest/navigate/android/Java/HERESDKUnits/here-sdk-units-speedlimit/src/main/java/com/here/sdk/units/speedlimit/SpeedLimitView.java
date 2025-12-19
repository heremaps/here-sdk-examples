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

import android.content.Context;
import android.util.AttributeSet;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;

// The view hosting this HERE SDK Unit.
// The view consists only of a label with speed limit sign.
// The unit is created after inflation and provides additional logic.
public class SpeedLimitView extends LinearLayout {

    public SpeedLimitUnit speedLimitUnit;

    public SpeedLimitView(Context context) {
        super(context);
        init(context);
    }

    public SpeedLimitView(Context context, AttributeSet attrs) {
        super(context, attrs);
        init(context);
    }

    public SpeedLimitView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        init (context);
    }

    private void init(Context context) {
        LayoutInflater inflater = LayoutInflater.from(context);
        View layout = inflater.inflate(R.layout.speed_limit_view, this, true);

        // Get references to UI elements
        TextView labelTextView = layout.findViewById(R.id.speed_limit_label);
        TextView speedValueTextView = layout.findViewById(R.id.speed_limit_value);
        FrameLayout outerCircle = layout.findViewById(R.id.speed_limit_outer_circle);
        speedLimitUnit = new SpeedLimitUnit(labelTextView, speedValueTextView, outerCircle);
    }
}
