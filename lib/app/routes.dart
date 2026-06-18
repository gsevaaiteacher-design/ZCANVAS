// ==========================================================
// app/routes.dart
// CENTRAL ROUTE REGISTRY
// PHASE-16 — APPLICATION SHELL CONTRACT
// ==========================================================
//
// PRIMARY ROLE: Single source of truth for navigation.
//
// OWNS:
//   ✔ Route Names
//   ✔ Route Registration
//   ✔ Route Resolution
//   ✔ Route Lookup
//   ✔ Navigation Mapping
//   ✔ Future Route Expansion
//
// DOES NOT OWN:
//   ✖ Navigation Decisions   ✖ Permission Logic
//   ✖ Business Logic         ✖ Editor Logic
//   ✖ Layer Logic            ✖ AI Logic
//   ✖ History Logic
//
// ALLOWED COMMUNICATION:
//   routes.dart → HomeScreen
//   routes.dart → GeneratorScreen
//   routes.dart → EditorScreen
//
// FORBIDDEN IMPORTS:
//   LayerEngine ❌  HistoryEngine ❌  StorageEngine ❌
//   AIEngine ❌     RenderEngine ❌   ExportEngine ❌
//   Canvas ❌
//
// FAILURE LAW:
//   Invalid route → return safe route, never crash navigation,
//   never crash application.
// ==========================================================

import 'package:flutter/material.dart';

// Screen imports — owned by their respective phases.
// Placeholder stubs are used here until each screen phase delivers its file.
import '../screens/home_screen.dart';
import '../screens/generator_screen.dart';
import '../screens/editor_screen.dart';

// ---------------------------------------------------------------------------
// ROUTE NAMES — single source of truth
// ---------------------------------------------------------------------------

/// All named application routes.
///
/// These constants are the ONLY authorised route identifiers.
/// No other file may define or duplicate these strings.
abstract final class RouteNames {
  /// Home / landing screen.
  static const String home = '/';

  /// Design generator screen.
  static const String generator = '/generator';

  /// Canvas editor screen.
  static const String editor = '/editor';

  /// Fallback safe route — used when an unknown route is requested.
  ///
  /// Points to [home] so navigation never crashes.
  static const String fallback = home;
}

// ---------------------------------------------------------------------------
// ROUTE REGISTRY
// ---------------------------------------------------------------------------

/// Central route registry for the Z-CANVAS application.
///
/// Owns route registration, lookup, and resolution.
/// Contains NO business logic, NO navigation decisions.
///
/// Usage:
/// ```dart
/// // In MaterialApp:
/// initialRoute: AppRoutes.getInitialRoute(),
/// onGenerateRoute: AppRoutes.resolveRoute,
/// ```
abstract final class AppRoutes {
  AppRoutes._(); // non-instantiable

  // -------------------------------------------------------------------------
  // Internal route table
  // -------------------------------------------------------------------------

  /// The complete route → builder mapping.
  ///
  /// Extend this map to register new routes.
  /// No logic other than route-to-builder mapping belongs here.
  static final Map<String, WidgetBuilder> _routeTable = <String, WidgetBuilder>{
    RouteNames.home: (_) => const HomeScreen(),
    RouteNames.generator: (_) => const GeneratorScreen(),
    RouteNames.editor: (_) => const EditorScreen(),
  };

  // -------------------------------------------------------------------------
  // PUBLIC API
  // -------------------------------------------------------------------------

  /// Registers all routes.
  ///
  /// Called during Step 4 of the mandatory startup sequence in app.dart.
  /// Safe to call multiple times — idempotent.
  static void registerRoutes() {
    // Route table is initialised statically; this hook exists so app.dart
    // can trigger registration in the correct startup order and for future
    // phases to attach dynamic route contributions.
    assert(_routeTable.containsKey(RouteNames.home), 'Home route must be registered.');
    assert(_routeTable.containsKey(RouteNames.generator), 'Generator route must be registered.');
    assert(_routeTable.containsKey(RouteNames.editor), 'Editor route must be registered.');
  }

  /// Returns the [WidgetBuilder] registered for [routeName].
  ///
  /// If [routeName] is not registered, returns the builder for [RouteNames.fallback].
  /// Never returns null — satisfies the failure law.
  static WidgetBuilder getRoute(String routeName) {
    return _routeTable[routeName] ?? _routeTable[RouteNames.fallback]!;
  }

  /// Returns the initial route name the application should display on launch.
  ///
  /// Always returns a valid, registered route.
  static String getInitialRoute() {
    return RouteNames.home;
  }

  /// Resolves a [RouteSettings] to a [MaterialPageRoute].
  ///
  /// Designed for use as [MaterialApp.onGenerateRoute].
  ///
  /// Failure law: unknown routes receive the fallback safe route;
  /// navigation never crashes.
  static Route<dynamic>? resolveRoute(RouteSettings settings) {
    final String routeName = settings.name ?? RouteNames.fallback;
    final WidgetBuilder builder = getRoute(routeName);

    return MaterialPageRoute<void>(
      settings: settings,
      builder: builder,
    );
  }

  // -------------------------------------------------------------------------
  // NAVIGATION HELPERS
  // -------------------------------------------------------------------------
  // These are convenience wrappers only.
  // Navigation DECISIONS belong to the caller, not to this file.

  /// Pushes [routeName] onto [navigator].
  ///
  /// Falls back to [RouteNames.home] if [routeName] is not registered,
  /// so navigation never crashes.
  static Future<T?> pushRoute<T extends Object?>(
    NavigatorState navigator,
    String routeName, {
    Object? arguments,
  }) {
    final String resolved = _routeTable.containsKey(routeName) ? routeName : RouteNames.fallback;
    return navigator.pushNamed<T>(resolved, arguments: arguments);
  }

  /// Replaces the current route with [routeName].
  ///
  /// Falls back to [RouteNames.home] on unknown routes.
  static Future<T?> replaceRoute<T extends Object?, TO extends Object?>(
    NavigatorState navigator,
    String routeName, {
    TO? result,
    Object? arguments,
  }) {
    final String resolved = _routeTable.containsKey(routeName) ? routeName : RouteNames.fallback;
    return navigator.pushReplacementNamed<T, TO>(resolved, result: result, arguments: arguments);
  }

  /// Returns `true` if [routeName] is a registered route.
  static bool isRegistered(String routeName) {
    return _routeTable.containsKey(routeName);
  }

  /// Returns an unmodifiable view of all registered route names.
  ///
  /// Intended for diagnostics and route auditing only.
  static Iterable<String> get registeredRoutes => _routeTable.keys;
}

// ---------------------------------------------------------------------------
// ROUTE FLOW (reference — enforced by screen navigation, not by this file)
// ---------------------------------------------------------------------------
//
//   HomeScreen
//         ↓
//   GeneratorScreen
//         ↓
//   EditorScreen
//
// Navigation decisions belong to the screens, not to routes.dart.
// ==========================================================
// END OF FILE — app/routes.dart
// ==========================================================
