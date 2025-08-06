/*
 * Copyright (C) 2020-2025 HERE Europe B.V.
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

package com.here.hikingdiary.backgroundpositioning;

import android.content.Context;
import android.content.SharedPreferences;
import android.webkit.WebResourceRequest;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import androidx.appcompat.app.AlertDialog;

// A class to help with the HERE privacy notice inclusion.
//
// Before HERE Positioning can be used, the user needs to agree to the terms and privacy notice
// and to the Android permissions required by an app to access the device's sensors.
// This helper defines two pages, "applicationTermsPage" which can optionally open "privacyPolicyPage".
// The layout and the texts can be adapted, however, the details on the HERE data collection handling need
// to be accessible. See Developer Guide for more details and alternatives.
//
// Usage example:
// 1. Get the user's agreement once before using the app (see MainActivity class):
// HEREPositioningTermsAndPrivacyHelper privacyHelper = new HEREPositioningTermsAndPrivacyHelper(this);
// privacyHelper.showAppTermsAndPrivacyPolicyDialogIfNeeded(this::handleAndroidPermissions);
// 2. Confirm that the user's agreement was collected (see HEREBackgroundPositioningService class):
// Before starting the LocationEngine call locationEngine.confirmHEREPrivacyNoticeInclusion().
public class HEREPositioningTermsAndPrivacyHelper {

    private static final String PREFERENCES_POLICY_KEY = "PREFERENCES_POLICY_KEY";
    private static final String PREFERENCES_POLICY_VALUE = "PREFERENCES_POLICY_VALUE";

    public interface OnAgreedListener {
        void onAgreed();
    }

    private final Context context;

    public HEREPositioningTermsAndPrivacyHelper(Context context) {
        this.context = context;
    }

    // Check if the user has already agreed once.
    private boolean hasUserAgreedToTermsAndPrivacyNotice() {
        boolean userAgreedDefaultValue = false;
        SharedPreferences prefs = context.getSharedPreferences(PREFERENCES_POLICY_KEY, Context.MODE_PRIVATE);
        return prefs.getBoolean(PREFERENCES_POLICY_VALUE, userAgreedDefaultValue);
    }

    // Persist a flag when the user agreed.
    private void setUserAgreedToTermsAndPrivacyNotice() {
        boolean userAgreed = true;
        SharedPreferences prefs = context.getSharedPreferences(PREFERENCES_POLICY_KEY, Context.MODE_PRIVATE);
        prefs.edit().putBoolean(PREFERENCES_POLICY_VALUE, userAgreed).apply();
    }

    /**
     * Show application service terms and a privacy notice to inform on HERE data collection.
     * Returns false, when the dialog was already shown once (no need to show it again).
     */
    public void showAppTermsAndPrivacyPolicyDialogIfNeeded(OnAgreedListener listener) {
        if (hasUserAgreedToTermsAndPrivacyNotice()) {
            listener.onAgreed();
            return;
        }

        // An example of a screen that can be agreed without looking at the details of
        // the terms and privacy notice. However, the link to the details needs to be
        // accessible for users. When clicking on "myapp://privacy-policy" the text of the
        // privacyPolicyPage (see below) is shown.
        String applicationTermsPage =
                "<!DOCTYPE html>" +
                "<html lang=\"EN-US\">" +
                "<body>" +
                "<p>You need to agree to the Service Terms " +
                "and <a href=myapp://privacy-policy>Privacy Policy</a> to use this app.</p>" +
                "</body>" +
                "</html>";

        // Do not forget to adapt this placeholderText for your app.
        String placeholderText =
                "(In this Privacy Policy example, the following paragraph demonstrates one way to " +
                "inform app users about data collection. All other potential privacy-related aspects " +
                "are intentionally omitted from this example.)";

        // An example of a screen that presents the required legal information on the
        // data collection of the HERE Positioning feature.
        String privacyPolicyPage =
                "<!DOCTYPE html>" +
                "<html lang=\"EN-US\">" +
                "<body style='tab-interval:36.0pt;word-wrap:break-word'>" +
                "        <div>" +
                "        <h1>Your privacy when using this application.</h1>" +
                "        <p>" + placeholderText +
                "        </p>" +
                "        <p>This application uses location services" +
                "        provided by HERE Technologies. To maintain, improve and provide these services," +
                "        HERE Technologies from time to time gathers characteristics information about the" +
                "        near-by network signals. For more information, please see the HERE Privacy Notice" +
                "        at <a href=\"https://legal.here.com/here-network-positioning-via-sdk\">https://legal.here.com/here-network-positioning-via-sdk</a>." +
                "        </p>" +
                "    </div>" +
                "</body>" +
                "</html>";

        WebView webView = new WebView(context);
        webView.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                // Here we define that clicking on the link should open privacyPolicyPage.
                String url = request.getUrl().toString();
                if (url.equals("myapp://privacy-policy")) {
                    view.loadDataWithBaseURL(null, privacyPolicyPage, "text/html", "UTF-8", null);
                    return true;
                }
                return false;
            }
        });

        // The first page that opens is applicationTermsPage, which contains a link to privacyPolicyPage.
        webView.loadDataWithBaseURL(null, applicationTermsPage, "text/html", "UTF-8", null);
        webView.requestLayout();

        AlertDialog.Builder builder = new AlertDialog.Builder(context);
        builder.setView(webView);
        builder.setCancelable(false);
        builder.setPositiveButton("Agree", (dialog, id) -> {
            // We store that the user has agreed to the terms and privacy notice, so that it is
            // shown only once.
            setUserAgreedToTermsAndPrivacyNotice();
            dialog.cancel();
            listener.onAgreed();
        });

        AlertDialog termsAndServicesDialog = builder.create();
        termsAndServicesDialog.show();
    }
}
