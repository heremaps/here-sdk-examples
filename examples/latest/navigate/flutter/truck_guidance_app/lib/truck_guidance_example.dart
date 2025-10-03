/*
 * Copyright (C) 2019-2025 HERE Europe B.V.
 *
 * Licensed under the Apache License, Version 2.0 (the "License")
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
import 'dart:async';
import 'dart:ui';

import 'package:here_sdk/animation.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/gestures.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/navigation.dart';
import 'package:here_sdk/routing.dart';
import 'package:here_sdk/search.dart';
import 'package:here_sdk/transport.dart';

import 'HEREPositioningSimulator.dart';
import 'main.dart';

// A callback to notify the hosting widget.
typedef ShowDialogFunction = void Function(String title, String message);

/// A stub implementation for truck guidance.
/// In a real port you would use the HERE SDK Flutter APIs to perform routing,
/// navigation and listen for speed limit and restriction updates.
class TruckGuidanceExample {
  static final String TAG = 'TruckGuidanceExample';
  UICallback? uiCallback;
  List<MapMarker> mapMarkers = [];
  List<MapPolyline> mapPolylines = [];
  SearchEngine? _searchEngine;
  RoutingEngine? _routingEngine;
  // A route in Berlin - can be changed via long tap.
  GeoCoordinates _startGeoCoordinates = GeoCoordinates(52.450798, 13.449408);
  GeoCoordinates _destinationGeoCoordinates = GeoCoordinates(52.620798, 13.409408);
  MapMarker? _startMapMarker;
  MapMarker? _destinationMapMarker;
  bool changeDestination = true;
  VisualNavigator? _visualNavigator;
  Navigator? _navigator;
  List<String> activeTruckRestrictionWarnings = [];
  HEREPositioningSimulator? _herePositioningSimulator;
  double _simulationSpeedFactor = 1;
  Route? lastCalculatedTruckRoute;
  bool _isGuidance = false;
  bool _isTracking = false;

  final HereMapController _hereMapController;
  final ShowDialogFunction _showDialog;

  TruckGuidanceExample(ShowDialogFunction showDialogCallback, HereMapController hereMapController)
    : _showDialog = showDialogCallback,
      _hereMapController = hereMapController {
    MapCamera camera = _hereMapController.camera;
    // Center map in Berlin.
    double distanceToEarthInMeters = 1000 * 90;
    MapMeasure mapMeasureZoom = MapMeasure(MapMeasureKind.distanceInMeters, distanceToEarthInMeters);
    camera.lookAtPointWithMeasure(GeoCoordinates(52.520798, 13.409408), mapMeasureZoom);

    try {
      // We use the search engine to find places along a route.
      _searchEngine = SearchEngine();
    } on InstantiationException catch (e) {
      throw ("Initialization of SearchEngine failed: " + e.error.name);
    }

    try {
      // We use routing engine to calculate a route.
      _routingEngine = RoutingEngine();
    } on InstantiationException catch (e) {
      throw ("Initialization of RoutingEngine failed: " + e.error.name);
    }

    try {
      // The Visual Navigator will be used for truck navigation.
      _visualNavigator = VisualNavigator();
    } on InstantiationException catch (e) {
      throw ("Initialization of VisualNavigator failed: " + e.error.name);
    }

    try {
      // A headless Navigator to receive car speed limits in parallel.
      // This instance is running in tracking mode for its entire lifetime.
      // By default, the navigator will receive car speed limits.
      _navigator = new Navigator();
    } on InstantiationException catch (e) {
      throw ("Initialization of Navigator failed: " + e.error.name);
    }

    // Create a TransportProfile instance.
    // This profile is currently only used to retrieve speed limits during tracking mode
    // when no route is set to the VisualNavigator instance.
    // This profile needs to be set only once during the lifetime of the VisualNavigator
    // instance - unless it should be updated.
    // Note that currently not all parameters are consumed, see API Reference for details.
    TransportProfile transportProfile = TransportProfile();
    transportProfile.vehicleProfile = _createVehicleProfile();
    _visualNavigator?.trackingTransportProfile = transportProfile;

    _enableLayers();
    _setTapGestureHandler();
    _setupListeners();

    _herePositioningSimulator = HEREPositioningSimulator();

    // Draw a circle to indicate the currently selected starting point and destination.
    _startMapMarker = _addPOIMapMarker(_startGeoCoordinates, "assets/poi_start.png");
    _destinationMapMarker = _addPOIMapMarker(_destinationGeoCoordinates, "assets/poi_destination.png");

    _setLongPressGestureHandler(_hereMapController);
    _showDialog("Note", "Do a long press to change start and destination coordinates. " + "Map icons are pickable.");
    // Initialize HERE SDK components, map view gestures, etc.
    // For now, this is a stub.
    print("TruckGuidanceExample initialized.");
  }

  // Allow simple communication with the example class and update our UI based
  // on the events we get from the visual navigator.
  void setUICallback(UICallback callback) {
    uiCallback = callback;
    // Optionally start simulation updates here.
    // For demonstration, we simulate periodic speed updates.
    Timer.periodic(Duration(seconds: 5), (timer) {
      if (uiCallback != null) {
        uiCallback!.onTruckSpeedLimit("80");
        uiCallback!.onCarSpeedLimit("100");
        uiCallback!.onDrivingSpeed("60");
      }
    });
  }

  // Used during tracking mode.
  VehicleProfile _createVehicleProfile() {
    VehicleProfile vehicleProfile = new VehicleProfile(VehicleType.truck);
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
  TruckSpecifications _createTruckSpecifications() {
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

  // Enable layers that may be useful for truck drivers.
  void _enableLayers() {
    final Map<String, String> mapFeatures = {
      MapFeatures.trafficFlow: MapFeatureModes.trafficFlowWithFreeFlow,
      MapFeatures.trafficIncidents: MapFeatureModes.defaultMode,
      MapFeatures.safetyCameras: MapFeatureModes.defaultMode,
      MapFeatures.vehicleRestrictions: MapFeatureModes.defaultMode,
      MapFeatures.environmentalZones: MapFeatureModes.defaultMode,
      MapFeatures.congestionZones: MapFeatureModes.defaultMode,
      MapFeatures.truckPreferredRoads: MapFeatureModes.truckPreferredRoadsAll
    };

    _hereMapController.mapScene.enableFeatures(mapFeatures);
  }

  void _setTapGestureHandler() {
    _hereMapController.gestures.tapListener = TapListener((Point2D touchPoint) {
      // Lambda function body: do something with the touchPoint.
      print("Map tapped at: $touchPoint");
      pickCartoPois(touchPoint);
    });
  }

  // Allows to retrieve details from carto POIs including vehicleRestriction layer
  // and traffic incidents.
  // Note that restriction icons are not directly pickable: Only the restriction lines marking
  // the affected streets are pickable, but with a larger pick rectangle,
  // also the icons will become pickable indirectly.
  void pickCartoPois(Point2D touchPoint) {
    // Use a larger area to include multiple carto POIs.
    final rectangle2D = Rectangle2D(touchPoint, Size2D(50, 50));

    // Creates a list of map content type from which the results will be picked.
    // The content type values can be mapContent, mapItems and customLayerData.
    final contentTypesToPickFrom = <MapSceneMapPickFilterContentType>[];

    // mapContent is used when picking embedded carto POIs, traffic incidents, vehicle restriction etc.
    // mapItems is used when picking map items such as MapMarker, MapPolyline, MapPolygon etc.
    // Currently we need traffic incidents, vehicle restrictions so adding the mapContent filter.
    contentTypesToPickFrom.add(MapSceneMapPickFilterContentType.mapContent);
    final filter = MapSceneMapPickFilter(contentTypesToPickFrom);

    // Call the pick function on the mapView, passing the filter, rectangle and a callback.
    _hereMapController.pick(filter, rectangle2D, (mapPickResult) {
      if (mapPickResult == null) {
        // An error occurred while performing the pick operation.
        return;
      }

      final pickedMapContent = mapPickResult.mapContent;
      final cartoPOIList = pickedMapContent?.pickedPlaces;
      final trafficPOIList = pickedMapContent?.trafficIncidents;
      final vehicleRestrictionResultList = pickedMapContent?.vehicleRestrictions;

      // Note that pick here only the top most icon and ignore others that may be underneath.
      if (cartoPOIList!.isNotEmpty) {
        final pickedPlace = cartoPOIList.first;
        print("Carto POI picked: ${pickedPlace.name}, Place category: ${pickedPlace.placeCategoryId}");

        // Optionally, you can now use the SearchEngine or the OfflineSearchEngine to retrieve more details.
        _searchEngine?.searchByPickedPlace(pickedPlace, LanguageCode.enUs, (searchError, place) {
          if (searchError == null && place != null) {
            final address = place.address.addressText;
            String categories = "";
            for (var category in place.details.categories) {
              final name = category.name;
              if (name != null) {
                categories += "$name ";
              }
            }
            _showDialog("Carto POI", "$address. Categories: $categories");
          } else {
            print("searchPickedPlace() resulted in an error: ${searchError?.name}");
          }
        });
      }

      // Handle traffic incidents.
      if (trafficPOIList!.isNotEmpty) {
        final topmostContent = trafficPOIList.first;
        _showDialog("Traffic incident picked", "Type: ${topmostContent.type.name}");
        // Optionally, use the TrafficEngine to retrieve more details.
      }

      // Handle vehicle restrictions.
      if (vehicleRestrictionResultList!.isNotEmpty) {
        final topmostContent = vehicleRestrictionResultList.first;
        // Note that the text property may be empty for general truck restrictions.
        _showDialog(
          "Vehicle restriction picked:",
          "Location: ${topmostContent.coordinates.latitude}, ${topmostContent.coordinates.longitude}.",
        );
      }
    });
  }

  void _setupListeners() {
    // Notifies on the current map-matched location and other useful information while driving.
    _visualNavigator?.navigableLocationListener = NavigableLocationListener((
      NavigableLocation currentNavigableLocation,
    ) {
      final drivingSpeed = currentNavigableLocation.originalLocation.speedInMetersPerSecond;
      // Note that we ignore speedAccuracyInMetersPerSecond here for simplicity.
      if (drivingSpeed == null) {
        uiCallback!.onDrivingSpeed("n/a");
      } else {
        final kmh = metersPerSecondToKilometersPerHour(drivingSpeed).toInt();
        uiCallback!.onDrivingSpeed("$kmh");
      }
    });

    // Notifies on the current speed limit valid on the current road.
    // Used for the truck route.
    _visualNavigator?.speedLimitListener = SpeedLimitListener((speedLimit) {
      // For simplicity, we use here the effective legal speed limit. More differentiated speed values,
      // for example, due to weather conditions or school zones are also available.
      // See our Developer's Guide for more details.
      final currentSpeedLimit = speedLimit.effectiveSpeedLimitInMetersPerSecond();
      if (currentSpeedLimit == null) {
        print("Warning: Speed limits unknown, data could not be retrieved.");
        uiCallback!.onTruckSpeedLimit("n/a");
      } else if (currentSpeedLimit == 0) {
        print("No speed limits on this road! Drive as fast as you feel safe ...");
        uiCallback!.onTruckSpeedLimit("NSL");
      } else {
        print("Current speed limit (m/s): $currentSpeedLimit");
        final kmh = metersPerSecondToKilometersPerHour(currentSpeedLimit).toInt();
        uiCallback!.onTruckSpeedLimit("$kmh");
      }
    });

    // Notifies on the current speed limit valid on the current road.
    // Note that this navigator instance is running in tracking mode without following a route.
    // It receives the same location updates as the visual navigator.
    _navigator?.speedLimitListener = SpeedLimitListener((speedLimit) {
      final currentSpeedLimit = speedLimit.effectiveSpeedLimitInMetersPerSecond();
      if (currentSpeedLimit == null) {
        print("Warning: Car speed limits unknown, data could not be retrieved.");
        uiCallback!.onCarSpeedLimit("n/a");
      } else if (currentSpeedLimit == 0) {
        print("No speed limits for cars on this road! Drive as fast as you feel safe ...");
        uiCallback!.onCarSpeedLimit("NSL");
      } else {
        print("Current car speed limit (m/s): $currentSpeedLimit");
        final kmh = metersPerSecondToKilometersPerHour(currentSpeedLimit).toInt();
        uiCallback!.onCarSpeedLimit("$kmh");
      }
    });

    // Notifies truck drivers on road restrictions ahead. Called whenever there is a change.
    // For example, there can be a bridge ahead not high enough to pass a big truck
    // or there can be a road ahead where the weight of the truck is beyond it's permissible weight.
    // This event notifies on truck restrictions in general,
    // so it will also deliver events, when the transport type was set to a non-truck transport type.
    // The given restrictions are based on the HERE database of the road network ahead.
    _visualNavigator?.truckRestrictionsWarningListener = TruckRestrictionsWarningListener((
      List<TruckRestrictionWarning> list,
    ) {
      // The list is guaranteed to be non-empty.
      for (final truckRestrictionWarning in list) {
        if (truckRestrictionWarning.timeRule != null && !truckRestrictionWarning.timeRule!.appliesTo(DateTime.now())) {
          // For example, during a specific time period of a day, some truck restriction warnings do not apply.
          // If truckRestrictionWarning.timeRule is null, the warning applies at anytime.
          // Note: For this example, we do not skip any restriction.
          // continue;
          print("Note that this truck restriction warning currently does not apply.");
        }

        // The trailer count for which the current restriction applies.
        // If the field is null then the current restriction is valid regardless of trailer count.
        if (truckRestrictionWarning.trailerCount != null && MyTruckSpecs.trailerCount != null) {
          final min = truckRestrictionWarning.trailerCount!.min;
          final max = truckRestrictionWarning.trailerCount!.max; // may be null.
          if (min > MyTruckSpecs.trailerCount || (max != null && max < MyTruckSpecs.trailerCount)) {
            // The restriction is not valid for this truck.
            // (For this example, we do not skip any restriction.)
          }
        }

        final distanceType = truckRestrictionWarning.distanceType;
        if (distanceType == DistanceType.ahead) {
          print("A TruckRestriction ahead in: ${truckRestrictionWarning.distanceInMeters} meters.");
        } else if (distanceType == DistanceType.reached) {
          print("A TruckRestriction has been reached.");
        } else if (distanceType == DistanceType.passed) {
          // If not preceded by a "REACHED"-notification, this restriction was valid only for the passed location.
          print("A TruckRestriction just passed.");
        }

        // One of the following restrictions applies, if more restrictions apply at the same time,
        // they are part of another TruckRestrictionWarning element contained in the list.
        if (truckRestrictionWarning.weightRestriction != null) {
          _handleWeightTruckWarning(truckRestrictionWarning.weightRestriction!, distanceType);
        } else if (truckRestrictionWarning.dimensionRestriction != null) {
          _handleDimensionTruckWarning(truckRestrictionWarning.dimensionRestriction!, distanceType);
        } else {
          _handleTruckRestrictions("No Trucks.", distanceType);
          print("TruckRestriction: General restriction - no trucks allowed.");
        }
      }
    });

    // Notifies on environmental zone warnings.
    _visualNavigator?.environmentalZoneWarningListener = EnvironmentalZoneWarningListener((
      List<EnvironmentalZoneWarning> list,
    ) {
      // The list is guaranteed to be non-empty.
      for (final environmentalZoneWarning in list) {
        final distanceType = environmentalZoneWarning.distanceType;
        if (distanceType == DistanceType.ahead) {
          print("An EnvironmentalZone ahead in: ${environmentalZoneWarning.distanceInMeters} meters.");
        } else if (distanceType == DistanceType.reached) {
          print("An EnvironmentalZone has been reached.");
        } else if (distanceType == DistanceType.passed) {
          print("An EnvironmentalZone just passed.");
        }

        // The official name of the environmental zone (example: "Zone basse émission Bruxelles").
        final name = environmentalZoneWarning.name;
        // The description of the environmental zone for the default language.
        final description = environmentalZoneWarning.description.getDefaultValue();
        // The environmental zone ID - uniquely identifies the zone in the HERE map data.
        final zoneID = environmentalZoneWarning.zoneId;
        // The website of the environmental zone, if available - null otherwise.
        final websiteUrl = environmentalZoneWarning.websiteUrl;
        print("environmentalZoneWarning: description: $description");
        print("environmentalZoneWarning: name: $name");
        print("environmentalZoneWarning: zoneID: $zoneID");
        print("environmentalZoneWarning: websiteUrl: $websiteUrl");
      }
    });

    // For more warners and events during guidance, please check the Navigation example app, available on GitHub.
  }

  void _handleWeightTruckWarning(WeightRestriction weightRestriction, DistanceType distanceType) {
    WeightRestrictionType type = weightRestriction.type;
    int value = weightRestriction.valueInKilograms;
    print("TruckRestriction for weight (kg): ${type.name}: $value");

    String weightType = "n/a";
    if (type == WeightRestrictionType.truckWeight) {
      weightType = "WEIGHT";
    }
    if (type == WeightRestrictionType.weightPerAxle) {
      weightType = "WEIGHTPA";
    }
    final weightValue = "${_getTons(value)}t";
    final description = "$weightType: $weightValue";
    _handleTruckRestrictions(description, distanceType);
  }

  void _handleDimensionTruckWarning(DimensionRestriction dimensionRestriction, DistanceType distanceType) {
    // Can be either a length, width or height restriction for a truck. For example, a height
    // restriction can apply for a tunnel.
    DimensionRestrictionType type = dimensionRestriction.type;
    int value = dimensionRestriction.valueInCentimeters;
    print("TruckRestriction for dimension: ${type.name}: $value");

    String dimType = "n/a";
    if (type == DimensionRestrictionType.truckHeight) {
      dimType = "HEIGHT";
    }
    if (type == DimensionRestrictionType.truckLength) {
      dimType = "LENGTH";
    }
    if (type == DimensionRestrictionType.truckWidth) {
      dimType = "WIDTH";
    }
    String dimValue = "${_getMeters(value)}m";
    String description = "$dimType: $dimValue";
    _handleTruckRestrictions(description, distanceType);
  }

  // For this example, we always show only the next restriction ahead.
  // In case there are multiple restrictions ahead,
  // the nearest one will be shown after the current one has passed by.
  void _handleTruckRestrictions(String newDescription, DistanceType distanceType) {
    if (distanceType == DistanceType.passed) {
      if (activeTruckRestrictionWarnings.isNotEmpty) {
        // Remove the oldest entry from the list that equals the description.
        activeTruckRestrictionWarnings.remove(newDescription);
      } else {
        throw Exception("Passed a restriction that was never added.");
      }
      if (activeTruckRestrictionWarnings.isEmpty) {
        uiCallback!.onHideTruckRestrictionWarning();
        return;
      } else {
        // Show the next restriction ahead which will be the first item in the list.
        uiCallback!.onTruckRestrictionWarning(activeTruckRestrictionWarnings.first);
        return;
      }
    }

    if (distanceType == DistanceType.reached) {
      // We reached a restriction which is already shown, so nothing to do here.
      return;
    }

    if (distanceType == DistanceType.ahead) {
      if (activeTruckRestrictionWarnings.isEmpty) {
        // Show the first restriction.
        uiCallback!.onTruckRestrictionWarning(newDescription);
        activeTruckRestrictionWarnings.add(newDescription);
      } else {
        // Do not show the restriction yet. We'll show it when the previous restrictions passed by.
        // Add the restriction to the end of the list.
        activeTruckRestrictionWarnings.add(newDescription);
      }
      return;
    }

    print("Unknown distance type.");
  }

  int _getTons(int valueInKilograms) {
    // Convert kilograms to tons.
    double valueInTons = valueInKilograms / 1000.0;
    // Round to one digit after the decimal point.
    double roundedValue = (valueInTons * 10).round() / 10.0;
    return roundedValue.toInt();
  }

  int _getMeters(int valueInCentimeters) {
    // Convert centimeters to meters.
    double valueInMeters = valueInCentimeters / 100.0;
    // Round to one digit after the decimal point.
    double roundedValue = (valueInMeters * 10).round() / 10.0;
    // Convert the rounded value back to integer and return.
    return roundedValue.toInt();
  }

  double metersPerSecondToKilometersPerHour(double metersPerSecond) {
    return metersPerSecond * 3.6;
  }

  // Use a LongPress handler to define start / destination waypoints.
  void _setLongPressGestureHandler(HereMapController hereMapController) {
    // Use a long-press listener to define start/destination waypoints.
    hereMapController.gestures.longPressListener = LongPressListener((GestureState gestureState, Point2D touchPoint) {
      final geoCoordinates = hereMapController.viewToGeoCoordinates(touchPoint);
      if (geoCoordinates == null) {
        _showDialog("Note", "Invalid GeoCoordinates.");
        return;
      }
      if (gestureState == GestureState.begin) {
        // Set new route start or destination geographic coordinates based on long press location.
        if (changeDestination) {
          _destinationGeoCoordinates = geoCoordinates;
          _destinationMapMarker!.coordinates = geoCoordinates;
        } else {
          _startGeoCoordinates = geoCoordinates;
          _startMapMarker!.coordinates = geoCoordinates;
        }
        // Toggle the marker that should be updated on next long press.
        changeDestination = !changeDestination;
      }
    });
  }

  List<Waypoint> _getCurrentWaypoints() {
    final startWaypoint = Waypoint(_startGeoCoordinates);
    final destinationWaypoint = Waypoint(_destinationGeoCoordinates);
    final waypoints = [startWaypoint, destinationWaypoint];

    print("Start Waypoint: ${startWaypoint.coordinates.latitude}, ${startWaypoint.coordinates.longitude}");
    print(
      "Destination Waypoint: ${destinationWaypoint.coordinates.latitude}, ${destinationWaypoint.coordinates.longitude}",
    );

    return waypoints;
  }

  void onShowRouteButtonClicked() {
    _routingEngine?.calculateTruckRoute(_getCurrentWaypoints(), _createTruckOptions(), (routingError, routes) {
      _handleTruckRouteResults(routingError, routes!);
    });
  }

  void _startRendering() {
    _visualNavigator?.startRendering(_hereMapController);
    _herePositioningSimulator?.setSpeedFactor(_simulationSpeedFactor);
    _herePositioningSimulator?.startLocating(_visualNavigator!, _navigator!, lastCalculatedTruckRoute!);
  }

  void _stopRendering() {
    _visualNavigator?.stopRendering();
    _herePositioningSimulator?.stopLocating();
    uiCallback!.onDrivingSpeed("n/a");
    uiCallback!.onTruckSpeedLimit("n/a");
    uiCallback!.onCarSpeedLimit("n/a");
    _unTiltUnRotateMap();
  }

  void _unTiltUnRotateMap() {
    final bearingInDegrees = 0.0;
    final tiltInDegrees = 0.0;
    _hereMapController.camera.setOrientationAtTarget(GeoOrientationUpdate(bearingInDegrees, tiltInDegrees));
  }

  void onSpeedButtonClicked() {
    // Toggle simulation speed factor.
    _simulationSpeedFactor = (_simulationSpeedFactor == 1) ? 8 : 1;
    _showDialog(
      "Note",
      "Changed simulation speed factor to $_simulationSpeedFactor. Start again to use the new value.",
    );
  }

  void _handleTruckRouteResults(RoutingError? routingError, List<Route> routes) {
    if (routingError != null) {
      _showDialog("Error while calculating a truck route: ", routingError.toString());
      return;
    }

    // When no error, routes contains at least one route.
    lastCalculatedTruckRoute = routes.first;

    // Search along the route for truck amenities.
    _searchAlongARoute(lastCalculatedTruckRoute!);

    for (final route in routes) {
      _logRouteViolations(route);
    }

    // Create a truck route color (RGBA). Adjust as needed for your Flutter color class.
    final truckRouteColor = Color.fromRGBO(0, 153, 255, 1.0); // For example, a shade of blue.
    const truckRouteWidthInPixels = 30.0;
    _showRouteOnMap(lastCalculatedTruckRoute!, truckRouteColor, truckRouteWidthInPixels);
  }

  void onStartStopButtonClicked() {
    if (lastCalculatedTruckRoute == null) {
      _showDialog("Note", "Show a route first.");
      return;
    }

    _isGuidance = !_isGuidance;
    if (_isGuidance) {
      // Start guidance.
      _visualNavigator?.route = lastCalculatedTruckRoute;
      _startRendering();
      _showDialog("Note", "Started guidance.");
    } else {
      // Stop guidance.
      _visualNavigator?.route = null;
      _stopRendering();
      _isTracking = false;
      _showDialog("Note", "Stopped guidance.");
    }
  }

  void onTrackingButtonClicked() {
    if (lastCalculatedTruckRoute == null) {
      _showDialog("Note", "Show a route first.");
      return;
    }

    _isTracking = !_isTracking;
    if (_isTracking) {
      // Start tracking.
      _visualNavigator?.route = null;
      _startRendering();
      // During tracking the set TransportProfile becomes active to receive suitable speed limits.
      _showDialog("Note", "Started tracking along the last calculated route.");
    } else {
      // Stop tracking.
      _visualNavigator?.route = null;
      _stopRendering();
      _isGuidance = false;
      _showDialog("Note", "Stopped tracking.");
    }
  }

  // Returns a TruckOptions instance configured for truck routing.
  TruckOptions _createTruckOptions() {
    TruckOptions truckOptions = TruckOptions();
    truckOptions.routeOptions.enableTolls = true;

    AvoidanceOptions avoidanceOptions = AvoidanceOptions();
    avoidanceOptions.roadFeatures = [
      RoadFeatures.uTurns,
      RoadFeatures.ferry,
      RoadFeatures.dirtRoad,
      RoadFeatures.tunnel,
      RoadFeatures.carShuttleTrain,
    ];
    // Exclude emission zones to not pollute the air in sensitive inner city areas.
    avoidanceOptions.zoneCategories = [ZoneCategory.environmental];
    truckOptions.avoidanceOptions = avoidanceOptions;
    truckOptions.truckSpecifications = _createTruckSpecifications();

    return truckOptions;
  }

  // A route may contain several warnings, for example, when a certain route option could not be fulfilled.
  // An implementation may decide to reject a route if one or more violations are detected.
  void _logRouteViolations(Route route) {
    print("RouteViolations: Log route violations (if any).");
    List<Section> sections = route.sections; // Assuming route.sections returns a List<Section>.
    int sectionNr = -1;
    for (Section section in sections) {
      sectionNr++;
      for (Span span in section.spans) {
        List<GeoCoordinates> spanGeometryVertices = span.geometry.vertices;
        // The violation spans the entire geometry.
        GeoCoordinates violationStartPoint = spanGeometryVertices.first;
        GeoCoordinates violationEndPoint = spanGeometryVertices.last;
        for (int index in span.noticeIndexes) {
          SectionNotice spanSectionNotice = section.sectionNotices[index];
          String violationCode = spanSectionNotice.code.toString();
          print(
            "Section $sectionNr: The violation $violationCode starts at ${toStringCoordinates(violationStartPoint)} and ends at ${toStringCoordinates(violationEndPoint)}.",
          );
        }
      }
      for (SectionNotice sectionNotice in section.sectionNotices) {
        for (ViolatedRestriction violatedRestriction in sectionNotice.violatedRestrictions) {
          String cause = violatedRestriction.cause;
          print("ViolatedRestriction: RouteViolation cause: $cause");
          bool timeDependent = violatedRestriction.timeDependent;
          print("ViolatedRestriction: timeDependent: $timeDependent");
          var details = violatedRestriction.details;
          if (details == null) continue;
          if (details.maxWeight != null) {
            print("ViolatedRestriction: Section $sectionNr: Exceeded maxWeightInKilograms: ${details.maxWeight}");
          }
          if (details.maxWeightPerAxleInKilograms != null) {
            print(
              "ViolatedRestriction: Section $sectionNr: Exceeded maxWeightPerAxleInKilograms: ${details.maxWeightPerAxleInKilograms}",
            );
          }
          if (details.maxHeightInCentimeters != null) {
            print(
              "ViolatedRestriction: Section $sectionNr: Exceeded maxHeightInCentimeters: ${details.maxHeightInCentimeters}",
            );
          }
          if (details.maxWidthInCentimeters != null) {
            print(
              "ViolatedRestriction: Section $sectionNr: Exceeded maxWidthInCentimeters: ${details.maxWidthInCentimeters}",
            );
          }
          if (details.maxLengthInCentimeters != null) {
            print(
              "ViolatedRestriction: Section $sectionNr: Exceeded maxLengthInCentimeters: ${details.maxLengthInCentimeters}",
            );
          }
          if (details.forbiddenAxleCount != null) {
            print(
              "ViolatedRestriction: Section $sectionNr: Inside of forbiddenAxleCount range: ${details.forbiddenAxleCount?.min} - ${details.forbiddenAxleCount?.max}",
            );
          }
          if (details.forbiddenTrailerCount != null) {
            print(
              "ViolatedRestriction: Section $sectionNr: Inside of forbiddenTrailerCount range: ${details.forbiddenTrailerCount?.min} - ${details.forbiddenTrailerCount?.max}",
            );
          }
          if (details.maxTunnelCategory != null) {
            print(
              "ViolatedRestriction: Section $sectionNr: Exceeded maxTunnelCategory: ${details.maxTunnelCategory?.name}",
            );
          }
          if (details.forbiddenTruckType != null) {
            print(
              "ViolatedRestriction: Section $sectionNr: ForbiddenTruckType is required: ${details.forbiddenTruckType?.name}",
            );
          }
          if (details.timeRule != null) {
            print(
              "ViolatedRestriction: Section $sectionNr: Violated time restriction: ${details.timeRule?.timeRuleString}",
            );
          }
          for (HazardousMaterial hazardousMaterial in details.forbiddenHazardousGoods) {
            print(
              "ViolatedRestriction: Section $sectionNr: Forbidden hazardousMaterial carried: ${hazardousMaterial.name}",
            );
          }
        }
      }
    }
  }

  // Helper method to create a human-readable string for GeoCoordinates.
  String toStringCoordinates(GeoCoordinates geoCoordinates) {
    return "${geoCoordinates.latitude}, ${geoCoordinates.longitude}";
  }

  // Searches for truck amenities along the given route.
  void _searchAlongARoute(Route route) {
    // Not all place categories are predefined as part of the PlaceCategory class. Find more here:
    // https://developer.here.com/documentation/geocoding-search-api/dev_guide/topics-places/introduction.html
    const String TRUCK_PARKING = "700-7900-0131";
    const String TRUCK_STOP_PLAZA = "700-7900-0132";

    List<PlaceCategory> placeCategoryList = [
      PlaceCategory(PlaceCategory.accommodation),
      PlaceCategory(PlaceCategory.facilitiesParking),
      PlaceCategory(PlaceCategory.areasAndBuildings),
      PlaceCategory(TRUCK_PARKING),
      PlaceCategory(TRUCK_STOP_PLAZA),
    ];

    // We specify here that we only want to include results
    // within a max distance of xx meters from any point of the route.
    int halfWidthInMeters = 200;
    List<GeoCoordinates> routeVertices = route.geometry.vertices;

    // The areaCenter specifies a prioritized point within the corridor.
    // You can choose any coordinate given it's closer to the route and within the corridor.
    // Following route calculation, the first relevant point is expected to be the start of the route,
    // but it can vary based on your use case.
    // For example, while travelling, you can set the current location of the user.
    GeoCoordinates areaCenter = routeVertices.first;
    GeoCorridor routeCorridor = GeoCorridor(routeVertices, halfWidthInMeters);
    CategoryQueryArea categoryQueryArea = CategoryQueryArea.withCorridorAndCenter(routeCorridor, areaCenter);
    CategoryQuery categoryQuery = CategoryQuery.withCategoriesInArea(placeCategoryList, categoryQueryArea);

    SearchOptions searchOptions = SearchOptions();
    searchOptions.languageCode = LanguageCode.enUs;
    searchOptions.maxItems = 30;

    // Note: TruckAmenities require a custom option when searching online.
    // This is not necessary when using the OfflineSearchEngine.
    // Additionally, this feature is released as closed-alpha, meaning a license must
    // be obtained from the HERE SDK team for online searches.
    // Otherwise, a SearchError.FORBIDDEN will occur.
    _searchEngine?.setCustomOption("show", "truck");

    _searchEngine?.searchByCategory(categoryQuery, searchOptions, (searchError, items) {
      if (searchError != null) {
        print("Search: No places found along the route. Error: $searchError");
        return;
      }
      // If error is nil, it is guaranteed that the items will not be nil.
      print("Search along route found ${items!.length} places:");
      for (Place place in items!) {
        _logPlaceAmenities(place);
      }
    });
  }

  // Note: This is a closed-alpha feature that requires an additional license.
  // Refer to the comment in searchAlongARoute() for more details.
  void _logPlaceAmenities(Place place) {
    TruckAmenities? truckAmenities = place.details.truckAmenities;
    if (truckAmenities != null) {
      print("Search: Found place with truck amenities: ${place.title}");
      print("This place hasParking: ${truckAmenities.hasParking}");
      print("This place hasSecureParking: ${truckAmenities.hasSecureParking}");
      print("This place hasCarWash: ${truckAmenities.hasCarWash}");
      print("This place hasTruckWash: ${truckAmenities.hasTruckWash}");
      print("This place hasHighCanopy: ${truckAmenities.hasHighCanopy}");
      print("This place hasIdleReductionSystem: ${truckAmenities.hasIdleReductionSystem}");
      print("This place hasTruckScales: ${truckAmenities.hasTruckScales}");
      print("This place hasPowerSupply: ${truckAmenities.hasPowerSupply}");
      print("This place hasChemicalToiletDisposal: ${truckAmenities.hasChemicalToiletDisposal}");
      print("This place hasTruckStop: ${truckAmenities.hasTruckStop}");
      print("This place hasWifi: ${truckAmenities.hasWifi}");
      print("This place hasTruckService: ${truckAmenities.hasTruckService}");
      print("This place hasShower: ${truckAmenities.hasShower}");
      if (truckAmenities.showerCount != null) {
        print("This place ${truckAmenities.showerCount} showers.");
      }
    }
  }

  // Displays the given route on the map as a polyline.
  void _showRouteOnMap(Route route, Color color, double widthInPixels) {
    GeoPolyline routeGeoPolyline = route.geometry;
    MapPolyline? routeMapPolyline;
    try {
      routeMapPolyline = MapPolyline.withRepresentation(
        routeGeoPolyline,
        MapPolylineSolidRepresentation(
          MapMeasureDependentRenderSize.withSingleSize(RenderSizeUnit.pixels, widthInPixels),
          color,
          LineCap.round,
        ),
      );
    } catch (e) {
      print("MapPolyline Representation Exception: $e");
    }

    // Optionally hide irrelevant icons from the vehicle restriction layer.
    _hereMapController.mapScene.addMapPolyline(routeMapPolyline!);
    mapPolylines.add(routeMapPolyline);

    _animateToRoute(route);
  }

  // Animates the map camera to show the route with a padding of 50 pixels.
  void _animateToRoute(Route route) {
    Point2D origin = Point2D(50, 50);
    Size2D sizeInPixels = Size2D(
      _hereMapController.viewportSize.width - 100,
      _hereMapController.viewportSize.height - 100,
    );
    Rectangle2D mapViewport = Rectangle2D(origin, sizeInPixels);

    MapCameraUpdate cameraUpdate = MapCameraUpdateFactory.lookAtAreaWithGeoOrientationAndViewRectangle(
      route.boundingBox,
      GeoOrientationUpdate(0.0, 0.0),
      mapViewport,
    );
    MapCameraAnimation animation = MapCameraAnimationFactory.createAnimationFromUpdateWithEasing(
      cameraUpdate,
      Duration(milliseconds: 2000),
      Easing(EasingFunction.outInSine),
    );

    _hereMapController.camera.startAnimation(animation);
  }

  // Called when the user clicks the "Clear Map" button.
  void onClearMapButtonClicked() {
    if (_isGuidance) {
      _showDialog("Note", "Turn-by-turn navigation must be stopped before clearing.");
      return;
    }
    clearRoute();
    clearMapMarker();
  }

  // Removes all route polylines from the map.
  void clearRoute() {
    for (MapPolyline mapPolyline in mapPolylines) {
      _hereMapController.mapScene.removeMapPolyline(mapPolyline);
    }
    mapPolylines.clear();
  }

  // Removes all map markers from the map.
  void clearMapMarker() {
    for (MapMarker mapMarker in mapMarkers) {
      _hereMapController.mapScene.removeMapMarker(mapMarker);
    }
    mapMarkers.clear();
  }

  MapMarker _addPOIMapMarker(GeoCoordinates geoCoordinates, String imageName) {
    // For this app, we only add images of size 60x60 pixels.
    int imageWidth = 60;
    int imageHeight = 60;
    // Note that you can reuse the same mapImage instance for other MapMarker instances
    // to save resources.
    MapImage mapImage = MapImage.withFilePathAndWidthAndHeight(imageName, imageWidth, imageHeight);
    MapMarker mapMarker = MapMarker(geoCoordinates, mapImage);
    _hereMapController.mapScene.addMapMarker(mapMarker);
    return mapMarker;
  }
}

// An immutable data class holding the definition of a truck.
class MyTruckSpecs {
  static final int grossWeightInKilograms = 17000; // 17 tons
  static final int heightInCentimeters = 3 * 100; // 3 meters
  static final int widthInCentimeters = 4 * 100; // 4 meters
  // The total length including all trailers (if any).
  static final int lengthInCentimeters = 8 * 100; // 8 meters
  static const int weightPerAxleInKilograms = 2 * 1000; // 2kilograms
  static final int axleCount = 4;
  static final int trailerCount = 2;
  static final TruckType truckType = TruckType.straight;
}
