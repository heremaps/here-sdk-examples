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
import heresdk

public protocol BufferCompletionDelegate: AnyObject {
    func onDone(_ avAudioPlayerNodeManager: AVAudioPlayerNodeManager, bufferLengthIsSeconds: Double)
}

/// This class setups and controlls the AVAudioPalyerNode which enables the buffer methodlogy which synthesises the audio cue 'String' into the next audio message.
public final class AVAudioPlayerNodeManager: NSObject{
    private lazy var avSpeechSynthesizer = AVSpeechSynthesizer()
    private lazy var voiceAssistant: VoiceAssistant = VoiceAssistant()
    
    private lazy var engine: AVAudioEngine = AVAudioEngine()
    private lazy var playerNode: AVAudioPlayerNode = AVAudioPlayerNode()
    private let SAMPLE_RATE: Double = 22050
    private let FRAME_CAPACITY: AVAudioFrameCount = 4410
    private let monoConverter: AVAudioConverter
    private let monoOutputFormat : AVAudioFormat
    private var locale = Locale(identifier: "en-US")
    private var bufferList = [AVAudioPCMBuffer]()
    private let preferredAudioFormat: AVAudioCommonFormat
    
    // Notifies when the buffer has been completely buffered and it is ready to be played
    public var bufferCompletionDelegate: BufferCompletionDelegate?
    
    fileprivate let cd = AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: kAudioUnitSubType_DynamicsProcessor,
        componentManufacturer: kAudioUnitManufacturer_Apple,
        componentFlags: 0,
        componentFlagsMask: 0)
    
    private enum channels: AVAudioChannelCount {
        case stereo = 2
        case mono = 1
    }
        
    private let speechRate: Float = 0.5
    private let speechPitch: Float = 1.0
    
    func isPlaying() -> Bool {
        playerNode.isPlaying
    }
    
    init?(_: Void) {
        /// Since iOS 17 AVAudioPCMBuffer supports only the Float32 format.
        if #available(iOS 17.0, *) {
            preferredAudioFormat = AVAudioCommonFormat.pcmFormatFloat32
        } else {
            preferredAudioFormat = AVAudioCommonFormat.pcmFormatInt16
        }

        // init Mono Converter and outputFormat
        guard let fromAudioFormat = AVAudioFormat(commonFormat: preferredAudioFormat, sampleRate: SAMPLE_RATE, channels: channels.mono.rawValue, interleaved: true),
            let toAudioFormat = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatFloat32, sampleRate: SAMPLE_RATE, channels: channels.mono.rawValue, interleaved: false),
            let monoConverter = AVAudioConverter(from: fromAudioFormat, to: toAudioFormat) else {
            print("Error while initializing AVAudioPlayerNodeManager.m_fromAudioFormat")

            return nil
        }
        self.monoConverter = monoConverter

        guard let monoOutputFormat = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatFloat32, sampleRate: SAMPLE_RATE, channels: channels.mono.rawValue, interleaved: false) else {
            print("Error while initializing AVAudioPlayerNodeManager.s_outputFormat")
            return nil
        }
        self.monoOutputFormat = monoOutputFormat
                
        super.init()
        
        avSpeechSynthesizer.delegate = self
    }
    
    public func stopPlaying() {
        avSpeechSynthesizer.stopSpeaking(at: .immediate)
        playerNode.stop()
    }
    
    /// Sets the locale language
    public func setAvSpeechSynthesizerLocale(locale: Locale) {
        self.locale = locale
    }
    
    /// Set all the requirements for spatialising the audio cue
    ///
    /// - Parameter audioCue:  String containing the audio cue to be spatialised
    public func prepareSpatialAudioCue(audioCue: String) {
        // Set voice message
        let utterance = AVSpeechUtterance(string: audioCue)
        utterance.pitchMultiplier = speechPitch
        utterance.rate = speechRate // Speech rate is double in order to calculate correctly the
        utterance.voice = AVSpeechSynthesisVoice(language: locale.languageCode)

        // Write the new voice message in the audio file
        if #available(iOS 13.0, *) {
            self.avSpeechSynthesizer.write(utterance) {[weak self] buffer in
                guard let self = self else {
                    return
                }
                guard let pcmBuffer = buffer as? AVAudioPCMBuffer, pcmBuffer.frameLength > 0 else {
                    print("Finished playing or empty buffer")
                    return
                }
                
                if let buffer = try? self.resampleMonoBuffer(pcmBuffer) {
                    self.bufferList.append(buffer)
                }
            }
        } else {
            // Fallback on earlier version. 'tts.speak' would be an example (classic mono audio).
        }
    }
    
    // Set the gains on each channel of the player
    public func updateChannelGains(leftChannelGains: Float, rightChannelGains: Float){
        // Following Apple documentation, the default panning value is 0.0, and the range of valid values is -1.0 to 1.0.
        // Having set the values of the left and right channel from 0 (muted) to 1 (full volume):
        // Front: Both channels are fully operating: (1 - 1) = 0 --> Front
        // Left: Only left channel is operating: (0 - 1) = -1 --> Left
        // Right: Only right channel is operating: (1 - 0) = 1 --> Right
        // If left and right channels are working with medium gains, then the operation will show the relation between them.
        playerNode.pan = rightChannelGains - leftChannelGains
    }
    
    /// Reset variables
    public func resetAudio(){
        playerNode.stop()
        engine.stop()
        monoConverter.reset()
        bufferList.removeAll()
    }
    
    /// Configures the audio so it works in a vehicles
    public func configureAudio() {
        // Set Dynamic Processor
        let internalEffect = AVAudioUnitEffect(audioComponentDescription: cd)
        engine.attach(playerNode)
        engine.mainMixerNode.inputFormat(forBus: 0)
        
        // Setting output format and number of channels
        let outputFormat: AVAudioFormat = monoOutputFormat
        
        engine.attach(internalEffect)
        engine.connect(playerNode, to: internalEffect, format: outputFormat)
        engine.connect(internalEffect,
                            to: engine.mainMixerNode,
                            format: AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatFloat32, sampleRate: self.SAMPLE_RATE, channels: channels.mono.rawValue, interleaved: false))
        engine.prepare()
    }
    
    func resampleMonoBuffer(_ buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer? {
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatFloat32, sampleRate: self.SAMPLE_RATE, channels: channels.mono.rawValue, interleaved: false)!, frameCapacity: buffer.frameLength) else {
            return nil
        }
        try self.monoConverter.convert(to: convertedBuffer, from: buffer)
        defer {
            self.monoConverter.reset()
        }
        return convertedBuffer
    }
    
    
    /// Plays the audio cue
    func play() {
        playerNode.volume = 1.0
        playerNode.play()
    }
    
    func startAudioEngineAndPlay() {
        // Start audio engine
        do {
            try engine.start()
            play()
        } catch let error {
            AudioSessionManager.shared.setAudioSessionState(activated: false)
            print("An error has occurred while starting the engine. \(error.localizedDescription)")
        }
    }
    
    // Calculates the time required to play the audio cue
    func getBufferLengthInMs(buffer: AVAudioPCMBuffer) -> TimeInterval {
      let framecount = Double(buffer.frameLength)
      let samplerate = buffer.format.sampleRate
        return TimeInterval(framecount / samplerate)
    }
}

extension AVAudioPlayerNodeManager: AVSpeechSynthesizerDelegate {
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("speechSynthesizer didFinish")

        // Audio cue buffer has been completely synthesized
        if !bufferList.isEmpty, let buffer = AVAudioPCMBuffer(concatenating: bufferList) {
            playerNode.stop()
            playerNode.scheduleBuffer(buffer)
            startAudioEngineAndPlay()
            
            bufferCompletionDelegate?.onDone(self, bufferLengthIsSeconds: getBufferLengthInMs(buffer: buffer))
        }
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("speechSynthesizer didStart")
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        print("speechSynthesizer didPause")
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        print("speechSynthesizer didContinue")
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("speechSynthesizer didCancel")
        playerNode.stop()
        bufferList.removeAll()
        AudioSessionManager.shared.setAudioSessionState(activated: false)
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        
    }
    
}

extension AVAudioPCMBuffer {
    private func append(_ buffer: AVAudioPCMBuffer) {
        append(buffer, startingFrame: 0, frameCount: buffer.frameLength)
    }

    private func append(_ buffer: AVAudioPCMBuffer, startingFrame: AVAudioFramePosition, frameCount: AVAudioFrameCount) {
        guard let src = buffer.floatChannelData, let dst = floatChannelData else {
            return
        }
        precondition(format == buffer.format, "Format mismatch")
        precondition(startingFrame + AVAudioFramePosition(frameCount) <= AVAudioFramePosition(buffer.frameLength), "Insufficient audio in buffer")
        precondition(frameLength + frameCount <= frameCapacity, "Insufficient space in buffer")

        memcpy(dst.pointee.advanced(by: stride * Int(frameLength)),
               src.pointee.advanced(by: stride * Int(startingFrame)),
               Int(frameCount) * stride * MemoryLayout<Float>.size)
        frameLength += frameCount
    }

    convenience init?(concatenating buffers: [AVAudioPCMBuffer]) {
        precondition(buffers.count > 0)
        let totalFrames = buffers.reduce(0, { $0 + $1.frameLength })
        self.init(pcmFormat: buffers[0].format, frameCapacity: totalFrames)
        buffers.forEach { append($0) }
    }
}

