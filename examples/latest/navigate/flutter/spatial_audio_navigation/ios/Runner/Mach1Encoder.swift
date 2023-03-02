/*
 * Copyright (C) 2019-2023 HERE Europe B.V.
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

/*
import Foundation
import Mach1SpatialKit
import heresdk


/// This class makes usage of Mach1 spatial audio engine ir order to create a much more sofisticated spatial audio example.
/// Some links which might be highly interested are:
/// https://www.mach1.tech/
/// https://www.mach1.tech/developers
class Mach1Encoder: EncoderInterface {
    private lazy var m1Encode : Mach1Encode = Mach1Encode()
    private lazy var m1Decode : Mach1Decode = Mach1Decode()

    // Yaw, pitch and roll will remain static on this version of the spatialisation. These coordinates set the direction of the decoder
    private let yaw : Float = 0;
    private let pitch : Float = 0;
    private let roll : Float = 0;

    init() {
        initDecoder()
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
        // Mach1Decode API requires use of `beginBuffer()` and `endBuffer()`
        // This design allows customization of the frequency of calls to update the orientatio
        m1Decode.beginBuffer()

        let decoded: [Float] = m1Decode.decode(Yaw: yaw, Pitch: pitch, Roll: roll)
        m1Decode.endBuffer();
        updateEncoder(decodeArray: decoded, decodeType: Mach1DecodeAlgoHorizon, azimuthInDegress: nextAzimuthInDegrees, avAudioPlayerNodeManager: avAudioPlayerNodeManager) /// Note: Using Mach1Horizon for Yaw only processing
    }

    /// Updates the properties of the encoder
    /// - Parameter decodeArray:
    /// - Parameter decodeType:
    func updateEncoder(decodeArray: [Float], decodeType: Mach1DecodeAlgoType, azimuthInDegress: Float, avAudioPlayerNodeManager: AVAudioPlayerNodeManager) {
        m1Encode.setAzimuthDegrees(azimuthDegrees: azimuthInDegress);
        print ("setAzimuthDegrees = \(azimuthInDegress)")
        m1Encode.setDiverge(diverge: 0.8);
        m1Encode.setElevation(elevationFromMinus1to1: 0);
        m1Encode.setAutoOrbit(setAutoOrbit: true)
        m1Encode.setIsotropicEncode(setIsotropicEncode: true)
        m1Encode.setInputMode(inputMode: Mach1EncodeInputModeMono)
        m1Encode.setPannerMode(pannerMode: Mach1EncodePannerModeIsotropicEqualPower)
        m1Encode.setOutputMode(outputMode: Mach1EncodeOutputModeM1Horizon) // Note: Using Mach1Horizon for Yaw only processing
        m1Encode.generatePointResults()

        // Use each coeff to decode multichannel Mach1 Spatial mix
        // Mach1 calculates specific gains for the left and right channel based on the angular values or azimuth
        let gains : [Float] = m1Encode.getResultingCoeffsDecoded(decodeType: decodeType, decodeResult: decodeArray)

        avAudioPlayerNodeManager.updateChannelGains(leftChannelGains: gains[0], rightChannelGains: gains[1])
    }

    private func initDecoder() {
        //Mach1 Decode Setup
        m1Decode.setPlatformType(type: Mach1PlatformiOS)
        //Setup the expected spatial audio mix format for decoding
        m1Decode.setDecodeAlgoType(newAlgorithmType: Mach1DecodeAlgoHorizon);  /// Note: Using Mach1Horizon for Yaw only processing
        //Setup for the safety filter speed:
        //1.0 = no filter | 0.1 = slow filter
        m1Decode.setFilterSpeed(filterSpeed: 0.95)
    }
}
*/
