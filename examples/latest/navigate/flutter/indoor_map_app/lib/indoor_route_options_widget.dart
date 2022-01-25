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
import 'package:here_sdk/routing.dart';

// Provides UI for indoor route options.
class IndoorRouteOptionsWidget extends StatefulWidget {
  final IndoorRouteOptionsState state;

  IndoorRouteOptionsWidget({required this.state});

  @override
  IndoorRouteOptionsState createState() => state;
}

class IndoorRouteOptionsState extends State<IndoorRouteOptionsWidget> {
  bool _isEnabled = false;
  IndoorRouteOptions _options = IndoorRouteOptions.withDefaults();
  Map<IndoorFeatures, bool> _avoidFeatures = {
    IndoorFeatures.elevator: false,
    IndoorFeatures.escalator: false,
    IndoorFeatures.stairs: false,
    IndoorFeatures.movingWalkway: false,
    IndoorFeatures.ramp: false,
    IndoorFeatures.transition: false
  };

  bool get isEnabled => _isEnabled;

  set isEnabled(bool value) {
    setState(() {
      _isEnabled = value;
    });
  }

  IndoorRouteOptions get options => _options;

  set options(IndoorRouteOptions value) {
    setState(() {
      _options = value;
    });
  }

  // Adds or removes avoidance features for indoor route calculation.
  _setAvoidIndoorFeature(IndoorFeatures feature, bool avoid) {
    _avoidFeatures[feature] = avoid;
    if (avoid) {
      _options.indoorAvoidanceOptions.indoorFeatures.add(feature);
    } else {
      _options.indoorAvoidanceOptions.indoorFeatures.remove(feature);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isEnabled) {
      return SizedBox.shrink();
    }

    return Container(
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.only(top: 10, left: 5, bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                child: Text(
                  "Route mode:",
                  textAlign: TextAlign.start,
                ),
              ),
              Container(
                child: Row(children: [
                  Radio(
                    value: OptimizationMode.fastest,
                    groupValue: _options.routeOptions.optimizationMode,
                    onChanged: (OptimizationMode? value) {
                      setState(() {
                        _options.routeOptions.optimizationMode = value!;
                      });
                    },
                  ),
                  Text('Fast'),
                ]),
              ),
              Container(
                child: Row(children: [
                  Radio(
                    value: OptimizationMode.shortest,
                    groupValue: _options.routeOptions.optimizationMode,
                    onChanged: (OptimizationMode? value) {
                      setState(() {
                        _options.routeOptions.optimizationMode = value!;
                      });
                    },
                  ),
                  Text('Short'),
                ]),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                child: Text(
                  "Transport mode:",
                  textAlign: TextAlign.start,
                ),
              ),
              Container(
                child: Row(children: [
                  Radio(
                    value: IndoorTransportMode.pedestrian,
                    groupValue: _options.transportMode,
                    onChanged: (IndoorTransportMode? value) {
                      setState(() {
                        _options.transportMode = value!;
                      });
                    },
                  ),
                  Text('Pedestrian'),
                ]),
              ),
              Container(
                child: Row(children: [
                  Radio(
                    value: IndoorTransportMode.car,
                    groupValue: _options.transportMode,
                    onChanged: (IndoorTransportMode? value) {
                      setState(() {
                        _options.transportMode = value!;
                      });
                    },
                  ),
                  Text('Car'),
                ]),
              ),
            ],
          ),
          Container(alignment: Alignment.centerLeft, padding: EdgeInsets.only(top: 10), child: Text("Avoid features:")),
          Row(
            children: [
              Container(
                width: 170,
                alignment: Alignment.centerLeft,
                child: CheckboxListTile(
                  title: Text("Elevator"),
                  value: _avoidFeatures[IndoorFeatures.elevator],
                  onChanged: (newValue) {
                    setState(() {
                      _setAvoidIndoorFeature(IndoorFeatures.elevator, newValue!);
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              Container(
                width: 170,
                alignment: Alignment.centerRight,
                child: CheckboxListTile(
                  title: Text("Moving walkway"),
                  value: _avoidFeatures[IndoorFeatures.movingWalkway],
                  onChanged: (newValue) {
                    setState(() {
                      _setAvoidIndoorFeature(IndoorFeatures.movingWalkway, newValue!);
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              )
            ],
          ),
          Row(
            children: [
              Container(
                width: 170,
                alignment: Alignment.centerLeft,
                child: CheckboxListTile(
                  title: Text("Escalator"),
                  value: _avoidFeatures[IndoorFeatures.escalator],
                  onChanged: (newValue) {
                    setState(() {
                      _setAvoidIndoorFeature(IndoorFeatures.escalator, newValue!);
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              Container(
                width: 170,
                alignment: Alignment.centerRight,
                child: CheckboxListTile(
                  title: Text("Ramp"),
                  value: _avoidFeatures[IndoorFeatures.ramp],
                  onChanged: (newValue) {
                    setState(() {
                      _setAvoidIndoorFeature(IndoorFeatures.ramp, newValue!);
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              )
            ],
          ),
          Row(
            children: [
              Container(
                width: 170,
                alignment: Alignment.centerLeft,
                child: CheckboxListTile(
                  title: Text("Stairs"),
                  value: _avoidFeatures[IndoorFeatures.stairs],
                  onChanged: (newValue) {
                    setState(() {
                      _setAvoidIndoorFeature(IndoorFeatures.stairs, newValue!);
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              Container(
                width: 170,
                alignment: Alignment.centerRight,
                child: CheckboxListTile(
                  title: Text("Transition"),
                  value: _avoidFeatures[IndoorFeatures.transition],
                  onChanged: (newValue) {
                    setState(() {
                      _setAvoidIndoorFeature(IndoorFeatures.transition, newValue!);
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              )
            ],
          ),
        ],
      ),
    );
  }
}
