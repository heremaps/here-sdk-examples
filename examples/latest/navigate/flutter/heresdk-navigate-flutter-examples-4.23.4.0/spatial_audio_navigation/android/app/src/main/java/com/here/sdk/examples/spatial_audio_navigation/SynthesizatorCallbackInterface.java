package com.here.sdk.examples.spatial_audio_navigation;

public interface SynthesizatorCallbackInterface {
    void onDone(SpatialAudioHandler audioMapper, int audioCueLength);

    void onStart(SpatialAudioHandler audioMapper);

    void onError(SpatialAudioHandler audioMapper);
}
