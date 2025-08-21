package com.here.sdk.examples.spatial_audio_navigation;

import android.content.Context;
import android.media.AudioManager;
import android.media.MediaMetadataRetriever;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.speech.tts.TextToSpeech;
import android.speech.tts.UtteranceProgressListener;

import com.here.sdk.examples.spatial_audio_navigation.defaultexample.DefaultEncoder;

import org.jetbrains.annotations.NotNull;

import java.io.File;
import java.io.IOException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class SpatialAudioHandler {
    private VoiceAssistant voiceAssistant;
    static final String FILE_NAME_PREFIX = "temp_audio_cue";
    private EncoderInterface encoder;
    private boolean isEncoderInitialized = false;
    private final MediaMetadataRetriever mmr = new MediaMetadataRetriever();

    // Avoid IO operations run from main thread.
    private ExecutorService executorPanning;
    private ExecutorService executorSynthesization;
    private ExecutorService executorPlayFile;

    private Context context;
    private SynthesizatorCallbackInterface synthesizatorCallbackInterface;

    public SpatialAudioHandler(Context context) {
        this.context = context;
        initSpatialAudioExample();
    }

    public void setListener(SynthesizatorCallbackInterface synthesizatorCallbackInterface) {
        this.synthesizatorCallbackInterface = synthesizatorCallbackInterface;
    }


    public void initSpatialAudioExample() {
        // A helper class for TTS.
        if (voiceAssistant == null)
            voiceAssistant = new VoiceAssistant(context);

        // Initializing encoder.
        if(!isEncoderInitialized){
            encoder = new DefaultEncoder(); // Switch to 'Mach1Encoder()' in order to use Mach1 spatial audio engine.
            isEncoderInitialized = true;
        }
    }

    public void updatePanning(float azimuthInDegrees, boolean completedSpatialTrajectory) {
        executorPanning.execute(new Runnable() {
            @Override
            public void run() {
                encoder.setCurrentAzimuthDegrees(azimuthInDegrees);
                if (completedSpatialTrajectory) {
                    executorPanning.shutdown();
                }
            }
        });
    }

    public boolean isEncoderPlaying() {
        return encoder.isEncoderPlaying();
    }

    // Synthesise the audio cue triggered by the SDK into an audio file.
    public void playSpatialAudioCue(@NotNull final String audioCue, float initialAzimuthInDegrees) {
        initSpatialAudioExecutors();

        executorSynthesization.execute(() -> {
            final File outputDir = context.getCacheDir();
            try {
                File outputFile = File.createTempFile(FILE_NAME_PREFIX, ".mp3", outputDir);

                if (outputFile.exists()) {
                    // Set the path to the audio file to be played.
                    final Uri uriToFile = Uri.parse(outputFile.getAbsolutePath());
                    Bundle bundle = new Bundle();
                    bundle.putInt(TextToSpeech.Engine.KEY_PARAM_STREAM, AudioManager.STREAM_MUSIC);
                    bundle.putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, 1.0f); // default

                    // Synthesize the audio cue (string) into an audio file.
                    voiceAssistant.getTextToSpeech().synthesizeToFile(audioCue, bundle, outputFile, outputFile.getName());
                    setSpatialUtteranceProgressListener(uriToFile, initialAzimuthInDegrees);
                }

            } catch (IOException e) {
                e.printStackTrace();
                executorSynthesization.shutdown();
            }

        });
    }

    // Set utterance listener to call methods when synthesization has finished.
    private void setSpatialUtteranceProgressListener(Uri uriToFile, float initialAzimuthInDegrees) {
        voiceAssistant.getTextToSpeech().setOnUtteranceProgressListener(new UtteranceProgressListener() {
            @Override
            public void onStart(String utteranceId) {
                if (synthesizatorCallbackInterface != null) {
                    synthesizatorCallbackInterface.onStart(SpatialAudioHandler.this);
                }
            }

            @Override
            public void onDone(String utteranceId) {
                // Play the audio file.
                playAudioFile(uriToFile, initialAzimuthInDegrees);

                // startPanning() can be called with new CustomPanningData if the data provided does not fulfil the expectations. For example,
                // for a more accurate estimation of the audio cue duration we recommend using the duration granted by Android.
                executorSynthesization.shutdown();

                if (synthesizatorCallbackInterface != null) {
                    synthesizatorCallbackInterface.onDone(SpatialAudioHandler.this, getFileDuration(uriToFile));
                }
            }

            @Override
            public void onError(String utteranceId) {
                executorSynthesization.shutdown();

                if (synthesizatorCallbackInterface != null) {
                    synthesizatorCallbackInterface.onError(SpatialAudioHandler.this);
                }
            }
        });
    }

    // Plays the synthesized audio file containing the audio cue for the next maneuver.
    private void playAudioFile(Uri uriToFile, float initialAzimuthInDegrees) {
        Handler mainHandler = new Handler(context.getMainLooper());
        // Set the animation timing to trigger and plays the audio file containing the current audio cue.
        Runnable playAudioFile = () -> {
            // Play audio file.
            encoder.playAudioCue(uriToFile, initialAzimuthInDegrees);
        };
        mainHandler.post(playAudioFile);
    }

    // Get the duration of the audio file.
    private int getFileDuration(Uri uriToFile) {
        mmr.setDataSource(String.valueOf(uriToFile));
        String durationStr = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION);
        return Integer.parseInt(durationStr);
    }

    // Initiates a new thread when required audio synthesization.
    public void initSpatialAudioExecutors() {
        if (executorSynthesization == null || executorSynthesization.isShutdown())
            executorSynthesization = Executors.newSingleThreadExecutor();
        if (executorPanning == null || executorPanning.isShutdown())
            executorPanning = Executors.newSingleThreadExecutor();
        if (executorPlayFile == null || executorPlayFile.isShutdown())
            executorPlayFile = Executors.newSingleThreadExecutor();
    }

    // Shuts down the initialized executors.
    public void shutdownExecutors() {
        if (executorSynthesization != null && !executorSynthesization.isShutdown())
            executorSynthesization.shutdown();
        if (executorPlayFile != null && !executorPlayFile.isShutdown())
            executorPlayFile.shutdown();
        if (encoder != null)
            encoder.shutdownEncoderExecutors();
    }
}
