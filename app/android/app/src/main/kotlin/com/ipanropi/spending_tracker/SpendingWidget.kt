package com.ipanropi.spending_tracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * The 1×1 home-screen widget: what you can spend today ("30" over "/day"),
 * coloured by pace, with what's left ("RM 365") as its label.
 *
 * The Flutter app works the numbers out (lib/src/home_screen_widget.dart) and
 * saves them; this only draws them. Tapping it opens the app.
 */
class SpendingWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val perDay = widgetData.getString("perDay", null) ?: "–"
        val left = widgetData.getString("left", null) ?: "Spending"
        val state = widgetData.getString("state", null)
        val colour = when (state) {
            "onPace" -> GOOD
            "fast" -> WARN
            "overspent" -> SPEND
            else -> MUTED
        }
        val description = if (state == null || state == "unknown") {
            "Spending. Open the app to load your balance."
        } else {
            "$left left, RM $perDay a day"
        }

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.spending_widget).apply {
                setTextViewText(R.id.per_day, perDay)
                setTextColor(R.id.per_day, colour)
                setTextViewText(R.id.left, left)
                setContentDescription(R.id.root, description)
                setOnClickPendingIntent(
                    R.id.root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    // The app's pace colours (lib/src/ui/theme.dart).
    private companion object {
        const val GOOD = 0xFF4ADE80.toInt()
        const val WARN = 0xFFFBBF24.toInt()
        const val SPEND = 0xFFF87171.toInt()
        const val MUTED = 0xFFA09F97.toInt()
    }
}
