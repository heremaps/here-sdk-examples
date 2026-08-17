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

import 'package:flutter/material.dart';
import 'package:here_sdk/venue.data.dart';
import 'package:provider/provider.dart';
import 'package:indoor_map_app/indoor_events.dart';
import 'package:indoor_map_app/indoor_map_tokens.dart';
import 'package:indoor_map_app/venue_data_provider.dart';
import 'package:indoor_map_app/venue_tap_controller.dart';
import 'package:indoor_map_app/widgets/app_list_tile_detailed.dart';
import 'package:indoor_map_app/widgets/app_search_field.dart';

const Duration _snapDuration = Duration(milliseconds: 220);

/// Draggable bottom sheet showing the venue list or the geometry list inside a
/// selected venue. Driven by [VenueDataProvider]'s sheet state fields.
class IndoorVenueBottomSheetWidget extends StatefulWidget {
  const IndoorVenueBottomSheetWidget({
    super.key,
    required this.dragController,
    required this.minBottomSheetSize,
    required this.maxBottomSheetSize,
    required this.tapController,
  });

  final DraggableScrollableController dragController;
  final double minBottomSheetSize;
  final double maxBottomSheetSize;
  final VenueTapController tapController;

  @override
  State<IndoorVenueBottomSheetWidget> createState() => IndoorVenueBottomSheetWidgetState();
}

class IndoorVenueBottomSheetWidgetState extends State<IndoorVenueBottomSheetWidget> {
  late final FocusNode _searchFocusNode;
  late final TextEditingController _searchController;
  late final ScrollController _listScrollController;
  late final VenueDataProvider _venueDataProvider;
  late final VenueTapController _tapController;
  double _currentSheetSize = 0.0;
  double _headerDragStartSize = 0.0;
  double _headerDragLatestSize = 0.0;
  static const double _geometrySelectedSheetSize = 0.22;

  // Tracks previous isSingleGeometrySelected to detect transitions and animate sheet height.
  bool _previousSingleGeometrySelected = false;
  // Hides the list from widget tree during venue load collapse to prevent RenderFlex overflow.
  bool _forceHideList = false;

  @override
  void initState() {
    super.initState();
    _venueDataProvider = context.read<VenueDataProvider>();
    _tapController = widget.tapController;
    _searchFocusNode = FocusNode();
    _searchController = TextEditingController();
    _listScrollController = ScrollController();
    _currentSheetSize = widget.minBottomSheetSize;
    _previousSingleGeometrySelected = _venueDataProvider.isSingleGeometrySelected;
    _searchController.addListener(_filterItems);
    _searchFocusNode.addListener(_handleSearchFocusChanged);
    widget.dragController.addListener(_handleSheetControllerChange);
  }

  @override
  void dispose() {
    _searchFocusNode
      ..removeListener(_handleSearchFocusChanged)
      ..dispose();
    _searchController
      ..removeListener(_filterItems)
      ..dispose();
    widget.dragController.removeListener(_handleSheetControllerChange);
    _listScrollController.dispose();
    super.dispose();
  }

  void _handleSheetControllerChange() {
    if (!mounted || !widget.dragController.isAttached) {
      return;
    }

    final double nextSize = widget.dragController.size;
    if ((_currentSheetSize - nextSize).abs() < 0.0001) {
      return;
    }

    // Only unfocus when sheet is shrinking (not during upward expansion from search tap).
    if (nextSize < _currentSheetSize && nextSize < widget.maxBottomSheetSize - 0.01 && _searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
    }

    // When sheet reaches min with no text, reset filtered lists to full.
    if (nextSize <= widget.minBottomSheetSize + 0.02 && _searchController.text.isEmpty) {
      filteredVenueIdList.updatedIdList.value = venueIdList.updatedIdList.value;
      filteredVenueNameList.updatedNameList.value = venueNameList.updatedNameList.value;
    }

    setState(() {
      _currentSheetSize = nextSize;
    });
  }

  /// Handles back button with progressive undo: keyboard -> text -> collapse.
  /// Returns true if consumed.
  bool handleBackEvent() {
    // Step 1: Close keyboard if open.
    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
      return true;
    }
    // Step 2: Clear search text if present.
    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
      return true;
    }
    // Step 3: Collapse sheet if expanded above min.
    if (widget.dragController.isAttached && widget.dragController.size > widget.minBottomSheetSize + 0.01) {
      widget.dragController.animateTo(widget.minBottomSheetSize, duration: _snapDuration, curve: Curves.easeOut);
      return true;
    }
    // Not consumed — parent should handle (remove venue or pop).
    return false;
  }

  void _handleSearchFocusChanged() {
    if (!_searchFocusNode.hasFocus) {
      return;
    }
    if (!widget.dragController.isAttached) {
      return;
    }
    // Tapping search at min or 0.22 should expand the sheet to max.
    widget.dragController.animateTo(widget.maxBottomSheetSize, duration: _snapDuration, curve: Curves.easeOut);
    // Re-request focus so keyboard stays open after sheet expansion.
    _searchFocusNode.requestFocus();
  }

  // Filters the displayed list based on the current search query.
  void _filterItems() {
    final String query = _searchController.text.toLowerCase();

    if (_venueDataProvider.sheetMode == VenueSheetMode.venueList) {
      if (query.isEmpty) {
        filteredVenueIdList.updatedIdList.value = venueIdList.updatedIdList.value;
        filteredVenueNameList.updatedNameList.value = venueNameList.updatedNameList.value;
        _venueDataProvider.refreshVenueList();
        return;
      }

      final List<int> indexList = <int>[];
      for (int i = 0; i < venueNameList.updatedNameList.value.length; i++) {
        final String venueName = venueNameList.updatedNameList.value[i];
        final String venueId = venueIdList.updatedIdList.value[i];
        if (venueName.toLowerCase().contains(query)) {
          indexList.add(i);
        }
      }

      filteredVenueIdList.updatedIdList.value = indexList.map((int i) => venueIdList.updatedIdList.value[i]).toList();
      filteredVenueNameList.updatedNameList.value = indexList
          .map((int i) => venueNameList.updatedNameList.value[i])
          .toList();
      _venueDataProvider.refreshVenueList();
    } else {
      if (query.isEmpty) {
        _venueDataProvider.resetGeometryList();
        return;
      }
      _venueDataProvider.filterGeometries(query);
    }
  }

  void _handleHeaderDragStart(DragStartDetails details) {
    _headerDragStartSize = widget.dragController.isAttached ? widget.dragController.size : widget.minBottomSheetSize;
    _headerDragLatestSize = _headerDragStartSize;
  }

  void _handleHeaderVerticalDrag(DragUpdateDetails details) {
    final double screenHeight = MediaQuery.sizeOf(context).height;
    if (screenHeight <= 0) {
      return;
    }

    final double baseSize = widget.dragController.isAttached ? widget.dragController.size : widget.minBottomSheetSize;
    final double deltaSize = -details.delta.dy / screenHeight;
    final double nextSize = (baseSize + deltaSize).clamp(widget.minBottomSheetSize, widget.maxBottomSheetSize);
    if (widget.dragController.isAttached) {
      widget.dragController.jumpTo(nextSize);
    }
    _headerDragLatestSize = nextSize;
  }

  void _handleHeaderDragEnd(DragEndDetails details) {
    if (!widget.dragController.isAttached) {
      return;
    }

    const double flingThreshold = 500.0;
    final double velocity = details.velocity.pixelsPerSecond.dy;
    final double current = widget.dragController.size;
    final double midPoint = (widget.minBottomSheetSize + widget.maxBottomSheetSize) / 2;

    final double target;
    if (velocity <= -flingThreshold) {
      target = widget.maxBottomSheetSize;
    } else if (velocity >= flingThreshold) {
      target = widget.minBottomSheetSize;
    } else {
      target = current < midPoint ? widget.minBottomSheetSize : widget.maxBottomSheetSize;
    }

    widget.dragController.animateTo(target, duration: _snapDuration, curve: Curves.easeOut);
  }

  // Handles venue load tap. Hides list first to prevent overflow, collapses, then loads.
  void _handleVenueLoadEvent(String venueId) {
    // Hide list FIRST to prevent overflow when clear() triggers rebuild.
    setState(() {
      _forceHideList = true;
    });
    _searchFocusNode.unfocus();
    _searchController.clear();
    // Collapse sheet, then trigger venue load after animation completes.
    widget.dragController.animateTo(widget.minBottomSheetSize, duration: _snapDuration, curve: Curves.easeOut).then((
      _,
    ) {
      if (!mounted) {
        return;
      }
      setState(() {
        _forceHideList = false;
      });
      _venueDataProvider.loadVenueEvent(venueId);
    });
  }

  // Handles geometry tap from the list.
  void _handleGeometryListTapEvent(VenueGeometry selectedGeometry) {
    _searchFocusNode.unfocus();
    _searchController.clear();
    _tapController.selectGeometryFromList(selectedGeometry);
  }

  // Reacts to [isSingleGeometrySelected] transitions by animating the sheet.
  void _handleSingleGeometryTransition(bool currentValue) {
    if (currentValue == _previousSingleGeometrySelected) {
      return;
    }
    _previousSingleGeometrySelected = currentValue;

    if (!widget.dragController.isAttached) {
      return;
    }

    if (currentValue) {
      // If search is active when geometry is selected from map, clear it first.
      if (_searchFocusNode.hasFocus || _searchController.text.isNotEmpty) {
        _searchFocusNode.unfocus();
        _searchController.clear();
      }
      widget.dragController.animateTo(_geometrySelectedSheetSize, duration: _snapDuration, curve: Curves.easeOut);
    } else {
      // Geometry deselected, collapse to min only if at peek height.
      final double currentSize = widget.dragController.isAttached ? widget.dragController.size : _currentSheetSize;
      if (currentSize <= _geometrySelectedSheetSize + 0.05) {
        widget.dragController.animateTo(widget.minBottomSheetSize, duration: _snapDuration, curve: Curves.easeOut);
      }
    }
  }

  /// Public helper used by the parent screen while handling back press.
  void sheetCollapseCleanup() {
    _searchFocusNode.unfocus();
    _searchController.clear();
    filteredVenueIdList.updatedIdList.value = venueIdList.updatedIdList.value;
    filteredVenueNameList.updatedNameList.value = venueNameList.updatedNameList.value;
  }

  @override
  Widget build(BuildContext context) {
    final VenueSheetMode sheetMode = context.select<VenueDataProvider, VenueSheetMode>(
      (VenueDataProvider p) => p.sheetMode,
    );
    final List<String> titleList = context.select<VenueDataProvider, List<String>>(
      (VenueDataProvider p) => p.sheetTitleList,
    );
    final List<String?> descriptionList = context.select<VenueDataProvider, List<String?>>(
      (VenueDataProvider p) => p.sheetDescriptionList,
    );
    final bool isSingleGeometrySelected = context.select<VenueDataProvider, bool>(
      (VenueDataProvider p) => p.isSingleGeometrySelected,
    );

    // React to isSingleGeometrySelected transitions to animate sheet height.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _handleSingleGeometryTransition(isSingleGeometrySelected);
    });

    final Widget leftAccessory = sheetMode == VenueSheetMode.venueList
        ? const ImageIcon(AssetImage('assets/building.png'))
        : Image.asset('assets/space_icon.png', width: IndoorMapTokens.size32, height: IndoorMapTokens.size32);

    final Widget rightAccessory = sheetMode == VenueSheetMode.venueList
        ? const ImageIcon(AssetImage('assets/right_arrow.png'))
        : const ImageIcon(AssetImage('assets/north_west_arrow.png'), size: IndoorMapTokens.size20);

    final String searchHintText = sheetMode == VenueSheetMode.venueList ? 'Search for venues' : 'Search for spaces';

    // Show the list when sheet is above min or search text is present.
    final bool showItemsInList =
        !_forceHideList && (_currentSheetSize > widget.minBottomSheetSize + 0.02 || _searchController.text.isNotEmpty);

    return Positioned.fill(
      child: DraggableScrollableSheet(
        controller: widget.dragController,
        initialChildSize: widget.minBottomSheetSize,
        minChildSize: widget.minBottomSheetSize,
        maxChildSize: widget.maxBottomSheetSize,
        expand: false,
        builder: (BuildContext context, ScrollController scrollController) {
          return SafeArea(
            child: Container(
              decoration: BoxDecoration(
                color: IndoorMapTokens.surfaceColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(IndoorMapTokens.radiusMedium)),
              ),
              child: Stack(
                children: <Widget>[
                  // This hidden scrollable keeps DraggableScrollableSheet internally attached.
                  // Real gestures are handled by dedicated header and list controllers.
                  IgnorePointer(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      physics: const NeverScrollableScrollPhysics(),
                      child: const SizedBox(height: 1),
                    ),
                  ),
                  // CustomScrollView avoids RenderFlex overflow during keyboard dismiss.
                  CustomScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    slivers: <Widget>[
                      // Header — handles drag gestures for sheet expand/collapse.
                      SliverToBoxAdapter(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onVerticalDragStart: _handleHeaderDragStart,
                          onVerticalDragUpdate: _handleHeaderVerticalDrag,
                          onVerticalDragEnd: _handleHeaderDragEnd,
                          child: Column(
                            children: <Widget>[
                              const SizedBox(height: IndoorMapTokens.size10),
                              Container(
                                height: IndoorMapTokens.dragHandleHeight,
                                width: IndoorMapTokens.dragHandleWidth,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade400,
                                  borderRadius: BorderRadius.circular(IndoorMapTokens.radiusMedium),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(IndoorMapTokens.size10),
                                child: AppSearchField(
                                  focusNode: _searchFocusNode,
                                  controller: _searchController,
                                  hintText: searchHintText,
                                  onCancel: () {
                                    _searchController.clear();
                                    _searchFocusNode.unfocus();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // List of venues or geometries — fills remaining viewport space.
                      if (showItemsInList)
                        SliverFillRemaining(
                          child: Scrollbar(
                            controller: _listScrollController,
                            thumbVisibility: true,
                            interactive: true,
                            child: ListView.builder(
                              controller: _listScrollController,
                              itemCount: titleList.length,
                              itemBuilder: (BuildContext context, int index) {
                                return AppListTileDetailed(
                                  title: titleList[index],
                                  subtitle: sheetMode == VenueSheetMode.geometryList ? descriptionList[index] : null,
                                  leadingAccessory: leftAccessory,
                                  trailingAccessory: rightAccessory,
                                  onTap: () {
                                    sheetMode == VenueSheetMode.venueList
                                        ? _handleVenueLoadEvent(descriptionList[index] ?? '')
                                        : _handleGeometryListTapEvent(_venueDataProvider.venueGeometryList[index]);
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
