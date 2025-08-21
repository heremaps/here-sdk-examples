/*
 * Copyright (C) 2019-2025 HERE Europe B.V.
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

import heresdk
import AVFoundation
import Foundation

class SpatialAudioExample {
    private let voiceAssistant: VoiceAssistant
    private var encoder: EncoderInterface?
    private var navigating: Bool = false

    init() {
        // A helper class for TTS.
        voiceAssistant = VoiceAssistant()
        encoder = DefaultEncoder() // Switch to Mach1Encoder in order to use Mach1 spatial audio guidance
    }
    
    public func setNavigating() {
        navigating = true
    }
    
    public func isNavigating() -> Bool {
        return navigating
    }
    
    public func playSpatialAudioCue(audioCue: String, initialAzimuthInDegrees: Float, audioCuePanning: SpatialAudioCuePanning, azimuthCallback : @escaping SpatialAudioCuePanning.onSpatialAzimuthStarterHandler){
        encoder!.playAudioCue(audioCue: audioCue, initialAzimuthInDegrees: initialAzimuthInDegrees, audioCuePanning: audioCuePanning,azimuthCallback: azimuthCallback)
    }
    
    public func updatePanning(azimuthInDegrees: Float) {
        encoder!.setCurrentAzimuthDegrees(nextAzimuthInDegrees: azimuthInDegrees)
    }
    
    public func setupVoiceGuidance(visualNavigator: VisualNavigator) {
        var maneuverNotificationOptions = ManeuverNotificationOptions()
        let ttsLanguageCode = getLanguageCodeForDevice(supportedVoiceSkins: VisualNavigator.availableLanguagesForManeuverNotifications())
        // Set the language in which the notifications will be generated.
        maneuverNotificationOptions.language = ttsLanguageCode
        // Set the measurement system used for distances.
        maneuverNotificationOptions.unitSystem = UnitSystem.metric
        visualNavigator.maneuverNotificationOptions = maneuverNotificationOptions
        print("LanguageCode for maneuver notifications: \(ttsLanguageCode).")
        
        // Set language to our TextToSpeech engine.
        let locale = LanguageCodeConverter.getLocale(languageCode: ttsLanguageCode)
        encoder?.setLocaleLanguage(locale: locale)
        
        if voiceAssistant.setLanguage(locale: locale) {
            print("TextToSpeech engine uses this language: \(locale)")
        } else {
            print("TextToSpeech engine does not support this language: \(locale)")
        }
    }
    
    /// Get the language preferrably used on this device.
    private func getLanguageCodeForDevice(supportedVoiceSkins: [heresdk.LanguageCode]) -> LanguageCode {
        
        // 1. Determine if preferred device language is supported by our TextToSpeech engine.
        let identifierForCurrenDevice = Locale.preferredLanguages.first!
        var localeForCurrenDevice = Locale(identifier: identifierForCurrenDevice)
        if !voiceAssistant.isLanguageAvailable(identifier: identifierForCurrenDevice) {
            print("TextToSpeech engine does not support: \(identifierForCurrenDevice), falling back to en-US.")
            localeForCurrenDevice = Locale(identifier: "en-US")
        }
        
        // 2. Determine supported voice skins from HERE SDK.
        var languageCodeForCurrenDevice = LanguageCodeConverter.getLanguageCode(locale: localeForCurrenDevice)
        if !supportedVoiceSkins.contains(languageCodeForCurrenDevice) {
            print("No voice skins available for \(languageCodeForCurrenDevice), falling back to enUs.")
            languageCodeForCurrenDevice = LanguageCode.enUs
        }
        
        return languageCodeForCurrenDevice
    }
    
    public func stopNavigation() {
        if(navigating){
            encoder?.stopPlayingAudioCue()
            navigating = false
        }
    }
    
}
