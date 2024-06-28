package com.here.spatialaudionavigation;

import android.content.Context;
import android.media.AudioManager;
import android.media.MediaMetadataRetriever;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.speech.tts.TextToSpeech;
import android.speech.tts.UtteranceProgressListener;
import android.util.Log;

import androidx.annotation.NonNull;

import com.here.sdk.navigation.CustomPanningData;
import com.here.sdk.navigation.SpatialAudioCuePanning;
import com.here.sdk.navigation.SpatialTrajectoryData;
import com.here.spatialaudionavigation.defaultexample.DefaultEncoder;
import com.here.time.Duration;

import org.jetbrains.annotations.NotNull;

import java.io.File;
import java.io.IOException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class SpatialAudioExample {

    private final VoiceAssistant voiceAssistant;
    private final String FILE_NAME_PREFIX = "temp_audio_cue";
    private EncoderInterface encoder;
    private boolean isEncoderInitialized = false;
    private final MediaMetadataRetriever mmr = new MediaMetadataRetriever();

    // Avoid IO operations run from main thread.
    private ExecutorService executorPanning;
    private ExecutorService executorSynthesization;
    private ExecutorService executorPlayFile;

    public SpatialAudioExample(VoiceAssistant voiceAssistant) {
        this.voiceAssistant = voiceAssistant;
    }

    public void initSpatialAudioExample() {
        // Initializing encoder.
        if(!isEncoderInitialized){
            encoder = new DefaultEncoder(); // Switch to 'Mach1Encoder()' in order to use Mach1 spatial audio engine.
            isEncoderInitialized = true;
        }
    }

    public void updatePanning(SpatialTrajectoryData spatialTrajectoryData) {
        executorPanning.execute(new Runnable() {
            @Override
            public void run() {
                encoder.setCurrentAzimuthDegrees((float) spatialTrajectoryData.azimuthInDegrees);
                if (spatialTrajectoryData.completedSpatialTrajectory) {
                    executorPanning.shutdown();
                }
            }
        });
    }

    // Synthesise the audio cue triggered by the SDK into an audio file.
    public void synthesizeStringToAudioFile(@NotNull final String audioCue, float initialAzimuthInDegrees, @NonNull SpatialAudioCuePanning spatialAudioCuePanning, Context context) {
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
                    setSpatialUtteranceProgressListener(uriToFile, initialAzimuthInDegrees, spatialAudioCuePanning, context);
                }

            } catch (IOException e) {
                e.printStackTrace();
                executorSynthesization.shutdown();
            }

        });
    }

    // Set utterance listener to call methods when synthesization has finished.
    private void setSpatialUtteranceProgressListener(Uri uriToFile, float initialAzimuthInDegrees, @NonNull SpatialAudioCuePanning spatialAudioCuePanning, Context context) {
        voiceAssistant.getTextToSpeech().setOnUtteranceProgressListener(new UtteranceProgressListener() {
            @Override
            public void onStart(String utteranceId) {
            }

            @Override
            public void onDone(String utteranceId) {
                // Play the audio file.
                playAudioFile(uriToFile, initialAzimuthInDegrees, context);

                // startPanning() can be called with new CustomPanningData if the data provided does not fulfil the expectations. For example,
                // for a more accurate estimation of the audio cue duration we recommend using the duration granted by Android.
                CustomPanningData customPanningData = new CustomPanningData(getFileDuration(uriToFile), null, null);
                spatialAudioCuePanning.startAngularPanning(customPanningData, spatialTrajectoryData -> {
                    Log.d(SpatialAudioCuePanning.class.getSimpleName(), "Next azimuth:" + spatialTrajectoryData.azimuthInDegrees);
                    updatePanning(spatialTrajectoryData);
                });
                executorSynthesization.shutdown();
            }

            @Override
            @SuppressWarnings("deprecation")
            public void onError(String utteranceId) {
                executorSynthesization.shutdown();
            }
        });
    }

    // Plays the synthesized audio file containing the audio cue for the next maneuver.
    private void playAudioFile(Uri uriToFile, float initialAzimuthInDegrees, Context context) {
        Handler mainHandler = new Handler(context.getMainLooper());
        // Set the animation timing to trigger and plays the audio file containing the current audio cue.
        Runnable playAudioFile = new Runnable() {
            @Override
            public void run() {
                // Play audio file.
                encoder.playAudioCue(uriToFile, initialAzimuthInDegrees);
            }
        };
        mainHandler.post(playAudioFile);
    }

    // Get the duration of the audio file.
    private Duration getFileDuration(Uri uriToFile) {
        mmr.setDataSource(String.valueOf(uriToFile));
        String durationStr = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION);
        return Duration.ofMillis(Integer.parseInt(durationStr));
    }

    // Stops playing the current audio cue and shutdown the executors required for spatial audio.
    public void stopSpatialAudio() {
        if (encoder != null)
            encoder.stopPlayingAudioCue(); // Stops current spatial audio cue.
        shutdownExecutors();
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
