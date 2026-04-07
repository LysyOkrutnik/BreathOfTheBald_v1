Role: Senior Flutter Engineer / Architect
Context: Refactoring a niche breathing app into a premium, high-performance product.
Tech Stack: Flutter (Stable channel), CustomPainter & Fragment Shaders (SkSL/SPIR-V), Drift (formerly Moor) or Sqflite for persistence, BLoC or Riverpod for state management.
Design Language: "Deep Night Premium" (#05070A), Glassmorphism, Procedural Fluid Dynamics.

1. Visual Engine: Procedural Organic Smoke (CustomPainter + SkSL)
Objective: Replace static assets with a photorealistic, real-time smoke effect that reacts to the breath cycle.

Implementation: Use a CustomPainter driven by a SingleTickerProviderStateMixin.

Technique: Use Fast Noise (Simplex/Perlin) to modulate a closed Path with 12-16 control points.

Shaders (SkSL): Implement a FragmentShader to create a "volumetric" smoke texture.

Inhale: Transform scale and opacity using CurvedAnimation(curve: Curves.easeInOutCubic).

Exhale: Increase noise turbulence to simulate dissipation.

Performance: Must maintain 60/120 FPS. Calculations for path points should be optimized (avoid object allocation in the paint method).

2. Architecture: Local-First Persistence (Drift/Sqflite)
Objective: Robust data tracking without an external backend.

Engine: Drift (for type-safe SQL) or Sqflite.

Schema: Three core tables/entities:

Sessions: id (UUID), timestamp, modeId, rounds, maxRetentionSec, xpEarned.

UserProfile: level, totalXp, dailyStreak, lastSessionDate.

HealthMetrics: timestamp, co2ToleranceScore, avgBreathsPerMin.

Business Logic: Implement a StatisticsRepository that uses reactive streams (Streams/Flows) to provide real-time data for charts.

3. Gamification & Progression System
Objective: Psychological "hook" for user retention.

XP Engine: Calculate XP: (breaths * multiplier) + (retentionSec * 2).

Leveling: Tier system (1-10). Formula: XP_for_next_level = current_level * 500.

Streak Logic: Custom Service to check the time difference between the current time and the lastSessionDate from the DB.

CO2 Lab: A dedicated timer mode for "Max Exhale Hold". Record and plot results on a secondary line chart.

4. Advanced UI/UX & Haptics
Objective: Premium feel and "eyes-closed" usability.

Glassmorphism: Use BackdropFilter with ImageFiltered (sigma: 15-20). Overlay with a subtle LinearGradient (white with 0.05 opacity) and a 1px border.

Hero Animations: Use Flutter's Hero widgets to morph the rhythm cards (Warrior, Beast) into the exercise background during navigation.

Haptic Engine: Use HapticFeedback class:

Inhale: Sequential lightImpact pulses.

Exhale: mediumImpact at the start.

Retention Peak: vibrate() or heavyImpact.

Results Card: After each session, use RepaintBoundary to capture a summary of stats and generate a shareable image.

5. OS Integration: Notifications & Widgets
Objective: Stay in the user's field of vision.

Notifications: Use flutter_local_notifications.

Logic: Scheduled ZonedSchedule reminders.

Payload: Deep-link to specific breathing modes using onDidReceiveNotificationResponse.

Copy: Aggressive/Motivational ("The void is calling. Breathe, Beast.").

Home Screen Widget: Use the home_widget package.

Display: Current Streak + Daily Progress.

Bridge: Write data to shared storage (AppGroups for iOS / SharedPreferences for Android) so the widget can access it.

6. Functional Requirements & Constraints
Custom Mode Builder: Create a UI to define Duration for each phase (Inhale/Hold/Exhale/Hold), saved as a JSON string or in a relational table.

Charts: Use fl_chart. Line chart for retention trends with BelowBarData (gradient fill).

Theming: ThemeData must be strictly dark. Use GoogleFonts.montserrat or similar clean sans-serif.

Structure: Follow Clean Architecture (Data, Domain, Presentation layers).

Agent Instruction: Start by setting up the Drift database schema and the CustomPainter for the smoke engine. Ensure the transition between the Dashboard and ExerciseScreen uses Hero animations for a seamless experience.

