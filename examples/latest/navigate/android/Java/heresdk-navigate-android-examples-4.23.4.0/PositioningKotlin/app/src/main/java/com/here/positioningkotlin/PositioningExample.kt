/*
* Copyright (C) 2020-2025 HERE Europe B.V.
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

package com.here.positioningkotlin

import android.util.Log
import com.here.sdk.core.GeoCoordinates
import com.here.sdk.core.Location
import com.here.sdk.core.LocationListener
import com.here.sdk.core.errors.InstantiationErrorException
import com.here.sdk.location.LocationAccuracy
import com.here.sdk.location.LocationEngine
import com.here.sdk.location.LocationEngineStatus
import com.here.sdk.location.LocationFeature
import com.here.sdk.location.LocationIssueListener
import com.here.sdk.location.LocationStatusListener
import com.here.sdk.mapview.LocationIndicator
import com.here.sdk.mapview.MapMeasure
import com.here.sdk.mapview.MapView
import java.util.Date

class PositioningExample {
    private val defaultCoordinates = GeoCoordinates(52.520798, 13.409408)

    private var mapView: MapView? = null
    private var locationEngine: LocationEngine
    private var locationIndicator: LocationIndicator

    private val locationListener =
        LocationListener { location: Location ->
            updateMyLocationOnMap(location)
        }

    init {
        try {
            locationEngine = LocationEngine()
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("Initialization failed: " + e.message)
        }

        //Create and setup location indicator.
        locationIndicator = LocationIndicator()
    }

    private val locationStatusListener: LocationStatusListener = object : LocationStatusListener {
        override fun onStatusChanged(locationEngineStatus: LocationEngineStatus) {
            if (locationEngineStatus == LocationEngineStatus.ENGINE_STOPPED) {
                locationEngine.removeLocationListener(locationListener)
                locationEngine.removeLocationStatusListener(this)
            }
        }

        override fun onFeaturesNotAvailable(features: List<LocationFeature>) {
            for (feature in features) {
                Log.d(TAG, "Feature not available: " + feature.name)
            }
        }
    }

    private val locationIssueListener =
        LocationIssueListener { issues ->
            for (issue in issues) {
                Log.d(TAG, "Location issue: " + issue.name)
            }
        }

    fun onMapSceneLoaded(mapView: MapView?) {
        this.mapView = mapView

        val myLastLocation = locationEngine.lastKnownLocation
        if (myLastLocation != null) {
            addMyLocationToMap(myLastLocation)
        } else {
            val defaultLocation = Location(defaultCoordinates)
            defaultLocation.time = Date()
            addMyLocationToMap(defaultLocation)
        }

        startLocating()
    }

    private fun startLocating() {
        locationEngine.addLocationStatusListener(locationStatusListener)
        locationEngine.addLocationIssueListener(locationIssueListener)
        locationEngine.addLocationListener(locationListener)
        // By calling confirmHEREPrivacyNoticeInclusion() you confirm that this app informs on
        // data collection, which is done for this app via PositioningTermsAndPrivacyHelper,
        // which shows a possible example for this.
        locationEngine.confirmHEREPrivacyNoticeInclusion()
        locationEngine.start(LocationAccuracy.BEST_AVAILABLE)
    }

    fun stopLocating() {
        locationEngine.removeLocationIssueListener(locationIssueListener)
        locationEngine.stop()
    }

    private fun addMyLocationToMap(myLocation: Location) {
        // Enable a halo to indicate the horizontal accuracy.
        locationIndicator.isAccuracyVisualized = true
        locationIndicator.locationIndicatorStyle = LocationIndicator.IndicatorStyle.PEDESTRIAN
        locationIndicator.updateLocation(myLocation)
        locationIndicator.enable(mapView!!)

        //Update the map viewport to be centered on the location.
        val mapMeasureZoom =
            MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, CAMERA_DISTANCE_IN_METERS.toDouble())
        mapView!!.camera.lookAt(myLocation.coordinates, mapMeasureZoom)
    }

    private fun updateMyLocationOnMap(myLocation: Location) {
        //Update the location indicator's location.
        locationIndicator.updateLocation(myLocation)
        //Update the map viewport to be centered on the location, preserving zoom level.
        mapView!!.camera.lookAt(myLocation.coordinates)
    }

    companion object {
        private val TAG: String = PositioningExample::class.java.simpleName
        private const val CAMERA_DISTANCE_IN_METERS = 200
    }
}