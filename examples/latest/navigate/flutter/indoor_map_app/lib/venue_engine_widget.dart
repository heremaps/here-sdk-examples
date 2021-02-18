/*
 * Copyright (C) 2020-2021 HERE Europe B.V.
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
import 'package:here_sdk/core.dart';
import 'package:here_sdk/gestures.dart';
import 'package:here_sdk/venue.data.dart';
import 'package:indoor_map/drawing_switcher.dart';
import 'package:indoor_map/indoor_routing_widget.dart';
import 'package:indoor_map/level_switcher.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/venue.control.dart';
import 'package:here_sdk/venue.dart';
import 'package:here_sdk/venue.service.dart';
import 'package:indoor_map/venue_search_controller.dart';
import 'package:indoor_map/venue_tap_controller.dart';
import 'package:indoor_map/venues_controller.dart';

import 'geometry_info.dart';

class VenueEngineWidget extends StatefulWidget {
  final VenueEngineState state;

  VenueEngineWidget({@required this.state});

  @override
  VenueEngineState createState() => state;
}

// The VenueEngineState listens to different venue events and helps another
// widgets react on changes.
class VenueEngineState extends State<VenueEngineWidget> {
  HereMapController _hereMapController;
  VenueEngine _venueEngine;
  IndoorRoutingState _indoorRoutingState;
  GeometryInfoState _geometryInfoState;
  VenueServiceListener _serviceListener;
  VenueSelectionListener _venueSelectionListener;
  VenueDrawingSelectionListener _drawingSelectionListener;
  VenueLevelSelectionListener _levelSelectionListener;
  VenueLifecycleListenerImpl _venueLifecycleListener;
  VenueTapController _venueTapController;
  VenueTapListenerImpl _tapListener;
  VenueLongPressListenerImpl _longPressListener;
  final _drawingSwitcherState = DrawingSwitcherState();
  final _levelSwitcherState = LevelSwitcherState();
  final _venueSearchState = VenueSearchControllerState();
  final _venuesState = VenuesControllerState();

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      // Add a drawing switcher.
      DrawingSwitcher(state: _drawingSwitcherState),
      // Add a level switcher.
      LevelSwitcher(state: _levelSwitcherState),
      // Add a venue search controller.
      VenueSearchController(state: _venueSearchState),
      // Add a venues controller.
      VenuesController(state: _venuesState),
    ]);
  }

  VenueEngine get venueEngine => _venueEngine;

  VenueSearchControllerState getVenueSearchState() {
    return _venueSearchState;
  }

  VenuesControllerState getVenuesControllerState() {
    return _venuesState;
  }

  set(HereMapController hereMapController, VenueEngine venueEngine,
      IndoorRoutingState indoorRoutingState, GeometryInfoState geometryInfoState) {
    _hereMapController = hereMapController;
    _venueEngine = venueEngine;
    _indoorRoutingState = indoorRoutingState;
    _geometryInfoState = geometryInfoState;
  }

  selectVenue(int venueId) {
    if (_venueEngine != null) {
      // Select venue by ID.
      _venueEngine.venueMap.selectVenueAsync(venueId);
    }
  }

  onVenueEngineCreated() {
    var venueMap = venueEngine.venueMap;
    // Add needed listeners.
    _serviceListener = VenueServiceListenerImpl();
    _venueEngine.venueService.addServiceListener(_serviceListener);
    _venueSelectionListener = VenueSelectionListenerImpl(this);
    _drawingSelectionListener = DrawingSelectionListenerImpl(this);
    _levelSelectionListener = LevelSelectionListenerImpl(this);
    _venueLifecycleListener = VenueLifecycleListenerImpl(this);
    venueMap.addVenueSelectionListener(_venueSelectionListener);
    venueMap.addDrawingSelectionListener(_drawingSelectionListener);
    venueMap.addLevelSelectionListener(_levelSelectionListener);
    venueMap.addVenueLifecycleListener(_venueLifecycleListener);
    // Create a venue tap controller.
    _venueTapController = VenueTapController(
        hereMapController: _hereMapController,
        venueMap: venueMap,
        geometryInfoState: _geometryInfoState);
    _indoorRoutingState.set(_hereMapController, venueEngine);
    _tapListener = VenueTapListenerImpl(_indoorRoutingState, _venueTapController);
    _longPressListener = VenueLongPressListenerImpl(_indoorRoutingState);
    // Set a tap listener.
    _hereMapController.gestures.tapListener = _tapListener;
    _hereMapController.gestures.longPressListener = _longPressListener;
    _venueSearchState.set(_venueTapController);
    _venuesState.set(venueMap);
    // Start VenueEngine. Once authentication is done, the authentication
    // callback will be triggered. Afterwards, VenueEngine will start
    // VenueService. Once VenueService is initialized,
    // VenueServiceListener.onInitializationCompleted method will be called.
    venueEngine.start(_onAuthCallback);
  }

  _onAuthCallback(AuthenticationError error, AuthenticationData data) {
    if (error != null) {
      print("Failed to authenticate the venue engine: " + error.toString());
    }
  }

  onVenueSelectionChanged(Venue selectedVenue) {
    _venueSearchState.setVenue(selectedVenue);
    if (selectedVenue != null) {
      // Move camera to the selected venue.
      _hereMapController.camera.lookAtPoint(selectedVenue.venueModel.center);
    }
    // Update the selected drawing with a new selected venue.
    onDrawingSelectionChanged(selectedVenue);
  }

  onDrawingSelectionChanged(Venue selectedVenue) {
    // Update the DrawingSwitcherState.
    _drawingSwitcherState.onDrawingsChanged(selectedVenue);
    // Update the selected level with a new selected drawing.
    onLevelSelectionChanged(selectedVenue);
  }

  onLevelSelectionChanged(Venue selectedVenue) {
    // Update the LevelSwitcherState.
    _levelSwitcherState.onLevelsChanged(selectedVenue);
    // Deselect the geometry in case of a selection of a level.
    _venueTapController.onLevelChanged(selectedVenue);
  }

  onVenuesChanged() {
    onVenueSelectionChanged(_venueEngine.venueMap.selectedVenue);
    _venuesState.setState(() {});
  }
}

// Listener for the VenueService event.
class VenueServiceListenerImpl extends VenueServiceListener {
  @override
  onInitializationCompleted(VenueServiceInitStatus result) {
    if (result != VenueServiceInitStatus.onlineSuccess) {
      print("VenueService failed to initialize!");
    }
  }

  @override
  onVenueServiceStopped() {}
}

// A listener for the venue selection event.
class VenueSelectionListenerImpl extends VenueSelectionListener {
  VenueEngineState _venueEngineState;

  VenueSelectionListenerImpl(VenueEngineState venueEngineState) {
    _venueEngineState = venueEngineState;
  }

  @override
  onSelectedVenueChanged(Venue deselectedVenue, Venue selectedVenue) {
    _venueEngineState.onVenueSelectionChanged(selectedVenue);
  }
}

// A listener for the drawing selection event.
class DrawingSelectionListenerImpl extends VenueDrawingSelectionListener {
  VenueEngineState _venueEngineState;

  DrawingSelectionListenerImpl(VenueEngineState venueEngineState) {
    _venueEngineState = venueEngineState;
  }

  @override
  onDrawingSelected(Venue venue, VenueDrawing deselectedDrawing,
      VenueDrawing selectedDrawing) {
    _venueEngineState.onDrawingSelectionChanged(venue);
  }
}

// A listener for the level selection event.
class LevelSelectionListenerImpl extends VenueLevelSelectionListener {
  VenueEngineState _venueEngineState;

  LevelSelectionListenerImpl(VenueEngineState venueEngineState) {
    _venueEngineState = venueEngineState;
  }

  @override
  onLevelSelected(Venue venue, VenueDrawing drawing, VenueLevel deselectedLevel,
      VenueLevel selectedLevel) {
    _venueEngineState.onLevelSelectionChanged(venue);
  }
}

// A listener for the venues lifecycle event.
class VenueLifecycleListenerImpl extends VenueLifecycleListener {
  VenueEngineState _venueEngineState;

  VenueLifecycleListenerImpl(VenueEngineState venueEngineState) {
    _venueEngineState = venueEngineState;
  }

  @override
  onVenueAdded(Venue venue) {
    _venueEngineState.onVenuesChanged();
  }

  @override
  onVenueRemoved(int venueId) {
    _venueEngineState.onVenuesChanged();
  }
}

// A listener for the map tap event.
class VenueTapListenerImpl extends TapListener {
  IndoorRoutingState _indoorRoutingState;
  VenueTapController _tapController;

  VenueTapListenerImpl(IndoorRoutingState indoorRoutingState, VenueTapController tapController) {
    _indoorRoutingState = indoorRoutingState;
    _tapController = tapController;
  }

  @override
  onTap(Point2D origin) {
    if (_indoorRoutingState.isEnabled) {
      // In case if the indoor routing state is visible, set a destination point.
      _indoorRoutingState.setDestinationPoint(origin);
    } else {
      // Otherwise, redirect the event to the venue tap controller.
      _tapController.onTap(origin);
    }
  }
}

// A listener for the map long press event.
class VenueLongPressListenerImpl extends LongPressListener {
  IndoorRoutingState _indoorRoutingState;

  VenueLongPressListenerImpl(IndoorRoutingState indoorRoutingState) {
    _indoorRoutingState = indoorRoutingState;
  }

  @override
  onLongPress(GestureState state, Point2D origin  ) {
    if (_indoorRoutingState.isEnabled) {
      // In case if the indoor routing state is visible, set a start point.
      _indoorRoutingState.setStartPoint(origin);
    }
  }
}
