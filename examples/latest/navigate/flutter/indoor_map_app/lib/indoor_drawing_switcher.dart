/*
 * Copyright (C) 2020-2026 HERE Europe B.V.
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

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:indoor_map_app/indoor_map_tokens.dart';
import 'package:indoor_map_app/venue_data_provider.dart';
import 'package:indoor_map_app/widgets/app_circle_icon_button.dart';
import 'package:here_sdk/venue.control.dart';
import 'package:here_sdk/venue.data.dart';

/// Drawing switcher overlay for the indoor map.
/// Displays a FAB to open a flyout list of all venue drawings, allowing the
/// user to switch the active drawing on the map. The list flyout is scrollable
/// if the number of drawings exceeds the max visible rows.
class IndoorDrawingSwitcher extends StatefulWidget {
  const IndoorDrawingSwitcher({super.key});

  @override
  State<IndoorDrawingSwitcher> createState() => _IndoorDrawingSwitcherState();
}

class _IndoorDrawingSwitcherState extends State<IndoorDrawingSwitcher> {
  static const double _rowHeight = IndoorMapTokens.drawingRowHeight;
  static const int _maxVisibleRows = IndoorMapTokens.drawingSwitcherMaxVisibleRows;
  static const double _listWidth = IndoorMapTokens.drawingListWidth;
  static const double _fabSize = IndoorMapTokens.size40;
  static const double _listGap = IndoorMapTokens.size10;

  late final ScrollController _controller;
  late VenueDataProvider _dataProvider;
  late VenueDrawingSelectionListener _drawingSelectionListener;
  VenueMap? _venueMap;
  Venue? _selectedVenue;

  @override
  void initState() {
    super.initState();
    _dataProvider = context.read<VenueDataProvider>();
    _controller = ScrollController();
    _venueMap = _dataProvider.venueEngine?.venueMap;
    _selectedVenue = _venueMap?.selectedVenue;
    if (_selectedVenue == null) {
      debugPrint('IndoorDrawingSwitcher: selected venue is null');
      return;
    }
    _drawingSelectionListener = VenueDrawingSelectionListener((
      Venue venue,
      VenueDrawing? deselectedDrawing,
      VenueDrawing selectedDrawing,
    ) {
      _dataProvider.setVenueDrawingListVisibility(false);
    });
    _venueMap?.addDrawingSelectionListener(_drawingSelectionListener);
  }

  @override
  void dispose() {
    _controller.dispose();
    _venueMap?.removeDrawingSelectionListener(_drawingSelectionListener);
    _venueMap = null;
    _selectedVenue = null;
    _dataProvider.currSelectedDrawingIndx = -1;
    super.dispose();
  }

  void _smoothScrollToSelectedDrawingIndex(int currIndex) {
    if (!_controller.hasClients) return;
    final int itemCount = _dataProvider.venueDrawingList?.length ?? 0;
    if (itemCount == 0) return;
    final int visibleRows = math.min(itemCount, _maxVisibleRows);
    final double offset = _controller.offset;
    final int firstVisible = (offset / _rowHeight).floor();
    final int lastVisible = firstVisible + visibleRows - 1;
    if (currIndex < firstVisible) {
      _controller.animateTo(currIndex * _rowHeight, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    } else if (currIndex > lastVisible) {
      _controller.animateTo(
        (currIndex - visibleRows + 1) * _rowHeight,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _tapDrawingChangeAction(int index) {
    // Delegate the SDK interaction (drawing selection + camera move) to the
    // provider; the widget only handles UI.
    _dataProvider.selectDrawing(index);
  }

  String _drawingName(VenueDrawing drawing) {
    final Property? property = drawing.properties['name'];
    return property?.asString ?? '';
  }

  @override
  Widget build(BuildContext context) {
    if (_venueMap == null || _selectedVenue == null || _dataProvider.venueDrawingList == null) {
      return const SizedBox.shrink();
    }
    final int currSelectedDrawingIndx = context.select<VenueDataProvider, int>(
      (VenueDataProvider p) => p.currSelectedDrawingIndx,
    );
    final bool showVenueDrawingList = context.select<VenueDataProvider, bool>(
      (VenueDataProvider p) => p.showVenueDrawingList,
    );

    final bool isScrollable = (_dataProvider.venueDrawingList?.length ?? 0) > _maxVisibleRows;
    final int visibleRows = math.min(_dataProvider.venueDrawingList?.length ?? 1, _maxVisibleRows);

    return SizedBox(
      // Keep full height so overflowed flyout remains touchable/scrollable.
      height: _rowHeight * visibleRows,
      width: _fabSize + _listWidth + _listGap,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          if (showVenueDrawingList)
            Positioned(
              right: _fabSize + _listGap,
              bottom: 0,
              child: Material(
                elevation: IndoorMapTokens.elevation4,
                borderRadius: BorderRadius.circular(IndoorMapTokens.radiusSmall),
                child: SizedBox(
                  width: _listWidth,
                  height: _rowHeight * visibleRows,
                  child: Scrollbar(
                    controller: _controller,
                    thumbVisibility: isScrollable,
                    interactive: isScrollable,
                    child: ListView.builder(
                      primary: false,
                      shrinkWrap: true,
                      itemCount: _dataProvider.venueDrawingList?.length ?? 0,
                      itemExtent: _rowHeight,
                      physics: isScrollable ? const ClampingScrollPhysics() : const NeverScrollableScrollPhysics(),
                      controller: _controller,
                      itemBuilder: (BuildContext context, int index) {
                        final bool selected = index == currSelectedDrawingIndx;
                        return GestureDetector(
                          onTap: () => _tapDrawingChangeAction(index),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(IndoorMapTokens.size5),
                            child: Text(
                              textAlign: TextAlign.center,
                              _drawingName(_dataProvider.venueDrawingList![index]),
                              style: TextStyle(
                                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                fontSize: IndoorMapTokens.size13,
                                color: selected ? IndoorMapTokens.selectedColor : IndoorMapTokens.unselectedTextColor,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: 0,
            bottom: 0,
            child: AppCircleIconButton(
              size: _fabSize,
              icon: const ImageIcon(AssetImage('assets/building.png')),
              onPressed: () {
                _dataProvider.setVenueDrawingListVisibility(!showVenueDrawingList);
                if (_dataProvider.showVenueDrawingList) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _smoothScrollToSelectedDrawingIndex(_dataProvider.currSelectedDrawingIndx);
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
