package com.aniwhere.aniwhere

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.URL
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.aniwhere.music/notification"
    private val NOTIFICATION_ID = 1001
    private val CHANNEL_ID = "aniwhere_music_channel"
    private var methodChannel: MethodChannel? = null
    private var mediaSession: MediaSession? = null
    private val executor = Executors.newSingleThreadExecutor()
    private var lastArtUrl: String? = null
    private var lastBitmap: Bitmap? = null

    private val actionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val action = intent?.action ?: return
            when (action) {
                "com.aniwhere.music.ACTION_PLAY" -> methodChannel?.invokeMethod("play", null)
                "com.aniwhere.music.ACTION_PAUSE" -> methodChannel?.invokeMethod("pause", null)
                "com.aniwhere.music.ACTION_NEXT" -> methodChannel?.invokeMethod("next", null)
                "com.aniwhere.music.ACTION_PREVIOUS" -> methodChannel?.invokeMethod("previous", null)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        // Initialize Android system MediaSession for notification drawer and device capsule
        mediaSession = MediaSession(this, "AniwhereMusicSession").apply {
            setCallback(object : MediaSession.Callback() {
                override fun onPlay() {
                    methodChannel?.invokeMethod("play", null)
                }

                override fun onPause() {
                    methodChannel?.invokeMethod("pause", null)
                }

                override fun onSkipToNext() {
                    methodChannel?.invokeMethod("next", null)
                }

                override fun onSkipToPrevious() {
                    methodChannel?.invokeMethod("previous", null)
                }

                override fun onSeekTo(pos: Long) {
                    methodChannel?.invokeMethod("seek", mapOf("position" to pos))
                }
            })
            isActive = true
        }

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "updatePlaybackState" -> {
                    val title = call.argument<String>("title") ?: "Now Playing"
                    val artist = call.argument<String>("artist") ?: ""
                    val album = call.argument<String>("album") ?: ""
                    val artUrl = call.argument<String>("artUrl")
                    val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                    val position = (call.argument<Number>("position")?.toLong()) ?: 0L
                    val duration = (call.argument<Number>("duration")?.toLong()) ?: 0L

                    updateMediaSessionAndNotification(title, artist, album, artUrl, isPlaying, position, duration)
                    result.success(true)
                }
                "stopNotification" -> {
                    val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    notificationManager.cancel(NOTIFICATION_ID)
                    mediaSession?.isActive = false
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        val filter = IntentFilter().apply {
            addAction("com.aniwhere.music.ACTION_PLAY")
            addAction("com.aniwhere.music.ACTION_PAUSE")
            addAction("com.aniwhere.music.ACTION_NEXT")
            addAction("com.aniwhere.music.ACTION_PREVIOUS")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(actionReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(actionReceiver, filter)
        }
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(actionReceiver)
        } catch (_: Exception) {}
        mediaSession?.release()
        mediaSession = null
        super.onDestroy()
    }

    private fun updateMediaSessionAndNotification(
        title: String,
        artist: String,
        album: String,
        artUrl: String?,
        isPlaying: Boolean,
        position: Long,
        duration: Long
    ) {
        val session = mediaSession ?: return
        session.isActive = true

        // 1. PlaybackState for Android system transport controls & status capsule
        val stateBuilder = PlaybackState.Builder()
            .setActions(
                PlaybackState.ACTION_PLAY or
                PlaybackState.ACTION_PAUSE or
                PlaybackState.ACTION_PLAY_PAUSE or
                PlaybackState.ACTION_SKIP_TO_NEXT or
                PlaybackState.ACTION_SKIP_TO_PREVIOUS or
                PlaybackState.ACTION_SEEK_TO
            )
            .setState(
                if (isPlaying) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED,
                position,
                1.0f
            )
        session.setPlaybackState(stateBuilder.build())

        // 2. Fetch cover art bitmap asynchronously for notification & Quick Settings tile
        if (artUrl != null && artUrl.isNotEmpty() && artUrl != lastArtUrl) {
            executor.execute {
                try {
                    val input = URL(artUrl).openStream()
                    val bitmap = BitmapFactory.decodeStream(input)
                    lastArtUrl = artUrl
                    lastBitmap = bitmap
                    runOnUiThread {
                        applyMetadataAndPostNotification(session, title, artist, album, duration, isPlaying, bitmap)
                    }
                } catch (_: Exception) {
                    runOnUiThread {
                        applyMetadataAndPostNotification(session, title, artist, album, duration, isPlaying, lastBitmap)
                    }
                }
            }
        } else {
            applyMetadataAndPostNotification(session, title, artist, album, duration, isPlaying, lastBitmap)
        }
    }

    private fun applyMetadataAndPostNotification(
        session: MediaSession,
        title: String,
        artist: String,
        album: String,
        duration: Long,
        isPlaying: Boolean,
        artBitmap: Bitmap?
    ) {
        // Set metadata on MediaSession
        val metaBuilder = MediaMetadata.Builder()
            .putString(MediaMetadata.METADATA_KEY_TITLE, title)
            .putString(MediaMetadata.METADATA_KEY_ARTIST, artist)
            .putString(MediaMetadata.METADATA_KEY_ALBUM, album)
            .putLong(MediaMetadata.METADATA_KEY_DURATION, duration)
        if (artBitmap != null) {
            metaBuilder.putBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART, artBitmap)
            metaBuilder.putBitmap(MediaMetadata.METADATA_KEY_ART, artBitmap)
        }
        session.setMetadata(metaBuilder.build())

        // Prepare NotificationChannel
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Music Playback",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows now playing music controls"
                setShowBadge(false)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val openIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            flags
        )

        val playPauseAction = if (isPlaying) {
            val pauseIntent = PendingIntent.getBroadcast(
                this, 1,
                Intent("com.aniwhere.music.ACTION_PAUSE"),
                flags
            )
            Notification.Action.Builder(
                android.R.drawable.ic_media_pause,
                "Pause",
                pauseIntent
            ).build()
        } else {
            val playIntent = PendingIntent.getBroadcast(
                this, 2,
                Intent("com.aniwhere.music.ACTION_PLAY"),
                flags
            )
            Notification.Action.Builder(
                android.R.drawable.ic_media_play,
                "Play",
                playIntent
            ).build()
        }

        val prevIntent = PendingIntent.getBroadcast(
            this, 3,
            Intent("com.aniwhere.music.ACTION_PREVIOUS"),
            flags
        )
        val prevAction = Notification.Action.Builder(
            android.R.drawable.ic_media_previous,
            "Previous",
            prevIntent
        ).build()

        val nextIntent = PendingIntent.getBroadcast(
            this, 4,
            Intent("com.aniwhere.music.ACTION_NEXT"),
            flags
        )
        val nextAction = Notification.Action.Builder(
            android.R.drawable.ic_media_next,
            "Next",
            nextIntent
        ).build()

        // Notification.MediaStyle connected to MediaSession token
        val mediaStyle = Notification.MediaStyle()
            .setMediaSession(session.sessionToken)
            .setShowActionsInCompactView(0, 1, 2)

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        builder
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(title)
            .setContentText(artist)
            .setContentIntent(openIntent)
            .setStyle(mediaStyle)
            .setOngoing(isPlaying)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .addAction(prevAction)
            .addAction(playPauseAction)
            .addAction(nextAction)

        if (artBitmap != null) {
            builder.setLargeIcon(artBitmap)
        }

        notificationManager.notify(NOTIFICATION_ID, builder.build())
    }
}
