/*
 * Copyright (C) 2020 HERE Europe B.V.
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

// Disabled null safety for this file:
// @dart=2.9
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:here_sdk/venue.data.dart';

class GeometryInfo extends StatefulWidget {
  final GeometryInfoState state;

  GeometryInfo({@required this.state});

  @override
  GeometryInfoState createState() => state;
}

class GeometryInfoState extends State<GeometryInfo> {
  VenueGeometry _geometry;

  VenueGeometry get geometry => _geometry;

  set geometry(VenueGeometry geometry) {
    setState(() {
      _geometry = geometry;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (geometry == null) {
      return SizedBox.shrink();
    }

    return Container(
      height: 40,
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.all(5),
      child: Text(
        // Show a name of the geometry.
        geometry.name ?? "",
        textAlign: TextAlign.start,
      ),
    );
  }
}
