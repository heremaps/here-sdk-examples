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

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:here_sdk/venue.control.dart';
import 'package:here_sdk/venue.data.dart';
import 'package:venues/venue_tap_controller.dart';

class VenueSearchController extends StatefulWidget {
  final VenueSearchControllerState state;

  VenueSearchController({@required this.state});

  @override
  VenueSearchControllerState createState() => state;
}

class VenueSearchControllerState extends State<VenueSearchController> {
  VenueTapController _tapController;
  Venue _venue;
  bool _isOpen = false;
  TextEditingController _filterController = TextEditingController();
  VenueGeometryFilterType _filterType = VenueGeometryFilterType.name;

  set(VenueTapController tapController) {
    _tapController = tapController;
  }

  bool isOpen() {
    return _isOpen;
  }

  setOpen(bool value) {
    setState(() {
      _isOpen = value;
    });
  }

  setVenue(Venue venue) {
    setState(() {
      _venue = venue;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOpen || _venue == null) {
      return SizedBox.shrink();
    }

    final filteredList =
        _venue.venueModel.filterGeometry(_filterController.text, _filterType);
    final height = min(filteredList.length, 8);

    Widget listView = ListView(
      children: filteredList.map((VenueGeometry geometry) {
        return _geometryItemBuilder(context, geometry);
      }).toList(),
    );

    return Container(
      padding: EdgeInsets.only(top: 5, right: 4, left: 4),
      color: Colors.white,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 200,
            child: TextField(
                controller: _filterController,
                decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Search inside the venue'),
                onChanged: (text) {
                  _setFilter(text);
                }),
          ),
          DropdownButton<VenueGeometryFilterType>(
            value: _filterType,
            onChanged: (VenueGeometryFilterType filterType) {
              setState(() {
                _filterType = filterType;
              });
            },
            items: VenueGeometryFilterType.values
                .map((VenueGeometryFilterType type) {
              return DropdownMenuItem<VenueGeometryFilterType>(
                value: type,
                child: Text(
                  _getFilterTypeName(type),
                  style: TextStyle(color: Colors.black),
                ),
              );
            }).toList(),
          )
        ]),
        Container(height: kMinInteractiveDimension * height, child: listView)
      ]),
    );
  }

  String _getFilterTypeName(VenueGeometryFilterType type) {
    switch (type) {
      case VenueGeometryFilterType.name:
        return "Name";
      case VenueGeometryFilterType.address:
        return "Address";
      case VenueGeometryFilterType.nameOrAddress:
        return "Name or address";
      case VenueGeometryFilterType.iconName:
        return "Icon name";
    }

    return "";
  }

  _setFilter(String filter) {
    setState(() {
      _filterController.value = TextEditingValue(
        text: filter,
        selection: TextSelection.fromPosition(
          TextPosition(offset: filter.length),
        ),
      );
    });
  }

  Widget _geometryItemBuilder(BuildContext context, VenueGeometry geometry) {
    String name = geometry.name + ", " + geometry.level.name;
    return FlatButton(
      color: Colors.blue,
      child: Text(
        name,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.normal,
        ),
      ),
      onPressed: () {
        _tapController.selectGeometry(geometry, geometry.center, true);
        setOpen(false);
      },
    );
  }
}
