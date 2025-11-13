package com.here.customrasterlayerskotlin

import android.content.Context
import com.here.sdk.core.Anchor2D
import com.here.sdk.core.GeoCoordinates
import com.here.sdk.mapview.MapCameraLimits
import com.here.sdk.mapview.MapContentType
import com.here.sdk.mapview.MapImageFactory
import com.here.sdk.mapview.MapLayer
import com.here.sdk.mapview.MapLayerBuilder
import com.here.sdk.mapview.MapLayerPriorityBuilder
import com.here.sdk.mapview.MapLayerVisibilityRange
import com.here.sdk.mapview.MapMarker
import com.here.sdk.mapview.MapMeasure
import com.here.sdk.mapview.MapView
import com.here.sdk.mapview.datasource.RasterDataSource
import com.here.sdk.mapview.datasource.RasterDataSourceConfiguration
import com.here.sdk.mapview.datasource.TileUrlProviderFactory
import com.here.sdk.mapview.datasource.TilingScheme

class CustomRasterLayersExample {
    private lateinit var mapView: MapView
    private lateinit var context: Context
    private var rasterMapLayerStyle: MapLayer? = null
    private var rasterDataSourceStyle: RasterDataSource? = null
    private val DEFAULT_DISTANCE_TO_EARTH_IN_METERS = (60 * 1000).toFloat()

    fun onMapSceneLoaded(mapView: MapView, context: Context) {
        this.mapView = mapView
        this.context = context

        val camera = mapView.camera
        val mapMeasureZoom = MapMeasure(
            MapMeasure.Kind.DISTANCE_IN_METERS,
            DEFAULT_DISTANCE_TO_EARTH_IN_METERS.toDouble()
        )
        camera.lookAt(GeoCoordinates(52.530932, 13.384915), mapMeasureZoom)

        val dataSourceName = "myRasterDataSourceStyle"
        rasterDataSourceStyle = createRasterDataSource(dataSourceName)
        rasterMapLayerStyle = createMapLayer(dataSourceName)

        // We want to start with the default map style.
        rasterMapLayerStyle?.setEnabled(false)

        // Add a POI marker
        addPOIMapMarker(GeoCoordinates(52.530932, 13.384915))
    }

    fun enableButtonClicked() {
        rasterMapLayerStyle?.setEnabled(true)
    }

    fun disableButtonClicked() {
        rasterMapLayerStyle?.setEnabled(false)
    }

    private fun createRasterDataSource(dataSourceName: String): RasterDataSource {
        // Note: As an example, below is an URL template of an outdoor layer from thunderforest.com.
        // On their web page you can register a key. Without setting a valid API key, the tiles will
        // show a watermark.
        // More details on the terms of usage can be found here: https://www.thunderforest.com/terms/
        // For example, your application must have working links to https://www.thunderforest.com
        // and https://www.osm.org/copyright.
        // For the below template URL, please pay attention to the following attribution:
        // Maps © www.thunderforest.com, Data © www.osm.org/copyright.
        // Alternatively, choose another tile provider or use the (customizable) map styles provided by HERE.
        val templateUrl = "https://tile.thunderforest.com/outdoors/{z}/{x}/{y}.png"

        // The storage levels available for this data source. Supported range [0, 31].
        val storageLevels: List<Int> =
            mutableListOf(2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16)
        val rasterProviderConfig = RasterDataSourceConfiguration.Provider(
            TileUrlProviderFactory.fromXyzUrlTemplate(templateUrl)!!,
            TilingScheme.QUAD_TREE_MERCATOR,
            storageLevels
        )

        // If you want to add transparent layers then set this to true.
        rasterProviderConfig.hasAlphaChannel = false

        // Raster tiles are stored in a separate cache on the device.
        val path = "cache/raster/mycustomlayer"
        val maxDiskSizeInBytes = (1024 * 1024 * 128).toLong() // 128 MB.
        val cacheConfig = RasterDataSourceConfiguration.Cache(path, maxDiskSizeInBytes)

        // Note that this will make the raster source already known to the passed map view.
        return RasterDataSource(
            mapView.mapContext,
            RasterDataSourceConfiguration(dataSourceName, rasterProviderConfig, cacheConfig)
        )
    }

    private fun createMapLayer(dataSourceName: String): MapLayer {
        // The layer should be rendered on top of other layers including the "labels" layer
        // so that we don't overlap the raster layer over POI markers.
        val priority = MapLayerPriorityBuilder().renderedAfterLayer("labels").build()

        // And it should be visible for all zoom levels. The minimum tilt level is 0 and maximum zoom level is 23.
        val range =
            MapLayerVisibilityRange(MapCameraLimits.MIN_TILT, MapCameraLimits.MAX_ZOOM_LEVEL)

        try {
            // Build and add the layer to the map.
            val mapLayer = MapLayerBuilder()
                .forMap(mapView.hereMap) // mandatory parameter
                .withName(dataSourceName + "Layer") // mandatory parameter
                .withDataSource(dataSourceName, MapContentType.RASTER_IMAGE)
                .withPriority(priority)
                .withVisibilityRange(range)
                .build()
            return mapLayer
        } catch (e: MapLayerBuilder.InstantiationException) {
            throw RuntimeException(e.message)
        }
    }

    fun onDestroy() {
        rasterMapLayerStyle?.destroy()
        rasterDataSourceStyle?.destroy()
    }

    private fun addPOIMapMarker(geoCoordinates: GeoCoordinates) {
        val mapImage = MapImageFactory.fromResource(context.resources, com.here.sdk.units.core.R.drawable.poi)

        // The bottom, middle position should point to the location.
        // By default, the anchor point is set to 0.5, 0.5.
        val anchor2D = Anchor2D(0.5, 1.0)
        val mapMarker = MapMarker(geoCoordinates, mapImage, anchor2D)

        mapView.mapScene.addMapMarker(mapMarker)
    }
}