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
package com.here.mapitemskotlin

import android.app.AlertDialog
import android.content.Context
import android.util.Log
import android.widget.Toast
import com.here.sdk.core.Anchor2D
import com.here.sdk.core.Color
import com.here.sdk.core.GeoCoordinates
import com.here.sdk.core.GeoOrientationUpdate
import com.here.sdk.core.Location
import com.here.sdk.core.Metadata
import com.here.sdk.core.Point2D
import com.here.sdk.core.Rectangle2D
import com.here.sdk.core.Size2D
import com.here.sdk.gestures.TapListener
import com.here.sdk.mapview.AssetsManager
import com.here.sdk.mapview.LocationIndicator
import com.here.sdk.mapview.MapImageFactory
import com.here.sdk.mapview.MapMarker
import com.here.sdk.mapview.MapMarker3D
import com.here.sdk.mapview.MapMarker3DModel
import com.here.sdk.mapview.MapMarkerCluster
import com.here.sdk.mapview.MapScene
import com.here.sdk.mapview.MapView
import com.here.sdk.mapview.MapViewBase
import com.here.sdk.mapview.PickMapItemsResult
import com.here.sdk.mapview.RenderSize
import com.here.time.Duration
import java.io.IOException
import java.util.Date

class MapItemsExample(private val context: Context, private val mapView: MapView) {

    private val mapMarkerList = arrayListOf<MapMarker>()
    private val mapMarker3DList = arrayListOf<MapMarker3D>()
    private val mapMarkerClusterList = arrayListOf<MapMarkerCluster>()
    private val locationIndicatorList = arrayListOf<LocationIndicator>()

    init {
        // Setting a tap handler to pick markers from map.
        setTapGestureHandler();

        Toast.makeText(context, "You can tap 2D markers.", Toast.LENGTH_LONG).show()

        registerCustomFont()
    }

    private fun registerCustomFont() {
        // Register a custom font from the assets folder.
        // Place the font file in the "assets" directory.
        // Full path example: app/src/main/assets/SignTextNarrow_Bold.ttf
        // Adjust file name and path as appropriate for your project.
        val fontFileName = "SignTextNarrow_Bold.ttf"

        // Make custom font assets available for use with MapImage.TextStyle.
        // "SignTextNarrow_Bold" is the font name which needs to be referenced when
        // creating a MapMarker, as shown in this example below.
        // Supported font formats can be found in the API Reference.
        // Use the asset folder or specify an absolute file path.
        // You can register multiple fonts with different names. Repeated registration with the same font name is ignored.
        val assetManager = AssetsManager(mapView.mapContext)
        assetManager.registerFont("SignTextNarrow_Bold", fontFileName)
    }

    fun showAnchoredMapMarkers() {
        unTiltMap()

        for (i in 0..9) {
            val geoCoordinates: GeoCoordinates = createRandomGeoCoordinatesAroundMapCenter()

            // Centered on location. Shown below the POI image to indicate the location.
            // The draw order is determined from what is first added to the map.
            addCircleMapMarker(geoCoordinates)

            // Anchored, pointing to location.
            addPOIMapMarker(geoCoordinates)
        }
    }

    fun showCenteredMapMarkers() {
        unTiltMap()

        val geoCoordinates: GeoCoordinates = createRandomGeoCoordinatesAroundMapCenter()

        // Centered on location.
        addPhotoMapMarker(geoCoordinates)

        // Centered on location. Shown above the photo marker to indicate the location.
        // The draw order is determined from what is first added to the map.
        addCircleMapMarker(geoCoordinates)
    }

    fun showMapMarkerWithText() {
        val mapImage = MapImageFactory.fromResource(context.resources, R.drawable.poi)

        // The bottom, middle position should point to the location.
        // By default, the anchor point is set to 0.5, 0.5.
        val anchor2D = Anchor2D(0.5, 1.0)
        val geoCoordinates: GeoCoordinates = createRandomGeoCoordinatesAroundMapCenter()
        val mapMarker = MapMarker(geoCoordinates, mapImage, anchor2D)

        val textStyleCurrent = mapMarker.textStyle
        var textStyleNew = mapMarker.textStyle
        val textSizeInPixels = 30.0
        val textOutlineSizeInPixels = 5.0
        // Placement priority is based on order. It is only effective when
        // overlap is disallowed. The below setting will show the text
        // at the bottom of the marker, but when the marker or the text overlaps
        // then the text will swap to the top before the marker disappears completely.
        // Note: By default, markers do not disappear when they overlap.
        val placements: MutableList<MapMarker.TextStyle.Placement> = ArrayList()
        placements.add(MapMarker.TextStyle.Placement.BOTTOM)
        placements.add(MapMarker.TextStyle.Placement.TOP)
        mapMarker.isOverlapAllowed = false
        try {
            textStyleNew = MapMarker.TextStyle(
                textSizeInPixels,
                textStyleCurrent.textColor,
                textOutlineSizeInPixels,
                textStyleCurrent.textOutlineColor,
                placements,
                // The font name as registered via assetsManager.registerFont above. If an empty string is provided or the asses is not found, a default font will be used.
                "SignTextNarrow_Bold"
            )
        } catch (e: MapMarker.TextStyle.InstantiationException) {
            // An error code will indicate what went wrong, for example, when negative values are set for text size.
            Log.e("TextStyle", "Error code: " + e.error.name)
        }
        mapMarker.text = "Hello Text"
        mapMarker.textStyle = textStyleNew!!

        val metadata = Metadata()
        metadata.setString("key_poi_text", "This is a POI with text.")
        mapMarker.setMetadata(metadata)

        mapView.mapScene.addMapMarker(mapMarker)
        mapMarkerList.add(mapMarker)
    }

    fun showMapMarkerCluster() {
        val clusterMapImage = MapImageFactory.fromResource(context.resources, R.drawable.green_square)

        // Defines a text that indicates how many markers are included in the cluster.
        val counterStyle = MapMarkerCluster.CounterStyle()
        counterStyle.textColor = Color(0f, 0f, 0f, 1f) // Black
        counterStyle.fontSize = 40.0
        counterStyle.maxCountNumber = 9
        counterStyle.aboveMaxText = "+9"

        val mapMarkerCluster = MapMarkerCluster(
            MapMarkerCluster.ImageStyle(clusterMapImage), counterStyle
        )
        mapView.mapScene.addMapMarkerCluster(mapMarkerCluster)
        mapMarkerClusterList.add(mapMarkerCluster)

        for (i in 0..9) {
            mapMarkerCluster.addMapMarker(createRandomMapMarkerInViewport("" + i))
        }
    }

    private fun createRandomMapMarkerInViewport(metaDataText: String): MapMarker {
        val geoCoordinates = createRandomGeoCoordinatesAroundMapCenter()
        val mapImage = MapImageFactory.fromResource(context.resources, R.drawable.green_square)

        val mapMarker = MapMarker(geoCoordinates, mapImage)

        val metadata = Metadata()
        metadata.setString("key_cluster", metaDataText)
        mapMarker.setMetadata(metadata)

        return mapMarker
    }

    fun showLocationIndicatorPedestrian() {
        unTiltMap()

        val geoCoordinates = createRandomGeoCoordinatesAroundMapCenter()

        // Centered on location.
        addLocationIndicator(geoCoordinates, LocationIndicator.IndicatorStyle.PEDESTRIAN)
    }

    fun showLocationIndicatorNavigation() {
        unTiltMap()

        val geoCoordinates = createRandomGeoCoordinatesAroundMapCenter()

        // Centered on location.
        addLocationIndicator(geoCoordinates, LocationIndicator.IndicatorStyle.NAVIGATION)
    }

    fun show2DTexture() {
        // Tilt the map for a better 3D effect.
        tiltMap()

        val geoCoordinates = createRandomGeoCoordinatesAroundMapCenter()

        // Adds a flat POI marker that rotates and tilts together with the map.
        add2DTexture(geoCoordinates)

        // A centered 2D map marker to indicate the exact location.
        // Note that 3D map markers are always drawn on top of 2D map markers.
        addCircleMapMarker(geoCoordinates)
    }

    fun showMapMarker3D() {
        // Tilt the map for a better 3D effect.
        tiltMap()

        val geoCoordinates = createRandomGeoCoordinatesAroundMapCenter()

        // Adds a textured 3D model.
        // It's origin is centered on the location.
        addMapMarker3D(geoCoordinates)
    }

    fun showFlatMapMarker() {
        // Tilt the map for a better 3D effect.
        tiltMap()

        val geoCoordinates = createRandomGeoCoordinatesAroundMapCenter()

        // It's origin is centered on the location.
        addFlatMarker(geoCoordinates)

        // A centered 2D map marker to indicate the exact location.
        addCircleMapMarker(geoCoordinates)
    }

    fun clearMap() {
        mapView.mapScene.removeMapMarkers(mapMarkerList)
        mapMarkerList.clear()

        for (mapMarker3D in mapMarker3DList) {
            mapView.mapScene.removeMapMarker3d(mapMarker3D!!)
        }
        mapMarker3DList.clear()

        for (locationIndicator in locationIndicatorList) {
            // Remove locationIndicator from map view.
            locationIndicator.disable()
        }
        locationIndicatorList.clear()

        for (mapMarkerCluster in mapMarkerClusterList) {
            mapView.mapScene.removeMapMarkerCluster(mapMarkerCluster!!)
        }
        mapMarkerClusterList.clear()
    }

    private fun addPOIMapMarker(geoCoordinates: GeoCoordinates) {
        val mapImage = MapImageFactory.fromResource(context.resources, R.drawable.poi)

        // The bottom, middle position should point to the location.
        // By default, the anchor point is set to 0.5, 0.5.
        val anchor2D = Anchor2D(0.5, 1.0)
        val mapMarker = MapMarker(geoCoordinates, mapImage, anchor2D)

        val metadata = Metadata()
        metadata.setString("key_poi", "This is a POI.")
        mapMarker.setMetadata(metadata)

        mapView.mapScene.addMapMarker(mapMarker)
        mapMarkerList.add(mapMarker)
    }

    private fun addPhotoMapMarker(geoCoordinates: GeoCoordinates) {
        val mapImage = MapImageFactory.fromResource(context.resources, R.drawable.here_car)
        val mapMarker = MapMarker(geoCoordinates, mapImage)

        mapView.mapScene.addMapMarker(mapMarker)
        mapMarkerList.add(mapMarker)
    }

    private fun addCircleMapMarker(geoCoordinates: GeoCoordinates) {
        val mapImage = MapImageFactory.fromResource(context.resources, R.drawable.circle)
        val mapMarker = MapMarker(geoCoordinates, mapImage)

        // Optionally, enable a fade in-out animation.
        mapMarker.fadeDuration = Duration.ofSeconds(3)

        mapView.mapScene.addMapMarker(mapMarker)
        mapMarkerList.add(mapMarker)
    }

    private fun addLocationIndicator(
        geoCoordinates: GeoCoordinates,
        indicatorStyle: LocationIndicator.IndicatorStyle
    ) {
        val locationIndicator = LocationIndicator()
        locationIndicator.locationIndicatorStyle = indicatorStyle

        // A LocationIndicator is intended to mark the user's current location,
        // including a bearing direction.
        val location: Location = Location(geoCoordinates)
        location.time = Date()
        location.bearingInDegrees = getRandom(0.0, 360.0)

        locationIndicator.updateLocation(location)

        // Show the indicator on the map view.
        locationIndicator.enable(mapView)

        locationIndicatorList.add(locationIndicator)
    }

    // A location indicator can be switched to a gray state, for example, to indicate a weak GPS signal.
    fun toggleActiveStateForLocationIndicator() {
        for (locationIndicator in locationIndicatorList) {
            val isActive = locationIndicator.isActive
            // Toggle between active / inactive state.
            locationIndicator.isActive = !isActive
        }
    }

    private fun add2DTexture(geoCoordinates: GeoCoordinates) {
        // Place the files in the "assets" directory.
        // Full path example: app/src/main/assets/plane.obj
        // Adjust file name and path as appropriate for your project.
        // Note: The bottom of the plane is centered on the origin.
        val geometryFile = "plane.obj"

        // The POI texture is a square, so we can easily wrap it onto the 2 x 2 plane model.
        val textureFile = "poi_texture.png"
        checkIfFileExistsInAssetsFolder(geometryFile)
        checkIfFileExistsInAssetsFolder(textureFile)

        val mapMarker3DModel = MapMarker3DModel(geometryFile, textureFile)
        val mapMarker3D = MapMarker3D(geoCoordinates, mapMarker3DModel)
        // Scale marker. Note that we used a normalized length of 2 units in 3D space.
        mapMarker3D.scale = 60.0

        mapView.mapScene.addMapMarker3d(mapMarker3D)
        mapMarker3DList.add(mapMarker3D)
    }

    private fun addFlatMarker(geoCoordinates: GeoCoordinates) {
        val mapImage = MapImageFactory.fromResource(context.resources, R.drawable.poi)

        // The default scale factor of the map marker is 1.0. For a scale of 2, the map marker becomes 2x larger.
        // For a scale of 0.5, the map marker shrinks to half of its original size.
        val scaleFactor = 0.5

        // With DENSITY_INDEPENDENT_PIXELS the map marker will have a constant size on the screen regardless if the map is zoomed in or out.
        val mapMarker3D = MapMarker3D(geoCoordinates, mapImage, scaleFactor, RenderSize.Unit.DENSITY_INDEPENDENT_PIXELS)

        mapView.mapScene.addMapMarker3d(mapMarker3D)
        mapMarker3DList.add(mapMarker3D)
    }

    private fun addMapMarker3D(geoCoordinates: GeoCoordinates) {
        // Place the files in the "assets" directory.
        // Full path example: app/src/main/assets/obstacle.obj
        // Adjust file name and path as appropriate for your project.
        val geometryFile = "obstacle.obj"
        val textureFile = "obstacle_texture.png"
        checkIfFileExistsInAssetsFolder(geometryFile)
        checkIfFileExistsInAssetsFolder(textureFile)

        // Without depth check, 3D models are rendered on top of everything. With depth check enabled,
        // it may be hidden by buildings. In addition:
        // If a 3D object has its center at the origin of its internal coordinate system,
        // then parts of it may be rendered below the ground surface (altitude < 0).
        // Note that the HERE SDK map surface is flat, following a Mercator or Globe projection.
        // Therefore, a 3D object becomes visible when the altitude of its location is 0 or higher.
        // By default, without setting a scale factor, 1 unit in 3D coordinate space equals 1 meter.
        val altitude = 18.0
        val geoCoordinatesWithAltitude = GeoCoordinates(geoCoordinates.latitude, geoCoordinates.longitude, altitude)

        val mapMarker3DModel = MapMarker3DModel(geometryFile, textureFile)
        val mapMarker3D = MapMarker3D(geoCoordinatesWithAltitude, mapMarker3DModel)
        mapMarker3D.scale = 6.0
        mapMarker3D.isDepthCheckEnabled = true

        mapView.mapScene.addMapMarker3d(mapMarker3D)
        mapMarker3DList.add(mapMarker3D)
    }

    private fun checkIfFileExistsInAssetsFolder(fileName: String) {
        val assetManager = context.assets
        try {
            assetManager.open(fileName)
        } catch (e: IOException) {
            Log.e("MapItemsExample", "Error: File not found!")
        }
    }

    private fun createRandomGeoCoordinatesAroundMapCenter(): GeoCoordinates {
        val centerGeoCoordinates = mapView.camera.state.targetCoordinates
        val lat = centerGeoCoordinates.latitude
        val lon = centerGeoCoordinates.longitude
        return GeoCoordinates(
            getRandom(lat - 0.02, lat + 0.02),
            getRandom(lon - 0.02, lon + 0.02)
        )
    }

    private fun getRandom(min: Double, max: Double): Double {
        return min + Math.random() * (max - min)
    }

    private fun setTapGestureHandler() {
        mapView.gestures.tapListener = TapListener { touchPoint -> pickMapMarker(touchPoint) }
    }

    private fun pickMapMarker(touchPoint: Point2D) {
        val originInPixels = Point2D(touchPoint.x, touchPoint.y)
        val sizeInPixels = Size2D(1.0, 1.0)
        val rectangle = Rectangle2D(originInPixels, sizeInPixels)

        // Creates a list of map content type from which the results will be picked.
        // The content type values can be MAP_CONTENT, MAP_ITEMS and CUSTOM_LAYER_DATA.
        val contentTypesToPickFrom = ArrayList<MapScene.MapPickFilter.ContentType>()

        // MAP_CONTENT is used when picking embedded carto POIs, traffic incidents, vehicle restriction etc.
        // MAP_ITEMS is used when picking map items such as MapMarker, MapPolyline, MapPolygon etc.
        // Currently we need map markers so adding the MAP_ITEMS filter.
        contentTypesToPickFrom.add(MapScene.MapPickFilter.ContentType.MAP_ITEMS)
        val filter = MapScene.MapPickFilter(contentTypesToPickFrom)

        // If you do not want to specify any filter you can pass filter as NULL and all of the pickable contents will be picked.
        mapView.pick(filter, rectangle, MapViewBase.MapPickCallback { mapPickResult ->
            if (mapPickResult == null) {
                // An error occurred while performing the pick operation.
                return@MapPickCallback
            }
            val pickMapItemsResult = mapPickResult.mapItems

            // Note that MapMarker items contained in a cluster are not part of pickMapItemsResult.getMarkers().
            handlePickedMapMarkerClusters(pickMapItemsResult)

            // Note that 3D map markers can't be picked yet. Only marker, polygon and polyline map items are pickable.
            val mapMarkerList = pickMapItemsResult!!.markers
            val listSize = mapMarkerList.size
            if (listSize == 0) {
                return@MapPickCallback
            }
            val topmostMapMarker = mapMarkerList[0]

            val metadata: Metadata? = topmostMapMarker.metadata
            if (metadata != null) {
                var message: String? = "No message found."
                val string: String? = metadata.getString("key_poi")
                if (string != null) {
                    message = string
                }

                val stringMarkerText: String? = metadata.getString("key_poi_text")
                if (stringMarkerText != null) {
                    // You can update text for a marker on-the-fly.
                    topmostMapMarker.text = "Marker was picked."
                    message = stringMarkerText
                }

                if (message != null) {
                    showDialog("Map marker picked", message)
                }
                return@MapPickCallback
            }
            showDialog(
                "Map marker picked:", "Location: " +
                        topmostMapMarker.coordinates.latitude + ", " +
                        topmostMapMarker.coordinates.longitude
            )
        })
    }

    private fun handlePickedMapMarkerClusters(pickMapItemsResult: PickMapItemsResult?) {
        val groupingList = pickMapItemsResult!!.clusteredMarkers
        if (groupingList.size == 0) {
            return
        }

        val topmostGrouping = groupingList[0]
        val clusterSize = topmostGrouping.markers.size
        if (clusterSize == 0) {
            // This cluster does not contain any MapMarker items.
            return
        }
        if (clusterSize == 1) {
            showDialog(
                "Map marker picked",
                "This MapMarker belongs to a cluster. Metadata: " + getClusterMetadata(topmostGrouping.markers[0])
            )
        } else {
            var metadata = ""
            for (mapMarker in topmostGrouping.markers) {
                metadata += getClusterMetadata(mapMarker)
                metadata += " "
            }
            showDialog(
                "Map marker cluster picked",
                "Number of contained markers in this cluster: " + clusterSize + ". " +
                        "Contained Metadata: " + metadata + ". " +
                        "Total number of markers in this MapMarkerCluster: " + topmostGrouping.parent.markers.size
            )
        }
    }

    private fun getClusterMetadata(mapMarker: MapMarker): String {
        val metadata: Metadata? = mapMarker.metadata
        var message = "No metadata."
        if (metadata != null) {
            val string: String? = metadata.getString("key_cluster")
            if (string != null) {
                message = string
            }
        }
        return message
    }

    private fun tiltMap() {
        val bearing = mapView.camera.state.orientationAtTarget.bearing
        val tilt = 60.0
        mapView.camera.setOrientationAtTarget(GeoOrientationUpdate(bearing, tilt))
    }

    private fun unTiltMap() {
        val bearing = mapView.camera.state.orientationAtTarget.bearing
        val tilt = 0.0
        mapView.camera.setOrientationAtTarget(GeoOrientationUpdate(bearing, tilt))
    }

    private fun showDialog(title: String, message: String) {
        val builder: AlertDialog.Builder = AlertDialog.Builder(context)
        builder.setTitle(title)
        builder.setMessage(message)
        builder.show()
    }

    companion object {
        private val TAG: String = MapItemsExample::class.java.name
    }
}