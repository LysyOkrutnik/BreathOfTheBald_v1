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
                val coldShowerDone = widgetData.getBoolean("cold_shower_done", false)
                val coldShowerLabel =
                    widgetData.getString("cold_shower_label", "COLD SHOWER") ?: "COLD SHOWER"
                val coldShowerDoneLabel =
                    widgetData.getString("cold_shower_done_label", "SHOWER DONE") ?: "SHOWER DONE"

                setTextViewText(R.id.widget_streak, streak.toString())
                setTextViewText(R.id.widget_streak_label, streakLabel)
                setTextViewText(R.id.widget_start_button, startLabel)

                // The cold shower is a once-a-day tick: once logged, the button
                // switches to a dimmed "done" look instead of disappearing —
                // still tappable, but re-logging is a no-op on the Flutter side.
                setTextViewText(
                    R.id.widget_coldshower_button,
                    if (coldShowerDone) coldShowerDoneLabel else coldShowerLabel,
                )
                setInt(
                    R.id.widget_coldshower_button,
                    "setBackgroundResource",
                    if (coldShowerDone) {
                        R.drawable.widget_coldshower_button_done_bg
                    } else {
                        R.drawable.widget_coldshower_button_bg
                    },
                )
                setTextColor(
                    R.id.widget_coldshower_button,
                    if (coldShowerDone) 0xFF80D8FF.toInt() else 0xFF000000.toInt(),
                )

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

                // Tapping the cold shower button logs it (a no-op if already done).
                setOnClickPendingIntent(
                    R.id.widget_coldshower_button,
                    HomeWidgetLaunchIntent.getActivity(
                        context, MainActivity::class.java, Uri.parse("breath://coldshower"),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
