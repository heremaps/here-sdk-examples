/**
package com.here.spatialaudionavigation.mach1example;

import static com.mach1.spatiallibs.Mach1EncodePannerMode.Mach1EncodePannerModeIsotropicEqualPower;

import android.net.Uri;
import android.util.Log;

import com.here.spatialaudionavigation.AudioPlayerManager;
import com.here.spatialaudionavigation.EncoderInterface;
import com.mach1.spatiallibs.Mach1Decode;
import com.mach1.spatiallibs.Mach1DecodeAlgoType;
import com.mach1.spatiallibs.Mach1Encode;
import com.mach1.spatiallibs.Mach1EncodeInputModeType;
import com.mach1.spatiallibs.Mach1EncodeOutputModeType;

public class Mach1Encoder implements EncoderInterface {
    private String TAG = "Encoder";

    // Mach1 example
    private Mach1Encode m1Encode;
    // Yaw, pitch and roll will remain static on this version of the spatialization. These coordinates set the direction of the listener
    private final float yaw = 0; // Initial value.
    private final float pitch = 0; // Initial value.
    private final float roll = 0; // Initial value.
    private Mach1Decode m1Decode;
    private AudioPlayerManager audioPlayerManager;

    public Mach1Encoder() {
        audioPlayerManager = new AudioPlayerManager();
        initMach1Decoder();
        m1Encode = new Mach1Encode();
    }

    // Plays the audio cue.
    @Override
    public void playAudioCue(Uri uriToFile, float initialAzimuthInDegrees) {
        // Stops the previous audio cue if is still being played when a new one has been triggered
        audioPlayerManager.stopPlaying();
        audioPlayerManager.initMediaPlayer();
        // It is recommended to set the initial azimuth right after stopping the previous one (if still playing) and playing the current one to ensure that is played from the correct side at the beginning of the audio cue.
        setCurrentAzimuthDegrees(initialAzimuthInDegrees);
        audioPlayerManager.play(uriToFile);
    }

    // Stops the current audio cue when playing.
    @Override
    public void stopPlayingAudioCue() {
        audioPlayerManager.stopPlaying();
    }

    @Override
    public boolean isEncoderPlaying() {
        return audioPlayerManager.isPlaying();
    }

    // Sets the value of azimuth.
    @Override
    public void setCurrentAzimuthDegrees(float nextAzimuthInDegrees) {
        // Mach1Decode API requires use of `beginBuffer()` and `endBuffer()`
        // This design allows customization of the frequency of calls to update the orientation.
        // Updating the Mach1Decode coeffs for next loop's orientation.
        m1Decode.beginBuffer();

        float[] decodeArray = new float[18];
        // In this example, YAW, PITCH AND ROLL remains static, but it could be used for head tracking.
        m1Decode.decode(yaw, pitch, roll, decodeArray, 0, 0);
        m1Decode.endBuffer();

        // Updates the properties of Mach1 Encoder.
        m1Encode.setAzimuthDegrees(nextAzimuthInDegrees);
        m1Encode.setDiverge(0.8f);
        m1Encode.setElevation(0f);
        m1Encode.setIsotropicEncode(true);
        m1Encode.setInputMode(Mach1EncodeInputModeType.Mach1EncodeInputModeMono);
        m1Encode.setPannerMode(Mach1EncodePannerModeIsotropicEqualPower);
        m1Encode.setOutputMode(Mach1EncodeOutputModeType.Mach1EncodeOutputModeM1Horizon); /// Note: Using Mach1Horizon for Yaw only processing.
        m1Encode.setAutoOrbit(false); // When true `stereoRotate` will be automatically calculated to rotate stereo points around origin.
        m1Encode.generatePointResults();

        //Use each coeff to decode multichannel Mach1 Spatial mix.
        // Mach1 calculates specific gains for the left and right channel based on the angular values or azimuth
        float[] gains = m1Encode.getResultingCoeffsDecoded(Mach1DecodeAlgoType.Mach1DecodeAlgoHorizon, decodeArray);

        Log.d(TAG, "New Mach1Encoder gains: (" + gains[0] +", " + gains[1] +")");

        audioPlayerManager.setVolumeMediaPlayer(gains[0], gains[1]);
    }

    @Override
    public void shutdownEncoderExecutors() {
        audioPlayerManager.shutdownExecutors();
    }

    private void initMach1Decoder() {
        m1Decode = new Mach1Decode();
        // Mach1 Decode Setup.
        // Setup the correct angle convention for orientation Euler input angles.
        // m1Decode.setPlatformType(Mach1PlatformType.Mach1PlatformAndroid);
        // Setup the expected spatial audio mix format for decoding.
        m1Decode.setDecodeAlgoType(Mach1DecodeAlgoType.Mach1DecodeAlgoHorizon);
        //Setup for the safety filter speed:
        //1.0 = no filter | 0.1 = slow filter.
        m1Decode.setFilterSpeed(0.95f);
    }
}
**/