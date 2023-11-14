/*
 * Copyright (C) 2019-2023 HERE Europe B.V.
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

package com.here.evrouting;

import android.content.Context;
import android.util.Log;

import androidx.appcompat.app.AlertDialog;

import com.here.sdk.core.Color;
import com.here.sdk.core.GeoBox;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.GeoCorridor;
import com.here.sdk.core.GeoPolygon;
import com.here.sdk.core.GeoPolyline;
import com.here.sdk.core.LanguageCode;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.mapview.LineCap;
import com.here.sdk.mapview.MapCamera;
import com.here.sdk.mapview.MapImage;
import com.here.sdk.mapview.MapImageFactory;
import com.here.sdk.mapview.MapMarker;
import com.here.sdk.mapview.MapMeasure;
import com.here.sdk.mapview.MapMeasureDependentRenderSize;
import com.here.sdk.mapview.MapPolygon;
import com.here.sdk.mapview.MapPolyline;
import com.here.sdk.mapview.MapView;
import com.here.sdk.mapview.RenderSize;
import com.here.sdk.routing.AvoidanceOptions;
import com.here.sdk.routing.CalculateIsolineCallback;
import com.here.sdk.routing.CalculateRouteCallback;
import com.here.sdk.routing.ChargingConnectorType;
import com.here.sdk.routing.ChargingStation;
import com.here.sdk.routing.EVCarOptions;
import com.here.sdk.routing.EVDetails;
import com.here.sdk.routing.Isoline;
import com.here.sdk.routing.IsolineCalculationMode;
import com.here.sdk.routing.IsolineOptions;
import com.here.sdk.routing.IsolineRangeType;
import com.here.sdk.routing.OptimizationMode;
import com.here.sdk.routing.PostAction;
import com.here.sdk.routing.Route;
import com.here.sdk.routing.RoutingEngine;
import com.here.sdk.routing.RoutingError;
import com.here.sdk.routing.Section;
import com.here.sdk.routing.SectionNotice;
import com.here.sdk.routing.Waypoint;
import com.here.sdk.search.Place;
import com.here.sdk.search.SearchCallback;
import com.here.sdk.search.SearchEngine;
import com.here.sdk.search.SearchError;
import com.here.sdk.search.SearchOptions;
import com.here.sdk.search.TextQuery;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;

// This example shows how to calculate routes for electric vehicles that contain necessary charging stations
// (indicated with red charging icon). In addition, all existing charging stations are searched along the route
// (indicated with green charging icon). You can also visualize the reachable area from your starting point
// (isoline routing).
public class EVRoutingExample {

    private final Context context;
    private final MapView mapView;
    private final List<MapMarker> mapMarkers = new ArrayList<>();
    private final List<MapPolyline> mapPolylines = new ArrayList<>();
    private final List<MapPolygon> mapPolygons = new ArrayList<>();
    private final RoutingEngine routingEngine;
    private final SearchEngine searchEngine;
    private GeoCoordinates startGeoCoordinates;
    private GeoCoordinates destinationGeoCoordinates;
    private final List<String> chargingStationsIDs = new ArrayList<>();

    public EVRoutingExample(Context context, MapView mapView) {
        this.context = context;
        this.mapView = mapView;
        MapCamera camera = mapView.getCamera();
        double distanceInMeters = 1000 * 10;
        MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE, distanceInMeters);
        camera.lookAt(new GeoCoordinates(52.520798, 13.409408), mapMeasureZoom);

        try {
            routingEngine = new RoutingEngine();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of RoutingEngine failed: " + e.error.name());
        }

        try {
            // Add search engine to search for places along a route.
            searchEngine = new SearchEngine();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of SearchEngine failed: " + e.error.name());
        }
    }

    // Calculates an EV car route based on random start / destination coordinates near viewport center.
    public void addEVRouteButtonClicked() {
        chargingStationsIDs.clear();

        startGeoCoordinates = createRandomGeoCoordinatesInViewport();
        destinationGeoCoordinates = createRandomGeoCoordinatesInViewport();
        Waypoint startWaypoint = new Waypoint(startGeoCoordinates);
        Waypoint destinationWaypoint = new Waypoint(destinationGeoCoordinates);
        List<Waypoint> waypoints =
                new ArrayList<>(Arrays.asList(startWaypoint, destinationWaypoint));

        routingEngine.calculateRoute(waypoints, getEVCarOptions(), new CalculateRouteCallback() {
            @Override
            public void onRouteCalculated(RoutingError routingError, List<Route> list) {
                if (routingError != null) {
                    showDialog("Error while calculating a route: ", routingError.toString());
                    return;
                }

                // When routingError is nil, routes is guaranteed to contain at least one route.
                Route route = list.get(0);
                showRouteOnMap(route);
                logRouteViolations(route);
                logEVDetails(route);
                searchAlongARoute(route);
            }
        });
    }

    private EVCarOptions getEVCarOptions()  {
        EVCarOptions evCarOptions = new EVCarOptions();

        // The below three options are the minimum you must specify or routing will result in an error.
        evCarOptions.consumptionModel.ascentConsumptionInWattHoursPerMeter = 9;
        evCarOptions.consumptionModel.descentRecoveryInWattHoursPerMeter = 4.3;
        evCarOptions.consumptionModel.freeFlowSpeedTable = new HashMap<Integer, Double>() {{
            put(0, 0.239);
            put(27, 0.239);
            put(60, 0.196);
            put(90, 0.238);
        }};

        // Must be 0 for isoline calculation.
        evCarOptions.routeOptions.alternatives = 0;

        // Ensure that the vehicle does not run out of energy along the way
        // and charging stations are added as additional waypoints.
        evCarOptions.ensureReachability = true;

        // The below options are required when setting the ensureReachability option to true
        // (AvoidanceOptions need to be empty).
        evCarOptions.avoidanceOptions = new AvoidanceOptions();
        evCarOptions.routeOptions.speedCapInMetersPerSecond = null;
        evCarOptions.routeOptions.optimizationMode = OptimizationMode.FASTEST;
        evCarOptions.batterySpecifications.connectorTypes =
                new ArrayList<>(Arrays.asList(ChargingConnectorType.TESLA,
                    ChargingConnectorType.IEC_62196_TYPE_1_COMBO, ChargingConnectorType.IEC_62196_TYPE_2_COMBO));
        evCarOptions.batterySpecifications.totalCapacityInKilowattHours = 80.0;
        evCarOptions.batterySpecifications.initialChargeInKilowattHours = 10.0;
        evCarOptions.batterySpecifications.targetChargeInKilowattHours = 72.0;
        evCarOptions.batterySpecifications.chargingCurve = new HashMap<Double, Double>() {{
            put(0.0, 239.0);
            put(64.0, 111.0);
            put(72.0, 1.0);
        }};

        // Note: More EV options are availeble, the above shows only the minimum viable options.

        return evCarOptions;
    }

    private void logEVDetails(Route route) {
        // Find inserted charging stations that are required for this route.
        // Note that this example assumes only one start waypoint and one destination waypoint.
        // By default, each route has one section.
        int additionalSectionCount = route.getSections().size() - 1;
        if (additionalSectionCount > 0) {
            // Each additional waypoint splits the route into two sections.
            Log.d("EVDetails", "Number of required stops at charging stations: " + additionalSectionCount);
        } else {
            Log.d("EVDetails","Based on the provided options, the destination can be reached without a stop at a charging station.");
        }

        int sectionIndex = 0;
        List<Section> sections = route.getSections();
        for (Section section : sections) {
            EVDetails evDetails = section.getEvDetails();
            if (evDetails == null) {
                return;
            }
            Log.d("EVDetails", "Estimated net energy consumption in kWh for this section: " + evDetails.consumptionInKilowattHour);
            for (PostAction postAction : section.getPostActions()) {
                switch (postAction.action) {
                    case CHARGING_SETUP:
                    Log.d("EVDetails", "At the end of this section you need to setup charging for " + postAction.duration.getSeconds() + " s.");
                        break;
                    case CHARGING:
                    Log.d("EVDetails", "At the end of this section you need to charge for " + postAction.duration.getSeconds() + " s.");
                        break;
                    case WAIT:
                    Log.d("EVDetails", "At the end of this section you need to wait for " + postAction.duration.getSeconds() + " s.");
                        break;
                    default: throw new RuntimeException("Unknown post action type.");
                }
            }

            Log.d("EVDetails", "Section " + sectionIndex + ": Estimated battery charge in kWh when leaving the departure place: " + section.getDeparturePlace().chargeInKilowattHours);
            Log.d("EVDetails", "Section " + sectionIndex + ": Estimated battery charge in kWh when leaving the arrival place: " + section.getArrivalPlace().chargeInKilowattHours);

            // Only charging stations that are needed to reach the destination are listed below.
            ChargingStation depStation = section.getDeparturePlace().chargingStation;
            if (depStation != null  && depStation.id != null && !chargingStationsIDs.contains(depStation.id)) {
                Log.d("EVDetails", "Section " + sectionIndex + ", name of charging station: " + depStation.name);
                chargingStationsIDs.add(depStation.id);
                addCircleMapMarker(section.getDeparturePlace().mapMatchedCoordinates, R.drawable.required_charging);
            }

            ChargingStation arrStation = section.getDeparturePlace().chargingStation;
            if (arrStation != null && arrStation.id != null && !chargingStationsIDs.contains(arrStation.id)) {
                Log.d("EVDetails", "Section " + sectionIndex + ", name of charging station: " + arrStation.name);
                chargingStationsIDs.add(arrStation.id);
                addCircleMapMarker(section.getArrivalPlace().mapMatchedCoordinates, R.drawable.required_charging);
            }

            sectionIndex += 1;
        }
    }

    // A route may contain several warnings, for example, when a certain route option could not be fulfilled.
    // An implementation may decide to reject a route if one or more violations are detected.
    private void logRouteViolations(Route route) {
        List<Section> sections = route.getSections();
        for (Section section : sections) {
            for (SectionNotice notice : section.getSectionNotices()) {
                Log.d("RouteViolations", "This route contains the following warning: " + notice.code);
            }
        }
    }

    private void showRouteOnMap(Route route) {
        clearMap();

        // Show route as polyline.
        GeoPolyline routeGeoPolyline = route.getGeometry();
        float widthInPixels = 20;
        Color polylineColor = Color.valueOf(0, 0.56f, 0.54f, 0.63f);
        MapPolyline routeMapPolyline = null; // RGBA
        try {
            routeMapPolyline = new MapPolyline(routeGeoPolyline, new MapPolyline.SolidRepresentation(
                    new MapMeasureDependentRenderSize(RenderSize.Unit.PIXELS, widthInPixels),
                    polylineColor,
                    LineCap.ROUND));
        } catch (MapPolyline.Representation.InstantiationException e) {
            Log.e("MapPolyline Representation Exception:", e.error.name());
        } catch (MapMeasureDependentRenderSize.InstantiationException e) {
            Log.e("MapMeasureDependentRenderSize Exception:", e.error.name());
        }

        mapView.getMapScene().addMapPolyline(routeMapPolyline);
        mapPolylines.add(routeMapPolyline);

        GeoCoordinates startPoint =
                route.getSections().get(0).getDeparturePlace().mapMatchedCoordinates;
        GeoCoordinates destination =
                route.getSections().get(route.getSections().size() - 1).getArrivalPlace().mapMatchedCoordinates;

        // Draw a circle to indicate starting point and destination.
        addCircleMapMarker(startPoint, R.drawable.green_dot);
        addCircleMapMarker(destination, R.drawable.green_dot);
    }

    // Perform a search for charging stations along the found route.
    private void searchAlongARoute(Route route) {
        // We specify here that we only want to include results
        // within a max distance of xx meters from any point of the route.
        int halfWidthInMeters = 200;
        GeoCorridor routeCorridor = new GeoCorridor(route.getGeometry().vertices, halfWidthInMeters);
        TextQuery.Area queryArea = new TextQuery.Area(routeCorridor, mapView.getCamera().getState().targetCoordinates);
        TextQuery textQuery = new TextQuery("charging station", queryArea);

        SearchOptions searchOptions = new SearchOptions();
        searchOptions.languageCode = LanguageCode.EN_US;
        searchOptions.maxItems = 30;

        searchEngine.search(textQuery, searchOptions, new SearchCallback() {
            @Override
            public void onSearchCompleted(SearchError searchError, List<Place> items) {
                if (searchError != null) {
                    if (searchError == SearchError.POLYLINE_TOO_LONG) {
                        // Increasing halfWidthInMeters will result in less precise results with the benefit of a less
                        // complex route shape.
                        Log.d("Search", "Route too long or halfWidthInMeters too small.");
                    } else {
                        Log.d("Search", "No charging stations found along the route. Error: " + searchError);
                    }
                    return;
                }

                // If error is nil, it is guaranteed that the items will not be nil.
                Log.d("Search","Search along route found " + items.size() + " charging stations:");
                for (Place place : items) {
                    if (chargingStationsIDs.contains(place.getId())) {
                        Log.d("Search", "Skipping: This charging station was already required to reach the destination (see red charging icon).");
                    } else {
                        // Only suggestions may not contain geoCoordinates, so it's safe to unwrap this search result's coordinates.
                        addCircleMapMarker(place.getGeoCoordinates(), R.drawable.charging);
                        Log.d("Search", place.getAddress().addressText);
                    }
                }
            }
        });
    }

    // Shows the reachable area for this electric vehicle from the current start coordinates and EV car options when the goal is
    // to consume 400 Wh or less (see options below).
    public void onReachableAreaButtonClicked() {
        if (startGeoCoordinates == null) {
            showDialog("Error", "Please add at least one route first.");
            return;
        }
        
        // Clear previously added polygon area, if any.
        clearIsolines();

        // This finds the area that an electric vehicle can reach by consuming 400 Wh or less,
        // while trying to take the fastest possible route into any possible straight direction from start.
        // Note: We have specified evCarOptions.routeOptions.optimizationMode = OptimizationMode.FASTEST for EV car options above.
        List<Integer> rangeValues = Collections.singletonList(400);

        IsolineOptions.Calculation calculationOptions =
                new IsolineOptions.Calculation(IsolineRangeType.CONSUMPTION_IN_WATT_HOURS, rangeValues, IsolineCalculationMode.BALANCED);
        IsolineOptions isolineOptions = new IsolineOptions(calculationOptions, getEVCarOptions());

        routingEngine.calculateIsoline(new Waypoint(startGeoCoordinates), isolineOptions, new CalculateIsolineCallback() {
            @Override
            public void onIsolineCalculated(RoutingError routingError, List<Isoline> list) {
                if (routingError != null) {
                    showDialog("Error while calculating reachable area:", routingError.toString());
                    return;
                }

                // When routingError is nil, the isolines list is guaranteed to contain at least one isoline.
                // The number of isolines matches the number of requested range values. Here we have used one range value,
                // so only one isoline object is expected.
                Isoline isoline = list.get(0);

                // If there is more than one polygon, the other polygons indicate separate areas, for example, islands, that
                // can only be reached by a ferry.
                for (GeoPolygon geoPolygon : isoline.getPolygons()) {
                    // Show polygon on map.
                      Color fillColor = Color.valueOf(0, 0.56f, 0.54f, 0.5f); // RGBA
                    MapPolygon mapPolygon = new MapPolygon(geoPolygon, fillColor);
                    mapView.getMapScene().addMapPolygon(mapPolygon);
                    mapPolygons.add(mapPolygon);
                }
            }
        });
    }

    public void clearMap() {
        clearWaypointMapMarker();
        clearRoute();
        clearIsolines();
    }

    private void clearWaypointMapMarker() {
        for (MapMarker mapMarker : mapMarkers) {
            mapView.getMapScene().removeMapMarker(mapMarker);
        }
        mapMarkers.clear();
    }

    private void clearRoute() {
        for (MapPolyline mapPolyline : mapPolylines) {
            mapView.getMapScene().removeMapPolyline(mapPolyline);
        }
        mapPolylines.clear();
    }

    private void clearIsolines() {
        for (MapPolygon mapPolygon : mapPolygons) {
            mapView.getMapScene().removeMapPolygon(mapPolygon);
        }
        mapPolygons.clear();
    }

    private GeoCoordinates createRandomGeoCoordinatesInViewport()  {
        GeoBox geoBox = mapView.getCamera().getBoundingBox();
        if (geoBox == null) {
            showDialog("Error", "No valid bbox.");
            return new GeoCoordinates(0, 0);
        }

        GeoCoordinates northEast = geoBox.northEastCorner;
        GeoCoordinates southWest = geoBox.southWestCorner;

        double minLat = southWest.latitude;
        double maxLat = northEast.latitude;
        double lat = getRandom(minLat, maxLat);

        double minLon = southWest.longitude;
        double maxLon = northEast.longitude;
        double lon = getRandom(minLon, maxLon);

        return new GeoCoordinates(lat, lon);
    }

    private double getRandom(double min, double max) {
        return min + Math.random() * (max - min);
    }

    private void addCircleMapMarker(GeoCoordinates geoCoordinates, int resourceId) {
        MapImage mapImage = MapImageFactory.fromResource(context.getResources(), resourceId);
        MapMarker mapMarker = new MapMarker(geoCoordinates, mapImage);
        mapView.getMapScene().addMapMarker(mapMarker);
        mapMarkers.add(mapMarker);
    }

    private void showDialog(String title, String message) {
        AlertDialog.Builder builder =
                new AlertDialog.Builder(context);
        builder.setTitle(title);
        builder.setMessage(message);
        builder.show();
    }
}
