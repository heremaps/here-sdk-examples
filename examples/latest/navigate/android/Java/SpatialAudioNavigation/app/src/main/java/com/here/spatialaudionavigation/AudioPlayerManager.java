package com.here.spatialaudionavigation;

import android.media.AudioAttributes;
import android.media.MediaPlayer;
import android.net.Uri;
import android.util.Log;

import java.io.File;
import java.io.IOException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class AudioPlayerManager {
    private static final String TAG = "AudioPlayerManager";
    private MediaPlayer mediaPlayer;
    private ExecutorService executorPlay;
    private volatile boolean isShutdown = false;

    public AudioPlayerManager() {
    }

    public boolean isPlaying() {
        try {
            return mediaPlayer != null && mediaPlayer.isPlaying();
        } catch (IllegalStateException ie) {
            Log.d(TAG, "MediaPlayer not in valid state for isPlaying check");
        }
        return false;
    }

    public void initMediaPlayer() {
        // Ensure next audio cue will be triggered in a new MediaPlayer
        if (isShutdown) {
            Log.d(TAG, "Cannot init MediaPlayer: AudioPlayerManager is shut down");
            return;
        }
        mediaPlayer = new MediaPlayer();
        mediaPlayer.setVolume(1, 1);
        mediaPlayer.setAudioAttributes(new AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build());
    }

    // Plays the audio file which contains the audio file to be triggered.
    public void play(Uri uriToFile) {
        if (isShutdown) {
            Log.d(TAG, "Cannot play: AudioPlayerManager is shut down");
            return;
        }
        initExecutorPlay();
        executorPlay.execute(() -> {
            // play the new audio file.
            try {
                if (mediaPlayer == null || isShutdown) {
                    Log.d(TAG, "MediaPlayer is null or shutdown, skipping play");
                    return;
                }
                mediaPlayer.setDataSource(String.valueOf(uriToFile));
                mediaPlayer.setOnPreparedListener(mp -> {
                    mp.setLooping(false);
                    mp.start();
                });
                mediaPlayer.setOnErrorListener((mp, what, extra) -> {
                    try {
                        mp.release();
                    } catch (IllegalStateException e) {
                        Log.d(TAG, "Error releasing MediaPlayer on error");
                    }
                    shutdownExecutors();
                    return true;
                });
                mediaPlayer.setOnCompletionListener(mp -> {
                    File audioFile = new File(uriToFile.getPath());
                    audioFile.deleteOnExit();
                    try {
                        mp.release();
                    } catch (IllegalStateException e) {
                        Log.d(TAG, "Error releasing MediaPlayer on completion");
                    }
                    shutdownExecutors();
                });

                mediaPlayer.prepareAsync();

            } catch (IOException e) {
                Log.e(TAG, "IOException during play", e);
                shutdownExecutors();
            } catch (IllegalStateException e) {
                Log.e(TAG, "IllegalStateException during play, MediaPlayer in invalid state", e);
                shutdownExecutors();
            }
        });
    }

    // Set the volume of each of MediaPlayer's audio channels
    public void setVolumeMediaPlayer(float leftChannelGains, float rightChannelGains) {
        if (isShutdown || mediaPlayer == null) {
            return;
        }
        try {
            mediaPlayer.setVolume(leftChannelGains, rightChannelGains);
        } catch (IllegalStateException e) {
            Log.e(TAG, "Error setting volume", e);
        }
    }

    // Initializes the executor
    public void initExecutorPlay() {
        if (executorPlay == null || executorPlay.isShutdown()) {
            executorPlay = Executors.newSingleThreadExecutor();
        }
    }

    // Shuts down the executor and marks as shutdown
    public void shutdownExecutors() {
        isShutdown = true;
        if (executorPlay != null && !executorPlay.isShutdown()) {
            executorPlay.shutdown();
        }
    }

    // Stops the current reproduction and safely releases resources
    public void stopPlaying() {
        try {
            if (isPlaying()) {
                mediaPlayer.stop();
            }
        } catch (IllegalStateException e) {
            Log.d(TAG, "Error stopping MediaPlayer", e);
        }
        
        if (mediaPlayer != null) {
            try {
                mediaPlayer.release();
                mediaPlayer = null;
                Log.d(TAG, "MediaPlayer released successfully");
            } catch (IllegalStateException e) {
                Log.d(TAG, "Error releasing MediaPlayer", e);
            }
        }
    }

}
