// ignore_for_file: avoid_catches_without_on_clauses

import 'dart:math';

// ── Monitored engines ─────────────────────────────────────────
enum MonitoredEngine {
  editorController,
  layerEngine,
  historyEngine,
  renderEngine,
  storageEngine,
  aiEngine,
  exportEngine,
  templateEngine,
  syncEngine,
  automationEngine,
  workflowEngine,
  pluginEngine,
}

// ── Overall health status ─────────────────────────────────────
enum HealthStatus { ok, warning, critical }

// ── Severity level ────────────────────────────────────────────
enum HealthSeverity { low, medium, high, critical }

// ── Check scope ───────────────────────────────────────────────
enum HealthCheckScope {
  all,
  coreOnly,
  phase5Only,
  single,
}

// ── Bottleneck category ───────────────────────────────────────
enum BottleneckCategory {
  latency,
  errorRate,
  callVolume,
  timeout,
  memoryPressure,
  loadSpike,
}

// ── EngineMetricSample — input data point ─────────────────────
// Callers (EditorController) supply these read-only snapshots;
// SystemHealthEngine never reads from engines directly.
class EngineMetricSample {
  final MonitoredEngine engine;
  final DateTime sampledAt;
  final double avgLatencyMs;
  final double peakLatencyMs;
  final int callCount;
  final int errorCount;
  final int timeoutCount;
  final double estimatedMemoryMb;
  final double cpuLoadPercent;
  final bool isReachable;

  const EngineMetricSample({
    required this.engine,
    required this.sampledAt,
    required this.avgLatencyMs,
    required this.peakLatencyMs,
    required this.callCount,
    required this.errorCount,
    required this.timeoutCount,
    required this.estimatedMemoryMb,
    required this.cpuLoadPercent,
    required this.isReachable,
  });

  double get errorRate =>
      callCount > 0 ? errorCount / callCount * 100.0 : 0.0;

  double get timeoutRate =>
      callCount > 0 ? timeoutCount / callCount * 100.0 : 0.0;
}

// ── HealthCheckRequest — input contract ───────────────────────
class HealthCheckRequest {
  final String checkId;
  final HealthCheckScope scope;
  final HealthSeverity severityLevel;
  final List<EngineMetricSample> samples;
  final MonitoredEngine? singleEngineTarget;

  const HealthCheckRequest({
    required this.checkId,
    required this.scope,
    required this.severityLevel,
    required this.samples,
    this.singleEngineTarget,
  });
}

// ── Engine health entry ────────────────────────────────────────
class EngineHealthEntry {
  final MonitoredEngine engine;
  final HealthStatus status;
  final double latencyMs;
  final double errorRatePercent;
  final double timeoutRatePercent;
  final double estimatedMemoryMb;
  final double cpuLoadPercent;
  final bool isReachable;
  final List<String> observations;
  final double stabilityScore;

  const EngineHealthEntry({
    required this.engine,
    required this.status,
    required this.latencyMs,
    required this.errorRatePercent,
    required this.timeoutRatePercent,
    required this.estimatedMemoryMb,
    required this.cpuLoadPercent,
    required this.isReachable,
    required this.observations,
    required this.stabilityScore,
  });

  Map<String, dynamic> toMap() => {
        'engine': engine.name,
        'status': status.name,
        'latencyMs': latencyMs,
        'errorRatePercent': errorRatePercent,
        'timeoutRatePercent': timeoutRatePercent,
        'estimatedMemoryMb': estimatedMemoryMb,
        'cpuLoadPercent': cpuLoadPercent,
        'isReachable': isReachable,
        'observations': observations,
        'stabilityScore': stabilityScore,
      };
}

// ── Bottleneck ────────────────────────────────────────────────
class Bottleneck {
  final String bottleneckId;
  final MonitoredEngine engine;
  final BottleneckCategory category;
  final HealthSeverity severity;
  final double measuredValue;
  final double threshold;
  final String description;
  final DateTime detectedAt;

  const Bottleneck({
    required this.bottleneckId,
    required this.engine,
    required this.category,
    required this.severity,
    required this.measuredValue,
    required this.threshold,
    required this.description,
    required this.detectedAt,
  });

  Map<String, dynamic> toMap() => {
        'bottleneckId': bottleneckId,
        'engine': engine.name,
        'category': category.name,
        'severity': severity.name,
        'measuredValue': measuredValue,
        'threshold': threshold,
        'description': description,
        'detectedAt': detectedAt.toIso8601String(),
      };
}

// ── Non-executable recommendation ────────────────────────────
class HealthRecommendation {
  final String recommendationId;
  final MonitoredEngine? affectedEngine;
  final HealthSeverity urgency;
  final String title;
  final String detail;

  const HealthRecommendation({
    required this.recommendationId,
    this.affectedEngine,
    required this.urgency,
    required this.title,
    required this.detail,
  });

  Map<String, dynamic> toMap() => {
        'recommendationId': recommendationId,
        'affectedEngine': affectedEngine?.name,
        'urgency': urgency.name,
        'title': title,
        'detail': detail,
      };
}

// ── SystemHealthReport — output contract ──────────────────────
class SystemHealthReport {
  final String reportId;
  final String checkId;
  final DateTime generatedAt;
  final HealthStatus overallStatus;
  final Map<String, EngineHealthEntry> engineHealthMap;
  final List<Bottleneck> bottlenecks;
  final double riskScore;
  final double stabilityIndex;
  final List<HealthRecommendation> recommendations;
  final List<String> warnings;

  const SystemHealthReport({
    required this.reportId,
    required this.checkId,
    required this.generatedAt,
    required this.overallStatus,
    required this.engineHealthMap,
    required this.bottlenecks,
    required this.riskScore,
    required this.stabilityIndex,
    required this.recommendations,
    this.warnings = const [],
  });

  Map<String, dynamic> toMap() => {
        'reportId': reportId,
        'checkId': checkId,
        'generatedAt': generatedAt.toIso8601String(),
        'overallStatus': overallStatus.name,
        'engineHealthMap': engineHealthMap
            .map((k, v) => MapEntry(k, v.toMap())),
        'bottlenecks': bottlenecks.map((b) => b.toMap()).toList(),
        'riskScore': riskScore,
        'stabilityIndex': stabilityIndex,
        'recommendations':
            recommendations.map((r) => r.toMap()).toList(),
        'warnings': warnings,
      };
}

// ── Health check result ────────────────────────────────────────
class HealthCheckResult {
  final bool success;
  final SystemHealthReport? report;
  final List<String> errors;

  const HealthCheckResult.ok(this.report)
      : success = true,
        errors = const [];

  const HealthCheckResult.failure(this.errors)
      : success = false,
        report = null;
}

// ── Thresholds ────────────────────────────────────────────────
class _Threshold {
  static const double latencyWarningMs = 200.0;
  static const double latencyCriticalMs = 1000.0;
  static const double errorRateWarningPct = 5.0;
  static const double errorRateCriticalPct = 15.0;
  static const double timeoutRateWarningPct = 2.0;
  static const double timeoutRateCriticalPct = 8.0;
  static const double memoryWarningMb = 256.0;
  static const double memoryCriticalMb = 512.0;
  static const double cpuWarningPct = 70.0;
  static const double cpuCriticalPct = 90.0;
  static const double callVolumeWarning = 500.0;
  static const double callVolumeCritical = 2000.0;
}

// ── ID generator ──────────────────────────────────────────────
class _SHIdGen {
  static final Random _rng = Random.secure();

  static String next(String prefix) {
    final bytes = List<int>.generate(6, (_) => _rng.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '$prefix-$hex-${DateTime.now().microsecondsSinceEpoch}';
  }
}

// ── SystemHealthEngine ────────────────────────────────────────
class SystemHealthEngine {
  final List<SystemHealthReport> _reportHistory = [];
  static const int _maxHistorySize = 200;

  // ── runHealthCheck ─────────────────────────────────────────────

  HealthCheckResult runHealthCheck(HealthCheckRequest request) {
    try {
      final validation = _validateRequest(request);
      if (validation != null) {
        return HealthCheckResult.failure([validation]);
      }

      final scopedSamples = _applyScopeFilter(
          request.samples, request.scope, request.singleEngineTarget);

      if (scopedSamples.isEmpty) {
        return const HealthCheckResult.failure(
            ['No metric samples available for the requested scope. '
                'Supply EngineMetricSample records to runHealthCheck().']);
      }

      final healthMap = <String, EngineHealthEntry>{};
      for (final sample in scopedSamples) {
        final entry = evaluateEngineHealth(sample, request.severityLevel);
        healthMap[sample.engine.name] = entry;
      }

      final bottlenecks = detectBottlenecks(scopedSamples);
      final riskScore = calculateRiskScore(healthMap, bottlenecks);
      final stabilityIndex = _computeStabilityIndex(healthMap);
      final overallStatus = _deriveOverallStatus(healthMap, riskScore);
      final recommendations = _buildRecommendations(
          healthMap, bottlenecks, overallStatus);
      final warnings = _collectWarnings(healthMap, bottlenecks, riskScore);

      final report = SystemHealthReport(
        reportId: _SHIdGen.next('rpt'),
        checkId: request.checkId,
        generatedAt: DateTime.now().toUtc(),
        overallStatus: overallStatus,
        engineHealthMap: Map.unmodifiable(healthMap),
        bottlenecks: List.unmodifiable(bottlenecks),
        riskScore: riskScore,
        stabilityIndex: stabilityIndex,
        recommendations: List.unmodifiable(recommendations),
        warnings: warnings,
      );

      if (_reportHistory.length >= _maxHistorySize) {
        _reportHistory.removeAt(0);
      }
      _reportHistory.add(report);

      return HealthCheckResult.ok(report);
    } catch (e) {
      return HealthCheckResult.failure(
          ['runHealthCheck threw: $e']);
    }
  }

  // ── evaluateEngineHealth ───────────────────────────────────────

  EngineHealthEntry evaluateEngineHealth(
      EngineMetricSample sample, HealthSeverity severityLevel) {
    final observations = <String>[];
    var worstStatus = HealthStatus.ok;

    void flag(HealthStatus s, String msg) {
      observations.add(msg);
      if (s.index > worstStatus.index) worstStatus = s;
    }

    if (!sample.isReachable) {
      flag(HealthStatus.critical,
          'Engine is unreachable — not responding to health probe.');
    }

    if (sample.avgLatencyMs >= _Threshold.latencyCriticalMs) {
      flag(HealthStatus.critical,
          'Avg latency ${_fmt(sample.avgLatencyMs)}ms exceeds critical '
          'threshold ${_fmt(_Threshold.latencyCriticalMs)}ms.');
    } else if (sample.avgLatencyMs >= _Threshold.latencyWarningMs) {
      flag(HealthStatus.warning,
          'Avg latency ${_fmt(sample.avgLatencyMs)}ms exceeds warning '
          'threshold ${_fmt(_Threshold.latencyWarningMs)}ms.');
    }

    if (sample.peakLatencyMs >= _Threshold.latencyCriticalMs * 2) {
      flag(HealthStatus.critical,
          'Peak latency ${_fmt(sample.peakLatencyMs)}ms is critically high.');
    }

    if (sample.errorRate >= _Threshold.errorRateCriticalPct) {
      flag(HealthStatus.critical,
          'Error rate ${_fmt(sample.errorRate)}% exceeds critical '
          'threshold ${_fmt(_Threshold.errorRateCriticalPct)}%.');
    } else if (sample.errorRate >= _Threshold.errorRateWarningPct) {
      flag(HealthStatus.warning,
          'Error rate ${_fmt(sample.errorRate)}% exceeds warning '
          'threshold ${_fmt(_Threshold.errorRateWarningPct)}%.');
    }

    if (sample.timeoutRate >= _Threshold.timeoutRateCriticalPct) {
      flag(HealthStatus.critical,
          'Timeout rate ${_fmt(sample.timeoutRate)}% exceeds critical '
          'threshold ${_fmt(_Threshold.timeoutRateCriticalPct)}%.');
    } else if (sample.timeoutRate >= _Threshold.timeoutRateWarningPct) {
      flag(HealthStatus.warning,
          'Timeout rate ${_fmt(sample.timeoutRate)}% exceeds warning '
          'threshold ${_fmt(_Threshold.timeoutRateWarningPct)}%.');
    }

    if (sample.estimatedMemoryMb >= _Threshold.memoryCriticalMb) {
      flag(HealthStatus.critical,
          'Estimated memory ${_fmt(sample.estimatedMemoryMb)}MB exceeds '
          'critical threshold ${_fmt(_Threshold.memoryCriticalMb)}MB.');
    } else if (sample.estimatedMemoryMb >= _Threshold.memoryWarningMb) {
      flag(HealthStatus.warning,
          'Estimated memory ${_fmt(sample.estimatedMemoryMb)}MB exceeds '
          'warning threshold ${_fmt(_Threshold.memoryWarningMb)}MB.');
    }

    if (sample.cpuLoadPercent >= _Threshold.cpuCriticalPct) {
      flag(HealthStatus.critical,
          'CPU load ${_fmt(sample.cpuLoadPercent)}% exceeds critical '
          'threshold ${_fmt(_Threshold.cpuCriticalPct)}%.');
    } else if (sample.cpuLoadPercent >= _Threshold.cpuWarningPct) {
      flag(HealthStatus.warning,
          'CPU load ${_fmt(sample.cpuLoadPercent)}% exceeds warning '
          'threshold ${_fmt(_Threshold.cpuWarningPct)}%.');
    }

    // Suppress sub-threshold findings when severityLevel is high/critical.
    final effectiveStatus =
        _applyMinimumSeverity(worstStatus, severityLevel);

    final stabilityScore = _scoreStability(sample);

    if (observations.isEmpty) {
      observations.add('All metrics within normal bounds.');
    }

    return EngineHealthEntry(
      engine: sample.engine,
      status: effectiveStatus,
      latencyMs: double.parse(sample.avgLatencyMs.toStringAsFixed(3)),
      errorRatePercent:
          double.parse(sample.errorRate.toStringAsFixed(4)),
      timeoutRatePercent:
          double.parse(sample.timeoutRate.toStringAsFixed(4)),
      estimatedMemoryMb:
          double.parse(sample.estimatedMemoryMb.toStringAsFixed(2)),
      cpuLoadPercent:
          double.parse(sample.cpuLoadPercent.toStringAsFixed(2)),
      isReachable: sample.isReachable,
      observations: List.unmodifiable(observations),
      stabilityScore: double.parse(stabilityScore.toStringAsFixed(4)),
    );
  }

  // ── detectBottlenecks ──────────────────────────────────────────

  List<Bottleneck> detectBottlenecks(List<EngineMetricSample> samples) {
    final bottlenecks = <Bottleneck>[];
    final now = DateTime.now().toUtc();

    for (final sample in samples) {
      // Latency bottleneck.
      if (sample.avgLatencyMs >= _Threshold.latencyWarningMs) {
        final severity = sample.avgLatencyMs >= _Threshold.latencyCriticalMs
            ? HealthSeverity.critical
            : HealthSeverity.medium;
        bottlenecks.add(Bottleneck(
          bottleneckId: _SHIdGen.next('bn'),
          engine: sample.engine,
          category: BottleneckCategory.latency,
          severity: severity,
          measuredValue:
              double.parse(sample.avgLatencyMs.toStringAsFixed(3)),
          threshold: severity == HealthSeverity.critical
              ? _Threshold.latencyCriticalMs
              : _Threshold.latencyWarningMs,
          description:
              '${sample.engine.name} avg latency ${_fmt(sample.avgLatencyMs)}ms '
              'exceeds ${_fmt(severity == HealthSeverity.critical ? _Threshold.latencyCriticalMs : _Threshold.latencyWarningMs)}ms threshold.',
          detectedAt: now,
        ));
      }

      // Error rate bottleneck.
      if (sample.errorRate >= _Threshold.errorRateWarningPct) {
        final severity = sample.errorRate >= _Threshold.errorRateCriticalPct
            ? HealthSeverity.critical
            : HealthSeverity.high;
        bottlenecks.add(Bottleneck(
          bottleneckId: _SHIdGen.next('bn'),
          engine: sample.engine,
          category: BottleneckCategory.errorRate,
          severity: severity,
          measuredValue: double.parse(sample.errorRate.toStringAsFixed(4)),
          threshold: severity == HealthSeverity.critical
              ? _Threshold.errorRateCriticalPct
              : _Threshold.errorRateWarningPct,
          description:
              '${sample.engine.name} error rate ${_fmt(sample.errorRate)}% '
              'is above acceptable bounds.',
          detectedAt: now,
        ));
      }

      // Timeout bottleneck.
      if (sample.timeoutRate >= _Threshold.timeoutRateWarningPct) {
        final severity =
            sample.timeoutRate >= _Threshold.timeoutRateCriticalPct
                ? HealthSeverity.critical
                : HealthSeverity.high;
        bottlenecks.add(Bottleneck(
          bottleneckId: _SHIdGen.next('bn'),
          engine: sample.engine,
          category: BottleneckCategory.timeout,
          severity: severity,
          measuredValue:
              double.parse(sample.timeoutRate.toStringAsFixed(4)),
          threshold: severity == HealthSeverity.critical
              ? _Threshold.timeoutRateCriticalPct
              : _Threshold.timeoutRateWarningPct,
          description:
              '${sample.engine.name} timeout rate ${_fmt(sample.timeoutRate)}% '
              'indicates connectivity or processing delay.',
          detectedAt: now,
        ));
      }

      // Call volume spike.
      if (sample.callCount >= _Threshold.callVolumeWarning) {
        final severity = sample.callCount >= _Threshold.callVolumeCritical
            ? HealthSeverity.critical
            : HealthSeverity.medium;
        bottlenecks.add(Bottleneck(
          bottleneckId: _SHIdGen.next('bn'),
          engine: sample.engine,
          category: BottleneckCategory.callVolume,
          severity: severity,
          measuredValue: sample.callCount.toDouble(),
          threshold: severity == HealthSeverity.critical
              ? _Threshold.callVolumeCritical
              : _Threshold.callVolumeWarning,
          description:
              '${sample.engine.name} call volume ${sample.callCount} '
              'is elevated; potential fan-out or loop.',
          detectedAt: now,
        ));
      }

      // Memory pressure.
      if (sample.estimatedMemoryMb >= _Threshold.memoryWarningMb) {
        final severity =
            sample.estimatedMemoryMb >= _Threshold.memoryCriticalMb
                ? HealthSeverity.critical
                : HealthSeverity.medium;
        bottlenecks.add(Bottleneck(
          bottleneckId: _SHIdGen.next('bn'),
          engine: sample.engine,
          category: BottleneckCategory.memoryPressure,
          severity: severity,
          measuredValue: double.parse(
              sample.estimatedMemoryMb.toStringAsFixed(2)),
          threshold: severity == HealthSeverity.critical
              ? _Threshold.memoryCriticalMb
              : _Threshold.memoryWarningMb,
          description:
              '${sample.engine.name} estimated memory ${_fmt(sample.estimatedMemoryMb)}MB '
              'exceeds pressure threshold.',
          detectedAt: now,
        ));
      }

      // CPU load spike.
      if (sample.cpuLoadPercent >= _Threshold.cpuWarningPct) {
        final severity =
            sample.cpuLoadPercent >= _Threshold.cpuCriticalPct
                ? HealthSeverity.critical
                : HealthSeverity.high;
        bottlenecks.add(Bottleneck(
          bottleneckId: _SHIdGen.next('bn'),
          engine: sample.engine,
          category: BottleneckCategory.loadSpike,
          severity: severity,
          measuredValue: double.parse(
              sample.cpuLoadPercent.toStringAsFixed(2)),
          threshold: severity == HealthSeverity.critical
              ? _Threshold.cpuCriticalPct
              : _Threshold.cpuWarningPct,
          description:
              '${sample.engine.name} CPU load ${_fmt(sample.cpuLoadPercent)}% '
              'is causing processing pressure.',
          detectedAt: now,
        ));
      }
    }

    // Sort by severity descending.
    bottlenecks.sort((a, b) =>
        b.severity.index.compareTo(a.severity.index));

    return bottlenecks;
  }

  // ── calculateRiskScore ─────────────────────────────────────────

  double calculateRiskScore(
      Map<String, EngineHealthEntry> healthMap,
      List<Bottleneck> bottlenecks) {
    if (healthMap.isEmpty) return 0.0;

    double score = 0.0;
    final entries = healthMap.values.toList();

    // Per-engine base risk.
    for (final entry in entries) {
      double engineRisk = 0.0;

      if (!entry.isReachable) engineRisk += 30.0;

      switch (entry.status) {
        case HealthStatus.critical:
          engineRisk += 20.0;
          break;
        case HealthStatus.warning:
          engineRisk += 8.0;
          break;
        case HealthStatus.ok:
          break;
      }

      engineRisk +=
          (entry.errorRatePercent / _Threshold.errorRateCriticalPct * 15.0)
              .clamp(0.0, 15.0);
      engineRisk +=
          (entry.latencyMs / _Threshold.latencyCriticalMs * 10.0)
              .clamp(0.0, 10.0);
      engineRisk +=
          (entry.timeoutRatePercent / _Threshold.timeoutRateCriticalPct * 8.0)
              .clamp(0.0, 8.0);
      engineRisk +=
          (entry.cpuLoadPercent / _Threshold.cpuCriticalPct * 5.0)
              .clamp(0.0, 5.0);
      engineRisk +=
          (entry.estimatedMemoryMb / _Threshold.memoryCriticalMb * 5.0)
              .clamp(0.0, 5.0);

      score += engineRisk.clamp(0.0, 100.0);
    }

    final avgEngineRisk = score / entries.length;

    // Bottleneck modifier.
    double bottleneckBoost = 0.0;
    for (final bn in bottlenecks) {
      switch (bn.severity) {
        case HealthSeverity.critical:
          bottleneckBoost += 5.0;
          break;
        case HealthSeverity.high:
          bottleneckBoost += 3.0;
          break;
        case HealthSeverity.medium:
          bottleneckBoost += 1.5;
          break;
        case HealthSeverity.low:
          bottleneckBoost += 0.5;
          break;
      }
    }

    final raw = (avgEngineRisk + bottleneckBoost.clamp(0.0, 30.0))
        .clamp(0.0, 100.0);
    return double.parse(raw.toStringAsFixed(2));
  }

  // ── generateReport ─────────────────────────────────────────────

  SystemHealthReport generateReport({
    required String checkId,
    required Map<String, EngineHealthEntry> engineHealthMap,
    required List<Bottleneck> bottlenecks,
    required double riskScore,
    List<String> warnings = const [],
  }) {
    final stabilityIndex = _computeStabilityIndex(engineHealthMap);
    final overallStatus =
        _deriveOverallStatus(engineHealthMap, riskScore);
    final recommendations =
        _buildRecommendations(engineHealthMap, bottlenecks, overallStatus);
    final allWarnings = [
      ...warnings,
      ..._collectWarnings(engineHealthMap, bottlenecks, riskScore),
    ];

    final report = SystemHealthReport(
      reportId: _SHIdGen.next('rpt'),
      checkId: checkId,
      generatedAt: DateTime.now().toUtc(),
      overallStatus: overallStatus,
      engineHealthMap: Map.unmodifiable(engineHealthMap),
      bottlenecks: List.unmodifiable(bottlenecks),
      riskScore: riskScore,
      stabilityIndex: stabilityIndex,
      recommendations: List.unmodifiable(recommendations),
      warnings: allWarnings,
    );

    if (_reportHistory.length >= _maxHistorySize) {
      _reportHistory.removeAt(0);
    }
    _reportHistory.add(report);
    return report;
  }

  // ── Read accessors ─────────────────────────────────────────────

  List<SystemHealthReport> get reportHistory =>
      List.unmodifiable(_reportHistory);

  SystemHealthReport? get lastReport =>
      _reportHistory.isEmpty ? null : _reportHistory.last;

  int get totalReportsGenerated => _reportHistory.length;

  // ── Private helpers ───────────────────────────────────────────

  String? _validateRequest(HealthCheckRequest request) {
    if (request.checkId.trim().isEmpty) {
      return 'HealthCheckRequest.checkId must not be empty.';
    }
    if (request.scope == HealthCheckScope.single &&
        request.singleEngineTarget == null) {
      return 'scope=single requires singleEngineTarget to be set.';
    }
    return null;
  }

  List<EngineMetricSample> _applyScopeFilter(
      List<EngineMetricSample> samples,
      HealthCheckScope scope,
      MonitoredEngine? singleTarget) {
    const coreEngines = {
      MonitoredEngine.editorController,
      MonitoredEngine.layerEngine,
      MonitoredEngine.historyEngine,
      MonitoredEngine.renderEngine,
      MonitoredEngine.storageEngine,
      MonitoredEngine.aiEngine,
      MonitoredEngine.exportEngine,
      MonitoredEngine.templateEngine,
      MonitoredEngine.syncEngine,
    };
    const phase5Engines = {
      MonitoredEngine.automationEngine,
      MonitoredEngine.workflowEngine,
      MonitoredEngine.pluginEngine,
    };

    switch (scope) {
      case HealthCheckScope.all:
        return samples;
      case HealthCheckScope.coreOnly:
        return samples
            .where((s) => coreEngines.contains(s.engine))
            .toList();
      case HealthCheckScope.phase5Only:
        return samples
            .where((s) => phase5Engines.contains(s.engine))
            .toList();
      case HealthCheckScope.single:
        if (singleTarget == null) return [];
        return samples
            .where((s) => s.engine == singleTarget)
            .toList();
    }
  }

  HealthStatus _applyMinimumSeverity(
      HealthStatus detected, HealthSeverity minimumSeverity) {
    switch (minimumSeverity) {
      case HealthSeverity.critical:
        return detected == HealthStatus.critical
            ? HealthStatus.critical
            : HealthStatus.ok;
      case HealthSeverity.high:
        return detected;
      case HealthSeverity.medium:
        return detected;
      case HealthSeverity.low:
        return detected;
    }
  }

  double _scoreStability(EngineMetricSample sample) {
    if (!sample.isReachable) return 0.0;

    double score = 100.0;
    score -= (sample.errorRate / _Threshold.errorRateCriticalPct * 40.0)
        .clamp(0.0, 40.0);
    score -= (sample.avgLatencyMs / _Threshold.latencyCriticalMs * 25.0)
        .clamp(0.0, 25.0);
    score -= (sample.timeoutRate / _Threshold.timeoutRateCriticalPct * 20.0)
        .clamp(0.0, 20.0);
    score -= (sample.cpuLoadPercent / _Threshold.cpuCriticalPct * 10.0)
        .clamp(0.0, 10.0);
    score -= (sample.estimatedMemoryMb / _Threshold.memoryCriticalMb * 5.0)
        .clamp(0.0, 5.0);
    return score.clamp(0.0, 100.0);
  }

  double _computeStabilityIndex(
      Map<String, EngineHealthEntry> healthMap) {
    if (healthMap.isEmpty) return 100.0;
    final avg = healthMap.values
            .fold(0.0, (sum, e) => sum + e.stabilityScore) /
        healthMap.length;
    return double.parse(avg.toStringAsFixed(2));
  }

  HealthStatus _deriveOverallStatus(
      Map<String, EngineHealthEntry> healthMap, double riskScore) {
    final hasCritical =
        healthMap.values.any((e) => e.status == HealthStatus.critical);
    if (hasCritical || riskScore >= 70.0) return HealthStatus.critical;

    final hasWarning =
        healthMap.values.any((e) => e.status == HealthStatus.warning);
    if (hasWarning || riskScore >= 35.0) return HealthStatus.warning;

    return HealthStatus.ok;
  }

  List<HealthRecommendation> _buildRecommendations(
      Map<String, EngineHealthEntry> healthMap,
      List<Bottleneck> bottlenecks,
      HealthStatus overallStatus) {
    final recommendations = <HealthRecommendation>[];

    // Overall system recommendation.
    if (overallStatus == HealthStatus.critical) {
      recommendations.add(HealthRecommendation(
        recommendationId: _SHIdGen.next('rec'),
        urgency: HealthSeverity.critical,
        title: 'System in critical state',
        detail:
            'One or more engines are critically degraded. Investigate error '
            'rates, latency, and reachability before continuing. '
            'Core editor should still function — Phase-6 monitoring is '
            'observing only.',
      ));
    }

    // Per-engine recommendations.
    for (final entry in healthMap.values) {
      if (!entry.isReachable) {
        recommendations.add(HealthRecommendation(
          recommendationId: _SHIdGen.next('rec'),
          affectedEngine: entry.engine,
          urgency: HealthSeverity.critical,
          title: '${entry.engine.name} is unreachable',
          detail:
              'Review ${entry.engine.name} initialization and connection. '
              'Verify the engine is registered and started correctly.',
        ));
      }
      if (entry.errorRatePercent >= _Threshold.errorRateCriticalPct) {
        recommendations.add(HealthRecommendation(
          recommendationId: _SHIdGen.next('rec'),
          affectedEngine: entry.engine,
          urgency: HealthSeverity.critical,
          title: 'High error rate on ${entry.engine.name}',
          detail:
              'Error rate ${_fmt(entry.errorRatePercent)}% is critically high. '
              'Review input validation and edge-case handling in '
              '${entry.engine.name}.',
        ));
      } else if (entry.errorRatePercent >= _Threshold.errorRateWarningPct) {
        recommendations.add(HealthRecommendation(
          recommendationId: _SHIdGen.next('rec'),
          affectedEngine: entry.engine,
          urgency: HealthSeverity.medium,
          title: 'Elevated error rate on ${entry.engine.name}',
          detail:
              'Error rate ${_fmt(entry.errorRatePercent)}% is above the '
              '${_fmt(_Threshold.errorRateWarningPct)}% warning threshold. '
              'Monitor for further degradation.',
        ));
      }
      if (entry.latencyMs >= _Threshold.latencyCriticalMs) {
        recommendations.add(HealthRecommendation(
          recommendationId: _SHIdGen.next('rec'),
          affectedEngine: entry.engine,
          urgency: HealthSeverity.high,
          title: 'Critical latency on ${entry.engine.name}',
          detail:
              'Average latency ${_fmt(entry.latencyMs)}ms is above '
              '${_fmt(_Threshold.latencyCriticalMs)}ms. '
              'Profile ${entry.engine.name} for slow operations or '
              'blocking calls.',
        ));
      }
      if (entry.estimatedMemoryMb >= _Threshold.memoryCriticalMb) {
        recommendations.add(HealthRecommendation(
          recommendationId: _SHIdGen.next('rec'),
          affectedEngine: entry.engine,
          urgency: HealthSeverity.high,
          title: 'Memory pressure on ${entry.engine.name}',
          detail:
              'Estimated memory ${_fmt(entry.estimatedMemoryMb)}MB exceeds '
              '${_fmt(_Threshold.memoryCriticalMb)}MB. '
              'Check for unbounded caches or retained references.',
        ));
      }
    }

    // Bottleneck-specific recommendations.
    final criticalBottlenecks = bottlenecks
        .where((b) => b.severity == HealthSeverity.critical)
        .toList();
    if (criticalBottlenecks.length > 3) {
      recommendations.add(HealthRecommendation(
        recommendationId: _SHIdGen.next('rec'),
        urgency: HealthSeverity.critical,
        title: 'Multiple critical bottlenecks detected',
        detail:
            '${criticalBottlenecks.length} critical bottlenecks are active '
            'simultaneously. Prioritise resolving the highest-impact engines '
            'first: ${criticalBottlenecks.map((b) => b.engine.name).toSet().join(', ')}.',
      ));
    }

    // Sort: critical first.
    recommendations.sort(
        (a, b) => b.urgency.index.compareTo(a.urgency.index));

    return recommendations;
  }

  List<String> _collectWarnings(
      Map<String, EngineHealthEntry> healthMap,
      List<Bottleneck> bottlenecks,
      double riskScore) {
    final warnings = <String>[];

    if (riskScore >= 80.0) {
      warnings.add(
          'System risk score ${riskScore.toStringAsFixed(1)}/100 is '
          'critically high. Immediate investigation recommended.');
    } else if (riskScore >= 50.0) {
      warnings.add(
          'System risk score ${riskScore.toStringAsFixed(1)}/100 is '
          'elevated. Monitor closely.');
    }

    final unreachable =
        healthMap.values.where((e) => !e.isReachable).toList();
    if (unreachable.isNotEmpty) {
      warnings.add(
          '${unreachable.length} engine(s) unreachable: '
          '${unreachable.map((e) => e.engine.name).join(', ')}.');
    }

    if (bottlenecks.length > 10) {
      warnings.add(
          '${bottlenecks.length} bottlenecks detected — system may be '
          'under significant load.');
    }

    if (_reportHistory.length >= _maxHistorySize) {
      warnings.add('Report history is at capacity ($_maxHistorySize); '
          'oldest reports are being discarded.');
    }

    return warnings;
  }

  String _fmt(double value) => value.toStringAsFixed(2);
}
