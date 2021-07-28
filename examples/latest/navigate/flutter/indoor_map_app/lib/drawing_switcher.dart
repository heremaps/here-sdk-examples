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

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:here_sdk/venue.control.dart';
import 'package:here_sdk/venue.data.dart';

// Allows to select a drawing inside a venue trough UI.
class DrawingSwitcher extends StatefulWidget {
  final DrawingSwitcherState state;

  DrawingSwitcher({required this.state});

  @override
  DrawingSwitcherState createState() => state;
}

class DrawingSwitcherState extends State<DrawingSwitcher> {
  Venue? _selectedVenue;
  VenueDrawing? _selectedDrawing;
  bool _isOpen = false;

  onDrawingsChanged(Venue? selectedVenue) {
    setState(() {
      _selectedVenue = selectedVenue;
      _selectedDrawing = selectedVenue != null ? selectedVenue.selectedDrawing : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Don't show the drawing switcher if no venue is selected or there is only
    // one drawing in the venue.
    if (_selectedDrawing == null || _selectedVenue!.venueModel.drawings.length < 2) {
      return SizedBox.shrink();
    }

    // Create a list view with drawings.
    Widget listView = ListView(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      reverse: true,
      itemExtent: kMinInteractiveDimension,
      children: _selectedVenue!.venueModel.drawings.map((VenueDrawing drawing) {
        return _drawingItemBuilder(context, drawing);
      }).toList(),
    );

    return Align(
      alignment: Alignment.topRight,
      child: Container(
        margin: EdgeInsets.only(top: 5, right: 0),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 200,
              height: _selectedVenue!.venueModel.drawings.length * kMinInteractiveDimension,
              child: _isOpen ? listView : null,
            ),
          ),
          Container(
            alignment: Alignment.topCenter,
            width: kMinInteractiveDimension,
            child: FlatButton(
              padding: EdgeInsets.zero,
              child:
                  Icon(Icons.menu, color: _isOpen ? Colors.blue : Colors.black, size: kMinInteractiveDimension * 0.75),
              onPressed: () {
                // Hide or show the list with drawings.
                setState(() {
                  _isOpen = !_isOpen;
                });
              },
            ),
          ),
        ]),
      ),
    );
  }

  // Create a list view item from the drawing.
  Widget _drawingItemBuilder(BuildContext context, VenueDrawing drawing) {
    bool isSelectedDrawing = drawing.id == _selectedDrawing!.id;
    Property? nameProp = drawing.properties["name"];
    return FlatButton(
      color: isSelectedDrawing ? Colors.blue : Colors.white,
      padding: EdgeInsets.zero,
      child: Text(
        nameProp != null ? nameProp.asString : "",
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isSelectedDrawing ? Colors.white : Colors.black,
          fontWeight: isSelectedDrawing ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onPressed: () {
        // Hide the list with drawings.
        _isOpen = false;
        // Select a drawing, if the user clicks on the item.
        _selectedVenue!.selectedDrawing = drawing;
      },
    );
  }
}
