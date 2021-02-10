/*
 * Copyright (C) 2021 HERE Europe B.V.
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
import 'package:venues/image_helper.dart';
import 'package:venues/indoor_route_options_widget.dart';

class IndoorRoutingWidget extends StatefulWidget {
  final IndoorRoutingState state;

  IndoorRoutingWidget({@required this.state});

  @override
  IndoorRoutingState createState() => state;
}

class IndoorRoutingState extends State<IndoorRoutingWidget> {
  bool _isEnabled = false;
  HereMapController _hereMapController;
  VenueMap _venueMap;
  IndoorRoutingEngine _routingEngine;
  IndoorRoutingController _routingController;
  IndoorRouteStyle _routeStyle = IndoorRouteStyle();
  IndoorWaypoint _startPoint;
  IndoorWaypoint _destinationPoint;
  final IndoorRouteOptionsState _indoorRouteOptionsState = new IndoorRouteOptionsState();
  final formatter = new NumberFormat("###.####", "en_US");

  bool get isEnabled => _isEnabled;

  set isEnabled(bool value) {
    setState(() {
      _isEnabled = value;
    });
  }

  set startPoint(IndoorWaypoint startPoint) {
    setState(() {
      _startPoint = startPoint;
    });
  }

  set destinationPoint(IndoorWaypoint destinationPoint) {
    setState(() {
      _destinationPoint = destinationPoint;
    });
  }

  set(HereMapController hereMapController, VenueEngine venueEngine) {
    _hereMapController = hereMapController;
    _venueMap = venueEngine.venueMap;
    _routingEngine = new IndoorRoutingEngine(venueEngine.venueService);
    _routingController = new IndoorRoutingController(_venueMap, _hereMapController.mapScene);

    final middleBottomAnchor = Anchor2D.withHorizontalAndVertical(0.5, 1.0);
    ImageHelper.initMapMarker('ic_route_start.png', middleBottomAnchor)
      .then((value) => _routeStyle.startMarker = value);
    ImageHelper.initMapMarker('ic_route_end.png', middleBottomAnchor)
      .then((value) => _routeStyle.destinationMarker = value);
    ImageHelper.initMapMarker('indoor_walk.png', null).then((value) => _routeStyle.walkMarker = value);
    ImageHelper.initMapMarker('indoor_drive.png', null).then((value) => _routeStyle.driveMarker = value);

    final features = [IndoorFeatures.stairs, IndoorFeatures.elevator, IndoorFeatures.escalator, IndoorFeatures.ramp];
    for (int i = 0; i < features.length; i++) {
      IndoorFeatures feature = features[i];
      String featureString = feature.toString().split('.').last;
      ImageHelper.initMapMarker('indoor_' + featureString + '.png', null)
        .then((marker) => ImageHelper.initMapMarker('indoor_' + featureString + '_up.png', null)
        .then((upMarker) => ImageHelper.initMapMarker('indoor_' + featureString + '_down.png', null)
        .then((downMarker) => _routeStyle.setIndoorMarkersFor(feature, upMarker, downMarker, marker))));
    }
  }

  setStartPoint(Point2D origin)
  {
    startPoint = _getIndoorWaypoint(origin);
  }

  setDestinationPoint(Point2D origin)
  {
    destinationPoint = _getIndoorWaypoint(origin);
  }

  IndoorWaypoint _getIndoorWaypoint(Point2D origin) {
    GeoCoordinates position = _hereMapController.viewToGeoCoordinates(origin);
    if (position != null) {
      Venue venue = _venueMap.getVenue(position);
      if (venue != null) {
        VenueModel venueModel = venue.venueModel;
        Venue selectedVenue = _venueMap.selectedVenue;
        if (selectedVenue != null &&
          venueModel.id == selectedVenue.venueModel.id) {
          return new IndoorWaypoint(
            position,
            venueModel.id.toString(),
            venue.selectedLevel.id.toString());
        } else {
          _venueMap.selectedVenue = venue;
          return null;
        }
      }
      return IndoorWaypoint.withOutdoorCoordinates(position);
    }
    return null;
  }

  String _getWaypointDescription(IndoorWaypoint waypoint) {
    StringBuffer builder = new StringBuffer();
    if (waypoint.venueId != null && waypoint.levelId != null) {
      builder.writeAll(["Venue ID: ", waypoint.venueId,
        ", Level ID: ", waypoint.levelId, ", "]);
    }
    builder.writeAll(["Lat: ", formatter.format(waypoint.coordinates.latitude),
      ", Lng: ", formatter.format(waypoint.coordinates.longitude)]);
    return builder.toString();
  }

  _requestRoute() {
    if (_routingEngine != null && _startPoint != null && _destinationPoint != null) {
      _routingEngine.calculateRoute(_startPoint, _destinationPoint, _indoorRouteOptionsState.options,
        (error, routes) async {
          _routingController.hideRoute();
          if (error == null && routes != null) {
            final route = routes[0];
            _routingController.showRoute(route, _routeStyle);
          } else {
            showDialog(context: context, builder: (_) =>
              AlertDialog(
                title: Text('The indoor route failed!'),
                content: SingleChildScrollView(
                  child: Text('Failed to calculate the indoor route!'),
                ),
                actions: <Widget>[
                  TextButton(
                    child: Text('Ok'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              )
            );
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
      child: Column(children: [
        Row( children: [
          Column(children: [
            Container(
              padding: EdgeInsets.all(5),
              width: 230,
              child: Text(
                // Show a name of the geometry.
                _startPoint != null
                  ? _getWaypointDescription(_startPoint)
                  : "Long tap for a start point.",
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
                  ? _getWaypointDescription(_destinationPoint)
                  : "Tap for a destination point.",
                textAlign: TextAlign.start,
                maxLines: 2,
              ),
            ),
          ],),
          Container(
            margin: EdgeInsets.all(5),
            width: kMinInteractiveDimension,
            child: FlatButton(
              color: Colors.lightBlueAccent,
              padding: EdgeInsets.zero,
              child: Icon(Icons.directions,
                color: Colors.black, size: kMinInteractiveDimension),
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
              child: Icon(Icons.settings,
                color: Colors.black, size: kMinInteractiveDimension),
              onPressed: () {
                _indoorRouteOptionsState.isEnabled = !_indoorRouteOptionsState.isEnabled;
              },
            ),
          ),
        ],),
        IndoorRouteOptionsWidget(state: _indoorRouteOptionsState),
      ],),
    );
  }
}
