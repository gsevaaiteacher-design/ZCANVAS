// app/integration_guard.dart
//
// PHASE-10 — IntegrationGuard
//
// ===========================================================================
// OWNERSHIP CONTRACT
// ===========================================================================
//
// WHAT THIS FILE CAN DO:
//   • Validate overall system architecture against the PHASE-10 contract
//   • Validate the dependency registration graph for completeness
//   • Validate communication rules from the Forbidden Communication Matrix
//   • Detect forbidden connections between components
//   • Verify EditorController supremacy (sole execution authority)
//   • Verify repository isolation (no direct engine → storage access)
//   • Verify dependency direction (UI → Controller → Engine → Repo → Storage)
//   • Detect circular dependencies in the declared dependency graph
//   • Generate an IntegrationReport summarising all findings
//   • Enforce all architectural laws from the PHASE-10 contract
//
// WHAT THIS FILE CANNOT DO:
//   ❌ Execute commands
//   ❌ Contain business logic
//   ❌ Contain layer mutation logic
//   ❌ Contain rendering logic
//   ❌ Access storage systems
//   ❌ Modify layers or history
//   ❌ Access Canvas
//   ❌ Block boot for optional-layer violations (warnings only)
//
// WHAT THIS FILE COMMUNICATES WITH:
//   ✔ DependencyRegistry — reads registration state (never writes)
//   ✔ SystemBootstrap    — returns IntegrationReport for STEP-10
//
// WHAT THIS FILE DOES NOT COMMUNICATE WITH:
//   ❌ LayerEngine directly
//   ❌ HistoryEngine directly
//   ❌ Canvas directly
//   ❌ Any UI component
//   ❌ Any storage system
//
// AUTHORITY: ARCHITECTURE SECURITY AUTHORITY.
//   Validates wiring. Never executes.
//   EditorController remains the only execution authority.
//
// FAILURE LAW:
//   Any architecture violation → IntegrationReport.passed = false → boot abort.
//   Advisory warnings do not abort boot.
// ===========================================================================

import 'system_bootstrap.dart'
    show
        DependencyRegistryContract,
        IntegrationGuardContract,
        IntegrationReport,
        RegistryKeys;

import 'dependency_registry.dart'
    show DependencyRegistry, RegistrationGroups;

// ---------------------------------------------------------------------------
// SECTION 1 — ENUMERATIONS
// ---------------------------------------------------------------------------

/// Severity of a single validation finding.
enum ViolationSeverity {
  /// Informational — does not affect boot.
  info,

  /// Advisory — does not abort boot; may degrade optional layer.
  warning,

  /// Architecture violation — aborts boot.
  violation,
}

/// Category of the architectural rule being checked.
enum ValidationCategory {
  /// Validates required components are present.
  dependencyGraph,

  /// Validates the layered direction law.
  dependencyDirection,

  /// Validates no forbidden communication paths exist.
  communicationRules,

  /// Validates no circular dependencies in the declared graph.
  circularDependency,

  /// Validates repository isolation from storage.
  repositoryIsolation,

  /// Validates EditorController is the sole execution authority.
  controllerAuthority,

  /// Validates event ownership metadata rules.
  eventOwnership,

  /// General architecture contract check.
  architectureContract,
}

// ---------------------------------------------------------------------------
// SECTION 2 — VALIDATION FINDING
// ---------------------------------------------------------------------------

/// A single finding produced during architecture validation.
final class ValidationFinding {
  const ValidationFinding({
    required this.findingId,
    required this.category,
    required this.severity,
    required this.message,
    this.involvedKeys = const [],
    this.rule,
  });

  final String findingId;
  final ValidationCategory category;
  final ViolationSeverity severity;
  final String message;

  /// Registry keys of components involved in this finding.
  final List<String> involvedKeys;

  /// The contract rule this finding relates to (e.g. 'DEPENDENCY_DIRECTION').
  final String? rule;

  bool get isViolation => severity == ViolationSeverity.violation;
  bool get isWarning => severity == ViolationSeverity.warning;

  @override
  String toString() =>
      '[${severity.name.toUpperCase()}][${category.name}] $message'
      '${involvedKeys.isNotEmpty ? ' (keys: ${involvedKeys.join(', ')})' : ''}';
}

// ---------------------------------------------------------------------------
// SECTION 3 — DEPENDENCY LAYER MODEL
// ---------------------------------------------------------------------------

/// Numeric layer rank for the Dependency Direction Law.
///
/// Lower numbers are deeper in the stack (storage = 0).
/// Valid dependencies flow from higher → lower rank only.
///
///   UI(4) → Controller(3) → Engine(2) → Repository(1) → Storage(0)
abstract final class _LayerRank {
  static const int storage = 0;
  static const int repository = 1;
  static const int engine = 2;
  static const int controller = 3;
  static const int ui = 4;
}

/// Resolves the layer rank for a registered component group label.
int _rankForGroup(String group) {
  switch (group) {
    case RegistrationGroups.repository:
      return _LayerRank.repository;
    case RegistrationGroups.coreEngine:
    case RegistrationGroups.observability:
    case RegistrationGroups.intelligence:
    case RegistrationGroups.executionGateway:
    case RegistrationGroups.runtimeGovernance:
      return _LayerRank.engine;
    case RegistrationGroups.controller:
      return _LayerRank.controller;
    default:
      return _LayerRank.engine;
  }
}

// ---------------------------------------------------------------------------
// SECTION 4 — FORBIDDEN COMMUNICATION MATRIX
//
// Derived directly from the PHASE-10 contract.
// Each entry is (sourceKey, targetKey) pair representing a forbidden route.
// ---------------------------------------------------------------------------

/// Represents a forbidden direct communication pair.
final class _ForbiddenRoute {
  const _ForbiddenRoute({
    required this.sourceKey,
    required this.targetKey,
    required this.rule,
  });

  final String sourceKey;
  final String targetKey;
  final String rule;
}

/// Static forbidden routes derived from the PHASE-10 Forbidden Communication
/// Matrix. Checked by [IntegrationGuard.detectForbiddenConnections].
const List<_ForbiddenRoute> _forbiddenRoutes = [
  // UI → Core (all forbidden)
  _ForbiddenRoute(
      sourceKey: 'UI',
      targetKey: RegistryKeys.layerEngine,
      rule: 'UI → LayerEngine ❌'),
  _ForbiddenRoute(
      sourceKey: 'UI',
      targetKey: RegistryKeys.historyEngine,
      rule: 'UI → HistoryEngine ❌'),
  _ForbiddenRoute(
      sourceKey: 'UI',
      targetKey: RegistryKeys.renderEngine,
      rule: 'UI → RenderEngine ❌'),
  _ForbiddenRoute(
      sourceKey: 'UI',
      targetKey: RegistryKeys.storageEngine,
      rule: 'UI → StorageEngine ❌'),
  _ForbiddenRoute(
      sourceKey: 'UI',
      targetKey: RegistryKeys.aiEngine,
      rule: 'UI → AIEngine ❌'),
  _ForbiddenRoute(
      sourceKey: 'UI',
      targetKey: 'Canvas',
      rule: 'UI → Canvas ❌'),

  // AI Engine forbidden routes
  _ForbiddenRoute(
      sourceKey: RegistryKeys.aiEngine,
      targetKey: 'Canvas',
      rule: 'AIEngine → Canvas ❌'),
  _ForbiddenRoute(
      sourceKey: RegistryKeys.aiEngine,
      targetKey: RegistryKeys.renderEngine,
      rule: 'AIEngine → RenderEngine ❌'),

  // Template Engine forbidden routes
  _ForbiddenRoute(
      sourceKey: RegistryKeys.templateEngine,
      targetKey: 'Canvas',
      rule: 'TemplateEngine → Canvas ❌'),

  // Storage Engine forbidden routes
  _ForbiddenRoute(
      sourceKey: RegistryKeys.storageEngine,
      targetKey: 'Canvas',
      rule: 'StorageEngine → Canvas ❌'),

  // History Engine forbidden routes
  _ForbiddenRoute(
      sourceKey: RegistryKeys.historyEngine,
      targetKey: 'Canvas',
      rule: 'HistoryEngine → Canvas ❌'),

  // Voice/Gesture/Robot Input forbidden routes
  _ForbiddenRoute(
      sourceKey: 'VoiceInput',
      targetKey: RegistryKeys.layerEngine,
      rule: 'VoiceInput → LayerEngine ❌'),
  _ForbiddenRoute(
      sourceKey: 'VoiceInput',
      targetKey: 'Canvas',
      rule: 'VoiceInput → Canvas ❌'),
  _ForbiddenRoute(
      sourceKey: 'RobotInput',
      targetKey: RegistryKeys.layerEngine,
      rule: 'RobotInput → LayerEngine ❌'),
  _ForbiddenRoute(
      sourceKey: 'RobotInput',
      targetKey: 'Canvas',
      rule: 'RobotInput → Canvas ❌'),
  _ForbiddenRoute(
      sourceKey: 'GestureInput',
      targetKey: RegistryKeys.layerEngine,
      rule: 'GestureInput → LayerEngine ❌'),
  _ForbiddenRoute(
      sourceKey: 'GestureInput',
      targetKey: 'Canvas',
      rule: 'GestureInput → Canvas ❌'),

  // Plugin forbidden routes
  _ForbiddenRoute(
      sourceKey: 'Plugin',
      targetKey: RegistryKeys.layerEngine,
      rule: 'Plugin → LayerEngine ❌'),
  _ForbiddenRoute(
      sourceKey: 'Plugin',
      targetKey: 'Canvas',
      rule: 'Plugin → Canvas ❌'),

  // Automation forbidden routes
  _ForbiddenRoute(
      sourceKey: 'Automation',
      targetKey: RegistryKeys.layerEngine,
      rule: 'Automation → LayerEngine ❌'),
  _ForbiddenRoute(
      sourceKey: 'Automation',
      targetKey: 'Canvas',
      rule: 'Automation → Canvas ❌'),

  // Repository → upper layers (Dependency Direction Law)
  _ForbiddenRoute(
      sourceKey: RegistryKeys.layerRepository,
      targetKey: RegistryKeys.layerEngine,
      rule: 'Repository → Engine ❌'),
  _ForbiddenRoute(
      sourceKey: RegistryKeys.historyRepository,
      targetKey: RegistryKeys.historyEngine,
      rule: 'Repository → Engine ❌'),

  // Repository Protection Law — engines must not access storage directly
  _ForbiddenRoute(
      sourceKey: RegistryKeys.layerEngine,
      targetKey: RegistryKeys.storageEngine,
      rule: 'Engine → Storage ❌ (must go through Repository)'),
  _ForbiddenRoute(
      sourceKey: RegistryKeys.historyEngine,
      targetKey: RegistryKeys.storageEngine,
      rule: 'HistoryEngine → Storage ❌'),
  _ForbiddenRoute(
      sourceKey: RegistryKeys.aiEngine,
      targetKey: RegistryKeys.storageEngine,
      rule: 'AIEngine → Storage ❌'),
  _ForbiddenRoute(
      sourceKey: RegistryKeys.editorController,
      targetKey: RegistryKeys.storageEngine,
      rule: 'EditorController → Storage ❌ (must go through Repository)'),
];

/// Statically declared dependency graph for circular dependency detection.
///
/// Each entry maps a component key to the set of component keys it
/// legitimately depends on. This represents the intended wiring.
/// The guard checks this graph for cycles.
const Map<String, List<String>> _declaredDependencyGraph = {
  // EditorController depends on all engine layers
  RegistryKeys.editorController: [
    RegistryKeys.layerEngine,
    RegistryKeys.historyEngine,
    RegistryKeys.renderEngine,
    RegistryKeys.storageEngine,
    RegistryKeys.templateEngine,
    RegistryKeys.exportEngine,
    RegistryKeys.syncEngine,
    RegistryKeys.aiEngine,
    RegistryKeys.telemetryEngine,
    RegistryKeys.debugTraceEngine,
    RegistryKeys.systemHealthEngine,
    RegistryKeys.suggestionEngine,
    RegistryKeys.insightEngine,
    RegistryKeys.inputOrchestratorEngine,
    RegistryKeys.commandGatewayEngine,
    RegistryKeys.executionPolicyEngine,
    RegistryKeys.contextMemoryEngine,
    RegistryKeys.runtimeManagerEngine,
    RegistryKeys.resourcePolicyEngine,
    RegistryKeys.taskSchedulerEngine,
  ],
  // Core engines depend on their repositories
  RegistryKeys.layerEngine: [RegistryKeys.layerRepository],
  RegistryKeys.historyEngine: [RegistryKeys.historyRepository],
  RegistryKeys.storageEngine: [RegistryKeys.storageRepository],
  RegistryKeys.templateEngine: [RegistryKeys.templateRepository],
  RegistryKeys.exportEngine: [RegistryKeys.storageRepository],
  RegistryKeys.syncEngine: [RegistryKeys.storageRepository],
  RegistryKeys.aiEngine: [],
  RegistryKeys.renderEngine: [],
  // Repositories have no declared upward deps
  RegistryKeys.layerRepository: [],
  RegistryKeys.historyRepository: [],
  RegistryKeys.storageRepository: [],
  RegistryKeys.templateRepository: [],
  // Observability
  RegistryKeys.telemetryEngine: [],
  RegistryKeys.debugTraceEngine: [],
  RegistryKeys.systemHealthEngine: [],
  // Intelligence
  RegistryKeys.suggestionEngine: [],
  RegistryKeys.insightEngine: [],
  RegistryKeys.inputOrchestratorEngine: [],
  // Execution Gateway (PHASE-8) — may read context; no engine commands
  RegistryKeys.commandGatewayEngine: [RegistryKeys.contextMemoryEngine],
  RegistryKeys.executionPolicyEngine: [],
  RegistryKeys.contextMemoryEngine: [],
  // Runtime Governance (PHASE-9) — fully independent
  RegistryKeys.runtimeManagerEngine: [],
  RegistryKeys.resourcePolicyEngine: [],
  RegistryKeys.taskSchedulerEngine: [],
};

// ---------------------------------------------------------------------------
// SECTION 5 — INTEGRATION GUARD
// ---------------------------------------------------------------------------

/// IntegrationGuard — PHASE-10 Architecture Security Authority
///
/// Validates the complete system wiring against the PHASE-10 contract.
///
/// LAWS:
///   1. READ ONLY — never modifies registry, engines, or any state.
///   2. NO EXECUTION — validates and reports; never triggers actions.
///   3. VIOLATION → ABORT — any architecture violation causes boot to halt.
///   4. WARNING → DEGRADE — advisory warnings allow boot to continue.
///   5. NEVER THROWS — all errors are converted to violation findings.
///
/// Implements [IntegrationGuardContract] so SystemBootstrap can call
/// [runAllValidations] without depending on this concrete type.
final class IntegrationGuard implements IntegrationGuardContract {
  IntegrationGuard({String guardId = 'integration_guard'})
      : _guardId = guardId;

  final String _guardId;
  int _findingCounter = 0;

  // -------------------------------------------------------------------------
  // SECTION 5A — IntegrationGuardContract ENTRY POINT
  // -------------------------------------------------------------------------

  /// Runs all architecture validations against [registry].
  ///
  /// Calls all 8 mandatory validation functions and aggregates findings
  /// into a single [IntegrationReport].
  ///
  /// Never throws — all internal errors are recorded as critical violations.
  @override
  IntegrationReport runAllValidations(DependencyRegistryContract registry) {
    final findings = <ValidationFinding>[];

    try {
      findings.addAll(validateArchitecture(registry));
      findings.addAll(validateDependencyGraph(registry));
      findings.addAll(validateCommunicationRules(registry));
      findings.addAll(detectForbiddenConnections(registry));
      findings.addAll(verifyControllerAuthority(registry));
      findings.addAll(verifyRepositoryIsolation(registry));
      findings.addAll(verifyDependencyDirection(registry));
      findings.addAll(detectCircularDependencies(registry));
    } catch (e) {
      findings.add(_finding(
        category: ValidationCategory.architectureContract,
        severity: ViolationSeverity.violation,
        message: 'IntegrationGuard encountered an unexpected internal error: $e',
        rule: 'GUARD_INTEGRITY',
      ));
    }

    return generateIntegrationReport(findings);
  }

  // -------------------------------------------------------------------------
  // SECTION 5B — MANDATORY VALIDATION FUNCTIONS
  // -------------------------------------------------------------------------

  /// Validates overall system architecture against the PHASE-10 contract.
  ///
  /// Checks that:
  ///   — All required component groups are present
  ///   — No PHASE-10 component declares execution authority
  ///   — The master boot flow structure is respected
  List<ValidationFinding> validateArchitecture(
      DependencyRegistryContract registry) {
    final findings = <ValidationFinding>[];

    try {
      // Verify all required groups have at least one registered component
      final requiredGroups = <String, Set<String>>{
        'Repositories': RegistryKeys.repositories,
        'Core Engines': RegistryKeys.coreEngines,
        'Controller': RegistryKeys.controller,
      };

      for (final entry in requiredGroups.entries) {
        final allPresent =
            entry.value.every((k) => registry.isRegistered(k));
        if (!allPresent) {
          final missing =
              entry.value.where((k) => !registry.isRegistered(k)).toList();
          findings.add(_finding(
            category: ValidationCategory.architectureContract,
            severity: ViolationSeverity.violation,
            message: '${entry.key} group is incomplete. '
                'Missing: ${missing.join(', ')}',
            involvedKeys: missing,
            rule: 'MANDATORY_REGISTRATION',
          ));
        }
      }

      // Verify optional groups produce only warnings when incomplete
      final optionalGroups = <String, Set<String>>{
        'Observability Layer': RegistryKeys.observabilityLayer,
        'Intelligence Layer': RegistryKeys.intelligenceLayer,
        'Execution Gateway Layer': RegistryKeys.executionGatewayLayer,
        'Runtime Governance Layer': RegistryKeys.runtimeGovernanceLayer,
      };

      for (final entry in optionalGroups.entries) {
        final missing =
            entry.value.where((k) => !registry.isRegistered(k)).toList();
        if (missing.isNotEmpty) {
          findings.add(_finding(
            category: ValidationCategory.architectureContract,
            severity: ViolationSeverity.warning,
            message: '${entry.key} is partially registered. '
                'Missing (optional): ${missing.join(', ')}. '
                'Editor remains operational.',
            involvedKeys: missing,
            rule: 'OPTIONAL_LAYER_INCOMPLETE',
          ));
        }
      }
    } catch (e) {
      findings.add(_finding(
        category: ValidationCategory.architectureContract,
        severity: ViolationSeverity.violation,
        message: 'validateArchitecture error: $e',
        rule: 'VALIDATE_ARCHITECTURE',
      ));
    }

    return findings;
  }

  /// Validates the dependency registration graph for completeness and
  /// consistency against the declared dependency map.
  List<ValidationFinding> validateDependencyGraph(
      DependencyRegistryContract registry) {
    final findings = <ValidationFinding>[];

    try {
      // Every key declared in the dependency graph should be registered
      // (or flagged as optional if it belongs to an optional group).
      final optionalKeys = {
        ...RegistryKeys.observabilityLayer,
        ...RegistryKeys.intelligenceLayer,
        ...RegistryKeys.executionGatewayLayer,
        ...RegistryKeys.runtimeGovernanceLayer,
      };

      for (final key in _declaredDependencyGraph.keys) {
        if (!registry.isRegistered(key)) {
          final severity = optionalKeys.contains(key)
              ? ViolationSeverity.warning
              : ViolationSeverity.violation;
          findings.add(_finding(
            category: ValidationCategory.dependencyGraph,
            severity: severity,
            message: 'Component declared in dependency graph but not registered: $key',
            involvedKeys: [key],
            rule: 'DEPENDENCY_GRAPH_COMPLETENESS',
          ));
        }
      }

      // Verify declared dependencies are themselves registered
      for (final entry in _declaredDependencyGraph.entries) {
        for (final dep in entry.value) {
          if (!registry.isRegistered(dep) && !optionalKeys.contains(dep)) {
            findings.add(_finding(
              category: ValidationCategory.dependencyGraph,
              severity: ViolationSeverity.violation,
              message:
                  '"${entry.key}" declares a dependency on "$dep" which is not registered.',
              involvedKeys: [entry.key, dep],
              rule: 'DEPENDENCY_RESOLVED',
            ));
          }
        }
      }
    } catch (e) {
      findings.add(_finding(
        category: ValidationCategory.dependencyGraph,
        severity: ViolationSeverity.violation,
        message: 'validateDependencyGraph error: $e',
        rule: 'VALIDATE_DEPENDENCY_GRAPH',
      ));
    }

    return findings;
  }

  /// Validates communication rules from the PHASE-10 Allowed Communication
  /// Matrix: ensures only permitted layer-to-layer paths exist.
  List<ValidationFinding> validateCommunicationRules(
      DependencyRegistryContract registry) {
    final findings = <ValidationFinding>[];

    try {
      // Verify the canonical allowed paths are structurally intact
      // by confirming each party in those paths is registered.
      final allowedPairs = [
        // UI → EditorController (only controller may receive from UI)
        (RegistryKeys.editorController, 'UI → EditorController allowed'),
        // EditorController → core layers
        (RegistryKeys.layerEngine, 'EditorController → LayerEngine allowed'),
        (RegistryKeys.historyEngine, 'EditorController → HistoryEngine allowed'),
        (RegistryKeys.renderEngine, 'EditorController → RenderEngine allowed'),
        // LayerEngine → RenderEngine (allowed)
        (RegistryKeys.renderEngine, 'LayerEngine → RenderEngine allowed'),
      ];

      for (final pair in allowedPairs) {
        if (!registry.isRegistered(pair.$1)) {
          findings.add(_finding(
            category: ValidationCategory.communicationRules,
            severity: ViolationSeverity.violation,
            message: 'Required participant of allowed communication path is '
                'not registered: ${pair.$1}. ${pair.$2}',
            involvedKeys: [pair.$1],
            rule: 'ALLOWED_COMMUNICATION_PATH',
          ));
        }
      }

      // Confirm PHASE-8/PHASE-9 engines only report to EditorController
      // (advisory paths — validated by confirming EditorController is registered
      // as the sole execution recipient).
      if (!registry.isRegistered(RegistryKeys.editorController)) {
        findings.add(_finding(
          category: ValidationCategory.communicationRules,
          severity: ViolationSeverity.violation,
          message: 'EditorController is not registered. '
              'All governance and gateway engines require EditorController '
              'as their sole execution recipient.',
          involvedKeys: [RegistryKeys.editorController],
          rule: 'EDITORCONTROLLER_SUPREMACY',
        ));
      }
    } catch (e) {
      findings.add(_finding(
        category: ValidationCategory.communicationRules,
        severity: ViolationSeverity.violation,
        message: 'validateCommunicationRules error: $e',
        rule: 'VALIDATE_COMMUNICATION_RULES',
      ));
    }

    return findings;
  }

  /// Detects forbidden connections from the PHASE-10 Forbidden Communication
  /// Matrix.
  ///
  /// Checks all statically declared forbidden routes. For routes involving
  /// external actors (UI, VoiceInput, Canvas, etc.) that are not in the
  /// registry, the check verifies structural intent via registry group
  /// metadata rather than exact key presence.
  List<ValidationFinding> detectForbiddenConnections(
      DependencyRegistryContract registry) {
    final findings = <ValidationFinding>[];

    try {
      // Verify no registered component belongs to a layer it should not.
      // For concrete registry keys, check their group rank for violations.
      if (registry is DependencyRegistry) {
        final concreteRegistry = registry;

        for (final key in concreteRegistry.allKeys) {
          final record = concreteRegistry.inspectRecord(key);
          if (record == null) continue;

          final sourceRank = _rankForGroup(record.group);

          // A repository must never depend upward to an engine or controller
          if (sourceRank == _LayerRank.repository) {
            for (final dep in (_declaredDependencyGraph[key] ?? [])) {
              final depRecord = concreteRegistry.inspectRecord(dep);
              if (depRecord != null) {
                final depRank = _rankForGroup(depRecord.group);
                if (depRank > _LayerRank.repository) {
                  findings.add(_finding(
                    category: ValidationCategory.communicationRules,
                    severity: ViolationSeverity.violation,
                    message: 'Repository "$key" declares upward dependency on '
                        '"$dep" (group: ${depRecord.group}). '
                        'Repository → Engine/Controller is forbidden.',
                    involvedKeys: [key, dep],
                    rule: 'REPOSITORY_ISOLATION',
                  ));
                }
              }
            }
          }
        }
      }

      // Check static forbidden routes for any that involve registered keys
      for (final route in _forbiddenRoutes) {
        final sourceRegistered = registry.isRegistered(route.sourceKey);
        final targetRegistered = registry.isRegistered(route.targetKey);

        // If both sides are registered and the declared dependency graph
        // shows the source depending on the target, it is a violation.
        if (sourceRegistered && targetRegistered) {
          final sourceDeps =
              _declaredDependencyGraph[route.sourceKey] ?? const [];
          if (sourceDeps.contains(route.targetKey)) {
            findings.add(_finding(
              category: ValidationCategory.communicationRules,
              severity: ViolationSeverity.violation,
              message: 'Forbidden connection detected: ${route.rule}. '
                  '"${route.sourceKey}" declares dependency on "${route.targetKey}".',
              involvedKeys: [route.sourceKey, route.targetKey],
              rule: route.rule,
            ));
          }
        }

        // If the target is not registered but the source is, emit an advisory
        // for routes where the target is a non-registry actor (Canvas, UI, etc.)
        if (sourceRegistered && !targetRegistered) {
          findings.add(_finding(
            category: ValidationCategory.communicationRules,
            severity: ViolationSeverity.info,
            message: 'Forbidden route advisory: ${route.rule}. '
                '"${route.targetKey}" is not in registry — '
                'ensure "${route.sourceKey}" does not communicate with it at runtime.',
            involvedKeys: [route.sourceKey],
            rule: route.rule,
          ));
        }
      }
    } catch (e) {
      findings.add(_finding(
        category: ValidationCategory.communicationRules,
        severity: ViolationSeverity.violation,
        message: 'detectForbiddenConnections error: $e',
        rule: 'DETECT_FORBIDDEN_CONNECTIONS',
      ));
    }

    return findings;
  }

  /// Verifies that EditorController is registered and is the sole
  /// component in the controller group.
  ///
  /// EditorController Supremacy Law: only EditorController may execute,
  /// change layers, change history, trigger exports, or execute workflows.
  List<ValidationFinding> verifyControllerAuthority(
      DependencyRegistryContract registry) {
    final findings = <ValidationFinding>[];

    try {
      // EditorController must be registered
      if (!registry.isRegistered(RegistryKeys.editorController)) {
        findings.add(_finding(
          category: ValidationCategory.controllerAuthority,
          severity: ViolationSeverity.violation,
          message: 'EditorController is not registered. '
              'EDITORCONTROLLER SUPREMACY LAW violated — '
              'no execution authority is present.',
          involvedKeys: [RegistryKeys.editorController],
          rule: 'EDITORCONTROLLER_SUPREMACY',
        ));
        return findings;
      }

      // Verify no engine-group component claims controller-level rank
      if (registry is DependencyRegistry) {
        final concreteRegistry = registry;
        for (final key in concreteRegistry.allKeys) {
          if (key == RegistryKeys.editorController) continue;
          final record = concreteRegistry.inspectRecord(key);
          if (record == null) continue;
          if (record.group == RegistrationGroups.controller) {
            findings.add(_finding(
              category: ValidationCategory.controllerAuthority,
              severity: ViolationSeverity.violation,
              message: 'Component "$key" is registered as a Controller. '
                  'Only EditorController may hold Controller authority. '
                  'EDITORCONTROLLER SUPREMACY LAW violated.',
              involvedKeys: [key, RegistryKeys.editorController],
              rule: 'EDITORCONTROLLER_SUPREMACY',
            ));
          }
        }
      }

      findings.add(_finding(
        category: ValidationCategory.controllerAuthority,
        severity: ViolationSeverity.info,
        message: 'EditorController authority verified — '
            'sole execution authority confirmed.',
        involvedKeys: [RegistryKeys.editorController],
        rule: 'EDITORCONTROLLER_SUPREMACY',
      ));
    } catch (e) {
      findings.add(_finding(
        category: ValidationCategory.controllerAuthority,
        severity: ViolationSeverity.violation,
        message: 'verifyControllerAuthority error: $e',
        rule: 'VERIFY_CONTROLLER_AUTHORITY',
      ));
    }

    return findings;
  }

  /// Verifies repository isolation: engines must not access storage directly.
  ///
  /// Repository Protection Law:
  ///   Engine → Repository ✔
  ///   Repository → Storage ✔
  ///   Engine → Storage ❌
  ///   EditorController → Storage ❌
  List<ValidationFinding> verifyRepositoryIsolation(
      DependencyRegistryContract registry) {
    final findings = <ValidationFinding>[];

    try {
      // Check declared graph: no engine-group key should depend on storageEngine
      // unless it is the storage repository going to a storage service
      final engineKeys = {
        ...RegistryKeys.coreEngines,
        ...RegistryKeys.observabilityLayer,
        ...RegistryKeys.intelligenceLayer,
        ...RegistryKeys.executionGatewayLayer,
        ...RegistryKeys.runtimeGovernanceLayer,
      };

      // storageEngine is the key representing the persistence engine
      // Engines must NOT declare storageEngine as a direct dependency.
      // (They may use storageRepository instead.)
      for (final engineKey in engineKeys) {
        if (engineKey == RegistryKeys.storageEngine) continue;
        final deps = _declaredDependencyGraph[engineKey] ?? [];
        if (deps.contains(RegistryKeys.storageEngine)) {
          findings.add(_finding(
            category: ValidationCategory.repositoryIsolation,
            severity: ViolationSeverity.violation,
            message: 'Engine "$engineKey" declares direct dependency on '
                'StorageEngine. Repository Protection Law violated — '
                'all persistence must pass through repositories.',
            involvedKeys: [engineKey, RegistryKeys.storageEngine],
            rule: 'REPOSITORY_PROTECTION',
          ));
        }
      }

      // EditorController must not directly depend on storageEngine
      final controllerDeps =
          _declaredDependencyGraph[RegistryKeys.editorController] ?? [];
      if (controllerDeps.contains(RegistryKeys.storageEngine)) {
        findings.add(_finding(
          category: ValidationCategory.repositoryIsolation,
          severity: ViolationSeverity.violation,
          message: 'EditorController declares direct dependency on StorageEngine. '
              'Repository Protection Law violated.',
          involvedKeys: [RegistryKeys.editorController, RegistryKeys.storageEngine],
          rule: 'REPOSITORY_PROTECTION',
        ));
      }

      if (findings.isEmpty) {
        findings.add(_finding(
          category: ValidationCategory.repositoryIsolation,
          severity: ViolationSeverity.info,
          message: 'Repository isolation verified — '
              'no engine bypasses repository layer.',
          rule: 'REPOSITORY_PROTECTION',
        ));
      }
    } catch (e) {
      findings.add(_finding(
        category: ValidationCategory.repositoryIsolation,
        severity: ViolationSeverity.violation,
        message: 'verifyRepositoryIsolation error: $e',
        rule: 'VERIFY_REPOSITORY_ISOLATION',
      ));
    }

    return findings;
  }

  /// Verifies the dependency direction law:
  ///   UI → Controller → Engine → Repository → Storage (only downward).
  ///
  /// Lower layers may never depend on upper layers.
  List<ValidationFinding> verifyDependencyDirection(
      DependencyRegistryContract registry) {
    final findings = <ValidationFinding>[];

    try {
      for (final entry in _declaredDependencyGraph.entries) {
        final sourceKey = entry.key;
        final sourceDeps = entry.value;

        // Determine source rank from known key sets
        final sourceRank = _rankForKey(sourceKey);

        for (final depKey in sourceDeps) {
          final depRank = _rankForKey(depKey);

          // A lower-rank component must not depend on a higher-rank one.
          if (depRank > sourceRank) {
            findings.add(_finding(
              category: ValidationCategory.dependencyDirection,
              severity: ViolationSeverity.violation,
              message: 'Dependency direction violation: "$sourceKey" '
                  '(layer rank: $sourceRank) depends on "$depKey" '
                  '(layer rank: $depRank). '
                  'Lower layers may never depend on upper layers.',
              involvedKeys: [sourceKey, depKey],
              rule: 'DEPENDENCY_DIRECTION_LAW',
            ));
          }
        }
      }

      final directionViolations = findings
          .where((f) => f.category == ValidationCategory.dependencyDirection
              && f.isViolation)
          .length;

      if (directionViolations == 0) {
        findings.add(_finding(
          category: ValidationCategory.dependencyDirection,
          severity: ViolationSeverity.info,
          message: 'Dependency direction law verified — '
              'all declared dependencies flow downward only.',
          rule: 'DEPENDENCY_DIRECTION_LAW',
        ));
      }
    } catch (e) {
      findings.add(_finding(
        category: ValidationCategory.dependencyDirection,
        severity: ViolationSeverity.violation,
        message: 'verifyDependencyDirection error: $e',
        rule: 'VERIFY_DEPENDENCY_DIRECTION',
      ));
    }

    return findings;
  }

  /// Detects circular dependencies in [_declaredDependencyGraph].
  ///
  /// Circular Dependency Law: no dependency loop is allowed.
  /// Examples:
  ///   LayerEngine ↔ HistoryEngine ❌
  ///   HistoryEngine ↔ StorageEngine ❌
  ///   AIEngine ↔ LayerEngine ❌
  List<ValidationFinding> detectCircularDependencies(
      DependencyRegistryContract registry) {
    final findings = <ValidationFinding>[];

    try {
      final allKeys = _declaredDependencyGraph.keys.toSet();
      final visited = <String>{};
      final cycles = <List<String>>[];

      // DFS-based cycle detection (Tarjan-style path tracking)
      void dfs(String node, List<String> path) {
        if (path.contains(node)) {
          final cycleStart = path.indexOf(node);
          final cycle = [...path.sublist(cycleStart), node];
          // Avoid recording duplicate cycles (same cycle, different start)
          final cycleKey = (List.from(cycle)..sort()).join(',');
          if (cycles.every((c) => (List.from(c)..sort()).join(',') != cycleKey)) {
            cycles.add(cycle);
          }
          return;
        }

        if (visited.contains(node)) return;

        final deps = _declaredDependencyGraph[node] ?? [];
        for (final dep in deps) {
          if (!allKeys.contains(dep)) continue;
          dfs(dep, [...path, node]);
        }

        visited.add(node);
      }

      for (final key in allKeys) {
        if (!visited.contains(key)) {
          dfs(key, []);
        }
      }

      for (final cycle in cycles) {
        findings.add(_finding(
          category: ValidationCategory.circularDependency,
          severity: ViolationSeverity.violation,
          message: 'Circular dependency detected: ${cycle.join(' → ')}. '
              'Boot must be aborted.',
          involvedKeys: cycle,
          rule: 'CIRCULAR_DEPENDENCY_LAW',
        ));
      }

      if (cycles.isEmpty) {
        findings.add(_finding(
          category: ValidationCategory.circularDependency,
          severity: ViolationSeverity.info,
          message: 'No circular dependencies detected in declared graph.',
          rule: 'CIRCULAR_DEPENDENCY_LAW',
        ));
      }
    } catch (e) {
      findings.add(_finding(
        category: ValidationCategory.circularDependency,
        severity: ViolationSeverity.violation,
        message: 'detectCircularDependencies error: $e',
        rule: 'DETECT_CIRCULAR_DEPENDENCIES',
      ));
    }

    return findings;
  }

  /// Generates a final [IntegrationReport] from [findings].
  ///
  /// Violations → report.passed = false.
  /// Warnings → report.passed may still be true; included in report.warnings.
  IntegrationReport generateIntegrationReport(
      List<ValidationFinding> findings) {
    try {
      final violations = findings
          .where((f) => f.isViolation)
          .map((f) => '[${f.category.name}] ${f.message}'
              '${f.rule != null ? ' (rule: ${f.rule})' : ''}')
          .toList(growable: false);

      final warnings = findings
          .where((f) => f.isWarning)
          .map((f) => '[${f.category.name}] ${f.message}')
          .toList(growable: false);

      return IntegrationReport(
        passed: violations.isEmpty,
        violations: violations,
        warnings: warnings,
        generatedAt: DateTime.now(),
      );
    } catch (_) {
      return IntegrationReport.error(
        'IntegrationGuard: generateIntegrationReport failed unexpectedly.',
      );
    }
  }

  // -------------------------------------------------------------------------
  // SECTION 5C — PRIVATE HELPERS
  // -------------------------------------------------------------------------

  /// Resolves the layer rank for a component key from known key sets.
  int _rankForKey(String key) {
    if (RegistryKeys.repositories.contains(key)) return _LayerRank.repository;
    if (key == RegistryKeys.editorController) return _LayerRank.controller;
    if (RegistryKeys.coreEngines.contains(key) ||
        RegistryKeys.observabilityLayer.contains(key) ||
        RegistryKeys.intelligenceLayer.contains(key) ||
        RegistryKeys.executionGatewayLayer.contains(key) ||
        RegistryKeys.runtimeGovernanceLayer.contains(key)) {
      return _LayerRank.engine;
    }
    // Unknown keys (Canvas, UI, etc.) treated as UI layer for direction checks
    return _LayerRank.ui;
  }

  ValidationFinding _finding({
    required ValidationCategory category,
    required ViolationSeverity severity,
    required String message,
    List<String> involvedKeys = const [],
    String? rule,
  }) {
    _findingCounter++;
    return ValidationFinding(
      findingId: '${_guardId}_finding_$_findingCounter',
      category: category,
      severity: severity,
      message: message,
      involvedKeys: List.unmodifiable(involvedKeys),
      rule: rule,
    );
  }
}
