// ignore_for_file: avoid_catches_without_on_clauses

import 'dart:math';

// ── Severity level ────────────────────────────────────────────
enum InsightSeverity { low, medium, high }

// ── Issue category ─────────────────────────────────────────────
enum IssueCategory {
  complexity,
  ux,
  accessibility,
  performance,
  structure,
  consistency,
  interaction,
}

// ── Risk area ──────────────────────────────────────────────────
enum RiskArea {
  layerOverload,
  hiddenContent,
  lockedContent,
  accessibilityGap,
  contrastIssue,
  deepNesting,
  poorAlignment,
  inconsistentSpacing,
  missingContent,
  interactionAnomaly,
  performanceDegradation,
}

// ── Layer descriptor — read-only snapshot ─────────────────────
// Callers supply these; InsightEngine never reads from LayerEngine.
class LayerDescriptor {
  final String layerId;
  final String layerType;
  final int zIndex;
  final bool visible;
  final bool locked;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;
  final double opacity;
  final double scaleX;
  final double scaleY;
  final Map<String, dynamic> properties;

  const LayerDescriptor({
    required this.layerId,
    required this.layerType,
    required this.zIndex,
    required this.visible,
    required this.locked,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.rotation,
    required this.opacity,
    this.scaleX = 1.0,
    this.scaleY = 1.0,
    this.properties = const {},
  });

  bool get isFullyTransparent => opacity <= 0.0;
  bool get isZeroSize => width <= 0.0 || height <= 0.0;
  bool get hasNonStandardRotation => rotation % 90.0 != 0.0;
}

// ── Design model snapshot ──────────────────────────────────────
class DesignSnapshot {
  final String? designId;
  final String? title;
  final double canvasWidth;
  final double canvasHeight;
  final String? version;
  final Map<String, dynamic> metadata;

  const DesignSnapshot({
    this.designId,
    this.title,
    required this.canvasWidth,
    required this.canvasHeight,
    this.version,
    this.metadata = const {},
  });

  bool get hasTitle => title != null && title!.trim().isNotEmpty;
  double get aspectRatio =>
      canvasHeight > 0 ? canvasWidth / canvasHeight : 1.0;
}

// ── Interaction event ─────────────────────────────────────────
class InteractionEvent {
  final String eventId;
  final String actionType;
  final DateTime occurredAt;
  final bool wasSuccessful;
  final String? targetLayerId;
  final Map<String, dynamic> context;

  const InteractionEvent({
    required this.eventId,
    required this.actionType,
    required this.occurredAt,
    required this.wasSuccessful,
    this.targetLayerId,
    this.context = const {},
  });
}

// ── System context snapshot ────────────────────────────────────
class SystemContext {
  final double sessionDurationMs;
  final int undoStackDepth;
  final bool hasUnsavedChanges;
  final double estimatedMemoryMb;
  final double renderLatencyMs;
  final bool isOnline;

  const SystemContext({
    required this.sessionDurationMs,
    required this.undoStackDepth,
    required this.hasUnsavedChanges,
    required this.estimatedMemoryMb,
    required this.renderLatencyMs,
    required this.isOnline,
  });
}

// ── InsightRequest — input contract ───────────────────────────
class InsightRequest {
  final String requestId;
  final DesignSnapshot designModel;
  final List<LayerDescriptor> layerList;
  final List<InteractionEvent> interactionHistory;
  final SystemContext systemContext;

  const InsightRequest({
    required this.requestId,
    required this.designModel,
    required this.layerList,
    required this.interactionHistory,
    required this.systemContext,
  });
}

// ── Issue — informational only ─────────────────────────────────
class InsightIssue {
  final String issueId;
  final IssueCategory category;
  final InsightSeverity severity;
  final String title;
  final String detail;
  final List<String> affectedLayerIds;

  const InsightIssue({
    required this.issueId,
    required this.category,
    required this.severity,
    required this.title,
    required this.detail,
    this.affectedLayerIds = const [],
  });

  Map<String, dynamic> toMap() => {
        'issueId': issueId,
        'category': category.name,
        'severity': severity.name,
        'title': title,
        'detail': detail,
        'affectedLayerIds': affectedLayerIds,
      };
}

// ── Risk area entry ────────────────────────────────────────────
class RiskEntry {
  final RiskArea area;
  final InsightSeverity severity;
  final String description;
  final double riskContribution;

  const RiskEntry({
    required this.area,
    required this.severity,
    required this.description,
    required this.riskContribution,
  });

  Map<String, dynamic> toMap() => {
        'area': area.name,
        'severity': severity.name,
        'description': description,
        'riskContribution': riskContribution,
      };
}

// ── Complexity result ──────────────────────────────────────────
class ComplexityResult {
  final double score;
  final int totalLayers;
  final int visibleLayers;
  final int lockedLayers;
  final int zeroSizeLayers;
  final int rotatedLayers;
  final int transparentLayers;
  final Map<String, int> typeDistribution;
  final InsightSeverity level;
  final List<String> observations;

  const ComplexityResult({
    required this.score,
    required this.totalLayers,
    required this.visibleLayers,
    required this.lockedLayers,
    required this.zeroSizeLayers,
    required this.rotatedLayers,
    required this.transparentLayers,
    required this.typeDistribution,
    required this.level,
    required this.observations,
  });

  Map<String, dynamic> toMap() => {
        'score': score,
        'totalLayers': totalLayers,
        'visibleLayers': visibleLayers,
        'lockedLayers': lockedLayers,
        'zeroSizeLayers': zeroSizeLayers,
        'rotatedLayers': rotatedLayers,
        'transparentLayers': transparentLayers,
        'typeDistribution': typeDistribution,
        'level': level.name,
        'observations': observations,
      };
}

// ── UX score result ────────────────────────────────────────────
class UXScoreResult {
  final double score;
  final double contentVisibilityRatio;
  final double lockRatio;
  final double alignmentScore;
  final double accessibilityScore;
  final InsightSeverity clarity;
  final List<String> observations;

  const UXScoreResult({
    required this.score,
    required this.contentVisibilityRatio,
    required this.lockRatio,
    required this.alignmentScore,
    required this.accessibilityScore,
    required this.clarity,
    required this.observations,
  });

  Map<String, dynamic> toMap() => {
        'score': score,
        'contentVisibilityRatio': contentVisibilityRatio,
        'lockRatio': lockRatio,
        'alignmentScore': alignmentScore,
        'accessibilityScore': accessibilityScore,
        'clarity': clarity.name,
        'observations': observations,
      };
}

// ── InsightReport — output contract ───────────────────────────
class InsightReport {
  final String reportId;
  final String requestId;
  final DateTime generatedAt;
  final double overallScore;
  final ComplexityResult complexityResult;
  final UXScoreResult uxScoreResult;
  final List<InsightIssue> issues;
  final List<String> warnings;
  final List<String> recommendations;
  final List<RiskEntry> riskAreas;
  final String voiceSummary;
  final InsightSeverity severityLevel;

  // CONTRACT INVARIANT: InsightReport is NEVER actionable — it is
  // purely informational and contains no executable commands.
  final bool isActionable;

  const InsightReport._({
    required this.reportId,
    required this.requestId,
    required this.generatedAt,
    required this.overallScore,
    required this.complexityResult,
    required this.uxScoreResult,
    required this.issues,
    required this.warnings,
    required this.recommendations,
    required this.riskAreas,
    required this.voiceSummary,
    required this.severityLevel,
  }) : isActionable = false;

  Map<String, dynamic> toMap() => {
        'reportId': reportId,
        'requestId': requestId,
        'generatedAt': generatedAt.toIso8601String(),
        'overallScore': overallScore,
        'complexity': complexityResult.toMap(),
        'uxScore': uxScoreResult.toMap(),
        'issues': issues.map((i) => i.toMap()).toList(),
        'warnings': warnings,
        'recommendations': recommendations,
        'riskAreas': riskAreas.map((r) => r.toMap()).toList(),
        'voiceSummary': voiceSummary,
        'severityLevel': severityLevel.name,
        'isActionable': isActionable,
      };
}

// ── Analysis validation result ────────────────────────────────
class InsightValidationResult {
  final bool valid;
  final List<String> errors;
  final List<String> warnings;

  const InsightValidationResult.ok({this.warnings = const []})
      : valid = true,
        errors = const [];

  const InsightValidationResult.fail(this.errors,
      {this.warnings = const []})
      : valid = false;
}

// ── ID generator ──────────────────────────────────────────────
class _IEIdGen {
  static final Random _rng = Random.secure();

  static String next(String prefix) {
    final bytes = List<int>.generate(6, (_) => _rng.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '$prefix-$hex-${DateTime.now().microsecondsSinceEpoch}';
  }
}

// ── InsightEngine ──────────────────────────────────────────────
class InsightEngine {
  // ── analyzeDesign ──────────────────────────────────────────────

  InsightReport analyzeDesign(InsightRequest request) {
    try {
      final validation = _validateRequest(request);

      final complexity = calculateComplexity(request.layerList);
      final uxScore = calculateUXScore(
          request.layerList, request.designModel);
      final risks = detectRisks(
          request.layerList, request.designModel,
          request.systemContext, request.interactionHistory);
      final issues = _buildIssues(
          complexity, uxScore, risks,
          request.layerList, request.designModel);
      final warnings = [
        ...validation.warnings,
        ..._buildWarnings(request.systemContext, request.designModel),
      ];
      final recommendations = _buildRecommendations(
          complexity, uxScore, risks, request.designModel);
      final overallScore = _computeOverallScore(complexity, uxScore, risks);
      final severityLevel = _deriveSeverity(overallScore, issues);
      final voiceSummary = generateVoiceSummary(
          overallScore, severityLevel, complexity, uxScore, issues);

      return generateReport(
        requestId: request.requestId,
        overallScore: overallScore,
        complexityResult: complexity,
        uxScoreResult: uxScore,
        issues: issues,
        warnings: warnings,
        recommendations: recommendations,
        riskAreas: risks,
        voiceSummary: voiceSummary,
        severityLevel: severityLevel,
      );
    } catch (e) {
      return generateReport(
        requestId: request.requestId,
        overallScore: 0.0,
        complexityResult: _emptyComplexity(),
        uxScoreResult: _emptyUX(),
        issues: const [],
        warnings: ['analyzeDesign threw: $e'],
        recommendations: const [],
        riskAreas: const [],
        voiceSummary: 'Analysis could not be completed due to an error.',
        severityLevel: InsightSeverity.high,
      );
    }
  }

  // ── calculateComplexity ────────────────────────────────────────

  ComplexityResult calculateComplexity(List<LayerDescriptor> layers) {
    final observations = <String>[];
    final total = layers.length;

    if (total == 0) {
      return ComplexityResult(
        score: 100.0,
        totalLayers: 0,
        visibleLayers: 0,
        lockedLayers: 0,
        zeroSizeLayers: 0,
        rotatedLayers: 0,
        transparentLayers: 0,
        typeDistribution: const {},
        level: InsightSeverity.low,
        observations: ['No layers present — canvas is empty.'],
      );
    }

    final visible = layers.where((l) => l.visible).length;
    final locked = layers.where((l) => l.locked).length;
    final zeroSize = layers.where((l) => l.isZeroSize).length;
    final rotated = layers.where((l) => l.hasNonStandardRotation).length;
    final transparent =
        layers.where((l) => l.isFullyTransparent).length;

    final typeMap = <String, int>{};
    for (final l in layers) {
      typeMap[l.layerType] = (typeMap[l.layerType] ?? 0) + 1;
    }

    // Complexity score: starts at 100 and is penalised.
    double score = 100.0;

    if (total > 50) {
      score -= 30.0;
      observations.add('Very high layer count ($total) significantly increases complexity.');
    } else if (total > 30) {
      score -= 18.0;
      observations.add('High layer count ($total) adds design complexity.');
    } else if (total > 15) {
      score -= 8.0;
      observations.add('Moderate layer count ($total).');
    }

    if (zeroSize > 0) {
      score -= (zeroSize * 4.0).clamp(0.0, 20.0);
      observations.add('$zeroSize layer(s) have zero width or height.');
    }

    if (transparent > 0) {
      score -= (transparent * 2.0).clamp(0.0, 10.0);
      observations.add('$transparent fully transparent layer(s) are invisible.');
    }

    if (locked == total && total > 0) {
      score -= 10.0;
      observations.add('All layers are locked — editing is blocked.');
    }

    if (visible == 0 && total > 0) {
      score -= 20.0;
      observations.add('No layers are visible on the canvas.');
    }

    final rotationPenalty = rotated > 5 ? 8.0 : rotated * 1.5;
    if (rotated > 0) {
      score -= rotationPenalty;
      observations.add('$rotated layer(s) have non-standard rotation angles.');
    }

    final typeCount = typeMap.length;
    if (typeCount > 6) {
      score -= 5.0;
      observations.add('$typeCount distinct layer types detected — high visual variety.');
    }

    final finalScore = score.clamp(0.0, 100.0);
    final level = finalScore < 40.0
        ? InsightSeverity.high
        : finalScore < 70.0
            ? InsightSeverity.medium
            : InsightSeverity.low;

    if (observations.isEmpty) {
      observations.add('Complexity is within normal bounds.');
    }

    return ComplexityResult(
      score: double.parse(finalScore.toStringAsFixed(2)),
      totalLayers: total,
      visibleLayers: visible,
      lockedLayers: locked,
      zeroSizeLayers: zeroSize,
      rotatedLayers: rotated,
      transparentLayers: transparent,
      typeDistribution: Map.unmodifiable(typeMap),
      level: level,
      observations: List.unmodifiable(observations),
    );
  }

  // ── calculateUXScore ── ��────────────────────────────────────────

  UXScoreResult calculateUXScore(
      List<LayerDescriptor> layers, DesignSnapshot design) {
    final observations = <String>[];

    if (layers.isEmpty) {
      return UXScoreResult(
        score: 0.0,
        contentVisibilityRatio: 0.0,
        lockRatio: 0.0,
        alignmentScore: 0.0,
        accessibilityScore: 0.0,
        clarity: InsightSeverity.high,
        observations: ['No layers to evaluate UX quality.'],
      );
    }

    final total = layers.length;

    // Content visibility ratio.
    final visible = layers.where((l) => l.visible && !l.isFullyTransparent).length;
    final visibilityRatio = visible / total;

    // Lock ratio (high lock ratio = poor editability signal).
    final locked = layers.where((l) => l.locked).length;
    final lockRatio = locked / total;

    // Alignment score: layers with x or y not divisible by 1 (sub-pixel).
    final misaligned = layers
        .where((l) => l.x % 1.0 != 0.0 || l.y % 1.0 != 0.0)
        .length;
    final alignmentScore =
        total > 0 ? ((total - misaligned) / total * 100.0) : 100.0;

    // Accessibility: text layers with very low opacity or zero size.
    final textLayers = layers
        .where((l) => l.layerType.toLowerCase().contains('text'))
        .toList();
    final badTextLayers = textLayers
        .where((l) => l.opacity < 0.3 || l.isZeroSize)
        .length;
    final accessibilityScore = textLayers.isEmpty
        ? 80.0
        : ((textLayers.length - badTextLayers) / textLayers.length * 100.0);

    // UX score composite.
    double score = 0.0;
    score += visibilityRatio * 35.0;
    score += (1.0 - lockRatio) * 20.0;
    score += alignmentScore * 0.25;
    score += accessibilityScore * 0.20;

    if (!design.hasTitle) {
      score -= 5.0;
      observations.add('Design has no title — untitled designs are harder to identify.');
    }

    if (visibilityRatio < 0.3) {
      observations.add(
          'Only ${(visibilityRatio * 100).toStringAsFixed(0)}% of layers '
          'are visible — much of the design content is hidden.');
    }
    if (lockRatio > 0.8) {
      observations.add(
          '${(lockRatio * 100).toStringAsFixed(0)}% of layers are locked, '
          'limiting editing flexibility.');
    }
    if (misaligned > 0) {
      observations.add(
          '$misaligned layer(s) have sub-pixel positions, which can cause '
          'blurry rendering on some screens.');
    }
    if (badTextLayers > 0) {
      observations.add(
          '$badTextLayers text layer(s) have very low opacity or zero size '
          'and may be unreadable.');
    }

    final finalScore = score.clamp(0.0, 100.0);
    final clarity = finalScore < 40.0
        ? InsightSeverity.high
        : finalScore < 70.0
            ? InsightSeverity.medium
            : InsightSeverity.low;

    if (observations.isEmpty) {
      observations.add('UX quality is within acceptable bounds.');
    }

    return UXScoreResult(
      score: double.parse(finalScore.toStringAsFixed(2)),
      contentVisibilityRatio:
          double.parse(visibilityRatio.toStringAsFixed(4)),
      lockRatio: double.parse(lockRatio.toStringAsFixed(4)),
      alignmentScore: double.parse(alignmentScore.toStringAsFixed(2)),
      accessibilityScore: double.parse(accessibilityScore.toStringAsFixed(2)),
      clarity: clarity,
      observations: List.unmodifiable(observations),
    );
  }

  // ── detectRisks ────────────────────────────────────────────────

  List<RiskEntry> detectRisks(
      List<LayerDescriptor> layers,
      DesignSnapshot design,
      SystemContext system,
      List<InteractionEvent> history) {
    final risks = <RiskEntry>[];

    // Layer overload.
    if (layers.length > 50) {
      risks.add(RiskEntry(
        area: RiskArea.layerOverload,
        severity: InsightSeverity.high,
        description:
            '${layers.length} layers detected. Designs above 50 layers '
            'typically experience slower render performance.',
        riskContribution: 20.0,
      ));
    } else if (layers.length > 25) {
      risks.add(RiskEntry(
        area: RiskArea.layerOverload,
        severity: InsightSeverity.medium,
        description:
            '${layers.length} layers — approaching high-complexity territory.',
        riskContribution: 8.0,
      ));
    }

    // Hidden content.
    final hidden = layers.where((l) => !l.visible).length;
    if (hidden > 10) {
      risks.add(RiskEntry(
        area: RiskArea.hiddenContent,
        severity: InsightSeverity.medium,
        description:
            '$hidden hidden layers may contain stale or forgotten content.',
        riskContribution: 6.0,
      ));
    }

    // All content locked.
    final locked = layers.where((l) => l.locked).length;
    if (locked == layers.length && layers.isNotEmpty) {
      risks.add(RiskEntry(
        area: RiskArea.lockedContent,
        severity: InsightSeverity.high,
        description: 'All layers are locked — the design cannot be edited.',
        riskContribution: 18.0,
      ));
    }

    // Accessibility gap — low opacity text.
    final lowOpacityText = layers
        .where((l) =>
            l.layerType.toLowerCase().contains('text') &&
            l.opacity < 0.4 &&
            l.visible)
        .length;
    if (lowOpacityText > 0) {
      risks.add(RiskEntry(
        area: RiskArea.accessibilityGap,
        severity: InsightSeverity.high,
        description:
            '$lowOpacityText text layer(s) have opacity below 40%, '
            'which may fail contrast accessibility standards.',
        riskContribution: 15.0,
      ));
    }

    // Sub-pixel misalignment.
    final misaligned = layers
        .where((l) => l.x % 1.0 != 0.0 || l.y % 1.0 != 0.0)
        .length;
    if (misaligned > layers.length * 0.3 && layers.length > 3) {
      risks.add(RiskEntry(
        area: RiskArea.poorAlignment,
        severity: InsightSeverity.medium,
        description:
            '${(misaligned / layers.length * 100).toStringAsFixed(0)}% of '
            'layers have sub-pixel positions that may cause blurry rendering.',
        riskContribution: 7.0,
      ));
    }

    // Zero-size layers (structural issue).
    final zeroSize = layers.where((l) => l.isZeroSize).length;
    if (zeroSize > 0) {
      risks.add(RiskEntry(
        area: RiskArea.missingContent,
        severity: InsightSeverity.medium,
        description:
            '$zeroSize layer(s) have zero width or height and render nothing.',
        riskContribution: 5.0,
      ));
    }

    // Performance risk — render latency.
    if (system.renderLatencyMs > 500.0) {
      risks.add(RiskEntry(
        area: RiskArea.performanceDegradation,
        severity: InsightSeverity.high,
        description:
            'Render latency is ${system.renderLatencyMs.toStringAsFixed(1)}ms, '
            'above the 500ms warning threshold.',
        riskContribution: 18.0,
      ));
    } else if (system.renderLatencyMs > 200.0) {
      risks.add(RiskEntry(
        area: RiskArea.performanceDegradation,
        severity: InsightSeverity.medium,
        description:
            'Render latency is ${system.renderLatencyMs.toStringAsFixed(1)}ms. '
            'Performance may degrade with more layers.',
        riskContribution: 8.0,
      ));
    }

    // Memory pressure.
    if (system.estimatedMemoryMb > 400.0) {
      risks.add(RiskEntry(
        area: RiskArea.performanceDegradation,
        severity: InsightSeverity.high,
        description:
            'Estimated memory usage ${system.estimatedMemoryMb.toStringAsFixed(1)}MB '
            'is critically high.',
        riskContribution: 16.0,
      ));
    }

    // Interaction anomaly — high failure rate.
    if (history.isNotEmpty) {
      final failed = history.where((e) => !e.wasSuccessful).length;
      final failRate = failed / history.length;
      if (failRate > 0.20) {
        risks.add(RiskEntry(
          area: RiskArea.interactionAnomaly,
          severity: InsightSeverity.high,
          description:
              '${(failRate * 100).toStringAsFixed(0)}% of recent interactions '
              'failed — the user may be experiencing errors.',
          riskContribution: 14.0,
        ));
      } else if (failRate > 0.08) {
        risks.add(RiskEntry(
          area: RiskArea.interactionAnomaly,
          severity: InsightSeverity.medium,
          description:
              '${(failRate * 100).toStringAsFixed(0)}% interaction failure '
              'rate detected in session history.',
          riskContribution: 6.0,
        ));
      }
    }

    // Deep nesting heuristic — many layers of same type stacked.
    final typeGroups = <String, int>{};
    for (final l in layers) {
      typeGroups[l.layerType] = (typeGroups[l.layerType] ?? 0) + 1;
    }
    final maxSameType = typeGroups.values.isEmpty
        ? 0
        : typeGroups.values.reduce(max);
    if (maxSameType > 15) {
      risks.add(RiskEntry(
        area: RiskArea.deepNesting,
        severity: InsightSeverity.medium,
        description:
            '$maxSameType layers of the same type detected. '
            'Excessive same-type stacking can indicate deep nesting.',
        riskContribution: 5.0,
      ));
    }

    // Sort: high severity first, then by contribution descending.
    risks.sort((a, b) {
      final sc = b.severity.index.compareTo(a.severity.index);
      if (sc != 0) return sc;
      return b.riskContribution.compareTo(a.riskContribution);
    });

    return risks;
  }

  // ── generateReport ─────────────────────────────────────────────

  InsightReport generateReport({
    required String requestId,
    required double overallScore,
    required ComplexityResult complexityResult,
    required UXScoreResult uxScoreResult,
    required List<InsightIssue> issues,
    required List<String> warnings,
    required List<String> recommendations,
    required List<RiskEntry> riskAreas,
    required String voiceSummary,
    required InsightSeverity severityLevel,
  }) {
    return InsightReport._(
      reportId: _IEIdGen.next('rpt'),
      requestId: requestId,
      generatedAt: DateTime.now().toUtc(),
      overallScore: double.parse(overallScore.clamp(0.0, 100.0).toStringAsFixed(2)),
      complexityResult: complexityResult,
      uxScoreResult: uxScoreResult,
      issues: List.unmodifiable(issues),
      warnings: List.unmodifiable(warnings),
      recommendations: List.unmodifiable(recommendations),
      riskAreas: List.unmodifiable(riskAreas),
      voiceSummary: voiceSummary,
      severityLevel: severityLevel,
    );
  }

  // ── generateVoiceSummary ───────────────────────────────────────

  String generateVoiceSummary(
      double overallScore,
      InsightSeverity severity,
      ComplexityResult complexity,
      UXScoreResult ux,
      List<InsightIssue> issues) {
    final buf = StringBuffer();

    // Opening verdict.
    if (overallScore >= 80.0) {
      buf.write('Your design is in great shape with an overall score of '
          '${overallScore.toStringAsFixed(0)} out of 100. ');
    } else if (overallScore >= 55.0) {
      buf.write('Your design looks reasonable, scoring '
          '${overallScore.toStringAsFixed(0)} out of 100. '
          'A few areas could use attention. ');
    } else {
      buf.write('Your design needs attention. '
          'The overall score is ${overallScore.toStringAsFixed(0)} out of 100. ');
    }

    // Complexity note.
    if (complexity.level == InsightSeverity.high) {
      buf.write('Complexity is high with ${complexity.totalLayers} layers, '
          'which may affect performance. ');
    } else if (complexity.totalLayers == 0) {
      buf.write('The canvas is currently empty. ');
    }

    // UX note.
    if (ux.score < 40.0) {
      buf.write('UX clarity is low — '
          '${(ux.contentVisibilityRatio * 100).toStringAsFixed(0)}% '
          'of layers are visible. ');
    } else if (ux.accessibilityScore < 60.0) {
      buf.write('Some text layers may have accessibility issues. ');
    }

    // Issues note.
    final highIssues =
        issues.where((i) => i.severity == InsightSeverity.high).length;
    if (highIssues > 0) {
      buf.write('There ${highIssues == 1 ? "is" : "are"} $highIssues '
          'high-severity ${highIssues == 1 ? "issue" : "issues"} to review. ');
    }

    // Closing.
    if (severity == InsightSeverity.low) {
      buf.write('No immediate action is required.');
    } else if (severity == InsightSeverity.medium) {
      buf.write('Review the recommendations in the report for guidance.');
    } else {
      buf.write('Review the high-severity issues listed in the report.');
    }

    return buf.toString().trim();
  }

  // ── Private helpers ───────────────────────────────────────────

  InsightValidationResult _validateRequest(InsightRequest request) {
    final errors = <String>[];
    final warnings = <String>[];

    if (request.requestId.trim().isEmpty) {
      errors.add('InsightRequest.requestId must not be empty.');
    }
    if (request.designModel.canvasWidth <= 0 ||
        request.designModel.canvasHeight <= 0) {
      warnings.add(
          'DesignSnapshot has non-positive canvas dimensions; '
          'some layout analyses may be inaccurate.');
    }

    if (errors.isEmpty) {
      return InsightValidationResult.ok(warnings: warnings);
    }
    return InsightValidationResult.fail(errors, warnings: warnings);
  }

  List<InsightIssue> _buildIssues(
      ComplexityResult complexity,
      UXScoreResult ux,
      List<RiskEntry> risks,
      List<LayerDescriptor> layers,
      DesignSnapshot design) {
    final issues = <InsightIssue>[];

    if (complexity.zeroSizeLayers > 0) {
      issues.add(InsightIssue(
        issueId: _IEIdGen.next('iss'),
        category: IssueCategory.structure,
        severity: InsightSeverity.medium,
        title: 'Zero-size layers detected',
        detail: '${complexity.zeroSizeLayers} layer(s) have zero width or '
            'height and do not render any visible content.',
        affectedLayerIds: layers
            .where((l) => l.isZeroSize)
            .map((l) => l.layerId)
            .toList(),
      ));
    }

    if (complexity.transparentLayers > 0) {
      issues.add(InsightIssue(
        issueId: _IEIdGen.next('iss'),
        category: IssueCategory.ux,
        severity: InsightSeverity.low,
        title: 'Fully transparent layers',
        detail: '${complexity.transparentLayers} layer(s) have zero opacity '
            'and are completely invisible.',
        affectedLayerIds: layers
            .where((l) => l.isFullyTransparent)
            .map((l) => l.layerId)
            .toList(),
      ));
    }

    if (ux.accessibilityScore < 50.0) {
      issues.add(InsightIssue(
        issueId: _IEIdGen.next('iss'),
        category: IssueCategory.accessibility,
        severity: InsightSeverity.high,
        title: 'Text accessibility concerns',
        detail: 'Multiple text layers have low opacity or zero size, '
            'which may make them unreadable.',
        affectedLayerIds: layers
            .where((l) =>
                l.layerType.toLowerCase().contains('text') &&
                (l.opacity < 0.3 || l.isZeroSize))
            .map((l) => l.layerId)
            .toList(),
      ));
    }

    if (!design.hasTitle) {
      issues.add(InsightIssue(
        issueId: _IEIdGen.next('iss'),
        category: IssueCategory.ux,
        severity: InsightSeverity.low,
        title: 'Untitled design',
        detail: 'The design has no title, making it difficult to identify '
            'in a library or export.',
      ));
    }

    for (final risk in risks) {
      if (risk.severity == InsightSeverity.high) {
        issues.add(InsightIssue(
          issueId: _IEIdGen.next('iss'),
          category: _riskAreaToCategory(risk.area),
        � severity: risk.severity,
          title: _riskAreaLabel(risk.area),
          detail: risk.description,
        ));
      }
    }

    // Sort: high first.
    issues.sort((a, b) => b.severity.index.compareTo(a.severity.index));
    return issues;
  }

  List<String> _buildWarnings(SystemContext system, DesignSnapshot design) {
    final warnings = <String>[];
    if (system.hasUnsavedChanges) {
      warnings.add('Design has unsaved changes.');
    }
    if (!system.isOnline) {
      warnings.add('Device is offline — cloud sync is unavailable.');
    }
    if (system.undoStackDepth > 20) {
      warnings.add(
          'Undo stack depth is ${system.undoStackDepth} — '
          'consider saving a checkpoint.');
    }
    return warnings;
  }

  List<String> _buildRecommendations(
      ComplexityResult complexity,
      UXScoreResult ux,
      List<RiskEntry> risks,
      DesignSnapshot design) {
    final recs = <String>[];

    if (complexity.totalLayers > 30) {
      recs.add('Group related layers to reduce overall layer count and '
          'improve design organisation.');
    }
    if (complexity.zeroSizeLayers > 0) {
      recs.add('Review and remove zero-size layers that render no content.');
    }
    if (complexity.transparentLayers > 0) {
      recs.add('Check fully transparent layers — they may be leftovers '
          'that can be removed.');
    }
    if (ux.accessibilityScore < 60.0) {
      recs.add('Increase the opacity of text layers to meet accessibility '
          'contrast guidelines.');
    }
    if (ux.lockRatio > 0.8) {
      recs.add('Unlock layers that need editing — high lock ratios limit '
          'design flexibility.');
    }
    if (!design.hasTitle) {
      recs.add('Give the design a meaningful title for easier identification.');
    }
    for (final risk in risks) {
      if (risk.severity == InsightSeverity.high) {
        recs.add(_riskToRecommendation(risk.area));
      }
    }

    return recs;
  }

  double _computeOverallScore(
      ComplexityResult complexity,
      UXScoreResult ux,
      List<RiskEntry> risks) {
    // Weighted composite.
    double score = complexity.score * 0.35 + ux.score * 0.45;

    // Deduct risk contributions (capped at 40 points total).
    final totalRisk = risks
        .fold(0.0, (sum, r) => sum + r.riskContribution)
        .clamp(0.0, 40.0);
    score -= totalRisk;

    return score.clamp(0.0, 100.0);
  }

  InsightSeverity _deriveSeverity(
      double overallScore, List<InsightIssue> issues) {
    final highIssues =
        issues.where((i) => i.severity == InsightSeverity.high).length;
    if (overallScore < 40.0 || highIssues >= 3) return InsightSeverity.high;
    if (overallScore < 65.0 || highIssues >= 1) return InsightSeverity.medium;
    return InsightSeverity.low;
  }

  IssueCategory _riskAreaToCategory(RiskArea area) {
    switch (area) {
      case RiskArea.accessibilityGap:
      case RiskArea.contrastIssue:
        return IssueCategory.accessibility;
      case RiskArea.performanceDegradation:
      case RiskArea.layerOverload:
        return IssueCategory.performance;
      case RiskArea.poorAlignment:
      case RiskArea.inconsistentSpacing:
        return IssueCategory.consistency;
      case RiskArea.interactionAnomaly:
        return IssueCategory.interaction;
      default:
        return IssueCategory.structure;
    }
  }

  String _riskAreaLabel(RiskArea area) {
    switch (area) {
      case RiskArea.layerOverload:
        return 'Layer overload';
      case RiskArea.hiddenContent:
        return 'Excessive hidden content';
      case RiskArea.lockedContent:
        return 'All content locked';
      case RiskArea.accessibilityGap:
        return 'Accessibility gap';
      case RiskArea.contrastIssue:
        return 'Contrast issue';
      case RiskArea.deepNesting:
        return 'Deep layer nesting';
      case RiskArea.poorAlignment:
        return 'Poor alignment';
      case RiskArea.inconsistentSpacing:
        return 'Inconsistent spacing';
      case RiskArea.missingContent:
        return 'Missing or zero-size content';
      case RiskArea.interactionAnomaly:
        return 'Interaction failure anomaly';
      case RiskArea.performanceDegradation:
        return 'Performance degradation';
    }
  }

  String _riskToRecommendation(RiskArea area) {
    switch (area) {
      case RiskArea.layerOverload:
        return 'Reduce layer count by merging or removing unused layers.';
      case RiskArea.lockedContent:
        return 'Unlock layers before attempting further edits.';
      case RiskArea.accessibilityGap:
        return 'Increase text layer opacity to improve readability and contrast.';
      case RiskArea.performanceDegradation:
        return 'Optimise resource-heavy layers and reduce overall layer count '
            'to improve render performance.';
      case RiskArea.interactionAnomaly:
        return 'Investigate recent interaction failures — review error logs '
            'for root cause.';
      default:
        return 'Review the ${_riskAreaLabel(area).toLowerCase()} '
            'identified in this report.';
    }
  }

  ComplexityResult _emptyComplexity() => const ComplexityResult(
        score: 0.0,
        totalLayers: 0,
        visibleLayers: 0,
        lockedLayers: 0,
        zeroSizeLayers: 0,
        rotatedLayers: 0,
        transparentLayers: 0,
        typeDistribution: {},
        level: InsightSeverity.high,
        observations: ['Complexity data unavailable.'],
      );

  UXScoreResult _emptyUX() => const UXScoreResult(
        score: 0.0,
        contentVisibilityRatio: 0.0,
        lockRatio: 0.0,
        alignmentScore: 0.0,
        accessibilityScore: 0.0,
        clarity: InsightSeverity.high,
        observations: ['UX data unavailable.'],
      );
}
