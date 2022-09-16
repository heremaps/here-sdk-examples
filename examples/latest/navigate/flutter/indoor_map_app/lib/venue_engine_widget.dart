/*
 * Copyright (C) 2020-2022 HERE Europe B.V.
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
import 'package:here_sdk/core.engine.dart';
import 'package:here_sdk/gestures.dart';
import 'package:here_sdk/venue.data.dart';
import 'package:indoor_map_app/drawing_switcher.dart';
import 'package:indoor_map_app/level_switcher.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/venue.control.dart';
import 'package:here_sdk/venue.dart';
import 'package:here_sdk/venue.service.dart';
import 'package:indoor_map_app/venue_search_controller.dart';
import 'package:indoor_map_app/venue_tap_controller.dart';
import 'package:indoor_map_app/venues_controller.dart';

import 'geometry_info.dart';

class VenueEngineWidget extends StatefulWidget {
  final VenueEngineState state;

  VenueEngineWidget({required this.state});

  @override
  VenueEngineState createState() => state;
}

// The VenueEngineState listens to different venue events and helps another
// widgets react on changes.
class VenueEngineState extends State<VenueEngineWidget> {
  HereMapController? _hereMapController;
  VenueEngine? _venueEngine;
  GeometryInfoState? _geometryInfoState;
  late VenueServiceListener _serviceListener;
  late VenueSelectionListener _venueSelectionListener;
  late VenueDrawingSelectionListener _drawingSelectionListener;
  late VenueLevelSelectionListener _levelSelectionListener;
  late VenueLifecycleListenerImpl _venueLifecycleListener;
  VenueTapController? _venueTapController;
  VenueTapListenerImpl? _tapListener;
  final _drawingSwitcherState = DrawingSwitcherState();
  final _levelSwitcherState = LevelSwitcherState();
  final _venueSearchState = VenueSearchControllerState();
  final _venuesState = VenuesControllerState();

  // Set value for hrn with your platform catalog HRN value if you want to load non default collection.
  String HRN = "";

  //Label text preference as per user choice
  final List<String> _labelPref = ["OCCUPANT_NAMES", "SPACE_NAME", "INTERNAL_ADDRESS"];

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

  @override
  void dispose() {
    // Free HERE SDK resources before the application shuts down.
    SDKNativeEngine.sharedInstance?.dispose();
    SdkContext.release();

    super.dispose();
  }

  VenueEngine? get venueEngine => _venueEngine;

  VenueSearchControllerState getVenueSearchState() {
    return _venueSearchState;
  }

  VenuesControllerState getVenuesControllerState() {
    return _venuesState;
  }

  set(HereMapController hereMapController, VenueEngine venueEngine,
      GeometryInfoState geometryInfoState) {
    _hereMapController = hereMapController;
    _venueEngine = venueEngine;
    _geometryInfoState = geometryInfoState;
  }

  selectVenue(int venueId) {
    if (_venueEngine != null) {
      // Select venue by ID.
      _venueEngine!.venueMap.selectVenueAsyncWithErrors(venueId, (VenueErrorCode? venueLoadError) {
        String errorMsg;
        switch(venueLoadError) {
          case VenueErrorCode.noNetwork:
            errorMsg = "The device has no internet connectivity";
            break;
          case VenueErrorCode.noMetaDataFound:
            errorMsg = "Meta data not present in platform collection catalog";
            break;
          case VenueErrorCode.hrnMissing:
            errorMsg = "HRN not provided. Please insert HRN";
            break;
          case VenueErrorCode.hrnMismatch:
            errorMsg = "HRN does not match with Auth key & secret";
            break;
          case VenueErrorCode.noDefaultCollection:
            errorMsg = "Default collection missing from platform collection catalog";
            break;
          case VenueErrorCode.mapIdNotFound:
            errorMsg = "Map ID requested is not part of the default collection";
            break;
          case VenueErrorCode.mapDataIncorrect:
            errorMsg = "Map data in collection is wrong";
            break;
          case VenueErrorCode.internalServerError:
            errorMsg = "Internal Server Error";
            break;
          case VenueErrorCode.serviceUnavailable:
            errorMsg = "Requested service is not available currently. Please try after some time";
            break;
          default:
            errorMsg = "Unknown Error encountered";
        }

        // set up the button
        Widget okButton = TextButton(
          child: Text("OK"),
          onPressed: () { Navigator.of(context, rootNavigator: true).pop('dialog'); },
        );

        // set up the AlertDialog
        AlertDialog alert = AlertDialog(
          title: Text("Attention"),
          content: Text(errorMsg),
          actions: [
            okButton,
          ],
        );

        // show the dialog
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return alert;
          },
        );

      });
    }
  }

  onVenueEngineCreated() {
    var venueMap = venueEngine!.venueMap;
    // Add needed listeners.
    _serviceListener = VenueServiceListenerImpl();
    _venueEngine!.venueService.addServiceListener(_serviceListener);
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
        hereMapController: _hereMapController, venueMap: venueMap, geometryInfoState: _geometryInfoState);
    _tapListener = VenueTapListenerImpl(_venueTapController);

    // Set a tap listener.
    _hereMapController!.gestures.tapListener = _tapListener;
    _venueSearchState.set(_venueTapController);
    _venuesState.set(venueMap);
    // Start VenueEngine. Once authentication is done, the authentication
    // callback will be triggered. Afterwards, VenueEngine will start
    // VenueService. Once VenueService is initialized,
    // VenueServiceListener.onInitializationCompleted method will be called.
    venueEngine!.start(_onAuthCallback);

    if(HRN != "") {
      // Set platform catalog HRN
      venueEngine!.venueService.setHrn(HRN);
    }

    // Set label text preference
    venueEngine!.venueService.setLabeltextPreference(_labelPref);
  }

  _onAuthCallback(AuthenticationError? error, AuthenticationData? data) {
    if (error != null) {
      print("Failed to authenticate the venue engine: " + error.toString());
    }
  }

  onVenueSelectionChanged(Venue? selectedVenue) {
    _venueSearchState.setVenue(selectedVenue);
    if (selectedVenue != null) {
      // Move camera to the selected venue.
      _hereMapController!.camera.lookAtPoint(selectedVenue.venueModel.center);
    }
    // Update the selected drawing with a new selected venue.
    onDrawingSelectionChanged(selectedVenue);
  }

  onDrawingSelectionChanged(Venue? selectedVenue) {
    // Update the DrawingSwitcherState.
    _drawingSwitcherState.onDrawingsChanged(selectedVenue);
    // Update the selected level with a new selected drawing.
    onLevelSelectionChanged(selectedVenue);
  }

  onLevelSelectionChanged(Venue? selectedVenue) {
    // Update the LevelSwitcherState.
    _levelSwitcherState.onLevelsChanged(selectedVenue);
    // Deselect the geometry in case of a selection of a level.
    _venueTapController!.onLevelChanged(selectedVenue);
  }

  onVenuesChanged() {
    onVenueSelectionChanged(_venueEngine!.venueMap.selectedVenue);
    _venuesState.setState(() {});
  }
}

// Listener for the VenueService event.
class VenueServiceListenerImpl implements VenueServiceListener {
  @override
  onInitializationCompleted(VenueServiceInitStatus result) {
    if (result != VenueServiceInitStatus.onlineSuccess) {
      print("VenueService failed to initialize!");
    }
  }

  @override
  onVenueServiceStopped() {}

  @override
  void release() {
    // Deprecated. Nothing to to here.
  }
}

// A listener for the venue selection event.
class VenueSelectionListenerImpl implements VenueSelectionListener {
  late VenueEngineState _venueEngineState;

  VenueSelectionListenerImpl(VenueEngineState venueEngineState) {
    _venueEngineState = venueEngineState;
  }

  @override
  onSelectedVenueChanged(Venue? deselectedVenue, Venue? selectedVenue) {
    _venueEngineState.onVenueSelectionChanged(selectedVenue);
  }

  @override
  void release() {
    // Deprecated. Nothing to to here.
  }
}

// A listener for the drawing selection event.
class DrawingSelectionListenerImpl implements VenueDrawingSelectionListener {
  late VenueEngineState _venueEngineState;

  DrawingSelectionListenerImpl(VenueEngineState venueEngineState) {
    _venueEngineState = venueEngineState;
  }

  @override
  onDrawingSelected(Venue venue, VenueDrawing? deselectedDrawing, VenueDrawing selectedDrawing) {
    _venueEngineState.onDrawingSelectionChanged(venue);
  }

  @override
  void release() {
    // Deprecated. Nothing to to here.
  }
}

// A listener for the level selection event.
class LevelSelectionListenerImpl implements VenueLevelSelectionListener {
  late VenueEngineState _venueEngineState;

  LevelSelectionListenerImpl(VenueEngineState venueEngineState) {
    _venueEngineState = venueEngineState;
  }

  @override
  onLevelSelected(Venue venue, VenueDrawing drawing, VenueLevel? deselectedLevel, VenueLevel selectedLevel) {
    _venueEngineState.onLevelSelectionChanged(venue);
  }

  @override
  void release() {
    // Deprecated. Nothing to to here.
  }
}

// A listener for the venues lifecycle event.
class VenueLifecycleListenerImpl implements VenueLifecycleListener {
  late VenueEngineState _venueEngineState;

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

  @override
  void release() {
    // Deprecated. Nothing to to here.
  }
}

// A listener for the map tap event.
class VenueTapListenerImpl implements TapListener {
  VenueTapController? _tapController;

  VenueTapListenerImpl(VenueTapController? tapController) {
    _tapController = tapController;
  }

  @override
  onTap(Point2D origin) {
      // Otherwise, redirect the event to the venue tap controller.
      _tapController!.onTap(origin);
  }
  @override
  void release() {
    // Deprecated. Nothing to to here.
  }
}

