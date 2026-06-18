// app/system_bootstrap.dart
//
// PHASE-10 — SystemBootstrap
//
// ===========================================================================
// OWNERSHIP CONTRACT
// ===========================================================================
//
// WHAT THIS FILE CAN DO:
//   • Own and drive the complete application boot lifecycle
//   • Define the mandatory 12-step startup sequence
//   • Verify that all required dependencies are registered and ready
//   • Verify repository presence and readiness
//   • Verify core engine presence and readiness
//   • Verify EditorController registration
//   • Verify overall startup integrity before UI launch
//   • Generate a BootReport summarising the startup outcome
//   • Hard-stop the application if any required component fails
//
// WHAT THIS FILE CANNOT DO:
//   ❌ Execute commands
//   ❌ Modify layers
//   ❌ Modify history
//   ❌ Modify canvas
//   ❌ Modify storage
//   ❌ Perform exports
//   ❌ Contain business logic
//   ❌ Contain layer logic
//   ❌ Contain AI logic
//   ❌ Contain render logic
//   ❌ Auto-recover from boot failures
//   ❌ Skip or bypass any boot step
//   ❌ Partially start the application
//
// WHAT THIS FILE COMMUNICATES WITH:
//   ✔ DependencyRegistry — to verify registrations (read-only checks)
//   ✔ IntegrationGuard   — to run architecture validation
//   ✔ Startup caller     — returns BootResult; caller decides UI launch
//
// WHAT THIS FILE DOES NOT COMMUNICATE WITH:
//   ❌ LayerEngine directly
//   ❌ HistoryEngine directly
//   ❌ StorageEngine directly
//   ❌ RenderEngine directly
//   ❌ Canvas directly
//   ❌ Any engine or repository directly
//
// AUTHORITY: APPLICATION STARTUP AUTHORITY.
//   Boots, verifies, reports. Never executes business logic.
//   EditorController remains the only execution authority.
//
// BOOT FAILURE LAW:
//   If any required dependency fails → STOP BOOT.
//   Do NOT partially start, skip validation, auto-recover, or bypass failure.
// ===========================================================================

// ---------------------------------------------------------------------------
// SECTION 1 — ENUMERATIONS
// ---------------------------------------------------------------------------

/// The overall result category of the boot sequence.
enum BootStatus {
  /// All steps passed; application is safe to launch UI.
  success,

  /// Boot was aborted due to one or more required-dependency failures.
  failed,

  /// Boot completed but optional layers reported degraded readiness.
  degraded,
}

/// Severity of a single boot event recorded in the boot report.
enum BootEventSeverity { info, warning, error, critical }

/// Identifies which of the 12 boot steps produced a record.
enum BootStep {
  step01_initializeBootstrap,
  step02_initializeRegistry,
  step03_registerRepositories,
  step04_registerCoreEngines,
  step05_registerObservabilityLayer,
  step06_registerIntelligenceLayer,
  step07_registerExecutionGatewayLayer,
  step08_registerRuntimeGovernanceLayer,
  step09_registerEditorController,
  step10_runIntegrationGuard,
  step11_generateBootReport,
  step12_launchUI,
}

/// Readiness level reported for a single registered component.
enum ComponentReadiness {
  /// Component is registered and ready.
  ready,

  /// Component is registered but degraded (optional layers only).
  degraded,

  /// Component is not registered or failed verification.
  missing,
}

// ---------------------------------------------------------------------------
// SECTION 2 — COMPONENT REGISTRY KEYS
//
// These string constants are the canonical registration keys that
// DependencyRegistry must use. SystemBootstrap uses them to verify
// that every required component is present.
// ---------------------------------------------------------------------------

/// Canonical registration keys for all system components.
///
/// DependencyRegistry must register components under exactly these keys.
/// SystemBootstrap verifies their presence by these keys at boot time.
abstract final class RegistryKeys {
  // Repositories
  static const String layerRepository = 'LayerRepository';
  static const String historyRepository = 'HistoryRepository';
  static const String storageRepository = 'StorageRepository';
  static const String templateRepository = 'TemplateRepository';

  // Core Engines
  static const String layerEngine = 'LayerEngine';
  static const String historyEngine = 'HistoryEngine';
  static const String renderEngine = 'RenderEngine';
  static const String storageEngine = 'StorageEngine';
  static const String templateEngine = 'TemplateEngine';
  static const String exportEngine = 'ExportEngine';
  static const String syncEngine = 'SyncEngine';
  static const String aiEngine = 'AIEngine';

  // Observability Layer
  static const String telemetryEngine = 'TelemetryEngine';
  static const String debugTraceEngine = 'DebugTraceEngine';
  static const String systemHealthEngine = 'SystemHealthEngine';

  // Intelligence Layer
  static const String suggestionEngine = 'SuggestionEngine';
  static const String insightEngine = 'InsightEngine';
  static const String inputOrchestratorEngine = 'InputOrchestratorEngine';

  // Execution Gateway Layer (PHASE-8)
  static const String commandGatewayEngine = 'CommandGatewayEngine';
  static const String executionPolicyEngine = 'ExecutionPolicyEngine';
  static const String contextMemoryEngine = 'ContextMemoryEngine';

  // Runtime Governance Layer (PHASE-9)
  static const String runtimeManagerEngine = 'RuntimeManagerEngine';
  static const String resourcePolicyEngine = 'ResourcePolicyEngine';
  static const String taskSchedulerEngine = 'TaskSchedulerEngine';

  // Controller
  static const String editorController = 'EditorController';

  // ---------------------------------------------------------------------------
  // Grouped key sets for boot verification
  // ---------------------------------------------------------------------------

  /// All repository keys — required for boot.
  static const Set<String> repositories = {
    layerRepository,
    historyRepository,
    storageRepository,
    templateRepository,
  };

  /// All core engine keys — required for boot.
  static const Set<String> coreEngines = {
    layerEngine,
    historyEngine,
    renderEngine,
    storageEngine,
    templateEngine,
    exportEngine,
    syncEngine,
    aiEngine,
  };

  /// Observability layer keys — optional (failure does not stop boot).
  static const Set<String> observabilityLayer = {
    telemetryEngine,
    debugTraceEngine,
    systemHealthEngine,
  };

  /// Intelligence layer keys — optional (failure does not stop boot).
  static const Set<String> intelligenceLayer = {
    suggestionEngine,
    insightEngine,
    inputOrchestratorEngine,
  };

  /// Execution gateway layer keys — optional (failure does not stop boot).
  static const Set<String> executionGatewayLayer = {
    commandGatewayEngine,
    executionPolicyEngine,
    contextMemoryEngine,
  };

  /// Runtime governance layer keys — optional (failure does not stop boot).
  static const Set<String> runtimeGovernanceLayer = {
    runtimeManagerEngine,
    resourcePolicyEngine,
    taskSchedulerEngine,
  };

  /// EditorController key — required for boot.
  static const Set<String> controller = {editorController};
}

// ---------------------------------------------------------------------------
// SECTION 3 — ABSTRACT CONTRACTS FOR PEER PHASE-10 FILES
//
// DependencyRegistry and IntegrationGuard are implemented in their own files
// (app/dependency_registry.dart and app/integration_guard.dart).
// SystemBootstrap depends on these abstract contracts, not on concrete types,
// keeping the bootstrap self-contained and independently verifiable.
// ---------------------------------------------------------------------------

/// Contract that app/dependency_registry.dart must fulfil.
///
/// SystemBootstrap calls these methods during boot verification.
/// The registry is the single source of truth for all registered components.
abstract interface class DependencyRegistryContract {
  /// Returns true if a component is registered under [key].
  bool isRegistered(String key);

  /// Returns the registered component for [key], or null if absent.
  Object? resolve(String key);

  /// Returns a map of all registered keys to their readiness level.
  Map<String, ComponentReadiness> readinessReport();
}

/// Contract that app/integration_guard.dart must fulfil.
///
/// SystemBootstrap calls [runAllValidations] during STEP-10.
abstract interface class IntegrationGuardContract {
  /// Runs all architecture and wiring validations against [registry].
  ///
  /// Returns an [IntegrationReport] summarising findings.
  /// Must never throw — returns a failed report on internal error.
  IntegrationReport runAllValidations(DependencyRegistryContract registry);
}

// ---------------------------------------------------------------------------
// SECTION 4 — INTEGRATION REPORT (produced by IntegrationGuard)
// ---------------------------------------------------------------------------

/// Report produced by IntegrationGuard after STEP-10 validation.
final class IntegrationReport {
  const IntegrationReport({
    required this.passed,
    this.violations = const [],
    this.warnings = const [],
    this.generatedAt,
  });

  /// Creates a minimal passing report (used when guard is unavailable).
  factory IntegrationReport.passing() => IntegrationReport(
        passed: true,
        generatedAt: DateTime.now(),
      );

  /// Creates a failed report wrapping an internal error message.
  factory IntegrationReport.error(String message) => IntegrationReport(
        passed: false,
        violations: [message],
        generatedAt: DateTime.now(),
      );

  /// True when all architecture validations passed.
  final bool passed;

  /// List of architecture violation descriptions (non-empty when not passed).
  final List<String> violations;

  /// Advisory warnings that do not block boot.
  final List<String> warnings;

  final DateTime? generatedAt;
}

// ---------------------------------------------------------------------------
// SECTION 5 — BOOT EVENT AND BOOT REPORT
// ---------------------------------------------------------------------------

/// A single recorded event during the boot sequence.
final class BootEvent {
  const BootEvent({
    required this.step,
    required this.severity,
    required this.message,
    required this.timestamp,
    this.componentKey,
  });

  final BootStep step;
  final BootEventSeverity severity;
  final String message;
  final DateTime timestamp;

  /// The registry key of the component this event relates to, if applicable.
  final String? componentKey;

  @override
  String toString() =>
      '[${severity.name.toUpperCase()}] ${step.name}: $message'
      '${componentKey != null ? ' (key: $componentKey)' : ''}';
}

/// The final boot report produced in STEP-11.
///
/// Returned by [SystemBootstrap.completeStartup] to the application launcher.
/// The launcher uses [status] to decide whether to display the UI (STEP-12).
final class BootReport {
  const BootReport({
    required this.status,
    required this.generatedAt,
    required this.durationMs,
    this.events = const [],
    this.componentReadiness = const {},
    this.integrationReport,
    this.failureReason,
  });

  /// Creates a minimal failure report for unhandled exceptions during boot.
  factory BootReport.fatalError(String reason, DateTime startedAt) {
    return BootReport(
      status: BootStatus.failed,
      generatedAt: DateTime.now(),
      durationMs: DateTime.now().difference(startedAt).inMilliseconds,
      failureReason: reason,
    );
  }

  /// The overall boot outcome.
  final BootStatus status;

  /// UTC timestamp when this report was generated (end of STEP-11).
  final DateTime generatedAt;

  /// Total boot duration in milliseconds.
  final int durationMs;

  /// Ordered log of all boot events recorded across all steps.
  final List<BootEvent> events;

  /// Readiness level of each registered component at boot time.
  final Map<String, ComponentReadiness> componentReadiness;

  /// The integration guard report from STEP-10, if available.
  final IntegrationReport? integrationReport;

  /// Human-readable reason for boot failure (only set when status == failed).
  final String? failureReason;

  bool get succeeded => status == BootStatus.success;
  bool get failed => status == BootStatus.failed;
  bool get degraded => status == BootStatus.degraded;

  /// Count of events at or above [BootEventSeverity.error].
  int get errorCount => events
      .where((e) =>
          e.severity == BootEventSeverity.error ||
          e.severity == BootEventSeverity.critical)
      .length;

  @override
  String toString() =>
      'BootReport(status: ${status.name}, durationMs: $durationMs, '
      'errors: $errorCount, components: ${componentReadiness.length})';
}

// ---------------------------------------------------------------------------
// SECTION 6 — BOOT FAILURE EXCEPTION
// ---------------------------------------------------------------------------

/// Thrown internally when a required boot step fails.
///
/// This exception is caught by [SystemBootstrap.completeStartup], which
/// converts it into a [BootReport] with [BootStatus.failed] and re-throws
/// as [BootAbortedException] so the application launcher can handle it.
final class _BootStepFailure implements Exception {
  const _BootStepFailure(this.step, this.reason, {this.componentKey});
  final BootStep step;
  final String reason;
  final String? componentKey;

  @override
  String toString() =>
      'BootStepFailure at ${step.name}: $reason'
      '${componentKey != null ? ' (component: $componentKey)' : ''}';
}

/// Thrown by [SystemBootstrap.completeStartup] when boot has been aborted.
///
/// The application launcher must catch this and handle the boot failure
/// (e.g. display an error screen). It must NOT attempt to launch the UI.
final class BootAbortedException implements Exception {
  const BootAbortedException(this.report);

  /// The full boot report describing what failed.
  final BootReport report;

  @override
  String toString() =>
      'BootAbortedException: Boot aborted — ${report.failureReason}';
}

// ---------------------------------------------------------------------------
// SECTION 7 — SYSTEM BOOTSTRAP
// ---------------------------------------------------------------------------

/// SystemBootstrap — PHASE-10 Application Startup Authority
///
/// Owns and drives the complete 12-step boot sequence.
///
/// LAWS:
///   1. Boot order is FIXED — steps 01–12 must execute in exact sequence.
///   2. Required-component failure → hard abort ([BootAbortedException]).
///      No partial start. No auto-recovery. No bypass.
///   3. Optional layer failure → [BootStatus.degraded]; boot continues.
///   4. No business logic, no layer mutation, no canvas access.
///   5. EditorController remains the only execution authority.
///
/// USAGE:
/// ```dart
/// final bootstrap = SystemBootstrap(
///   registry: MyDependencyRegistry(),
///   guard:    MyIntegrationGuard(),
/// );
/// try {
///   final report = await bootstrap.completeStartup();
///   // STEP-12: caller launches UI only when report.succeeded is true.
///   launchUI();
/// } on BootAbortedException catch (e) {
///   showFatalErrorScreen(e.report);
/// }
/// ```
final class SystemBootstrap {
  SystemBootstrap({
    required DependencyRegistryContract registry,
    required IntegrationGuardContract guard,
  })  : _registry = registry,
        _guard = guard;

  final DependencyRegistryContract _registry;
  final IntegrationGuardContract _guard;

  final List<BootEvent> _events = [];
  late DateTime _bootStartedAt;

  // -------------------------------------------------------------------------
  // SECTION 7A — MANDATORY FUNCTIONS
  // -------------------------------------------------------------------------

  /// STEP-01 + driver for STEPS 02–12.
  ///
  /// Initializes the bootstrap, then invokes each boot step in the mandatory
  /// order defined by the contract. All verification and reporting happens here.
  ///
  /// Returns a [BootReport] with [BootStatus.success] or [BootStatus.degraded]
  /// when the system is ready for UI launch.
  ///
  /// Throws [BootAbortedException] if any required component is missing or
  /// if IntegrationGuard reports architecture violations.
  Future<BootReport> initializeSystem() async {
    _bootStartedAt = DateTime.now();
    _events.clear();

    _record(
      BootStep.step01_initializeBootstrap,
      BootEventSeverity.info,
      'SystemBootstrap initializing — PHASE-10 boot sequence started.',
    );

    try {
      // STEP-02: Initialize DependencyRegistry
      _record(
        BootStep.step02_initializeRegistry,
        BootEventSeverity.info,
        'DependencyRegistry initialized.',
      );

      // STEP-03: Verify repositories
      await verifyRepositories();

      // STEP-04: Verify core engines
      await verifyCoreEngines();

      // STEP-05: Verify observability layer (optional)
      _verifyOptionalLayer(
        step: BootStep.step05_registerObservabilityLayer,
        keys: RegistryKeys.observabilityLayer,
        layerName: 'Observability Layer',
      );

      // STEP-06: Verify intelligence layer (optional)
      _verifyOptionalLayer(
        step: BootStep.step06_registerIntelligenceLayer,
        keys: RegistryKeys.intelligenceLayer,
        layerName: 'Intelligence Layer',
      );

      // STEP-07: Verify execution gateway layer (optional)
      _verifyOptionalLayer(
        step: BootStep.step07_registerExecutionGatewayLayer,
        keys: RegistryKeys.executionGatewayLayer,
        layerName: 'Execution Gateway Layer',
      );

      // STEP-08: Verify runtime governance layer (optional)
      _verifyOptionalLayer(
        step: BootStep.step08_registerRuntimeGovernanceLayer,
        keys: RegistryKeys.runtimeGovernanceLayer,
        layerName: 'Runtime Governance Layer',
      );

      // STEP-09: Verify EditorController
      await verifyControllers();

      // STEP-10: Run IntegrationGuard
      final integrationReport = await _runIntegrationGuard();

      // STEP-11 + STEP-12 handled by completeStartup
      return await completeStartup(integrationReport: integrationReport);
    } on _BootStepFailure catch (e) {
      final report = BootReport.fatalError(e.reason, _bootStartedAt);
      throw BootAbortedException(report);
    } catch (e) {
      final report = BootReport.fatalError(
        'Unexpected boot error: $e',
        _bootStartedAt,
      );
      throw BootAbortedException(report);
    }
  }

  /// STEP-03 — Verifies all required repositories are registered.
  ///
  /// Throws [_BootStepFailure] if any required repository is missing.
  Future<void> verifyRepositories() async {
    _record(
      BootStep.step03_registerRepositories,
      BootEventSeverity.info,
      'Verifying repository registrations.',
    );

    for (final key in RegistryKeys.repositories) {
      _requireComponent(
        step: BootStep.step03_registerRepositories,
        key: key,
        category: 'Repository',
      );
    }

    _record(
      BootStep.step03_registerRepositories,
      BootEventSeverity.info,
      'All ${RegistryKeys.repositories.length} repositories verified.',
    );
  }

  /// STEP-04 — Verifies all required dependencies across all layers.
  ///
  /// Delegates to layer-specific verifiers. For optional layers, records
  /// warnings but does not abort.
  Future<void> verifyDependencies() async {
    await verifyCoreEngines();

    _verifyOptionalLayer(
      step: BootStep.step05_registerObservabilityLayer,
      keys: RegistryKeys.observabilityLayer,
      layerName: 'Observability Layer',
    );
    _verifyOptionalLayer(
      step: BootStep.step06_registerIntelligenceLayer,
      keys: RegistryKeys.intelligenceLayer,
      layerName: 'Intelligence Layer',
    );
    _verifyOptionalLayer(
      step: BootStep.step07_registerExecutionGatewayLayer,
      keys: RegistryKeys.executionGatewayLayer,
      layerName: 'Execution Gateway Layer',
    );
    _verifyOptionalLayer(
      step: BootStep.step08_registerRuntimeGovernanceLayer,
      keys: RegistryKeys.runtimeGovernanceLayer,
      layerName: 'Runtime Governance Layer',
    );
  }

  /// STEP-04 — Verifies all required core engines are registered.
  ///
  /// Throws [_BootStepFailure] if any required engine is missing.
  Future<void> verifyCoreEngines() async {
    _record(
      BootStep.step04_registerCoreEngines,
      BootEventSeverity.info,
      'Verifying core engine registrations.',
    );

    for (final key in RegistryKeys.coreEngines) {
      _requireComponent(
        step: BootStep.step04_registerCoreEngines,
        key: key,
        category: 'Core Engine',
      );
    }

    _record(
      BootStep.step04_registerCoreEngines,
      BootEventSeverity.info,
      'All ${RegistryKeys.coreEngines.length} core engines verified.',
    );
  }

  /// STEP-09 — Verifies EditorController is registered.
  ///
  /// Throws [_BootStepFailure] if EditorController is missing.
  Future<void> verifyControllers() async {
    _record(
      BootStep.step09_registerEditorController,
      BootEventSeverity.info,
      'Verifying EditorController registration.',
    );

    _requireComponent(
      step: BootStep.step09_registerEditorController,
      key: RegistryKeys.editorController,
      category: 'Controller',
    );

    _record(
      BootStep.step09_registerEditorController,
      BootEventSeverity.info,
      'EditorController verified — execution authority confirmed.',
    );
  }

  /// Cross-step — Validates overall startup integrity.
  ///
  /// Checks that all required component groups are accounted for.
  /// Called by [completeStartup] before generating the final report.
  ///
  /// Returns a list of integrity failure reasons (empty = all good).
  Future<List<String>> verifyStartupIntegrity() async {
    final failures = <String>[];

    void checkGroup(Set<String> keys, String groupName) {
      for (final key in keys) {
        if (!_registry.isRegistered(key)) {
          failures.add('$groupName missing required component: $key');
        }
      }
    }

    checkGroup(RegistryKeys.repositories, 'Repositories');
    checkGroup(RegistryKeys.coreEngines, 'Core Engines');
    checkGroup(RegistryKeys.controller, 'Controller');

    return failures;
  }

  /// STEP-11 — Generates the boot report.
  ///
  /// Aggregates all recorded boot events, component readiness data, and
  /// the integration report into a [BootReport].
  Future<BootReport> generateBootReport({
    required IntegrationReport integrationReport,
  }) async {
    _record(
      BootStep.step11_generateBootReport,
      BootEventSeverity.info,
      'Generating boot report.',
    );

    final componentReadiness = _registry.readinessReport();

    final hasDegradedOptional = componentReadiness.values
        .any((r) => r == ComponentReadiness.degraded);

    final hasCriticalErrors = _events.any(
      (e) => e.severity == BootEventSeverity.critical,
    );

    BootStatus status;
    if (hasCriticalErrors || !integrationReport.passed) {
      status = BootStatus.failed;
    } else if (hasDegradedOptional) {
      status = BootStatus.degraded;
    } else {
      status = BootStatus.success;
    }

    if (integrationReport.warnings.isNotEmpty) {
      for (final w in integrationReport.warnings) {
        _record(
          BootStep.step11_generateBootReport,
          BootEventSeverity.warning,
          'IntegrationGuard advisory: $w',
        );
      }
    }

    return BootReport(
      status: status,
      generatedAt: DateTime.now(),
      durationMs: DateTime.now().difference(_bootStartedAt).inMilliseconds,
      events: List.unmodifiable(_events),
      componentReadiness: Map.unmodifiable(componentReadiness),
      integrationReport: integrationReport,
      failureReason: status == BootStatus.failed
          ? (integrationReport.passed
              ? 'One or more critical boot events failed.'
              : 'Architecture validation failed: '
                  '${integrationReport.violations.join('; ')}')
          : null,
    );
  }

  /// STEP-11 → STEP-12 — Finalises startup and signals UI launch readiness.
  ///
  /// Performs a final integrity check, generates the boot report, then
  /// either returns the report (success/degraded) or throws
  /// [BootAbortedException] (failed).
  ///
  /// STEP-12 (launching the UI) is the responsibility of the caller —
  /// this engine only confirms that it is safe to do so.
  Future<BootReport> completeStartup({
    required IntegrationReport integrationReport,
  }) async {
    // Final integrity sweep
    final integrityFailures = await verifyStartupIntegrity();
    for (final failure in integrityFailures) {
      _record(
        BootStep.step11_generateBootReport,
        BootEventSeverity.critical,
        failure,
      );
    }

    final report = await generateBootReport(
      integrationReport: integrationReport,
    );

    if (report.failed) {
      _record(
        BootStep.step12_launchUI,
        BootEventSeverity.critical,
        'Boot aborted — UI launch blocked. '
            'Reason: ${report.failureReason}',
      );
      throw BootAbortedException(report);
    }

    _record(
      BootStep.step12_launchUI,
      BootEventSeverity.info,
      'Boot ${report.status.name} — system is ready. '
          'Caller may now launch UI (STEP-12).',
    );

    return report;
  }

  // -------------------------------------------------------------------------
  // SECTION 7B — PRIVATE HELPERS
  // -------------------------------------------------------------------------

  /// STEP-10 — Runs IntegrationGuard validation.
  Future<IntegrationReport> _runIntegrationGuard() async {
    _record(
      BootStep.step10_runIntegrationGuard,
      BootEventSeverity.info,
      'Running IntegrationGuard architecture validation.',
    );

    IntegrationReport report;
    try {
      report = _guard.runAllValidations(_registry);
    } catch (e) {
      report = IntegrationReport.error(
        'IntegrationGuard threw an unexpected error: $e',
      );
    }

    if (report.passed) {
      _record(
        BootStep.step10_runIntegrationGuard,
        BootEventSeverity.info,
        'IntegrationGuard validation passed. '
            'Warnings: ${report.warnings.length}.',
      );
    } else {
      for (final violation in report.violations) {
        _record(
          BootStep.step10_runIntegrationGuard,
          BootEventSeverity.critical,
          'Architecture violation: $violation',
        );
      }
      throw _BootStepFailure(
        BootStep.step10_runIntegrationGuard,
        'IntegrationGuard detected architecture violations. Boot aborted.',
      );
    }

    return report;
  }

  /// Requires that a component is registered under [key].
  ///
  /// Throws [_BootStepFailure] if the component is missing.
  void _requireComponent({
    required BootStep step,
    required String key,
    required String category,
  }) {
    if (_registry.isRegistered(key)) {
      _record(
        step,
        BootEventSeverity.info,
        '$category verified: $key',
        componentKey: key,
      );
    } else {
      _record(
        step,
        BootEventSeverity.critical,
        '$category missing — required component not registered: $key',
        componentKey: key,
      );
      throw _BootStepFailure(
        step,
        'Required $category not registered: $key. '
            'Boot cannot continue.',
        componentKey: key,
      );
    }
  }

  /// Verifies an optional layer. Missing or degraded components produce
  /// warnings but do NOT abort boot.
  void _verifyOptionalLayer({
    required BootStep step,
    required Set<String> keys,
    required String layerName,
  }) {
    _record(step, BootEventSeverity.info, 'Verifying $layerName.');

    int missing = 0;
    for (final key in keys) {
      if (_registry.isRegistered(key)) {
        _record(
          step,
          BootEventSeverity.info,
          '$layerName component verified: $key',
          componentKey: key,
        );
      } else {
        missing++;
        _record(
          step,
          BootEventSeverity.warning,
          '$layerName component not registered (optional): $key — '
              'layer will operate in degraded mode.',
          componentKey: key,
        );
      }
    }

    if (missing == 0) {
      _record(step, BootEventSeverity.info, '$layerName fully ready.');
    } else {
      _record(
        step,
        BootEventSeverity.warning,
        '$layerName degraded — $missing of ${keys.length} component(s) '
            'missing. Editor remains operational.',
      );
    }
  }

  void _record(
    BootStep step,
    BootEventSeverity severity,
    String message, {
    String? componentKey,
  }) {
    _events.add(BootEvent(
      step: step,
      severity: severity,
      message: message,
      timestamp: DateTime.now(),
      componentKey: componentKey,
    ));
  }
}
