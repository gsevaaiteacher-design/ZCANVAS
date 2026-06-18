// ignore_for_file: avoid_catches_without_on_clauses

import 'dart:math';

// ── Input mode ────────────────────────────────────────────────
enum SuggestionInputMode {
  text,
  voice,
  gesture,
  futureRobot,
}

// ── Suggestion type ───────────────────────────────────────────
enum SuggestionType {
  ui,
  layout,
  performance,
  ux,
  prediction,
}

// ── Suggestion confidence tier ────────────────────────────────
enum ConfidenceTier { low, medium, high, veryHigh }

extension ConfidenceTierRange on ConfidenceTier {
  static ConfidenceTier from(double score) {
    if (score >= 85.0) return ConfidenceTier.veryHigh;
    if (score >= 65.0) return ConfidenceTier.high;
    if (score >= 40.0) return ConfidenceTier.medium;
    return ConfidenceTier.low;
  }
}

// ── Design context ─────────────────────────────────────────────
class DesignContext {
  final String? designId;
  final double canvasWidth;
  final double canvasHeight;
  final int layerCount;
  final int visibleLayerCount;
  final int lockedLayerCount;
  final Map<String, int> layerTypeCountMap;
  final Map<String, dynamic> metadata;

  const DesignContext({
    this.designId,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.layerCount,
    required this.visibleLayerCount,
    required this.lockedLayerCount,
    this.layerTypeCountMap = const {},
    this.metadata = const {},
  });

  bool get isEmpty => layerCount == 0;
  double get canvasAspectRatio =>
      canvasHeight > 0 ? canvasWidth / canvasHeight : 1.0;
}

// ── User action context ───────────────────────────────────────
class UserActionContext {
  final String? lastActionType;
  final int recentActionCount;
  final double sessionDurationMs;
  final List<String> recentActionTypes;
  final bool hasUnsavedChanges;
  final int undoStackDepth;

  const UserActionContext({
    this.lastActionType,
    required this.recentActionCount,
    required this.sessionDurationMs,
    this.recentActionTypes = const [],
    required this.hasUnsavedChanges,
    required this.undoStackDepth,
  });

  bool get isHighActivity => recentActionCount > 20;
  bool get isStagnant => recentActionCount == 0 && sessionDurationMs > 30000;
}

// ── Selected layer context ─────────────────────────────────────
class SelectedLayerContext {
  final String? layerId;
  final String? layerType;
  final double? x;
  final double? y;
  final double? width;
  final double? height;
  final double? rotation;
  final double? opacity;
  final bool? isVisible;
  final bool? isLocked;
  final int? zIndex;
  final int totalLayers;

  const SelectedLayerContext({
    this.layerId,
    this.layerType,
    this.x,
    this.y,
    this.width,
    this.height,
    this.rotation,
    this.opacity,
    this.isVisible,
    this.isLocked,
    this.zIndex,
    required this.totalLayers,
  });

  bool get hasSelection => layerId != null;

  bool get isNearEdge {
    if (x == null || y == null) return false;
    return x! < 5.0 || y! < 5.0;
  }

  bool get hasNonStandardRotation =>
      rotation != null && rotation! % 90.0 != 0.0;

  bool get isFullyTransparent => opacity != null && opacity! <= 0.0;
}

// ── SuggestionRequest — input contract ────────────────────────
class SuggestionRequest {
  final String requestId;
  final DesignContext designContext;
  final UserActionContext userActionContext;
  final SelectedLayerContext selectedLayerContext;
  final SuggestionInputMode inputMode;
  final int maxSuggestions;

  const SuggestionRequest({
    required this.requestId,
    required this.designContext,
    required this.userActionContext,
    required this.selectedLayerContext,
    required this.inputMode,
    this.maxSuggestions = 10,
  });
}

// ── Suggestion — atomic output unit ───────────────────────────
class Suggestion {
  final String suggestionId;
  final SuggestionType type;
  final String message;
  final double confidenceScore;
  final String uiPreviewHint;
  final String voiceFriendlyText;

  // CONTRACT HARD RULE: this field is ALWAYS false.
  // No suggestion may ever be auto-executed without EditorController approval.
  final bool isAutoExecutable;

  final ConfidenceTier confidenceTier;
  final List<String> tags;
  final DateTime generatedAt;

  const Suggestion._({
    required this.suggestionId,
    required this.type,
    required this.message,
    required this.confidenceScore,
    required this.uiPreviewHint,
    required this.voiceFriendlyText,
    required this.confidenceTier,
    required this.tags,
    required this.generatedAt,
  })  : isAutoExecutable = false;

  factory Suggestion.create({
    required String suggestionId,
    required SuggestionType type,
    required String message,
    required double confidenceScore,
    required String uiPreviewHint,
    required String voiceFriendlyText,
    List<String> tags = const [],
  }) {
    final clampedScore = confidenceScore.clamp(0.0, 100.0);
    return Suggestion._(
      suggestionId: suggestionId,
      type: type,
      message: message,
      confidenceScore: double.parse(clampedScore.toStringAsFixed(2)),
      uiPreviewHint: uiPreviewHint,
      voiceFriendlyText: voiceFriendlyText,
      confidenceTier: ConfidenceTierRange.from(clampedScore),
      tags: List.unmodifiable(tags),
      generatedAt: DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toMap() => {
        'suggestionId': suggestionId,
        'type': type.name,
        'message': message,
        'confidenceScore': confidenceScore,
        'confidenceTier': confidenceTier.name,
        'uiPreviewHint': uiPreviewHint,
        'voiceFriendlyText': voiceFriendlyText,
        'isAutoExecutable': isAutoExecutable,
        'tags': tags,
        'generatedAt': generatedAt.toIso8601String(),
      };
}

// ── SuggestionResponse — output contract ──────────────────────
class SuggestionResponse {
  final String requestId;
  final List<Suggestion> suggestions;
  final int totalGenerated;
  final int totalFiltered;
  final List<String> warnings;
  final DateTime respondedAt;

  // CONTRACT INVARIANT: isExecutable is ALWAYS false on the response.
  final bool isExecutable;

  const SuggestionResponse._({
    required this.requestId,
    required this.suggestions,
    required this.totalGenerated,
    required this.totalFiltered,
    required this.warnings,
    required this.respondedAt,
  }) : isExecutable = false;

  factory SuggestionResponse.build({
    required String requestId,
    required List<Suggestion> suggestions,
    required int totalGenerated,
    required int totalFiltered,
    List<String> warnings = const [],
  }) =>
      SuggestionResponse._(
        requestId: requestId,
        suggestions: List.unmodifiable(suggestions),
        totalGenerated: totalGenerated,
        totalFiltered: totalFiltered,
        warnings: warnings,
        respondedAt: DateTime.now().toUtc(),
      );

  factory SuggestionResponse.empty(String requestId,
          {List<String> warnings = const []}) =>
      SuggestionResponse._(
        requestId: requestId,
        suggestions: const [],
        totalGenerated: 0,
        totalFiltered: 0,
        warnings: warnings,
        respondedAt: DateTime.now().toUtc(),
      );
}

// ── Validation result ──────────────────────────────────────────
class SuggestionValidationResult {
  final bool valid;
  final List<String> errors;
  final List<String> warnings;

  const SuggestionValidationResult.ok({this.warnings = const []})
      : valid = true,
        errors = const [];

  const SuggestionValidationResult.fail(this.errors,
      {this.warnings = const []})
      : valid = false;
}

// ── ID generator ──────────────────────────────────────────────
class _SGIdGen {
  static final Random _rng = Random.secure();

  static String next(String prefix) {
    final bytes = List<int>.generate(6, (_) => _rng.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '$prefix-$hex-${DateTime.now().microsecondsSinceEpoch}';
  }
}

// ── SuggestionEngine ───────────────────────────────────────────
class SuggestionEngine {
  static const double _minConfidenceThreshold = 30.0;

  // ── generateSuggestions ────────────────────────────────────────

  SuggestionResponse generateSuggestions(SuggestionRequest request) {
    try {
      final validation = _validateRequest(request);
      if (!validation.valid) {
        return SuggestionResponse.empty(request.requestId,
            warnings: validation.errors);
      }

      final raw = <Suggestion>[
        ..._analyseDesignContext(request.designContext),
        ..._analyseLayoutContext(
            request.designContext, request.selectedLayerContext),
        ..._analyseSelectedLayer(request.selectedLayerContext,
            request.designContext),
        ..._analyseUserBehaviour(request.userActionContext,
            request.designContext),
        ..._analysePredictions(request.designContext,
            request.userActionContext, request.selectedLayerContext),
        ..._analysePerformance(request.designContext),
      ];

      final totalGenerated = raw.length;
      final safe = filterUnsafeSuggestions(raw);
      final ranked = rankSuggestions(safe);

      final capped = ranked.length > request.maxSuggestions
          ? ranked.sublist(0, request.maxSuggestions)
          : ranked;

      final voiced = capped
          .map((s) => createVoiceFriendlyVersion(s, request.inputMode))
          .toList();

      final totalFiltered = totalGenerated - safe.length;
      final warnings = validation.warnings.toList();
      if (totalFiltered > 0) {
        warnings.add('$totalFiltered suggestion(s) removed by safety filter.');
      }

      return SuggestionResponse.build(
        requestId: request.requestId,
        suggestions: voiced,
        totalGenerated: totalGenerated,
        totalFiltered: totalFiltered,
        warnings: warnings,
      );
    } catch (e) {
      return SuggestionResponse.empty(request.requestId,
          warnings: ['generateSuggestions threw: $e']);
    }
  }

  // ── rankSuggestions ────────────────────────────────────────────

  List<Suggestion> rankSuggestions(List<Suggestion> suggestions) {
    if (suggestions.isEmpty) return const [];

    final ranked = List<Suggestion>.from(suggestions);

    // Primary: confidenceScore descending.
    // Secondary: type priority (ux > ui > layout > performance > prediction).
    const typePriority = {
      SuggestionType.ux: 5,
      SuggestionType.ui: 4,
      SuggestionType.layout: 3,
      SuggestionType.performance: 2,
      SuggestionType.prediction: 1,
    };

    ranked.sort((a, b) {
      final scoreCmp = b.confidenceScore.compareTo(a.confidenceScore);
      if (scoreCmp != 0) return scoreCmp;
      final aPriority = typePriority[a.type] ?? 0;
      final bPriority = typePriority[b.type] ?? 0;
      return bPriority.compareTo(aPriority);
    });

    return ranked;
  }

  // ── filterUnsafeSuggestions ────────────────────────────────────

  List<Suggestion> filterUnsafeSuggestions(List<Suggestion> suggestions) {
    return suggestions.where((s) {
      // Hard rule: isAutoExecutable must always be false.
      if (s.isAutoExecutable) return false;

      // Remove below confidence floor.
      if (s.confidenceScore < _minConfidenceThreshold) return false;

      // Remove empty messages.
      if (s.message.trim().isEmpty) return false;

      // Remove suggestions that contain forbidden instruction patterns.
      final forbidden = _containsForbiddenPattern(s.message);
      if (forbidden) return false;

      return true;
    }).toList();
  }

  // ── createVoiceFriendlyVersion ─────────────────────────────────

  Suggestion createVoiceFriendlyVersion(
      Suggestion suggestion, SuggestionInputMode mode) {
    if (mode == SuggestionInputMode.text) return suggestion;

    final voiced = _buildVoiceText(suggestion, mode);

    return Suggestion.create(
      suggestionId: suggestion.suggestionId,
      type: suggestion.type,
      message: suggestion.message,
      confidenceScore: suggestion.confidenceScore,
      uiPreviewHint: suggestion.uiPreviewHint,
      voiceFriendlyText: voiced,
      tags: suggestion.tags,
    );
  }

  // ── validateSuggestion ─────────────────────────────────────────

  SuggestionValidationResult validateSuggestion(Suggestion suggestion) {
    final errors = <String>[];
    final warnings = <String>[];

    if (suggestion.suggestionId.trim().isEmpty) {
      errors.add('Suggestion.suggestionId must not be empty.');
    }
    if (suggestion.message.trim().isEmpty) {
      errors.add('Suggestion.message must not be empty.');
    }
    if (suggestion.voiceFriendlyText.trim().isEmpty) {
      warnings.add('Suggestion.voiceFriendlyText is empty.');
    }
    if (suggestion.uiPreviewHint.trim().isEmpty) {
      warnings.add('Suggestion.uiPreviewHint is empty.');
    }
    if (suggestion.confidenceScore < 0.0 || suggestion.confidenceScore > 100.0) {
      errors.add(
          'Suggestion.confidenceScore ${suggestion.confidenceScore} is '
          'outside [0, 100].');
    }
    if (suggestion.isAutoExecutable) {
      errors.add(
          'Suggestion.isAutoExecutable is true — this violates the '
          'Phase-7 contract. All suggestions must have '
          'isAutoExecutable = false.');
    }
    if (_containsForbiddenPattern(suggestion.message)) {
      errors.add(
          'Suggestion.message contains a forbidden imperative execution '
          'pattern. Suggestions must be advisory only.');
    }

    if (errors.isEmpty) {
      return SuggestionValidationResult.ok(warnings: warnings);
    }
    return SuggestionValidationResult.fail(errors, warnings: warnings);
  }

  // ── Private analysis methods ───────────────────────────────────

  List<Suggestion> _analyseDesignContext(DesignContext ctx) {
    final suggestions = <Suggestion>[];

    if (ctx.isEmpty) {
      suggestions.add(Suggestion.create(
        suggestionId: _SGIdGen.next('sg'),
        type: SuggestionType.ux,
        message:
            'Your canvas is empty. Consider adding a background or template '
            'to start building your design.',
        confidenceScore: 92.0,
        uiPreviewHint: 'show_template_picker',
        voiceFriendlyText:
            'Your canvas is empty. Would you like to start with a template?',
        tags: ['empty_canvas', 'onboarding'],
      ));
    }

    if (ctx.layerCount > 30) {
      suggestions.add(Suggestion.create(
        suggestionId: _SGIdGen.next('sg'),
        type: SuggestionType.performance,
        message:
            'Your design has ${ctx.layerCount} layers. Grouping related '
            'elements may improve performance and organisation.',
        confidenceScore: 74.0,
        uiPreviewHint: 'highlight_ungrouped_layers',
        voiceFriendlyText:
            'You have ${ctx.layerCount} layers. Grouping similar elements '
            'can keep your design easier to manage.',
        tags: ['layer_count', 'performance'],
      ));
    }

    if (ctx.lockedLayerCount > 0 &&
        ctx.lockedLayerCount == ctx.layerCount) {
      suggestions.add(Suggestion.create(
        suggestionId: _SGIdGen.next('sg'),
        type: SuggestionType.ux,
        message: 'All layers are locked. Unlock a layer to start editing.',
        confidenceScore: 88.0,
        uiPreviewHint: 'highlight_locked_layers',
        voiceFriendlyText:
            'All your layers are currently locked. Unlock one to make changes.',
        tags: ['locked', 'ux'],
      ));
    }

    if (ctx.visibleLayerCount == 0 && ctx.layerCount > 0) {
      suggestions.add(Suggestion.create(
        suggestionId: _SGIdGen.next('sg'),
        type: SuggestionType.ux,
        message:
            'No layers are visible. Toggling layer visibility will reveal '
            'your design content.',
        confidenceScore: 90.0,
        uiPreviewHint: 'show_layer_panel',
        voiceFriendlyText:
            'None of your layers are visible right now. '
            'Would you like to show them?',
        tags: ['visibility', 'ux'],
      ));
    }

    return suggestions;
  }

  List<Suggestion> _analyseLayoutContext(
      DesignContext design, SelectedLayerContext layer) {
    final suggestions = <Suggestion>[];

    final aspectRatio = design.canvasAspectRatio;

    if (aspectRatio < 0.5) {
      suggestions.add(Suggestion.create(
        suggestionId: _SGIdGen.next('sg'),
        type: SuggestionType.layout,
        message:
            'Your canvas is very tall and narrow '
            '(${design.canvasWidth.toStringAsFixed(0)} × '
            '${design.canvasHeight.toStringAsFixed(0)}). '
            'This ratio works well for stories and reels.',
        confidenceScore: 65.0,
        uiPreviewHint: 'canvas_ratio_info',
        voiceFriendlyText:
            'Your canvas is tall format — great for social stories.',
        tags: ['aspect_ratio', 'layout'],
      ));
    } else if (aspectRatio > 2.5) {
      suggestions.add(Suggestion.create(
        suggestionId: _SGIdGen.next('sg'),
        type: SuggestionType.layout,
        message:
            'Your canvas is very wide '
            '(${design.canvasWidth.toStringAsFixed(0)} × '
            '${design.canvasHeight.toStringAsFixed(0)}). '
            'Consider whether all content is visible on standard screens.',
        confidenceScore: 62.0,
        uiPreviewHint: 'canvas_ratio_info',
        voiceFriendlyText:
            'Your canvas is very wide. Check that all content fits '
            'on most screens.',
        tags: ['aspect_ratio', 'layout'],
      ));
    }

    if (layer.hasSelection && layer.isNearEdge) {
      suggestions.add(Suggestion.create(
        suggestionId: _SGIdGen.next('sg'),
        type: SuggestionType.layout,
        message:
            'The selected layer is very close to the canvas edge. '
            'Adding a small margin may improve visual balance.',
        confidenceScore: 71.0,
        uiPreviewHint: 'highlight_safe_zone',
        voiceFriendlyText:
            'The selected layer is near the edge. '
            'A small margin could improve the look.',
        tags: ['margin', 'layout', 'edge'],
      ));
    }

    return suggestions;
  }

  List<Suggestion> _analyseSelectedLayer(
      SelectedLayerContext layer, DesignContext design) {
    final suggestions = <Suggestion>[];
    if (!layer.hasSelection) return suggestions;

    if (layer.isFullyTransparent) {
      suggestions.add(Suggestion.create(
        suggestionId: _SGIdGen.next('sg'),
        type: SuggestionType.ux,
        message:
            'The selected layer has zero opacity and is invisible. '
            'Increasing its opacity will make it visible on the canvas.',
        confidenceScore: 87.0,
        uiPreviewHint: 'highlight_opacity_slider',
        voiceFriendlyText:
            'The selected layer is invisible because its opacity is zero. '
            'Try increasing it to see the layer.',
        tags: ['opacity', 'visibility', 'ux'],
      ));
    }

    if (layer.isLocked == true) {
      suggestions.add(Suggestion.create(
        suggestionId: _SGIdGen.next('sg'),
        type: SuggestionType.ux,
        message: 'The selected layer is locked. Unlock it to make edits.',
        confidenceScore: 85.0,
        uiPreviewHint: 'highlight_lock_toggle',
        voiceFriendlyText:
            'The layer you selected is locked. Unlock it first to edit.',
        tags: ['locked', 'ux'],
      ));
    }

    if (layer.hasNonStandardRotation) {
      suggestions.add(Suggestion.create(
        suggestionId: _SGIdGen.next('sg'),
        type: SuggestionType.ui,
        message:
            'The selected layer is rotated ${(layer.rotation ?? 0).toStringAsFixed(1)}°. '
            'Aligning it to 0°, 90°, or 180° creates a cleaner layout.',
        confidenceScore: 58.0,
        uiPreviewHint: 'show_rotation_snap_hint',
        voiceFriendlyText:
            'Your layer is rotated at an unusual angle. '
            'Snapping to 90 degrees might look cleaner.',
        tags: ['rotation', 'alignment', 'ui'],
      ));
    }

    if (layer.zIndex != null && design.layerCount > 1) {
      final isOnTop = layer.zIndex! == design.layerCount - 1;
      final isAtBottom = layer.zIndex! == 0;
      if (isAtBottom && design.layerCount > 3) {
        suggestions.add(Suggestion.create(
          suggestionId: _SGIdGen.next('sg'),
          type: SuggestionType.layout,
          message:
              'The selected layer is at the bottom of the stack. '
              'If it contains text or key content, consider moving it higher.',
          confidenceScore: 52.0,
          uiPreviewHint: 'show_layer_order_hint',
          voiceFriendlyText:
              'The selected layer is at the very bottom. '
              'You might want to move it up so it is visible.',
          tags: ['z_index', 'layout'],
        ));
      }
      if (isOnTop) {
        suggestions.add(Suggestion.create(
          suggestionId: _SGIdGen.next('sg'),
          type: SuggestionType.layout,
          message:
              'The selected layer is on top of all others. '
              'Ensure it is the element that should be in front.',
          confidenceScore: 48.0,
          uiPreviewHint: 'show_layer_order_hint',
          voiceFriendlyText:
              'This layer is at the very top of the stack.',
          tags: ['z_index', 'layout'],
        ));
      }
    }

    return suggestions;
  }

  List<Suggestion> _analyseUserBehaviour(
      UserActionContext action, DesignContext design) {
    final suggestions = <Suggestion>[];

    if (action.isStagnant) {
      suggestions.add(Suggestion.create(
        suggestionId: _SGIdGen.next('sg'),
        type: SuggestionType.ux,
        message:
            'No edits detected recently. If you are unsure what to do next, '
            'try selecting a layer to see edit options.',
        confidenceScore: 60.0,
        uiPreviewHint: 'show_contextual_help',
        voiceFriendlyText:
            'You have been idle for a while. Select any layer to see '
            'what you can change.',
        tags: ['idle', 'onboarding', 'ux'],
      ));
    }

    if (action.undoStackDepth > 15) {
      suggestions.add(Suggestion.create(
        suggestionId: _SGIdGen.next('sg'),
        type: SuggestionType.ux,
        message:
            'You have ${action.undoStackDepth} undoable actions. '
            'Saving a checkpoint now will protect your progress.',
        confidenceScore: 73.0,
        uiPreviewHint: 'highlight_save_button',
        voiceFriendlyText:
            'You have made many changes. '
            'Saving now would be a good idea.',
        tags: ['undo', 'save', 'ux'],
      ));
    }

    if (action.hasUnsavedChanges && action.sessionDurationMs > 120000) {
      suggestions.add(Suggestion.create(
        suggestionId: _SGIdGen.next('sg'),
        type: SuggestionType.ux,
        message:
            'You have unsaved changes and have been editing for over 2 minutes. '
            'Saving your work will prevent data loss.',
        confidenceScore: 82.0,
        uiPreviewHint: 'highlight_save_button',
        voiceFriendlyText:
            'You have unsaved changes. Save your design to avoid losing work.',
        tags: ['unsaved', 'save', 'ux'],
      ));
    }

    if (action.isHighActivity && design.layerCount > 10) {
      suggestions.add(Suggestion.create(
        suggestionId: _SGIdGen.next('sg'),
        type: SuggestionType.performance,
        message:
            'High editing activity with ${design.layerCount} layers detected. '
            'Hiding layers you are not currently editing can improve responsiveness.',
        confidenceScore: 66.0,
        uiPreviewHint: 'show_layer_visibility_controls',
        voiceFriendlyText:
            'You are editing quickly with many layers. '
            'Hiding unused layers can help keep things fast.',
        tags: ['activity', 'performance'],
      ));
    }

    return suggestions;
  }

  List<Suggestion> _analysePredictions(
      DesignContext design,
      UserActionContext action,
      SelectedLayerContext layer) {
    final suggestions = <Suggestion>[];

    if (layer.hasSelection &&
        action.recentActionTypes.contains('move_layer')) {
      suggestions.add(Suggestion.create(
        suggestionId: _SGIdGen.next('sg'),
        type: SuggestionType.prediction,
        message:
            'You have been moving layers. Would you like to align the '
            'selected layer to the canvas centre?',
        confidenceScore: 55.0,
        uiPreviewHint: 'show_alignment_tools',
        voiceFriendlyText:
            'It looks like you are positioning layers. '
            'Alignment tools might help.',
        tags: ['move', 'align', 'prediction'],
      ));
    }

    if (action.recentActionTypes.contains('add_layer') &&
        design.layerCount > 5) {
      suggestions.add(Suggestion.create(
        suggestionId: _SGIdGen.next('sg'),
        type: SuggestionType.prediction,
        message:
            'You have been adding layers. Naming your layers will help '
            'keep the layer panel organised as the design grows.',
        confidenceScore: 50.0,
        uiPreviewHint: 'prompt_layer_naming',
        voiceFriendlyText:
            'You are adding a lot of layers. '
            'Naming them now will save time later.',
        tags: ['add_layer', 'naming', 'prediction'],
      ));
    }

    if (action.recentActionTypes.contains('change_color') &&
        action.recentActionTypes.contains('change_font')) {
      suggestions.add(Suggestion.create(
        suggestionId: _SGIdGen.next('sg'),
        type: SuggestionType.prediction,
        message:
            'You have been adjusting colours and fonts. '
            'Applying a brand style guide can keep changes consistent '
            'across all layers.',
        confidenceScore: 63.0,
        uiPreviewHint: 'show_brand_kit_panel',
        voiceFriendlyText:
            'You are customising colours and fonts. '
            'A brand kit can help keep things consistent.',
        tags: ['branding', 'style', 'prediction'],
      ));
    }

    return suggestions;
  }

  List<Suggestion> _analysePerformance(DesignContext design) {
    final suggestions = <Suggestion>[];

    final hiddenCount = design.layerCount - design.visibleLayerCount;
    if (hiddenCount > 10) {
      suggestions.add(Suggestion.create(
        suggestionId: _SGIdGen.next('sg'),
        type: SuggestionType.performance,
        message:
            '$hiddenCount layers are hidden. Removing unused hidden layers '
            'can reduce design file size.',
        confidenceScore: 57.0,
        uiPreviewHint: 'show_hidden_layer_list',
        voiceFriendlyText:
            'You have $hiddenCount hidden layers. Removing unused ones '
            'can keep your file lean.',
        tags: ['hidden', 'cleanup', 'performance'],
      ));
    }

    if (design.layerTypeCountMap.containsKey('image') &&
        (design.layerTypeCountMap['image'] ?? 0) > 10) {
      suggestions.add(Suggestion.create(
        suggestionId: _SGIdGen.next('sg'),
        type: SuggestionType.performance,
        message:
            'Your design contains more than 10 image layers. '
            'Large or uncompressed images can slow down render performance.',
        confidenceScore: 69.0,
        uiPreviewHint: 'show_image_optimisation_hint',
        voiceFriendlyText:
            'You have many image layers. '
            'Compressing large images can improve speed.',
        tags: ['images', 'performance'],
      ));
    }

    return suggestions;
  }

  // ── Voice text builder ────────────────────────────────────────

  String _buildVoiceText(Suggestion suggestion, SuggestionInputMode mode) {
    if (suggestion.voiceFriendlyText.isNotEmpty) {
      return suggestion.voiceFriendlyText;
    }

    switch (mode) {
      case SuggestionInputMode.voice:
        return _trimToVoiceLength(suggestion.message);
      case SuggestionInputMode.gesture:
        return 'Tip: ${_trimToVoiceLength(suggestion.message)}';
      case SuggestionInputMode.futureRobot:
        return '[ROBOT-SAFE] ${_trimToVoiceLength(suggestion.message)}';
      case SuggestionInputMode.text:
        return suggestion.message;
    }
  }

  String _trimToVoiceLength(String text, {int maxChars = 120}) {
    if (text.length <= maxChars) return text;
    final trimmed = text.substring(0, maxChars).trimRight();
    final lastSpace = trimmed.lastIndexOf(' ');
    return lastSpace > 0
        ? '${trimmed.substring(0, lastSpace)}…'
        : '$trimmed…';
  }

  // ── Forbidden pattern scanner ─────────────────────────────────

  bool _containsForbiddenPattern(String message) {
    final lower = message.toLowerCase();
    const forbidden = [
      'call layerengine',
      'call historyengine',
      'call renderengine',
      'call storageengine',
      'call exportengine',
      'call syncengine',
      'execute ',
      'layerengine.',
      'historyengine.',
      'renderengine.',
      'storageengine.',
    ];
    for (final pattern in forbidden) {
      if (lower.contains(pattern)) return true;
    }
    return false;
  }

  // ── Request validation ────────────────────────────────────────

  SuggestionValidationResult _validateRequest(SuggestionRequest request) {
    final errors = <String>[];
    final warnings = <String>[];

    if (request.requestId.trim().isEmpty) {
      errors.add('SuggestionRequest.requestId must not be empty.');
    }
    if (request.maxSuggestions < 1) {
      errors.add('SuggestionRequest.maxSuggestions must be >= 1.');
    }
    if (request.designContext.canvasWidth <= 0 ||
        request.designContext.canvasHeight <= 0) {
      warnings.add(
          'DesignContext has zero or negative canvas dimensions; '
          'layout suggestions may be inaccurate.');
    }

    if (errors.isEmpty) {
      return SuggestionValidationResult.ok(warnings: warnings);
    }
    return SuggestionValidationResult.fail(errors, warnings: warnings);
  }
}
