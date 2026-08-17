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

/// Bottom panel shown when a geometry is tapped, displaying its name, address,
/// and a "Directions" button that opens the routing menu.
/// This is a simplified version of the bottom sheet shown when tapping a geometry
class IndoorRoutingSpacePreview extends StatelessWidget {
  const IndoorRoutingSpacePreview({super.key});

  @override
  Widget build(BuildContext context) {
    final IndoorRoutingDataProvider provider = context.watch<IndoorRoutingDataProvider>();
    final VenueGeometry? destination = provider.selectedDestination;
    if (destination == null) return const SizedBox.shrink();

    final String name = geometryDisplayTitle(destination);
    final String? address = destination.internalAddress?.address;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            IndoorMapTokens.padding20,
            IndoorMapTokens.size10,
            IndoorMapTokens.padding20,
            IndoorMapTokens.padding20,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(IndoorMapTokens.radiusMedium)),
            boxShadow: const <BoxShadow>[BoxShadow(color: Colors.black26, blurRadius: IndoorMapTokens.size10)],
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
              // Name + close button
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: IndoorMapTokens.size15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: IndoorMapTokens.size6),
                        if (address != null && address.isNotEmpty)
                          Text(
                            address,
                            style: TextStyle(fontSize: IndoorMapTokens.size13, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: provider.closeSpacePreviewUI,
                    icon: const Icon(Icons.close, size: IndoorMapTokens.size28),
                    color: Colors.black54,
                  ),
                ],
              ),
              const SizedBox(height: IndoorMapTokens.size15),
              // Directions button
              Row(
                children: <Widget>[
                  Expanded(
                    child: GestureDetector(
                      onTap: provider.onDirectionButtonClickInPreviewMode,
                      child: Container(
                        height: IndoorMapTokens.size40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: <Color>[Color(0xff69AdF8), Color(0xff53D9D0)]),
                          borderRadius: BorderRadius.circular(IndoorMapTokens.size28),
                        ),
                        child: const Center(
                          child: Text(
                            'Directions',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: IndoorMapTokens.size14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
