/*
 * Copyright (C) 2019-2026 HERE Europe B.V.
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

import 'EVSearchExample.dart';

// A callback to notify the hosting widget.
typedef ShowDialogFunction = void Function(String title, String message);

// This example shows how to calculate routes for electric vehicles that contain necessary charging stations
// (indicated with red charging icon). In addition, all existing charging stations are searched along the route
// (indicated with green charging icon). You can also visualize the reachable area from your starting point
// (isoline routing).
class EVRoutingExample {
  final HereMapController _hereMapController;
  late MapCamera _camera;
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
  Waypoint? _lastPlannedChargingWaypoint;

  // Metadata keys used when picking a charging station on the map.
  final String supplierNameMetadataKey = "supplierName";
  final String connectorCountMetadataKey = "connectorCount";
  final String availableConnectorsMetadataKey = "availableConnectors";
  final String occupiedConnectorsMetadataKey = "occupiedConnectors";
  final String outOfServiceConnectorsMetadataKey = "outOfServiceConnectors";
  final String reservedConnectorsMetadataKey = "reservedConnectors";
  final String lastUpdatedMetadataKey = "lastUpdated";
  final String requiredChargingMetadataKey = "requiredCharging";

  // Metadata keys for EVCP 3.0 data (used when isEVCP3 is true).
  final String nameMetadataKey = "name";
  final String cpoIdMetadataKey = "cpo_id";
  final String subOperatorNameMetadataKey = "sub_operator_name";
  final String emspNamesMetadataKey = "emsp_names";
  final String facilityTypesMetadataKey = "facility_types";
  final String parkingTypeMetadataKey = "parking_type";
  final String energyMixMetadataKey = "energy_mix";
  final String tariffCountMetadataKey = "tariff_count";
  final String connectorGroupCountMetadataKey = "connector_group_count";
  final String supportedVehicleCountMetadataKey = "supported_vehicle_count";
  final String truckRestrictionsMetadataKey = "truck_restrictions";
  final String restrictionCountMetadataKey = "restriction_count";
  final String supportPhoneNumberMetadataKey = "support_phone_number";
  final String timeZoneMetadataKey = "time_zone";
  final String openingHoursMetadataKey = "opening_hours";

  late EVSearchExample _evSearchExample;

  // This flag enables the use of the EVSearchEngine.
  // This engine will look online for enhanced data for EV charging stations.
  // Internally, the engine accesses the Electric Vehicle Charging Point (EVCP) 3.0 backend.
  // Find more info here: https://www.here.com/docs/bundle/ev-charge-points-api-v3-developer-guide/page/README.html
  // ATTENTION: This new API requires a separate license; find info more in the linked document.
  bool _isEVCP3 = false;

  EVRoutingExample(ShowDialogFunction showDialogCallback, HereMapController hereMapController)
    : _showDialog = showDialogCallback,
      _hereMapController = hereMapController {
    _camera = _hereMapController.camera;
    double distanceToEarthInMeters = 10000;
    MapMeasure mapMeasureZoom = MapMeasure(MapMeasureKind.distanceInMeters, distanceToEarthInMeters);
    _camera.lookAtPointWithMeasure(GeoCoordinates(52.520798, 13.409408), mapMeasureZoom);

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

    // Create an instance of EVSearchExample to enable EVSearchEngine for enriching search results with EVCP 3.0 data.
    _evSearchExample=EVSearchExample();
    // Attach EVSearchEngine to SearchEngine for EV enrichment.
    // Place results will contain additional data such as operator, sub-operator and eMSPs info, facility types, parking type, energy mix.
    EVSearchEngine? _evSearchEngine = _evSearchExample.evSearchEngine;
    if (_evSearchExample.evSearchEngine != null && _isEVCP3) {
      _searchEngine.setEVInterface(_evSearchEngine!);
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
    // Store the user-defined charging stop to verify whether it was included or modified in the route.
    _lastPlannedChargingWaypoint = plannedChargingStopWaypoint;
    List<Waypoint> waypoints = [startWaypoint, plannedChargingStopWaypoint, destinationWaypoint];

    _currentRouteCalculationTask = _routingEngine.calculateRouteWithRoutingOptions(waypoints, _getEVRoutingOptions(), (
      RoutingError? routingError,
      List<here.Route>? routeList,
    ) {
      if (routingError == null) {
        // When error is null, the list is guaranteed to be non empty.
        here.Route route = routeList!.first;
        _showRouteOnMap(route);
        _logRouteViolations(route);
        _logEVDetails(route);

        _logSpanConsumption(route);
        _logSectionArrivalCharge(route);
        _verifyAndLogPlannedStopOutcome(route);

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
    // initialChargeInKilowattHours, and chargingCurve using BatterySpecifications in ElectricVehicleOptions.
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

  void _applyEMSPPreferences(ElectricVehicleOptions evOptions) {
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

    evOptions.evMobilityServiceProviderPreferences = EVMobilityServiceProviderPreferences();
    evOptions.evMobilityServiceProviderPreferences.high = preferredProviders;
    evOptions.evMobilityServiceProviderPreferences.low = leastPreferredProviders;
    evOptions.evMobilityServiceProviderPreferences.medium = alternativeProviders;
  }

  RoutingOptions _getEVRoutingOptions() {
    RoutingOptions routingOptions = RoutingOptions();

    // Configure a data-driven EV energy consumption model that combines empirically
    // derived vehicle parameters with speed and elevation characteristics.
    EmpiricalConsumptionModel empiricalConsumptionModel = EmpiricalConsumptionModel();
    // The below three options are the minimum you must specify or routing will result in an error.
    empiricalConsumptionModel.ascentConsumptionInWattHoursPerMeter = 9;
    empiricalConsumptionModel.descentRecoveryInWattHoursPerMeter = 4.3;
    empiricalConsumptionModel.freeFlowSpeedTable = {0: 0.239, 27: 0.239, 60: 0.196, 90: 0.238};

    ElectricVehicleOptions evOptions = ElectricVehicleOptions();

    // Set the empirical consumption model so the EV routing
    // can estimate energy usage based on speed and elevation.
    evOptions.empiricalConsumptionModel = empiricalConsumptionModel;

    // Must be 0 for isoline calculation.
    routingOptions.routeOptions.alternatives = 0;

    // Ensure that the vehicle does not run out of energy along the way
    // and charging stations are added as additional waypoints.
    evOptions.ensureReachability = true;

    // The below options are required when setting the ensureReachability option to true
    // (AvoidanceOptions need to be empty).
    routingOptions.avoidanceOptions = AvoidanceOptions();
    routingOptions.routeOptions.speedCapInMetersPerSecond = null;
    routingOptions.routeOptions.optimizationMode = OptimizationMode.fastest;

    BatterySpecifications batterySpecifications = BatterySpecifications();
    batterySpecifications.connectorTypes = [
      ChargingConnectorType.tesla,
      ChargingConnectorType.iec62196Type1Combo,
      ChargingConnectorType.iec62196Type2Combo,
    ];
    batterySpecifications.totalCapacityInKilowattHours = 80.0;
    batterySpecifications.initialChargeInKilowattHours = 10.0;
    batterySpecifications.targetChargeInKilowattHours = 72.0;
    batterySpecifications.chargingCurve = {0.0: 239.0, 64.0: 111.0, 72.0: 1.0};
    evOptions.batterySpecifications = batterySpecifications;

    // Apply EV mobility service provider preferences (eMSP).
    _applyEMSPPreferences(evOptions);

    routingOptions.evOptions = evOptions;

    // Note: More EV options are available, the above shows only the minimum viable options.
    return routingOptions;
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

  // Logs estimated energy consumption by EV vehicle per span.
  void _logSpanConsumption(here.Route route) {
    int sectionIndex = 0;
    for (Section section in route.sections) {
      int spanIndex = 0;
      for (Span span in section.spans) {
        double? kWh = span.consumptionInKilowattHours;
        if (kWh != null) {
          print(
            "EVSpan: Section $sectionIndex span $spanIndex consumption: ${kWh.toStringAsFixed(3)} kWh",
          );
        } else {
          print("EVSpan: Section $sectionIndex span $spanIndex consumption: n/a");
        }
        spanIndex += 1;
      }
      sectionIndex += 1;
    }
  }

  // Logs remaining EV battery charge at the end of each route's section
  // and verifies the vehicle reachability to the destination.
  void _logSectionArrivalCharge(here.Route route) {
    int sectionIndex = 0;
    double? lastSectionArrivalChargeKWh;

    for (Section routeSection in route.sections) {
      double? remainingChargeAtArrivalKWh = routeSection.arrivalPlace.chargeInKilowattHours;

      if (remainingChargeAtArrivalKWh != null) {
        print(
          "EVArrival: Section $sectionIndex: remaining charge upon arrival = ${remainingChargeAtArrivalKWh.toStringAsFixed(2)} kWh",
        );
        lastSectionArrivalChargeKWh = remainingChargeAtArrivalKWh;
      } else {
        print("EVArrival: Section $sectionIndex: remaining charge upon arrival not available");
      }
      sectionIndex += 1;
    }

    if (lastSectionArrivalChargeKWh != null) {
      print(
        "EVArrival: Final destination arrival charge = ${lastSectionArrivalChargeKWh.toStringAsFixed(2)} kWh",
      );
      if (lastSectionArrivalChargeKWh < 0.0) {
        print("EVArrival: Destination not reachable with the current battery configuration.");
      }
    } else {
      print("EVArrival: No arrival charge data available for any section in this route.");
    }
  }

  // Verify and log whether the user-defined charging stop was included, adjusted,
  // or omitted in the calculated route based on reachability and optimization.
  void _verifyAndLogPlannedStopOutcome(here.Route route) {
    if (_lastPlannedChargingWaypoint == null) {
      print("EVChargingStop: No user-planned charging stop to verify.");
      return;
    }

    const double coordinateMatchRadiusMeters = 200.0;
    bool isStopIncludedInRoute = false;
    String? matchedChargingStationName;

    GeoCoordinates plannedStopCoordinates = _lastPlannedChargingWaypoint!.coordinates;

    for (Section routeSection in route.sections) {
      ChargingStation? departureStation = routeSection.departurePlace.chargingStation;
      if (departureStation != null) {
        GeoCoordinates departureStationCoordinates = routeSection.departurePlace.mapMatchedCoordinates;
        if (departureStationCoordinates.distanceTo(plannedStopCoordinates) <= coordinateMatchRadiusMeters) {
          isStopIncludedInRoute = true;
          matchedChargingStationName = departureStation.name;
          break;
        }
      }

      ChargingStation? arrivalStation = routeSection.arrivalPlace.chargingStation;
      if (arrivalStation != null) {
        GeoCoordinates arrivalStationCoordinates = routeSection.arrivalPlace.mapMatchedCoordinates;
        if (arrivalStationCoordinates.distanceTo(plannedStopCoordinates) <= coordinateMatchRadiusMeters) {
          isStopIncludedInRoute = true;
          matchedChargingStationName = arrivalStation.name;
          break;
        }
      }
    }

    if (isStopIncludedInRoute) {
      print(
        "EVChargingStop: User-defined charging stop was included in the calculated route${matchedChargingStationName != null ? " (≈ $matchedChargingStationName)." : "."}",
      );
      print(
        "EVChargingStop: Verification result: Stop successfully matched within $coordinateMatchRadiusMeters meters.",
      );
    } else {
      print("EVChargingStop: User-defined charging stop was adjusted or replaced during route optimization.");
      print(
        "EVChargingStop: Verification result: Planned stop coordinates did not match any charging station within $coordinateMatchRadiusMeters meters.",
      );
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
      print("Search: Search along route found \\${items!.length} charging stations:");
      List<String> placeIds = [];
      for (Place place in items) {
        Details details = place.details;
        Metadata metadata;
        if (_isEVCP3) {
          metadata = getMetadataForEVChargingLocation(details);
        } else {
          metadata = getMetadataForEVChargingPools(details);
        }
        bool foundExistingChargingStation = false;
        for (MapMarker mapMarker in _mapMarkers) {
          if (mapMarker.metadata != null) {
            String? id = mapMarker.metadata!.getString(requiredChargingMetadataKey);
            if (id != null && id.toLowerCase() == place.id.toLowerCase()) {
              print("Search: Insert metadata to existing charging station: This charging station was already required to reach the destination (see red charging icon).");
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
      print("MapPick: No metadata found for picked marker.");
      return;
    }
    List<String> details = [];
    void addDetail(String key, String label) {
      String? value = metadata.getString(key);
      if (value != null && value.isNotEmpty) details.add("$label: $value");
    }
    if (_isEVCP3) {
      addDetail(nameMetadataKey, "Name");
      addDetail(cpoIdMetadataKey, "CPO ID");
      addDetail(supplierNameMetadataKey, "Operator");
      addDetail(subOperatorNameMetadataKey, "Sub-Operator");
      addDetail(emspNamesMetadataKey, "eMSPs");
      addDetail(facilityTypesMetadataKey, "Facility Types");
      addDetail(parkingTypeMetadataKey, "Parking Type");
      addDetail(energyMixMetadataKey, "Energy Mix");
      addDetail(connectorCountMetadataKey, "Connector Count");
      addDetail(tariffCountMetadataKey, "Tariff Count");
      addDetail(connectorGroupCountMetadataKey, "Connector Group Count");
      addDetail(supportedVehicleCountMetadataKey, "Supported Vehicle Count");
      addDetail(truckRestrictionsMetadataKey, "Truck Restrictions");
      addDetail(openingHoursMetadataKey, "Opening Hours");
      addDetail(restrictionCountMetadataKey, "Restriction Count");
      addDetail(supportPhoneNumberMetadataKey, "Support Phone Number");
      addDetail(timeZoneMetadataKey, "Time Zone");
    } else {
      addDetail(supplierNameMetadataKey, "Electronic Charging Pool Name");
      addDetail(connectorCountMetadataKey, "Connector Count");
      addDetail(availableConnectorsMetadataKey, "Available Connectors");
      addDetail(occupiedConnectorsMetadataKey, "Occupied Connectors");
      addDetail(outOfServiceConnectorsMetadataKey, "Out of Service Connectors");
      addDetail(reservedConnectorsMetadataKey, "Reserved Connectors");
      addDetail(lastUpdatedMetadataKey, "Last Updated");
    }
    if (details.isNotEmpty) {
      details.add("\n\nFor a full list of attributes please refer to the API Reference.");
      _showDialog("Charging station details", details.join("\n"));
    } else {
      print("MapPick: No relevant metadata available for charging station.");
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

  // Returns metadata for an EVChargingLocation using both original and camelCase keys.
  Metadata getMetadataForEVChargingLocation(Details details) {
    Metadata metadata = Metadata();
    final evChargingLocation = details.evChargingLocation;
    if (evChargingLocation != null) {
      // Name
      if (evChargingLocation.name != null) {
        metadata.setString(nameMetadataKey, evChargingLocation.name!);
        metadata.setString("name_metadata_key", evChargingLocation.name!);
      }
      // CPO ID (if available)
      final cpoId = evChargingLocation.cpoID;
      if (cpoId != null) {
        metadata.setString(cpoIdMetadataKey, cpoId);
        metadata.setString("cpo_id_metadata_key", cpoId);
      }
      // Supplier/Operator Name
      if (evChargingLocation.evChargingOperator?.name != null) {
        metadata.setString(supplierNameMetadataKey, evChargingLocation.evChargingOperator!.name!);
      }
      // Sub Operator Name
      if (evChargingLocation.evChargingSubOperator?.name != null) {
        metadata.setString(subOperatorNameMetadataKey, evChargingLocation.evChargingSubOperator!.name!);
        metadata.setString("sub_operator_name_metadata_key", evChargingLocation.evChargingSubOperator!.name!);
      }
      // eMSPs
      final emsps = evChargingLocation.eMobilityServiceProviders;
      if (emsps.isNotEmpty) {
        final emspNames = emsps.map((emsp) => emsp.name).whereType<String>().join(", ");
        metadata.setString(emspNamesMetadataKey, emspNames);
        metadata.setString("emsp_names_metadata_key", emspNames);
      }
      // Facility Types
      final facilityTypes = evChargingLocation.facilityTypes;
      if (facilityTypes.isNotEmpty) {
        metadata.setString(facilityTypesMetadataKey, facilityTypes.toString());
        metadata.setString("facility_types_metadata_key", facilityTypes.toString());
      }
      // Parking Type
      if (evChargingLocation.parkingType != null) {
        metadata.setString(parkingTypeMetadataKey, evChargingLocation.parkingType.toString());
        metadata.setString("parking_type_metadata_key", evChargingLocation.parkingType.toString());
      }
      // Energy Mix
      if (evChargingLocation.energyMix != null) {
        metadata.setString(energyMixMetadataKey, evChargingLocation.energyMix.toString());
        metadata.setString("energy_mix_metadata_key", evChargingLocation.energyMix.toString());
      }
      // Tariffs
      final tariffs = evChargingLocation.tariffs;
      metadata.setString(tariffCountMetadataKey, tariffs.length.toString());
      // Connector Groups
      final connectorGroups = evChargingLocation.connectorGroups;
      metadata.setString(connectorGroupCountMetadataKey, connectorGroups.length.toString());
      // Supported Vehicles
      final supportedVehicles = evChargingLocation.supportedVehicles;
      metadata.setString(supportedVehicleCountMetadataKey, supportedVehicles.length.toString());
      // Truck Restrictions
      if (evChargingLocation.truckRestrictions != null) {
        metadata.setString(truckRestrictionsMetadataKey, evChargingLocation.truckRestrictions.toString());
      }
      // Opening Hours (mapped to lastUpdatedMetadataKey for parity)
      if (evChargingLocation.openingHours != null) {
        metadata.setString(openingHoursMetadataKey, evChargingLocation.openingHours.toString());
      }
      // Restrictions
      final restrictions = evChargingLocation.restrictions;
      metadata.setString(restrictionCountMetadataKey, restrictions.length.toString());
      // Support Phone Number
      if (evChargingLocation.supportPhoneNumber != null) {
        metadata.setString(supportPhoneNumberMetadataKey, evChargingLocation.supportPhoneNumber!);
      }
      // Time Zone
      if (evChargingLocation.timeZone != null) {
        metadata.setString(timeZoneMetadataKey, evChargingLocation.timeZone!);
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
    // Note: We have specified routingOptions.evOptions.ensureReachability = true and routingOptions.routeOptions.optimizationMode = OptimizationMode.fastest for EV options above.
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
    IsolineOptions isolineOptions = IsolineOptions.withRoutingOptions(calculationOptions, _getEVRoutingOptions());

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
    GeoBox geoBox = _getMapViewGeoBox();

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

  GeoBox _getMapViewGeoBox() {
    GeoBox? cameraBoundingBox = _camera.boundingBox;
    if (cameraBoundingBox != null) {
      return cameraBoundingBox;
    }

    // Happens when map does not fully cover the viewport, e.g. due to tilt.
    GeoCoordinates center = _getMapViewCenter();
    double delta = 0.08;
    GeoCoordinates southWestCorner = GeoCoordinates(center.latitude - delta, center.longitude - delta);
    GeoCoordinates northEastCorner = GeoCoordinates(center.latitude + delta, center.longitude + delta);
    return GeoBox(southWestCorner, northEastCorner);
  }

  GeoCoordinates _getMapViewCenter() {
    return _hereMapController.camera.state.targetCoordinates;
  }

  double _getRandom(double min, double max) {
    return min + Random().nextDouble() * (max - min);
  }
}
