package com.aniket.ewallet

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * Persistent floating ₹ button over other apps.
 * Tap opens the quick-add popup (amount, account, section, subcategory)
 * so a missed SMS can still be logged without opening the full app.
 */
class QuickAccessBubbleService : Service() {
    companion object {
        private const val CHANNEL_ID = "quick_access_bubble"
        private const val NOTIFICATION_ID = 72001
        const val PREFS_NAME = OverlayFirebaseRepository.PREFS_NAME
        const val KEY_ENABLED = "quick_access_enabled"
        const val ACTION_STOP = "com.aniket.ewallet.STOP_QUICK_ACCESS"
        const val ACTION_OPEN = "com.aniket.ewallet.OPEN_QUICK_ACCESS"

        fun isEnabled(context: Context): Boolean =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .getBoolean(KEY_ENABLED, false)

        fun setEnabled(context: Context, enabled: Boolean) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(KEY_ENABLED, enabled)
                .apply()
        }

        fun start(context: Context): Boolean {
            if (!Settings.canDrawOverlays(context)) return false
            setEnabled(context, true)
            val intent = Intent(context, QuickAccessBubbleService::class.java)
            ContextCompat.startForegroundService(context, intent)
            return true
        }

        fun stop(context: Context) {
            setEnabled(context, false)
            context.stopService(Intent(context, QuickAccessBubbleService::class.java))
        }

        fun launchQuickAdd(context: Context) {
            val intent = Intent(context, SmsOverlayActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
                putExtra(SmsOverlayActivity.EXTRA_MANUAL, true)
                putExtra(SmsOverlayActivity.EXTRA_TYPE, "debit")
                putExtra(SmsOverlayActivity.EXTRA_AMOUNT, 0.0)
                putExtra(SmsOverlayActivity.EXTRA_DATE, System.currentTimeMillis())
                putExtra(SmsOverlayActivity.EXTRA_BODY, "")
                putExtra(SmsOverlayActivity.EXTRA_ADDRESS, "Quick add")
            }
            context.startActivity(intent)
        }
    }

    private var windowManager: WindowManager? = null
    private var bubbleView: View? = null
    private var layoutParams: WindowManager.LayoutParams? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ensureChannel()
        val notification = buildNotification()
        // Hidden from user permission list — uncomment with manifest REMOTE_MESSAGING if needed on Android 14+:
        // if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
        //     startForeground(
        //         NOTIFICATION_ID,
        //         notification,
        //         ServiceInfo.FOREGROUND_SERVICE_TYPE_REMOTE_MESSAGING,
        //     )
        // } else {
        startForeground(NOTIFICATION_ID, notification)
        // }
        if (!Settings.canDrawOverlays(this)) {
            stopSelf()
            return
        }
        showBubble()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stop(this)
                return START_NOT_STICKY
            }
            ACTION_OPEN -> launchQuickAdd(this)
        }
        if (!Settings.canDrawOverlays(this)) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (bubbleView == null) showBubble()
        return START_STICKY
    }

    override fun onDestroy() {
        removeBubble()
        super.onDestroy()
    }

    private fun showBubble() {
        if (bubbleView != null) return
        val wm = getSystemService(WINDOW_SERVICE) as WindowManager
        windowManager = wm

        val view = LayoutInflater.from(this).inflate(R.layout.quick_access_bubble, null)
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        )
        params.gravity = Gravity.TOP or Gravity.END
        params.x = 16
        params.y = 220

        attachDrag(view, params)
        try {
            wm.addView(view, params)
            bubbleView = view
            layoutParams = params
        } catch (_: Exception) {
            stopSelf()
        }
    }

    private fun attachDrag(view: View, params: WindowManager.LayoutParams) {
        val slop = ViewConfiguration.get(this).scaledTouchSlop
        var startX = 0
        var startY = 0
        var touchX = 0f
        var touchY = 0f
        var moved = false

        view.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    startX = params.x
                    startY = params.y
                    touchX = event.rawX
                    touchY = event.rawY
                    moved = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - touchX).toInt()
                    val dy = (event.rawY - touchY).toInt()
                    if (kotlin.math.abs(dx) > slop || kotlin.math.abs(dy) > slop) {
                        moved = true
                    }
                    if (moved) {
                        params.x = (startX - dx).coerceAtLeast(0)
                        params.y = (startY + dy).coerceAtLeast(0)
                        try {
                            windowManager?.updateViewLayout(view, params)
                        } catch (_: Exception) {
                        }
                    }
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    if (!moved) launchQuickAdd(this)
                    true
                }
                else -> false
            }
        }
    }

    private fun removeBubble() {
        val view = bubbleView ?: return
        try {
            windowManager?.removeView(view)
        } catch (_: Exception) {
        }
        bubbleView = null
        layoutParams = null
        windowManager = null
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Quick add button",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Keeps the floating quick-add button on screen"
            setShowBadge(false)
        }
        nm.createNotificationChannel(channel)
    }

    private fun buildNotification(): android.app.Notification {
        val openIntent = Intent(this, QuickAccessBubbleService::class.java).apply {
            action = ACTION_OPEN
        }
        val stopIntent = Intent(this, QuickAccessBubbleService::class.java).apply {
            action = ACTION_STOP
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0

        val appIcon = BitmapFactory.decodeResource(resources, R.drawable.ic_quick_access)
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_quick_access_status)
            .setLargeIcon(appIcon)
            .setContentTitle("Quick add is on")
            .setContentText("Tap the floating button to log amount, account & category")
            .setOngoing(true)
            .setContentIntent(
                PendingIntent.getService(this, 1, openIntent, flags),
            )
            .addAction(
                0,
                "Add now",
                PendingIntent.getService(this, 2, openIntent, flags),
            )
            .addAction(
                0,
                "Hide",
                PendingIntent.getService(this, 3, stopIntent, flags),
            )
            .build()
    }
}
