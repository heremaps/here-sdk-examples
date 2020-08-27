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

package com.here.examples.positioning;

import android.os.Bundle;
import android.widget.Button;
import android.widget.TextView;

import com.here.sdk.consent.ConsentEngine;
import com.here.sdk.core.errors.InstantiationErrorException;

import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.widget.Toolbar;

/**
 * Shows what answer the user has given regarding the consent to join the data improvement
 * program, and allows them to change it by showing a consent dialog.
 */
public class ConsentStateActivity extends AppCompatActivity {

    private ConsentEngine consentEngine;
    private TextView consentStateTextView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_consent_state);

        Toolbar myToolbar = (Toolbar) findViewById(R.id.toolbar);
        setSupportActionBar(myToolbar);

        try {
            consentEngine = new ConsentEngine();
        } catch (InstantiationErrorException e) {
            throw new RuntimeException("Initialization of ConsentEngine failed: " + e.getMessage());
        }

        consentStateTextView = findViewById(R.id.status);

        final Button button = findViewById(R.id.button);
        button.setOnClickListener(view -> consentEngine.requestUserConsent());
    }

    @Override
    public void onBackPressed() {
        super.onBackPressed();
    }

    @Override
    public void onResume() {
        super.onResume();
        refreshImprovementProgramStatus();
    }

    private void refreshImprovementProgramStatus() {
        if (consentEngine == null || consentStateTextView == null) {
            return;
        }
        switch(consentEngine.getUserConsentState()) {
            case GRANTED:
                //The user has previously given permission.
                consentStateTextView.setText(R.string.consent_state_granted);
                break;
            case DENIED:
                // The user has previously denied permission.
            case NOT_HANDLED:
                //The user has not been asked for consent.
            case REQUESTING:
                //The dialog is currently being shown to the user.
                consentStateTextView.setText(R.string.consent_state_denied);
                break;
            default:
                throw new RuntimeException("Unknown consent state.");
        }
    }
}
