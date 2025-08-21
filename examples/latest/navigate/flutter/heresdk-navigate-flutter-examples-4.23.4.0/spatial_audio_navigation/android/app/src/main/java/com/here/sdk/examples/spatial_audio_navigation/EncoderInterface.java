package com.here.sdk.examples.spatial_audio_navigation;

import android.net.Uri;

public interface EncoderInterface {
    void stopPlayingAudioCue();
    void playAudioCue(Uri uriToFile, float initialAzimuthInDegrees);
    void shutdownEncoderExecutors();
    void setCurrentAzimuthDegrees(float nextAzimuthInDegrees);
    boolean isEncoderPlaying();
}
