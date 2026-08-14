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
import 'package:here_sdk/venue.data.dart';

/// Bottom sheet panel that shows source / destination fields, a transport mode
/// bar, an optional routing warning message, and a loading indicator while the
/// route is being calculated.
class IndoorRoutingMainMenu extends StatelessWidget {
  const IndoorRoutingMainMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final IndoorRoutingDataProvider provider = context.watch<IndoorRoutingDataProvider>();

    final VenueGeometry? selectedSource = provider.selectedSource;
    final VenueGeometry? selectedDestination = provider.selectedDestination;

    final String sourceLabel = selectedSource != null ? geometryDisplayTitle(selectedSource) : '';
    final String destinationLabel = selectedDestination != null ? geometryDisplayTitle(selectedDestination) : '';

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(IndoorMapTokens.radiusMedium)),
            boxShadow: const <BoxShadow>[BoxShadow(color: Colors.black26, blurRadius: IndoorMapTokens.size10)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  IndoorMapTokens.padding20,
                  IndoorMapTokens.size10,
                  IndoorMapTokens.padding20,
                  0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Drag handle
                    Container(
                      width: IndoorMapTokens.dragHandleWidth,
                      height: IndoorMapTokens.dragHandleHeight,
                      margin: const EdgeInsets.only(bottom: IndoorMapTokens.size10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(IndoorMapTokens.radiusMedium),
                      ),
                    ),
                    SizedBox(height: IndoorMapTokens.size5),
                    // Source row
                    Row(
                      children: <Widget>[
                        Image.asset(
                          'assets/source_location_main_menu.png',
                          width: IndoorMapTokens.size20,
                          height: IndoorMapTokens.size20,
                        ),
                        const SizedBox(width: IndoorMapTokens.size10),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: provider.onEditSourceInRoutingMenuMode,
                            child: Text(
                              sourceLabel.isNotEmpty ? sourceLabel : 'Choose starting location',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                              style: TextStyle(fontSize: IndoorMapTokens.size13, color: Colors.teal),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: provider.closeMainRoutingMenuUI,
                          behavior: HitTestBehavior.opaque,
                          child: Image.asset(
                            'assets/indoor_close_icon.png',
                            width: 24,
                            height: 24,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: IndoorMapTokens.size10),
                    Row(
                      children: <Widget>[
                        const SizedBox(width: IndoorMapTokens.size25),
                        Expanded(child: Divider(height: 1, thickness: 1, color: Colors.grey.shade300)),
                        const SizedBox(width: IndoorMapTokens.size50),
                      ],
                    ),
                    const SizedBox(height: IndoorMapTokens.size10),
                    // Destination row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Image.asset(
                          'assets/destination_location_main_menu.png',
                          width: IndoorMapTokens.size20,
                          height: IndoorMapTokens.size20,
                        ),
                        const SizedBox(width: IndoorMapTokens.size10),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: provider.onEditDestinationInRoutingMenuMode,
                            child: Text(
                              destinationLabel.isNotEmpty ? destinationLabel : 'Choose destination',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                              style: TextStyle(fontSize: IndoorMapTokens.size13, color: Colors.black87),
                            ),
                          ),
                        ),
                        const SizedBox(width: IndoorMapTokens.size50),
                      ],
                    ),
                    const SizedBox(height: IndoorMapTokens.size10),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
            ],
          ),
        ),
      ),
    );
  }
}
