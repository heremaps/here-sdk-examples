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

class _MyAppState extends State<MyApp> implements HERE.LocationListener, AnimationListener {
  final GeoCoordinates _routeStartGeoCoordinates = GeoCoordinates(52.520798, 13.409408);
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
  bool _isCurrentColorBlue = false;

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
    return WillPopScope(
        onWillPop: _handleBackPress,
        child: Scaffold(
          appBar: AppBar(
            title: Text('Custom Navigation'),
          ),
          body: Stack(
            children: [
              HereMap(onMapCreated: _onMapCreated),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  button('Start', _startButtonClicked),
                  button('Stop', _stopButtonClicked),
                  button('Toggle', _toggleButtonClicked),
                  button('Color', _colorButtonClicked)
                ],
              ),
            ],
          ),
        ));
  }

  void _onMapCreated(HereMapController hereMapController) {
    _hereMapController = hereMapController;
    _hereMapController!.mapScene.loadSceneForMapScheme(MapScheme.normalDay, (MapError? error) {
      if (error != null) {
        print('Map scene not loaded. MapError: ${error.toString()}');
        return;
      }

      // Optionally, enable textured 3D landmarks.
      hereMapController.mapScene.enableFeatures({MapFeatures.landmarks: MapFeatureModes.landmarksTextured});

      MapMeasure mapMeasureZoom = MapMeasure(MapMeasureKind.distanceInMeters, _distanceInMeters);
      _hereMapController!.camera.lookAtPointWithMeasure(_routeStartGeoCoordinates, mapMeasureZoom);
      _startAppLogic();
    });
  }

  _startAppLogic() {
    print("Start / stop simulated route guidance. Toggle between custom / default LocationIndicator.");

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

    // Enable a few map layers that might be useful to see for drivers.
    _hereMapController!.mapScene.enableFeatures({MapFeatures.trafficFlow: MapFeatureModes.trafficFlowWithFreeFlow});
    _hereMapController!.mapScene.enableFeatures({MapFeatures.trafficIncidents: MapFeatureModes.defaultMode});
    _hereMapController!.mapScene.enableFeatures({MapFeatures.safetyCameras: MapFeatureModes.defaultMode});
    _hereMapController!.mapScene.enableFeatures({MapFeatures.vehicleRestrictions: MapFeatureModes.defaultMode});

    _defaultLocationIndicator = LocationIndicator();
    _customLocationIndicator = _createCustomLocationIndicator();

    // Show indicator on map. We start with the built-in default LocationIndicator.
    _isDefaultLocationIndicator = true;
    _switchToPedestrianLocationIndicator();
  }

  LocationIndicator _createCustomLocationIndicator() {
    // Place the files in the "assets" directory as specified in pubspec.yaml.
    // Adjust file name and path as appropriate for your project.
    String pedGeometryFile = "assets/custom_location_indicator_pedestrian.obj";
    String pedTextureFile = "assets/custom_location_indicator_pedestrian.png";
    MapMarker3DModel pedestrianMapMarker3DModel = MapMarker3DModel.withTextureFilePath(pedGeometryFile, pedTextureFile);

    String navGeometryFile = "assets/custom_location_indicator_navigation.obj";
    String navTextureFile = "assets/custom_location_indicator_navigation.png";
    MapMarker3DModel navigationMapMarker3DModel = MapMarker3DModel.withTextureFilePath(navGeometryFile, navTextureFile);

    LocationIndicator locationIndicator = LocationIndicator();
    double scaleFactor = 3;

    // Note: For this example app, we use only simulated location data.
    // Therefore, we do not create a custom LocationIndicator for
    // .pedestrianInactive and .navigationInactive.
    // If set with a gray texture model, the type can be switched by calling locationIndicator.isActive = false
    // when the GPS accuracy is weak or no location was found.
    locationIndicator.setMarker3dModel(pedestrianMapMarker3DModel, scaleFactor, LocationIndicatorMarkerType.pedestrian);
    locationIndicator.setMarker3dModel(navigationMapMarker3DModel, scaleFactor, LocationIndicatorMarkerType.navigation);

    locationIndicator.isAccuracyVisualized = true;
    
    return locationIndicator;
  }

  // Calculate a fixed route for testing and start guidance simulation along the route.
  void _startButtonClicked() {
    if (_visualNavigator!.isRendering) {
      return;
    }

    HERE.Waypoint startWaypoint = HERE.Waypoint(_routeStartGeoCoordinates);
    HERE.Waypoint destinationWaypoint = HERE.Waypoint(HERE.GeoCoordinates(52.530905, 13.385007));

    _routingEngine!.calculateCarRoute([startWaypoint, destinationWaypoint], HERE.CarOptions(),
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
  void _toggleButtonClicked() {
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
  void _colorButtonClicked() {
    if (_isCurrentColorBlue) {
      _defaultLocationIndicator?.setHaloColor(
          _defaultLocationIndicator!.locationIndicatorStyle,
          Color.fromRGBO(255, 255, 0, 0.30)); // Yellow with 30% opacity

      _customLocationIndicator?.setHaloColor(
          _customLocationIndicator!.locationIndicatorStyle,
          Color.fromRGBO(255, 255, 0, 0.30));

      _isCurrentColorBlue = false;
    } else {
      _defaultLocationIndicator?.setHaloColor(
          _defaultLocationIndicator!.locationIndicatorStyle,
          Color.fromRGBO(0, 0, 255, 0.30)); // Blue with 30% opacity

      _customLocationIndicator?.setHaloColor(
          _customLocationIndicator!.locationIndicatorStyle,
          Color.fromRGBO(0, 0, 255, 0.30));

      _isCurrentColorBlue = true;
    }
  }


  void _switchToPedestrianLocationIndicator() {
    if (_isDefaultLocationIndicator) {
      _defaultLocationIndicator!.enable(_hereMapController!);
      _defaultLocationIndicator!.locationIndicatorStyle = LocationIndicatorIndicatorStyle.pedestrian;
      _customLocationIndicator!.disable();
    } else {
      _defaultLocationIndicator!.disable();
      _customLocationIndicator!.enable(_hereMapController!);
      _customLocationIndicator!.locationIndicatorStyle = LocationIndicatorIndicatorStyle.pedestrian;
    }

    // Set last location from LocationSimulator.
    _defaultLocationIndicator!.updateLocation(getLastKnownLocation());
    _customLocationIndicator!.updateLocation(getLastKnownLocation());
  }

  void _switchToNavigationLocationIndicator() {
    if (_isDefaultLocationIndicator) {
      // By default, the VisualNavigator adds a LocationIndicator on its own.
      _defaultLocationIndicator!.disable();
      _customLocationIndicator!.disable();
      _visualNavigator!.customLocationIndicator = null;
    } else {
      _defaultLocationIndicator!.disable();
      _customLocationIndicator!.enable(_hereMapController!);
      _customLocationIndicator!.locationIndicatorStyle = LocationIndicatorIndicatorStyle.navigation;
      _visualNavigator!.customLocationIndicator = _customLocationIndicator;

      // Note that the type of the LocationIndicator is taken from the route's TransportMode.
      // It cannot be overriden during guidance.
      // During tracking mode (not shown in this app) you can specify the marker type via:
      // _visualNavigator!.trackingTransportMode = TransportMode.pedestrian;
    }

    // Location is set by VisualNavigator for smooth interpolation.
  }

  Location getLastKnownLocation() {
    if (_lastKnownLocation == null) {
      // A LocationIndicator is intended to mark the user's current location,
      // including a bearing direction.
      // For testing purposes, we create below a Location object. Usually, you want to get this from
      // a GPS sensor instead. Check the Positioning example app for this.
      Location location = Location.withCoordinates(_routeStartGeoCoordinates);
      location.time = DateTime.now();
      location.horizontalAccuracyInMeters = 30.0;
      return location;

    }

    // This location is taken from the LocationSimulator that provides locations along the route.
    return _lastKnownLocation!;
  }

  // Implement AnimationListener.
  @override
  void onAnimationStateChanged(AnimationState state) {
    if (state == AnimationState.completed || state == AnimationState.cancelled) {
      _startGuidance(myRoute!);
    }
  }

  // Animate to custom guidance perspective, centered on start location of route.
  void _animateToRouteStart(HERE.Route route) {
    // The first coordinate marks the start location of the route.
    var routeStart = route.geometry.vertices.first;
    var geoCoordinatesUpdate = GeoCoordinatesUpdate.fromGeoCoordinates(routeStart);

    double? bearingInDegrees;
    double tiltInDegrees = 70;
    var orientationUpdate = GeoOrientationUpdate(bearingInDegrees, tiltInDegrees);

    double distanceToEarthInMeters = 50;
    var mapMeasure = MapMeasure(MapMeasureKind.distanceInMeters, distanceToEarthInMeters);

    double bowFactor = 1;
    MapCameraAnimation animation = MapCameraAnimationFactory.flyToWithOrientationAndZoom(
        geoCoordinatesUpdate, orientationUpdate, mapMeasure, bowFactor, Duration(seconds: 3));
    _hereMapController!.camera.startAnimationWithListener(animation, this);
  }

  void _animateToDefaultMapPerspective() {
    var targetCoordinates = _hereMapController!.camera.state.targetCoordinates;
    var geoCoordinatesUpdate = GeoCoordinatesUpdate.fromGeoCoordinates(targetCoordinates);

    // By setting null we keep the current bearing rotation of the map.
    double? bearingInDegrees;
    double tiltInDegrees = 0;
    var orientationUpdate = GeoOrientationUpdate(bearingInDegrees, tiltInDegrees);

    var mapMeasure = MapMeasure(MapMeasureKind.distanceInMeters, _distanceInMeters);

    double bowFactor = 1;
    MapCameraAnimation animation = MapCameraAnimationFactory.flyToWithOrientationAndZoom(
        geoCoordinatesUpdate, orientationUpdate, mapMeasure, bowFactor, Duration(seconds: 3));
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

    VisualNavigatorColors visualNavigatorColors = VisualNavigatorColors.dayColors();
    RouteProgressColors routeProgressColors =
        new RouteProgressColors(routeAheadColor, routeBehindColor, routeAheadOutlineColor, routeBehindOutlineColor);

    // Sets the color used to draw maneuver arrows.
    visualNavigatorColors.maneuverArrowColor = maneuverArrowColor;
    // Sets route color for a single transport mode. Other modes are kept using defaults.
    visualNavigatorColors.setRouteProgressColors(SectionTransportMode.car, routeProgressColors);
    // Sets the adjusted colors for route progress and maneuver arrows based on the day color scheme.
    _visualNavigator?.colors = visualNavigatorColors;
  }

  void _customizeGuidanceView() {
    FixedCameraBehavior cameraBehavior = FixedCameraBehavior();
    // Set custom zoom level and tilt.
    cameraBehavior.cameraDistanceInMeters = 50; // Defaults to 150.
    cameraBehavior.cameraTiltInDegrees = 70; // Defaults to 50.
    // Disable North-Up mode by setting null. Enable North-up mode by setting 0.
    // By default, North-Up mode is disabled.
    cameraBehavior.cameraBearingInDegrees = null;

    // The CameraBehavior can be updated during guidance at any time as often as desired.
    _visualNavigator?.cameraBehavior = cameraBehavior;
  }

  // Implement HERE.LocationListener.
  @override
  void onLocationUpdated(HERE.Location location) {
    // Feed location data into the VisualNavigator.
    _visualNavigator?.onLocationUpdated(location);
    _lastKnownLocation = location;
  }

  void _startRouteSimulation(HERE.Route route) {
    // Make sure to stop an existing LocationSimulator before starting a new one.
    _locationSimulator?.stop();

    try {
      // Provides fake GPS signals based on the route geometry.
      _locationSimulator = LocationSimulator.withRoute(route, LocationSimulatorOptions());
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
