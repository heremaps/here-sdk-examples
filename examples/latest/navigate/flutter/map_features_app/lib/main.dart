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

import 'package:flutter/material.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.engine.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/mapview.dart';
import 'package:map_features_app/MenuSectionExpansionTile.dart';

import 'MapFeaturesExample.dart';
import 'MapSchemesExample.dart';

void main() async {
  // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
  await _initializeHERESDK();

  // Ensure that all widgets, including MyApp, have a MaterialLocalizations object available.
  runApp(MaterialApp(home: MyApp()));
}

Future<void> _initializeHERESDK() async {
  // Needs to be called before accessing SDKOptions to load necessary libraries.
  SdkContext.init(IsolateOrigin.main);

  // Set your credentials for the HERE SDK.
  String accessKeyId = "YOUR_ACCESS_KEY_ID";
  String accessKeySecret = "YOUR_ACCESS_KEY_SECRET";
  AuthenticationMode authenticationMode = AuthenticationMode.withKeySecret(accessKeyId, accessKeySecret);
  SDKOptions sdkOptions = SDKOptions.withAuthenticationMode(authenticationMode);

  try {
    await SDKNativeEngine.makeSharedInstance(sdkOptions);
  } on InstantiationException {
    throw Exception("Failed to initialize the HERE SDK.");
  }
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  MapFeaturesExample? _mapFeaturesExample;
  MapSchemesExample? _mapSchemesExample;
  late final AppLifecycleListener _appLifecycleListener;
  bool isWebMercatorProjection = false;
  late HereMap mapViewWebMercator;
  late HereMap mapViewGlobe;
  HereMapOptions hereMapOptions = HereMapOptions();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('HERE SDK - Map Features Example')),
      drawer: Drawer(child: ListView(children: _buildDrawerList(context))),
      body: Stack(
        children: [
          Visibility(visible: isWebMercatorProjection, child: mapViewWebMercator),
          Visibility(visible: !isWebMercatorProjection, child: mapViewGlobe),
          button(isWebMercatorProjection ? "Switch to Globe" : "Switch to Web Mercator", changeMapProjection),
        ],
      ),
    );
  }

  void changeMapProjection() {
    setState(() {
      isWebMercatorProjection = !isWebMercatorProjection;
    });
  }

  void _onMapCreated(HereMapController hereMapController) {
    hereMapController.mapScene.loadSceneForMapScheme(_mapSchemesExample?.getCurrentMapScheme() ?? MapScheme.normalDay, (
      MapError? error,
    ) {
      if (error == null) {
        _mapFeaturesExample = MapFeaturesExample(hereMapController, _mapFeaturesExample?.getEnabledFeatures());
        _mapFeaturesExample?.applyEnabledFeaturesForMapScene(_mapFeaturesExample?.getEnabledFeatures());
        _mapSchemesExample = MapSchemesExample(hereMapController, _mapSchemesExample?.getCurrentMapScheme());
        _mapSchemesExample?.loadCurrentMapScheme();
      } else {
        print("Map scene not loaded. MapError: " + error.toString());
      }
    });
  }

  // Map Schemes
  void _loadSceneLiteNightScheme() {
    _mapSchemesExample?.loadSceneForMapScheme(MapScheme.liteNight);
    _mapFeaturesExample?.applyEnabledFeaturesForMapScene(_mapFeaturesExample?.getEnabledFeatures());
  }

  void _loadSceneHybridDayScheme() {
    _mapSchemesExample?.loadSceneForMapScheme(MapScheme.hybridDay);
    _mapFeaturesExample?.applyEnabledFeaturesForMapScene(_mapFeaturesExample?.getEnabledFeatures());
  }

  void _loadSceneHybridNightScheme() {
    _mapSchemesExample?.loadSceneForMapScheme(MapScheme.hybridNight);
    _mapFeaturesExample?.applyEnabledFeaturesForMapScene(_mapFeaturesExample?.getEnabledFeatures());
  }

  void _loadSceneLiteDayScheme() {
    _mapSchemesExample?.loadSceneForMapScheme(MapScheme.liteDay);
    _mapFeaturesExample?.applyEnabledFeaturesForMapScene(_mapFeaturesExample?.getEnabledFeatures());
  }

  void _loadSceneLiteHybridDayScheme() {
    _mapSchemesExample?.loadSceneForMapScheme(MapScheme.liteHybridDay);
    _mapFeaturesExample?.applyEnabledFeaturesForMapScene(_mapFeaturesExample?.getEnabledFeatures());
  }

  void _loadSceneLiteHybridNightScheme() {
    _mapSchemesExample?.loadSceneForMapScheme(MapScheme.liteHybridNight);
    _mapFeaturesExample?.applyEnabledFeaturesForMapScene(_mapFeaturesExample?.getEnabledFeatures());
  }

  void _loadSceneLogisticsDayScheme() {
    _mapSchemesExample?.loadSceneForMapScheme(MapScheme.logisticsDay);
    _mapFeaturesExample?.applyEnabledFeaturesForMapScene(_mapFeaturesExample?.getEnabledFeatures());
  }

  void _loadSceneLogisticsHybridDayScheme() {
    _mapSchemesExample?.loadSceneForMapScheme(MapScheme.logisticsHybridDay);
    _mapFeaturesExample?.applyEnabledFeaturesForMapScene(_mapFeaturesExample?.getEnabledFeatures());
  }

  void _loadSceneLogisticsNightScheme() {
    _mapSchemesExample?.loadSceneForMapScheme(MapScheme.logisticsNight);
    _mapFeaturesExample?.applyEnabledFeaturesForMapScene(_mapFeaturesExample?.getEnabledFeatures());
  }

  void _loadSceneLogisticsHybridNightScheme() {
    _mapSchemesExample?.loadSceneForMapScheme(MapScheme.liteHybridNight);
    _mapFeaturesExample?.applyEnabledFeaturesForMapScene(_mapFeaturesExample?.getEnabledFeatures());
  }

  void _loadSceneNormalDayScheme() {
    _mapSchemesExample?.loadSceneForMapScheme(MapScheme.normalDay);
    _mapFeaturesExample?.applyEnabledFeaturesForMapScene(_mapFeaturesExample?.getEnabledFeatures());
  }

  void _loadSceneNormalNightScheme() {
    _mapSchemesExample?.loadSceneForMapScheme(MapScheme.normalNight);
    _mapFeaturesExample?.applyEnabledFeaturesForMapScene(_mapFeaturesExample?.getEnabledFeatures());
  }

  void _loadSceneRoadNetworkDayScheme() {
    _mapSchemesExample?.loadSceneForMapScheme(MapScheme.roadNetworkDay);
    _mapFeaturesExample?.applyEnabledFeaturesForMapScene(_mapFeaturesExample?.getEnabledFeatures());
  }

  void _loadSceneRoadNetworkNightScheme() {
    _mapSchemesExample?.loadSceneForMapScheme(MapScheme.roadNetworkNight);
    _mapFeaturesExample?.applyEnabledFeaturesForMapScene(_mapFeaturesExample?.getEnabledFeatures());
  }

  void _loadSceneSatelliteScheme() {
    _mapSchemesExample?.loadSceneForMapScheme(MapScheme.satellite);
    _mapFeaturesExample?.applyEnabledFeaturesForMapScene(_mapFeaturesExample?.getEnabledFeatures());
  }

  void _loadSceneTopoDayScheme() {
    _mapSchemesExample?.loadSceneForMapScheme(MapScheme.topoDay);
    _mapFeaturesExample?.applyEnabledFeaturesForMapScene(_mapFeaturesExample?.getEnabledFeatures());
  }

  void _loadSceneTopoNightScheme() {
    _mapSchemesExample?.loadSceneForMapScheme(MapScheme.topoNight);
    _mapFeaturesExample?.applyEnabledFeaturesForMapScene(_mapFeaturesExample?.getEnabledFeatures());
  }

  // Map Features
  void _clearMapFeaturesButtonClicked() {
    _mapFeaturesExample?.disableFeatures();
  }

  void _buildingFootprintsButtonClicked() {
    _mapFeaturesExample?.enableBuildingFootprints();
  }

  void _congestionZoneButtonClicked() {
    _mapFeaturesExample?.enableCongestionZones();
  }

  void _environmentalZonesButtonClicked() {
    _mapFeaturesExample?.enableEnvironmentalZones();
  }

  void _extrudedBuildingsButtonClicked() {
    _mapFeaturesExample?.enableBuildingFootprints();
  }

  void _landmarksTexturedButtonClicked() {
    _mapFeaturesExample?.enableLandmarksTextured();
  }

  void _landmarksTexturelessButtonClicked() {
    _mapFeaturesExample?.enableLandmarksTextureless();
  }

  void _safetyCamerasButtonClicked() {
    _mapFeaturesExample?.enableSafetyCameras();
  }

  void _shadowsButtonClicked() {
    _showDialog("Building Shadows", "Enabled building shadows for non-satellite-based schemes.");
    _mapFeaturesExample?.enableShadows();
  }

  void _terrainHillshadeButtonClicked() {
    _mapFeaturesExample?.enableTerrainHillShade();
  }

  void _terrain3DButtonClicked() {
    _mapFeaturesExample?.enableTerrain3D();
  }

  void _ambientOcclusionButtonClicked() {
    _mapFeaturesExample?.enableAmbientOcclusion();
  }

  void _contoursButtonClicked() {
    _mapFeaturesExample?.enableContours();
  }

  void _lowSpeedZonesButtonClicked() {
    _mapFeaturesExample?.enableLowSpeedZones();
  }

  void _trafficFlowWithFreeFlowButtonClicked() {
    _mapFeaturesExample?.enableTrafficFlowWithFreeFlow();
  }

  void _trafficFlowWithoutFreeFlowButtonClicked() {
    _mapFeaturesExample?.enableTrafficFlowWithoutFreeFlow();
  }

  void _trafficIncidentsButtonClicked() {
    _mapFeaturesExample?.enableTrafficIncidents();
  }

  void _vehicleRestrictionsActiveButtonClicked() {
    _mapFeaturesExample?.enableVehicleRestrictionsActive();
  }

  void _vehicleRestrictionsActiveInactiveButtonClicked() {
    _mapFeaturesExample?.enableVehicleRestrictionsActiveAndInactive();
  }

  void _vehicleRestrictionsActiveInactiveDiffButtonClicked() {
    _mapFeaturesExample?.enableVehicleRestrictionsActiveAndInactiveDiff();
  }

  void _roadExitLabelsButtonClicked() {
    _mapFeaturesExample?.enableRoadExitLabels();
  }

  void _roadExitLabelsNumbersOnlyButtonClicked() {
    _mapFeaturesExample?.enableRoadExitLabelsNumbersOnly();
  }

  // A helper method to build a drawer list.
  List<Widget> _buildDrawerList(BuildContext context) {
    List<Widget> children = [];

    DrawerHeader header = DrawerHeader(
      child: Column(
        children: [Text('HERE SDK - Map Features Example', style: TextStyle(fontSize: 24, color: Colors.white))],
      ),
      decoration: BoxDecoration(color: Colors.blue),
    );
    children.add(header);

    // Add MapMarker section.
    var mapMarkerTile = _buildMapSchemeExpansionTile(context);
    children.add(mapMarkerTile);

    // Add LocationIndicator section.
    var locationIndicatorTile = _buildMapFeaturesExpansionTile(context);
    children.add(locationIndicatorTile);

    return children;
  }

  // Build the menu entries for the MapMarker section.
  Widget _buildMapSchemeExpansionTile(BuildContext context) {
    final List<MenuSectionItem> menuItems = [
      MenuSectionItem("Lite Night", _loadSceneLiteNightScheme),
      MenuSectionItem("Hybrid Day", _loadSceneHybridDayScheme),
      MenuSectionItem("Hybrid Night", _loadSceneHybridNightScheme),
      MenuSectionItem("Lite Day", _loadSceneLiteDayScheme),
      MenuSectionItem("Lite Hybrid Day", _loadSceneLiteHybridDayScheme),
      MenuSectionItem("Lite Hybrid Night", _loadSceneLiteHybridNightScheme),
      MenuSectionItem("Logistics Day", _loadSceneLogisticsDayScheme),
      MenuSectionItem("Logistics Hybrid Day", _loadSceneLogisticsHybridDayScheme),
      MenuSectionItem("Logistics Night", _loadSceneLogisticsNightScheme),
      MenuSectionItem("Logistics Hybrid Night", _loadSceneLogisticsHybridNightScheme),
      MenuSectionItem("Normal Day", _loadSceneNormalDayScheme),
      MenuSectionItem("Normal Night", _loadSceneNormalNightScheme),
      MenuSectionItem("Road Network Day", _loadSceneRoadNetworkDayScheme),
      MenuSectionItem("Road Network Night", _loadSceneRoadNetworkNightScheme),
      MenuSectionItem("Satellite", _loadSceneSatelliteScheme),
      MenuSectionItem("Topo Day", _loadSceneTopoDayScheme),
      MenuSectionItem("Topo Night", _loadSceneTopoNightScheme),
    ];

    return MenuSectionExpansionTile("Map Schemes", menuItems);
  }

  // Build the menu entries for the LocationIndicator section.
  Widget _buildMapFeaturesExpansionTile(BuildContext context) {
    final List<MenuSectionItem> menuItems = [
      MenuSectionItem("Clear Map Features", _clearMapFeaturesButtonClicked),
      MenuSectionItem("Ambient Occlusion", _ambientOcclusionButtonClicked),
      MenuSectionItem("Building Footprints", _buildingFootprintsButtonClicked),
      MenuSectionItem("Congestion Zone", _congestionZoneButtonClicked),
      MenuSectionItem("Environmental Zones", _environmentalZonesButtonClicked),
      MenuSectionItem("Extruded Buildings", _extrudedBuildingsButtonClicked),
      MenuSectionItem("Landmarks Textured", _landmarksTexturedButtonClicked),
      MenuSectionItem("Landmarks Textureless", _landmarksTexturelessButtonClicked),
      MenuSectionItem("Safety Cameras", _safetyCamerasButtonClicked),
      MenuSectionItem("Shadows", _shadowsButtonClicked),
      MenuSectionItem("Terrain Hillshade", _terrainHillshadeButtonClicked),
      MenuSectionItem("Terrain 3D", _terrain3DButtonClicked),
      MenuSectionItem("Contours", _contoursButtonClicked),
      MenuSectionItem("Low Speed Zones", _lowSpeedZonesButtonClicked),
      MenuSectionItem("Traffic Flow with Free Flow", _trafficFlowWithFreeFlowButtonClicked),
      MenuSectionItem("Traffic Flow without Free Flow", _trafficFlowWithoutFreeFlowButtonClicked),
      MenuSectionItem("Traffic Incidents", _trafficIncidentsButtonClicked),
      MenuSectionItem("Vehicle Restrictions Active", _vehicleRestrictionsActiveButtonClicked),
      MenuSectionItem("Vehicle Restrictions Active/Inactive", _vehicleRestrictionsActiveInactiveButtonClicked),
      MenuSectionItem("Vehicle Restrictions Active/Inactive Diff", _vehicleRestrictionsActiveInactiveDiffButtonClicked),
      MenuSectionItem("Road Exit Labels", _roadExitLabelsButtonClicked),
      MenuSectionItem("Road Exit Labels Numbers Only", _roadExitLabelsNumbersOnlyButtonClicked),
    ];

    return MenuSectionExpansionTile("Map Features", menuItems);
  }

  @override
  void initState() {
    super.initState();
    _appLifecycleListener = AppLifecycleListener(
      onDetach: () =>
          // Sometimes Flutter may not reliably call dispose(),
          // therefore it is recommended to dispose the HERE SDK
          // also when the AppLifecycleListener is detached.
          // See more details: https://github.com/flutter/flutter/issues/40940
          {print('AppLifecycleListener detached.'), _disposeHERESDK()},
    );

    // Setting map projection to webMercator.
    hereMapOptions.projection = MapProjection.webMercator;

    mapViewWebMercator = HereMap(onMapCreated: _onMapCreated, options: hereMapOptions);
    mapViewGlobe = HereMap(onMapCreated: _onMapCreated);
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
    _appLifecycleListener.dispose();
  }

  // A helper method to add a button on top of the HERE map.
  Align button(String buttonLabel, Function callbackFunction) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.lightBlueAccent),
          onPressed: () => callbackFunction(),
          child: Text(buttonLabel, style: TextStyle(fontSize: 20)),
        ),
      ),
    );
  }

  // A helper method to show a dialog.
  Future<void> _showDialog(String title, String message) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: ListBody(children: <Widget>[Text(message)])),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
