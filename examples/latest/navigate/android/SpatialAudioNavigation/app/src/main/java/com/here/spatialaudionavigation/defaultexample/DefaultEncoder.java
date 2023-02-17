package com.here.spatialaudionavigation.defaultexample;

import android.net.Uri;
import android.util.Log;

import com.here.spatialaudionavigation.AudioPlayerManager;
import com.here.spatialaudionavigation.EncoderInterface;

public class DefaultEncoder implements EncoderInterface {

    private String TAG = "Encoder";
    private AudioPlayerManager audioPlayerManager;

    public DefaultEncoder() {
        audioPlayerManager = new AudioPlayerManager();
    }

    @Override
    // Basic encoder
    // Sets a really simple spatialization by defining the left and right channel volume level based on 'nextAzimuthInDegrees'
    // Differenciates between three audio directions based on the angular value or azimuth
    // < -10 -> Left audio channel set to maximum and no right channel -> Left
    // > 10 -> Right audio channel set to maximum and no left channel -> Right
    // > -10 && < 10 -> Both audio channels to maximum capacity -> Front
    public void setCurrentAzimuthDegrees(float nextAzimuthInDegrees) {
        float leftGains;
        float rightGains;

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
        Log.d(TAG, "New DefaultEncoder gains: (" + leftGains +", " + rightGains +")");

        audioPlayerManager.setVolumeMediaPlayer(leftGains, rightGains);
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

    // Shuts down the executor.
    @Override
    public void shutdownEncoderExecutors() {
        audioPlayerManager.shutdownExecutors();
    }

    @Override
    public boolean isEncoderPlaying() {
        return audioPlayerManager.isPlaying();
    }
}
