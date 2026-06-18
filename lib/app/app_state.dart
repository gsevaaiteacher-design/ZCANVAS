// ==========================================================
// app/app_state.dart
// GLOBAL APPLICATION STATE HOLDER
// PHASE-16 — APPLICATION SHELL CONTRACT
// ==========================================================
//
// PRIMARY ROLE: Stores application-level runtime state only.
//
// OWNS:
//   ✔ Theme State
//   ✔ Route State
//   ✔ Session State
//   ✔ Startup Flags
//   ✔ Runtime Configuration
//   ✔ Application Lifecycle State
//
// DOES NOT OWN:
//   ✖ Layers              ✖ Canvas State
//   ✖ History Entries     ✖ Undo / Redo Stacks
//   ✖ Snapshots           ✖ Template Data
//   ✖ Export Data         ✖ Editor Data
//
// PERSISTENCE LAW:
//   Runtime state only. StorageEngine owns all file persistence.
//   This file NEVER saves or loads files.
//
// ALLOWED COMMUNICATION:
//   app.dart              → app_state.dart
//   dependency_container  → app_state.dart
//
// FORBIDDEN COMMUNICATION:
//   app_state.dart → LayerEngine   ❌
//   app_state.dart → HistoryEngine ❌
//   app_state.dart → RenderEngine  ❌
//   app_state.dart → Canvas        ❌
//
// FAILURE LAW:
//   Corrupted state must not crash the application.
//   Must recover safe defaults. Must not affect editor data
//   or the layer system.
// ==========================================================

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// APP STATE — Singleton
// ---------------------------------------------------------------------------

/// Global application-level runtime state.
///
/// Access via [AppState.instance] — never construct directly.
///
/// Contains ONLY application shell state:
///   [themeState], [routeState], [sessionState],
///   [applicationFlags], [runtimeConfiguration].
///
/// Editor state, layer state, history, and canvas objects
/// are NEVER stored here.
class AppState extends ChangeNotifier {
  AppState._internal();

  /// Singleton instance — single source of truth for app-level state.
  static final AppState instance = AppState._internal();

  // -------------------------------------------------------------------------
  // MANDATORY STATE SECTIONS
  // -------------------------------------------------------------------------

  /// Theme state — current theme mode and theme data.
  late AppThemeState themeState;

  /// Route state — current and previous route.
  late AppRouteState routeState;

  /// Session state — runtime session metadata.
  late AppSessionState sessionState;

  /// Application flags — startup and feature flags.
  late AppFlags applicationFlags;

  /// Runtime configuration — environment and feature configuration.
  late AppRuntimeConfiguration runtimeConfiguration;

  // -------------------------------------------------------------------------
  // MANDATORY FUNCTIONS
  // -------------------------------------------------------------------------

  /// Initialises all state sections to safe defaults.
  ///
  /// Must be called first in the startup sequence (Step 1 of app.dart).
  /// Safe to call again — equivalent to a full reset.
  void initializeState() {
    try {
      themeState = AppThemeState.defaultTheme();
      routeState = AppRouteState.initial();
      sessionState = AppSessionState.initial();
      applicationFlags = AppFlags.initial();
      runtimeConfiguration = AppRuntimeConfiguration.defaults();
    } catch (_) {
      // Failure law: if state initialisation fails, recover safe defaults
      // rather than propagating the error up to crash the application.
      _recoverSafeDefaults();
    }
    notifyListeners();
  }

  /// Resets all state sections to their initial safe defaults.
  ///
  /// Equivalent to [initializeState]. Does NOT affect:
  ///   - Editor data   - Layer system   - History   - Canvas objects
  void resetState() {
    initializeState();
  }

  /// Updates the active theme state.
  ///
  /// [newTheme] must not be null; if an invalid value is supplied
  /// the current theme is preserved (failure law — never crash).
  void updateTheme(AppThemeState newTheme) {
    try {
      themeState = newTheme;
      notifyListeners();
    } catch (_) {
      // Preserve existing theme on error — do not crash.
    }
  }

  /// Updates the active route state.
  ///
  /// Stores [routeName] as the current route and demotes the
  /// previous current route to [AppRouteState.previousRoute].
  void updateRoute(String routeName) {
    try {
      routeState = routeState.copyWith(
        previousRoute: routeState.currentRoute,
        currentRoute: routeName,
      );
      notifyListeners();
    } catch (_) {
      // Preserve existing route on error — do not crash.
    }
  }

  /// Updates the active session state.
  ///
  /// [updater] receives the current session and returns the new session.
  void updateSession(AppSessionState Function(AppSessionState current) updater) {
    try {
      sessionState = updater(sessionState);
      notifyListeners();
    } catch (_) {
      // Preserve existing session on error — do not crash.
    }
  }

  /// Returns a human-readable diagnostics report of the current state.
  ///
  /// Intended for crash reporting, debug overlays, and logging.
  /// Never exposes private keys, tokens, or PII.
  String generateStateReport() {
    final StringBuffer buffer = StringBuffer()
      ..writeln('=== Z-CANVAS AppState Report ===')
      ..writeln('Theme     : ${themeState.themeMode.name}')
      ..writeln('Route     : ${routeState.currentRoute}  (prev: ${routeState.previousRoute})')
      ..writeln('Session   : started=${sessionState.sessionStartedAt.toIso8601String()}')
      ..writeln('Flags     : dependencyContainerReady=${applicationFlags.dependencyContainerReady}')
      ..writeln('            startupComplete=${applicationFlags.startupComplete}')
      ..writeln('Config    : env=${runtimeConfiguration.environment.name}')
      ..writeln('================================');
    return buffer.toString();
  }

  // -------------------------------------------------------------------------
  // INTERNAL HELPERS
  // -------------------------------------------------------------------------

  /// Recovers safe defaults when [initializeState] itself fails.
  ///
  /// Uses only const/literal values — no external dependencies.
  void _recoverSafeDefaults() {
    themeState = AppThemeState.defaultTheme();
    routeState = AppRouteState.initial();
    sessionState = AppSessionState.initial();
    applicationFlags = AppFlags.initial();
    runtimeConfiguration = AppRuntimeConfiguration.defaults();
  }
}

// ---------------------------------------------------------------------------
// THEME STATE
// ---------------------------------------------------------------------------

/// Holds the active theme configuration for the application shell.
///
/// Owned by [AppState.themeState].
/// Does NOT own canvas colours, layer colours, or editor colours.
class AppThemeState {
  const AppThemeState({
    required this.themeMode,
    required this.lightTheme,
    required this.darkTheme,
  });

  /// Active Flutter theme mode.
  final ThemeMode themeMode;

  /// Light theme data.
  final ThemeData lightTheme;

  /// Dark theme data.
  final ThemeData darkTheme;

  /// Returns the canonical default theme for Z-CANVAS.
  factory AppThemeState.defaultTheme() {
    return AppThemeState(
      themeMode: ThemeMode.dark,
      lightTheme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
    );
  }

  AppThemeState copyWith({
    ThemeMode? themeMode,
    ThemeData? lightTheme,
    ThemeData? darkTheme,
  }) {
    return AppThemeState(
      themeMode: themeMode ?? this.themeMode,
      lightTheme: lightTheme ?? this.lightTheme,
      darkTheme: darkTheme ?? this.darkTheme,
    );
  }

  // -------------------------------------------------------------------------
  // THEME BUILDERS
  // -------------------------------------------------------------------------

  static ThemeData _buildDarkTheme() {
    const Color surface = Color(0xFF121212);
    const Color background = Color(0xFF0A0A0A);
    const Color primary = Color(0xFF6C63FF);
    const Color onPrimary = Color(0xFFFFFFFF);
    const Color onSurface = Color(0xFFE0E0E0);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        onPrimary: onPrimary,
        surface: surface,
        onSurface: onSurface,
      ),
      scaffoldBackgroundColor: background,
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  static ThemeData _buildLightTheme() {
    const Color surface = Color(0xFFF5F5F5);
    const Color background = Color(0xFFFFFFFF);
    const Color primary = Color(0xFF6C63FF);
    const Color onPrimary = Color(0xFFFFFFFF);
    const Color onSurface = Color(0xFF1A1A1A);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: onPrimary,
        surface: surface,
        onSurface: onSurface,
      ),
      scaffoldBackgroundColor: background,
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ROUTE STATE
// ---------------------------------------------------------------------------

/// Holds the current and previous navigation route at the application level.
///
/// Owned by [AppState.routeState].
/// Contains NO navigation decisions or permission logic.
class AppRouteState {
  const AppRouteState({
    required this.currentRoute,
    required this.previousRoute,
  });

  /// The route the application is currently displaying.
  final String currentRoute;

  /// The route the application displayed before [currentRoute].
  final String previousRoute;

  /// Returns the initial route state — home, no previous route.
  factory AppRouteState.initial() {
    return const AppRouteState(
      currentRoute: '/',
      previousRoute: '',
    );
  }

  AppRouteState copyWith({
    String? currentRoute,
    String? previousRoute,
  }) {
    return AppRouteState(
      currentRoute: currentRoute ?? this.currentRoute,
      previousRoute: previousRoute ?? this.previousRoute,
    );
  }
}

// ---------------------------------------------------------------------------
// SESSION STATE
// ---------------------------------------------------------------------------

/// Holds runtime session metadata.
///
/// Owned by [AppState.sessionState].
/// Does NOT persist to disk — runtime only (failure law).
class AppSessionState {
  const AppSessionState({
    required this.sessionStartedAt,
    required this.isActive,
    required this.sessionId,
  });

  /// UTC timestamp when the session was started.
  final DateTime sessionStartedAt;

  /// Whether the session is currently active.
  final bool isActive;

  /// Opaque, non-PII runtime session identifier.
  final String sessionId;

  /// Returns the initial session state for a new launch.
  factory AppSessionState.initial() {
    return AppSessionState(
      sessionStartedAt: DateTime.now().toUtc(),
      isActive: true,
      sessionId: _generateSessionId(),
    );
  }

  AppSessionState copyWith({
    DateTime? sessionStartedAt,
    bool? isActive,
    String? sessionId,
  }) {
    return AppSessionState(
      sessionStartedAt: sessionStartedAt ?? this.sessionStartedAt,
      isActive: isActive ?? this.isActive,
      sessionId: sessionId ?? this.sessionId,
    );
  }

  /// Generates a simple, collision-resistant, non-PII session identifier.
  static String _generateSessionId() {
    final int ms = DateTime.now().millisecondsSinceEpoch;
    final int hash = ms.hashCode ^ Object.hash(ms, 0xCAFE_BABE);
    return 'zc-${ms.toRadixString(16)}-${hash.toRadixString(16).replaceAll('-', '')}';
  }
}

// ---------------------------------------------------------------------------
// APPLICATION FLAGS
// ---------------------------------------------------------------------------

/// Startup and feature flags for the application shell.
///
/// Owned by [AppState.applicationFlags].
/// Contains NO editor flags, NO layer flags, NO canvas flags.
class AppFlags {
  AppFlags({
    required this.dependencyContainerReady,
    required this.startupComplete,
    required this.isFirstLaunch,
    required this.hasStartupError,
  });

  /// True once [DependencyContainer] has successfully bootstrapped.
  bool dependencyContainerReady;

  /// True once all six startup steps in app.dart have completed.
  bool startupComplete;

  /// True on the very first application launch.
  bool isFirstLaunch;

  /// True if startup encountered a non-fatal error that was recovered.
  bool hasStartupError;

  /// Returns safe initial flags — nothing is ready until startup proves it is.
  factory AppFlags.initial() {
    return AppFlags(
      dependencyContainerReady: false,
      startupComplete: false,
      isFirstLaunch: true,
      hasStartupError: false,
    );
  }

  AppFlags copyWith({
    bool? dependencyContainerReady,
    bool? startupComplete,
    bool? isFirstLaunch,
    bool? hasStartupError,
  }) {
    return AppFlags(
      dependencyContainerReady: dependencyContainerReady ?? this.dependencyContainerReady,
      startupComplete: startupComplete ?? this.startupComplete,
      isFirstLaunch: isFirstLaunch ?? this.isFirstLaunch,
      hasStartupError: hasStartupError ?? this.hasStartupError,
    );
  }
}

// ---------------------------------------------------------------------------
// RUNTIME CONFIGURATION
// ---------------------------------------------------------------------------

/// Environment and feature configuration for the application shell.
///
/// Owned by [AppState.runtimeConfiguration].
/// Contains NO editor config, NO canvas config, NO storage paths.
class AppRuntimeConfiguration {
  const AppRuntimeConfiguration({
    required this.environment,
    required this.version,
    required this.buildNumber,
    required this.enableDiagnosticsOverlay,
  });

  /// Deployment environment the application is running in.
  final AppEnvironment environment;

  /// Human-readable application version string (e.g. "1.0.0").
  final String version;

  /// Monotonic build number.
  final int buildNumber;

  /// When true, a diagnostics overlay may be rendered in debug builds.
  final bool enableDiagnosticsOverlay;

  /// Returns the canonical safe defaults for runtime configuration.
  factory AppRuntimeConfiguration.defaults() {
    return const AppRuntimeConfiguration(
      environment: AppEnvironment.production,
      version: '1.0.0',
      buildNumber: 1,
      enableDiagnosticsOverlay: false,
    );
  }

  AppRuntimeConfiguration copyWith({
    AppEnvironment? environment,
    String? version,
    int? buildNumber,
    bool? enableDiagnosticsOverlay,
  }) {
    return AppRuntimeConfiguration(
      environment: environment ?? this.environment,
      version: version ?? this.version,
      buildNumber: buildNumber ?? this.buildNumber,
      enableDiagnosticsOverlay: enableDiagnosticsOverlay ?? this.enableDiagnosticsOverlay,
    );
  }
}

// ---------------------------------------------------------------------------
// ENUMERATIONS
// ---------------------------------------------------------------------------

/// Deployment environment for the running application instance.
enum AppEnvironment {
  development,
  staging,
  production,
}

// ==========================================================
// END OF FILE — app/app_state.dart
// ==========================================================
