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

package com.here.sdk.units.mapswitcher

import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.here.sdk.mapview.MapView

class MapSwitcherUnit {
    internal var mapView by mutableStateOf<MapView?>(null)
        private set

    fun setUp(newMapView: MapView?) {
        mapView = newMapView
    }

    fun getListOfMapSchemeOptions(): List<MapSchemeOption> {
        return listOf(
            MapSchemeOption(
                iconRes = R.drawable.normal_map_scheme,
                label = "Normal",
                scheme = com.here.sdk.mapview.MapScheme.NORMAL_DAY
            ),
            MapSchemeOption(
                iconRes = R.drawable.satellite_map_scheme,
                label = "Satellite",
                scheme = com.here.sdk.mapview.MapScheme.SATELLITE
            ),
            MapSchemeOption(
                iconRes = R.drawable.hybrid_map_scheme,
                label = "Hybrid",
                scheme = com.here.sdk.mapview.MapScheme.HYBRID_DAY
            ),
            MapSchemeOption(
                iconRes = R.drawable.topo_day_scheme,
                label = "Topographic",
                scheme = com.here.sdk.mapview.MapScheme.TOPO_DAY
            )
        )
    }

    fun loadMapScheme(mapScheme: MapSchemeOption) {
        mapView?.mapScene?.loadScene(mapScheme.scheme) { mapError ->
            if (mapError == null) {
                Log.d(
                    "MapSwitcher",
                    "Map scheme changed to: ${mapScheme.label}"
                )
            } else {
                Log.e(
                    "MapSwitcher",
                    "Failed to load map scheme: ${mapError.name}"
                )
            }
        }
    }
}