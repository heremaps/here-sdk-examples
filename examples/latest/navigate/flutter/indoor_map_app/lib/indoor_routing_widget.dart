/*
 * Copyright (C) 2021-2022 HERE Europe B.V.
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

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:here_sdk/venue.dart';
import "package:intl/intl.dart";
import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/routing.dart';
import 'package:here_sdk/venue.control.dart';
import 'package:here_sdk/venue.data.dart';
import 'package:indoor_map_app/image_helper.dart';
import 'package:indoor_map_app/indoor_route_options_widget.dart';

// Provides UI elements for indoor route calculation and displays an indoor route on the map.
class IndoorRoutingWidget extends StatefulWidget {
  final IndoorRoutingState state;

  IndoorRoutingWidget({required this.state});

  @override
  IndoorRoutingState createState() => state;
}

class IndoorRoutingState extends State<IndoorRoutingWidget> {
  bool _isEnabled = false;
  HereMapController? _hereMapController;
  late VenueMap _venueMap;
  IndoorRoutingEngine? _routingEngine;
  late IndoorRoutingController _routingController;
  IndoorRouteStyle _routeStyle = IndoorRouteStyle();
  IndoorWaypoint? _startPoint;
  IndoorWaypoint? _destinationPoint;
  late IndoorRouteOptionsState _indoorRouteOptionsState;
  final formatter = new NumberFormat("###.####", "en_US");

  bool get isEnabled => _isEnabled;

  // Set visibility of UI elements for indoor routes calculation.
  set isEnabled(bool value) {
    setState(() {
      _isEnabled = value;
    });
  }

  // Set a start waypoint.
  set startPoint(IndoorWaypoint? startPoint) {
    setState(() {
      _startPoint = startPoint;
    });
  }

  // Set a destination waypoint.
  set destinationPoint(IndoorWaypoint? destinationPoint) {
    setState(() {
      _destinationPoint = destinationPoint;
    });
  }

  set(HereMapController? hereMapController, VenueEngine venueEngine) {
    _hereMapController = hereMapController;
    _venueMap = venueEngine.venueMap;
    // Initialize IndoorRoutingEngine to be able to calculate indoor routes.
    _routingEngine = new IndoorRoutingEngine(venueEngine.venueService);
    // Initialize IndoorRoutingController to be able to display indoor routes on the map.
    _routingController = new IndoorRoutingController(_venueMap, _hereMapController!.mapScene);

    // Set start, end, walk and drive markers. The start marker will be shown at the start of
    // the route and the destination marker at the destination of the route. The walk marker
    // will be shown when the route switches from drive to walk mode and the drive marker
    // vice versa.
    final middleBottomAnchor = Anchor2D.withHorizontalAndVertical(0.5, 1.0);
    ImageHelper.initMapMarker('ic_route_start.png', middleBottomAnchor)
        .then((value) => _routeStyle.startMarker = value);
    ImageHelper.initMapMarker('ic_route_end.png', middleBottomAnchor)
        .then((value) => _routeStyle.destinationMarker = value);
    ImageHelper.initMapMarker('indoor_walk.png', null).then((value) => _routeStyle.walkMarker = value);
    ImageHelper.initMapMarker('indoor_drive.png', null).then((value) => _routeStyle.driveMarker = value);

    // Set markers for some of the indoor features. The 'up' marker indicates that the route is
    // going up, and the 'down' marker indicates that the route is going down. The default marker
    // indicates that a user should exit the current indoor feature (e.g. an elevator) to enter
    // the current floor.
    final features = [IndoorFeatures.stairs, IndoorFeatures.elevator, IndoorFeatures.escalator, IndoorFeatures.ramp];
    for (int i = 0; i < features.length; i++) {
      IndoorFeatures feature = features[i];
      String featureString = feature.toString().split('.').last;
      ImageHelper.initMapMarker('indoor_' + featureString + '.png', null).then((marker) =>
          ImageHelper.initMapMarker('indoor_' + featureString + '_up.png', null).then((upMarker) =>
              ImageHelper.initMapMarker('indoor_' + featureString + '_down.png', null)
                  .then((downMarker) => _routeStyle.setIndoorMarkersFor(feature, upMarker, downMarker, marker))));
    }
  }

  // Set a start point for indoor routes calculation.
  setStartPoint(Point2D origin) {
    startPoint = _getIndoorWaypoint(origin);
  }

  // Set a destination point for indoor routes calculation.
  setDestinationPoint(Point2D origin) {
    destinationPoint = _getIndoorWaypoint(origin);
  }

  // Create an indoor waypoint based on the tap point on the map.
  IndoorWaypoint? _getIndoorWaypoint(Point2D origin) {
    GeoCoordinates? position = _hereMapController!.viewToGeoCoordinates(origin);
    if (position != null) {
      // Check if there is a venue in the tap position.
      Venue? venue = _venueMap.getVenue(position);
      if (venue != null) {
        VenueModel venueModel = venue.venueModel;
        Venue? selectedVenue = _venueMap.selectedVenue;
        if (selectedVenue != null && venueModel.id == selectedVenue.venueModel.id) {
          // If the venue is the selected one, return an indoor waypoint
          // with indoor information.
          return new IndoorWaypoint(position, venueModel.id.toString(), venue.selectedLevel.id.toString());
        } else {
          // If the venue is not the selected one, select it.
          _venueMap.selectedVenue = venue;
          return null;
        }
      }
      // If the tap position is outside of any venue, return an indoor waypoint with
      // outdoor coordinates.
      return IndoorWaypoint.withOutdoorCoordinates(position);
    }
    return null;
  }

  // Get the text description for a new indoor waypoint.
  String _getWaypointDescription(IndoorWaypoint waypoint) {
    StringBuffer builder = new StringBuffer();
    if (waypoint.venueId != null && waypoint.levelId != null) {
      builder.writeAll(["Venue ID: ", waypoint.venueId, ", Level ID: ", waypoint.levelId, ", "]);
    }
    builder.writeAll([
      "Lat: ",
      formatter.format(waypoint.coordinates.latitude),
      ", Lng: ",
      formatter.format(waypoint.coordinates.longitude)
    ]);
    return builder.toString();
  }

  _requestRoute() {
    if (_routingEngine != null && _startPoint != null && _destinationPoint != null) {
      // Calculate an indoor route based on the start and destination waypoints, and
      // the indoor route options.
      _routingEngine!.calculateRoute(_startPoint!, _destinationPoint!, _indoorRouteOptionsState.options,
          (error, routes) async {
        // Hide the existing route, if any.
        _routingController.hideRoute();
        if (error == null && routes != null) {
          final route = routes[0];
          // Show the resulting route with predefined indoor routing styles.
          _routingController.showRoute(route, _routeStyle);
        } else {
          // Show an alert dialog in case of error.
          showDialog(
              context: context,
              builder: (_) => AlertDialog(
                    title: Text('The indoor route failed!'),
                    content: SingleChildScrollView(
                      child: Text('Failed to calculate the indoor route!'),
                    ),
                    actions: <Widget>[
                      FlatButton(
                        child: Text('Ok'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isEnabled) {
      return SizedBox.shrink();
    }

    return Container(
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.all(5),
      child: Column(
        children: [
          Row(
            children: [
              Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(5),
                    width: 230,
                    child: Text(
                      // Show a name of the geometry.
                      _startPoint != null ? _getWaypointDescription(_startPoint!) : "Long tap for a start point.",
                      textAlign: TextAlign.start,
                      maxLines: 2,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(5),
                    width: 230,
                    child: Text(
                      // Show a name of the geometry.
                      _destinationPoint != null
                          ? _getWaypointDescription(_destinationPoint!)
                          : "Tap for a destination point.",
                      textAlign: TextAlign.start,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
              Container(
                margin: EdgeInsets.all(5),
                width: kMinInteractiveDimension,
                child: FlatButton(
                  color: Colors.lightBlueAccent,
                  padding: EdgeInsets.zero,
                  child: Icon(Icons.directions, color: Colors.black, size: kMinInteractiveDimension),
                  onPressed: () {
                    _requestRoute();
                  },
                ),
              ),
              Container(
                margin: EdgeInsets.all(5),
                width: kMinInteractiveDimension,
                child: FlatButton(
                  color: Colors.lightBlueAccent,
                  padding: EdgeInsets.zero,
                  child: Icon(Icons.settings, color: Colors.black, size: kMinInteractiveDimension),
                  onPressed: () {
                    _indoorRouteOptionsState.isEnabled = !_indoorRouteOptionsState.isEnabled;
                  },
                ),
              ),
            ],
          ),
          IndoorRouteOptionsWidget(state: _indoorRouteOptionsState = IndoorRouteOptionsState()),
        ],
      ),
    );
  }
}
