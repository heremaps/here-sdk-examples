/*
 * Copyright (C) 2023 HERE Europe B.V.
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

// A helper class to show selectable entries.
// Entries can be deleted by swiping an entry to the left.
import 'package:flutter/material.dart';
import 'CustomListTile.dart';

class MenuScreen extends StatefulWidget {
  final List<String> entryKeys;
  final List<String> entryTexts;
  final ValueChanged<int> onSelected;
  final ValueChanged<int> onDeleted;

  MenuScreen({
    required this.entryKeys,
    required this.entryTexts,
    required this.onSelected,
    required this.onDeleted,
  });

  @override
  _MenuScreenState createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('HikingDiary - Past Hikes')),
      body: ListView.builder(
        itemCount: widget.entryKeys.length,
        itemBuilder: (context, index) {
          return Dismissible(
            key: Key(widget.entryKeys[index]),
            background: ColoredBox(
              child: Container(),
              color: Colors.pink,
            ),
            direction: DismissDirection.endToStart,
            onDismissed: (direction) {
              widget.onDeleted(index);
              setState(() {
                widget.entryKeys.removeAt(index);
                widget.entryTexts.removeAt(index);
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Hike deleted'),
                  backgroundColor: Colors.pink,
                ),
              );
            },
            child: CustomListTile(
              text: widget.entryTexts[index],
              onTap: () {
                widget.onSelected(index);
              },
            ),
          );
        },
      ),
    );
  }
}
