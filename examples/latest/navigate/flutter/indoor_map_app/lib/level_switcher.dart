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
  final int _maxNumberOfVisibleLevels = 3;
  ScrollController _scrollController = ScrollController();

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
    // Don't show the level switcher if no venue is selected.
    if (_selectedDrawing == null || _selectedLevel == null) {
      return SizedBox.shrink();
    }

    // Find scroll position.
    final visibleHeight = _getVisibleHeight(_selectedDrawing!.levels.length);
    final scrollIndex = _getScrollIndex();
    final scrollPosition = max(0, scrollIndex * kMinInteractiveDimension);
    final scrollController = new ScrollController();
    double _marginBottom = 594;

    if (_selectedDrawing!.levels.length == 1) {
      _marginBottom = _marginBottom - (2 * visibleHeight);
    }

    if (_selectedDrawing!.levels.length == 2) {
      _marginBottom = 545;
    }

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
        scrollController.animateTo(
          _centerLevelInVisibleArea(visibleHeight, scrollPosition as double),
          duration: new Duration(milliseconds: 400),
          curve: Curves.linear,
        );
      });
    }

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: kMinInteractiveDimension,
          margin: EdgeInsets.only(bottom: _marginBottom, right: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          ),
          child: GestureDetector(
            onTap: () {
              int currentIndex = _selectedDrawing!.levels.indexOf(_selectedLevel!);
              if (currentIndex >= 0) {
                VenueLevel levelAbove = _selectedDrawing!.levels[currentIndex + 1];
                setState(() {
                  _selectedVenue!.selectedLevel = levelAbove;
                });
              }
            },
            child: Image.asset('assets/indoor_up-arrow-level-switcher.png', width: 40, height: 40),
          ),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: Container(
            margin: EdgeInsets.only(bottom: 450, right: 12),
            decoration: BoxDecoration(color: Colors.black12),
            child: SizedBox(
              width: kMinInteractiveDimension,
              height: _getVisibleHeight(_selectedDrawing!.levels.length),
              child: listView,
            ),
          ),
        ),
        Container(
          width: kMinInteractiveDimension,
          margin: EdgeInsets.only(bottom: 410, right: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
          ),
          child: GestureDetector(
            onTap: () {
              int currentIndex = _selectedDrawing!.levels.indexOf(_selectedLevel!);
              int lastIndex = _selectedDrawing!.levels.length - 1;
              if (currentIndex <= lastIndex) {
                VenueLevel levelBelow = _selectedDrawing!.levels[currentIndex - 1];
                setState(() {
                  _selectedVenue!.selectedLevel = levelBelow;
                });
              }
            },
            child: Image.asset('assets/indoor_down-arrow-level-switcher.png', width: 40, height: 40),
          ),
        ),
      ],
    );
  }

  // Create a list view item from the level.
  Widget _levelItemBuilder(BuildContext context, VenueLevel level) {
    bool isSelectedLevel = level.identifier == _selectedLevel!.identifier;

    return Container(
      color: isSelectedLevel ? Colors.grey : Colors.white,
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: isSelectedLevel ? Colors.white : Colors.black,
          padding: EdgeInsets.zero,
        ),
        child: Text(
          level.shortName,
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: isSelectedLevel ? FontWeight.bold : FontWeight.normal),
        ),
        onPressed: () {
          // Select a level, if the user clicks on the item.
          _selectedVenue!.selectedLevel = level;
        },
      ),
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
