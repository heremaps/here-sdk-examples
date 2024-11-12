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

import Foundation
import AVFoundation

class AudioSessionManager {
    
    var audioSessionIsActivated: Bool = false
    static let shared = AudioSessionManager()
    private lazy var audioSession = AVAudioSession.sharedInstance()
    
    public func isAudioSessionActivated() -> Bool {
        return audioSessionIsActivated
    }
    
    /// Activates or deactivates the audio session
    public func setAudioSessionState(activated: Bool) {
        audioSessionIsActivated = activated
        activated ? activateAudioSession() : deactivateAudioSession()
    }
    
    /// Checks if any audio is being played
    public func isOtherAudioPlaying() -> Bool{
        return audioSession.isOtherAudioPlaying
    }
    
    private func activateAudioSession() {
        do {
            try? audioSession.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers])
            try audioSession.setActive(true)
        } catch let error as NSError  {
            print("An error has occurred while activating the AVAudioSession. \(error.localizedDescription)")
        }
    }
    
    private func deactivateAudioSession() {
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            if audioSession.category != .playback {
                try audioSession.setCategory(.playback, mode: .voicePrompt, options: .duckOthers)
            }
        } catch let error as NSError  {
            print("An error has occurred while deactivating the AVAudioSession. \(error.localizedDescription)")
        }
    }
}
