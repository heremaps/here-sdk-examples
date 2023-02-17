package com.here.spatialaudionavigation;

import android.net.Uri;

public interface EncoderInterface {
    void stopPlayingAudioCue();
    void playAudioCue(Uri uriToFile, float initialAzimuthInDegrees);
    void shutdownEncoderExecutors();
    void setCurrentAzimuthDegrees(float nextAzimuthInDegrees);
    boolean isEncoderPlaying();
}
