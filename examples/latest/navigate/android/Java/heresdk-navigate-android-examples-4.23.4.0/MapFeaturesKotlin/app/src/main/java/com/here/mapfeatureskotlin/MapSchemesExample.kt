/*
 * Copyright (C) 2025 HERE Europe B.V.
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
package com.here.mapfeatureskotlin

import android.util.Log
import com.here.sdk.mapview.MapScheme
import com.here.sdk.mapview.MapView

class MapSchemesExample {
    private var currentMapScheme: MapScheme? = null

    private fun loadMapScene(mapView: MapView?, mode: MapScheme) {
        currentMapScheme = mode
        mapView?.mapScene?.loadScene(mode) { mapError ->
            mapError?.let { Log.d("loadMapScene()", "Loading map failed: mapError: ${it.name}") }
        }
    }

    fun getCurrentMapScheme(): MapScheme? {
        return currentMapScheme
    }

    fun loadSchemeForCurrentView(currentMapView: MapView?, mapScheme: MapScheme) {
        loadMapScene(currentMapView, mapScheme)
    }
}