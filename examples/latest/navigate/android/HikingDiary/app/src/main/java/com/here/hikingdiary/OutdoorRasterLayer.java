/*
 * Copyright (C) 2022-2025 HERE Europe B.V.
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

package com.here.hikingdiary;

import com.here.sdk.mapview.MapCameraLimits;
import com.here.sdk.mapview.MapContentType;
import com.here.sdk.mapview.MapLayer;
import com.here.sdk.mapview.MapLayerBuilder;
import com.here.sdk.mapview.MapLayerPriority;
import com.here.sdk.mapview.MapLayerPriorityBuilder;
import com.here.sdk.mapview.MapLayerVisibilityRange;
import com.here.sdk.mapview.MapView;
import com.here.sdk.mapview.datasource.RasterDataSource;
import com.here.sdk.mapview.datasource.RasterDataSourceConfiguration;
import com.here.sdk.mapview.datasource.TileUrlProviderFactory;
import com.here.sdk.mapview.datasource.TilingScheme;

import java.util.Arrays;
import java.util.List;

// A class to show a custom raster layer on top of the default map style.
// This class has been taken and adapted for this app from the CustomerRasterLayers example app, you can find here:
// https://github.com/heremaps/here-sdk-examples/tree/master/examples/latest/navigate/android/CustomRasterLayers
public class OutdoorRasterLayer {
    private MapView mapView;
    private MapLayer customRasterLayer;
    private RasterDataSource customRasterDataSourceStyle;

    public OutdoorRasterLayer(MapView mapView) {
        this.mapView = mapView;

        String dataSourceName = "myRasterDataSourceStyle";
        customRasterDataSourceStyle = createRasterDataSource(dataSourceName);
        customRasterLayer = createMapLayer(dataSourceName);

        // We want to start with the default map style.
        customRasterLayer.setEnabled(false);
    }

    public void enable() {
        customRasterLayer.setEnabled(true);
    }

    public void disable() {
        customRasterLayer.setEnabled(false);
    }

    private RasterDataSource createRasterDataSource(String dataSourceName) {
        // Note: As an example, below is an URL template of an outdoor layer from thunderforest.com.
        // On their web page you can register a key. Without setting a valid API key, the tiles will
        // show a watermark.
        // More details on the terms of usage can be found here: https://www.thunderforest.com/terms/
        // For example, your application must have working links to https://www.thunderforest.com
        // and https://www.osm.org/copyright.
        // For the below template URL, please pay attention to the following attribution:
        // Maps © www.thunderforest.com, Data © www.osm.org/copyright.
        // Alternatively, choose another tile provider or use the (customizable) map styles provided by HERE.
        String templateUrl = "https://tile.thunderforest.com/outdoors/{z}/{x}/{y}.png";

        // The storage levels available for this data source. Supported range [0, 31].
        List<Integer> storageLevels = Arrays.asList(2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16);

        RasterDataSourceConfiguration.Provider rasterProviderConfig = new RasterDataSourceConfiguration.Provider(
                TileUrlProviderFactory.fromXyzUrlTemplate(templateUrl),
                TilingScheme.QUAD_TREE_MERCATOR,
                storageLevels);

        // If you want to add transparent layers then set this to true.
        rasterProviderConfig.hasAlphaChannel = false;

        // Raster tiles are stored in a separate cache on the device.
        String path = "cache/raster/mycustomlayer";
        long maxDiskSizeInBytes = 1024L * 1024L * 128L; // 128 MB
        RasterDataSourceConfiguration.Cache cacheConfig = new RasterDataSourceConfiguration.Cache(path,
                maxDiskSizeInBytes);

        // Note that this will make the raster source already known to the passed map view.
        return new RasterDataSource(mapView.getMapContext(),
                new RasterDataSourceConfiguration(dataSourceName, rasterProviderConfig, cacheConfig));
    }

    private MapLayer createMapLayer(String dataSourceName) {
        // The layer should be rendered on top of other layers except the layers showing the location indicator and polylines/polygons.
        MapLayerPriority priority = new MapLayerPriorityBuilder()
                .renderedAfterLayer("labels")
                .renderedBeforeLayer("&location_indicator_layer")
                .renderedBeforeLayer("&polyline_layer")
                .build();

        // And it should be visible for all zoom levels. The minimum tilt level is 0 and maximum zoom level is 23.
        MapLayerVisibilityRange range = new MapLayerVisibilityRange(MapCameraLimits.MIN_TILT, MapCameraLimits.MAX_ZOOM_LEVEL);

        try {
            // Build and add the layer to the map. 
            MapLayer mapLayer = new MapLayerBuilder()
                    .forMap(mapView.getHereMap()) // mandatory parameter
                    .withName(dataSourceName + "Layer") // mandatory parameter
                    .withDataSource(dataSourceName, MapContentType.RASTER_IMAGE)
                    .withPriority(priority)
                    .withVisibilityRange(range)
                    .build();
            return mapLayer;
        } catch (MapLayerBuilder.InstantiationException e) {
            throw new RuntimeException("MapLayer creation failed. Cause: " + e);
        }
    }
}
