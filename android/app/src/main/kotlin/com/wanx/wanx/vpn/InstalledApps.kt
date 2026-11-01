package com.wanx.wanx.vpn

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Handler
import android.os.Looper
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

/**
 * Apps the user can pick for the per-app VPN: everything with a launcher
 * icon, except WanX itself. Visible through the manifest's <queries>
 * entry, so the app needs no QUERY_ALL_PACKAGES permission.
 */
object InstalledApps {
    private const val ICON_PX = 96
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    /** [done] gets [{package, label, icon: PNG bytes?}], on the main thread. */
    fun list(context: Context, done: (List<Map<String, Any?>>) -> Unit) {
        worker.execute {
            val pm = context.packageManager
            val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
            val apps = pm.queryIntentActivities(launcher, 0)
                .map { it.activityInfo.applicationInfo }
                .distinctBy { it.packageName }
                .filter { it.packageName != context.packageName }
                .map { info ->
                    mapOf(
                        "package" to info.packageName,
                        "label" to info.loadLabel(pm).toString(),
                        "icon" to runCatching { png(info.loadIcon(pm)) }.getOrNull(),
                    )
                }
                .sortedBy { (it["label"] as String).lowercase() }
            main.post { done(apps) }
        }
    }

    private fun png(drawable: android.graphics.drawable.Drawable): ByteArray {
        val bitmap = Bitmap.createBitmap(ICON_PX, ICON_PX, Bitmap.Config.ARGB_8888)
        drawable.setBounds(0, 0, ICON_PX, ICON_PX)
        drawable.draw(Canvas(bitmap))
        return ByteArrayOutputStream().use {
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
            bitmap.recycle()
            it.toByteArray()
        }
    }
}
