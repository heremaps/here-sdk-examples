package com.here.sdk.examples.spatial_audio_navigation;

import android.media.AudioAttributes;
import android.media.MediaPlayer;
import android.net.Uri;
import android.util.Log;

import java.io.File;
import java.io.IOException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class AudioPlayerManager {
    private MediaPlayer mediaPlayer;
    private ExecutorService executorPlay;

    public AudioPlayerManager() {
    }

    public boolean isPlaying() {
        try {
            return mediaPlayer != null && mediaPlayer.isPlaying();
        } catch (IllegalStateException ie) {
            //no-op.
        }
        return false;
    }

    // Plays the audio file which contains the audio file to be triggered.
    public void play(Uri uriToFile) {
        initExecutorPlay();
        executorPlay.execute(() -> {
            // play the new audio file.
            try {
                mediaPlayer.setDataSource(String.valueOf(uriToFile));
                mediaPlayer.setOnPreparedListener(mp -> {
                    mp.setLooping(false);
                    mp.start();
                });
                mediaPlayer.setOnErrorListener((mp, what, extra) -> {
                    mp.release();
                    executorPlay.shutdown();
                    return true;
                });
                mediaPlayer.setOnCompletionListener(mp -> {
                    File audioFile = new File(uriToFile.getPath());
                    audioFile.deleteOnExit();
                    mp.release();
                    executorPlay.shutdown();
                });

                mediaPlayer.prepareAsync();

            } catch (IOException e) {
                e.printStackTrace();
                executorPlay.shutdown();
            }
        });
    }

    public void initMediaPlayer() {
        // Ensure next audio cue will be triggered in a new MediaPlayer
        mediaPlayer = new MediaPlayer();
        mediaPlayer.setVolume(1, 1);
        mediaPlayer.setAudioAttributes(new AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build());
    }

        // Set the volume of each of MediaPlayer's audio channels
    public void setVolumeMediaPlayer(float leftChannelGains, float rightChannelGains) {
        mediaPlayer.setVolume(leftChannelGains, rightChannelGains);
    }

    // Initializes the executor
    public void initExecutorPlay() {
        if (executorPlay == null || executorPlay.isShutdown()) {
            executorPlay = Executors.newSingleThreadExecutor();
        }
    }

    // Shuts down the executor
    public void shutdownExecutors() {
        if (executorPlay != null && !executorPlay.isShutdown())
            executorPlay.shutdown();
    }

    // Stops the current reproduction.
    public void stopPlaying() {
        if (isPlaying()) {
            Log.d(AudioPlayerManager.class.getSimpleName(), "Stop playing");
            mediaPlayer.stop();
            mediaPlayer.release();
            mediaPlayer = null;
        }
    }

}
