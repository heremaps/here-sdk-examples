/*
 * Copyright (C) 2019-2024 HERE Europe B.V.
 *
 * Licensed under the Apache License, Version 2.0 (the "License")
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

// A helper class to define a menu item.
class MenuSectionItem {
  const MenuSectionItem(this.title, this.onSelect);
  final String title;
  final VoidCallback onSelect;
}

// A helper class to build menu entries.
class MenuSectionExpansionTile extends StatelessWidget {
  const MenuSectionExpansionTile(this.title, this.items);

  final String title;
  final List<MenuSectionItem> items;

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];

    items.forEach((MenuSectionItem item) {
      ListTile tile = ListTile(
        title: Text('${item.title}', overflow: TextOverflow.ellipsis),
        onTap: () {
          item.onSelect();
          Navigator.pop(context);
        },
      );
      children.add(tile);
    });

    return ExpansionTile(
      title: Text(title),
      children: children,
      initiallyExpanded: true,
    );
  }
}
