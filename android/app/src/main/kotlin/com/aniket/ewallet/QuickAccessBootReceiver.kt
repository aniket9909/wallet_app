package com.aniket.ewallet

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Settings

class QuickAccessBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_LOCKED_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            return
        }
        if (!QuickAccessBubbleService.isEnabled(context)) return
        if (!Settings.canDrawOverlays(context)) return
        QuickAccessBubbleService.start(context)
    }
}
