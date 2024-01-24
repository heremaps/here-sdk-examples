/*
 * Copyright (C) 2019-2024 HERE Europe B.V.
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

package com.here.sdk.examples.spatial_audio_navigation;

import static android.speech.tts.TextToSpeech.LANG_AVAILABLE;

import android.content.Context;
import android.os.Bundle;
import android.speech.tts.TextToSpeech;
import android.util.Log;

import java.util.Locale;

// A simple class that uses Android's TextToSpeech engine to speak texts.
public class VoiceAssistant {

    private static final String TAG = VoiceAssistant.class.getName();

    public TextToSpeech getTextToSpeech() {
        return textToSpeech;
    }

    private final TextToSpeech textToSpeech;
    private String utteranceId;
    private int messageId;

    public VoiceAssistant(Context context) {
        textToSpeech = new TextToSpeech(context.getApplicationContext(), status -> {
            if (status == TextToSpeech.ERROR) {
                Log.d(TAG, ("ERROR: Initialization of Android's TextToSpeech failed."));
            }
        });
    }

    public boolean isLanguageAvailable(Locale locale) {
        return textToSpeech.isLanguageAvailable(locale) == LANG_AVAILABLE;
    }

    public boolean setLanguage(Locale locale) {
        boolean isLanguageSet = textToSpeech.setLanguage(locale) == LANG_AVAILABLE;
        return isLanguageSet;
    }

    public void speak(String speechMessage) {
        Log.d(TAG, "Voice message: " + speechMessage);

        // No engine specific params used for this example.
        Bundle engineParams = null;
        utteranceId = TAG + messageId++;

        // QUEUE_FLUSH interrupts already speaking messages.
        int error = textToSpeech.speak(speechMessage, TextToSpeech.QUEUE_FLUSH, engineParams, utteranceId);
        if (error != -1) {
            Log.e(TAG, "Error when speaking using Android's TextToSpeech: " + error);
        }
    }
}
