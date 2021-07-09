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

// Disabled null safety for this file:
// @dart=2.9
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:here_sdk/core.engine.dart';
import 'package:here_sdk/venue.dart';

class SettingsPage extends StatelessWidget {
  final VenueEngine _engine = VenueEngine.make(null);
  final accessIdController = TextEditingController();
  final accessSecretController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Column(children: [
        Container(
            padding: EdgeInsets.only(left: 8, right: 8),
            child: TextField(
              controller: accessIdController,
              decoration: InputDecoration(
                  border: InputBorder.none, hintText: 'Enter an access ID'),
            )),
        Container(
            padding: EdgeInsets.only(left: 8, right: 8),
            child: TextField(
              controller: accessSecretController,
              decoration: InputDecoration(
                  border: InputBorder.none, hintText: 'Enter an access secret'),
            )),
        FlatButton(
            color: Colors.blue,
            padding: EdgeInsets.only(left: 8, right: 8),
            child: Text(
              'Restart the venue engine',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.normal,
              ),
            ),
            onPressed: () async {
              if (accessIdController.text.isNotEmpty &&
                  accessSecretController.text.isNotEmpty) {
                SDKNativeEngine.sharedInstance.setAccessKey(
                    accessIdController.text, accessSecretController.text);
                _engine.start(null);
              }
            })
      ]),
    );
  }
}
