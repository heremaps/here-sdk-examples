/* Licensed under the Apache License, Version 2.0 (the "License");
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
package com.here.mapfeatures;

import android.util.Log;

import androidx.annotation.Nullable;

import com.here.sdk.mapview.MapError;
import com.here.sdk.mapview.MapScene;
import com.here.sdk.mapview.MapScheme;
import com.here.sdk.mapview.MapView;

public class MapSchemesExample {

    private MapScheme currentMapScheme;

    public MapSchemesExample() {
    }

    private void loadMapScene(MapView mapView, MapScheme mode) {
        currentMapScheme = mode;
        mapView.getMapScene().loadScene(mode, new MapScene.LoadSceneCallback() {
            @Override
            public void onLoadScene(@Nullable MapError mapError) {
                if (mapError == null) {
                    // Map scene loaded successfully
                } else {
                    Log.d("loadMapScene()", "Loading map failed: mapError: " + mapError.name());
                }
            }
        });
    }

    public MapScheme getCurrentMapScheme() {
        return currentMapScheme;
    }

    public void loadSchemeForCurrentView(MapView currentMapView, MapScheme mapScheme) {
        loadMapScene(currentMapView, mapScheme);
    }
}
