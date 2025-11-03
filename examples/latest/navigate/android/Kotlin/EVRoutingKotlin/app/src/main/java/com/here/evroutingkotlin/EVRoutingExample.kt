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

package com.here.evroutingkotlin

import android.app.AlertDialog
import android.content.Context
import android.util.Log
import com.here.sdk.core.Color
import com.here.sdk.core.GeoCoordinates
import com.here.sdk.core.GeoCorridor
import com.here.sdk.core.LanguageCode
import com.here.sdk.core.Metadata
import com.here.sdk.core.Point2D
import com.here.sdk.core.Rectangle2D
import com.here.sdk.core.Size2D
import com.here.sdk.core.errors.InstantiationErrorException
import com.here.sdk.gestures.TapListener
import com.here.sdk.mapview.LineCap
import com.here.sdk.mapview.MapImageFactory
import com.here.sdk.mapview.MapMarker
import com.here.sdk.mapview.MapMeasure
import com.here.sdk.mapview.MapMeasureDependentRenderSize
import com.here.sdk.mapview.MapPolygon
import com.here.sdk.mapview.MapPolyline
import com.here.sdk.mapview.MapPolyline.SolidRepresentation
import com.here.sdk.mapview.MapScene.MapPickFilter
import com.here.sdk.mapview.MapView
import com.here.sdk.mapview.MapViewBase.MapPickCallback
import com.here.sdk.mapview.RenderSize
import com.here.sdk.routing.AvoidanceOptions
import com.here.sdk.routing.CalculateIsolineCallback
import com.here.sdk.routing.CalculateRouteCallback
import com.here.sdk.routing.ChargingConnectorType
import com.here.sdk.routing.ChargingStop
import com.here.sdk.routing.ChargingSupplyType
import com.here.sdk.routing.EVCarOptions
import com.here.sdk.routing.EVMobilityServiceProviderPreferences
import com.here.sdk.routing.IsolineCalculationMode
import com.here.sdk.routing.IsolineOptions
import com.here.sdk.routing.IsolineOptions.Calculation
import com.here.sdk.routing.IsolineRangeType
import com.here.sdk.routing.IsolineRoutingEngine
import com.here.sdk.routing.OptimizationMode
import com.here.sdk.routing.PostActionType
import com.here.sdk.routing.Route
import com.here.sdk.routing.RoutingEngine
import com.here.sdk.routing.Waypoint
import com.here.sdk.search.CategoryQuery
import com.here.sdk.search.Details
import com.here.sdk.search.PlaceCategory
import com.here.sdk.search.SearchCallback
import com.here.sdk.search.SearchEngine
import com.here.sdk.search.SearchOptions
import com.here.time.Duration

// This example shows how to calculate routes for electric vehicles that contain necessary charging stations
// (indicated with red charging icon). In addition, all existing charging stations are searched along the route
// (indicated with green charging icon). You can also visualize the reachable area from your starting point
// (isoline routing).
class EVRoutingExample(private val context: Context, private val mapView: MapView) {
    private val mapMarkers: MutableList<MapMarker> = ArrayList()
    private val mapPolylines: MutableList<MapPolyline> = ArrayList()
    private val mapPolygons: MutableList<MapPolygon> = ArrayList()
    private var routingEngine: RoutingEngine
    private var searchEngine: SearchEngine
    private var startGeoCoordinates: GeoCoordinates? = null
    private var destinationGeoCoordinates: GeoCoordinates? = null
    private val chargingStationsIDs: MutableList<String?> = ArrayList()
    private var isolineRoutingEngine: IsolineRoutingEngine

    // Metadata keys used when picking a charging station on the map.
    private val SUPPLIER_NAME_METADATA_KEY = "supplier_name"
    private val CONNECTOR_COUNT_METADATA_KEY = "connector_count"
    private val AVAILABLE_CONNECTORS_METADATA_KEY = "available_connectors"
    private val OCCUPIED_CONNECTORS_METADATA_KEY = "occupied_connectors"
    private val OUT_OF_SERVICE_CONNECTORS_METADATA_KEY = "out_of_service_connectors"
    private val RESERVED_CONNECTORS_METADATA_KEY = "reserved_connectors"
    private val LAST_UPDATED_METADATA_KEY = "last_updated"
    private val REQUIRED_CHARGING_METADATA_KEY = "required_charging"

    init {
        val camera = mapView.camera
        val distanceInMeters = (1000 * 10).toDouble()
        val mapMeasureZoom = MapMeasure(MapMeasure.Kind.DISTANCE_IN_METERS, distanceInMeters)
        camera.lookAt(GeoCoordinates(52.520798, 13.409408), mapMeasureZoom)

        try {
            routingEngine = RoutingEngine()
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("Initialization of RoutingEngine failed: " + e.error.name)
        }

        try {
            // Use the IsolineRoutingEngine to calculate a reachable area from a center point.
            // The calculation is done asynchronously and requires an online connection.
            isolineRoutingEngine = IsolineRoutingEngine()
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("Initialization of IsolineRoutingEngine failed: " + e.error.name)
        }

        try {
            // Add search engine to search for places along a route.
            searchEngine = SearchEngine()
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("Initialization of SearchEngine failed: " + e.error.name)
        }

        setTapGestureHandler()
    }

    // Calculates an EV car route based on random start / destination coordinates near viewport center.
    // Includes a user waypoint to add an intermediate charging stop along the route,
    // in addition to charging stops that are added by the engine.
    fun addEVRouteButtonClicked() {
        chargingStationsIDs.clear()

        startGeoCoordinates = createRandomGeoCoordinatesInViewport()
        destinationGeoCoordinates = createRandomGeoCoordinatesInViewport()
        val startWaypoint = Waypoint(startGeoCoordinates!!)
        val destinationWaypoint = Waypoint(destinationGeoCoordinates!!)
        val plannedChargingStopWaypoint = createUserPlannedChargingStopWaypoint()
        val waypoints: List<Waypoint> = listOf(
            startWaypoint,
            plannedChargingStopWaypoint,
            destinationWaypoint
        )

        routingEngine.calculateRoute(
            waypoints, eVCarOptions,
            CalculateRouteCallback { routingError, list ->
                if (routingError != null) {
                    showDialog("Error while calculating a route: ", routingError.toString())
                    return@CalculateRouteCallback
                }
                // When routingError is nil, routes is guaranteed to contain at least one route.
                val route = list!![0]
                showRouteOnMap(route)
                logRouteViolations(route)
                logEVDetails(route)
                searchAlongARoute(route)
            }
        )
    }

    // Simulate a user planned stop based on random coordinates.
    private fun createUserPlannedChargingStopWaypoint(): Waypoint {
        // The rated power of the connector, in kilowatts (kW).
        val powerInKilowatts = 350.0

        // The rated current of the connector, in amperes (A).
        val currentInAmperes = 350.0

        // The rated voltage of the connector, in volts (V).
        val voltageInVolts = 1000.0

        // The minimum duration (in seconds) the user plans to charge at the station.
        val minimumDuration = Duration.ofSeconds(3000)

        // The maximum duration (in seconds) the user plans to charge at the station.
        val maximumDuration = Duration.ofSeconds(4000)

        // Add a user-defined charging stop.
        //
        // Note: To specify a ChargingStop, you must also set totalCapacityInKilowattHours,
        // initialChargeInKilowattHours, and chargingCurve using BatterySpecification in EVCarOptions.
        // If any of these values are missing, the route calculation will fail with an invalid parameter error.
        val plannedChargingStop = ChargingStop(
            powerInKilowatts,
            currentInAmperes,
            voltageInVolts,
            ChargingSupplyType.DC,
            minimumDuration,
            maximumDuration
        )

        val plannedChargingStopWaypoint = Waypoint(createRandomGeoCoordinatesInViewport())
        plannedChargingStopWaypoint.chargingStop = plannedChargingStop
        return plannedChargingStopWaypoint
    }

    private fun applyEMSPPreferences(evCarOptions: EVCarOptions) {
        // You can get a list of all E-Mobility Service Providers and their partner IDs by using the request described here:
        // https://www.here.com/docs/bundle/ev-charge-points-api-developer-guide/page/topics/example-charging-station.html.
        // No more than 10 E-Mobility Service Providers should be specified.
        // The RoutingEngine will follow the priority order you specify when calculating routes, so try to specify at least most preferred providers.
        // Note that this may impact the route geometry.

        // Most preferred provider for route calculation: As an example, we use "Jaguar Charging" referenced by the partner ID taken from above link.

        val preferredProviders = listOf("3379b852-cca5-11ed-8856-42010aa40002")

        // Example code for a least preferred provider.
        val leastPreferredProviders = listOf("12345678-abcd-0000-0000-000000000000")

        // Alternative provider for route calculation to be used only when no better options are available.
        // Example code for an alternative provider.
        val alternativeProviders = listOf("12345678-0000-abcd-0000-000123456789")

        evCarOptions.evMobilityServiceProviderPreferences = EVMobilityServiceProviderPreferences()
        evCarOptions.evMobilityServiceProviderPreferences.high = preferredProviders
        evCarOptions.evMobilityServiceProviderPreferences.low = leastPreferredProviders
        evCarOptions.evMobilityServiceProviderPreferences.medium = alternativeProviders
    }

    private val eVCarOptions: EVCarOptions
        get() {
            val evCarOptions = EVCarOptions()

            // The below three options are the minimum you must specify or routing will result in an error.
            evCarOptions.consumptionModel.ascentConsumptionInWattHoursPerMeter = 9.0
            evCarOptions.consumptionModel.descentRecoveryInWattHoursPerMeter = 4.3
            evCarOptions.consumptionModel.freeFlowSpeedTable = object : HashMap<Int?, Double?>() {
                init {
                    put(0, 0.239)
                    put(27, 0.239)
                    put(60, 0.196)
                    put(90, 0.238)
                }
            }

            // Must be 0 for isoline calculation.
            evCarOptions.routeOptions.alternatives = 0

            // Ensure that the vehicle does not run out of energy along the way
            // and charging stations are added as additional waypoints.
            evCarOptions.ensureReachability = true

            // The below options are required when setting the ensureReachability option to true
            // (AvoidanceOptions need to be empty).
            evCarOptions.avoidanceOptions = AvoidanceOptions()
            evCarOptions.routeOptions.speedCapInMetersPerSecond = null
            evCarOptions.routeOptions.optimizationMode = OptimizationMode.FASTEST
            evCarOptions.batterySpecifications.connectorTypes =
                listOf(
                    ChargingConnectorType.TESLA,
                    ChargingConnectorType.IEC_62196_TYPE_1_COMBO,
                    ChargingConnectorType.IEC_62196_TYPE_2_COMBO
                )
            evCarOptions.batterySpecifications.totalCapacityInKilowattHours = 80.0
            evCarOptions.batterySpecifications.initialChargeInKilowattHours = 10.0
            evCarOptions.batterySpecifications.targetChargeInKilowattHours = 72.0
            evCarOptions.batterySpecifications.chargingCurve =
                object : HashMap<Double?, Double?>() {
                    init {
                        put(0.0, 239.0)
                        put(64.0, 111.0)
                        put(72.0, 1.0)
                    }
                }

            // Apply EV mobility service provider preferences (eMSP).
            applyEMSPPreferences(evCarOptions)

            // Note: More EV options are available, the above shows only the minimum viable options.
            return evCarOptions
        }

    private fun logEVDetails(route: Route) {
        // Find inserted charging stations that are required for this route.
        // Note that this example assumes only one start waypoint and one destination waypoint.
        // By default, each route has one section.
        val additionalSectionCount = route.sections.size - 1
        if (additionalSectionCount > 0) {
            // Each additional waypoint splits the route into two sections.
            Log.d(
                "EVDetails",
                "Number of required stops at charging stations: $additionalSectionCount"
            )
        } else {
            Log.d(
                "EVDetails",
                "Based on the provided options, the destination can be reached without a stop at a charging station."
            )
        }

        var sectionIndex = 0
        val sections = route.sections
        for (section in sections) {
            Log.d(
                "EVDetails",
                "Estimated net energy consumption in kWh for this section: " + section.consumptionInKilowattHours
            )
            for (postAction in section.postActions) {
                when (postAction.action) {
                    PostActionType.CHARGING_SETUP -> Log.d(
                        "EVDetails",
                        "At the end of this section you need to setup charging for " + postAction.duration.seconds + " s."
                    )

                    PostActionType.CHARGING -> Log.d(
                        "EVDetails",
                        "At the end of this section you need to charge for " + postAction.duration.seconds + " s."
                    )

                    PostActionType.WAIT -> Log.d(
                        "EVDetails",
                        "At the end of this section you need to wait for " + postAction.duration.seconds + " s."
                    )

                    else -> throw RuntimeException("Unknown post action type.")
                }
            }

            Log.d(
                "EVDetails",
                "Section " + sectionIndex + ": Estimated battery charge in kWh when leaving the departure place: " + section.departurePlace.chargeInKilowattHours
            )
            Log.d(
                "EVDetails",
                "Section " + sectionIndex + ": Estimated battery charge in kWh when leaving the arrival place: " + section.arrivalPlace.chargeInKilowattHours
            )

            // Only charging stations that are needed to reach the destination are listed below.
            val depStation = section.departurePlace.chargingStation
            if (depStation?.id != null && !chargingStationsIDs.contains(depStation.id)) {
                Log.d(
                    "EVDetails",
                    "Section " + sectionIndex + ", name of charging station: " + depStation.name
                )
                chargingStationsIDs.add(depStation.id)
                val metadata = Metadata()
                metadata.setString(REQUIRED_CHARGING_METADATA_KEY, depStation.id!!)
                metadata.setString(SUPPLIER_NAME_METADATA_KEY, depStation.name!!)
                addMapMarker(
                    section.departurePlace.mapMatchedCoordinates,
                    R.drawable.required_charging,
                    metadata
                )
            }


            val arrStation = section.departurePlace.chargingStation
            if (arrStation?.id != null && !chargingStationsIDs.contains(arrStation.id)) {
                Log.d(
                    "EVDetails",
                    "Section " + sectionIndex + ", name of charging station: " + arrStation.name
                )
                chargingStationsIDs.add(arrStation.id)
                val metadata = Metadata()
                metadata.setString(REQUIRED_CHARGING_METADATA_KEY, arrStation.id!!)
                metadata.setString(SUPPLIER_NAME_METADATA_KEY, depStation!!.name!!)
                addMapMarker(
                    section.arrivalPlace.mapMatchedCoordinates,
                    R.drawable.required_charging,
                    metadata
                )
            }

            sectionIndex += 1
        }
    }

    // A route may contain several warnings, for example, when a certain route option could not be fulfilled.
    // An implementation may decide to reject a route if one or more violations are detected.
    private fun logRouteViolations(route: Route) {
        val sections = route.sections
        for (section in sections) {
            for (notice in section.sectionNotices) {
                Log.d(
                    "RouteViolations",
                    "This route contains the following warning: " + notice.code
                )
            }
        }
    }

    private fun showRouteOnMap(route: Route) {
        clearMap()

        // Show route as polyline.
        val routeGeoPolyline = route.geometry
        val widthInPixels = 20f
        val polylineColor = Color.valueOf(0f, 0.56f, 0.54f, 0.63f)
        var routeMapPolyline: MapPolyline? = null // RGBA
        try {
            routeMapPolyline = MapPolyline(
                routeGeoPolyline, SolidRepresentation(
                    MapMeasureDependentRenderSize(RenderSize.Unit.PIXELS, widthInPixels.toDouble()),
                    polylineColor,
                    LineCap.ROUND
                )
            )
        } catch (e: MapPolyline.Representation.InstantiationException) {
            Log.e("MapPolyline Representation Exception:", e.error.name)
        } catch (e: MapMeasureDependentRenderSize.InstantiationException) {
            Log.e("MapMeasureDependentRenderSize Exception:", e.error.name)
        }

        mapView.mapScene.addMapPolyline(routeMapPolyline!!)
        mapPolylines.add(routeMapPolyline)

        val startPoint =
            route.sections[0].departurePlace.mapMatchedCoordinates
        val destination =
            route.sections[route.sections.size - 1].arrivalPlace.mapMatchedCoordinates

        // Draw a circle to indicate starting point and destination.
        addCircleMapMarker(startPoint, R.drawable.poi_start)
        addCircleMapMarker(destination, R.drawable.poi_destination)
    }

    // Perform a search for charging stations along the found route.
    private fun searchAlongARoute(route: Route) {
        // We specify here that we only want to include results
        // within a max distance of xx meters from any point of the route.
        val halfWidthInMeters = 200
        val routeCorridor = GeoCorridor(route.geometry.vertices, halfWidthInMeters)
        val placeCategory = PlaceCategory(PlaceCategory.BUSINESS_AND_SERVICES_EV_CHARGING_STATION)
        val categoryQueryArea =
            CategoryQuery.Area(routeCorridor, mapView.camera.state.targetCoordinates)
        val categoryQuery = CategoryQuery(placeCategory, categoryQueryArea)

        val searchOptions = SearchOptions()
        searchOptions.languageCode = LanguageCode.EN_US
        searchOptions.maxItems = 30

        enableEVChargingStationDetails()

        searchEngine.searchByCategory(
            categoryQuery, searchOptions,
            SearchCallback { searchError, items ->
                if (searchError != null) {
                    Log.d(
                        "Search",
                        "No charging stations found along the route. Error: $searchError"
                    )
                    return@SearchCallback
                }
                // If error is nil, it is guaranteed that the items will not be nil.
                Log.d("Search", "Search along route found " + items!!.size + " charging stations:")
                for (place in items) {
                    val details = place.details
                    val metadata = getMetadataForEVChargingPools(details)
                    var foundExistingChargingStation = false
                    for (mapMarker in mapMarkers) {
                        if (mapMarker.metadata != null) {
                            val id = mapMarker.metadata!!.getString(REQUIRED_CHARGING_METADATA_KEY)
                            if (id != null && id.equals(place.id, ignoreCase = true)) {
                                Log.d(
                                    "Search",
                                    "Insert metdata to existing charging station: This charging station was already required to reach the destination (see red charging icon)."
                                )
                                mapMarker.metadata = metadata
                                foundExistingChargingStation = true
                                break
                            }
                        }
                    }

                    if (!foundExistingChargingStation) {
                        addMapMarker(place.geoCoordinates!!, R.drawable.charging, metadata)
                    }
                }
            })
    }

    // Enable fetching online availability details for EV charging stations.
    // It allows retrieving additional details, such as whether a charging station is currently occupied.
    // Check the API Reference for more details.
    private fun enableEVChargingStationDetails() {
        // Fetching additional charging stations details requires a custom option call.
        val error = searchEngine.setCustomOption("browse.show", "ev")
        if (error != null) {
            showDialog(
                "Charging station",
                "Failed to enableEVChargingStationDetails. "
            )
        } else {
            Log.d("ChargingStation", "EV charging station availability enabled successfully.")
        }
    }

    private fun setTapGestureHandler() {
        mapView.gestures.tapListener = TapListener { touchPoint -> pickMapMarker(touchPoint) }
    }

    // This method is used to pick a map marker when a user taps on a charging station icon on the map.
    // When performing a search for charging stations along the route, clicking on a charging station icon
    // will display its details, including the supplier name, connector count, availability status, last update time, etc.
    private fun pickMapMarker(touchPoint: Point2D) {
        val originInPixels = Point2D(touchPoint.x, touchPoint.y)
        val sizeInPixels = Size2D(1.0, 1.0)
        val rectangle = Rectangle2D(originInPixels, sizeInPixels)

        // If you do not want to specify any filter you can pass filter as NULL and all of the pickable contents will be picked.
        val filter: MapPickFilter? = null
        mapView.pick(
            filter, rectangle,
            MapPickCallback { mapPickResult ->
                if (mapPickResult == null) {
                    // An error occurred while performing the pick operation.
                    return@MapPickCallback
                }
                val pickMapItemsResult = mapPickResult.mapItems
                val mapMarkerList = pickMapItemsResult!!.markers
                val listSize = mapMarkerList.size
                if (listSize == 0) {
                    return@MapPickCallback
                }
                val topmostMapMarker = mapMarkerList[0]
                showPickedChargingStationResults(topmostMapMarker)
            })
    }

    private fun showPickedChargingStationResults(mapMarker: MapMarker) {
        val metadata = mapMarker.metadata
        if (metadata == null) {
            Log.d("MapPick", "No metadata found for picked marker.")
            return
        }

        val messageBuilder = StringBuilder()

        appendMetadataValue(messageBuilder, "Name", metadata.getString(SUPPLIER_NAME_METADATA_KEY))
        appendMetadataValue(
            messageBuilder,
            "Connector Count",
            metadata.getString(CONNECTOR_COUNT_METADATA_KEY)
        )
        appendMetadataValue(
            messageBuilder,
            "Available Connectors",
            metadata.getString(AVAILABLE_CONNECTORS_METADATA_KEY)
        )
        appendMetadataValue(
            messageBuilder,
            "Occupied Connectors",
            metadata.getString(OCCUPIED_CONNECTORS_METADATA_KEY)
        )
        appendMetadataValue(
            messageBuilder,
            "Out of Service Connectors",
            metadata.getString(OUT_OF_SERVICE_CONNECTORS_METADATA_KEY)
        )
        appendMetadataValue(
            messageBuilder,
            "Reserved Connectors",
            metadata.getString(RESERVED_CONNECTORS_METADATA_KEY)
        )
        appendMetadataValue(
            messageBuilder,
            "Last Updated",
            metadata.getString(LAST_UPDATED_METADATA_KEY)
        )

        if (messageBuilder.isNotEmpty()) {
            messageBuilder.append("\n\nFor a full list of attributes please refer to the API Reference.")
            showDialog("Charging station details", messageBuilder.toString())
        } else {
            Log.d("MapPick", "No relevant metadata available for charging station.")
        }
    }

    private fun appendMetadataValue(builder: StringBuilder, label: String, value: String?) {
        if (value != null) {
            builder.append("\n").append(label).append(": ").append(value)
        }
    }

    private fun getMetadataForEVChargingPools(placeDetails: Details): Metadata {
        val metadata = Metadata()
        if (placeDetails.evChargingPool != null) {
            for (station in placeDetails.evChargingPool!!.chargingStations) {
                if (station.supplierName != null) {
                    metadata.setString(SUPPLIER_NAME_METADATA_KEY, station.supplierName!!)
                }
                if (station.connectorCount != null) {
                    metadata.setString(
                        CONNECTOR_COUNT_METADATA_KEY,
                        station.connectorCount.toString()
                    )
                }
                if (station.availableConnectorCount != null) {
                    metadata.setString(
                        AVAILABLE_CONNECTORS_METADATA_KEY,
                        station.availableConnectorCount.toString()
                    )
                }
                if (station.occupiedConnectorCount != null) {
                    metadata.setString(
                        OCCUPIED_CONNECTORS_METADATA_KEY,
                        station.occupiedConnectorCount.toString()
                    )
                }
                if (station.outOfServiceConnectorCount != null) {
                    metadata.setString(
                        OUT_OF_SERVICE_CONNECTORS_METADATA_KEY,
                        station.outOfServiceConnectorCount.toString()
                    )
                }
                if (station.reservedConnectorCount != null) {
                    metadata.setString(
                        RESERVED_CONNECTORS_METADATA_KEY,
                        station.reservedConnectorCount.toString()
                    )
                }
                if (station.lastUpdated != null) {
                    metadata.setString(LAST_UPDATED_METADATA_KEY, station.lastUpdated.toString())
                }
            }
        }
        return metadata
    }

    // Shows the reachable area for this electric vehicle from the current start coordinates and EV car options when the goal is
    // to consume 400 Wh or less (see options below).
    fun onReachableAreaButtonClicked() {
        if (startGeoCoordinates == null) {
            showDialog("Error", "Please add at least one route first.")
            return
        }

        // Clear previously added polygon area, if any.
        clearIsolines()

        // This finds the area that an electric vehicle can reach by consuming 400 Wh or less,
        // while trying to take the fastest possible route into any possible straight direction from start.
        // Note: We have specified evCarOptions.routeOptions.optimizationMode = OptimizationMode.FASTEST for EV car options above.
        val rangeValues = listOf(400)

        val calculationOptions =
            Calculation(
                IsolineRangeType.CONSUMPTION_IN_WATT_HOURS,
                rangeValues,
                IsolineCalculationMode.BALANCED
            )
        val isolineOptions = IsolineOptions(calculationOptions, eVCarOptions)

        isolineRoutingEngine.calculateIsoline(
            Waypoint(startGeoCoordinates!!), isolineOptions,
            CalculateIsolineCallback { routingError, list ->
                if (routingError != null) {
                    showDialog("Error while calculating reachable area:", routingError.toString())
                    return@CalculateIsolineCallback
                }
                // When routingError is nil, the isolines list is guaranteed to contain at least one isoline.
                // The number of isolines matches the number of requested range values. Here we have used one range value,
                // so only one isoline object is expected.
                val isoline = list!![0]

                // If there is more than one polygon, the other polygons indicate separate areas, for example, islands, that
                // can only be reached by a ferry.
                for (geoPolygon in isoline.polygons) {
                    // Show polygon on map.
                    val fillColor = Color.valueOf(0f, 0.56f, 0.54f, 0.5f) // RGBA
                    val mapPolygon = MapPolygon(geoPolygon!!, fillColor)
                    mapView.mapScene.addMapPolygon(mapPolygon)
                    mapPolygons.add(mapPolygon)
                }
            })
    }

    fun clearMap() {
        clearWaypointMapMarker()
        clearRoute()
        clearIsolines()
    }

    private fun clearWaypointMapMarker() {
        for (mapMarker in mapMarkers) {
            mapView.mapScene.removeMapMarker(mapMarker)
        }
        mapMarkers.clear()
    }

    private fun clearRoute() {
        for (mapPolyline in mapPolylines) {
            mapView.mapScene.removeMapPolyline(mapPolyline)
        }
        mapPolylines.clear()
    }

    private fun clearIsolines() {
        for (mapPolygon in mapPolygons) {
            mapView.mapScene.removeMapPolygon(mapPolygon)
        }
        mapPolygons.clear()
    }

    private fun createRandomGeoCoordinatesInViewport(): GeoCoordinates {
        val geoBox = mapView.camera.boundingBox
        if (geoBox == null) {
            showDialog("Error", "No valid bbox.")
            return GeoCoordinates(0.0, 0.0)
        }

        val northEast = geoBox.northEastCorner
        val southWest = geoBox.southWestCorner

        val minLat = southWest.latitude
        val maxLat = northEast.latitude
        val lat = getRandom(minLat, maxLat)

        val minLon = southWest.longitude
        val maxLon = northEast.longitude
        val lon = getRandom(minLon, maxLon)

        return GeoCoordinates(lat, lon)
    }

    private fun getRandom(min: Double, max: Double): Double {
        return min + Math.random() * (max - min)
    }

    private fun addMapMarker(geoCoordinates: GeoCoordinates, resourceId: Int, metadata: Metadata) {
        val mapImage = MapImageFactory.fromResource(context.resources, resourceId)
        val mapMarker = MapMarker(geoCoordinates, mapImage)
        mapView.mapScene.addMapMarker(mapMarker)
        mapMarker.metadata = metadata
        mapMarkers.add(mapMarker)
    }

    private fun addCircleMapMarker(geoCoordinates: GeoCoordinates, resourceId: Int) {
        val mapImage = MapImageFactory.fromResource(context.resources, resourceId)
        val mapMarker = MapMarker(geoCoordinates, mapImage)
        mapView.mapScene.addMapMarker(mapMarker)
        mapMarkers.add(mapMarker)
    }

    private fun showDialog(title: String, message: String) {
        val builder: AlertDialog.Builder = AlertDialog.Builder(context)
        builder.setTitle(title)
        builder.setMessage(message)
        builder.show()
    }

    // Dispose the RoutingEngine instance to cancel any pending requests
    // and shut it down for proper resource cleanup.
    fun dispose() {
        routingEngine.dispose()
    }
}