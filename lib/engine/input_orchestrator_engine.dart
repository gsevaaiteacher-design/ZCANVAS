// ignore_for_file: avoid_catches_without_on_clauses

import 'dart:math';

// ── Input types ────────────────────────────────────────────────
enum InputType {
  text,
  voice,
  gesture,
  robot,
  multimodal,
  unknown,
}

// ── Device mode ────────────────────────────────────────────────
enum DeviceMode {
  mobile,
  tablet,
  desktop,
  tv,
  robotFuture,
  unknown,
}

// ── Intent types ───────────────────────────────────────────────
enum IntentType {
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
  unknown,
}

// ── Routing target ─────────────────────────────────────────────
enum TargetSuggestionEngine {
  suggestionEngine,
  insightEngine,
  editorController,
  none,
}

// ── Confidence tier ────────────────────────────────────────────
enum IntentConfidenceTier { veryLow, low, medium, high, veryHigh }

extension IntentConfidenceTierRange on IntentConfidenceTier {
  static IntentConfidenceTier from(double score) {
    if (score >= 88.0) return IntentConfidenceTier.veryHigh;
    if (score >= 70.0) return IntentConfidenceTier.high;
    if (score >= 50.0) return IntentConfidenceTier.medium;
    if (score >= 28.0) return IntentConfidenceTier.low;
    return IntentConfidenceTier.veryLow;
  }
}

// ── Context snapshot ───────────────────────────────────────────
class InputContextSnapshot {
  final String? activeDesignId;
  final String? selectedLayerId;
  final int layerCount;
  final bool hasUnsavedChanges;
  final Map<String, dynamic> sessionData;

  const InputContextSnapshot({
    this.activeDesignId,
    this.selectedLayerId,
    required this.layerCount,
    required this.hasUnsavedChanges,
    this.sessionData = const {},
  });
}

// ── InteractionRequest — input contract ───────────────────────
class InteractionRequest {
  final String requestId;
  final InputType inputType;
  final String rawPayload;
  final InputContextSnapshot contextSnapshot;
  final DeviceMode deviceMode;
  final Map<String, dynamic> inputMetadata;

  const InteractionRequest({
    required this.requestId,
    required this.inputType,
    required this.rawPayload,
    required this.contextSnapshot,
    required this.deviceMode,
    this.inputMetadata = const {},
  });
}

// ── Safe action step ───────────────────────────────────────────
class SafeActionStep {
  final String stepId;
  final String actionType;
  final String description;
  final Map<String, dynamic> parameters;
  final bool requiresApproval;
  final int priority;

  const SafeActionStep._({
    required this.stepId,
    required this.actionType,
    required this.description,
    required this.parameters,
    required this.priority,
  }) : requiresApproval = true;

  factory SafeActionStep.create({
    required String stepId,
    required String actionType,
    required String description,
    Map<String, dynamic> parameters = const {},
    int priority = 5,
  }) =>
      SafeActionStep._(
        stepId: stepId,
        actionType: actionType,
        description: description,
        parameters: Map.unmodifiable(parameters),
        priority: priority.clamp(1, 10),
      );

  Map<String, dynamic> toMap() => {
        'stepId': stepId,
        'actionType': actionType,
        'description': description,
        'parameters': parameters,
        'requiresApproval': requiresApproval,
        'priority': priority,
      };
}

// ── SafeActionProposal ────────────────────────────────────────
class SafeActionProposal {
  final String proposalId;
  final String intentId;
  final List<SafeActionStep> steps;
  final String humanReadableSummary;
  final double confidenceScore;
  final bool requiresApproval;
  final String routingTarget;

  const SafeActionProposal._({
    required this.proposalId,
    required this.intentId,
    required this.steps,
    required this.humanReadableSummary,
    required this.confidenceScore,
    required this.routingTarget,
  }) : requiresApproval = true;

  factory SafeActionProposal.create({
    required String proposalId,
    required String intentId,
    required List<SafeActionStep> steps,
    required String humanReadableSummary,
    required double confidenceScore,
    required String routingTarget,
  }) =>
      SafeActionProposal._(
        proposalId: proposalId,
        intentId: intentId,
        steps: List.unmodifiable(steps),
        humanReadableSummary: humanReadableSummary,
        confidenceScore: confidenceScore.clamp(0.0, 100.0),
        routingTarget: routingTarget,
      );

  factory SafeActionProposal.empty(String intentId) =>
      SafeActionProposal._(
        proposalId: _IOIdGen.next('prop'),
        intentId: intentId,
        steps: const [],
        humanReadableSummary: 'No actionable proposal — intent unclear.',
        confidenceScore: 0.0,
        routingTarget: TargetSuggestionEngine.none.name,
      );

  Map<String, dynamic> toMap() => {
        'proposalId': proposalId,
        'intentId': intentId,
        'steps': steps.map((s) => s.toMap()).toList(),
        'humanReadableSummary': humanReadableSummary,
        'confidenceScore': confidenceScore,
        'requiresApproval': requiresApproval,
        'routingTarget': routingTarget,
      };
}

// ── NormalizedIntent — output contract ────────────────────────
class NormalizedIntent {
  final String intentId;
  final String requestId;
  final IntentType intentType;
  final String normalizedAction;
  final double confidenceScore;
  final IntentConfidenceTier confidenceTier;
  final TargetSuggestionEngine targetSuggestionEngine;
  final SafeActionProposal safeActionPlan;
  final InputType sourceInputType;
  final DeviceMode deviceMode;
  final List<String> warnings;

  // CONTRACT HARD RULE: requiresEditorApproval is ALWAYS true.
  // No intent may ever be executed without EditorController gate.
  final bool requiresEditorApproval;

  const NormalizedIntent._({
    required this.intentId,
    required this.requestId,
    required this.intentType,
    required this.normalizedAction,
    required this.confidenceScore,
    required this.confidenceTier,
    required this.targetSuggestionEngine,
    required this.safeActionPlan,
    required this.sourceInputType,
    required this.deviceMode,
    required this.warnings,
  }) : requiresEditorApproval = true;

  factory NormalizedIntent.create({
    required String intentId,
    required String requestId,
    required IntentType intentType,
    required String normalizedAction,
    required double confidenceScore,
    required TargetSuggestionEngine targetSuggestionEngine,
    required SafeActionProposal safeActionPlan,
    required InputType sourceInputType,
    required DeviceMode deviceMode,
    List<String> warnings = const [],
  }) {
    final clamped = confidenceScore.clamp(0.0, 100.0);
    return NormalizedIntent._(
      intentId: intentId,
      requestId: requestId,
      intentType: intentType,
      normalizedAction: normalizedAction,
      confidenceScore: double.parse(clamped.toStringAsFixed(2)),
      confidenceTier: IntentConfidenceTierRange.from(clamped),
      targetSuggestionEngine: targetSuggestionEngine,
      safeActionPlan: safeActionPlan,
      sourceInputType: sourceInputType,
      deviceMode: deviceMode,
      warnings: List.unmodifiable(warnings),
    );
  }

  Map<String, dynamic> toMap() => {
        'intentId': intentId,
        'requestId': requestId,
        'intentType': intentType.name,
        'normalizedAction': normalizedAction,
        'confidenceScore': confidenceScore,
        'confidenceTier': confidenceTier.name,
        'targetSuggestionEngine': targetSuggestionEngine.name,
        'safeActionPlan': safeActionPlan.toMap(),
        'sourceInputType': sourceInputType.name,
        'deviceMode': deviceMode.name,
        'requiresEditorApproval': requiresEditorApproval,
        'warnings': warnings,
      };
}

// ── Orchestration result ───────────────────────────────────────
class OrchestrationResult {
  final bool success;
  final NormalizedIntent? intent;
  final List<String> errors;
  final List<String> warnings;

  const OrchestrationResult.ok(this.intent, {this.warnings = const []})
      : success = true,
        errors = const [];

  const OrchestrationResult.failure(this.errors, {this.warnings = const []})
      : success = false,
        intent = null;
}

// ── Validation result ──────────────────────────────────────────
class IntentValidationResult {
  final bool valid;
  final List<String> errors;
  final List<String> warnings;

  const IntentValidationResult.ok({this.warnings = const []})
      : valid = true,
        errors = const [];

  const IntentValidationResult.fail(this.errors,
      {this.warnings = const []})
      : valid = false;
}

// ── Voice parse result ─────────────────────────────────────────
class VoiceParseResult {
  final IntentType intentType;
  final double confidence;
  final Map<String, dynamic> extractedParameters;
  final String normalizedText;
  final List<String> alternativeInterpretations;

  const VoiceParseResult({
    required this.intentType,
    required this.confidence,
    required this.extractedParameters,
    required this.normalizedText,
    this.alternativeInterpretations = const [],
  });
}

// ── Gesture parse result ───────────────────────────────────────
class GestureParseResult {
  final IntentType intentType;
  final double confidence;
  final Map<String, dynamic> extractedParameters;
  final String gestureLabel;

  const GestureParseResult({
    required this.intentType,
    required this.confidence,
    required this.extractedParameters,
    required this.gestureLabel,
  });
}

// ── ID generator ──────────────────────────────────────────────
class _IOIdGen {
  static final Random _rng = Random.secure();

  static String next(String prefix) {
    final bytes = List<int>.generate(8, (_) => _rng.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '$prefix-$hex-${DateTime.now().microsecondsSinceEpoch}';
  }
}

// ── Voice keyword map (read-only, no engine calls) ────────────
const Map<String, IntentType> _kVoiceKeywords = {
  'add layer':       IntentType.addLayer,
  'new layer':       IntentType.addLayer,
  'create layer':    IntentType.addLayer,
  'delete layer':    IntentType.deleteLayer,
  'remove layer':    IntentType.deleteLayer,
  'select':          IntentType.selectLayer,
  'move':            IntentType.moveLayer,
  'drag':            IntentType.moveLayer,
  'resize':          IntentType.resizeLayer,
  'scale':           IntentType.resizeLayer,
  'rotate':          IntentType.rotateLayer,
  'turn':            IntentType.rotateLayer,
  'duplicate':       IntentType.duplicateLayer,
  'copy':            IntentType.duplicateLayer,
  'show layer':      IntentType.showLayer,
  'unhide':          IntentType.showLayer,
  'hide layer':      IntentType.hideLayer,
  'hide':            IntentType.hideLayer,
  'lock layer':      IntentType.lockLayer,
  'lock':            IntentType.lockLayer,
  'unlock layer':    IntentType.unlockLayer,
  'unlock':          IntentType.unlockLayer,
  'change color':    IntentType.changeColor,
  'colour':          IntentType.changeColor,
  'color':           IntentType.changeColor,
  'change font':     IntentType.changeFont,
  'font':            IntentType.changeFont,
  'apply template':  IntentType.applyTemplate,
  'template':        IntentType.applyTemplate,
  'undo':            IntentType.undoAction,
  'go back':         IntentType.undoAction,
  'redo':            IntentType.redoAction,
  'save':            IntentType.saveDesign,
  'export':          IntentType.exportDesign,
  'settings':        IntentType.openSettings,
  'layers panel':    IntentType.openLayerPanel,
  'deselect':        IntentType.clearSelection,
  'clear selection': IntentType.clearSelection,
  'batch':           IntentType.batchEdit,
  'reorder':         IntentType.reorderLayers,
};

// ── Gesture pattern map (future-ready, no engine calls) ───────
const Map<String, IntentType> _kGesturePatterns = {
  'swipe_up':           IntentType.addLayer,
  'swipe_down':         IntentType.deleteLayer,
  'swipe_left':         IntentType.undoAction,
  'swipe_right':        IntentType.redoAction,
  'pinch_in':           IntentType.resizeLayer,
  'pinch_out':          IntentType.resizeLayer,
  'two_finger_tap':     IntentType.selectLayer,
  'long_press':         IntentType.openLayerPanel,
  'rotate_gesture':     IntentType.rotateLayer,
  'double_tap':         IntentType.duplicateLayer,
  'three_finger_swipe': IntentType.batchEdit,
  'tap':                IntentType.selectLayer,
};

// ── Intent routing table ───────────────────────────────────────
const Map<IntentType, TargetSuggestionEngine> _kIntentRouting = {
  IntentType.addLayer:       TargetSuggestionEngine.editorController,
  IntentType.deleteLayer:    TargetSuggestionEngine.editorController,
  IntentType.selectLayer:    TargetSuggestionEngine.editorController,
  IntentType.moveLayer:      TargetSuggestionEngine.editorController,
  IntentType.resizeLayer:    TargetSuggestionEngine.editorController,
  IntentType.rotateLayer:    TargetSuggestionEngine.editorController,
  IntentType.duplicateLayer: TargetSuggestionEngine.editorController,
  IntentType.showLayer:      TargetSuggestionEngine.editorController,
  IntentType.hideLayer:      TargetSuggestionEngine.editorController,
  IntentType.lockLayer:      TargetSuggestionEngine.editorController,
  IntentType.unlockLayer:    TargetSuggestionEngine.editorController,
  IntentType.changeColor:    TargetSuggestionEngine.editorController,
  IntentType.changeFont:     TargetSuggestionEngine.editorController,
  IntentType.applyTemplate:  TargetSuggestionEngine.editorController,
  IntentType.undoAction:     TargetSuggestionEngine.editorController,
  IntentType.redoAction:     TargetSuggestionEngine.editorController,
  IntentType.saveDesign:     TargetSuggestionEngine.editorController,
  IntentType.exportDesign:   TargetSuggestionEngine.editorController,
  IntentType.openSettings:   TargetSuggestionEngine.editorController,
  IntentType.openLayerPanel: TargetSuggestionEngine.suggestionEngine,
  IntentType.clearSelection: TargetSuggestionEngine.editorController,
  IntentType.batchEdit:      TargetSuggestionEngine.editorController,
  IntentType.reorderLayers:  TargetSuggestionEngine.editorController,
  IntentType.unknown:        TargetSuggestionEngine.suggestionEngine,
};

// ── InputOrchestratorEngine ───────────────────────────────────
class InputOrchestratorEngine {
  // ── Public entry point ────────────────────────────────────────

  OrchestrationResult processInput(InteractionRequest request) {
    try {
      final validation = _validateRequest(request);
      if (!validation.valid) {
        return OrchestrationResult.failure(validation.errors,
            warnings: validation.warnings);
      }

      final detectedType = detectInputType(request);
      final normalized = normalizeInput(request, detectedType);
      final intent = buildIntent(normalized, request);
      final intentValidation = validateIntent(intent);

      if (!intentValidation.valid) {
        return OrchestrationResult.failure(intentValidation.errors,
            warnings: [...validation.warnings, ...intentValidation.warnings]);
      }

      return OrchestrationResult.ok(intent,
          warnings: [...validation.warnings, ...intentValidation.warnings]);
    } catch (e) {
      return OrchestrationResult.failure(
          ['processInput threw: $e']);
    }
  }

  // ── detectInputType ────────────────────────────────────────────

  InputType detectInputType(InteractionRequest request) {
    // Explicit declaration from caller takes priority.
    if (request.inputType != InputType.unknown) {
      return request.inputType;
    }

    final payload = request.rawPayload.trim().toLowerCase();
    final meta = request.inputMetadata;

    // Metadata hints.
    final metaType = meta['inputType']?.toString().toLowerCase();
    if (metaType != null) {
      switch (metaType) {
        case 'voice':      return InputType.voice;
        case 'gesture':    return InputType.gesture;
        case 'robot':      return InputType.robot;
        case 'multimodal': return InputType.multimodal;
        case 'text':       return InputType.text;
      }
    }

    // Gesture-pattern heuristic.
    if (_kGesturePatterns.keys.any((k) => payload.contains(k))) {
      return InputType.gesture;
    }

    // Voice heuristic — starts with common spoken words.
    final voiceStarters = ['hey', 'please', 'can you', 'could you', 'i want'];
    if (voiceStarters.any((s) => payload.startsWith(s))) {
      return InputType.voice;
    }

    // Robot / automation marker.
    if (payload.startsWith('robot:') || payload.startsWith('auto:')) {
      return InputType.robot;
    }

    // Multimodal marker.
    if (meta.containsKey('gesturePayload') && meta.containsKey('textPayload')) {
      return InputType.multimodal;
    }

    return InputType.text;
  }

  // ── normalizeInput ─────────────────────────────────────────────

  String normalizeInput(InteractionRequest request, InputType detectedType) {
    var raw = request.rawPayload.trim();

    switch (detectedType) {
      case InputType.voice:
        raw = _normalizeVoice(raw);
        break;
      case InputType.gesture:
        raw = _normalizeGesture(raw);
        break;
      case InputType.robot:
        raw = _normalizeRobot(raw);
        break;
      case InputType.multimodal:
        raw = _normalizeMultimodal(raw, request.inputMetadata);
        break;
      case InputType.text:
      case InputType.unknown:
        raw = _normalizeText(raw);
        break;
    }

    return raw;
  }

  // ── parseVoiceInput ────────────────────────────────────────────

  VoiceParseResult parseVoiceInput(String normalizedText) {
    final lower = normalizedText.toLowerCase();
    IntentType matched = IntentType.unknown;
    double confidence = 30.0;
    final params = <String, dynamic>{};
    final alternatives = <String>[];

    // Longest-match keyword scan.
    int bestLen = 0;
    for (final entry in _kVoiceKeywords.entries) {
      if (lower.contains(entry.key) && entry.key.length > bestLen) {
        matched = entry.value;
        bestLen = entry.key.length;
      }
    }

    // Confidence scales with keyword specificity.
    if (matched != IntentType.unknown) {
      confidence = bestLen > 8 ? 82.0 : bestLen > 4 ? 68.0 : 54.0;
    }

    // Extract optional target from "... the [target]" pattern.
    final targetMatch = RegExp(r'\bthe\s+(\w+)\b').firstMatch(lower);
    if (targetMatch != null) {
      params['voiceTarget'] = targetMatch.group(1);
    }

    // Extract numeric values (e.g. "rotate 45 degrees").
    final numMatch = RegExp(r'\b(\d+(?:\.\d+)?)\b').firstMatch(lower);
    if (numMatch != null) {
      params['numericValue'] = double.tryParse(numMatch.group(1) ?? '');
    }

    // Extract colour names.
    const colours = [
      'red', 'blue', 'green', 'yellow', 'black', 'white',
      'orange', 'purple', 'pink', 'grey', 'gray', 'brown',
    ];
    for (final colour in colours) {
      if (lower.contains(colour)) {
        params['colorHint'] = colour;
        break;
      }
    }

    // Build alternatives from other keyword matches.
    for (final entry in _kVoiceKeywords.entries) {
      if (lower.contains(entry.key) && entry.value != matched) {
        final alt = entry.value.name;
        if (!alternatives.contains(alt)) alternatives.add(alt);
        if (alternatives.length >= 3) break;
      }
    }

    return VoiceParseResult(
      intentType: matched,
      confidence: confidence,
      extractedParameters: Map.unmodifiable(params),
      normalizedText: normalizedText,
      alternativeInterpretations: List.unmodifiable(alternatives),
    );
  }

  // ── parseGestureInput ──────────────────────────────────────────

  GestureParseResult parseGestureInput(String normalizedGesture) {
    final lower = normalizedGesture.toLowerCase().trim();
    IntentType matched = IntentType.unknown;
    double confidence = 35.0;
    String label = lower;
    final params = <String, dynamic>{};

    // Direct pattern lookup (longest match).
    int bestLen = 0;
    for (final entry in _kGesturePatterns.entries) {
      if (lower.contains(entry.key) && entry.key.length > bestLen) {
        matched = entry.value;
        bestLen = entry.key.length;
        label = entry.key;
      }
    }

    if (matched != IntentType.unknown) {
      confidence = 78.0;
    }

    // Extract velocity hint (fast / slow).
    if (lower.contains('fast') || lower.contains('quick')) {
      params['velocity'] = 'fast';
    } else if (lower.contains('slow')) {
      params['velocity'] = 'slow';
    }

    // Extract direction hint.
    for (final dir in ['up', 'down', 'left', 'right']) {
      if (lower.contains(dir)) {
        params['direction'] = dir;
        break;
      }
    }

    // Pinch direction.
    if (label.contains('pinch')) {
      params['pinchDirection'] =
          label.contains('in') ? 'shrink' : 'grow';
    }

    return GestureParseResult(
      intentType: matched,
      confidence: confidence,
      extractedParameters: Map.unmodifiable(params),
      gestureLabel: label,
    );
  }

  // ── buildIntent ────────────────────────────────────────────────

  NormalizedIntent buildIntent(
      String normalizedInput, InteractionRequest request) {
    final intentId = _IOIdGen.next('int');
    final detectedType = detectInputType(request);

    IntentType intentType;
    double confidence;
    Map<String, dynamic> params;

    switch (detectedType) {
      case InputType.voice:
        final parsed = parseVoiceInput(normalizedInput);
        intentType = parsed.intentType;
        confidence = parsed.confidence;
        params = Map<String, dynamic>.from(parsed.extractedParameters);
        break;

      case InputType.gesture:
        final parsed = parseGestureInput(normalizedInput);
        intentType = parsed.intentType;
        confidence = parsed.confidence;
        params = Map<String, dynamic>.from(parsed.extractedParameters);
        break;

      case InputType.robot:
        final parsed = _parseRobotPayload(normalizedInput);
        intentType = parsed.$1;
        confidence = parsed.$2;
        params = parsed.$3;
        break;

      case InputType.multimodal:
        final parsed = _parseMultimodalPayload(
            normalizedInput, request.inputMetadata);
        intentType = parsed.$1;
        confidence = parsed.$2;
        params = parsed.$3;
        break;

      case InputType.text:
      case InputType.unknown:
        final parsed = _parseTextPayload(normalizedInput);
        intentType = parsed.$1;
        confidence = parsed.$2;
        params = parsed.$3;
        break;
    }

    // Inject context.
    params['requestId'] = request.requestId;
    params['deviceMode'] = request.deviceMode.name;
    if (request.contextSnapshot.selectedLayerId != null) {
      params['contextSelectedLayerId'] =
          request.contextSnapshot.selectedLayerId;
    }
    if (request.contextSnapshot.activeDesignId != null) {
      params['contextDesignId'] = request.contextSnapshot.activeDesignId;
    }

    final safeParams = _sanitiseParams(params);
    final target =
        _kIntentRouting[intentType] ?? TargetSuggestionEngine.suggestionEngine;
    final plan = createSafeActionPlan(intentId, intentType,
        confidence, target, safeParams, request.contextSnapshot);

    final warnings = <String>[];
    if (intentType == IntentType.unknown) {
      warnings.add(
          'Intent could not be determined from input; '
          'routed to SuggestionEngine for guidance.');
    }
    if (confidence < 50.0) {
      warnings.add(
          'Low confidence (${confidence.toStringAsFixed(1)}) — '
          'EditorController should request user confirmation.');
    }

    return NormalizedIntent.create(
      intentId: intentId,
      requestId: request.requestId,
      intentType: intentType,
      normalizedAction: intentType.name,
      confidenceScore: confidence,
      targetSuggestionEngine: target,
      safeActionPlan: plan,
      sourceInputType: detectedType,
      deviceMode: request.deviceMode,
      warnings: warnings,
    );
  }

  // ── validateIntent ─────────────────────────────────────────────

  IntentValidationResult validateIntent(NormalizedIntent intent) {
    final errors = <String>[];
    final warnings = <String>[];

    if (intent.intentId.trim().isEmpty) {
      errors.add('NormalizedIntent.intentId must not be empty.');
    }
    if (intent.requestId.trim().isEmpty) {
      errors.add('NormalizedIntent.requestId must not be empty.');
    }
    if (intent.normalizedAction.trim().isEmpty) {
      errors.add('NormalizedIntent.normalizedAction must not be empty.');
    }
    if (!intent.requiresEditorApproval) {
      errors.add(
          'NormalizedIntent.requiresEditorApproval must be true. '
          'All intents require EditorController gate — this is a '
          'Phase-7 contract violation.');
    }
    if (intent.confidenceScore < 0.0 || intent.confidenceScore > 100.0) {
      errors.add(
          'NormalizedIntent.confidenceScore ${intent.confidenceScore} '
          'is outside [0, 100].');
    }
    if (!intent.safeActionPlan.requiresApproval) {
      errors.add(
          'SafeActionProposal.requiresApproval must be true. '
          'No action proposal may bypass EditorController.');
    }
    for (final step in intent.safeActionPlan.steps) {
      if (!step.requiresApproval) {
        errors.add(
            'SafeActionStep "${step.stepId}" has requiresApproval=false, '
            'which violates the Phase-7 contract.');
      }
      if (step.actionType.trim().isEmpty) {
        errors.add('SafeActionStep "${step.stepId}" has empty actionType.');
      }
      _checkForbiddenParams(step.parameters, step.stepId, errors);
    }

    if (errors.isEmpty) {
      return IntentValidationResult.ok(warnings: warnings);
    }
    return IntentValidationResult.fail(errors, warnings: warnings);
  }

  // ── createSafeActionPlan ───────────────────────────────────────

  SafeActionProposal createSafeActionPlan(
      String intentId,
      IntentType intentType,
      double confidence,
      TargetSuggestionEngine target,
      Map<String, dynamic> parameters,
      InputContextSnapshot context) {
    final proposalId = _IOIdGen.next('prop');

    if (intentType == IntentType.unknown || confidence < 28.0) {
      return SafeActionProposal._(
        proposalId: proposalId,
        intentId: intentId,
        steps: const [],
        humanReadableSummary:
            'Intent is unclear. EditorController should prompt the user '
            'for clarification before taking any action.',
        confidenceScore: confidence,
        routingTarget: TargetSuggestionEngine.suggestionEngine.name,
      );
    }

    final steps = _buildStepsForIntent(
        intentType, parameters, context, proposalId);
    final summary = _buildHumanSummary(intentType, parameters, confidence);

    return SafeActionProposal._(
      proposalId: proposalId,
      intentId: intentId,
      steps: List.unmodifiable(steps),
      humanReadableSummary: summary,
      confidenceScore: confidence.clamp(0.0, 100.0),
      routingTarget: target.name,
    );
  }

  // ── Private normalizers ───────────────────────────────────────

  String _normalizeText(String raw) =>
      raw.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  String _normalizeVoice(String raw) {
    var text = raw.trim().toLowerCase();
    // Strip common filler words.
    const fillers = [
      'um ', 'uh ', 'like ', 'you know ', 'basically ',
      'actually ', 'just ', 'please ', 'hey ', 'okay ',
    ];
    for (final filler in fillers) {
      text = text.replaceAll(filler, ' ');
    }
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _normalizeGesture(String raw) =>
      raw.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');

  String _normalizeRobot(String raw) {
    final stripped = raw.replaceFirst(RegExp(r'^robot:\s*', caseSensitive: false), '');
    return stripped.trim().toLowerCase();
  }

  String _normalizeMultimodal(String raw, Map<String, dynamic> meta) {
    final text = (meta['textPayload'] as String?) ?? raw;
    final gesture = (meta['gesturePayload'] as String?) ?? '';
    final combined = '${_normalizeText(text)} ${_normalizeGesture(gesture)}'.trim();
    return combined;
  }

  // ── Private parsers ───────────────────────────────────────────

  (IntentType, double, Map<String, dynamic>) _parseTextPayload(String text) {
    final lower = text.toLowerCase();
    IntentType matched = IntentType.unknown;
    double confidence = 30.0;
    final params = <String, dynamic>{};
    int bestLen = 0;

    for (final entry in _kVoiceKeywords.entries) {
      if (lower.contains(entry.key) && entry.key.length > bestLen) {
        matched = entry.value;
        bestLen = entry.key.length;
      }
    }

    if (matched != IntentType.unknown) {
      confidence = bestLen > 8 ? 80.0 : 65.0;
    }

    final num = RegExp(r'\b(\d+(?:\.\d+)?)\b').firstMatch(lower);
    if (num != null) params['numericValue'] = double.tryParse(num.group(1)!);

    return (matched, confidence, params);
  }

  (IntentType, double, Map<String, dynamic>) _parseRobotPayload(String text) {
    final lower = text.toLowerCase();
    IntentType matched = IntentType.unknown;
    final params = <String, dynamic>{'source': 'robot'};
    int bestLen = 0;

    for (final entry in _kVoiceKeywords.entries) {
      if (lower.contains(entry.key) && entry.key.length > bestLen) {
        matched = entry.value;
        bestLen = entry.key.length;
      }
    }

    // Robot inputs are more explicit — higher confidence if matched.
    final confidence = matched != IntentType.unknown ? 85.0 : 25.0;
    return (matched, confidence, params);
  }

  (IntentType, double, Map<String, dynamic>) _parseMultimodalPayload(
      String combined, Map<String, dynamic> meta) {
    final lower = combined.toLowerCase();
    IntentType matched = IntentType.unknown;
    final params = <String, dynamic>{'source': 'multimodal'};
    int bestLen = 0;

    for (final entry in _kVoiceKeywords.entries) {
      if (lower.contains(entry.key) && entry.key.length > bestLen) {
        matched = entry.value;
        bestLen = entry.key.length;
      }
    }
    for (final entry in _kGesturePatterns.entries) {
      if (lower.contains(entry.key) && entry.key.length > bestLen) {
        matched = entry.value;
        bestLen = entry.key.length;
      }
    }

    // Multimodal fusion increases confidence.
    final confidence = matched != IntentType.unknown ? 88.0 : 32.0;
    if (meta.containsKey('fusionScore')) {
      params['fusionScore'] = meta['fusionScore'];
    }
    return (matched, confidence, params);
  }

  // ── Step builders ──────────────────────────────────────────────

  List<SafeActionStep> _buildStepsForIntent(
      IntentType intent,
      Map<String, dynamic> params,
      InputContextSnapshot context,
      String proposalId) {
    final steps = <SafeActionStep>[];
    final pid = proposalId;

    switch (intent) {
      case IntentType.addLayer:
        steps.add(SafeActionStep.create(
          stepId: _IOIdGen.next('step'),
          actionType: 'add_layer',
          description: 'Add a new layer to the canvas.',
          parameters: {
            ...params,
            'designId': context.activeDesignId,
          },
          priority: 6,
        ));
        break;

      case IntentType.deleteLayer:
        steps.add(SafeActionStep.create(
          stepId: _IOIdGen.next('step'),
          actionType: 'delete_layer',
          description: 'Delete the selected layer.',
          parameters: {
            ...params,
            'targetLayerId': context.selectedLayerId,
          },
          priority: 8,
        ));
        break;

      case IntentType.selectLayer:
        steps.add(SafeActionStep.create(
          stepId: _IOIdGen.next('step'),
          actionType: 'select_layer',
          description: 'Select the target layer.',
          parameters: params,
          priority: 5,
        ));
        break;

      case IntentType.moveLayer:
        steps.add(SafeActionStep.create(
          stepId: _IOIdGen.next('step'),
          actionType: 'move_layer',
          description: 'Move the selected layer to a new position.',
          parameters: {
            ...params,
            'targetLayerId': context.selectedLayerId,
          },
          priority: 6,
        ));
        break;

      case IntentType.resizeLayer:
        steps.add(SafeActionStep.create(
          stepId: _IOIdGen.next('step'),
          actionType: 'resize_layer',
          description: 'Resize the selected layer.',
          parameters: {
            ...params,
            'targetLayerId': context.selectedLayerId,
          },
          priority: 6,
        ));
        break;

      case IntentType.rotateLayer:
        steps.add(SafeActionStep.create(
          stepId: _IOIdGen.next('step'),
          actionType: 'rotate_layer',
          description: 'Rotate the selected layer.',
          parameters: {
            ...params,
            'targetLayerId': context.selectedLayerId,
          },
          priority: 5,
        ));
        break;

      case IntentType.duplicateLayer:
        steps.add(SafeActionStep.create(
          stepId: _IOIdGen.next('step'),
          actionType: 'duplicate_layer',
          description: 'Duplicate the selected layer.',
          parameters: {
            ...params,
            'targetLayerId': context.selectedLayerId,
          },
          priority: 6,
        ));
        break;

      case IntentType.showLayer:
        steps.add(SafeActionStep.create(
          stepId: _IOIdGen.next('step'),
          actionType: 'show_layer',
          description: 'Make the target layer visible.',
          parameters: {
            ...params,
            'targetLayerId': context.selectedLayerId,
          },
          priority: 5,
        ));
        break;

      case IntentType.hideLayer:
        steps.add(SafeActionStep.create(
          stepId: _IOIdGen.next('step'),
          actionType: 'hide_layer',
          description: 'Hide the target layer.',
          parameters: {
            ...params,
            'targetLayerId': context.selectedLayerId,
          },
          priority: 5,
        ));
        break;

      case IntentType.lockLayer:
        steps.add(SafeActionStep.create(
          stepId: _IOIdGen.next('step'),
          actionType: 'lock_layer',
          description: 'Lock the selected layer to prevent editing.',
          parameters: {
            ...params,
            'targetLayerId': context.selectedLayerId,
          },
          priority: 5,
        ));
        break;

      case IntentType.unlockLayer:
        steps.add(SafeActionStep.create(
          stepId: _IOIdGen.next('step'),
          actionType: 'unlock_layer',
          description: 'Unlock the selected layer.',
          parameters: {
            ...params,
            'targetLayerId': context.selectedLayerId,
          },
          priority: 5,
        ));
        break;

      case IntentType.changeColor:
        steps.add(SafeActionStep.create(
          stepId: _IOIdGen.next('step'),
          actionType: 'change_color',
          description: 'Change the colour of the selected layer.',
          parameters: {
            ...params,
            'targetLayerId': context.selectedLayerId,
          },
          priority: 5,
        ));
        break;

      case IntentType.changeFont:
        steps.add(SafeActionStep.create(
          stepId: _IOIdGen.next('step'),
          actionType: 'change_font',
          description: 'Update the font of the selected text layer.',
          parameters: {
            ...params,
            'targetLayerId': context.selectedLayerId,
          },
          priority: 5,
        ));
        break;

      case IntentType.applyTemplate:
        steps.add(SafeActionStep.create(
          stepId: _IOIdGen.next('step'),
          actionType: 'apply_template',
          description: 'Apply a template to the current design.',
          parameters: {
            ...params,
            'designId': context.activeDesignId,
          },
          priority: 7,
        ));
        break;

      case IntentType.undoAction:
        steps.add(SafeActionStep.create(
          stepId: _IOIdGen.next('step'),
          actionType: 'undo',
          description: 'Undo the last action.',
          parameters: params,
          priority: 9,
        ));
        break;

      case IntentType.redoAction:
        steps.add(SafeActionStep.create(
          stepId: _IOIdGen.next('step'),
          actionType: 'redo',
          description: 'Redo the previously undone action.',
          parameters: params,
          priority: 9,
        ));
        break;

      case IntentType.saveDesign:
        steps.add(SafeActionStep.create(
          stepId: _IOIdGen.next('step'),
          actionType: 'save_design',
          description: 'Save the current design.',
          parameters: {
            ...params,
            'designId': context.activeDesignId,
            'hasUnsavedChanges': context.hasUnsavedChanges,
          },
          priority: 8,
        ));
        break;

      case IntentType.exportDesign:
        steps.add(SafeActionStep.create(
          stepId: _IOIdGen.next('step'),
          actionType: 'export_design',
          description: 'Export the current design.',
          parameters: {
            ...params,
            'designId': context.activeDesignId,
          },
          priority: 7,
        ));
        break;

      case IntentType.clearSelection:
        steps.add(SafeActionStep.create(
          stepId: _IOIdGen.next('step'),
          actionType: 'clear_selection',
          description: 'Deselect all selected layers.',
          parameters: params,
          priority: 4,
        ));
        break;

      case IntentType.batchEdit:
        steps.add(SafeActionStep.create(
          stepId: _IOIdGen.next('step'),
          actionType: 'batch_update',
          description: 'Apply a batch operation to selected layers.',
          parameters: {
            ...params,
            'designId': context.activeDesignId,
          },
          priority: 7,
        ));
        break;

      case IntentType.reorderLayers:
        steps.add(SafeActionStep.create(
          stepId: _IOIdGen.next('step'),
          actionType: 'reorder_layers',
          description: 'Reorder layers in the design.',
          parameters: {
            ...params,
            'designId': context.activeDesignId,
          },
          priority: 6,
        ));
        break;

      case IntentType.openSettings:
      case IntentType.openLayerPanel:
        steps.add(SafeActionStep.create(
          stepId: _IOIdGen.next('step'),
          actionType: intent.name,
          description: 'Open the ${intent == IntentType.openSettings ? "settings" : "layer"} panel.',
          parameters: params,
          priority: 3,
        ));
        break;

      case IntentType.unknown:
        break;
    }

    // Suppress unused variable warning.
    pid.length;

    return steps;
  }

  String _buildHumanSummary(
      IntentType intentType,
      Map<String, dynamic> params,
      double confidence) {
    final tier = IntentConfidenceTierRange.from(confidence);
    final conf = tier == IntentConfidenceTier.veryHigh
        ? 'high confidence'
        : tier == IntentConfidenceTier.high
            ? 'reasonable confidence'
            : 'low confidence';

    final target =
        params['targetLayerId'] != null ? ' on layer "${params['targetLayerId']}"' : '';

    return 'Detected intent: ${intentType.name}$target '
        'with $conf (${confidence.toStringAsFixed(1)}%). '
        'Awaiting EditorController approval before execution.';
  }

  // ── Safety helpers ─────────────────────────────────────────────

  Map<String, dynamic> _sanitiseParams(Map<String, dynamic> raw) {
    const forbidden = {
      'layerengine', 'historyengine', 'renderengine',
      'storageengine', 'aiengine', 'templateengine',
      'syncengine', 'exportengine', 'buildcontext',
      'canvas', 'widget',
    };
    final result = <String, dynamic>{};
    for (final entry in raw.entries) {
      if (forbidden.contains(entry.key.toLowerCase())) continue;
      final v = entry.value;
      final safe = v == null ||
          v is num ||
          v is String ||
          v is bool ||
          (v is List &&
              v.every((e) => e is num || e is String || e is bool)) ||
          v is Map<String, dynamic>;
      if (safe) result[entry.key] = v;
    }
    return result;
  }

  void _checkForbiddenParams(
      Map<String, dynamic> params, String stepId,
      List<String> errors) {
    const forbidden = {
      'layerengine', 'historyengine', 'renderengine',
      'storageengine', 'buildcontext', 'canvas', 'widget',
    };
    for (final key in params.keys) {
      if (forbidden.contains(key.toLowerCase())) {
        errors.add(
            'SafeActionStep "$stepId" param "$key" references a '
            'forbidden engine or context object.');
      }
    }
  }

  IntentValidationResult _validateRequest(InteractionRequest request) {
    final errors = <String>[];
    final warnings = <String>[];

    if (request.requestId.trim().isEmpty) {
      errors.add('InteractionRequest.requestId must not be empty.');
    }
    if (request.rawPayload.trim().isEmpty) {
      errors.add('InteractionRequest.rawPayload must not be empty.');
    }

    const forbiddenMetaKeys = {
      'layerengine', 'historyengine', 'renderengine',
      'storageengine', 'canvas', 'widget', 'buildcontext',
    };
    for (final key in request.inputMetadata.keys) {
      if (forbiddenMetaKeys.contains(key.toLowerCase())) {
        errors.add(
            'InteractionRequest.inputMetadata key "$key" references '
            'a forbidden engine or context object.');
      }
    }

    if (errors.isEmpty) {
      return IntentValidationResult.ok(warnings: warnings);
    }
    return IntentValidationResult.fail(errors, warnings: warnings);
  }
}
