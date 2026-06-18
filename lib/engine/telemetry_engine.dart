// ignore_for_file: avoid_catches_without_on_clauses

import 'dart:math';

// ── Event types ───────────────────────────────────────────────
enum TelemetryEventType {
  engineCall,
  featureUsed,
  commandEmitted,
  commandRejected,
  syncAttempt,
  exportStarted,
  exportCompleted,
  templateApplied,
  pluginExecuted,
  workflowStep,
  automationRun,
  errorNonFatal,
  sessionStart,
  sessionEnd,
  latencyRecorded,
  healthCheck,
}

// ── Source engines ────────────────────────────────────────────
enum TelemetrySourceEngine {
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
  unknown,
}

// ── TelemetryEvent — input contract ──────────────────────────
class TelemetryEvent {
  final String eventId;
  final TelemetryEventType eventType;
  final TelemetrySourceEngine sourceEngine;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  const TelemetryEvent({
    required this.eventId,
    required this.eventType,
    required this.sourceEngine,
    required this.timestamp,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() => {
        'eventId': eventId,
        'eventType': eventType.name,
        'sourceEngine': sourceEngine.name,
        'timestamp': timestamp.toIso8601String(),
        'metadata': metadata,
      };
}

// ── Latency sample ────────────────────────────────────────────
class LatencySample {
  final String operationId;
  final String operationLabel;
  final TelemetrySourceEngine sourceEngine;
  final Duration duration;
  final DateTime recordedAt;

  const LatencySample({
    required this.operationId,
    required this.operationLabel,
    required this.sourceEngine,
    required this.duration,
    required this.recordedAt,
  });
}

// ── Session record ─────────────────────────────────────────────
class TelemetrySession {
  final String sessionId;
  final DateTime startedAt;
  DateTime? endedAt;

  TelemetrySession({required this.sessionId, required this.startedAt});

  Duration? get duration =>
      endedAt == null ? null : endedAt!.difference(startedAt);

  bool get isActive => endedAt == null;
}

// ── Aggregated metrics ─────────────────────────────────────────
class AggregatedMetrics {
  final int totalEvents;
  final Map<String, int> eventCountByType;
  final Map<String, int> eventCountByEngine;
  final Map<String, double> avgLatencyMsByOperation;
  final Map<String, double> p95LatencyMsByOperation;
  final int errorCount;
  final double errorRate;

  const AggregatedMetrics({
    required this.totalEvents,
    required this.eventCountByType,
    required this.eventCountByEngine,
    required this.avgLatencyMsByOperation,
    required this.p95LatencyMsByOperation,
    required this.errorCount,
    required this.errorRate,
  });

  static AggregatedMetrics empty() => const AggregatedMetrics(
        totalEvents: 0,
        eventCountByType: {},
        eventCountByEngine: {},
        avgLatencyMsByOperation: {},
        p95LatencyMsByOperation: {},
        errorCount: 0,
        errorRate: 0.0,
      );

  Map<String, dynamic> toMap() => {
        'totalEvents': totalEvents,
        'eventCountByType': eventCountByType,
        'eventCountByEngine': eventCountByEngine,
        'avgLatencyMsByOperation': avgLatencyMsByOperation,
        'p95LatencyMsByOperation': p95LatencyMsByOperation,
        'errorCount': errorCount,
        'errorRate': errorRate,
      };
}

// ── Performance stats ─────────────────────────────────────────
class PerformanceStats {
  final double avgSessionDurationMs;
  final double totalObservationWindowMs;
  final int sampleCount;
  final double minLatencyMs;
  final double maxLatencyMs;
  final double medianLatencyMs;
  final Map<String, double> throughputByEngine;

  const PerformanceStats({
    required this.avgSessionDurationMs,
    required this.totalObservationWindowMs,
    required this.sampleCount,
    required this.minLatencyMs,
    required this.maxLatencyMs,
    required this.medianLatencyMs,
    required this.throughputByEngine,
  });

  static PerformanceStats empty() => const PerformanceStats(
        avgSessionDurationMs: 0.0,
        totalObservationWindowMs: 0.0,
        sampleCount: 0,
        minLatencyMs: 0.0,
        maxLatencyMs: 0.0,
        medianLatencyMs: 0.0,
        throughputByEngine: {},
      );

  Map<String, dynamic> toMap() => {
        'avgSessionDurationMs': avgSessionDurationMs,
        'totalObservationWindowMs': totalObservationWindowMs,
        'sampleCount': sampleCount,
        'minLatencyMs': minLatencyMs,
        'maxLatencyMs': maxLatencyMs,
        'medianLatencyMs': medianLatencyMs,
        'throughputByEngine': throughputByEngine,
      };
}

// ── Usage heatmap ─────────────────────────────────────────────
class UsageHeatmap {
  final Map<String, int> featureCallCount;
  final Map<String, int> engineCallCount;
  final Map<String, double> featureEngagementScore;
  final String? hottest;

  const UsageHeatmap({
    required this.featureCallCount,
    required this.engineCallCount,
    required this.featureEngagementScore,
    this.hottest,
  });

  static UsageHeatmap empty() => const UsageHeatmap(
        featureCallCount: {},
        engineCallCount: {},
        featureEngagementScore: {},
      );

  Map<String, dynamic> toMap() => {
        'featureCallCount': featureCallCount,
        'engineCallCount': engineCallCount,
        'featureEngagementScore': featureEngagementScore,
        'hottest': hottest,
      };
}

// ── TelemetryReport — output contract ────────────────────────
class TelemetryReport {
  final String reportId;
  final String sessionId;
  final DateTime generatedAt;
  final AggregatedMetrics aggregatedMetrics;
  final PerformanceStats performanceStats;
  final Map<String, double> errorRates;
  final UsageHeatmap usageHeatmap;
  final List<String> warnings;

  const TelemetryReport({
    required this.reportId,
    required this.sessionId,
    required this.generatedAt,
    required this.aggregatedMetrics,
    required this.performanceStats,
    required this.errorRates,
    required this.usageHeatmap,
    this.warnings = const [],
  });

  Map<String, dynamic> toMap() => {
        'reportId': reportId,
        'sessionId': sessionId,
        'generatedAt': generatedAt.toIso8601String(),
        'aggregatedMetrics': aggregatedMetrics.toMap(),
        'performanceStats': performanceStats.toMap(),
        'errorRates': errorRates,
        'usageHeatmap': usageHeatmap.toMap(),
        'warnings': warnings,
      };
}

// ── Event log result ──────────────────────────────────────────
class LogEventResult {
  final bool accepted;
  final String? rejectionReason;

  const LogEventResult.accepted() : accepted = true, rejectionReason = null;
  const LogEventResult.rejected(this.rejectionReason) : accepted = false;
}

// ── Session result ─────────────────────────────────────────────
class SessionResult {
  final bool success;
  final String sessionId;
  final String? error;

  const SessionResult.ok(this.sessionId) : success = true, error = null;
  const SessionResult.failure(this.sessionId, this.error) : success = false;
}

// ── Latency record result ──────────────────────────────────────
class LatencyResult {
  final bool accepted;
  final String? rejectionReason;

  const LatencyResult.accepted() : accepted = true, rejectionReason = null;
  const LatencyResult.rejected(this.rejectionReason) : accepted = false;
}

// ── ID generator ──────────────────────────────────────────────
class _TIdGen {
  static final Random _rng = Random.secure();

  static String next(String prefix) {
    final bytes = List<int>.generate(8, (_) => _rng.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '$prefix-$hex-${DateTime.now().microsecondsSinceEpoch}';
  }
}

// ── TelemetryEngine ───────────────────────────────────────────
class TelemetryEngine {
  static const int _maxEventBufferSize = 10000;
  static const int _maxLatencySamples = 5000;

  TelemetrySession? _activeSession;
  final List<TelemetryEvent> _eventBuffer = [];
  final List<LatencySample> _latencySamples = [];
  final List<TelemetrySession> _completedSessions = [];

  // ── startSession ───────────────────────────────────────────────

  SessionResult startSession() {
    try {
      if (_activeSession != null && _activeSession!.isActive) {
        final existing = _activeSession!.sessionId;
        return SessionResult.failure(
          existing,
          'A session "$existing" is already active. '
              'Call endSession() before starting a new one.',
        );
      }

      final sessionId = _TIdGen.next('sess');
      _activeSession = TelemetrySession(
        sessionId: sessionId,
        startedAt: DateTime.now().toUtc(),
      );

      _internalLog(TelemetryEventType.sessionStart, sessionId);
      return SessionResult.ok(sessionId);
    } catch (e) {
      return SessionResult.failure('', 'startSession failed: $e');
    }
  }

  // ── endSession ────────────────────────────────────────────────

  SessionResult endSession() {
    try {
      if (_activeSession == null || !_activeSession!.isActive) {
        return SessionResult.failure(
          '',
          'No active session to end.',
        );
      }

      _activeSession!.endedAt = DateTime.now().toUtc();
      _internalLog(TelemetryEventType.sessionEnd, _activeSession!.sessionId);
      _completedSessions.add(_activeSession!);
      final id = _activeSession!.sessionId;
      _activeSession = null;
      return SessionResult.ok(id);
    } catch (e) {
      return SessionResult.failure('', 'endSession failed: $e');
    }
  }

  // ── logEvent ──────────────────────────────────────────────────

  LogEventResult logEvent(TelemetryEvent event) {
    try {
      final validation = _validateEvent(event);
      if (validation != null) {
        return LogEventResult.rejected(validation);
      }

      if (_eventBuffer.length >= _maxEventBufferSize) {
        _eventBuffer.removeAt(0);
      }

      _eventBuffer.add(event);
      return const LogEventResult.accepted();
    } catch (e) {
      return LogEventResult.rejected('logEvent threw: $e');
    }
  }

  // ── recordLatency ──────────────────────────────────────────────

  LatencyResult recordLatency({
    required String operationLabel,
    required TelemetrySourceEngine sourceEngine,
    required Duration duration,
    String? operationId,
  }) {
    try {
      if (operationLabel.trim().isEmpty) {
        return const LatencyResult.rejected(
            'operationLabel must not be empty.');
      }
      if (duration.isNegative) {
        return const LatencyResult.rejected(
            'Duration must not be negative.');
      }

      if (_latencySamples.length >= _maxLatencySamples) {
        _latencySamples.removeAt(0);
      }

      _latencySamples.add(LatencySample(
        operationId: operationId ?? _TIdGen.next('lat'),
        operationLabel: operationLabel,
        sourceEngine: sourceEngine,
        duration: duration,
        recordedAt: DateTime.now().toUtc(),
      ));

      return const LatencyResult.accepted();
    } catch (e) {
      return LatencyResult.rejected('recordLatency threw: $e');
    }
  }

  // ── aggregateMetrics ──────────────────────────────────────────

  AggregatedMetrics aggregateMetrics() {
    try {
      if (_eventBuffer.isEmpty) return AggregatedMetrics.empty();

      final countByType = <String, int>{};
      final countByEngine = <String, int>{};
      int errorCount = 0;

      for (final event in _eventBuffer) {
        final typeKey = event.eventType.name;
        countByType[typeKey] = (countByType[typeKey] ?? 0) + 1;

        final engineKey = event.sourceEngine.name;
        countByEngine[engineKey] = (countByEngine[engineKey] ?? 0) + 1;

        if (event.eventType == TelemetryEventType.errorNonFatal) {
          errorCount++;
        }
      }

      final avgLatency = _computeAvgLatencyByOperation();
      final p95Latency = _computeP95LatencyByOperation();
      final total = _eventBuffer.length;
      final errorRate =
          total > 0 ? (errorCount / total * 100.0) : 0.0;

      return AggregatedMetrics(
        totalEvents: total,
        eventCountByType: Map.unmodifiable(countByType),
        eventCountByEngine: Map.unmodifiable(countByEngine),
        avgLatencyMsByOperation: Map.unmodifiable(avgLatency),
        p95LatencyMsByOperation: Map.unmodifiable(p95Latency),
        errorCount: errorCount,
        errorRate: double.parse(errorRate.toStringAsFixed(4)),
      );
    } catch (_) {
      return AggregatedMetrics.empty();
    }
  }

  // ── generateReport ────────────────────────────────────────────

  TelemetryReport generateReport() {
    try {
      final sessionId = _activeSession?.sessionId ??
          (_completedSessions.isNotEmpty
              ? _completedSessions.last.sessionId
              : 'no-session');

      final metrics = aggregateMetrics();
      final performance = _computePerformanceStats();
      final errorRates = _computeErrorRates(metrics);
      final heatmap = _computeUsageHeatmap(metrics);
      final warnings = _collectWarnings(metrics, performance);

      return TelemetryReport(
        reportId: _TIdGen.next('rpt'),
        sessionId: sessionId,
        generatedAt: DateTime.now().toUtc(),
        aggregatedMetrics: metrics,
        performanceStats: performance,
        errorRates: errorRates,
        usageHeatmap: heatmap,
        warnings: warnings,
      );
    } catch (e) {
      return TelemetryReport(
        reportId: _TIdGen.next('rpt-err'),
        sessionId: 'error',
        generatedAt: DateTime.now().toUtc(),
        aggregatedMetrics: AggregatedMetrics.empty(),
        performanceStats: PerformanceStats.empty(),
        errorRates: const {},
        usageHeatmap: UsageHeatmap.empty(),
        warnings: ['generateReport threw: $e'],
      );
    }
  }

  // ── Read accessors (non-mutating) ─────────────────────────────

  bool get hasActiveSession => _activeSession != null && _activeSession!.isActive;
  String? get activeSessionId => _activeSession?.sessionId;
  int get bufferedEventCount => _eventBuffer.length;
  int get latencySampleCount => _latencySamples.length;
  int get completedSessionCount => _completedSessions.length;

  List<TelemetryEvent> eventsForEngine(TelemetrySourceEngine engine) =>
      _eventBuffer.where((e) => e.sourceEngine == engine).toList();

  List<TelemetryEvent> eventsOfType(TelemetryEventType type) =>
      _eventBuffer.where((e) => e.eventType == type).toList();

  // ── Private helpers ───────────────────────────────────────────

  String? _validateEvent(TelemetryEvent event) {
    if (event.eventId.trim().isEmpty) {
      return 'TelemetryEvent.eventId must not be empty.';
    }
    const forbiddenMetaKeys = [
      'layerengine', 'historyengine', 'renderengine',
      'storageengine', 'buildcontext', 'canvas', 'widget',
    ];
    for (final key in event.metadata.keys) {
      if (forbiddenMetaKeys.contains(key.toLowerCase())) {
        return 'TelemetryEvent.metadata key "$key" references a '
            'forbidden engine or context object.';
      }
    }
    return null;
  }

  void _internalLog(TelemetryEventType type, String sessionId) {
    if (_eventBuffer.length >= _maxEventBufferSize) {
      _eventBuffer.removeAt(0);
    }
    _eventBuffer.add(TelemetryEvent(
      eventId: _TIdGen.next('int-evt'),
      eventType: type,
      sourceEngine: TelemetrySourceEngine.editorController,
      timestamp: DateTime.now().toUtc(),
      metadata: {'sessionId': sessionId},
    ));
  }

  Map<String, double> _computeAvgLatencyByOperation() {
    if (_latencySamples.isEmpty) return {};
    final groups = <String, List<double>>{};
    for (final sample in _latencySamples) {
      groups.putIfAbsent(sample.operationLabel, () => []);
      groups[sample.operationLabel]!
          .add(sample.duration.inMicroseconds / 1000.0);
    }
    return groups.map((k, v) {
      final avg = v.fold(0.0, (sum, x) => sum + x) / v.length;
      return MapEntry(k, double.parse(avg.toStringAsFixed(3)));
    });
  }

  Map<String, double> _computeP95LatencyByOperation() {
    if (_latencySamples.isEmpty) return {};
    final groups = <String, List<double>>{};
    for (final sample in _latencySamples) {
      groups.putIfAbsent(sample.operationLabel, () => []);
      groups[sample.operationLabel]!
          .add(sample.duration.inMicroseconds / 1000.0);
    }
    return groups.map((k, v) {
      final sorted = List<double>.from(v)..sort();
      final idx = ((sorted.length * 0.95).ceil() - 1).clamp(0, sorted.length - 1);
      return MapEntry(k, double.parse(sorted[idx].toStringAsFixed(3)));
    });
  }

  PerformanceStats _computePerformanceStats() {
    if (_latencySamples.isEmpty && _completedSessions.isEmpty) {
      return PerformanceStats.empty();
    }

    double avgSessionMs = 0.0;
    if (_completedSessions.isNotEmpty) {
      final totalMs = _completedSessions
          .where((s) => s.duration != null)
          .fold(0.0, (sum, s) => sum + s.duration!.inMicroseconds / 1000.0);
      avgSessionMs = totalMs / _completedSessions.length;
    }

    double windowMs = 0.0;
    if (_eventBuffer.isNotEmpty) {
      final oldest = _eventBuffer.first.timestamp;
      final newest = _eventBuffer.last.timestamp;
      windowMs = newest.difference(oldest).inMicroseconds / 1000.0;
    }

    final allMs = _latencySamples
        .map((s) => s.duration.inMicroseconds / 1000.0)
        .toList();

    double minMs = 0.0, maxMs = 0.0, medianMs = 0.0;
    if (allMs.isNotEmpty) {
      final sorted = List<double>.from(allMs)..sort();
      minMs = sorted.first;
      maxMs = sorted.last;
      final mid = sorted.length ~/ 2;
      medianMs = sorted.length.isOdd
          ? sorted[mid]
          : (sorted[mid - 1] + sorted[mid]) / 2.0;
    }

    final throughput = <String, double>{};
    if (windowMs > 0) {
      final countByEngine = <String, int>{};
      for (final s in _latencySamples) {
        final k = s.sourceEngine.name;
        countByEngine[k] = (countByEngine[k] ?? 0) + 1;
      }
      for (final entry in countByEngine.entries) {
        throughput[entry.key] = double.parse(
            (entry.value / (windowMs / 1000.0)).toStringAsFixed(3));
      }
    }

    return PerformanceStats(
      avgSessionDurationMs: double.parse(avgSessionMs.toStringAsFixed(3)),
      totalObservationWindowMs: double.parse(windowMs.toStringAsFixed(3)),
      sampleCount: _latencySamples.length,
      minLatencyMs: double.parse(minMs.toStringAsFixed(3)),
      maxLatencyMs: double.parse(maxMs.toStringAsFixed(3)),
      medianLatencyMs: double.parse(medianMs.toStringAsFixed(3)),
      throughputByEngine: Map.unmodifiable(throughput),
    );
  }

  Map<String, double> _computeErrorRates(AggregatedMetrics metrics) {
    final result = <String, double>{};
    final total = metrics.totalEvents;
    if (total == 0) return result;

    for (final entry in metrics.eventCountByEngine.entries) {
      final engineEvents = entry.value;
      final engineErrors = _eventBuffer
          .where((e) =>
              e.sourceEngine.name == entry.key &&
              e.eventType == TelemetryEventType.errorNonFatal)
          .length;
      if (engineErrors > 0) {
        final rate = engineErrors / engineEvents * 100.0;
        result[entry.key] = double.parse(rate.toStringAsFixed(4));
      }
    }

    return Map.unmodifiable(result);
  }

  UsageHeatmap _computeUsageHeatmap(AggregatedMetrics metrics) {
    if (_eventBuffer.isEmpty) return UsageHeatmap.empty();

    final featureCount = <String, int>{};
    for (final event in _eventBuffer) {
      if (event.eventType == TelemetryEventType.featureUsed) {
        final feature = (event.metadata['feature'] as String?) ??
            event.eventType.name;
        featureCount[feature] = (featureCount[feature] ?? 0) + 1;
      }
    }

    final engineCount = Map<String, int>.from(metrics.eventCountByEngine);

    final total = _eventBuffer.length;
    final engagementScore = <String, double>{};
    for (final entry in featureCount.entries) {
      final score = total > 0 ? entry.value / total * 100.0 : 0.0;
      engagementScore[entry.key] =
          double.parse(score.toStringAsFixed(4));
    }

    String? hottest;
    if (featureCount.isNotEmpty) {
      hottest = featureCount.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
    } else if (engineCount.isNotEmpty) {
      hottest = engineCount.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
    }

    return UsageHeatmap(
      featureCallCount: Map.unmodifiable(featureCount),
      engineCallCount: Map.unmodifiable(engineCount),
      featureEngagementScore: Map.unmodifiable(engagementScore),
      hottest: hottest,
    );
  }

  List<String> _collectWarnings(
      AggregatedMetrics metrics, PerformanceStats performance) {
    final warnings = <String>[];

    if (metrics.errorRate > 10.0) {
      warnings.add(
          'High non-fatal error rate: ${metrics.errorRate.toStringAsFixed(2)}%. '
          'Investigate error sources.');
    }
    if (performance.maxLatencyMs > 2000.0) {
      warnings.add(
          'Peak latency ${performance.maxLatencyMs.toStringAsFixed(1)}ms '
          'exceeds 2000ms threshold.');
    }
    if (_eventBuffer.length >= _maxEventBufferSize) {
      warnings.add(
          'Event buffer is at capacity ($_maxEventBufferSize). '
          'Oldest events are being dropped.');
    }
    if (_latencySamples.length >= _maxLatencySamples) {
      warnings.add(
          'Latency sample buffer is at capacity ($_maxLatencySamples). '
          'Oldest samples are being dropped.');
    }
    if (!hasActiveSession) {
      warnings.add('No active session; events are being logged '
          'outside a session boundary.');
    }

    return warnings;
  }
}
