/*
 * Copyright (C) 2020-2025 HERE Europe B.V.
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

import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/venue.data.dart';
import 'package:indoor_map_app/geometry_info.dart';
import 'package:indoor_map_app/level_switcher.dart';
import 'package:indoor_map_app/settings_page.dart';
import 'package:indoor_map_app/venue_engine_widget.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.engine.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/venue.dart';
import 'package:indoor_map_app/venue_tap_controller.dart';
import 'dart:convert';
import 'events.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:indoor_map_app/venue_search_controller.dart';

void main() {
  // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
  _initializeHERESDK();

  runApp(MyApp());
}

void _initializeHERESDK() async {
  // Needs to be called before accessing SDKOptions to load necessary libraries.
  SdkContext.init(IsolateOrigin.main);

  // Set your credentials for the HERE SDK.
  String accessKeyId = "VENUE_ACCESS_KEY_ID";
  String accessKeySecret = "VENUE_ACCESS_KEY_SECRET";
  AuthenticationMode authenticationMode = AuthenticationMode.withKeySecret(accessKeyId, accessKeySecret);
  SDKOptions sdkOptions = SDKOptions.withAuthenticationMode(authenticationMode);

  try {
    await SDKNativeEngine.makeSharedInstance(sdkOptions);
  } on InstantiationException {
    throw Exception("Failed to initialize the HERE SDK.");
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HERE SDK for Flutter - Indoor Map',
      initialRoute: '/',
      routes: {
        '/': (context) => MainPage(),
        '/settings': (context) => SettingsPage(),
      },
    );
  }
}

class MainPage extends StatefulWidget {
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final VenueEngineState _venueEngineState = VenueEngineState();
  final GeometryInfoState _geometryInfoState = GeometryInfoState();
  late final AppLifecycleListener _listener;
  late String _venueIdAsString = "";
  late String _selectedVenue = "Venue Id";
  List _venueList = ["Venue Id"];
  List _venueName = ["Venue Name"];
  bool _isPressed = false;
  PanelController _panelController = PanelController();
  String searchQuery = '';
  late Map<String, String> venueMap;
  late TextEditingController _searchController = TextEditingController();
  late List<String> _geometryItemsList = ["Item"];
  bool _isVenueListTapped = false;
  bool _topologyPressed = false;
  String _clickedVenueName = "";
  late HereMapController _hereMapController;
  int clickCount = 0;
  bool isTextFieldTapped = false;

  void _resetCameraPosition() {
    const double distanceToEarthInMeters = 500;
    MapMeasure mapMeasureZoom =
        MapMeasure(MapMeasureKind.distance, distanceToEarthInMeters);
    _hereMapController.camera.lookAtPointWithMeasure(
        GeoCoordinates(52.530932, 13.384915), mapMeasureZoom);

    // Hide the extruded building layer, so that it does not overlap
    // with the venues.
    _hereMapController.mapScene
        .disableFeatures([MapFeatures.extrudedBuildings]);
  }

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onDetach: () =>
      // Sometimes Flutter may not reliably call dispose(),
      // therefore it is recommended to dispose the HERE SDK
      // also when the AppLifecycleListener is detached.
      // See more details: https://github.com/flutter/flutter/issues/40940
      { print('AppLifecycleListener detached.'), _disposeHERESDK() },
    );
  }

  @override
  void dispose() {
    _disposeHERESDK();
    super.dispose();
  }

  void _disposeHERESDK() async {
    // Free HERE SDK resources before the application shuts down.
    await SDKNativeEngine.sharedInstance?.dispose();
    SdkContext.release();
    _listener.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          SlidingUpPanel(
            controller: _panelController,
            minHeight: 100,
            maxHeight: 850,
            panel: _buildSlidingPanel(),
            body: Column(
              children: [
                Padding(
                    padding: const EdgeInsets.only(
                        top: 29), // Set the desired margin top here
                    child: ValueListenableBuilder(
                        valueListenable: mapLoading.isMapLoading,
                        builder: (BuildContext context, bool isLoading,
                            Widget? child) {
                          return isLoading
                              ? Container(
                                  width: double.infinity,
                                  height: 60,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Padding(
                                            padding: EdgeInsets.only(left: 20),
                                            child: GestureDetector(
                                              onTap: () =>
                                                  _handleBackButtonPress(
                                                      context),
                                              child: Image.asset(
                                                'assets/back-button.png',
                                                width: 24,
                                                height: 24,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Container(
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width -
                                                105,
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 8),
                                              child: Text(
                                                _clickedVenueName,
                                                style: TextStyle(fontSize: 16),
                                                textAlign: TextAlign.left,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _topologyPressed =
                                                    !_topologyPressed;
                                              });
                                              _venueEngineState
                                                      .venueEngine!
                                                      .venueMap
                                                      .selectedVenue!
                                                      .isTopologyVisible =
                                                  _topologyPressed;
                                            },
                                            child: Image.asset(
                                              _topologyPressed
                                                  ? 'assets/topology-focused.png'
                                                  : 'assets/topology-default.png',
                                              width: 40,
                                              height: 40,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Padding(
                                        padding:
                                            EdgeInsets.only(left: 5, right: 5),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            ValueListenableBuilder<List>(
                                              builder: (BuildContext context,
                                                  List value, Widget? child) {
                                                _venueList = value;
                                                return SizedBox();
                                              },
                                              valueListenable:
                                                  listEventHandler.updatedList,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Container();
                        })),
                Expanded(
                  child: Stack(
                    children: <Widget>[
                      HereMap(onMapCreated: _onMapCreated),
                      VenueEngineWidget(state: _venueEngineState),
                      ValueListenableBuilder<bool>(
                        valueListenable: mapLoading.isMapLoading,
                        builder: (BuildContext context, bool isLoading,
                            Widget? child) {
                          return Center(
                            child: Stack(
                              children: [
                                !_isVenueListTapped || isLoading
                                    ? SizedBox() // Empty container when not loading or not tapped
                                    : Transform.translate(
                                        offset: Offset(0, -150),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          padding: EdgeInsets.all(16),
                                          child: CircularProgressIndicator(
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.black),
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                GeometryInfo(state: _geometryInfoState),
              ],
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: topologyLineTapped.isTopologyLineTapped,
            builder: (BuildContext context, bool isTapped, Widget? child) {
              return Visibility(
                visible: isTapped && _topologyPressed,
                child: Positioned(
                  bottom: 0,
                  child: Container(
                    width: MediaQuery.of(context).size.width,
                    height: 250,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_venueEngineState
                                .venueTapController?.topologyDetails !=
                            null)
                          ..._buildRowsFromTopologyDetails(_venueEngineState
                              .venueTapController!.topologyDetails),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRowsFromTopologyDetails(String topologyDetails) {
    List<Widget> rows = [];
    List<String> lines = topologyDetails.split('\n');

    for (String line in lines) {
      List<Widget> rowItems = [];
      List<String> parts = line.split(' ');
      int pngCount = parts.where((part) => part.endsWith('.png')).length;

      for (String part in parts) {
        if (part.endsWith('.png')) {
          rowItems.add(
            Image.asset(
              'assets/$part',
              height: 30.0,
              width: 30.0,
            ),
          );
        } else {
          rowItems.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                part,
                style: TextStyle(
                  fontSize: 16,
                ),
              ),
            ),
          );
        }
      }

      if (pngCount > 0) {
        double blankSpace = 0;
        if (pngCount == 1) {
          blankSpace = 150.0;
        } else if (pngCount == 2) {
          blankSpace = 122.0;
        } else if (pngCount == 3) {
          blankSpace = 92.0;
        } else if (pngCount >= 4) {
          blankSpace = 62.0;
        }
        rowItems.insert(pngCount, SizedBox(width: blankSpace));
      }

      rows.add(Column(
        children: [
          Row(children: rowItems),
          SizedBox(height: 15.0),
        ],
      ));
    }

    return rows;
  }

  Widget _buildSlidingPanel() {
    return Column(
      children: [
        // Non-scrollable elements
        GestureDetector(
          onPanUpdate: (details) {},
          onPanEnd: (details) {},
          child: Container(
            padding: EdgeInsets.all(8.0),
            height: 25,
            child: Image.asset('assets/indoor_handle.png'),
          ),
        ),
        Container(
          margin: EdgeInsets.all(8.0),
          padding: EdgeInsets.all(8.0),
          height: 60,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: ValueListenableBuilder<bool>(
            valueListenable: mapLoading.isMapLoading,
            builder: (context, isMapLoading, child) {
              return TextField(
                controller: _searchController,
                onChanged: (query) {
                  setState(() {
                    searchQuery = query.toLowerCase();
                  });
                },
                onTap: () {
                  _panelController.animatePanelToPosition(1.0);
                },
                decoration: InputDecoration(
                  hintText: isMapLoading ? 
		  	'Search for spaces' 
			: 'Search for venues',
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                  labelStyle: TextStyle(
                      color: isTextFieldTapped ? Colors.black : Colors.black),
                  suffix: searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            setState(() {
                              _searchController.clear();
                              searchQuery = '';
                              isTextFieldTapped = true;
                            });
                          },
                          child: Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey,
                            ),
                            child: Icon(
                              Icons.clear,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : null,
                ),
              );
            },
          ),
        ),
        Container(
          alignment: Alignment.topCenter,
          child: ValueListenableBuilder<List>(
            builder: (BuildContext context, List value, Widget? child) {
              _venueList = value;
              if (_venueList.length == 1) {
                return Container(
                  height:
                      650, // Set the height of the container to match the sliding panel height
                  alignment: Alignment.center, // Center its child vertically
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                );
              } else {
                // Return an empty SizedBox to occupy no space
                return SizedBox.shrink();
              }
            },
            valueListenable: listEventHandler.updatedList,
          ),
        ),
        SizedBox(height: 0),
        // Scrollable elements
        Expanded(
          child: _buildDataTable(),
        ),
      ],
    );
  }

  Widget _buildDataTable() {
    return ValueListenableBuilder<bool>(
      valueListenable: mapLoading.isMapLoading,
      builder: (context, isMapLoading, child) {
        if (isMapLoading) {
          return ValueListenableBuilder<bool>(
            valueListenable: spaceTapped.isSpaceTapped,
            builder: (context, isSpaceTapped, child) {
              if (isSpaceTapped) {
                if(MediaQuery.of(context).viewInsets.bottom > 1)
                  _panelController.animatePanelToPosition(0.5);
                else
                  _panelController.animatePanelToPosition(0.12);
                return SingleChildScrollView(
                  child: DataTable(
                    headingRowHeight: 0,
                    columns: [
                      DataColumn(label: Text('')),
                      DataColumn(label: Text('')),
                      DataColumn(label: Text('')),
                    ],
                    rows: _buildSingleTableRow(
                        searchQuery, _venueEngineState.geometryList),
                  ),
                );
              } else {
                return SingleChildScrollView(
                  child: DataTable(
                    headingRowHeight: 0,
                    columns: [
                      DataColumn(label: Text('')),
                      DataColumn(label: Text('')),
                      DataColumn(label: Text('')),
                    ],
                    rows: _buildTableRowsOfLoadedVenue(
                        searchQuery, _venueEngineState.geometryList),
                  ),
                );
              }
            },
          );
        } else {
          return ValueListenableBuilder<List<String>>(
            valueListenable: nameListEventHandler.updatedNameList,
            builder: (context, venueNames, child) {
              _venueName = venueNames.cast<String>();
              return SingleChildScrollView(
                child: DataTable(
                  headingRowHeight: 0,
                  columns: [
                    DataColumn(label: Text('')),
                    DataColumn(label: Text('')),
                    DataColumn(label: Text('')),
                  ],
                  rows: _buildTableRows(searchQuery, _venueName.cast<String>()),
                ),
              );
            },
          );
        }
      },
    );
  }

  List<DataRow> _buildSingleTableRow(
      String searchQuery, List<String> venueList) {

    List<DataRow> rows = [];
    rows.clear();
    rows.add(
      DataRow(
        cells: [
          DataCell(
            GestureDetector(
              onTap: () {
                //Do Nothing
              },
              child: Container(
                width: 20,
                child: Image.asset('assets/indoor_rowleft.png',
                    width: 20, height: 22),
              ),
            ),
          ),
          DataCell(
            GestureDetector(
              onTap: () {
                //Do Nothing
              },
              child: Container(
                //width: 225,
                width: MediaQuery.of(context).size.width - 200,
                child: Text(
                  _venueEngineState.venueTapController!.tappedSpaceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          DataCell(
            GestureDetector(
              onTap: () {
                //Do Nothing
              },
              child: Container(
                width: 16,
                child: Image.asset('assets/indoor_rowright.png',
                    width: 16, height: 18),
              ),
            ),
          ),
        ],
      ),
    );
    return rows;
  }

  List<DataRow> _buildTableRowsOfLoadedVenue(
      String searchQuery, List<String> venueList) {
    if (_venueEngineState.venueTapController?.clickCount == 1) {
      FocusScope.of(context).unfocus();
      _panelController.animatePanelToPosition(0.0);
      _venueEngineState.venueTapController?.clickCount = 0;
    }

    List<DataRow> rows = [];
    rows.clear();
    for (int i = 1; i < venueList.length; i++) {
      String venue = venueList[i];
      if (venue.toLowerCase().contains(searchQuery)) {
        rows.add(
          DataRow(
            cells: [
              DataCell(
                GestureDetector(
                  onTap: () {
                    onTapRowOfLoadedVenue(venue);
                  },
                  child: Container(
                    width: 20,
                    child: Image.asset('assets/indoor_rowleft.png',
                        width: 20, height: 22),
                  ),
                ),
              ),
              DataCell(
                GestureDetector(
                  onTap: () {
                    onTapRowOfLoadedVenue(venue);
                  },
                  child: Container(
                    //width: 225,
                    width: MediaQuery.of(context).size.width - 200,
                    child: Text(
                      venue,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              DataCell(
                GestureDetector(
                  onTap: () {
                    onTapRowOfLoadedVenue(venue);
                  },
                  child: Container(
                    width: 16,
                    child: Image.asset('assets/indoor_rowright.png',
                        width: 16, height: 18),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }

    return rows;
  }

  List<DataRow> _buildTableRows(String searchQuery, List<String> venueList) {
    List<DataRow> rows = [];

    // Ensure both _venueName and _venueList are of type List<String>
    List<String> venueNameList = _venueName.cast<String>();
    List<String> venueListString = _venueList.cast<String>();

    // Create a map to link venue names to venue IDs
    venueMap = Map.fromIterables(venueNameList, venueListString);
    for (int i = 1; i < venueList.length; i++) {
      String venue = venueList[i];

      // Check if the current row matches the search query
      if (venue.toLowerCase().contains(searchQuery)) {
        rows.add(
          DataRow(
            cells: [
              DataCell(
                GestureDetector(
                  onTap: () {
                    onTapRow(venue);
                  },
                  child: Container(
                    width: 20,
                    child: Image.asset('assets/indoor_row_icon.png',
                        width: 20, height: 22),
                  ),
                ),
              ),
              DataCell(
                GestureDetector(
                  onTap: () {
                    onTapRow(venue);
                  },
                  child: Container(
                    //width: 225,
                    width: MediaQuery.of(context).size.width - 200,
                    child: Text(
                      venue,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              DataCell(
                GestureDetector(
                  onTap: () {
                    onTapRow(venue);
                  },
                  child: Container(
                    width: 16,
                    child: Image.asset('assets/indoor_rightaccessory.png',
                        width: 16, height: 18),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }

    return rows;
  }

  void onTapRowOfLoadedVenue(String venue) {
    _searchController.text = '';
    searchQuery = '';
    _searchController.clear();

    print('clicked spaces for loaded venue: $venue');
    final index = _venueEngineState.geometryList.indexOf(venue) - 1;
    print('index value : $index');

    if (_venueEngineState.venueTapController != null &&
        _venueEngineState != null) {
      _venueEngineState.venueTapController?.selectGeometry(
          _venueEngineState.getVenueSearchState().searchResult[index],
          _venueEngineState.getVenueSearchState().searchResult[index].center,
          true);
    }

    FocusScope.of(context).unfocus();
    _panelController.animatePanelToPosition(0.0);

    _buildSlidingPanel();
  }

  void onTapRow(String venue) {
    _searchController.text = '';
    searchQuery = '';
    _searchController.clear();
    print('clicked name of venue: $venue');
    _clickedVenueName = venue;

    _isVenueListTapped = true;

    if (mapLoading.isMapLoading.value) {
      print("true");
    } else {
      print("false");
    }

    mapLoading.isMapLoading.value = true;
    mapLoading.isMapLoading.value = false;

    // Perform additional actions when a row is tapped
    String venueIdentifier = venueMap[venue] ?? "";
    if (venueIdentifier.isNotEmpty) {
      _venueEngineState.selectVenue(venueIdentifier);
    } else {
      print('Venue Identifier not found for venue: $venue');
    }

    FocusScope.of(context).unfocus();
    _panelController.animatePanelToPosition(0.0);

    _buildSlidingPanel();
  }

  void _onMapCreated(HereMapController hereMapController) {
    _hereMapController = hereMapController;
    // Load a scene from the HERE SDK to render the map with a map scheme.
    hereMapController.mapScene.loadSceneForMapScheme(MapScheme.normalDay,
        (MapError? error) {
      if (error != null) {
        print('Map scene not loaded. MapError: ${error.toString()}');
        return;
      }

      const double distanceToEarthInMeters = 500;
      MapMeasure mapMeasureZoom =
          MapMeasure(MapMeasureKind.distance, distanceToEarthInMeters);
      hereMapController.camera.lookAtPointWithMeasure(
          GeoCoordinates(52.530932, 13.384915), mapMeasureZoom);

      // Hide the extruded building layer, so that it does not overlap
      // with the venues.
      hereMapController.mapScene
          .disableFeatures([MapFeatures.extrudedBuildings]);

      // Create a venue engine object. Once the initialization is done,
      // a callback will be called.
      var venueEngine;
      try {
        venueEngine = VenueEngine(_onVenueEngineCreated);
        _venueEngineState.set(
            hereMapController, venueEngine, _geometryInfoState);
      } on InstantiationException catch (e) {
        print('error caught: $e');
      }
    });
    setWatermarkLocation(hereMapController);
  }

  _onVenueEngineCreated() {
    _venueEngineState.onVenueEngineCreated();
  }

  void setWatermarkLocation(HereMapController hereMapController) {
    Anchor2D anchor = Anchor2D.withHorizontalAndVertical(0.0, 0.65);
    Point2D offset = Point2D(0.0, 0.0);
    hereMapController.setWatermarkLocation(anchor, offset);
  }

  void _handleBackButtonPress(BuildContext context) {
    print("back button pressed");
    setState(() {
      _isVenueListTapped = false;
      _clickedVenueName = '';
    });
    mapLoading.isMapLoading.value = false;

    setState(() {
      _topologyPressed = false;
    });
    _venueEngineState.venueEngine!.venueMap.selectedVenue!.isTopologyVisible =
        _topologyPressed;

    _venueEngineState.venueEngine?.venueMap
        .removeVenue(_venueEngineState.venueEngine!.venueMap.selectedVenue!);
    _venueEngineState.getLevelSwitcherState().onLevelsChanged(null);
    _venueEngineState.getDrawingSwitcherState().onDrawingsChanged(null);
    _venueEngineState.venueTapController?.deselectTopology();

    _buildSlidingPanel();

    Navigator.of(context).maybePop();
    setState(() {});

    if (_hereMapController != null) {
      _resetCameraPosition();
    }
  }
}
