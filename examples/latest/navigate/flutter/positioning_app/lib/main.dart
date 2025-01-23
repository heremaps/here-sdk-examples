/*
 * Copyright (C) 2020-2025 HERE Europe B.V.
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
import 'package:here_sdk/consent.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.engine.dart';
import 'package:here_sdk/core.errors.dart';

import 'PositioningExample.dart';

void main() {
  // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
  _initializeHERESDK();

  runApp(
    MaterialApp(
      theme: ThemeData.dark().copyWith(
        // Optional: force dark theme with custom consent dialog colors.
        extensions: <ThemeExtension<dynamic>>[
          const ConsentDialogColors(
            text: Color.fromARGB(255, 0, 0, 0),
            background: Color.fromARGB(255, 255, 255, 255),
            learnMoreLink: Color.fromARGB(255, 0x28, 0x7e, 0xf7),
            acceptButtonCaption: Color.fromARGB(255, 255, 255, 255),
            acceptButtonPrimary: Color.fromARGB(255, 0x80, 0xaa, 0xff),
            acceptButtonSecondary: Color.fromARGB(255, 0x7d, 0xe6, 0xe1),
            rejectButtonCaption: Color.fromARGB(255, 0, 0, 0),
            rejectButtonPrimary: Color.fromARGB(255, 255, 255, 255),
            rejectButtonBorder: Color.fromARGB(0x1f, 0, 0, 0),
          ),
        ],
      ),
      localizationsDelegates: HereSdkConsentLocalizations.localizationsDelegates,
      supportedLocales: HereSdkConsentLocalizations.supportedLocales,
      home: MyApp(),
    ),
  );
}

void _initializeHERESDK() async {
  // Needs to be called before accessing SDKOptions to load necessary libraries.
  SdkContext.init(IsolateOrigin.main);

  // Set your credentials for the HERE SDK.
  String accessKeyId = "YOUR_ACCESS_KEY_ID";
  String accessKeySecret = "YOUR_ACCESS_KEY_SECRET";
  AuthenticationMode authenticationMode = AuthenticationMode.withKeySecret(accessKeyId, accessKeySecret);
  SDKOptions sdkOptions = SDKOptions.withAuthenticationMode(authenticationMode);

  try {
    await SDKNativeEngine.makeSharedInstance(sdkOptions);
  } on InstantiationException {
    throw Exception("Failed to initialize the HERE SDK.");
  }
}

class MyApp extends StatefulWidget {
  @override
  PositioningExample createState() => PositioningExample();
}
