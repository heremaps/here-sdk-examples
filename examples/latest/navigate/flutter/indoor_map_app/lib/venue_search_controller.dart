/*
* Copyright (C) 2020-2023 HERE Europe B.V.
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
import 'package:indoor_map_app/venue_tap_controller.dart';

class VenueSearchController extends StatefulWidget {
  final VenueSearchControllerState state;

  VenueSearchController({required this.state});

  @override
  VenueSearchControllerState createState() => state;
}

class VenueSearchControllerState extends State<VenueSearchController> {
  VenueTapController? _tapController;
  Venue? _venue;
  bool _isOpen = false;
  TextEditingController _filterController = TextEditingController();
  VenueGeometryFilterType? _filterType = VenueGeometryFilterType.name;
  late List<String> _itemsList = ["Select Item"];
  late String _dropdownValue = "Select Item";
  late List<VenueGeometry> _searchResult;
  var _iconMap = new Map();
  int _rowStrLength = 40;

  set(VenueTapController? tapController) {
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

  setVenue(Venue? venue) {
    setState(() {
      _venue = venue;
      _filterType = VenueGeometryFilterType.name;
      if(_itemsList.length > 1) {
        _itemsList.removeRange(1, _itemsList.length);
        _dropdownValue = "Select Item";
      }
      int duplicateCount = 0;
      _searchResult = _venue!.venueModel.geometriesByName;
      for (var i = 0; i < _searchResult.length; i++) {
        var geometryName = _searchResult[i].name;
        if(geometryName.length > _rowStrLength) {
          int startIndex = 0;
          int endIndex = _rowStrLength;
          geometryName = geometryName.substring(startIndex, endIndex);
        }
        var geometryLevel = _searchResult[i].level.name;
        var name = geometryName + "," + geometryLevel;
        if(_itemsList.contains(name)) {
          duplicateCount += 1;
          name += " $duplicateCount";
          _itemsList.insert(i + 1, name);
        }
        else {
          duplicateCount = 0;
          _itemsList.insert(i + 1, name);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOpen || _venue == null) {
      return SizedBox.shrink();
    }

    final filteredList = _venue!.venueModel.filterGeometry(_filterController.text, _filterType!);
    final height = min(filteredList.length, 8);

    Widget listView = ListView(
      children: filteredList.map((VenueGeometry geometry) {
        return _geometryItemBuilder(context, geometry);
      }).toList(),
    );

    return Container(
      padding: EdgeInsets.only(top: 5, left: 0),
      color: Colors.white,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: MediaQuery.of(context).size.width,
            child: DropdownButton<VenueGeometryFilterType>(
              value: _filterType,
              onChanged: (VenueGeometryFilterType? filterType) {
                setState(() {
                  _filterType = filterType;
                  if(_itemsList.length > 1) {
                    _itemsList.removeRange(1, _itemsList.length);
                  }
                  if(_filterType!.name == "name") {
                    int duplicateCount = 0;
                    _searchResult = _venue!.venueModel.geometriesByName;
                    for (var i = 0; i < _searchResult.length; i++) {
                      var geometryName = _searchResult[i].name;
                      if(geometryName.length > _rowStrLength) {
                        int startIndex = 0;
                        int endIndex = _rowStrLength;
                        geometryName = geometryName.substring(startIndex, endIndex);
                      }
                      var geometryLevel = _searchResult[i].level.name;
                      var name = geometryName + ", " + geometryLevel;
                      if(_itemsList.contains(name)) {
                        duplicateCount += 1;
                        name += " $duplicateCount";
                        _itemsList.insert(i + 1, name);
                      }
                      else {
                        duplicateCount = 0;
                        _itemsList.insert(i + 1, name);
                      }
                    }
                  }
                  else if(_filterType!.name == "iconName") {
                    int duplicateCount = 0;
                    _searchResult.clear();
                    _iconMap = _venue!.venueModel.geometriesByIconNames;
                    _iconMap.forEach((key, value) {
                      for (var i = 0; i < value.length; i++) {
                        _searchResult.add(value[i]);
                      }
                    });
                    for (var i = 0; i < _searchResult.length; i++) {
                      var geometryName = _searchResult[i].name;
                      var geometryLevel = _searchResult[i].level.name;
                      var name = geometryName + ", " + geometryLevel;
                      name += "\n(Icon: " + _searchResult[i].labelName + ")";
                      if(_itemsList.contains(name)) {
                        duplicateCount += 1;
                        name += " $duplicateCount";
                        _itemsList.insert(i+1, name);
                      }
                      else {
                        duplicateCount = 0;
                        _itemsList.insert(i+1, name);
                      }
                    }
                  }
                  else {
                    int duplicateCount = 0;
                    _searchResult = _venue!.venueModel.geometriesByName;
                    for (var i = 0; i < _searchResult.length; i++) {
                      var geometryName = _searchResult[i].name;
                      if(geometryName.length > _rowStrLength) {
                        int startIndex = 0;
                        int endIndex = _rowStrLength;
                        geometryName = geometryName.substring(startIndex, endIndex);
                      }
                      var geometryLevel = _searchResult[i].level.name;
                      var geometryAddress = _searchResult[i].internalAddress;
                      var name = geometryName + ", " + geometryLevel;
                      var address = "";
                      if(geometryAddress != null) {
                          address = geometryAddress!.address;
                      }
                      name += "\n(Address: " + address + ")";
                      if(_itemsList.contains(name)) {
                        duplicateCount += 1;
                        name += " $duplicateCount";
                        _itemsList.insert(i + 1, name);
                      }
                      else {
                        duplicateCount = 0;
                        _itemsList.insert(i + 1, name);
                      }
                      }
                    }
                  _dropdownValue = _itemsList[0];
                });
              },
              items: VenueGeometryFilterType.values.map((VenueGeometryFilterType type) {
                return DropdownMenuItem<VenueGeometryFilterType>(
                  value: type,
                  child: Text(
                    _getFilterTypeName(type),
                    style: TextStyle(color: Colors.black),
                  ),
                );
              }).toList(),
            ),
          ),
        ]),
        Container(
          width: MediaQuery.of(context).size.width,
          child: DropdownButton(
            // Initial Value
            value: _dropdownValue,
            items: _itemsList.map((String items) {
              return DropdownMenuItem(
                value: items,
                child: Text(items),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _dropdownValue = value!;
                final index = _itemsList.indexOf(_dropdownValue)-1;
                _tapController!.selectGeometry(_searchResult[index], _searchResult[index].center, true);
                setOpen(false);
              });
            },
          ),
        ),
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
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: Colors.blue,
      ),
      child: Text(
        name,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.normal,
        ),
      ),
      onPressed: () {
        _tapController!.selectGeometry(geometry, geometry.center, true);
        setOpen(false);
      },
    );
  }
}
