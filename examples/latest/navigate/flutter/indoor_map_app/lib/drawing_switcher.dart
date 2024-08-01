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
    if (_selectedDrawing == null) {
      return SizedBox.shrink();
    }

    // Create a list view with drawings.
    Widget listView = Padding(
      padding: EdgeInsets.only(bottom: 82), // Adjust the top padding as needed
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          reverse: true,
          itemExtent: kMinInteractiveDimension,
          children: _selectedVenue!.venueModel.drawings.map((VenueDrawing drawing) {
            return _drawingItemBuilder(context, drawing);
          }).toList(),
        ),
      ),
    );

    double getTextWidth(String text, TextStyle style) {
      final TextPainter textPainter = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout(minWidth: 0, maxWidth: double.infinity);

      return textPainter.width;
    }

    return Stack(
      children: [
        Positioned(
          right: 2,
          bottom: _selectedVenue!.venueModel.drawings.length == 1 ? 280 : 280,
          child: GestureDetector(
            onTap: () {
              // Hide or show the list with drawings.
              setState(() {
                _isOpen = !_isOpen;
              });
            },
            child: Image.asset(
              'assets/structure-switcher.png',
              width: 70,
              height: 70,
            ),
          ),
        ),
        Positioned(
          right: 65,
          bottom: _selectedVenue!.venueModel.drawings.length == 1
              ? 210
              : _selectedVenue!.venueModel.drawings.length == 2
              ? 185
              : 150,
          child: Container(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: 200,
                    height: _selectedVenue!.venueModel.drawings.length == 1
                        ? 130
                        : _selectedVenue!.venueModel.drawings.length == 2
                        ? 170
                        : 280,
                    child: _isOpen ? listView : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Create a list view item from the drawing.
  Widget _drawingItemBuilder(BuildContext context, VenueDrawing drawing) {
    bool isSelectedDrawing = drawing.identifier == _selectedDrawing!.identifier;
    Property? nameProp = drawing.properties["name"];
    return TextButton(
      style: TextButton.styleFrom(
        backgroundColor: Colors.white, // Set background color to white
        foregroundColor: Colors.black, // Set text color to black
        padding: EdgeInsets.zero,
      ),
      child: Text(
        nameProp != null ? nameProp.asString : "",
        textAlign: TextAlign.left,
        style: TextStyle(
          color: isSelectedDrawing ? Colors.blue : Colors.black,
          fontWeight: isSelectedDrawing ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onPressed: () {
        // Hide the list with drawings.
        _isOpen = false;
        // Select a drawing, if the user clicks on the item.
        _selectedVenue!.selectedDrawing = drawing;
        setState(() {});
      },
    );
  }
}
