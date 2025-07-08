/*
 * Copyright (C) 2019-2025 HERE Europe B.V.
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
import 'package:here_sdk/animation.dart';
import 'package:here_sdk/core.dart' as HERE;
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.engine.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/navigation.dart';
import 'package:here_sdk/routing.dart' as HERE;
import 'package:here_sdk/routing.dart';

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
  String accessKeySecret =
      "YOUR_ACCESS_KEY_SECRET";
  AuthenticationMode authenticationMode =
      AuthenticationMode.withKeySecret(accessKeyId, accessKeySecret);
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

class _MyAppState extends State<MyApp>
    implements HERE.LocationListener, AnimationListener {
  final GeoCoordinates _routeStartGeoCoordinates =
      GeoCoordinates(52.520798, 13.409408);
  final double _distanceInMeters = 1000;
  late final AppLifecycleListener _listener;

  HereMapController? _hereMapController;

  HERE.RoutingEngine? _routingEngine;
  VisualNavigator? _visualNavigator;
  LocationSimulator? _locationSimulator;

  LocationIndicator? _defaultLocationIndicator;
  LocationIndicator? _customLocationIndicator;
  Location? _lastKnownLocation;
  bool _isDefaultLocationIndicator = true;
  HERE.Route? myRoute;
  bool _isCustomHaloColor = false;
  Color _defaultHaloColor = Color(0);
  double _defaultHaloAccurarcyInMeters = 30.0;
  double _cameraTiltInDegrees = 40.0;
  double _cameraDistanceInMeters = 200.0;

  Future<bool> _handleBackPress() async {
    // Handle the back press.
    _visualNavigator?.stopRendering();
    _locationSimulator?.stop();

    // Return true to allow the back press.
    return true;
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
          {print('AppLifecycleListener detached.'), _disposeHERESDK()},
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
    return WillPopScope(
        onWillPop: _handleBackPress,
        child: Scaffold(
          appBar: AppBar(
            title: Text('Custom Navigation'),
          ),
          body: Stack(
            children: [
              HereMap(onMapCreated: _onMapCreated),
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      button('Start simulation', _startButtonClicked),
                      button('Stop simulation', _stopButtonClicked)
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      button(
                          'Toggle indicator style', _toggleStyleButtonClicked),
                      button('Toggle halo', _togglehaloColorButtonClicked)
                    ],
                  ),
                ],
              ),
            ],
          ),
        ));
  }

  void _onMapCreated(HereMapController hereMapController) {
    _hereMapController = hereMapController;
    _hereMapController!.mapScene.loadSceneForMapScheme(MapScheme.normalDay,
        (MapError? error) {
      if (error != null) {
        print('Map scene not loaded. MapError: ${error.toString()}');
        return;
      }

      print(
          "Start / stop simulated route guidance. Toggle between custom / default LocationIndicator.");

      try {
        _routingEngine = HERE.RoutingEngine();
      } on InstantiationException {
        throw Exception('Initialization of RoutingEngine failed.');
      }

      try {
        // Without a route set, this starts tracking mode.
        _visualNavigator = VisualNavigator();
      } on InstantiationException {
        throw Exception("Initialization of VisualNavigator failed.");
      }

      // Configure the map.
      MapMeasure mapMeasureZoom =
          MapMeasure(MapMeasureKind.distanceInMeters, _distanceInMeters);
      hereMapController.camera
          .lookAtPointWithMeasure(_routeStartGeoCoordinates, mapMeasureZoom);

      // Enable a few map layers that might be useful to see for drivers.
      hereMapController.mapScene.enableFeatures(
          {MapFeatures.trafficFlow: MapFeatureModes.trafficFlowWithFreeFlow});
      hereMapController.mapScene.enableFeatures(
          {MapFeatures.trafficIncidents: MapFeatureModes.defaultMode});
      hereMapController.mapScene.enableFeatures(
          {MapFeatures.safetyCameras: MapFeatureModes.defaultMode});
      hereMapController.mapScene.enableFeatures(
          {MapFeatures.vehicleRestrictions: MapFeatureModes.defaultMode});

      // Optionally, enable textured 3D landmarks.
      hereMapController.mapScene.enableFeatures(
          {MapFeatures.landmarks: MapFeatureModes.landmarksTextured});

      _defaultLocationIndicator = _createDefaultLocationIndicator();
      _customLocationIndicator = _createCustomLocationIndicator();

      // We start with the built-in default LocationIndicator.
      _isDefaultLocationIndicator = true;
      _switchToPedestrianLocationIndicator();
    });
  }

  LocationIndicator _createDefaultLocationIndicator() {
    LocationIndicator locationIndicator = LocationIndicator();
    locationIndicator.isAccuracyVisualized = true;
    locationIndicator.locationIndicatorStyle =
        LocationIndicatorIndicatorStyle.pedestrian;
    _defaultHaloColor = locationIndicator
        .getHaloColor(locationIndicator.locationIndicatorStyle);
    return locationIndicator;
  }

  LocationIndicator _createCustomLocationIndicator() {
    // Place the files in the "assets" directory as specified in pubspec.yaml.
    // Adjust file name and path as appropriate for your project.
    String pedGeometryFile = "assets/custom_location_indicator_pedestrian.obj";
    String pedTextureFile = "assets/custom_location_indicator_pedestrian.png";
    MapMarker3DModel pedestrianMapMarker3DModel =
        MapMarker3DModel.withTextureFilePath(pedGeometryFile, pedTextureFile);

    String navGeometryFile = "assets/custom_location_indicator_navigation.obj";
    String navTextureFile = "assets/custom_location_indicator_navigation.png";
    MapMarker3DModel navigationMapMarker3DModel =
        MapMarker3DModel.withTextureFilePath(navGeometryFile, navTextureFile);

    LocationIndicator locationIndicator = LocationIndicator();
    double scaleFactor = 3;

    // Note: For this example app, we use only simulated location data.
    // Therefore, we do not create a custom LocationIndicator for
    // .pedestrianInactive and .navigationInactive.
    // If set with a gray texture model, the type can be switched by calling locationIndicator.isActive = false
    // when the GPS accuracy is weak or no location was found.
    locationIndicator.setMarker3dModel(pedestrianMapMarker3DModel, scaleFactor,
        LocationIndicatorMarkerType.pedestrian);
    locationIndicator.setMarker3dModel(navigationMapMarker3DModel, scaleFactor,
        LocationIndicatorMarkerType.navigation);

    locationIndicator.isAccuracyVisualized = true;
    locationIndicator.locationIndicatorStyle =
        LocationIndicatorIndicatorStyle.pedestrian;

    return locationIndicator;
  }

  // Calculate a fixed route for testing and start guidance simulation along the route.
  void _startButtonClicked() {
    if (_visualNavigator!.isRendering) {
      return;
    }

    HERE.Waypoint startWaypoint =
        HERE.Waypoint(getLastKnownLocation().coordinates);
    HERE.Waypoint destinationWaypoint =
        HERE.Waypoint(HERE.GeoCoordinates(52.530905, 13.385007));

    _routingEngine!.calculateCarRoute(
        [startWaypoint, destinationWaypoint], HERE.CarOptions(),
        (HERE.RoutingError? routingError, List<HERE.Route>? routeList) async {
      if (routingError == null) {
        // When error is null, it is guaranteed that the routeList is not empty.
        myRoute = routeList!.first;
        _animateToRouteStart(myRoute!);
      } else {
        final error = routingError.toString();
        print('Error while calculating a route: $error');
      }
    });
  }

  // Stop guidance simulation and switch pedestrian LocationIndicator on.
  void _stopButtonClicked() {
    _stopGuidance();
  }

  // Toggle between the default LocationIndicator and custom LocationIndicator.
  // The default LocationIndicator uses a 3D asset that is part of the HERE SDK.
  // The custom LocationIndicator uses different 3D assets, see asset folder.
  void _toggleStyleButtonClicked() {
    // Toggle state.
    _isDefaultLocationIndicator = !_isDefaultLocationIndicator;

    // Select pedestrian or navigation assets.
    if (_visualNavigator!.isRendering) {
      _switchToNavigationLocationIndicator();
    } else {
      _switchToPedestrianLocationIndicator();
    }
  }

  // Toggle the halo color of the default LocationIndicator.
  void _togglehaloColorButtonClicked() {
    // Toggle state.
    _isCustomHaloColor = !_isCustomHaloColor;
    setSelectedHaloColor();
  }

  void setSelectedHaloColor() {
    if (_isCustomHaloColor) {
      Color customHaloColor =
          Color.fromRGBO(255, 255, 0, 0.30); // Yellow with 30% opacity
      _defaultLocationIndicator!.setHaloColor(
          _defaultLocationIndicator!.locationIndicatorStyle, customHaloColor);
      _customLocationIndicator!.setHaloColor(
          _customLocationIndicator!.locationIndicatorStyle, customHaloColor);
    } else {
      _defaultLocationIndicator!.setHaloColor(
          _defaultLocationIndicator!.locationIndicatorStyle, _defaultHaloColor);
      _customLocationIndicator!.setHaloColor(
          _customLocationIndicator!.locationIndicatorStyle, _defaultHaloColor);
    }
  }

  void _switchToPedestrianLocationIndicator() {
    if (_isDefaultLocationIndicator) {
      _defaultLocationIndicator!.enable(_hereMapController!);
      _defaultLocationIndicator!.locationIndicatorStyle =
          LocationIndicatorIndicatorStyle.pedestrian;
      _customLocationIndicator!.disable();
    } else {
      _defaultLocationIndicator!.disable();
      _customLocationIndicator!.enable(_hereMapController!);
      _customLocationIndicator!.locationIndicatorStyle =
          LocationIndicatorIndicatorStyle.pedestrian;
    }

    // Set last location from LocationSimulator.
    _defaultLocationIndicator!.updateLocation(getLastKnownLocation());
    _customLocationIndicator!.updateLocation(getLastKnownLocation());

    setSelectedHaloColor();
  }

  void _switchToNavigationLocationIndicator() {
    if (_isDefaultLocationIndicator) {
      // By default, the VisualNavigator adds a LocationIndicator on its own.
      // This can be kept by calling visualNavigator.customLocationIndicator = nil
      // However, here we want to be able to customize the halo for the default location indicator.
      // Therefore, we still need to set our own instance to the VisualNavigator.
      _customLocationIndicator!.disable();
      _defaultLocationIndicator!.enable(_hereMapController!);
      _defaultLocationIndicator!.locationIndicatorStyle =
          LocationIndicatorIndicatorStyle.navigation;
      _visualNavigator!.customLocationIndicator = _defaultLocationIndicator!;
    } else {
      _defaultLocationIndicator!.disable();
      _customLocationIndicator!.enable(_hereMapController!);
      _customLocationIndicator!.locationIndicatorStyle =
          LocationIndicatorIndicatorStyle.navigation;
      _visualNavigator!.customLocationIndicator = _customLocationIndicator;

      // Note that the type of the LocationIndicator is taken from the route's TransportMode.
      // It cannot be overriden during guidance.
      // During tracking mode (not shown in this app) you can specify the marker type via:
      // _visualNavigator!.trackingTransportMode = TransportMode.pedestrian;
    }

    // By default, during navigation the location of the indicator is controlled by the VisualNavigator.

    setSelectedHaloColor();
  }

  Location getLastKnownLocation() {
    if (_lastKnownLocation == null) {
      // A LocationIndicator is intended to mark the user's current location,
      // including a bearing direction.
      // For testing purposes, we create below a Location object. Usually, you want to get this from
      // a GPS sensor instead. Check the Positioning example app for this.
      Location location = Location.withCoordinates(_routeStartGeoCoordinates);
      location.time = DateTime.now();
      location.horizontalAccuracyInMeters = _defaultHaloAccurarcyInMeters;
      return location;
    }

    // This location is taken from the LocationSimulator that provides locations along the route.
    return _lastKnownLocation!;
  }

  // Implement AnimationListener.
  @override
  void onAnimationStateChanged(AnimationState state) {
    if (state == AnimationState.completed ||
        state == AnimationState.cancelled) {
      _startGuidance(myRoute!);
    }
  }

  // Animate to custom guidance perspective, centered on start location of route.
  void _animateToRouteStart(HERE.Route route) {
    // The first coordinate marks the start location of the route.
    var routeStart = route.geometry.vertices.first;
    var geoCoordinatesUpdate =
        GeoCoordinatesUpdate.fromGeoCoordinates(routeStart);

    double? bearingInDegrees = null;
    var orientationUpdate =
        GeoOrientationUpdate(bearingInDegrees, _cameraTiltInDegrees);
    var mapMeasure =
        MapMeasure(MapMeasureKind.distanceInMeters, _cameraDistanceInMeters);

    double bowFactor = 1;
    MapCameraAnimation animation =
        MapCameraAnimationFactory.flyToWithOrientationAndZoom(
            geoCoordinatesUpdate,
            orientationUpdate,
            mapMeasure,
            bowFactor,
            Duration(seconds: 3));
    _hereMapController!.camera.startAnimationWithListener(animation, this);
  }

  void _animateToDefaultMapPerspective() {
    var targetCoordinates = _hereMapController!.camera.state.targetCoordinates;
    var geoCoordinatesUpdate =
        GeoCoordinatesUpdate.fromGeoCoordinates(targetCoordinates);

    // By setting null we keep the current bearing rotation of the map.
    double? bearingInDegrees;
    double tiltInDegrees = 0;
    var orientationUpdate =
        GeoOrientationUpdate(bearingInDegrees, tiltInDegrees);

    var mapMeasure =
        MapMeasure(MapMeasureKind.distanceInMeters, _distanceInMeters);

    double bowFactor = 1;
    MapCameraAnimation animation =
        MapCameraAnimationFactory.flyToWithOrientationAndZoom(
            geoCoordinatesUpdate,
            orientationUpdate,
            mapMeasure,
            bowFactor,
            Duration(seconds: 3));
    _hereMapController!.camera.startAnimation(animation);
  }

  _startGuidance(HERE.Route route) {
    if (_visualNavigator!.isRendering) {
      return;
    }

    // Set the route and maneuver arrow color.
    _customizeVisualNavigatorColors();

    // Set custom guidance perspective.
    _customizeGuidanceView();

    // This enables a navigation view and adds a LocationIndicator.
    _visualNavigator!.startRendering(_hereMapController!);

    // Note: By default, when VisualNavigator starts rendering, a default LocationIndicator is added
    // by the HERE SDK automatically.
    _visualNavigator!.customLocationIndicator = _customLocationIndicator;
    _switchToNavigationLocationIndicator();

    // Set a route to follow. This leaves tracking mode.
    _visualNavigator!.route = route;

    // This app does not use real location updates. Instead it provides location updates based
    // on the geographic coordinates of a route using HERE SDK's LocationSimulator.
    _startRouteSimulation(route);
  }

  void _stopGuidance() {
    _visualNavigator?.stopRendering();

    _locationSimulator?.stop();

    // Note: By default, when VisualNavigator stops rendering, no LocationIndicator is visible.
    _switchToPedestrianLocationIndicator();

    _animateToDefaultMapPerspective();
  }

  void _customizeVisualNavigatorColors() {
    Color routeAheadColor = Colors.blue;
    Color routeBehindColor = Colors.red;
    Color routeAheadOutlineColor = Colors.yellow;
    Color routeBehindOutlineColor = Colors.grey;
    Color maneuverArrowColor = Colors.green;

    VisualNavigatorColors visualNavigatorColors =
        VisualNavigatorColors.dayColors();
    RouteProgressColors routeProgressColors = new RouteProgressColors(
        routeAheadColor,
        routeBehindColor,
        routeAheadOutlineColor,
        routeBehindOutlineColor);

    // Sets the color used to draw maneuver arrows.
    visualNavigatorColors.maneuverArrowColor = maneuverArrowColor;
    // Sets route color for a single transport mode. Other modes are kept using defaults.
    visualNavigatorColors.setRouteProgressColors(
        SectionTransportMode.car, routeProgressColors);
    // Sets the adjusted colors for route progress and maneuver arrows based on the day color scheme.
    _visualNavigator?.colors = visualNavigatorColors;
  }

  void _customizeGuidanceView() {
    FixedCameraBehavior cameraBehavior = FixedCameraBehavior();
    // Set custom zoom level and tilt.
    cameraBehavior.cameraDistanceInMeters =
        _cameraDistanceInMeters; // Defaults to 150.
    cameraBehavior.cameraTiltInDegrees =
        _cameraTiltInDegrees; // Defaults to 50.
    // Disable North-Up mode by setting null. Enable North-up mode by setting 0.
    // By default, North-Up mode is disabled.
    cameraBehavior.cameraBearingInDegrees = null;
    cameraBehavior.normalizedPrincipalPoint =
        Anchor2D.withHorizontalAndVertical(0.5, 0.5);

    // The CameraBehavior can be updated during guidance at any time as often as desired.
    _visualNavigator?.cameraBehavior = cameraBehavior;
  }

  // Implement LocationListener.
  @override
  void onLocationUpdated(Location location) {
    // By default, accuracy is nil during simulation, but we want to customize the halo,
    // so we hijack the location object and add an accuracy value.
    var updatedLocation = _addHorizontalAccuracy(location);
    // Feed location data into the VisualNavigator.
    _visualNavigator?.onLocationUpdated(updatedLocation);
    _lastKnownLocation = updatedLocation;
  }

  Location _addHorizontalAccuracy(Location simulatedLocation) {
    var location = Location.withCoordinates(simulatedLocation.coordinates);
    location.time = simulatedLocation.time;
    location.bearingInDegrees = simulatedLocation.bearingInDegrees;
    location.horizontalAccuracyInMeters = _defaultHaloAccurarcyInMeters;
    return location;
  }

  void _startRouteSimulation(HERE.Route route) {
    // Make sure to stop an existing LocationSimulator before starting a new one.
    _locationSimulator?.stop();

    try {
      // Provides fake GPS signals based on the route geometry.
      _locationSimulator =
          LocationSimulator.withRoute(route, LocationSimulatorOptions());
    } on InstantiationException {
      throw Exception("Initialization of LocationSimulator failed.");
    }

    _locationSimulator!.listener = this;
    _locationSimulator!.start();
  }

  // A helper method to add a button on top of the HERE map.
  Align button(String buttonLabel, Function callbackFunction) {
    return Align(
      alignment: Alignment.topCenter,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.lightBlueAccent,
          foregroundColor: Colors.white,
        ),
        onPressed: () => callbackFunction(),
        child: Text(buttonLabel, style: TextStyle(fontSize: 20)),
      ),
    );
  }
}
