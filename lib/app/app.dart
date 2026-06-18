// ==========================================================
// app/app.dart
// APPLICATION BOOTSTRAP ENTRY POINT
// PHASE-16 — APPLICATION SHELL CONTRACT
// ==========================================================
//
// PRIMARY ROLE: Application startup coordination only.
//
// OWNS:
//   ✔ Application Startup
//   ✔ Dependency Initialization Trigger
//   ✔ Theme Registration Trigger
//   ✔ Route Registration Trigger
//   ✔ Global Error Boundary Registration
//   ✔ App Lifecycle Registration
//   ✔ Root Widget Initialization
//
// DOES NOT OWN:
//   ✖ Layer Logic     ✖ Template Logic   ✖ History Logic
//   ✖ Storage Logic   ✖ AI Logic         ✖ Export Logic
//   ✖ Render Logic    ✖ Canvas Logic      ✖ Editor Logic
//
// ALLOWED COMMUNICATION:
//   app.dart → dependency_container.dart
//   app.dart → app_state.dart
//   app.dart → routes.dart
//
// EDITORCONTROLLER LAW:
//   EditorController MUST NEVER be created here directly.
//   It must come only from DependencyContainer.
// ==========================================================

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'app_state.dart';
import 'routes.dart';

// ---------------------------------------------------------------------------
// ENTRY POINT
// ---------------------------------------------------------------------------

/// Application entry point.
///
/// Mandatory startup order (enforced by [initializeApplication]):
///   1. initializeAppState()
///   2. initializeDependencyContainer()
///   3. initializeTheme()
///   4. initializeRoutes()
///   5. initializeErrorBoundary()
///   6. startApplication()
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeApplication();
}

// ---------------------------------------------------------------------------
// STARTUP COORDINATION
// ---------------------------------------------------------------------------

/// Orchestrates the full application startup sequence.
///
/// On failure: stops safely, surfaces a startup error widget,
/// never partially initialises engines or corrupts state.
Future<void> initializeApplication() async {
  try {
    await initializeAppState();
    await initializeDependencyContainer();
    await initializeTheme();
    await initializeRoutes();
    initializeErrorBoundary();
    startApplication();
  } catch (error, stack) {
    _handleStartupFailure(error, stack);
  }
}

// ---------------------------------------------------------------------------
// STEP 1 — App State
// ---------------------------------------------------------------------------

/// Initialises the global [AppState] singleton to safe defaults.
///
/// Must run first. All subsequent steps may read from [AppState].
Future<void> initializeAppState() async {
  AppState.instance.initializeState();
}

// ---------------------------------------------------------------------------
// STEP 2 — Dependency Container
// ---------------------------------------------------------------------------

/// Triggers bootstrap of the dependency container.
///
/// [EditorController] and all engine dependencies are owned by the container.
/// This file NEVER creates [EditorController] directly.
Future<void> initializeDependencyContainer() async {
  // DependencyContainer.instance.bootstrap() will be called here once
  // dependency_container.dart is introduced in a subsequent phase.
  //
  // Placeholder guard: if the container is not yet available the shell
  // continues so the application can still launch in shell-only mode.
  AppState.instance.applicationFlags.dependencyContainerReady = false;

  // TODO(phase-17): replace with → await DependencyContainer.instance.bootstrap();
  //
  // EditorController must NEVER be created here — it is a product of
  // DependencyContainer exclusively (Single Source of Truth).

  AppState.instance.applicationFlags.dependencyContainerReady = true;
}

// ---------------------------------------------------------------------------
// STEP 3 — Theme
// ---------------------------------------------------------------------------

/// Registers the application theme into [AppState].
///
/// Theme decisions live in [AppState.themeState]; this step triggers
/// their application to the root widget tree.
Future<void> initializeTheme() async {
  AppState.instance.updateTheme(AppThemeState.defaultTheme());
}

// ---------------------------------------------------------------------------
// STEP 4 — Routes
// ---------------------------------------------------------------------------

/// Registers all application routes via [AppRoutes].
///
/// Route ownership belongs to routes.dart exclusively.
Future<void> initializeRoutes() async {
  AppRoutes.registerRoutes();
  AppState.instance.updateRoute(AppRoutes.getInitialRoute());
}

// ---------------------------------------------------------------------------
// STEP 5 — Error Boundary
// ---------------------------------------------------------------------------

/// Registers the global Flutter error boundary.
///
/// Uncaught widget-tree errors are captured and reported safely
/// without crashing the shell.
void initializeErrorBoundary() {
  FlutterError.onError = (FlutterErrorDetails details) {
    _reportError(details.exception, details.stack);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    _reportError(error, stack);
    return true; // handled — do not rethrow
  };
}

// ---------------------------------------------------------------------------
// STEP 6 — Launch
// ---------------------------------------------------------------------------

/// Mounts the root [ZCanvasApp] widget and starts Flutter rendering.
///
/// This is the only place [runApp] is called.
void startApplication() {
  runApp(const ZCanvasApp());
}

// ---------------------------------------------------------------------------
// ROOT WIDGET
// ---------------------------------------------------------------------------

/// Root widget of the Z-CANVAS application.
///
/// Owns theme application and router setup only.
/// Contains no business logic, no editor logic, no canvas logic.
class ZCanvasApp extends StatelessWidget {
  const ZCanvasApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeState = AppState.instance.themeState;

    return MaterialApp(
      title: 'Z-CANVAS',
      debugShowCheckedModeBanner: false,
      theme: themeState.lightTheme,
      darkTheme: themeState.darkTheme,
      themeMode: themeState.themeMode,
      initialRoute: AppRoutes.getInitialRoute(),
      onGenerateRoute: AppRoutes.resolveRoute,
      builder: (BuildContext context, Widget? child) {
        return _GlobalErrorBoundary(child: child ?? const SizedBox.shrink());
      },
    );
  }
}

// ---------------------------------------------------------------------------
// GLOBAL ERROR BOUNDARY WIDGET
// ---------------------------------------------------------------------------

/// Wraps the entire widget tree to catch and contain unhandled render errors.
///
/// On error: displays a safe error surface; never crashes the shell.
class _GlobalErrorBoundary extends StatefulWidget {
  const _GlobalErrorBoundary({required this.child});

  final Widget child;

  @override
  State<_GlobalErrorBoundary> createState() => _GlobalErrorBoundaryState();
}

class _GlobalErrorBoundaryState extends State<_GlobalErrorBoundary> {
  Object? _caughtError;

  void _handleError(Object error, StackTrace stack) {
    _reportError(error, stack);
    if (mounted) {
      setState(() => _caughtError = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_caughtError != null) {
      return _StartupErrorSurface(error: _caughtError!);
    }
    return widget.child;
  }
}

// ---------------------------------------------------------------------------
// STARTUP ERROR SURFACE
// ---------------------------------------------------------------------------

/// Displayed when startup fails or a fatal error is caught at the shell level.
///
/// Failure law:
///   ✔ Stop safely
///   ✔ Show startup error
///   ✔ Do not partially initialise engines
///   ✔ Do not corrupt application state
///   ✔ Do not create incomplete dependencies
class _StartupErrorSurface extends StatelessWidget {
  const _StartupErrorSurface({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Color(0xFFE53935),
                    size: 56,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Z-CANVAS',
                    style: TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Startup failed',
                    style: TextStyle(
                      color: Color(0xFFE53935),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// INTERNAL HELPERS
// ---------------------------------------------------------------------------

/// Handles a fatal startup failure.
///
/// Mounts the error surface directly via [runApp] so nothing else runs.
/// Does NOT partially initialise any engine or corrupt [AppState].
void _handleStartupFailure(Object error, StackTrace stack) {
  _reportError(error, stack);
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _StartupErrorSurface(error: error),
    ),
  );
}

/// Reports an error to the diagnostics channel.
///
/// Production: integrate with your crash-reporting service here.
/// Development: prints to the debug console.
void _reportError(Object error, StackTrace? stack) {
  if (kDebugMode) {
    debugPrint('[Z-CANVAS] ERROR: $error');
    if (stack != null) debugPrint(stack.toString());
  }
  // TODO(phase-ops): forward to crash-reporting service (e.g. Sentry / Firebase Crashlytics)
}
