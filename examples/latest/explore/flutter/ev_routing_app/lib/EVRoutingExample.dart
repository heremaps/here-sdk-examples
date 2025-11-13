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

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/core.threading.dart';
import 'package:here_sdk/gestures.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/routing.dart';
import 'package:here_sdk/routing.dart' as here;
import 'package:here_sdk/search.dart';

// A callback to notify the hosting widget.
typedef ShowDialogFunction = void Function(String title, String message);

// This example shows how to calculate routes for electric vehicles that contain necessary charging stations
// (indicated with red charging icon). In addition, all existing charging stations are searched along the route
// (indicated with green charging icon). You can also visualize the reachable area from your starting point
// (isoline routing).
class EVRoutingExample {
  final HereMapController _hereMapController;
  List<MapMarker> _mapMarkers = [];
  List<MapPolyline> _mapPolylines = [];
  List<MapPolygon> _mapPolygons = [];
  late RoutingEngine _routingEngine;
  late SearchEngine _searchEngine;
  late IsolineRoutingEngine _isolineRoutingEngine;
  GeoCoordinates? _startGeoCoordinates;
  GeoCoordinates? _destinationGeoCoordinates;
  final ShowDialogFunction _showDialog;
  List<String> chargingStationsIDs = [];
  TaskHandle? _currentRouteCalculationTask;

  // Metadata keys used when picking a charging station on the map.
  final String supplierNameMetadataKey = "supplierName";
  final String connectorCountMetadataKey = "connectorCount";
  final String availableConnectorsMetadataKey = "availableConnectors";
  final String occupiedConnectorsMetadataKey = "occupiedConnectors";
  final String outOfServiceConnectorsMetadataKey = "outOfServiceConnectors";
  final String reservedConnectorsMetadataKey = "reservedConnectors";
  final String lastUpdatedMetadataKey = "lastUpdated";
  final String requiredChargingMetadataKey = "requiredCharging";

  EVRoutingExample(ShowDialogFunction showDialogCallback, HereMapController hereMapController)
    : _showDialog = showDialogCallback,
      _hereMapController = hereMapController {
    double distanceToEarthInMeters = 10000;
    MapMeasure mapMeasureZoom = MapMeasure(MapMeasureKind.distanceInMeters, distanceToEarthInMeters);
    _hereMapController.camera.lookAtPointWithMeasure(GeoCoordinates(52.520798, 13.409408), mapMeasureZoom);

    // Setting a tap handler to pick markers from map.
    _setTapGestureHandler();

    try {
      _routingEngine = RoutingEngine();
    } on InstantiationException {
      throw ("Initialization of RoutingEngine failed.");
    }

    try {
      // Use the IsolineRoutingEngine to calculate a reachable area from a center point.
      // The calculation is done asynchronously and requires an online connection.
      _isolineRoutingEngine = IsolineRoutingEngine();
    } on InstantiationException {
      throw ("Initialization of IsolineRoutingEngine failed.");
    }

    try {
      // Add search engine to search for places along a route.
      _searchEngine = SearchEngine();
    } on InstantiationException {
      throw ("Initialization of SearchEngine failed.");
    }
  }

  // Calculates an EV car route based on random start / destination coordinates near viewport center.
  // Includes a user waypoint to add an intermediate charging stop along the route,
  // in addition to charging stops that are added by the engine.
  void addEVRoute() {
    if (_isRouteCalculationRunning) {
      print("Previous route calculation still in progress.");
      return;
    }

    clearMap();
    chargingStationsIDs.clear();

    _startGeoCoordinates = _createRandomGeoCoordinatesInViewport();
    _destinationGeoCoordinates = _createRandomGeoCoordinatesInViewport();
    var startWaypoint = Waypoint(_startGeoCoordinates!);
    var destinationWaypoint = Waypoint(_destinationGeoCoordinates!);
    var plannedChargingStopWaypoint = createUserPlannedChargingStopWaypoint();
    List<Waypoint> waypoints = [startWaypoint, plannedChargingStopWaypoint, destinationWaypoint];

    _currentRouteCalculationTask = _routingEngine.calculateEVCarRoute(waypoints, _getEVCarOptions(), (
      RoutingError? routingError,
      List<here.Route>? routeList,
    ) {
      if (routingError == null) {
        // When error is null, the list is guaranteed to be non empty.
        here.Route route = routeList!.first;
        _showRouteOnMap(route);
        _logRouteViolations(route);
        _logEVDetails(route);
        _searchAlongARoute(route);
      } else {
        var error = routingError.toString();
        _showDialog('Error', 'Error while calculating a route: $error');
      }
    });
  }

  bool get _isRouteCalculationRunning => _currentRouteCalculationTask?.isFinished == false;

  // Simulate a user planned stop based on random coordinates.
  Waypoint createUserPlannedChargingStopWaypoint() {
    // The rated power of the connector, in kilowatts (kW).
    double powerInKilowatts = 350.0;

    // The rated current of the connector, in amperes (A).
    double currentInAmperes = 350.0;

    // The rated voltage of the connector, in volts (V).
    double voltageInVolts = 1000.0;

    // The minimum duration (in seconds) the user plans to charge at the station.
    Duration minimumDuration = Duration(seconds: 3000);

    // The maximum duration (in seconds) the user plans to charge at the station.
    Duration maximumDuration = Duration(seconds: 4000);

    // Add a user-defined charging stop.
    //
    // Note: To specify a ChargingStop, you must also set totalCapacityInKilowattHours,
    // initialChargeInKilowattHours, and chargingCurve using BatterySpecification in EVCarOptions.
    // If any of these values are missing, the route calculation will fail with an invalid parameter error.
    ChargingStop plannedChargingStop = ChargingStop(
      powerInKilowatts,
      currentInAmperes,
      voltageInVolts,
      ChargingSupplyType.dc,
      minimumDuration,
      maximumDuration,
    );

    Waypoint plannedChargingStopWaypoint = Waypoint(_createRandomGeoCoordinatesInViewport());
    plannedChargingStopWaypoint.chargingStop = plannedChargingStop;
    return plannedChargingStopWaypoint;
  }

  void _applyEMSPPreferences(EVCarOptions evCarOptions) {
    // You can get a list of all E-Mobility Service Providers and their partner IDs by using the request described here:
    // https://www.here.com/docs/bundle/ev-charge-points-api-developer-guide/page/topics/example-charging-station.html.
    // No more than 10 E-Mobility Service Providers should be specified.
    // The RoutingEngine will follow the priority order you specify when calculating routes, so try to specify at least most preferred providers.
    // Note that this may impact the route geometry.

    // Most preferred provider for route calculation: As an example, we use "Jaguar Charging" referenced by the partner ID taken from above link.
    List<String> preferredProviders = ["3379b852-cca5-11ed-8856-42010aa40002"];

    // Example code for a least preferred provider.
    List<String> leastPreferredProviders = ["12345678-abcd-0000-0000-000000000000"];

    // Alternative provider for route calculation to be used only when no better options are available.
    // Example code for an alternative provider.
    List<String> alternativeProviders = ["12345678-0000-abcd-0000-000123456789"];

    evCarOptions.evMobilityServiceProviderPreferences = EVMobilityServiceProviderPreferences();
    evCarOptions.evMobilityServiceProviderPreferences.high = preferredProviders;
    evCarOptions.evMobilityServiceProviderPreferences.low = leastPreferredProviders;
    evCarOptions.evMobilityServiceProviderPreferences.medium = alternativeProviders;
  }

  EVCarOptions _getEVCarOptions() {
    EVCarOptions evCarOptions = EVCarOptions();

    // The below three options are the minimum you must specify or routing will result in an error.
    evCarOptions.consumptionModel.ascentConsumptionInWattHoursPerMeter = 9;
    evCarOptions.consumptionModel.descentRecoveryInWattHoursPerMeter = 4.3;
    evCarOptions.consumptionModel.freeFlowSpeedTable = {0: 0.239, 27: 0.239, 60: 0.196, 90: 0.238};

    // Must be 0 for isoline calculation.
    evCarOptions.routeOptions.alternatives = 0;

    // Ensure that the vehicle does not run out of energy along the way
    // and charging stations are added as additional waypoints.
    evCarOptions.ensureReachability = true;

    // The below options are required when setting the ensureReachability option to true
    // (AvoidanceOptions need to be empty).
    evCarOptions.avoidanceOptions = AvoidanceOptions();
    evCarOptions.routeOptions.speedCapInMetersPerSecond = null;
    evCarOptions.routeOptions.optimizationMode = OptimizationMode.fastest;
    evCarOptions.batterySpecifications.connectorTypes = [
      ChargingConnectorType.tesla,
      ChargingConnectorType.iec62196Type1Combo,
      ChargingConnectorType.iec62196Type2Combo,
    ];
    evCarOptions.batterySpecifications.totalCapacityInKilowattHours = 80.0;
    evCarOptions.batterySpecifications.initialChargeInKilowattHours = 10.0;
    evCarOptions.batterySpecifications.targetChargeInKilowattHours = 72.0;
    evCarOptions.batterySpecifications.chargingCurve = {0.0: 239.0, 64.0: 111.0, 72.0: 1.0};

    // Apply EV mobility service provider preferences (eMSP).
    _applyEMSPPreferences(evCarOptions);

    // Note: More EV options are available, the above shows only the minimum viable options.
    return evCarOptions;
  }

  void _logEVDetails(here.Route route) {
    // Find inserted charging stations that are required for this route.
    // Note that this example assumes only one start waypoint and one destination waypoint.
    // By default, each route has one section.
    int additionalSectionCount = route.sections.length - 1;
    if (additionalSectionCount > 0) {
      // Each additional waypoint splits the route into two sections.
      print("EVDetails: Number of required stops at charging stations: " + additionalSectionCount.toString());
    } else {
      print(
        "EVDetails: Based on the provided options, the destination can be reached without a stop at a charging station.",
      );
    }

    int sectionIndex = 0;
    List<Section> sections = route.sections;
    for (Section section in sections) {
      print(
        "EVDetails: Estimated net energy consumption in kWh for this section: " +
            section.consumptionInKilowattHours.toString(),
      );
      for (PostAction postAction in section.postActions) {
        switch (postAction.action) {
          case PostActionType.chargingSetup:
            print(
              "EVDetails: At the end of this section you need to setup charging for " +
                  postAction.duration.inSeconds.toString() +
                  " s.",
            );
            break;
          case PostActionType.charging:
            print(
              "EVDetails: At the end of this section you need to charge for " +
                  postAction.duration.inSeconds.toString() +
                  " s.",
            );
            break;
          case PostActionType.wait:
            print(
              "EVDetails: At the end of this section you need to wait for " +
                  postAction.duration.inSeconds.toString() +
                  " s.",
            );
            break;
          default:
            throw ("Unknown post action type.");
        }
      }

      print(
        "EVDetails: Section " +
            sectionIndex.toString() +
            ": Estimated battery charge in kWh when leaving the departure place: " +
            section.departurePlace.chargeInKilowattHours.toString(),
      );
      print(
        "EVDetails: Section " +
            sectionIndex.toString() +
            ": Estimated battery charge in kWh when leaving the arrival place: " +
            section.arrivalPlace.chargeInKilowattHours.toString(),
      );

      // Only charging stations that are needed to reach the destination are listed below.
      ChargingStation? depStation = section.departurePlace.chargingStation;
      if (depStation != null && depStation.id != null && !chargingStationsIDs.contains(depStation.id)) {
        print(
          "EVDetails: Section " + sectionIndex.toString() + ", name of charging station: " + depStation.name.toString(),
        );
        chargingStationsIDs.add(depStation.id.toString());
        Metadata metadata = Metadata();
        metadata.setString(requiredChargingMetadataKey, depStation.id!);
        metadata.setString(supplierNameMetadataKey, depStation.name!);
        _addMapMarker(section.departurePlace.mapMatchedCoordinates, "assets/required_charging.png", metadata);
      }

      ChargingStation? arrStation = section.departurePlace.chargingStation;
      if (arrStation != null && arrStation.id != null && !chargingStationsIDs.contains(arrStation.id)) {
        print(
          "EVDetails: Section " + sectionIndex.toString() + ", name of charging station: " + arrStation.name.toString(),
        );
        chargingStationsIDs.add(arrStation.id.toString());
        Metadata metadata = Metadata();
        metadata.setString(requiredChargingMetadataKey, arrStation.id!);
        metadata.setString(supplierNameMetadataKey, arrStation.name!);
        _addMapMarker(section.arrivalPlace.mapMatchedCoordinates, "assets/required_charging.png", metadata);
      }

      sectionIndex += 1;
    }
  }

  // A route may contain several warnings, for example, when a certain route option could not be fulfilled.
  // An implementation may decide to reject a route if one or more violations are detected.
  void _logRouteViolations(here.Route route) {
    for (var section in route.sections) {
      for (var notice in section.sectionNotices) {
        print("This route contains the following warning: " + notice.code.toString());
      }
    }
  }

  // Perform a search for charging stations along the found route.
  void _searchAlongARoute(here.Route route) {
    // We specify here that we only want to include results
    // within a max distance of xx meters from any point of the route.
    int halfWidthInMeters = 200;
    GeoCorridor routeCorridor = GeoCorridor(route.geometry.vertices, halfWidthInMeters);
    PlaceCategory placeCategory = PlaceCategory(PlaceCategory.businessAndServicesEvChargingStation);
    CategoryQueryArea categoryQueryArea = CategoryQueryArea.withCorridorAndCenter(
      routeCorridor,
      _hereMapController.camera.state.targetCoordinates,
    );
    CategoryQuery categoryQuery = CategoryQuery.withCategoryInArea(placeCategory, categoryQueryArea);

    SearchOptions searchOptions = SearchOptions();
    searchOptions.languageCode = LanguageCode.enUs;
    searchOptions.maxItems = 30;

    enableEVChargingStationDetails();

    _searchEngine.searchByCategory(categoryQuery, searchOptions, (SearchError? searchError, List<Place>? items) {
      if (searchError != null) {
        print("Search: No charging stations found along the route. Error: $searchError");
        return;
      }

      // If error is nil, it is guaranteed that the items will not be nil.
      print("Search: Search along route found ${items!.length} charging stations:");
      for (Place place in items) {
        Details details = place.details;
        Metadata metadata = getMetadataForEVChargingPools(details);
        bool foundExistingChargingStation = false;
        for (MapMarker mapMarker in _mapMarkers) {
          if (mapMarker.metadata != null) {
            String? id = mapMarker.metadata!.getString(requiredChargingMetadataKey);
            if (id != null && id.toLowerCase() == place.id.toLowerCase()) {
              print(
                "Search: Skipping: This charging station was already required to reach the destination (see red charging icon).",
              );
              mapMarker.metadata = metadata;
              foundExistingChargingStation = true;
              break;
            }
          }
        }

        if (!foundExistingChargingStation) {
          _addMapMarker(place.geoCoordinates!, "assets/charging.png", metadata);
        }
      }
    });
  }

  // Enable fetching online availability details for EV charging stations.
  // It allows retrieving additional details, such as whether a charging station is currently occupied.
  // Check the API Reference for more details.
  void enableEVChargingStationDetails() {
    // Fetching additional charging stations details requires a custom option call.
    SearchError? error = _searchEngine.setCustomOption("browse.show", "ev");
    if (error != null) {
      _showDialog("Charging Station", "Failed to enableEVChargingStationDetails. ");
    } else {
      print("EV charging station availability enabled successfully.");
    }
  }

  void _setTapGestureHandler() {
    _hereMapController.gestures.tapListener = TapListener((Point2D touchPoint) {
      _pickMapMarker(touchPoint);
    });
  }

  // This method is used to pick a map marker when a user taps on a charging station icon on the map.
  // When performing a search for charging stations along the route, clicking on a charging station icon
  // will display its details, including the supplier name, connector count, availability status, last update time, etc.
  void _pickMapMarker(Point2D touchPoint) {
    Point2D originInPixels = Point2D(touchPoint.x, touchPoint.y);
    Size2D sizeInPixels = Size2D(1, 1);
    Rectangle2D rectangle = Rectangle2D(originInPixels, sizeInPixels);

    // If you do not want to specify any filter you can pass filter as NULL and all of the pickable contents will be picked.
    MapSceneMapPickFilter? filter = null;
    _hereMapController.pick(filter, rectangle, (MapPickResult? mapPickResult) {
      if (mapPickResult == null) {
        // An error occurred while performing the pick operation.
        return;
      }

      PickMapItemsResult? pickMapItemsResult = mapPickResult.mapItems;
      List<MapMarker>? mapMarkerList = pickMapItemsResult?.markers;
      if (mapMarkerList!.isEmpty) {
        return;
      }

      MapMarker topmostMapMarker = mapMarkerList.first;
      _showPickedChargingStationResults(topmostMapMarker);
    });
  }

  void _showPickedChargingStationResults(MapMarker mapMarker) {
    Metadata? metadata = mapMarker.metadata;
    if (metadata == null) {
      print("No metadata found for the picked marker.");
      return;
    }

    List<String> details = [];

    // Fetch metadata values and build message
    void addDetail(String key, String label) {
      String? value = metadata.getString(key);
      if (value != null) details.add("$label: $value");
    }

    addDetail(supplierNameMetadataKey, "Name");
    addDetail(connectorCountMetadataKey, "Connector Count");
    addDetail(availableConnectorsMetadataKey, "Available Connectors");
    addDetail(occupiedConnectorsMetadataKey, "Occupied Connectors");
    addDetail(outOfServiceConnectorsMetadataKey, "Out of Service Connectors");
    addDetail(reservedConnectorsMetadataKey, "Reserved Connectors");
    addDetail(lastUpdatedMetadataKey, "Last Updated");

    if (details.isNotEmpty) {
      details.add("\n\nFor a full list of attributes please refer to the API Reference.");
      _showDialog("Charging station details", details.join("\n"));
    } else {
      print("No relevant metadata available for charging station.");
    }
  }

  Metadata getMetadataForEVChargingPools(Details placeDetails) {
    Metadata metadata = Metadata();
    if (placeDetails.evChargingPool != null) {
      for (var station in placeDetails.evChargingPool!.chargingStations) {
        if (station.supplierName != null) {
          metadata.setString(supplierNameMetadataKey, station.supplierName!);
        }
        if (station.connectorCount != null) {
          metadata.setString(connectorCountMetadataKey, station.connectorCount!.toString());
        }
        if (station.availableConnectorCount != null) {
          metadata.setString(availableConnectorsMetadataKey, station.availableConnectorCount!.toString());
        }
        if (station.occupiedConnectorCount != null) {
          metadata.setString(occupiedConnectorsMetadataKey, station.occupiedConnectorCount!.toString());
        }
        if (station.outOfServiceConnectorCount != null) {
          metadata.setString(outOfServiceConnectorsMetadataKey, station.outOfServiceConnectorCount!.toString());
        }
        if (station.reservedConnectorCount != null) {
          metadata.setString(reservedConnectorsMetadataKey, station.reservedConnectorCount!.toString());
        }
        if (station.lastUpdated != null) {
          metadata.setString(lastUpdatedMetadataKey, station.lastUpdated!.toString());
        }
      }
    }
    return metadata;
  }

  // Shows the reachable area for this electric vehicle from the current start coordinates and EV car options when the goal is
  // to consume 400 Wh or less (see options below).
  void showReachableArea() {
    if (_startGeoCoordinates == null) {
      _showDialog("Error", "Please add at least one route first.");
      return;
    }

    // Clear previously added polygon area, if any.
    _clearIsolines();

    // This finds the area that an electric vehicle can reach by consuming 400 Wh or less,
    // while trying to take the fastest possible route into any possible straight direction from start.
    // Note: We have specified evCarOptions.routeOptions.optimizationMode = OptimizationMode.FASTEST for EV car options above.
    List<int> rangeValues = [400];

    // With null we choose the default option for the resulting polygon shape.
    int? maxPoints;
    IsolineOptionsCalculation calculationOptions = IsolineOptionsCalculation.withNoDefaults(
      IsolineRangeType.consumptionInWattHours,
      rangeValues,
      IsolineCalculationMode.balanced,
      maxPoints,
      RoutePlaceDirection.departure,
    );
    IsolineOptions isolineOptions = IsolineOptions.withEVCarOptions(calculationOptions, _getEVCarOptions());

    _isolineRoutingEngine.calculateIsoline(Waypoint(_startGeoCoordinates!), isolineOptions, (
      RoutingError? routingError,
      List<Isoline>? list,
    ) {
      if (routingError != null) {
        _showDialog("Error while calculating reachable area:", routingError.toString());
        return;
      }

      // When routingError is nil, the isolines list is guaranteed to contain at least one isoline.
      // The number of isolines matches the number of requested range values. Here we have used one range value,
      // so only one isoline object is expected.
      Isoline isoline = list!.first;

      // If there is more than one polygon, the other polygons indicate separate areas, for example, islands, that
      // can only be reached by a ferry.
      for (GeoPolygon geoPolygon in isoline.polygons) {
        // Show polygon on map.
        Color fillColor = Color.fromARGB(128, 0, 143, 138);
        MapPolygon mapPolygon = MapPolygon(geoPolygon, fillColor);
        _hereMapController.mapScene.addMapPolygon(mapPolygon);
        _mapPolygons.add(mapPolygon);
      }
    });
  }

  void clearMap() {
    _clearWaypointMapMarker();
    _clearRoute();
    _clearIsolines();
  }

  void _clearWaypointMapMarker() {
    for (MapMarker mapMarker in _mapMarkers) {
      _hereMapController.mapScene.removeMapMarker(mapMarker);
    }
    _mapMarkers.clear();
  }

  void _clearRoute() {
    for (var mapPolyline in _mapPolylines) {
      _hereMapController.mapScene.removeMapPolyline(mapPolyline);
    }
    _mapPolylines.clear();
  }

  void _clearIsolines() {
    for (MapPolygon mapPolygon in _mapPolygons) {
      _hereMapController.mapScene.removeMapPolygon(mapPolygon);
    }
    _mapPolygons.clear();
  }

  _showRouteOnMap(here.Route route) {
    // Show route as polyline.
    GeoPolyline routeGeoPolyline = route.geometry;
    double widthInPixels = 20;
    Color polylineColor = const Color.fromARGB(160, 0, 144, 138);
    MapPolyline routeMapPolyline;
    try {
      routeMapPolyline = MapPolyline.withRepresentation(
        routeGeoPolyline,
        MapPolylineSolidRepresentation(
          MapMeasureDependentRenderSize.withSingleSize(RenderSizeUnit.pixels, widthInPixels),
          polylineColor,
          LineCap.round,
        ),
      );
      _hereMapController.mapScene.addMapPolyline(routeMapPolyline);
      _mapPolylines.add(routeMapPolyline);
    } on MapPolylineRepresentationInstantiationException catch (e) {
      print("MapPolylineRepresentation Exception:" + e.error.name);
      return;
    } on MapMeasureDependentRenderSizeInstantiationException catch (e) {
      print("MapMeasureDependentRenderSize Exception:" + e.error.name);
      return;
    }

    if (_startGeoCoordinates == null || _destinationGeoCoordinates == null) {
      return;
    }

    // Draw a circle to indicate starting point and destination.
    _addCircleMapMarker(_startGeoCoordinates!, "assets/poi_start.png");
    _addCircleMapMarker(_destinationGeoCoordinates!, "assets/poi_destination.png");
  }

  void _addMapMarker(GeoCoordinates geoCoordinates, String imageName, Metadata metadata) {
    // For this app, we only add images of size 60x60 pixels.
    int imageWidth = 60;
    int imageHeight = 60;
    // Note that you can optionally optimize by reusing the mapImage instance for other MapMarker instance.
    MapImage mapImage = MapImage.withFilePathAndWidthAndHeight(imageName, imageWidth, imageHeight);
    MapMarker mapMarker = MapMarker(geoCoordinates, mapImage);
    _hereMapController.mapScene.addMapMarker(mapMarker);
    mapMarker.metadata = metadata;
    _mapMarkers.add(mapMarker);
  }

  void _addCircleMapMarker(GeoCoordinates geoCoordinates, String imageName) {
    int imageWidth = 100;
    int imageHeight = 100;
    // Note that you can optionally optimize by reusing the mapImage instance for other MapMarker instance.
    MapImage mapImage = MapImage.withFilePathAndWidthAndHeight(imageName, imageWidth, imageHeight);
    MapMarker mapMarker = MapMarker(geoCoordinates, mapImage);
    _hereMapController.mapScene.addMapMarker(mapMarker);
    _mapMarkers.add(mapMarker);
  }

  GeoCoordinates _createRandomGeoCoordinatesInViewport() {
    GeoBox? geoBox = _hereMapController.camera.boundingBox;
    if (geoBox == null) {
      // Happens only when map is not fully covering the viewport.
      return GeoCoordinates(52.530932, 13.384915);
    }

    GeoCoordinates northEast = geoBox.northEastCorner;
    GeoCoordinates southWest = geoBox.southWestCorner;

    double minLat = southWest.latitude;
    double maxLat = northEast.latitude;
    double lat = _getRandom(minLat, maxLat);

    double minLon = southWest.longitude;
    double maxLon = northEast.longitude;
    double lon = _getRandom(minLon, maxLon);

    return GeoCoordinates(lat, lon);
  }

  double _getRandom(double min, double max) {
    return min + Random().nextDouble() * (max - min);
  }
}
