// ignore_for_file: avoid_catches_without_on_clauses

import 'dart:math';

// ── Risk levels ────────────────────────────────────────────────
enum RiskLevel { none, low, medium, high, critical }

// ── Policy decision outcome ────────────────────────────────────
enum PolicyOutcome {
  // Engine recommends approval — EditorController still holds final veto.
  approved,
  // Engine recommends rejection — EditorController may override.
  rejected,
  // Engine cannot determine safety — EditorController must decide.
  deferred,
}

// ── Permission tier ────────────────────────────────────────────
enum PermissionTier { guest, viewer, editor, owner, system }

// ── Restriction category ───────────────────────────────────────
enum RestrictionCategory {
  sourceBlocked,
  intentDisabled,
  targetLocked,
  rateLimitExceeded,
  featureGated,
  conflictingState,
  payloadInvalid,
}

// ── Confirmation trigger ───────────────────────────────────────
enum ConfirmationTrigger {
  destructiveAction,
  bulkAction,
  unsavedChanges,
  lowConfidence,
  highRisk,
  externalSource,
  irreversibleChange,
  featureGated,
}

// ── Source types (mirrored from gateway — no import needed) ───
enum PolicySourceType {
  text,
  voice,
  gesture,
  robotAssistant,
  aiAssistant,
  automation,
  plugin,
  workflow,
  multimodal,
  unknown,
}

// ── Intent types (mirrored — no cross-engine import) ──────────
enum PolicyIntentType {
  addLayer,
  deleteLayer,
  selectLayer,
  moveLayer,
  resizeLayer,
  rotateLayer,
  duplicateLayer,
  showLayer,
  hideLayer,
  lockLayer,
  unlockLayer,
  changeColor,
  changeFont,
  changeOpacity,
  applyTemplate,
  undoAction,
  redoAction,
  saveDesign,
  exportDesign,
  openSettings,
  openLayerPanel,
  clearSelection,
  batchEdit,
  reorderLayers,
  runWorkflow,
  triggerPlugin,
  requestAnalysis,
  requestSuggestion,
  unknown,
}

// ── Command target (mirrored) ──────────────────────────────────
enum PolicyCommandTarget {
  selectedLayer,
  specificLayer,
  allLayers,
  visibleLayers,
  lockedLayers,
  design,
  canvas,
  system,
  none,
}

// ── Policy command snapshot ────────────────────────────────────
// A flattened, read-only view of a UnifiedEditorCommand.
// ExecutionPolicyEngine never imports from CommandGatewayEngine.
class PolicyCommandSnapshot {
  final String commandId;
  final PolicyIntentType intent;
  final PolicyCommandTarget target;
  final double confidence;
  final Map<String, dynamic> parameters;
  final Map<String, dynamic> metadata;

  const PolicyCommandSnapshot({
    required this.commandId,
    required this.intent,
    required this.target,
    required this.confidence,
    this.parameters = const {},
    this.metadata = const {},
  });
}

// ── Policy context snapshot ────────────────────────────────────
class PolicyContextSnapshot {
  final String? activeDesignId;
  final String? selectedLayerId;
  final bool hasUnsavedChanges;
  final int layerCount;
  final int lockedLayerCount;
  final PermissionTier userPermissionTier;
  final bool isOnline;
  final int recentCommandCount;
  final List<String> recentIntentTypes;
  final Map<String, dynamic> featureFlags;

  const PolicyContextSnapshot({
    this.activeDesignId,
    this.selectedLayerId,
    required this.hasUnsavedChanges,
    required this.layerCount,
    required this.lockedLayerCount,
    required this.userPermissionTier,
    required this.isOnline,
    required this.recentCommandCount,
    this.recentIntentTypes = const [],
    this.featureFlags = const {},
  });

  bool isFeatureEnabled(String flag) =>
      featureFlags[flag] == true;
}

// ── PolicyRequest — input contract ────────────────────────────
class PolicyRequest {
  final String requestId;
  final String commandId;
  final PolicyCommandSnapshot command;
  final PolicySourceType sourceType;
  final PolicyContextSnapshot contextSnapshot;

  const PolicyRequest({
    required this.requestId,
    required this.commandId,
    required this.command,
    required this.sourceType,
    required this.contextSnapshot,
  });
}

// ── Risk finding ───────────────────────────────────────────────
class RiskFinding {
  final RiskLevel level;
  final String description;
  final RestrictionCategory? relatedRestriction;
  final double riskScore;

  const RiskFinding({
    required this.level,
    required this.description,
    this.relatedRestriction,
    required this.riskScore,
  });

  Map<String, dynamic> toMap() => {
        'level': level.name,
        'description': description,
        'relatedRestriction': relatedRestriction?.name,
        'riskScore': riskScore,
      };
}

// ── Permission check result ────────────────────────────────────
class PermissionCheckResult {
  final bool permitted;
  final PermissionTier requiredTier;
  final PermissionTier actualTier;
  final String reason;

  const PermissionCheckResult.granted({
    required this.requiredTier,
    required this.actualTier,
  })  : permitted = true,
        reason = 'Permission tier satisfied.';

  const PermissionCheckResult.denied({
    required this.requiredTier,
    required this.actualTier,
    required this.reason,
  }) : permitted = false;
}

// ── Restriction check result ───────────────────────────────────
class RestrictionCheckResult {
  final bool restricted;
  final List<RestrictionCategory> violations;
  final List<String> reasons;

  const RestrictionCheckResult.clear()
      : restricted = false,
        violations = const [],
        reasons = const [];

  const RestrictionCheckResult.blocked(this.violations, this.reasons)
      : restricted = true;
}

// ── Confirmation check result ──────────────────────────────────
class ConfirmationCheckResult {
  final bool required;
  final List<ConfirmationTrigger> triggers;
  final String? confirmationMessage;

  const ConfirmationCheckResult.notRequired()
      : required = false,
        triggers = const [],
        confirmationMessage = null;

  const ConfirmationCheckResult.required(
      this.triggers, this.confirmationMessage)
      : required = true;
}

// ── PolicyDecision — output contract ──────────────────────────
class PolicyDecision {
  final String policyId;
  final String commandId;
  final String requestId;
  final PolicyOutcome outcome;
  final bool approved;
  final bool requiresConfirmation;
  final String reason;
  final RiskLevel riskLevel;
  final double riskScore;
  final List<RiskFinding> riskFindings;
  final List<String> restrictionReasons;
  final List<ConfirmationTrigger> confirmationTriggers;
  final DateTime decidedAt;

  // AUTHORITY LAW: This approval recommendation is ADVISORY ONLY.
  // EditorController holds final execution authority and may reject
  // any approved command or cancel any command at will.
  final bool isAdvisoryOnly;

  const PolicyDecision._({
    required this.policyId,
    required this.commandId,
    required this.requestId,
    required this.outcome,
    required this.approved,
    required this.requiresConfirmation,
    required this.reason,
    required this.riskLevel,
    required this.riskScore,
    required this.riskFindings,
    required this.restrictionReasons,
    required this.confirmationTriggers,
    required this.decidedAt,
  }) : isAdvisoryOnly = true;

  factory PolicyDecision.approve({
    required String policyId,
    required String commandId,
    required String requestId,
    required RiskLevel riskLevel,
    required double riskScore,
    required List<RiskFinding> riskFindings,
    required bool requiresConfirmation,
    required List<ConfirmationTrigger> confirmationTriggers,
    String reason = 'Command passed all policy checks.',
  }) =>
      PolicyDecision._(
        policyId: policyId,
        commandId: commandId,
        requestId: requestId,
        outcome: PolicyOutcome.approved,
        approved: true,
        requiresConfirmation: requiresConfirmation,
        reason: reason,
        riskLevel: riskLevel,
        riskScore: riskScore.clamp(0.0, 100.0),
        riskFindings: List.unmodifiable(riskFindings),
        restrictionReasons: const [],
        confirmationTriggers: List.unmodifiable(confirmationTriggers),
        decidedAt: DateTime.now().toUtc(),
      );

  factory PolicyDecision.reject({
    required String policyId,
    required String commandId,
    required String requestId,
    required RiskLevel riskLevel,
    required double riskScore,
    required List<RiskFinding> riskFindings,
    required List<String> restrictionReasons,
    required String reason,
  }) =>
      PolicyDecision._(
        policyId: policyId,
        commandId: commandId,
        requestId: requestId,
        outcome: PolicyOutcome.rejected,
        approved: false,
        requiresConfirmation: false,
        reason: reason,
        riskLevel: riskLevel,
        riskScore: riskScore.clamp(0.0, 100.0),
        riskFindings: List.unmodifiable(riskFindings),
        restrictionReasons: List.unmodifiable(restrictionReasons),
        confirmationTriggers: const [],
        decidedAt: DateTime.now().toUtc(),
      );

  factory PolicyDecision.defer({
    required String policyId,
    required String commandId,
    required String requestId,
    required String reason,
  }) =>
      PolicyDecision._(
        policyId: policyId,
        commandId: commandId,
        requestId: requestId,
        outcome: PolicyOutcome.deferred,
        approved: false,
        requiresConfirmation: true,
        reason: reason,
        riskLevel: RiskLevel.medium,
        riskScore: 50.0,
        riskFindings: const [],
        restrictionReasons: const [],
        confirmationTriggers: const [ConfirmationTrigger.lowConfidence],
        decidedAt: DateTime.now().toUtc(),
      );

  Map<String, dynamic> toMap() => {
        'policyId': policyId,
        'commandId': commandId,
        'requestId': requestId,
        'outcome': outcome.name,
        'approved': approved,
        'requiresConfirmation': requiresConfirmation,
        'reason': reason,
        'riskLevel': riskLevel.name,
        'riskScore': riskScore,
        'riskFindings': riskFindings.map((f) => f.toMap()).toList(),
        'restrictionReasons': restrictionReasons,
        'confirmationTriggers':
            confirmationTriggers.map((t) => t.name).toList(),
        'isAdvisoryOnly': isAdvisoryOnly,
        'decidedAt': decidedAt.toIso8601String(),
      };
}

// ── Policy evaluation result (internal) ───────────────────────
class _PolicyEvaluationBundle {
  final List<RiskFinding> riskFindings;
  final RiskLevel aggregateRiskLevel;
  final double aggregateRiskScore;
  final PermissionCheckResult permissionResult;
  final RestrictionCheckResult restrictionResult;
  final ConfirmationCheckResult confirmationResult;
  final List<String> validationErrors;

  const _PolicyEvaluationBundle({
    required this.riskFindings,
    required this.aggregateRiskLevel,
    required this.aggregateRiskScore,
    required this.permissionResult,
    required this.restrictionResult,
    required this.confirmationResult,
    required this.validationErrors,
  });
}

// ── ID generator ──────────────────────────────────────────────
class _EPIdGen {
  static final Random _rng = Random.secure();

  static String next(String prefix) {
    final bytes = List<int>.generate(8, (_) => _rng.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '$prefix-$hex-${DateTime.now().microsecondsSinceEpoch}';
  }
}

// ── Required permission tiers per intent ──────────────────────
const Map<PolicyIntentType, PermissionTier> _kIntentPermissions = {
  PolicyIntentType.addLayer:          PermissionTier.editor,
  PolicyIntentType.deleteLayer:       PermissionTier.editor,
  PolicyIntentType.selectLayer:       PermissionTier.viewer,
  PolicyIntentType.moveLayer:         PermissionTier.editor,
  PolicyIntentType.resizeLayer:       PermissionTier.editor,
  PolicyIntentType.rotateLayer:       PermissionTier.editor,
  PolicyIntentType.duplicateLayer:    PermissionTier.editor,
  PolicyIntentType.showLayer:         PermissionTier.editor,
  PolicyIntentType.hideLayer:         PermissionTier.editor,
  PolicyIntentType.lockLayer:         PermissionTier.editor,
  PolicyIntentType.unlockLayer:       PermissionTier.editor,
  PolicyIntentType.changeColor:       PermissionTier.editor,
  PolicyIntentType.changeFont:        PermissionTier.editor,
  PolicyIntentType.changeOpacity:     PermissionTier.editor,
  PolicyIntentType.applyTemplate:     PermissionTier.editor,
  PolicyIntentType.undoAction:        PermissionTier.editor,
  PolicyIntentType.redoAction:        PermissionTier.editor,
  PolicyIntentType.saveDesign:        PermissionTier.editor,
  PolicyIntentType.exportDesign:      PermissionTier.editor,
  PolicyIntentType.openSettings:      PermissionTier.owner,
  PolicyIntentType.openLayerPanel:    PermissionTier.viewer,
  PolicyIntentType.clearSelection:    PermissionTier.viewer,
  PolicyIntentType.batchEdit:         PermissionTier.editor,
  PolicyIntentType.reorderLayers:     PermissionTier.editor,
  PolicyIntentType.runWorkflow:       PermissionTier.editor,
  PolicyIntentType.triggerPlugin:     PermissionTier.owner,
  PolicyIntentType.requestAnalysis:   PermissionTier.viewer,
  PolicyIntentType.requestSuggestion: PermissionTier.viewer,
  PolicyIntentType.unknown:           PermissionTier.system,
};

// ── Base risk score per intent ────────────────────────────────
const Map<PolicyIntentType, double> _kIntentBaseRisk = {
  PolicyIntentType.deleteLayer:    30.0,
  PolicyIntentType.batchEdit:      25.0,
  PolicyIntentType.applyTemplate:  22.0,
  PolicyIntentType.reorderLayers:  15.0,
  PolicyIntentType.runWorkflow:    18.0,
  PolicyIntentType.triggerPlugin:  20.0,
  PolicyIntentType.exportDesign:   10.0,
  PolicyIntentType.saveDesign:      5.0,
  PolicyIntentType.unknown:        50.0,
};

// ── Destructive intents ────────────────────────────────────────
const _kDestructiveIntents = {
  PolicyIntentType.deleteLayer,
  PolicyIntentType.batchEdit,
  PolicyIntentType.applyTemplate,
  PolicyIntentType.reorderLayers,
};

// ── Intents that require online access ────────────────────────
const _kOnlineRequiredIntents = {
  PolicyIntentType.exportDesign,
  PolicyIntentType.runWorkflow,
};

// ── Feature-gated intents ─────────────────────────────────────
const Map<PolicyIntentType, String> _kFeatureGatedIntents = {
  PolicyIntentType.triggerPlugin:  'plugins_enabled',
  PolicyIntentType.runWorkflow:    'workflows_enabled',
  PolicyIntentType.requestAnalysis: 'insight_engine_enabled',
};

// ══════════════════════════════════════════════════════════════
// ExecutionPolicyEngine
// ══════════════════════════════════════════════════════════════
class ExecutionPolicyEngine {
  // ── Public entry point ────────────────────────────────────────

  PolicyDecision evaluateRequest(PolicyRequest request) {
    try {
      final guardErrors = _guardRequest(request);
      if (guardErrors.isNotEmpty) {
        return PolicyDecision.reject(
          policyId: _EPIdGen.next('pol'),
          commandId: request.commandId,
          requestId: request.requestId,
          riskLevel: RiskLevel.critical,
          riskScore: 100.0,
          riskFindings: const [],
          restrictionReasons: guardErrors,
          reason: guardErrors.first,
        );
      }

      final bundle = _buildEvaluationBundle(request);
      return generateDecision(request, bundle);
    } catch (e) {
      return PolicyDecision.defer(
        policyId: _EPIdGen.next('pol'),
        commandId: request.commandId,
        requestId: request.requestId,
        reason: 'Policy evaluation threw: $e. '
            'EditorController must make the final determination.',
      );
    }
  }

  // ── validateCommand ────────────────────────────────────────────

  List<String> validateCommand(PolicyCommandSnapshot command) {
    final errors = <String>[];

    if (command.commandId.trim().isEmpty) {
      errors.add('PolicyCommandSnapshot.commandId must not be empty.');
    }
    if (command.confidence < 0.0 || command.confidence > 100.0) {
      errors.add(
          'Command confidence ${command.confidence} is outside [0, 100].');
    }
    if (command.intent == PolicyIntentType.unknown) {
      errors.add(
          'Command intent is unknown — policy cannot evaluate an '
          'undefined intent without EditorController guidance.');
    }

    // Forbidden keys in parameters.
    for (final key in command.parameters.keys) {
      if (_kForbiddenParamKeys.contains(key.toLowerCase())) {
        errors.add(
            'Command parameter key "$key" references a forbidden '
            'engine or context object.');
      }
    }

    return errors;
  }

  // ── evaluateRisk ───────────────────────────────────────────────

  List<RiskFinding> evaluateRisk(
      PolicyCommandSnapshot command,
      PolicyContextSnapshot context,
      PolicySourceType source) {
    final findings = <RiskFinding>[];

    // Base risk from intent category.
    final baseRisk = _kIntentBaseRisk[command.intent] ?? 5.0;
    if (baseRisk >= 20.0) {
      findings.add(RiskFinding(
        level: baseRisk >= 30.0 ? RiskLevel.high : RiskLevel.medium,
        description:
            'Intent "${command.intent.name}" carries an inherent '
            'risk score of ${baseRisk.toStringAsFixed(0)}.',
        riskScore: baseRisk,
      ));
    }

    // Destructive action.
    if (_kDestructiveIntents.contains(command.intent)) {
      findings.add(RiskFinding(
        level: RiskLevel.high,
        description:
            '"${command.intent.name}" is a destructive or '
            'bulk-modifying operation that cannot be fully previewed.',
        relatedRestriction: RestrictionCategory.intentDisabled,
        riskScore: 28.0,
      ));
    }

    // Low confidence.
    if (command.confidence < 40.0) {
      findings.add(RiskFinding(
        level: RiskLevel.medium,
        description:
            'Command confidence is ${command.confidence.toStringAsFixed(1)} — '
            'very low. The intended action may not match the user request.',
        riskScore: 20.0,
      ));
    } else if (command.confidence < 60.0) {
      findings.add(RiskFinding(
        level: RiskLevel.low,
        description:
            'Command confidence is ${command.confidence.toStringAsFixed(1)} — '
            'below the recommended 60% threshold.',
        riskScore: 10.0,
      ));
    }

    // External / non-human source.
    const externalSources = {
      PolicySourceType.robotAssistant,
      PolicySourceType.aiAssistant,
      PolicySourceType.automation,
      PolicySourceType.plugin,
      PolicySourceType.workflow,
    };
    if (externalSources.contains(source)) {
      findings.add(RiskFinding(
        level: RiskLevel.medium,
        description:
            'Command originates from an external source '
            '(${source.name}). All non-human inputs require '
            'explicit EditorController confirmation.',
        riskScore: 15.0,
      ));
    }

    // Locked layer target.
    if ((command.target == PolicyCommandTarget.selectedLayer ||
            command.target == PolicyCommandTarget.specificLayer) &&
        context.lockedLayerCount > 0 &&
        context.selectedLayerId != null) {
      findings.add(RiskFinding(
        level: RiskLevel.medium,
        description:
            'The target layer may be locked. '
            'Modifying locked layers requires explicit unlock first.',
        relatedRestriction: RestrictionCategory.targetLocked,
        riskScore: 18.0,
      ));
    }

    // All-layer target with many layers.
    if (command.target == PolicyCommandTarget.allLayers &&
        context.layerCount > 10) {
      findings.add(RiskFinding(
        level: RiskLevel.high,
        description:
            'Command targets all ${context.layerCount} layers simultaneously. '
            'Bulk operations on large layer sets carry elevated risk.',
        riskScore: 22.0,
      ));
    }

    // Unsaved changes + destructive.
    if (context.hasUnsavedChanges &&
        _kDestructiveIntents.contains(command.intent)) {
      findings.add(RiskFinding(
        level: RiskLevel.high,
        description:
            'Design has unsaved changes and a destructive operation '
            'is being requested. Data loss risk is elevated.',
        relatedRestriction: RestrictionCategory.conflictingState,
        riskScore: 25.0,
      ));
    }

    // Offline + export/workflow.
    if (!context.isOnline && _kOnlineRequiredIntents.contains(command.intent)) {
      findings.add(RiskFinding(
        level: RiskLevel.critical,
        description:
            '"${command.intent.name}" requires network access but '
            'the device is offline.',
        relatedRestriction: RestrictionCategory.conflictingState,
        riskScore: 40.0,
      ));
    }

    // Rate limit.
    if (context.recentCommandCount > 50) {
      findings.add(RiskFinding(
        level: RiskLevel.medium,
        description:
            'High command rate detected (${context.recentCommandCount} '
            'recent commands). Possible automation or input loop.',
        relatedRestriction: RestrictionCategory.rateLimitExceeded,
        riskScore: 12.0,
      ));
    }

    // Target mismatch — layer-targeted intent with no selection.
    if ((command.target == PolicyCommandTarget.selectedLayer) &&
        context.selectedLayerId == null) {
      findings.add(RiskFinding(
        level: RiskLevel.medium,
        description:
            'Command targets a selected layer but no layer is selected. '
            'The operation has no valid target.',
        relatedRestriction: RestrictionCategory.conflictingState,
        riskScore: 14.0,
      ));
    }

    return findings;
  }

  // ── checkPermissions ───────────────────────────────────────────

  PermissionCheckResult checkPermissions(
      PolicyCommandSnapshot command,
      PolicyContextSnapshot context) {
    final required =
        _kIntentPermissions[command.intent] ?? PermissionTier.editor;
    final actual = context.userPermissionTier;

    if (actual.index >= required.index) {
      return PermissionCheckResult.granted(
        requiredTier: required,
        actualTier: actual,
      );
    }

    return PermissionCheckResult.denied(
      requiredTier: required,
      actualTier: actual,
      reason:
          'Intent "${command.intent.name}" requires '
          '${required.name} permission. '
          'Current user tier is ${actual.name}.',
    );
  }

  // ── checkRestrictions ─────────────────────────────────────────

  RestrictionCheckResult checkRestrictions(
      PolicyCommandSnapshot command,
      PolicyContextSnapshot context,
      PolicySourceType source) {
    final violations = <RestrictionCategory>[];
    final reasons = <String>[];

    // Unknown intent is always restricted.
    if (command.intent == PolicyIntentType.unknown) {
      violations.add(RestrictionCategory.intentDisabled);
      reasons.add(
          'Intent is unknown. The command cannot be safely validated '
          'without a recognised intent.');
    }

    // Feature gate check.
    final requiredFlag = _kFeatureGatedIntents[command.intent];
    if (requiredFlag != null && !context.isFeatureEnabled(requiredFlag)) {
      violations.add(RestrictionCategory.featureGated);
      reasons.add(
          '"${command.intent.name}" requires the "$requiredFlag" '
          'feature to be enabled.');
    }

    // Offline restriction for network-dependent intents.
    if (!context.isOnline && _kOnlineRequiredIntents.contains(command.intent)) {
      violations.add(RestrictionCategory.conflictingState);
      reasons.add(
          '"${command.intent.name}" cannot proceed — '
          'network access is required but device is offline.');
    }

    // Rate limit.
    if (context.recentCommandCount > 100) {
      violations.add(RestrictionCategory.rateLimitExceeded);
      reasons.add(
          'Rate limit exceeded: ${context.recentCommandCount} recent '
          'commands. EditorController should pause command intake.');
    }

    // Guest cannot mutate.
    if (context.userPermissionTier == PermissionTier.guest &&
        command.intent != PolicyIntentType.selectLayer &&
        command.intent != PolicyIntentType.openLayerPanel &&
        command.intent != PolicyIntentType.clearSelection &&
        command.intent != PolicyIntentType.requestAnalysis &&
        command.intent != PolicyIntentType.requestSuggestion) {
      violations.add(RestrictionCategory.sourceBlocked);
      reasons.add(
          'Guest tier users may only observe — '
          'mutation commands are restricted.');
    }

    // Viewer cannot write.
    if (context.userPermissionTier == PermissionTier.viewer) {
      const viewerForbidden = {
        PolicyIntentType.addLayer,
        PolicyIntentType.deleteLayer,
        PolicyIntentType.moveLayer,
        PolicyIntentType.resizeLayer,
        PolicyIntentType.rotateLayer,
        PolicyIntentType.duplicateLayer,
        PolicyIntentType.changeColor,
        PolicyIntentType.changeFont,
        PolicyIntentType.changeOpacity,
        PolicyIntentType.applyTemplate,
        PolicyIntentType.batchEdit,
        PolicyIntentType.reorderLayers,
        PolicyIntentType.triggerPlugin,
        PolicyIntentType.runWorkflow,
        PolicyIntentType.saveDesign,
        PolicyIntentType.exportDesign,
        PolicyIntentType.openSettings,
      };
      if (viewerForbidden.contains(command.intent)) {
        violations.add(RestrictionCategory.sourceBlocked);
        reasons.add(
            'Viewer tier users cannot perform mutation operations. '
            '"${command.intent.name}" requires editor or owner access.');
      }
    }

    // Payload sanity — confidence zero with non-trivial intent.
    if (command.confidence <= 0.0 &&
        command.intent != PolicyIntentType.unknown) {
      violations.add(RestrictionCategory.payloadInvalid);
      reasons.add(
          'Command confidence is exactly 0 — '
          'the payload is likely malformed.');
    }

    if (violations.isEmpty) return const RestrictionCheckResult.clear();
    return RestrictionCheckResult.blocked(violations, reasons);
  }

  // ── checkConfirmationNeed ──────────────────────────────────────

  ConfirmationCheckResult checkConfirmationNeed(
      PolicyCommandSnapshot command,
      PolicyContextSnapshot context,
      PolicySourceType source,
      List<RiskFinding> riskFindings) {
    final triggers = <ConfirmationTrigger>[];

    // Destructive operations always prompt.
    if (_kDestructiveIntents.contains(command.intent)) {
      triggers.add(ConfirmationTrigger.destructiveAction);
    }

    // Bulk / all-layer target.
    if (command.target == PolicyCommandTarget.allLayers ||
        command.target == PolicyCommandTarget.visibleLayers ||
        command.target == PolicyCommandTarget.lockedLayers) {
      triggers.add(ConfirmationTrigger.bulkAction);
    }

    // Unsaved changes.
    if (context.hasUnsavedChanges &&
        _kDestructiveIntents.contains(command.intent)) {
      triggers.add(ConfirmationTrigger.unsavedChanges);
    }

    // Low confidence.
    if (command.confidence < 50.0) {
      triggers.add(ConfirmationTrigger.lowConfidence);
    }

    // High risk in findings.
    final hasHighRisk = riskFindings.any((f) =>
        f.level == RiskLevel.high || f.level == RiskLevel.critical);
    if (hasHighRisk) triggers.add(ConfirmationTrigger.highRisk);

    // External source.
    const externalSources = {
      PolicySourceType.robotAssistant,
      PolicySourceType.aiAssistant,
      PolicySourceType.automation,
      PolicySourceType.plugin,
      PolicySourceType.workflow,
    };
    if (externalSources.contains(source)) {
      triggers.add(ConfirmationTrigger.externalSource);
    }

    // Irreversible: delete, apply template, reorder are hard to undo if
    // there are already unsaved changes filling the undo stack.
    const irreversible = {
      PolicyIntentType.deleteLayer,
      PolicyIntentType.applyTemplate,
    };
    if (irreversible.contains(command.intent)) {
      triggers.add(ConfirmationTrigger.irreversibleChange);
    }

    // Feature-gated intents.
    if (_kFeatureGatedIntents.containsKey(command.intent)) {
      triggers.add(ConfirmationTrigger.featureGated);
    }

    if (triggers.isEmpty) return const ConfirmationCheckResult.notRequired();

    final unique = triggers.toSet().toList();
    final msg = _buildConfirmationMessage(command.intent, unique);
    return ConfirmationCheckResult.required(unique, msg);
  }

  // ── generateDecision ───────────────────────────────────────────

  PolicyDecision generateDecision(
      PolicyRequest request,
      _PolicyEvaluationBundle bundle) {
    final policyId = _EPIdGen.next('pol');

    // Hard validation errors → reject immediately.
    if (bundle.validationErrors.isNotEmpty) {
      return PolicyDecision.reject(
        policyId: policyId,
        commandId: request.commandId,
        requestId: request.requestId,
        riskLevel: RiskLevel.critical,
        riskScore: 100.0,
        riskFindings: bundle.riskFindings,
        restrictionReasons: bundle.validationErrors,
        reason: bundle.validationErrors.first,
      );
    }

    // Permission failure → reject.
    if (!bundle.permissionResult.permitted) {
      return PolicyDecision.reject(
        policyId: policyId,
        commandId: request.commandId,
        requestId: request.requestId,
        riskLevel: RiskLevel.high,
        riskScore: max(bundle.aggregateRiskScore, 60.0),
        riskFindings: bundle.riskFindings,
        restrictionReasons: [bundle.permissionResult.reason],
        reason: bundle.permissionResult.reason,
      );
    }

    // Restriction violation → reject.
    if (bundle.restrictionResult.restricted) {
      return PolicyDecision.reject(
        policyId: policyId,
        commandId: request.commandId,
        requestId: request.requestId,
        riskLevel: bundle.aggregateRiskLevel,
        riskScore: max(bundle.aggregateRiskScore, 55.0),
        riskFindings: bundle.riskFindings,
        restrictionReasons: bundle.restrictionResult.reasons,
        reason: bundle.restrictionResult.reasons.first,
      );
    }

    // Critical risk → reject.
    if (bundle.aggregateRiskLevel == RiskLevel.critical) {
      return PolicyDecision.reject(
        policyId: policyId,
        commandId: request.commandId,
        requestId: request.requestId,
        riskLevel: RiskLevel.critical,
        riskScore: bundle.aggregateRiskScore,
        riskFindings: bundle.riskFindings,
        restrictionReasons: bundle.riskFindings
            .where((f) => f.level == RiskLevel.critical)
            .map((f) => f.description)
            .toList(),
        reason: 'Command carries critical risk and cannot be recommended '
            'for approval. EditorController must intervene.',
      );
    }

    // Approved — with or without confirmation requirement.
    final confirmation = bundle.confirmationResult;
    return PolicyDecision.approve(
      policyId: policyId,
      commandId: request.commandId,
      requestId: request.requestId,
      riskLevel: bundle.aggregateRiskLevel,
      riskScore: bundle.aggregateRiskScore,
      riskFindings: bundle.riskFindings,
      requiresConfirmation: confirmation.required,
      confirmationTriggers: confirmation.triggers,
      reason: confirmation.required
          ? (confirmation.confirmationMessage ??
              'Command approved pending EditorController confirmation.')
          : 'Command approved. No confirmation required. '
              'EditorController may execute.',
    );
  }

  // ── Private: full evaluation bundle ───────────────────────────

  _PolicyEvaluationBundle _buildEvaluationBundle(PolicyRequest request) {
    final cmd = request.command;
    final ctx = request.contextSnapshot;
    final src = request.sourceType;

    final validationErrors = validateCommand(cmd);
    final riskFindings = evaluateRisk(cmd, ctx, src);
    final aggregateRisk = _aggregateRisk(riskFindings);
    final permissionResult = checkPermissions(cmd, ctx);
    final restrictionResult = checkRestrictions(cmd, ctx, src);
    final confirmationResult =
        checkConfirmationNeed(cmd, ctx, src, riskFindings);

    return _PolicyEvaluationBundle(
      riskFindings: riskFindings,
      aggregateRiskLevel: aggregateRisk.$1,
      aggregateRiskScore: aggregateRisk.$2,
      permissionResult: permissionResult,
      restrictionResult: restrictionResult,
      confirmationResult: confirmationResult,
      validationErrors: validationErrors,
    );
  }

  // ── Risk aggregation ───────────────────────────────────────────

  (RiskLevel, double) _aggregateRisk(List<RiskFinding> findings) {
    if (findings.isEmpty) return (RiskLevel.none, 0.0);

    double total = findings.fold(0.0, (sum, f) => sum + f.riskScore);
    total = total.clamp(0.0, 100.0);

    final highestLevel = findings
        .map((f) => f.level)
        .reduce((a, b) => a.index > b.index ? a : b);

    final effectiveLevel = total >= 70.0
        ? RiskLevel.critical
        : total >= 45.0
            ? RiskLevel.high
            : total >= 25.0
                ? RiskLevel.medium
                : total >= 10.0
                    ? RiskLevel.low
                    : RiskLevel.none;

    // Use the higher of score-derived and finding-derived level.
    final finalLevel = effectiveLevel.index > highestLevel.index
        ? effectiveLevel
        : highestLevel;

    return (finalLevel, double.parse(total.toStringAsFixed(2)));
  }

  // ── Confirmation message builder ───────────────────────────────

  String _buildConfirmationMessage(
      PolicyIntentType intent, List<ConfirmationTrigger> triggers) {
    final buf = StringBuffer();

    buf.write('EditorController confirmation required before executing '
        '"${intent.name}". ');

    if (triggers.contains(ConfirmationTrigger.destructiveAction)) {
      buf.write('This is a destructive operation. ');
    }
    if (triggers.contains(ConfirmationTrigger.irreversibleChange)) {
      buf.write('This change may be difficult to undo. ');
    }
    if (triggers.contains(ConfirmationTrigger.unsavedChanges)) {
      buf.write('There are unsaved changes that could be lost. ');
    }
    if (triggers.contains(ConfirmationTrigger.bulkAction)) {
      buf.write('This operation affects multiple layers simultaneously. ');
    }
    if (triggers.contains(ConfirmationTrigger.externalSource)) {
      buf.write('This command originates from an external source. ');
    }
    if (triggers.contains(ConfirmationTrigger.highRisk)) {
      buf.write('The command has been flagged as high risk. ');
    }
    if (triggers.contains(ConfirmationTrigger.lowConfidence)) {
      buf.write('Intent confidence is low — please verify the action. ');
    }
    if (triggers.contains(ConfirmationTrigger.featureGated)) {
      buf.write('This feature may require additional permissions. ');
    }

    buf.write('EditorController holds final execution authority.');
    return buf.toString().trim();
  }

  // ── Request guard ─────────────────────────────────────────────

  List<String> _guardRequest(PolicyRequest request) {
    final errors = <String>[];
    if (request.requestId.trim().isEmpty) {
      errors.add('PolicyRequest.requestId must not be empty.');
    }
    if (request.commandId.trim().isEmpty) {
      errors.add('PolicyRequest.commandId must not be empty.');
    }
    if (request.commandId != request.command.commandId) {
      errors.add(
          'PolicyRequest.commandId "${request.commandId}" does not match '
          'command snapshot commandId "${request.command.commandId}".');
    }
    return errors;
  }
}

// ── Forbidden parameter keys ───────────────────────────────────
const _kForbiddenParamKeys = {
  'layerengine', 'historyengine', 'renderengine',
  'storageengine', 'exportengine', 'canvas',
  'buildcontext', 'widget', 'aiengine',
};
