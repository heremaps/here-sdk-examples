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

// Allows to select a level inside a venue trough UI.
class LevelSwitcher extends StatefulWidget {
  final LevelSwitcherState state;

  LevelSwitcher({required this.state});

  @override
  LevelSwitcherState createState() => state;
}

class LevelSwitcherState extends State<LevelSwitcher> {
  Venue? _selectedVenue;
  VenueDrawing? _selectedDrawing;
  VenueLevel? _selectedLevel;
  final int _maxNumberOfVisibleLevels = 5;

  onLevelsChanged(Venue? selectedVenue) {
    setState(() {
      _selectedVenue = selectedVenue;
      if (selectedVenue != null) {
        _selectedDrawing = selectedVenue.selectedDrawing;
        _selectedLevel = selectedVenue.selectedLevel;
      } else {
        _selectedDrawing = null;
        _selectedLevel = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Don't show the level switcher if no venue is selected or there is only
    // one level in the drawing.
    if (_selectedDrawing == null || _selectedDrawing!.levels.length < 2 || _selectedLevel == null) {
      return SizedBox.shrink();
    }

    // Find scroll position.
    final visibleHeight = _getVisibleHeight(_selectedDrawing!.levels.length);
    final scrollIndex = _getScrollIndex();
    final scrollPosition = max(0, scrollIndex * kMinInteractiveDimension);
    final scrollController = new ScrollController();

    // Create a list view with levels.
    Widget listView = ListView(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      reverse: true,
      controller: scrollController,
      itemExtent: kMinInteractiveDimension,
      children: _selectedDrawing!.levels.map((VenueLevel level) {
        return _levelItemBuilder(context, level);
      }).toList(),
    );

    // Scroll the list view to make the selected level in the middle of
    // the list, if possible.
    if (_selectedDrawing!.levels.length > _maxNumberOfVisibleLevels) {
      Future.delayed(Duration(milliseconds: 100), () {
        scrollController.animateTo(_centerLevelInVisibleArea(visibleHeight, scrollPosition as double),
            duration: new Duration(milliseconds: 400), curve: Curves.linear);
      });
    }

    return Align(
      alignment: Alignment.bottomRight,
      child: Container(
        margin: EdgeInsets.only(bottom: 60, right: 5),
        decoration: BoxDecoration(
          color: Colors.black12,
          border: Border.all(color: Colors.black12),
        ),
        child: SizedBox(
          width: kMinInteractiveDimension,
          height: _getVisibleHeight(_selectedDrawing!.levels.length),
          child: listView,
        ),
      ),
    );
  }

  // Create a list view item from the level.
  Widget _levelItemBuilder(BuildContext context, VenueLevel level) {
    bool isSelectedLevel = level.id == _selectedLevel!.id;
    return FlatButton(
      color: isSelectedLevel ? Colors.blue : Colors.white,
      padding: EdgeInsets.zero,
      child: Text(
        level.shortName,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isSelectedLevel ? Colors.white : Colors.black,
          fontWeight: isSelectedLevel ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onPressed: () {
        // Select a level, if the user clicks on the item.
        _selectedVenue!.selectedLevel = level;
      },
    );
  }

  // Get an index of the item to scroll to it. If the selected level far enough
  // from the begin of the end of the list, scroll to it. Otherwise scroll to
  // the offset in begin or in the end of the list.
  int _getScrollIndex() {
    int indexOffset = (_maxNumberOfVisibleLevels / 2).floor();
    if (_selectedVenue!.selectedLevelIndex < indexOffset) {
      return indexOffset;
    }
    int backOffset = _selectedDrawing!.levels.length - 1 - indexOffset;
    if (_selectedVenue!.selectedLevelIndex > backOffset) {
      return backOffset;
    }

    return _selectedVenue!.selectedLevelIndex;
  }

  // Get a visible height of the list view with levels.
  double _getVisibleHeight(int levelsCount) {
    final int numberOfVisibleLevels = min(_maxNumberOfVisibleLevels, levelsCount);
    return numberOfVisibleLevels * kMinInteractiveDimension;
  }

  // Returns a scroll offset to put the level to the center of the list view.
  double _centerLevelInVisibleArea(double visibleHeight, double levelPosition) {
    return max(0.0, levelPosition - (visibleHeight - kMinInteractiveDimension) / 2);
  }
}
