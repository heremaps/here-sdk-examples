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
import 'package:provider/provider.dart';
import 'package:indoor_map_app/indoor_map_tokens.dart';
import 'package:indoor_map_app/indoor_routing_data_provider.dart';
import 'package:indoor_map_app/venue_data_provider.dart';
import 'package:indoor_map_app/widgets/app_list_tile_detailed.dart';
import 'package:indoor_map_app/widgets/app_search_field.dart';
import 'package:here_sdk/venue.data.dart';

/// Full-screen space selection list used while picking source / destination.
/// Displays a search field and a scrollable list of spaces matching the search query.
class IndoorRoutingSpaceSelectionList extends StatefulWidget {
  const IndoorRoutingSpaceSelectionList({super.key});

  @override
  State<IndoorRoutingSpaceSelectionList> createState() => _IndoorRoutingSpaceSelectionListState();
}

class _IndoorRoutingSpaceSelectionListState extends State<IndoorRoutingSpaceSelectionList> {
  late final FocusNode _focusNode;
  late final TextEditingController _searchController;
  late final ScrollController _listScrollController;
  late IndoorRoutingDataProvider _provider;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _searchController = TextEditingController();
    _listScrollController = ScrollController();
    _searchController.addListener(_handleSearch);
    _provider = context.read<IndoorRoutingDataProvider>();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _searchController
      ..removeListener(_handleSearch)
      ..dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  void _handleSearch() {
    _provider.filterSpaces(_searchController.text.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final List<VenueGeometry>? geometryList = context.select<IndoorRoutingDataProvider, List<VenueGeometry>?>(
      (IndoorRoutingDataProvider p) => p.geometryList,
    );
    final EditingField? editingField = _provider.activeField;

    return Positioned.fill(
      child: Material(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(IndoorMapTokens.size10),
              child: AppSearchField(
                focusNode: _focusNode,
                controller: _searchController,
                hintText: editingField == EditingField.source ? 'Choose starting location' : 'Choose destination',
                onCancel: _provider.closeSpaceSelectionListUI,
                autofocus: true,
              ),
            ),
            Expanded(
              child: Scrollbar(
                controller: _listScrollController,
                thumbVisibility: true,
                interactive: true,
                child: ListView.builder(
                  controller: _listScrollController,
                  itemCount: geometryList?.length ?? 0,
                  itemBuilder: (BuildContext context, int index) {
                    final VenueGeometry? space = geometryList?[index];
                    if (space == null) return const SizedBox.shrink();

                    final String spaceName = geometryDisplayTitle(space);
                    final String? address = geometryDisplayDescription(space);

                    return AppListTileDetailed(
                      title: spaceName,
                      subtitle: address,
                      leadingAccessory: Image.asset(
                        'assets/space_icon.png',
                        width: IndoorMapTokens.size32,
                        height: IndoorMapTokens.size32,
                      ),
                      trailingAccessory: const ImageIcon(
                        AssetImage('assets/north_west_arrow.png'),
                        size: IndoorMapTokens.size20,
                      ),
                      onTap: () => _provider.onSpaceSelectionFromList(space),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
