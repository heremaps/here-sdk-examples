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

import Foundation
import heresdk

class DefaultEncoder: EncoderInterface {
    init() {
    }
    
    func stopPlayingAudioCue(avAudioPlayerNodeManager: AVAudioPlayerNodeManager) {
        avAudioPlayerNodeManager.stopPlaying()
    }
    
    func playAudioCue(audioCue: String, avAudioPlayerNodeManager: AVAudioPlayerNodeManager, initialAzimuth: Float) {
        // Stops the previous audio cue if is still being played when a new one has been triggered
        avAudioPlayerNodeManager.resetAudio()
        avAudioPlayerNodeManager.configureAudio()
        // It is recommended to set the initial azimuth right after stopping the previous one (if still playing) and playing the current one to ensure that is played from the correct side at the beginning of the audio cue.
        setCurrentAzimuthDegrees(nextAzimuthInDegrees: initialAzimuth, avAudioPlayerNodeManager: avAudioPlayerNodeManager)
        
        avAudioPlayerNodeManager.prepareSpatialAudioCue(audioCue: audioCue)
    }
    
    func setCurrentAzimuthDegrees(nextAzimuthInDegrees: Float, avAudioPlayerNodeManager: AVAudioPlayerNodeManager) {
        let leftGains: Float
        let rightGains: Float

        // Basic Encoder
        // Differenciates between three audio directions based on the angular value or azimuth
        // < -10 -> Left audio channel set to maximum and no right channel -> Left
        // > 10 -> Right audio channel set to maximum and no left channel -> Right
        // > -10 && < 10 -> Both audio channels to maximum capacity -> Front
        if (nextAzimuthInDegrees < -10) { // Left
            leftGains = 1;
            rightGains = 0;
        } else if (nextAzimuthInDegrees >= -10 && nextAzimuthInDegrees <= 10 ) { // Front
            leftGains = 1;
            rightGains = 1;
        } else { // Right
            leftGains = 0;
            rightGains = 1;
        }
        print("New DefaultEncoder gains: (\(leftGains), \(rightGains))")

        avAudioPlayerNodeManager.updateChannelGains(leftChannelGains: leftGains, rightChannelGains: rightGains)
    }
}

