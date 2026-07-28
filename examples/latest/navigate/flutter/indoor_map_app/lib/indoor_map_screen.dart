/*
 * Copyright (C) 2020-2026 HERE Europe B.V.
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
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:indoor_map_app/indoor_drawing_switcher.dart';
import 'package:indoor_map_app/indoor_events.dart';
import 'package:indoor_map_app/indoor_level_switcher.dart';
import 'package:indoor_map_app/indoor_routing_data_provider.dart';
import 'package:indoor_map_app/indoor_routing_main_menu.dart';
import 'package:indoor_map_app/indoor_routing_space_preview.dart';
import 'package:indoor_map_app/indoor_routing_space_selection_list.dart';
import 'package:indoor_map_app/indoor_topology_info.dart';
import 'package:indoor_map_app/indoor_topology_info_widget.dart';
import 'package:indoor_map_app/indoor_venue_bottom_sheet_widget.dart';
import 'package:indoor_map_app/indoor_venue_engine.dart';
import 'package:indoor_map_app/venue_data_provider.dart';
import 'package:indoor_map_app/venue_error_data.dart';
import 'package:indoor_map_app/venue_tap_controller.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/venue.control.dart';
import 'package:here_sdk/venue.dart';

/// Entry point for the indoor maps feature.
///
/// Wraps [VenueDataProvider] and [IndoorRoutingDataProvider] in a
/// [MultiProvider] and renders the HERE map with all indoor-map overlays
/// (venue list / geometry bottom sheet, routing panels, level/drawing switchers,
/// topology info).
///
class IndoorMapScreen extends StatefulWidget {
  const IndoorMapScreen({super.key});

  @override
  State<IndoorMapScreen> createState() => _IndoorMapScreenState();
}

class _IndoorMapScreenState extends State<IndoorMapScreen> {
  // -------- Map camera --------
  static const double _distanceToEarthInMeters = 500;
  static final GeoCoordinates _defaultGeoCoords = GeoCoordinates(52.530932, 13.384915);

  HereMapController? _mapController;

  // -------- HERE watermark position --------
  final double _watermarkH = 1.0;
  final double _watermarkV = 0.84;

  // -------- VenueEngine wrapper --------
  late IndoorVenueEngine _indoorVenueEngine;
  bool _isVenueEngineInitialized = false;

  VenueEngine? _venueEngine;
  late VenueMap _venueMap;
  late VenueTapController _venueTapController;

  // -------- Providers --------
  late VenueDataProvider _venueDataProvider;
  late IndoorRoutingDataProvider _routingDataProvider;

  // -------- Bottom sheet --------
  late final DraggableScrollableController _venueBottomSheetController;
  static const double _minBottomSheetSize = 0.13;
  static const double _maxBottomSheetSize = 1.0;
  late final GlobalKey<IndoorVenueBottomSheetWidgetState> _venueBottomSheetKey = GlobalKey();

  // -------- Map feature toggle --------
  static final List<String> _disabledMapFeatures = <String>[MapFeatures.extrudedBuildings, MapFeatures.landmarks];

  // -------- Switcher layout constants --------
  static const double _levelSwitcherBaseHeight = 82.0;
  static const double _levelSwitcherRowHeight = 40.0;
  static const int _levelSwitcherMaxVisibleRows = 3;
  static const double _drawingSwitcherButtonHeight = 40.0;
  static const double _drawingSwitcherRowHeight = 60.0;
  static const int _drawingSwitcherMaxVisibleRows = 3;
  static const double _switcherGap = 4.0;

  @override
  void initState() {
    super.initState();
    _venueBottomSheetController = DraggableScrollableController();

    // Initialise global event handlers before the venue engine starts.
    venueIdList = VenueIdListEventHandler();
    venueNameList = VenueNameListEventHandler();
    filteredVenueIdList = VenueIdListEventHandler();
    filteredVenueNameList = VenueNameListEventHandler();

    _venueDataProvider = context.read<VenueDataProvider>();
    _routingDataProvider = context.read<IndoorRoutingDataProvider>();
  }

  @override
  void dispose() {
    if (_isVenueEngineInitialized) {
      _indoorVenueEngine.dispose();
    }
    _venueEngine = null;
    _venueBottomSheetController.dispose();
    _venueDataProvider.resetDataProviderParam();
    venueIdList.dispose();
    venueNameList.dispose();
    filteredVenueIdList.dispose();
    filteredVenueNameList.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Map lifecycle
  // ---------------------------------------------------------------------------

  void _onMapCreated(HereMapController controller) {
    _mapController = controller;
    _mapController!.mapScene.loadSceneForMapScheme(MapScheme.normalDay, _onMapSceneLoaded);
  }

  void _onMapSceneLoaded(MapError? error) {
    if (error != null) {
      _showErrorDialog('Map error', 'Map scene could not be loaded: $error');
      return;
    }

    final MapMeasure zoom = MapMeasure(MapMeasureKind.distanceInMeters, _distanceToEarthInMeters);
    _mapController!.camera.lookAtPointWithMeasure(_defaultGeoCoords, zoom);
    _mapController!.setWatermarkLocation(Anchor2D.withHorizontalAndVertical(_watermarkH, _watermarkV), Point2D(0, 0));
    _mapController!.mapScene.disableFeatures(_disabledMapFeatures);

    try {
      _indoorVenueEngine = IndoorVenueEngine(
        mapController: _mapController!,
        providerInterface: _venueDataProvider,
        routingDataProviderInterface: _routingDataProvider,
        onAuthErrorCallback: (String reason) {
            _venueDataProvider.isAuthenticationFailed = true;
            _venueDataProvider.notifyListeners();
            _showErrorDialog('Authentication Error', reason);
        },
      );
      _indoorVenueEngine.createVenueEngine();
      _indoorVenueEngine.venueEngineInitCompleted.then((_) => _onVenueEngineReady());
    } on InstantiationException catch (e) {
      _showErrorDialog('Venue engine error', 'Could not create Venue Engine: $e');
    }
  }

  void _onVenueEngineReady() {
    if (!mounted) return;
    _venueEngine = _indoorVenueEngine.venueEngine!;
    _venueMap = _venueEngine!.venueMap;
    _venueTapController = _indoorVenueEngine.venueTapController!;
    _isVenueEngineInitialized = true;

    _venueDataProvider
      ..setVenueEngine(_venueEngine!)
      ..setTapController(_venueTapController);

    _routingDataProvider.initializeIndoorRoutingDataProvider(_venueEngine!, _mapController!, _venueDataProvider);
  }

  void _loadBaseMap() {
    _mapController?.mapScene.loadSceneForMapScheme(MapScheme.normalDay, (MapError? e) {
      if (e != null) {
        _showErrorDialog('Map error', 'Map scene reload failed: $e');
        return;
      }
      final MapMeasure zoom = MapMeasure(MapMeasureKind.distanceInMeters, _distanceToEarthInMeters);
      _mapController!.camera.lookAtPointWithMeasure(_defaultGeoCoords, zoom);
      _mapController!.setWatermarkLocation(Anchor2D.withHorizontalAndVertical(_watermarkH, _watermarkV), Point2D(0, 0));
      _mapController!.mapScene.disableFeatures(_disabledMapFeatures);
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _venueNameForId(String venueId) {
    for (int i = 0; i < venueIdList.updatedIdList.value.length; i++) {
      if (venueIdList.updatedIdList.value[i] == venueId) {
        return venueNameList.updatedNameList.value[i];
      }
    }
    return '';
  }

  void _handleTapOnTopologyButton() {
    final Venue? selectedVenue = _venueMap.selectedVenue;
    if (selectedVenue == null) return;
    selectedVenue.isTopologyVisible = !selectedVenue.isTopologyVisible;
    _venueTapController.deselectTopology();
    _venueDataProvider.setTopologyVisibilityOnVenue(selectedVenue.isTopologyVisible);
  }

  // ---------------------------------------------------------------------------
  // Back navigation
  // ---------------------------------------------------------------------------

  Future<void> _handleBackPress() async {
    if (!mounted) return;

    // Routing panels take priority.
    if (_routingDataProvider.currentState != RoutingUIState.hidden) {
      _routingDataProvider.handleBackButtonEvent();
      return;
    }

    // Collapse expanded bottom sheet.
    if (_venueBottomSheetController.isAttached) {
      final double size = _venueBottomSheetController.size;
      if (size > _minBottomSheetSize + 0.01) {
        _venueBottomSheetKey.currentState?.sheetCollapseCleanup();
        await _venueBottomSheetController.animateTo(
          _minBottomSheetSize,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
        return;
      }
    }

    // Remove venue from map.
    if (_venueDataProvider.venueLoadedOnMap) {
      _venueTapController
        ..deselectGeometry()
        ..deselectTopology();
      _venueDataProvider.removeVenueFromMap();
      _loadBaseMap();
      return;
    }

    if (!mounted) return;
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      SystemNavigator.pop();
    }
  }

  // ---------------------------------------------------------------------------
  // Switcher layout helpers (simplified from dev-app)
  // ---------------------------------------------------------------------------

  double _computeLevelSwitcherHeight(int? levelCount) {
    if (levelCount == null || levelCount == 0) return _levelSwitcherBaseHeight;
    final int rows = levelCount.clamp(0, _levelSwitcherMaxVisibleRows);
    return _levelSwitcherBaseHeight + rows * _levelSwitcherRowHeight;
  }

  double _calcLevelSwitcherTop(double bodyHeight, int? levelCount) {
    final double totalH = _computeLevelSwitcherHeight(levelCount) + _switcherGap + _drawingSwitcherButtonHeight;
    final double visibleMapH = bodyHeight * (1.0 - _minBottomSheetSize);
    final double defaultTop = (visibleMapH - totalH) / 2;
    return defaultTop.clamp(0.0, bodyHeight);
  }

  double _computeDrawingSwitcherContainerHeight(int? drawingCount) {
    final int rows = ((drawingCount ?? 0) <= 0)
        ? 1
        : (drawingCount! > _drawingSwitcherMaxVisibleRows ? _drawingSwitcherMaxVisibleRows : drawingCount);
    return _drawingSwitcherRowHeight * rows;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bool isVenueLoading = context.select<VenueDataProvider, bool>((VenueDataProvider p) => p.isVenueLoading);
    final bool venueLoadedOnMap = context.select<VenueDataProvider, bool>((VenueDataProvider p) => p.venueLoadedOnMap);
    final bool isVenueListAvailable = context.select<VenueDataProvider, bool>(
      (VenueDataProvider p) => p.isVenueListAvailable,
    );
    final bool isAuthenticationFailed = context.select<VenueDataProvider, bool>(
      (VenueDataProvider p) => p.isAuthenticationFailed,
    );
    final bool isTopologyPresent = context.select<VenueDataProvider, bool>(
      (VenueDataProvider p) => p.isTopologyPresent,
    );
    final bool topologyVisible = context.select<VenueDataProvider, bool>(
      (VenueDataProvider p) => p.topologyVisibleOnVenue,
    );
    final IndoorTopologyInfo? topologyInfo = context.select<VenueDataProvider, IndoorTopologyInfo?>(
      (VenueDataProvider p) => p.topologyInfo,
    );
    final VenueErrorData? venueErrorData = context.select<VenueDataProvider, VenueErrorData?>(
      (VenueDataProvider p) => p.venueErrorData,
    );
    final RoutingUIState? routingUIState = context.select<IndoorRoutingDataProvider, RoutingUIState?>(
      (IndoorRoutingDataProvider p) => p.currentState,
    );
    final bool isRouteCalculating = context.select<IndoorRoutingDataProvider, bool>(
      (IndoorRoutingDataProvider p) => p.isRouteCalculating,
    );
    final int? levelCount = context.select<VenueDataProvider, int?>((VenueDataProvider p) => p.levelList?.length);
    final int? drawingCount = context.select<VenueDataProvider, int?>(
      (VenueDataProvider p) => p.venueDrawingList?.length,
    );
    final String? routingWarningMsg = context.select<IndoorRoutingDataProvider, String?>(
      (IndoorRoutingDataProvider p) => p.routingWarningMsg,
    );

    // Show error dialogs once.
    if (venueErrorData != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        String title = 'Error';
        String message = venueErrorData.errorMessage ?? 'An error occurred';
        switch (venueErrorData.errorType) {
          case VenueErrorType.venueServiceInitFailure:
            message = 'Venue service initialisation failed';
            break;
          case VenueErrorType.venueInfoListLoadFailure:
            title = 'Venue engine error';
            message = 'Venue service init failure: ${venueErrorData.errorMessage}';
            break;
          case VenueErrorType.venueLoadingFailure:
            title = 'Venue loading error';
            break;
          case VenueErrorType.venueEngineFailure:
            title = venueErrorData.title ?? title;
            break;
          default:
            break;
        }
        _showErrorDialog(title, message);
        context.read<VenueDataProvider>().resetVenueErrorDataParam();
      });
    }

    if (routingWarningMsg != null && routingWarningMsg.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showErrorDialog('Routing error', routingWarningMsg);
        context.read<IndoorRoutingDataProvider>().setRoutingWarningMsg('');
      });
    }

    final double bodyHeight = MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - kToolbarHeight;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          (venueLoadedOnMap && _venueMap.selectedVenue != null)
              ? _venueNameForId(_venueMap.selectedVenue!.venueModel.identifier)
              : 'Indoor Maps',
        ),
        leading: venueLoadedOnMap
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _handleBackPress)
            : null,
        actions: isTopologyPresent
            ? <Widget>[
                IconButton(
                  icon: topologyVisible
                      ? Image.asset('assets/topology-focused.png')
                      : Image.asset('assets/topology-default.png'),
                  onPressed: _handleTapOnTopologyButton,
                ),
              ]
            : null,
      ),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, _) async {
          if (!didPop) await _handleBackPress();
        },
        child: SafeArea(
          minimum: EdgeInsets.zero,
          child: Stack(
            children: <Widget>[
              // HERE Map
              HereMap(onMapCreated: _onMapCreated, mode: NativeViewMode.hybridComposition),

              // Loading overlay (while venue list loads or venue is being placed)
              if ((isVenueLoading || (!isVenueListAvailable) || isRouteCalculating) && !isAuthenticationFailed)
                const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),

              if (_mapController != null) ...<Widget>[
                // Level + drawing switchers (visible when a venue is loaded)
                if (venueLoadedOnMap)
                  LayoutBuilder(
                    builder: (_, BoxConstraints c) {
                      final double levelTop = _calcLevelSwitcherTop(bodyHeight, levelCount);
                      final double levelH = _computeLevelSwitcherHeight(levelCount);
                      final double drawingButtonTop = levelTop + levelH + _switcherGap;
                      final double drawingContainerH = _computeDrawingSwitcherContainerHeight(drawingCount);
                      final double drawingTop = (drawingButtonTop - (drawingContainerH - _drawingSwitcherButtonHeight))
                          .clamp(0.0, double.infinity);

                      return Stack(
                        children: <Widget>[
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 150),
                            right: 10.0,
                            top: levelTop,
                            child: const IndoorLevelSwitcher(),
                          ),
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 150),
                            right: 10.0,
                            top: drawingTop,
                            child: const IndoorDrawingSwitcher(),
                          ),
                        ],
                      );
                    },
                  ),

                // Venue / geometry bottom sheet
                if (isVenueListAvailable && routingUIState == RoutingUIState.hidden)
                  Positioned.fill(
                    child: IndoorVenueBottomSheetWidget(
                      key: _venueBottomSheetKey,
                      dragController: _venueBottomSheetController,
                      minBottomSheetSize: _minBottomSheetSize,
                      maxBottomSheetSize: _maxBottomSheetSize,
                      tapController: _venueTapController,
                    ),
                  ),

                // Topology info
                if (topologyInfo != null)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IndoorTopologyInfoWidget(topologyInfo: topologyInfo),
                  ),

                // Space preview (shown after tapping a geometry)
                if (routingUIState == RoutingUIState.spacePreview) IndoorRoutingSpacePreview(),
                // Main routing menu
                if (routingUIState == RoutingUIState.mainRoutingMenu) IndoorRoutingMainMenu(),
                // Space selection list (full-screen overlay)
                if (routingUIState == RoutingUIState.spaceSelectionList) IndoorRoutingSpaceSelectionList(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
  }
}
