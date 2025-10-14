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

import android.os.Bundle;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.google.android.material.bottomsheet.BottomSheetDialogFragment;
import com.here.sdk.mapview.MapError;
import com.here.sdk.mapview.MapScene;
import com.here.sdk.mapview.MapScheme;
import com.here.sdk.mapview.MapView;
import com.here.sdk.units.core.animation.UnitAnimations;

public class MapSwitcherBottomSheet extends BottomSheetDialogFragment {

    private final MapView mapView;

    protected MapSwitcherBottomSheet(MapView mapView) {
        this.mapView = mapView;
    }

    public View onCreateView(@NonNull LayoutInflater inflater,
                             @Nullable ViewGroup container,
                             @Nullable Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.heresdk_units_mapswitcher, container, false);

        TextView menuItem1 = view.findViewById(R.id.menu_item1);
        TextView menuItem2 = view.findViewById(R.id.menu_item2);
        TextView menuItem3 = view.findViewById(R.id.menu_item3);
        TextView menuItem4 = view.findViewById(R.id.menu_item4);

        UnitAnimations.applyClickAnimation(menuItem1);
        UnitAnimations.applyClickAnimation(menuItem2);
        UnitAnimations.applyClickAnimation(menuItem3);
        UnitAnimations.applyClickAnimation(menuItem4);

        menuItem1.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                loadMapScene(MapScheme.SATELLITE);
                dismiss();
            }
        });

        menuItem2.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                loadMapScene(MapScheme.NORMAL_DAY);
                dismiss();
            }
        });

        menuItem3.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                loadMapScene(MapScheme.HYBRID_DAY);
                dismiss();
            }
        });

        menuItem4.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                loadMapScene(MapScheme.TOPO_DAY);
                dismiss();
            }
        });

        return view;
    }

    private void loadMapScene(MapScheme mapScheme) {
        mapView.getMapScene().loadScene(mapScheme, new MapScene.LoadSceneCallback() {
            @Override
            public void onLoadScene(@Nullable MapError mapError) {
                if (mapError != null) {
                    Log.e("MapSwitcher", "onLoadScene() failed: " + mapError.name());
                }
            }
        });
    }
}
