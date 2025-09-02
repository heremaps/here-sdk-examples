/*
 * Copyright (C) 2023-2025 HERE Europe B.V.
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

class CustomListTile extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  CustomListTile({required this.text, required this.onTap});

  @override
  _CustomListTileState createState() => _CustomListTileState();
}

class _CustomListTileState extends State<CustomListTile> {
  bool _isSelected = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Material(
        elevation: _isSelected ? 8.0 : 2.0,
        borderRadius: BorderRadius.circular(12.0),
        child: InkWell(
          onTap: () {
            setState(() {
              _isSelected = !_isSelected;
            });
          },
          borderRadius: BorderRadius.circular(12.0),
          splashColor: _isSelected ? Colors.blueAccent : Colors.redAccent,
          child: Container(
            padding: EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.0),
              color: _isSelected ? Colors.blue : Colors.white,
            ),
            child: ListTile(
              leading: Icon(Icons.hiking, color: Colors.cyan),
              title: Text(widget.text),
              onTap: () {
                widget.onTap();
              },
            ),
          ),
        ),
      ),
    );
  }
}
