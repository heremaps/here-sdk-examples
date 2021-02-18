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

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:here_sdk/venue.control.dart';

class VenuesController extends StatefulWidget {
  final VenuesControllerState state;

  VenuesController({@required this.state});

  @override
  VenuesControllerState createState() => state;
}

class VenuesControllerState extends State<VenuesController> {
  VenueMap _venueMap;
  bool _isOpen = false;

  set(VenueMap venueMap) {
    _venueMap = venueMap;
  }

  bool isOpen() {
    return _isOpen;
  }

  setOpen(bool value) {
    setState(() {
      _isOpen = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOpen || _venueMap == null || _venueMap.venues.length == 0) {
      return SizedBox.shrink();
    }

    final venueList = _venueMap.venues.values;
    final height = min(venueList.length, 8);

    Widget listView = ListView(
      children: venueList.map((Venue venue) {
        return _venueItemBuilder(context, venue);
      }).toList(),
    );

    return Container(
      padding: EdgeInsets.only(top: 5, right: 4, left: 4),
      color: Colors.white,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(height: kMinInteractiveDimension * height, child: listView)
      ]),
    );
  }

  Widget _venueItemBuilder(BuildContext context, Venue venue) {
    String name = venue.venueModel.id.toString() +
        ": " +
        venue.venueModel.properties["name"].asString;
    return Stack(children: [
      Align(alignment: Alignment.centerLeft,
        child: Container(
          padding: EdgeInsets.only(right: kMinInteractiveDimension),
          child: FlatButton(
            color: Colors.blue,
            child: Text(
              name,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.normal,
              ),
            ),
            onPressed: () {
              _venueMap.selectedVenue = venue;
              setOpen(false);
            },
          ),
        ),
      ),
      Align(alignment: Alignment.centerRight,
        child: Container(
          width: kMinInteractiveDimension * 0.75,
          child: FlatButton(
            color: Colors.redAccent,
            padding: EdgeInsets.zero,
            child: Icon(Icons.close,
                color: Colors.white, size: kMinInteractiveDimension * 0.75),
            onPressed: () {
              setState(() {
                _venueMap.removeVenue(venue);
              });
            },
          ),
        ),
      ),
    ]);
  }
}
