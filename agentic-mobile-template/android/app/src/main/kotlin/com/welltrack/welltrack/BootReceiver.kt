package com.welltrack.welltrack

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequest
import androidx.work.WorkManager
import dev.fluttercommunity.workmanager.BackgroundWorker

/**
 * Receives BOOT_COMPLETED broadcast and schedules a WorkManager task
 * to reschedule all active flutter_local_notifications after device reboot.
 *
 * The task is handled by the Flutter [callbackDispatcher] in
 * health_background_sync.dart under the "reschedule_notifications" task name.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != "android.intent.action.QUICKBOOT_POWERON"
        ) return

        val inputData = Data.Builder()
            .putString(BackgroundWorker.DART_TASK_KEY, "reschedule_notifications")
            .build()

        val request = OneTimeWorkRequest.Builder(BackgroundWorker::class.java)
            .setInputData(inputData)
            .build()

        WorkManager.getInstance(context).enqueueUniqueWork(
            "welltrack_reschedule_on_boot",
            ExistingWorkPolicy.REPLACE,
            request,
        )
    }
}
