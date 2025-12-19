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
 
package com.here.sdk.units.mapruler;

import android.content.Context;
import android.util.AttributeSet;
import android.view.LayoutInflater;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.here.sdk.mapview.MapView;

public class MapScaleView extends LinearLayout {

    private MapScaleUnit mapScaleUnit;
    private TextView scaleText;

    public MapScaleView(Context context) {
        super(context);
        init(context);
    }

    public MapScaleView(Context context, AttributeSet attrs) {
        super(context, attrs);
        init(context);
    }

    public MapScaleView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        init(context);
    }

    private void init(Context context) {
        LayoutInflater.from(context).inflate(R.layout.heresdk_units_mapruler, this, true);
        scaleText = findViewById(R.id.scaleText);
    }

    public void setup(MapView mapView) {
        mapScaleUnit = new MapScaleUnit(mapView, scaleText);
    }
}
