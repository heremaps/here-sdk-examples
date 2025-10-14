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

package com.here.sdk.units.mapswitcher;

import android.view.View;
import android.widget.ImageButton;

import androidx.fragment.app.FragmentManager;

import com.here.sdk.mapview.MapView;

// The HERE SDK unit class that defines the logic for the view.
// The logic controls what to show.
public class MapSwitcherUnit {

    private final ImageButton button;

    protected MapSwitcherUnit(ImageButton button) {
        this.button = button;
    }

    /**
     * Sets up the button to show the map switcher menu.
     * It allows to select four map schemes.
     *
     * Call this from i.e. an AppCompatActivity to get the FragmentManager with
     * getSupportFragmentManager().
     */
    public void setup(MapView mapview, FragmentManager manager) {
        button.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                MapSwitcherBottomSheet sheet = new MapSwitcherBottomSheet(mapview);
                sheet.show(manager, sheet.getTag());
            }
        });
    }

    // Show the button again, after hide() was called.
    public void show() {
        button.setVisibility(View.VISIBLE);
    }

    // Hide the button and do not keep the space it occupies in the layout.
    public void hide() {
        button.setVisibility(View.GONE);
    }
}
