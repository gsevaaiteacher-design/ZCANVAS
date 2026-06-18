// app/dependency_registry.dart
//
// PHASE-10 — DependencyRegistry
//
// ===========================================================================
// OWNERSHIP CONTRACT
// ===========================================================================
//
// WHAT THIS FILE CAN DO:
//   • Be the single source of truth for every registered system object
//   • Accept registrations for all repositories, engines, and controllers
//   • Resolve registered objects by canonical key
//   • Validate that all mandatory components are registered
//   • Enforce singleton ownership — one instance per key, no overwrites
//   • Track readiness level of each registered component
//   • Report registration status to SystemBootstrap
//   • Provide typed resolution helpers per component group
//
// WHAT THIS FILE CANNOT DO:
//   ❌ Execute commands
//   ❌ Contain business logic
//   ❌ Contain layer mutation logic
//   ❌ Contain rendering logic
//   ❌ Create objects outside of registration calls
//   ❌ Allow any component to be instantiated outside this registry
//   ❌ Allow duplicate registration of the same key
//   ❌ Allow overwriting an existing registration
//
// WHAT THIS FILE COMMUNICATES WITH:
//   ✔ SystemBootstrap — provides isRegistered(), resolve(), readinessReport()
//   ✔ IntegrationGuard — provides read-only access to the registry state
//
// WHAT THIS FILE DOES NOT COMMUNICATE WITH:
//   ❌ LayerEngine directly
//   ❌ Canvas directly
//   ❌ Any UI component
//   ❌ Any storage system
//
// AUTHORITY: SINGLE DEPENDENCY AUTHORITY.
//   Every object in the system must be registered here.
//   No object may create its own dependencies.
//   All dependencies must come from DependencyRegistry only.
//
// STRICT REGISTRY LAW:
//   new LayerEngine()       outside DependencyRegistry ❌
//   new HistoryEngine()     outside DependencyRegistry ❌
//   new StorageEngine()     outside DependencyRegistry ❌
//   new EditorController()  outside DependencyRegistry ❌
// ===========================================================================

import 'system_bootstrap.dart'
    show
        ComponentReadiness,
        DependencyRegistryContract,
        RegistryKeys;

// ---------------------------------------------------------------------------
// SECTION 1 — REGISTRATION RECORD
// ---------------------------------------------------------------------------

/// Metadata record for a single registered component.
final class _RegistrationRecord {
  _RegistrationRecord({
    required this.key,
    required this.instance,
    required this.readiness,
    required this.registeredAt,
    required this.group,
  });

  final String key;
  final Object instance;
  ComponentReadiness readiness;
  final DateTime registeredAt;

  /// Group label for reporting (e.g. 'Repository', 'Core Engine').
  final String group;
}

// ---------------------------------------------------------------------------
// SECTION 2 — REGISTRY EXCEPTIONS
// ---------------------------------------------------------------------------

/// Thrown when an attempt is made to register a key that is already taken.
final class DuplicateRegistrationException implements Exception {
  const DuplicateRegistrationException(this.key);
  final String key;

  @override
  String toString() =>
      'DuplicateRegistrationException: "$key" is already registered. '
      'The registry enforces singleton ownership — no overwrites permitted.';
}

/// Thrown when resolve() is called for a key that has no registration.
final class UnregisteredDependencyException implements Exception {
  const UnregisteredDependencyException(this.key);
  final String key;

  @override
  String toString() =>
      'UnregisteredDependencyException: No component registered under "$key". '
      'All dependencies must be registered via DependencyRegistry.';
}

/// Thrown when a mandatory registration group is incomplete.
final class IncompleteRegistrationException implements Exception {
  const IncompleteRegistrationException(this.missingKeys);
  final List<String> missingKeys;

  @override
  String toString() =>
      'IncompleteRegistrationException: The following required components are '
      'not registered: ${missingKeys.join(', ')}';
}

// ---------------------------------------------------------------------------
// SECTION 3 — REGISTRATION RESULT
// ---------------------------------------------------------------------------

/// Returned by [DependencyRegistry.register] to confirm the outcome.
final class RegistrationResult {
  const RegistrationResult({
    required this.key,
    required this.succeeded,
    this.reason,
  });

  final String key;
  final bool succeeded;

  /// Failure reason if [succeeded] is false.
  final String? reason;

  @override
  String toString() =>
      'RegistrationResult(key: $key, succeeded: $succeeded'
      '${reason != null ? ', reason: $reason' : ''})';
}

// ---------------------------------------------------------------------------
// SECTION 4 — VALIDATION REPORT
// ---------------------------------------------------------------------------

/// Produced by [DependencyRegistry.validateRegistrations].
final class RegistrationValidationReport {
  const RegistrationValidationReport({
    required this.isComplete,
    required this.totalRegistered,
    this.missingRequired = const [],
    this.missingOptional = const [],
    this.allKeys = const [],
  });

  /// True when all required registrations (repositories, core engines,
  /// EditorController) are present.
  final bool isComplete;

  final int totalRegistered;

  /// Required keys that are absent (boot must fail if non-empty).
  final List<String> missingRequired;

  /// Optional keys that are absent (boot may continue in degraded mode).
  final List<String> missingOptional;

  /// All currently registered keys.
  final List<String> allKeys;

  @override
  String toString() =>
      'RegistrationValidationReport(complete: $isComplete, '
      'registered: $totalRegistered, '
      'missingRequired: ${missingRequired.length}, '
      'missingOptional: ${missingOptional.length})';
}

// ---------------------------------------------------------------------------
// SECTION 5 — DEPENDENCY REGISTRY
// ---------------------------------------------------------------------------

/// DependencyRegistry — PHASE-10 Single Dependency Authority
///
/// Every object in the system must be registered here.
/// No object may create its own dependencies — all must come from here.
///
/// LAWS:
///   1. SINGLETON OWNERSHIP — one registration per key; no overwrites.
///   2. NO EXECUTION — the registry stores and resolves; it never runs logic.
///   3. NO BUSINESS LOGIC — registration keys, not behaviour.
///   4. FAILURE SAFE — resolution errors throw typed exceptions; never
///      return null silently for registered components.
///   5. IMMUTABLE AFTER LOCK — once [lock] is called, no new registrations
///      are accepted. SystemBootstrap locks the registry after STEP-09.
///
/// Implements [DependencyRegistryContract] so SystemBootstrap can verify
/// component presence without depending on this concrete type directly.
final class DependencyRegistry implements DependencyRegistryContract {
  DependencyRegistry();

  final Map<String, _RegistrationRecord> _store = {};
  bool _locked = false;

  // -------------------------------------------------------------------------
  // SECTION 5A — REGISTRATION
  // -------------------------------------------------------------------------

  /// Registers [instance] under [key].
  ///
  /// [group] is a human-readable category label used in reports.
  /// [readiness] defaults to [ComponentReadiness.ready].
  ///
  /// Throws [DuplicateRegistrationException] if [key] is already registered.
  /// Throws [StateError] if the registry has been locked.
  ///
  /// Returns a [RegistrationResult] confirming success.
  RegistrationResult register(
    String key,
    Object instance, {
    required String group,
    ComponentReadiness readiness = ComponentReadiness.ready,
  }) {
    if (_locked) {
      throw StateError(
        'DependencyRegistry is locked. '
        'No new registrations are accepted after SystemBootstrap completes '
        'STEP-09. Attempted to register: "$key".',
      );
    }

    if (_store.containsKey(key)) {
      throw DuplicateRegistrationException(key);
    }

    _store[key] = _RegistrationRecord(
      key: key,
      instance: instance,
      readiness: readiness,
      registeredAt: DateTime.now(),
      group: group,
    );

    return RegistrationResult(key: key, succeeded: true);
  }

  /// Registers [instance] under [key] with [ComponentReadiness.degraded].
  ///
  /// Use for optional-layer components that are present but known to be
  /// limited in capability.
  RegistrationResult registerDegraded(
    String key,
    Object instance, {
    required String group,
  }) {
    return register(key, instance,
        group: group, readiness: ComponentReadiness.degraded);
  }

  // -------------------------------------------------------------------------
  // SECTION 5B — RESOLUTION
  // -------------------------------------------------------------------------

  /// Returns true if a component is registered under [key].
  @override
  bool isRegistered(String key) => _store.containsKey(key);

  /// Returns the registered instance for [key], or null if absent.
  ///
  /// Prefer [resolveRequired] for components that must be present.
  @override
  Object? resolve(String key) => _store[key]?.instance;

  /// Returns the registered instance for [key].
  ///
  /// Throws [UnregisteredDependencyException] if [key] is not registered.
  Object resolveRequired(String key) {
    final record = _store[key];
    if (record == null) throw UnregisteredDependencyException(key);
    return record.instance;
  }

  /// Returns the registered instance cast to [T].
  ///
  /// Throws [UnregisteredDependencyException] if absent.
  /// Throws [TypeError] if the registered instance is not assignable to [T].
  T resolveAs<T>(String key) => resolveRequired(key) as T;

  // -------------------------------------------------------------------------
  // SECTION 5C — TYPED RESOLUTION HELPERS (per mandatory group)
  //
  // Each helper resolves the canonical key and returns the raw Object.
  // Callers cast to their concrete type. This keeps the registry free of
  // any concrete engine imports while still providing a clear resolution API.
  // -------------------------------------------------------------------------

  // Repositories

  Object get layerRepository =>
      resolveRequired(RegistryKeys.layerRepository);

  Object get historyRepository =>
      resolveRequired(RegistryKeys.historyRepository);

  Object get storageRepository =>
      resolveRequired(RegistryKeys.storageRepository);

  Object get templateRepository =>
      resolveRequired(RegistryKeys.templateRepository);

  // Core Engines

  Object get layerEngine =>
      resolveRequired(RegistryKeys.layerEngine);

  Object get historyEngine =>
      resolveRequired(RegistryKeys.historyEngine);

  Object get renderEngine =>
      resolveRequired(RegistryKeys.renderEngine);

  Object get storageEngine =>
      resolveRequired(RegistryKeys.storageEngine);

  Object get templateEngine =>
      resolveRequired(RegistryKeys.templateEngine);

  Object get exportEngine =>
      resolveRequired(RegistryKeys.exportEngine);

  Object get syncEngine =>
      resolveRequired(RegistryKeys.syncEngine);

  Object get aiEngine =>
      resolveRequired(RegistryKeys.aiEngine);

  // Observability Layer

  Object get telemetryEngine =>
      resolveRequired(RegistryKeys.telemetryEngine);

  Object get debugTraceEngine =>
      resolveRequired(RegistryKeys.debugTraceEngine);

  Object get systemHealthEngine =>
      resolveRequired(RegistryKeys.systemHealthEngine);

  // Intelligence Layer

  Object get suggestionEngine =>
      resolveRequired(RegistryKeys.suggestionEngine);

  Object get insightEngine =>
      resolveRequired(RegistryKeys.insightEngine);

  Object get inputOrchestratorEngine =>
      resolveRequired(RegistryKeys.inputOrchestratorEngine);

  // Execution Gateway Layer (PHASE-8)

  Object get commandGatewayEngine =>
      resolveRequired(RegistryKeys.commandGatewayEngine);

  Object get executionPolicyEngine =>
      resolveRequired(RegistryKeys.executionPolicyEngine);

  Object get contextMemoryEngine =>
      resolveRequired(RegistryKeys.contextMemoryEngine);

  // Runtime Governance Layer (PHASE-9)

  Object get runtimeManagerEngine =>
      resolveRequired(RegistryKeys.runtimeManagerEngine);

  Object get resourcePolicyEngine =>
      resolveRequired(RegistryKeys.resourcePolicyEngine);

  Object get taskSchedulerEngine =>
      resolveRequired(RegistryKeys.taskSchedulerEngine);

  // Controller

  Object get editorController =>
      resolveRequired(RegistryKeys.editorController);

  // -------------------------------------------------------------------------
  // SECTION 5D — VALIDATION
  // -------------------------------------------------------------------------

  /// Validates that all mandatory registrations are present.
  ///
  /// Returns a [RegistrationValidationReport] summarising completeness.
  /// Does NOT throw — callers inspect [RegistrationValidationReport.isComplete].
  RegistrationValidationReport validateRegistrations() {
    final required = {
      ...RegistryKeys.repositories,
      ...RegistryKeys.coreEngines,
      ...RegistryKeys.controller,
    };

    final optional = {
      ...RegistryKeys.observabilityLayer,
      ...RegistryKeys.intelligenceLayer,
      ...RegistryKeys.executionGatewayLayer,
      ...RegistryKeys.runtimeGovernanceLayer,
    };

    final missingRequired = required
        .where((k) => !_store.containsKey(k))
        .toList(growable: false);

    final missingOptional = optional
        .where((k) => !_store.containsKey(k))
        .toList(growable: false);

    return RegistrationValidationReport(
      isComplete: missingRequired.isEmpty,
      totalRegistered: _store.length,
      missingRequired: missingRequired,
      missingOptional: missingOptional,
      allKeys: List.unmodifiable(_store.keys.toList()),
    );
  }

  /// Asserts that all required registrations are present.
  ///
  /// Throws [IncompleteRegistrationException] if any required key is absent.
  void assertComplete() {
    final report = validateRegistrations();
    if (!report.isComplete) {
      throw IncompleteRegistrationException(report.missingRequired);
    }
  }

  // -------------------------------------------------------------------------
  // SECTION 5E — LIFECYCLE
  // -------------------------------------------------------------------------

  /// Locks the registry, preventing any further registrations.
  ///
  /// SystemBootstrap calls this after STEP-09 (EditorController registered).
  /// Subsequent calls to [register] will throw a [StateError].
  void lock() {
    _locked = true;
  }

  /// True after [lock] has been called.
  bool get isLocked => _locked;

  /// Updates the readiness level of an already-registered component.
  ///
  /// This is the only mutation permitted after [lock]. Readiness levels
  /// may be downgraded (e.g. to [ComponentReadiness.degraded]) by the
  /// health monitoring system at runtime.
  ///
  /// Throws [UnregisteredDependencyException] if [key] is not found.
  void updateReadiness(String key, ComponentReadiness readiness) {
    final record = _store[key];
    if (record == null) throw UnregisteredDependencyException(key);
    record.readiness = readiness;
  }

  // -------------------------------------------------------------------------
  // SECTION 5F — DependencyRegistryContract IMPLEMENTATION
  // -------------------------------------------------------------------------

  /// Returns a snapshot of every registered component's readiness level.
  ///
  /// Used by SystemBootstrap (STEP-11) to build the [BootReport].
  @override
  Map<String, ComponentReadiness> readinessReport() {
    return Map.unmodifiable(
      _store.map((key, record) => MapEntry(key, record.readiness)),
    );
  }

  // -------------------------------------------------------------------------
  // SECTION 5G — INSPECTION (read-only, for IntegrationGuard)
  // -------------------------------------------------------------------------

  /// Returns all registered keys.
  List<String> get allKeys => List.unmodifiable(_store.keys);

  /// Returns registration metadata for [key], or null if absent.
  ({String key, String group, ComponentReadiness readiness, DateTime registeredAt})?
      inspectRecord(String key) {
    final r = _store[key];
    if (r == null) return null;
    return (
      key: r.key,
      group: r.group,
      readiness: r.readiness,
      registeredAt: r.registeredAt,
    );
  }

  /// Returns all registered keys belonging to [group].
  List<String> keysForGroup(String group) => _store.entries
      .where((e) => e.value.group == group)
      .map((e) => e.key)
      .toList(growable: false);

  /// Total number of registered components.
  int get count => _store.length;

  @override
  String toString() =>
      'DependencyRegistry(count: $count, locked: $_locked)';
}

// ---------------------------------------------------------------------------
// SECTION 6 — REGISTRATION GROUP LABELS
//
// Canonical group name constants used when calling register().
// These labels appear in boot reports and integration reports.
// ---------------------------------------------------------------------------

/// Canonical group labels for use in [DependencyRegistry.register] calls.
abstract final class RegistrationGroups {
  static const String repository = 'Repository';
  static const String coreEngine = 'Core Engine';
  static const String observability = 'Observability Layer';
  static const String intelligence = 'Intelligence Layer';
  static const String executionGateway = 'Execution Gateway Layer';
  static const String runtimeGovernance = 'Runtime Governance Layer';
  static const String controller = 'Controller';
}
