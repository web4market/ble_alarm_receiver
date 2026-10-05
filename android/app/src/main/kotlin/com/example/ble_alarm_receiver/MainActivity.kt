package com.example.ble_alarm_receiver

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.View
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Всплытие приложения на весь экран при тревоге (lib/services/app_foreground.dart).
//
// Android не даёт свёрнутому приложению самому открыть свой экран. Поэтому
// используются сразу три способа — какой-то сработает на любой прошивке:
//  1. Разрешение «Поверх других приложений» + временное невидимое окно-оверлей:
//     пока оно показано, система считает приложение видимым и разрешает запуск.
//  2. Прямой startActivity (работает на «чистом» Android с этим разрешением).
//  3. Уведомление тревоги с fullScreenIntent (как у будильника/звонка): при
//     выключенном или заблокированном экране открывает приложение, иначе
//     показывается всплывающим баннером.
class MainActivity : FlutterActivity() {
    private val channel = "zhurin/foreground"
    private val tag = "AppForeground"
    private val alarmChannelId = "alarm_popup"
    private val alarmNotificationId = 7001
    private val handler = Handler(Looper.getMainLooper())
    private var overlayView: View? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canDrawOverlays" -> result.success(canDrawOverlays())
                    "requestOverlayPermission" -> {
                        requestOverlayPermission()
                        result.success(null)
                    }
                    "openAppSettings" -> {
                        openAppSettings()
                        result.success(null)
                    }
                    "bringToFront" -> {
                        val text = call.argument<String>("text") ?: "Тревога"
                        result.success(bringToFront(text))
                    }
                    "releaseLockScreen" -> {
                        setShowOverLockScreen(false)
                        cancelAlarmNotification()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // Приложение вернулось на экран — уведомление тревоги больше не нужно
    override fun onResume() {
        super.onResume()
        cancelAlarmNotification()
    }

    private fun canDrawOverlays(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        startActivity(
            Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
    }

    // Экран «О приложении» — там на Xiaomi/Huawei «Другие разрешения» →
    // «Отображать всплывающие окна, когда приложение работает в фоне»
    private fun openAppSettings() {
        startActivity(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
    }

    private fun bringToFront(text: String): Boolean {
        setShowOverLockScreen(true)
        showTemporaryOverlay()

        val intent = Intent(this, MainActivity::class.java).addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
        )
        // Небольшая задержка, чтобы оверлей успел появиться
        handler.postDelayed({
            try {
                startActivity(intent)
                Log.i(tag, "startActivity выполнен")
            } catch (e: Exception) {
                Log.w(tag, "startActivity не удался: $e")
            }
        }, 150)

        showAlarmNotification(text)
        return true
    }

    // ── 1. Временное невидимое окно-оверлей ─────────────────────────────────

    private fun showTemporaryOverlay() {
        if (!canDrawOverlays() || overlayView != null) return
        try {
            val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE
            val params = WindowManager.LayoutParams(
                1, 1, type,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                PixelFormat.TRANSLUCENT
            )
            val view = View(applicationContext)
            wm.addView(view, params)
            overlayView = view
            handler.postDelayed({ removeOverlay() }, 3000)
        } catch (e: Exception) {
            Log.w(tag, "Оверлей не показан: $e")
        }
    }

    private fun removeOverlay() {
        val v = overlayView ?: return
        try {
            (getSystemService(Context.WINDOW_SERVICE) as WindowManager).removeView(v)
        } catch (_: Exception) {
        }
        overlayView = null
    }

    // ── 3. Уведомление тревоги с fullScreenIntent ───────────────────────────

    private fun showAlarmNotification(text: String) {
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                nm.getNotificationChannel(alarmChannelId) == null
            ) {
                val ch = NotificationChannel(
                    alarmChannelId, "Тревога", NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Открывает приложение при тревоге"
                    setSound(null, null) // звук тревоги играет само приложение
                    lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                }
                nm.createNotificationChannel(ch)
            }

            val pi = PendingIntent.getActivity(
                this, 0,
                Intent(this, MainActivity::class.java).addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                ),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val n = NotificationCompat.Builder(this, alarmChannelId)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("ТРЕВОГА")
                .setContentText(text)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setContentIntent(pi)
                .setFullScreenIntent(pi, true)
                .setAutoCancel(true)
                .setOngoing(true)
                .build()
            nm.notify(alarmNotificationId, n)
        } catch (e: Exception) {
            Log.w(tag, "Уведомление тревоги не показано: $e")
        }
    }

    private fun cancelAlarmNotification() {
        try {
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .cancel(alarmNotificationId)
        } catch (_: Exception) {
        }
    }

    // Поверх блокировки показываемся только на время тревоги — иначе
    // пульт был бы виден без разблокировки планшета.
    private fun setShowOverLockScreen(on: Boolean) {
        runOnUiThread {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(on)
                setTurnScreenOn(on)
            } else {
                @Suppress("DEPRECATION")
                val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                if (on) window.addFlags(flags) else window.clearFlags(flags)
            }
        }
    }
}
