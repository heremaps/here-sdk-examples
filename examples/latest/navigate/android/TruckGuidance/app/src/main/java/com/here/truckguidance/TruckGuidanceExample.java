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

package com.here.truckguidance;

import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;

import com.here.sdk.animation.Easing;
import com.here.sdk.animation.EasingFunction;
import com.here.sdk.core.Anchor2D;
import com.here.sdk.core.Color;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.GeoCorridor;
import com.here.sdk.core.GeoOrientationUpdate;
import com.here.sdk.core.GeoPolyline;
import com.here.sdk.core.LanguageCode;
import com.here.sdk.core.PickedPlace;
import com.here.sdk.core.Point2D;
import com.here.sdk.core.Rectangle2D;
import com.here.sdk.core.Size2D;
import com.here.sdk.core.TransportProfile;
import com.here.sdk.core.errors.InstantiationErrorException;
import com.here.sdk.gestures.GestureState;
import com.here.sdk.mapview.LineCap;
import com.here.sdk.mapview.MapCamera;
import com.here.sdk.mapview.MapCameraAnimation;
import com.here.sdk.mapview.MapCameraAnimationFactory;
import com.here.sdk.mapview.MapCameraUpdate;
import com.here.sdk.mapview.MapCameraUpdateFactory;
import com.here.sdk.mapview.MapFeatureModes;
import com.here.sdk.mapview.MapFeatures;
import com.here.sdk.mapview.MapImage;
import com.here.sdk.mapview.MapImageFactory;
import com.here.sdk.mapview.MapMarker;
import com.here.sdk.mapview.MapMeasure;
import com.here.sdk.mapview.MapMeasureDependentRenderSize;
import com.here.sdk.mapview.MapPolyline;
import com.here.sdk.mapview.MapView;
import com.here.sdk.mapview.PickMapContentResult;
import com.here.sdk.mapview.RenderSize;
import com.here.sdk.navigation.DimensionRestriction;
import com.here.sdk.navigation.DimensionRestrictionType;
import com.here.sdk.navigation.DistanceType;
import com.here.sdk.navigation.EnvironmentalZoneWarning;
import com.here.sdk.navigation.EnvironmentalZoneWarningListener;
import com.here.sdk.navigation.NavigableLocation;
import com.here.sdk.navigation.NavigableLocationListener;
import com.here.sdk.navigation.Navigator;
import com.here.sdk.navigation.TruckRestrictionWarning;
import com.here.sdk.navigation.TruckRestrictionWarningType;
import com.here.sdk.navigation.TruckRestrictionsWarningListener;
import com.here.sdk.navigation.VisualNavigator;
import com.here.sdk.navigation.WeightRestriction;
import com.here.sdk.navigation.WeightRestrictionType;
import com.here.sdk.routing.AvoidanceOptions;
import com.here.sdk.routing.RoadFeatures;
import com.here.sdk.routing.Route;
import com.here.sdk.routing.RoutingEngine;
import com.here.sdk.routing.RoutingError;
import com.here.sdk.routing.Section;
import com.here.sdk.routing.SectionNotice;
import com.here.sdk.routing.TruckOptions;
import com.here.sdk.routing.ViolatedRestriction;
import com.here.sdk.routing.Waypoint;
import com.here.sdk.routing.ZoneCategory;
import com.here.sdk.search.CategoryQuery;
import com.here.sdk.search.Place;
import com.here.sdk.search.PlaceCategory;
import com.here.sdk.search.PlaceIdSearchCallback;
import com.here.sdk.search.SearchCallback;
import com.here.sdk.search.SearchEngine;
import com.here.sdk.search.SearchError;
import com.here.sdk.search.SearchOptions;
import com.here.sdk.search.TruckAmenities;
import com.here.sdk.transport.HazardousMaterial;
import com.here.sdk.transport.TruckSpecifications;
import com.here.sdk.transport.TruckType;
import com.here.sdk.transport.VehicleProfile;
import com.here.sdk.transport.VehicleType;
import com.here.time.Duration;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

// An example that shows key features for truck routing.
// It uses two navigator instances to show truck and car speed limits simultaneously.
// Note that this example does not show all truck features the HERE SDK has to offer.
public class TruckGuidanceExample {

    private static final String TAG = TruckGuidanceExample.class.getName();

    private final Context context;
    private final MapView mapView;
    private final List<MapMarker> mapMarkers = new ArrayList<>();
    private final List<MapPolyline> mapPolylines = new ArrayList<>();
    private final SearchEngine searchEngine;
    private final RoutingEngine routingEngine;
    // A route in Berlin - can be changed via longtap.
    private GeoCoordinates startGeoCoordinates = new GeoCoordinates(52.450798, 13.449408);
    private GeoCoordinates destinationGeoCoordinates = new GeoCoordinates(52.620798, 13.409408);
    private final MapMarker startMapMarker;
    private final MapMarker destinationMapMarker;
    private boolean changeDestination = true;
    private final VisualNavigator visualNavigator;
    private final Navigator navigator;
    private final List<String> activeTruckRestrictionWarnings = new ArrayList<>();
    private final HEREPositioningSimulator herePositioningSimulator;
    private double simulationSpeedFactor = 1;
    private Route lastCalculatedTruckRoute;
    private boolean isGuidance = false;
    private boolean isTracking = false;
    private MainActivity.UICallback uiCallback;

    public TruckGuidanceExample(Context context, MapView mapView) {
        this.context = context;
        this.mapView = mapView;
        MapCamera camera = mapView.getCamera();

        // Center map in Berlin.
        double distanceInMeters = 1000 * 90;
        MapMeasure mapMeasureZoom = new MapMeasure(MapMeasure.Kind.DISTANCE, distanceInMeters);
        camera.lookAt(new GeoCoordinates(52.520798, 13.409408), mapMeasureZoom);

        try {
            // We use the search engine to find places along a route.
            searchEngine = new SearchEngine();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of SearchEngine failed: " + e.error.name());
        }

        try {
            routingEngine = new RoutingEngine();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of RoutingEngine failed: " + e.error.name());
        }

        try {
            // The Visual Navigator will be used for truck navigation.
            visualNavigator = new VisualNavigator();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of VisualNavigator failed: " + e.error.name());
        }

        try {
            // A headless Navigator to receive car speed limits in parallel.
            // This instance is running in tracking mode for its entire lifetime.
            // By default, the navigator will receive car speed limits.
            navigator = new Navigator();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of Navigator failed: " + e.error.name());
        }

        // Create a TransportProfile instance.
        // This profile is currently only used to retrieve speed limits during tracking mode
        // when no route is set to the VisualNavigator instance.
        // This profile needs to be set only once during the lifetime of the VisualNavigator
        // instance - unless it should be updated.
        // Note that currently not all parameters are consumed, see API Reference for details.
        TransportProfile transportProfile = new TransportProfile();
        transportProfile.vehicleProfile = createVehicleProfile();
        visualNavigator.setTrackingTransportProfile(transportProfile);

        enableLayers();
        setTapGestureHandler();
        setupListeners();

        herePositioningSimulator = new HEREPositioningSimulator();

        // Draw a circle to indicate the currently selected starting point and destination.
        startMapMarker = addPOIMapMarker(startGeoCoordinates, R.drawable.poi_start);
        destinationMapMarker = addPOIMapMarker(destinationGeoCoordinates, R.drawable.poi_destination);

        setLongPressGestureHandler(mapView);
        showDialog("Note","Do a long press to change start and destination coordinates. " +
                "Map icons are pickable.");
    }

    // An immutable data class holding the definition of a truck.
    private static class MyTruckSpecs {
        static final int grossWeightInKilograms = 17000; // 17 tons
        static final int heightInCentimeters = 3 * 100; // 3 meters
        static final int widthInCentimeters = 4 * 100; // 4 meters
        // The total length including all trailers (if any).
        static final int lengthInCentimeters = 8 * 100; // 8 meters
        static final Integer weightPerAxleInKilograms = null;
        static final Integer axleCount = null;
        static final Integer trailerCount = null;
        static final TruckType truckType = TruckType.STRAIGHT;
    }

    // Used during tracking mode.
    private VehicleProfile createVehicleProfile() {
        VehicleProfile vehicleProfile = new VehicleProfile(VehicleType.TRUCK);
        vehicleProfile.grossWeightInKilograms = MyTruckSpecs.grossWeightInKilograms;
        vehicleProfile.heightInCentimeters = MyTruckSpecs.heightInCentimeters;
        // The total length including all trailers (if any).
        vehicleProfile.lengthInCentimeters = MyTruckSpecs.lengthInCentimeters;
        vehicleProfile.widthInCentimeters = MyTruckSpecs.widthInCentimeters;
        vehicleProfile.truckType = MyTruckSpecs.truckType;
        vehicleProfile.trailerCount = MyTruckSpecs.trailerCount == null ? 0 : MyTruckSpecs.trailerCount;
        vehicleProfile.axleCount = MyTruckSpecs.axleCount;
        vehicleProfile.weightPerAxleInKilograms = MyTruckSpecs.weightPerAxleInKilograms;
        return vehicleProfile;
    }

    // Used for route calculation.
    private TruckSpecifications createTruckSpecifications() {
        TruckSpecifications truckSpecifications = new TruckSpecifications();
        // When weight is not set, possible weight restrictions will not be taken into consideration
        // for route calculation. By default, weight is not set.
        // Specify the weight including trailers and shipped goods (if any).
        truckSpecifications.grossWeightInKilograms = MyTruckSpecs.grossWeightInKilograms;
        truckSpecifications.heightInCentimeters = MyTruckSpecs.heightInCentimeters;
        truckSpecifications.widthInCentimeters = MyTruckSpecs.widthInCentimeters;
        // The total length including all trailers (if any).
        truckSpecifications.lengthInCentimeters = MyTruckSpecs.lengthInCentimeters;
        truckSpecifications.weightPerAxleInKilograms = MyTruckSpecs.weightPerAxleInKilograms;
        truckSpecifications.axleCount = MyTruckSpecs.axleCount;
        truckSpecifications.trailerCount = MyTruckSpecs.trailerCount;
        truckSpecifications.truckType = MyTruckSpecs.truckType;
        return truckSpecifications;
    }

    public void setUICallback(MainActivity.UICallback callback) {
        uiCallback = callback;
    }

    // Enable layers that may be useful for truck drivers.
    private void enableLayers() {
        Map<String, String> mapFeatures = new HashMap<>();
        mapFeatures.put(MapFeatures.TRAFFIC_FLOW, MapFeatureModes.TRAFFIC_FLOW_WITH_FREE_FLOW);
        mapFeatures.put(MapFeatures.TRAFFIC_INCIDENTS, MapFeatureModes.DEFAULT);
        mapFeatures.put(MapFeatures.SAFETY_CAMERAS, MapFeatureModes.DEFAULT);
        mapFeatures.put(MapFeatures.VEHICLE_RESTRICTIONS, MapFeatureModes.DEFAULT);
        mapFeatures.put(MapFeatures.ENVIRONMENTAL_ZONES, MapFeatureModes.DEFAULT);
        mapFeatures.put(MapFeatures.CONGESTION_ZONES, MapFeatureModes.DEFAULT);
        mapView.getMapScene().enableFeatures(mapFeatures);
    }

    private void setTapGestureHandler() {
        mapView.getGestures().setTapListener(touchPoint -> pickCartoPois(touchPoint));
    }

    // Allows to retrieve details from carto POIs including VEHICLE_RESTRICTIONS layer
    // and traffic incidents.
    // Note that restriction icons are not directly pickable: Only the restriction lines marking
    // the affected streets are pickable, but with a larger pick rectangle,
    // also the icons will become pickable indirectly.
    private void pickCartoPois(final Point2D touchPoint) {
        // You can also use a larger area to include multiple carto POIs.
        Rectangle2D rectangle2D = new Rectangle2D(touchPoint, new Size2D(50, 50));
        mapView.pickMapContent(rectangle2D, pickMapContentResult -> {
            if (pickMapContentResult == null) {
                // An error occurred while performing the pick operation.
                return;
            }

            List<PickMapContentResult.PoiResult> cartoPOIList = pickMapContentResult.getPois();
            List<PickMapContentResult.TrafficIncidentResult> trafficPOIList = pickMapContentResult.getTrafficIncidents();
            List<PickMapContentResult.VehicleRestrictionResult> vehicleRestrictionResultList = pickMapContentResult.getVehicleRestrictions();

            // Note that pick here only the top most icon and ignore others that may be underneath.
            if (cartoPOIList.size() > 0) {
                PickMapContentResult.PoiResult topmostContent = cartoPOIList.get(0);
                Log.d("Carto POI picked: ", topmostContent.name +
                        ", Place category: " + topmostContent.placeCategoryId);

                // Optionally, you can now use the SearchEngine or the OfflineSearchEngine to retrieve more details.
                PickedPlace pickedPlace =
                        new PickedPlace(topmostContent.name, topmostContent.coordinates, topmostContent.placeCategoryId);
                searchEngine.searchPickedPlace(pickedPlace, LanguageCode.EN_US, new PlaceIdSearchCallback() {
                    @Override
                    public void onPlaceIdSearchCompleted(@Nullable SearchError searchError, @Nullable Place place) {
                        if (searchError == null) {
                            String address = place.getAddress().addressText;
                            String categories = "";
                            for (PlaceCategory category : place.getDetails().categories) {
                                String name = category.getName();
                                if (name != null) {
                                    categories += category.getName() + " ";
                                }
                            }
                            showDialog("Carto POI", address + ". Categories: " + categories);
                        } else {
                            Log.e(TAG, "searchPickedPlace() resulted in an error: " + searchError.name());
                        }
                    }
                });
            }

            if (trafficPOIList.size() > 0) {
                PickMapContentResult.TrafficIncidentResult topmostContent = trafficPOIList.get(0);
                showDialog("Traffic incident picked", "Type: " +
                        topmostContent.getType().name());
                // Optionally, you can now use the TrafficEngine to retrieve more details for this incident.
            }

            if (vehicleRestrictionResultList.size() > 0) {
                PickMapContentResult.VehicleRestrictionResult topmostContent = vehicleRestrictionResultList.get(0);
                // Note that the text property is empty for general truck restrictions.
                showDialog("Vehicle restriction picked", "Type: " +
                        topmostContent.restrictionType + ". " + topmostContent.text);
            }
        });
    }

    private void setupListeners() {
        // Notifies on the current map-matched location and other useful information while driving.
        visualNavigator.setNavigableLocationListener(new NavigableLocationListener() {
            @Override
            public void onNavigableLocationUpdated(@NonNull NavigableLocation currentNavigableLocation) {
                Double drivingSpeed = currentNavigableLocation.originalLocation.speedInMetersPerSecond;
                // Note that we ignore speedAccuracyInMetersPerSecond here for simplicity.
                if (drivingSpeed == null) {
                    uiCallback.onDrivingSpeed("n/a");
                } else {
                    int kmh = (int) metersPerSecondToKilometersPerHour(drivingSpeed);
                    uiCallback.onDrivingSpeed("" + kmh);
                }
            }
        });

        // Notifies on the current speed limit valid on the current road.
        // Used for the truck route.
        visualNavigator.setSpeedLimitListener(speedLimit -> {
            // For simplicity, we use here the effective legal speed limit. More differentiated speed values,
            // for example, due to weather conditions or school zones are also available.
            // See our Developer's Guide for more details.
            Double currentSpeedLimit = speedLimit.effectiveSpeedLimitInMetersPerSecond();
            if (currentSpeedLimit == null) {
                Log.d(TAG, "Warning: Speed limits unknown, data could not be retrieved.");
                uiCallback.onTruckSpeedLimit("n/a");
            } else if (currentSpeedLimit == 0) {
                Log.d(TAG, "No speed limits on this road! Drive as fast as you feel safe ...");
                uiCallback.onTruckSpeedLimit("NSL");
            } else {
                Log.d(TAG, "Current speed limit (m/s):" + currentSpeedLimit);
                // For this example, we keep it simple and show speed limits only km/h.
                int kmh = (int) metersPerSecondToKilometersPerHour(currentSpeedLimit);
                uiCallback.onTruckSpeedLimit("" + kmh);
            }
        });

        // Notifies on the current speed limit valid on the current road.
        // Note that this navigator instance is running in tracking mode without following a route.
        // It receives the same location updates as the visual navigator.
        navigator.setSpeedLimitListener(speedLimit -> {
            Double currentSpeedLimit = speedLimit.effectiveSpeedLimitInMetersPerSecond();
            if (currentSpeedLimit == null) {
                Log.d(TAG, "Warning: Car speed limits unknown, data could not be retrieved.");
                uiCallback.onCarSpeedLimit("n/a");
            } else if (currentSpeedLimit == 0) {
                Log.d(TAG, "No speed limits for cars on this road! Drive as fast as you feel safe ...");
                uiCallback.onCarSpeedLimit("NSL");
            } else {
                Log.d(TAG, "Current car speed limit (m/s):" + currentSpeedLimit);
                // For this example, we keep it simple and show speed limits only km/h.
                int kmh = (int) metersPerSecondToKilometersPerHour(currentSpeedLimit);
                uiCallback.onCarSpeedLimit("" + kmh);
            }
        });

        // Notifies truck drivers on road restrictions ahead. Called whenever there is a change.
        // For example, there can be a bridge ahead not high enough to pass a big truck
        // or there can be a road ahead where the weight of the truck is beyond it's permissible weight.
        // This event notifies on truck restrictions in general,
        // so it will also deliver events, when the transport type was set to a non-truck transport type.
        // The given restrictions are based on the HERE database of the road network ahead.
        visualNavigator.setTruckRestrictionsWarningListener(new TruckRestrictionsWarningListener() {
            @Override
            public void onTruckRestrictionsWarningUpdated(@NonNull List<TruckRestrictionWarning> list) {
                // The list is guaranteed to be non-empty.
                for (TruckRestrictionWarning truckRestrictionWarning : list) {
                    if (truckRestrictionWarning.timeRule != null && !truckRestrictionWarning.timeRule.appliesTo(new Date())) {
                        // The restriction is time-dependent and does currently not apply.
                        // Note: For this example, we do not skip any restriction.
                        // continue;
                    }

                    // The trailer count for which the current restriction applies.
                    // If the field is 'null' then the current restriction is valid regardless of trailer count.
                    if (truckRestrictionWarning.trailerCount != null && MyTruckSpecs.trailerCount != null) {
                        int min = truckRestrictionWarning.trailerCount.min;
                        Integer max = truckRestrictionWarning.trailerCount.max; // If not set, maximum is unbounded.
                        if (min > MyTruckSpecs.trailerCount || (max != null && max < MyTruckSpecs.trailerCount)) {
                            // The restriction is not valid for this truck.
                            // Note: For this example, we do not skip any restriction.
                            // continue;
                        }
                    }

                    DistanceType distanceType = truckRestrictionWarning.distanceType;
                    if (distanceType == DistanceType.AHEAD) {
                        Log.d(TAG, "A TruckRestriction ahead in: "+ truckRestrictionWarning.distanceInMeters + " meters.");
                    } else if (distanceType == DistanceType.REACHED) {
                        Log.d(TAG, "A TruckRestriction has been reached.");
                    } else if (distanceType == DistanceType.PASSED) {
                        // If not preceded by a "REACHED"-notification, this restriction was valid only for the passed location.
                        Log.d(TAG, "A TruckRestriction just passed.");
                    }

                    // One of the following restrictions applies, if more restrictions apply at the same time,
                    // they are part of another TruckRestrictionWarning element contained in the list.
                    if (truckRestrictionWarning.weightRestriction != null) {
                        assert truckRestrictionWarning.type == TruckRestrictionWarningType.WEIGHT;
                        handleWeightTruckWarning(truckRestrictionWarning.weightRestriction, distanceType);
                    } else if (truckRestrictionWarning.dimensionRestriction != null) {
                        assert truckRestrictionWarning.type == TruckRestrictionWarningType.DIMENSION;
                        handleDimensionTruckWarning(truckRestrictionWarning.dimensionRestriction, distanceType);
                    } else {
                        assert truckRestrictionWarning.type == TruckRestrictionWarningType.GENERAL;
                        handleTruckRestrictions("No Trucks.", distanceType);
                        Log.d(TAG, "TruckRestriction: General restriction - no trucks allowed.");
                    }
                 }
            }
        });

        visualNavigator.setEnvironmentalZoneWarningListener(new EnvironmentalZoneWarningListener() {
            @Override
            public void onEnvironmentalZoneWarningsUpdated(@NonNull List<EnvironmentalZoneWarning> list) {
                // The list is guaranteed to be non-empty.
                for (EnvironmentalZoneWarning environmentalZoneWarning : list) {
                    DistanceType distanceType = environmentalZoneWarning.distanceType;
                    if (distanceType == DistanceType.AHEAD) {
                        Log.d(TAG, "A EnvironmentalZone ahead in: "+ environmentalZoneWarning.distanceInMeters + " meters.");
                    } else if (distanceType == DistanceType.REACHED) {
                        Log.d(TAG, "A EnvironmentalZone has been reached.");
                    } else if (distanceType == DistanceType.PASSED) {
                        Log.d(TAG, "A EnvironmentalZone just passed.");
                    }

                    // The official name of the environmental zone (example: "Zone basse émission Bruxelles").
                    String name = environmentalZoneWarning.name;
                    // The description of the environmental zone for the default language.
                    String description = environmentalZoneWarning.description.getDefaultValue();
                    // The environmental zone ID - uniquely identifies the zone in the HERE map data.
                    String zoneID = environmentalZoneWarning.zoneId;
                    // The website of the environmental zone, if available - null otherwise.
                    String websiteUrl = environmentalZoneWarning.websiteUrl;
                    Log.d(TAG, "environmentalZoneWarning: description: " + description);
                    Log.d(TAG, "environmentalZoneWarning: name: " + name);
                    Log.d(TAG, "environmentalZoneWarning: zoneID: " + zoneID);
                    Log.d(TAG, "environmentalZoneWarning: websiteUrl: " + websiteUrl);
                }
            }
        });

        // For more warners and events during guidance, please check the Navigation example app, available on GitHub.
    }

    private void handleWeightTruckWarning(WeightRestriction weightRestriction, DistanceType distanceType) {
        WeightRestrictionType type = weightRestriction.type;
        int value = weightRestriction.valueInKilograms;
        Log.d(TAG, "TruckRestriction for weight (kg): " + type.name() + ": " + value);

        String weightType = "n/a";
        if (type == WeightRestrictionType.TRUCK_WEIGHT) {
            weightType = "WEIGHT";
        }
        if (type == WeightRestrictionType.WEIGHT_PER_AXLE) {
            weightType = "WEIGHTPA";
        }
        String weightValue = "" + getTons(value) + "t";
        String description = weightType + ": " + weightValue;
        handleTruckRestrictions(description, distanceType);
    }

    private void handleDimensionTruckWarning(DimensionRestriction dimensionRestriction, DistanceType distanceType) {
        // Can be either a length, width or height restriction for a truck. For example, a height
        // restriction can apply for a tunnel.
        DimensionRestrictionType type = dimensionRestriction.type;
        int value = dimensionRestriction.valueInCentimeters;
        Log.d(TAG, "TruckRestriction for dimension: " + type.name() + ": " + value);

        String dimType = "n/a";
        if (type == DimensionRestrictionType.TRUCK_HEIGHT) {
            dimType = "HEIGHT";
        }
        if (type == DimensionRestrictionType.TRUCK_LENGTH) {
            dimType = "LENGTH";
        }
        if (type == DimensionRestrictionType.TRUCK_WIDTH) {
            dimType = "WIDTH";
        }
        String dimValue = "" + getMeters(value) + "m";
        String description = dimType + ": " + dimValue;
        handleTruckRestrictions(description, distanceType);
    }

    // For this example, we always show only the next restriction ahead.
    // In case there are multiple restrictions ahead,
    // the nearest one will be shown after the current one has passed by.
    private void handleTruckRestrictions(String newDescription, DistanceType distanceType) {
        if (distanceType == DistanceType.PASSED) {
            if (activeTruckRestrictionWarnings.size() > 0) {
                // Remove the oldest entry from the list that equals the description.
                activeTruckRestrictionWarnings.remove(newDescription);
            } else {
                // Should never happen.
                throw new RuntimeException("Passed a restriction that was never added.");
            }

            if (activeTruckRestrictionWarnings.isEmpty()) {
                // No more restrictions ahead.
                uiCallback.onHideTruckRestrictionWarning();
                return;
            } else {
                // Show the next restriction ahead which will be the first item in the list.
                uiCallback.onTruckRestrictionWarning(activeTruckRestrictionWarnings.get(0));
                return;
            }
        }

        if (distanceType == DistanceType.REACHED) {
            // We reached a restriction which is already shown, so nothing to do here.
            return;
        }

        if (distanceType == DistanceType.AHEAD) {
            if (activeTruckRestrictionWarnings.isEmpty()) {
                // Show the first restriction.
                uiCallback.onTruckRestrictionWarning(newDescription);
                activeTruckRestrictionWarnings.add(newDescription);
            } else {
                // Do not show the restriction yet. We'll show it when the previous restrictions passed by.
                // Add the restriction to the end of the list.
                activeTruckRestrictionWarnings.add(newDescription);
            }
            return;
        }

        Log.e(TAG, "Unknown distance type.");
    }

    private int getTons(int valueInKilograms) {
        // Convert kilograms to tons.
        double valueInTons = valueInKilograms / 1000.0;
        // Round to one digit after the decimal point.
        double roundedValue = Math.round(valueInTons * 10.0) / 10.0;
        // Convert the rounded value back to integer and return.
        return (int) roundedValue;
    }

    private int getMeters(int valueInCentimeters) {
        // Convert centimeters to meters.
        double valueInMeters = valueInCentimeters / 100.0;
        // Round to one digit after the decimal point.
        double roundedValue = Math.round(valueInMeters * 10.0) / 10.0;
        // Convert the rounded value back to integer and return.
        return (int) roundedValue;
    }

    private static double metersPerSecondToKilometersPerHour(double metersPerSecond) {
        return metersPerSecond * 3.6;
    }

    // Use a LongPress handler to define start / destination waypoints.
    private void setLongPressGestureHandler(MapView mapView) {
        mapView.getGestures().setLongPressListener((gestureState, touchPoint) -> {
            GeoCoordinates geoCoordinates = mapView.viewToGeoCoordinates(touchPoint);
            if (geoCoordinates == null) {
                showDialog("Note", "Invalid GeoCoordinates.");
                return;
            }
            if (gestureState == GestureState.BEGIN) {
                // Set new route start or destination geographic coordinates based on long press location.
                if (changeDestination) {
                    destinationGeoCoordinates = geoCoordinates;
                    destinationMapMarker.setCoordinates(geoCoordinates);
                } else {
                    startGeoCoordinates = geoCoordinates;
                    startMapMarker.setCoordinates(geoCoordinates);
                }
                // Toggle the marker that should be updated on next long press.
                changeDestination = !changeDestination;
            }
        });
    }

    // Get the waypoint list using the last two long press points.
    private List<Waypoint> getCurrentWaypoints() {
        Waypoint startWaypoint = new Waypoint(startGeoCoordinates);
        Waypoint destinationWaypoint = new Waypoint(destinationGeoCoordinates);
        List<Waypoint> waypoints =
                new ArrayList<>(Arrays.asList(startWaypoint, destinationWaypoint));

        Log.d(TAG, "Start Waypoint: " + startWaypoint.coordinates.latitude + ", " + startWaypoint.coordinates.longitude);
        Log.d(TAG, "Destination Waypoint: " + destinationWaypoint.coordinates.latitude + ", " + destinationWaypoint.coordinates.longitude);

        return waypoints;
    }

    public void onShowRouteButtonClicked() {
        routingEngine.calculateRoute(getCurrentWaypoints(), createTruckOptions(), (routingError, list) -> {
             handleTruckRouteResults(routingError, list);
        });
    }

    public void onStartStopButtonClicked() {
        if (lastCalculatedTruckRoute == null) {
            showDialog("Note","Show a route first.");
            return;
        }

        isGuidance = !isGuidance;
        if (isGuidance) {
            // Start guidance.
            visualNavigator.setRoute(lastCalculatedTruckRoute);
            startRendering();
            showDialog("Note","Started guidance.");
        } else {
            // Stop guidance.
            visualNavigator.setRoute(null);
            stopRendering();
            isTracking = false;
            showDialog("Note","Stopped guidance.");
        }
    }

    public void onTrackingButtonClicked() {
        if (lastCalculatedTruckRoute == null) {
            showDialog("Note","Show a route first.");
            return;
        }

        isTracking = !isTracking;
        if (isTracking) {
            // Start tracking.
            visualNavigator.setRoute(null);
            startRendering();
            // Note that during tracking the above set TransportProfile becomes active to receive
            // suitable speed limits.
            showDialog("Note","Started tracking along the last calculated route.");
        } else {
            // Stop tracking.
            visualNavigator.setRoute(null);
            stopRendering();
            isGuidance = false;
            showDialog("Note","Stopped tracking.");
        }
    }

    private void startRendering() {
        visualNavigator.startRendering(mapView);
        herePositioningSimulator.setSpeedFactor(simulationSpeedFactor);
        herePositioningSimulator.startLocating(visualNavigator, navigator, lastCalculatedTruckRoute);
    }

    private void stopRendering() {
        visualNavigator.stopRendering();
        herePositioningSimulator.stopLocating();
        uiCallback.onDrivingSpeed("n/a");
        uiCallback.onTruckSpeedLimit("n/a");
        uiCallback.onCarSpeedLimit("n/a");
        untiltUnrotateMap();
    }

    private void untiltUnrotateMap() {
        double bearingInDegress = 0;
        double tiltInDegress = 0;
        mapView.getCamera().setOrientationAtTarget(new GeoOrientationUpdate(bearingInDegress, tiltInDegress));
    }

    public void onSpeedButtonClicked() {
        // Toggle simulation speed factor.
        if (simulationSpeedFactor == 1) {
            simulationSpeedFactor = 8;
        } else {
            simulationSpeedFactor = 1;
        }

        showDialog("Note","Changed simulation speed factor to " + simulationSpeedFactor +
                ". Start again to use the new value.");
    }

    private void handleTruckRouteResults(RoutingError routingError, List<Route> routes) {
        if (routingError != null) {
            showDialog("Error while calculating a truck route: ", routingError.toString());
            return;
        }

        // When routingError is nil, routes is guaranteed to contain at least one route.
        lastCalculatedTruckRoute = routes.get(0);

        // Search along the route for truck amenities.
        searchAlongARoute(lastCalculatedTruckRoute);

        for (Route route : routes) {
            logRouteViolations(route);
        }

        Color truckRouteColor = Color.valueOf(0, 0.6f, 1, 1); // RGBA
        int truckRouteWidthInPixels = 30;
        showRouteOnMap(lastCalculatedTruckRoute, truckRouteColor, truckRouteWidthInPixels);
    }

    private TruckOptions createTruckOptions() {
        TruckOptions truckOptions = new TruckOptions();
        truckOptions.routeOptions.enableTolls = true;

        AvoidanceOptions avoidanceOptions = new AvoidanceOptions();
        avoidanceOptions.roadFeatures = Arrays.asList(
                RoadFeatures.U_TURNS,
                RoadFeatures.FERRY,
                RoadFeatures.DIRT_ROAD,
                RoadFeatures.TUNNEL,
                RoadFeatures.CAR_SHUTTLE_TRAIN);
        // Exclude emission zones to not pollute the air in sensible inner city areas.
        avoidanceOptions.zoneCategories = Arrays.asList(ZoneCategory.ENVIRONMENTAL);
        truckOptions.avoidanceOptions = avoidanceOptions;
        truckOptions.truckSpecifications = createTruckSpecifications();

        return truckOptions;
    }

    // A route may contain several warnings, for example, when a certain route option could not be fulfilled.
    // An implementation may decide to reject a route if one or more violations are detected.
    private void logRouteViolations(Route route) {
        Log.d("RouteViolations", "Log route violations (if any).");
        List<Section> sections = route.getSections();
        int sectionNr = -1;
        for (Section section : sections) {
            sectionNr++;
            for (SectionNotice sectionNotice : section.getSectionNotices()) {
                // For example, if code is VIOLATED_AVOID_FERRY, then the route contains a ferry, although it
                // was requested to avoid ferries in RouteOptions.AvoidanceOptions.
                Log.d("RouteViolations", "Section " + sectionNr + ": " +
                        "This route contains the following warning: " + sectionNotice.code);

                // Get violated truck vehicle restrictions.
                for (ViolatedRestriction violatedRestriction : sectionNotice.violatedRestrictions) {
                    // A human readable description of the violated restriction.
                    String cause = violatedRestriction.cause;
                    Log.d("ViolatedRestriction", "RouteViolation cause: " + cause);
                    // If true, the violated restriction is time-dependent.
                    boolean timeDependent = violatedRestriction.timeDependent;
                    Log.d("ViolatedRestriction", "timeDependent: " + timeDependent);
                    ViolatedRestriction.Details details = violatedRestriction.details;
                    if (details == null) {
                        // No details. This may happen when the route violates a time-dependent restriction,
                        // for example, when trucks are not allowed on this section in the given time frame.
                        continue;
                    }
                    // The provided TruckSpecifications or TruckOptions are violated by the below values.
                    if (details.maxGrossWeightInKilograms != null) {
                        Log.d("ViolatedRestriction", "Section " + sectionNr + ": " +
                                "Exceeded maxGrossWeightInKilograms: " + details.maxGrossWeightInKilograms);
                    }
                    if (details.maxWeightPerAxleInKilograms != null) {
                        Log.d("ViolatedRestriction", "Section " + sectionNr + ": " +
                                "Exceeded maxWeightPerAxleInKilograms: " + details.maxWeightPerAxleInKilograms);
                    }
                    if (details.maxHeightInCentimeters != null) {
                        Log.d("ViolatedRestriction", "Section " + sectionNr + ": " +
                                "Exceeded maxHeightInCentimeters: " + details.maxHeightInCentimeters);
                    }
                    if (details.maxWidthInCentimeters != null) {
                        Log.d("ViolatedRestriction", "Section " + sectionNr + ": " +
                                "Exceeded maxWidthInCentimeters: " + details.maxWidthInCentimeters);
                    }
                    if (details.maxLengthInCentimeters != null) {
                        Log.d("ViolatedRestriction", "Section " + sectionNr + ": " +
                                "Exceeded maxLengthInCentimeters: " + details.maxLengthInCentimeters);
                    }
                    if (details.forbiddenAxleCount != null) {
                        Log.d("ViolatedRestriction", "Section " + sectionNr + ": " +
                                "Inside of forbiddenAxleCount range: " + details.forbiddenAxleCount.min
                                        + " - " + details.forbiddenAxleCount.max);
                    }
                    if (details.forbiddenTrailerCount != null) {
                        Log.d("ViolatedRestriction", "Section " + sectionNr + ": " +
                                "Inside of forbiddenTrailerCount range: " + details.forbiddenTrailerCount.min
                                        + " - " + details.forbiddenAxleCount.max);
                    }
                    if (details.maxTunnelCategory != null) {
                        Log.d("ViolatedRestriction", "Section " + sectionNr + ": " +
                                "Exceeded maxTunnelCategory: " + details.maxTunnelCategory.name());
                    }
                    if (details.forbiddenTruckType != null) {
                        Log.d("ViolatedRestriction", "Section " + sectionNr + ": " +
                                "ForbiddenTruckType is required: " + details.forbiddenTruckType.name());
                    }

                    for (HazardousMaterial hazardousMaterial : details.forbiddenHazardousGoods) {
                        Log.d("ViolatedRestriction", "Section " + sectionNr + ": " +
                                "Forbidden hazardousMaterial carried: " + hazardousMaterial.name());
                    }
                }
            }
        }
    }

    private void searchAlongARoute(Route route) {
        // We specify here that we only want to include results
        // within a max distance of xx meters from any point of the route.
        int halfWidthInMeters = 200;
        GeoCorridor routeCorridor = new GeoCorridor(route.getGeometry().vertices, halfWidthInMeters);

        // Not all place categories are predefined as part of the PlaceCategory class. Find more here:
        // https://developer.here.com/documentation/geocoding-search-api/dev_guide/topics-places/introduction.html
        String TRUCK_PARKING = "700-7900-0131";
        String TRUCK_STOP_PLAZA = "700-7900-0132";

        List<PlaceCategory> placeCategoryList = Arrays.asList(
                new PlaceCategory(PlaceCategory.ACCOMMODATION),
                new PlaceCategory(PlaceCategory.FACILITIES_PARKING),
                new PlaceCategory(PlaceCategory.AREAS_AND_BUILDINGS),
                new PlaceCategory(TRUCK_PARKING),
                new PlaceCategory(TRUCK_STOP_PLAZA));

        CategoryQuery.Area categoryQueryArea = new CategoryQuery.Area(routeCorridor);
        CategoryQuery categoryQuery = new CategoryQuery(placeCategoryList, categoryQueryArea);

        SearchOptions searchOptions = new SearchOptions();
        searchOptions.languageCode = LanguageCode.EN_US;
        searchOptions.maxItems = 30;

        // Note that TruckAmenities require this custom setting.
        searchEngine.setCustomOption("show", "truck");

        searchEngine.search(categoryQuery, searchOptions, new SearchCallback() {
            @Override
            public void onSearchCompleted(SearchError searchError, List<Place> items) {
                if (searchError != null) {
                    if (searchError == SearchError.POLYLINE_TOO_LONG) {
                        // Increasing halfWidthInMeters will result in less precise results with the benefit of a less
                        // complex route shape.
                        Log.d("Search", "Route too long or halfWidthInMeters too small.");
                    } else {
                        Log.d("Search", "No places found along the route. Error: " + searchError);
                    }
                    return;
                }

                // If error is nil, it is guaranteed that the items will not be nil.
                Log.d("Search","Search along route found " + items.size() + " places:");
                for (Place place : items) {
                    logPlaceAmenities(place);
                }
            }
        });
    }

    private void logPlaceAmenities(Place place) {
        TruckAmenities truckAmenities = place.getDetails().truckAmenities;
        if (truckAmenities != null) {
            Log.d("Search","Found place with truck amenities: " + place.getTitle());

            // All amenities can be true or false at the same time.
            // You can use this information like in a bitmask to visualize the possible amenities.
            Log.d(TAG,"This place hasParking: " + truckAmenities.hasParking);
            Log.d(TAG,"This place hasSecureParking: " + truckAmenities.hasSecureParking);
            Log.d(TAG,"This place hasCarWash: " + truckAmenities.hasCarWash);
            Log.d(TAG,"This place hasTruckWash: " + truckAmenities.hasTruckWash);
            Log.d(TAG,"This place hasHighCanopy: " + truckAmenities.hasHighCanopy);
            Log.d(TAG,"This place hasIdleReductionSystem: " + truckAmenities.hasIdleReductionSystem);
            Log.d(TAG,"This place hasTruckScales: " + truckAmenities.hasTruckScales);
            Log.d(TAG,"This place hasPowerSupply: " + truckAmenities.hasPowerSupply);
            Log.d(TAG,"This place hasChemicalToiletDisposal: " + truckAmenities.hasChemicalToiletDisposal);
            Log.d(TAG,"This place hasTruckStop: " + truckAmenities.hasTruckStop);
            Log.d(TAG,"This place hasWifi: " + truckAmenities.hasWifi);
            Log.d(TAG,"This place hasTruckService: " + truckAmenities.hasTruckService);
            Log.d(TAG,"This place hasShower: " + truckAmenities.hasShower);

            if (truckAmenities.showerCount != null) {
                Log.d(TAG,"This place " + truckAmenities.showerCount + " showers.");
            }
        }
    }

    private void showRouteOnMap(Route route, Color color, int widthInPixels) {
        // Show route as polyline.
        GeoPolyline routeGeoPolyline = route.getGeometry();
        MapPolyline routeMapPolyline = null;
        try {
            routeMapPolyline = new MapPolyline(routeGeoPolyline, new MapPolyline.SolidRepresentation(
                    new MapMeasureDependentRenderSize(RenderSize.Unit.PIXELS, widthInPixels),
                    color,
                    LineCap.ROUND));
        } catch (MapPolyline.Representation.InstantiationException e) {
            Log.e("MapPolyline Representation Exception:", e.error.name());
        } catch (MapMeasureDependentRenderSize.InstantiationException e) {
            Log.e("MapMeasureDependentRenderSize Exception:", e.error.name());
        }

        // Optionally, hide irrelevant icons from the vehicle restriction layer that cross our route. If the route crosses
        // such icons, then they are not applicable based on the provided TruckSpecifications.
        // By default, the restriction layer shows all restrictions independent of specific vehicle specifications.
        // Note that the VisualNavigator, too, hides all icons that cross the route during guidance.
        // routeMapPolyline.setMapContentCategoriesToBlock(Arrays.asList(MapContentCategory.VEHICLE_RESTRICTION_ICONS));

        mapView.getMapScene().addMapPolyline(routeMapPolyline);
        mapPolylines.add(routeMapPolyline);

        animateToRoute(route);
    }

    private void animateToRoute(Route route) {
        // We want to show the route fitting in the map view with an additional padding of 50 pixels.
        Point2D origin = new Point2D(50, 50);
        Size2D sizeInPixels = new Size2D(mapView.getWidth() - 100, mapView.getHeight() - 100);
        Rectangle2D mapViewport = new Rectangle2D(origin, sizeInPixels);

        // Animate to the route within a duration of 3 seconds.
        MapCameraUpdate update = MapCameraUpdateFactory.lookAt(
                route.getBoundingBox(),
                // The animation should result in an unrotated and untilted map.
                new GeoOrientationUpdate(0.0, 0.0),
                mapViewport);
        MapCameraAnimation animation =
                MapCameraAnimationFactory.createAnimation(update, Duration.ofMillis(2000), new Easing(EasingFunction.OUT_SINE));
        mapView.getCamera().startAnimation(animation);
    }

    public void onClearMapButtonClicked() {
        clearRoute();
        clearMapMarker();
    }

    private void clearRoute() {
        for (MapPolyline mapPolyline : mapPolylines) {
            mapView.getMapScene().removeMapPolyline(mapPolyline);
        }
        mapPolylines.clear();
    }

    private void clearMapMarker() {
        for (MapMarker mapMarker : mapMarkers) {
            mapView.getMapScene().removeMapMarker(mapMarker);
        }
        mapMarkers.clear();
    }

    private MapMarker addPOIMapMarker(GeoCoordinates geoCoordinates, int resourceId) {
        MapImage mapImage = MapImageFactory.fromResource(context.getResources(), resourceId);
        Anchor2D anchor2D = new Anchor2D(0.5F, 1);
        MapMarker mapMarker = new MapMarker(geoCoordinates, mapImage, anchor2D);
        mapView.getMapScene().addMapMarker(mapMarker);
        return mapMarker;
    }

    private void showDialog(String title, String message) {
        AlertDialog.Builder builder =
                new AlertDialog.Builder(context);
        builder.setTitle(title);
        builder.setMessage(message);
        builder.show();
    }
}
