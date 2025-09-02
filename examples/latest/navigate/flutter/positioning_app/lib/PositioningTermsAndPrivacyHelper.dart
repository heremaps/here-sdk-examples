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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// A class to help with the HERE privacy notice inclusion.
//
// Before HERE Positioning can be used on Android devices,
// the user needs to agree to the terms and privacy notice
// and to the Android permissions required by an app to access the device's sensors.
// This helper defines two pages, "applicationTermsPage" which can optionally open "privacyPolicyPage".
// The layout and the texts can be adapted, however, the details on the HERE data collection handling need
// to be accessible. See Developer Guide for more details and alternatives.
//
// Usage example:
// 1. Get the user's agreement once before using the app (see PositioningExample class):
// final termsAndPrivacyHelper = HEREPositioningTermsAndPrivacyHelper(context);
// await termsAndPrivacyHelper.showAppTermsAndPrivacyPolicyDialogIfNeeded();
// ...
// await _handlePermissions();
// 2. Confirm that the user's agreement was collected (see PositioningExample class):
// Before starting the LocationEngine call _locationEngine.confirmHEREPrivacyNoticeInclusion().
class HEREPositioningTermsAndPrivacyHelper {
  static const String _policyKey = 'PREFERENCES_POLICY_KEY';

  final BuildContext context;

  HEREPositioningTermsAndPrivacyHelper(this.context);

  /// Check if the user has already agreed once.
  Future<bool> _hasUserAgreedToTermsAndPrivacyNotice() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_policyKey) ?? false;
  }

  /// Persist a flag when the user agreed.
  Future<void> _setUserAgreedToTermsAndPrivacyNotice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_policyKey, true);
  }

  /// Show application service terms and a privacy notice to inform on HERE data collection.
  /// Returns only when user has agreed or already agreed previously (no need to show it again).
  Future<void> showAppTermsAndPrivacyPolicyDialogIfNeeded() async {
    if (await _hasUserAgreedToTermsAndPrivacyNotice()) {
      return;
    }

    // An example of a screen that can be agreed without looking at the details of
    // the terms and privacy notice. However, the link to the details needs to be
    // accessible for users.

    // An example of a screen that can be agreed without looking at the details of
    // the terms and privacy notice. However, the link to the details needs to be
    // accessible for users. When clicking on applicationTermsPageButtonText the text of the
    // privacyPolicyPage (see below) is shown.
    const String applicationTermsPage = "You need to agree to the Service Terms and Privacy Policy to use this app.";
    const String applicationTermsPageButtonText = "View Privacy Policy";

    // Do not forget to adapt this placeholderText for your app.
    const String placeholderText =
        "(In this Privacy Policy example, the following paragraph demonstrates one way to "
        "inform app users about data collection. All other potential privacy-related aspects "
        "are intentionally omitted from this example.)";

    // An example of a screen that presents the required legal information on the
    // data collection of the HERE Positioning feature.
    const String privacyPolicyPageTitle = "Your privacy when using this application.";
    const String privacyPolicyPage =
        "This application uses location services provided by HERE Technologies"
        "To maintain, improve and provide these services, HERE Technologies from time to time"
        "gathers characteristics information about the near-by network signals."
        "For more information, please see the HERE Privacy Notice at"
        "https://legal.here.com/here-network-positioning-via-sdk.";
    const String privacyURL = "https://legal.here.com/here-network-positioning-via-sdk";
    const String privacyURLButtonText = "View HERE Privacy Notice";

    final completer = Completer<void>();

    bool showingPrivacyPolicePage = false;

    await showDialog(
      context: context,
      // Prevent tap outside to dismiss
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return PopScope(
            // Prevents back button dismissal.
            canPop: false,
            child: AlertDialog(
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The first page that opens is applicationTermsPage, which contains a link to privacyPolicyPage.
                    if (!showingPrivacyPolicePage) ...[
                      Text(applicationTermsPage),
                    ] else ...[
                      const Text(privacyPolicyPageTitle, style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(placeholderText),
                      const SizedBox(height: 12),
                      const Text(privacyPolicyPage),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final url = Uri.parse(privacyURL);
                          if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                            debugPrint('Could not launch \$url');
                          }
                        },
                        child: const Text(
                          privacyURLButtonText,
                          style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                if (!showingPrivacyPolicePage)
                  TextButton(
                    onPressed: () {
                      // Here we define that clicking on the button should open privacyPolicyPage.
                      setState(() => showingPrivacyPolicePage = true);
                    },
                    child: const Text(applicationTermsPageButtonText),
                  ),
                TextButton(
                  onPressed: () async {
                    // We store that the user has agreed to the terms and privacy notice, so that it is
                    // shown only once.
                    await _setUserAgreedToTermsAndPrivacyNotice();
                    Navigator.of(context).pop();
                    completer.complete();
                  },
                  child: const Text('Agree'),
                ),
              ],
            ),
          );
        },
      ),
    );

    return completer.future;
  }
}
