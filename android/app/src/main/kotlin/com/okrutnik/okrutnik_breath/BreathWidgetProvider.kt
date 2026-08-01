package com.okrutnik.okrutnik_breath

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/// Home-screen widget showing the current streak with a quick-start button.
/// Data is pushed from Flutter via the `home_widget` plugin.
class BreathWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.breath_widget).apply {
                val streak = widgetData.getInt("streak", 0)
                val streakLabel = widgetData.getString("streak_label", "day streak") ?: "day streak"
                val startLabel = widgetData.getString("start_label", "BREATHE") ?: "BREATHE"

                setTextViewText(R.id.widget_streak, streak.toString())
                setTextViewText(R.id.widget_streak_label, streakLabel)
                setTextViewText(R.id.widget_start_button, startLabel)

                // Tapping the card opens the app.
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(
                        context, MainActivity::class.java, Uri.parse("breath://open"),
                    ),
                )

                // Tapping the button quick-starts a session.
                setOnClickPendingIntent(
                    R.id.widget_start_button,
                    HomeWidgetLaunchIntent.getActivity(
                        context, MainActivity::class.java, Uri.parse("breath://quickstart"),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
