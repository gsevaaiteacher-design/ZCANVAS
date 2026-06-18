// ignore_for_file: avoid_catches_without_on_clauses

import 'dart:convert';
import 'dart:math';

// ── Trace origin ──────────────────────────────────────────────
enum TraceOrigin {
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
  user,
  system,
  unknown,
}

// ── Step outcome ──────────────────────────────────────────────
enum StepOutcome { success, failure, skipped, timeout, warning }

// ── Trace status ──────────────────────────────────────────────
enum TraceStatus { open, finalized, exported, abandoned }

// ── Severity ──────────────────────────────────────────────────
enum TraceSeverity { debug, info, warning, error, critical }

// ── DebugTraceRequest — input contract ───────────────────────
class DebugTraceRequest {
  final String traceId;
  final TraceOrigin origin;
  final String actionType;
  final Map<String, dynamic> contextSnapshot;

  const DebugTraceRequest({
    required this.traceId,
    required this.origin,
    required this.actionType,
    required this.contextSnapshot,
  });
}

// ── Execution step ────────────────────────────────────────────
class ExecutionStep {
  final String stepId;
  final String traceId;
  final int sequenceIndex;
  final String label;
  final TraceOrigin origin;
  final String actionType;
  final StepOutcome outcome;
  final DateTime timestamp;
  final Duration? duration;
  final Map<String, dynamic> inputSnapshot;
  final Map<String, dynamic> outputSnapshot;
  final String? errorMessage;
  final List<String> tags;

  const ExecutionStep({
    required this.stepId,
    required this.traceId,
    required this.sequenceIndex,
    required this.label,
    required this.origin,
    required this.actionType,
    required this.outcome,
    required this.timestamp,
    this.duration,
    this.inputSnapshot = const {},
    this.outputSnapshot = const {},
    this.errorMessage,
    this.tags = const [],
  });

  bool get isFailure =>
      outcome == StepOutcome.failure || outcome == StepOutcome.timeout;

  Map<String, dynamic> toMap() => {
        'stepId': stepId,
        'traceId': traceId,
        'sequenceIndex': sequenceIndex,
        'label': label,
        'origin': origin.name,
        'actionType': actionType,
        'outcome': outcome.name,
        'timestamp': timestamp.toIso8601String(),
        'durationMs': duration?.inMicroseconds != null
            ? duration!.inMicroseconds / 1000.0
            : null,
        'inputSnapshot': inputSnapshot,
        'outputSnapshot': outputSnapshot,
        'errorMessage': errorMessage,
        'tags': tags,
      };
}

// ── Error node — reconstructed failure point ──────────────────
class ErrorNode {
  final String nodeId;
  final String traceId;
  final String stepId;
  final TraceOrigin origin;
  final String actionType;
  final String errorMessage;
  final TraceSeverity severity;
  final DateTime detectedAt;
  final List<String> affectedStepIds;

  const ErrorNode({
    required this.nodeId,
    required this.traceId,
    required this.stepId,
    required this.origin,
    required this.actionType,
    required this.errorMessage,
    required this.severity,
    required this.detectedAt,
    this.affectedStepIds = const [],
  });

  Map<String, dynamic> toMap() => {
        'nodeId': nodeId,
        'traceId': traceId,
        'stepId': stepId,
        'origin': origin.name,
        'actionType': actionType,
        'errorMessage': errorMessage,
        'severity': severity.name,
        'detectedAt': detectedAt.toIso8601String(),
        'affectedStepIds': affectedStepIds,
      };
}

// ── Context snapshot capture ──────────────────────────────────
class SnapshotCapture {
  final String snapshotId;
  final String traceId;
  final String label;
  final DateTime capturedAt;
  final Map<String, dynamic> data;
  final int stepSequenceAtCapture;

  const SnapshotCapture({
    required this.snapshotId,
    required this.traceId,
    required this.label,
    required this.capturedAt,
    required this.data,
    required this.stepSequenceAtCapture,
  });

  Map<String, dynamic> toMap() => {
        'snapshotId': snapshotId,
        'traceId': traceId,
        'label': label,
        'capturedAt': capturedAt.toIso8601String(),
        'data': data,
        'stepSequenceAtCapture': stepSequenceAtCapture,
      };
}

// ── Open trace context ─────────────────────────────────────────
class _ActiveTrace {
  final String traceId;
  final TraceOrigin origin;
  final String actionType;
  final DateTime openedAt;
  final List<ExecutionStep> steps = [];
  final List<SnapshotCapture> snapshots = [];
  TraceStatus status = TraceStatus.open;

  _ActiveTrace({
    required this.traceId,
    required this.origin,
    required this.actionType,
    required this.openedAt,
  });

  int get nextSequenceIndex => steps.length;
}

// ── DebugTraceResult — output contract ────────────────────────
class DebugTraceResult {
  final String traceId;
  final TraceOrigin origin;
  final String actionType;
  final List<ExecutionStep> executionSteps;
  final List<DateTime> timestamps;
  final bool overallSuccess;
  final List<ErrorNode> errorNodes;
  final List<SnapshotCapture> snapshots;
  final Duration? totalDuration;
  final TraceStatus status;
  final Map<String, dynamic> callHierarchy;

  const DebugTraceResult({
    required this.traceId,
    required this.origin,
    required this.actionType,
    required this.executionSteps,
    required this.timestamps,
    required this.overallSuccess,
    required this.errorNodes,
    required this.snapshots,
    this.totalDuration,
    required this.status,
    required this.callHierarchy,
  });

  Map<String, dynamic> toMap() => {
        'traceId': traceId,
        'origin': origin.name,
        'actionType': actionType,
        'executionSteps': executionSteps.map((s) => s.toMap()).toList(),
        'timestamps':
            timestamps.map((t) => t.toIso8601String()).toList(),
        'overallSuccess': overallSuccess,
        'errorNodes': errorNodes.map((e) => e.toMap()).toList(),
        'snapshots': snapshots.map((s) => s.toMap()).toList(),
        'totalDurationMs': totalDuration?.inMicroseconds != null
            ? totalDuration!.inMicroseconds / 1000.0
            : null,
        'status': status.name,
        'callHierarchy': callHierarchy,
      };
}

// ── Record step input ─────────────────────────────────────────
class StepRecord {
  final String label;
  final TraceOrigin origin;
  final String actionType;
  final StepOutcome outcome;
  final Duration? duration;
  final Map<String, dynamic> inputSnapshot;
  final Map<String, dynamic> outputSnapshot;
  final String? errorMessage;
  final List<String> tags;

  const StepRecord({
    required this.label,
    required this.origin,
    required this.actionType,
    required this.outcome,
    this.duration,
    this.inputSnapshot = const {},
    this.outputSnapshot = const {},
    this.errorMessage,
    this.tags = const [],
  });
}

// ── Operation results ─────────────────────────────────────────
class TraceOperationResult {
  final bool success;
  final String? error;

  const TraceOperationResult.ok() : success = true, error = null;
  const TraceOperationResult.failure(this.error) : success = false;
}

class ExportResult {
  final bool success;
  final String traceId;
  final String format;
  final String payload;
  final int byteSize;
  final DateTime exportedAt;
  final String? error;

  const ExportResult._({
    required this.success,
    required this.traceId,
    required this.format,
    required this.payload,
    required this.byteSize,
    required this.exportedAt,
    this.error,
  });

  factory ExportResult.ok({
    required String traceId,
    required String format,
    required String payload,
  }) =>
      ExportResult._(
        success: true,
        traceId: traceId,
        format: format,
        payload: payload,
        byteSize: payload.length,
        exportedAt: DateTime.now().toUtc(),
      );

  factory ExportResult.failure(String traceId, String error) =>
      ExportResult._(
        success: false,
        traceId: traceId,
        format: 'none',
        payload: '',
        byteSize: 0,
        exportedAt: DateTime.now().toUtc(),
        error: error,
      );
}

// ── ID generator ──────────────────────────────────────────────
class _DIdGen {
  static final Random _rng = Random.secure();

  static String next(String prefix) {
    final bytes = List<int>.generate(8, (_) => _rng.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '$prefix-$hex-${DateTime.now().microsecondsSinceEpoch}';
  }
}

// ── Allowed export formats ────────────────────────────────────
const Set<String> _kExportFormats = {'json', 'text'};

// ── DebugTraceEngine ──────────────────────────────────────────
class DebugTraceEngine {
  static const int _maxOpenTraces = 100;
  static const int _maxFinalizedTraces = 500;
  static const int _maxStepsPerTrace = 1000;
  static const int _maxSnapshotsPerTrace = 200;

  final Map<String, _ActiveTrace> _openTraces = {};
  final Map<String, DebugTraceResult> _finalizedTraces = {};

  // ── startTrace ────────────────────────────────────────────────

  TraceOperationResult startTrace(DebugTraceRequest request) {
    try {
      final validation = _validateRequest(request);
      if (validation != null) {
        return TraceOperationResult.failure(validation);
      }

      if (_openTraces.containsKey(request.traceId)) {
        return TraceOperationResult.failure(
            'Trace "${request.traceId}" is already open.');
      }

      if (_finalizedTraces.containsKey(request.traceId)) {
        return TraceOperationResult.failure(
            'Trace "${request.traceId}" was already finalized.');
      }

      if (_openTraces.length >= _maxOpenTraces) {
        final oldest = _openTraces.keys.first;
        _openTraces[oldest]!.status = TraceStatus.abandoned;
        _openTraces.remove(oldest);
      }

      final trace = _ActiveTrace(
        traceId: request.traceId,
        origin: request.origin,
        actionType: request.actionType,
        openedAt: DateTime.now().toUtc(),
      );

      // Capture the initial context as first snapshot.
      if (request.contextSnapshot.isNotEmpty) {
        final safe = _sanitiseSnapshot(request.contextSnapshot);
        trace.snapshots.add(SnapshotCapture(
          snapshotId: _DIdGen.next('snap'),
          traceId: request.traceId,
          label: 'initial_context',
          capturedAt: trace.openedAt,
          data: safe,
          stepSequenceAtCapture: 0,
        ));
      }

      _openTraces[request.traceId] = trace;
      return const TraceOperationResult.ok();
    } catch (e) {
      return TraceOperationResult.failure('startTrace threw: $e');
    }
  }

  // ── recordStep ────────────────────────────────────────────────

  TraceOperationResult recordStep(String traceId, StepRecord record) {
    try {
      final trace = _openTraces[traceId];
      if (trace == null) {
        return TraceOperationResult.failure(
            'No open trace found for "$traceId". '
            'Call startTrace() first.');
      }
      if (trace.status != TraceStatus.open) {
        return TraceOperationResult.failure(
            'Trace "$traceId" is ${trace.status.name}; '
            'cannot record additional steps.');
      }
      if (record.label.trim().isEmpty) {
        return const TraceOperationResult.failure(
            'StepRecord.label must not be empty.');
      }
      if (record.actionType.trim().isEmpty) {
        return const TraceOperationResult.failure(
            'StepRecord.actionType must not be empty.');
      }
      if (trace.steps.length >= _maxStepsPerTrace) {
        return TraceOperationResult.failure(
            'Trace "$traceId" has reached the step limit '
            '($_maxStepsPerTrace).');
      }

      final step = ExecutionStep(
        stepId: _DIdGen.next('step'),
        traceId: traceId,
        sequenceIndex: trace.nextSequenceIndex,
        label: record.label,
        origin: record.origin,
        actionType: record.actionType,
        outcome: record.outcome,
        timestamp: DateTime.now().toUtc(),
        duration: record.duration,
        inputSnapshot: Map.unmodifiable(
            _sanitiseSnapshot(record.inputSnapshot)),
        outputSnapshot: Map.unmodifiable(
            _sanitiseSnapshot(record.outputSnapshot)),
        errorMessage: record.errorMessage,
        tags: List.unmodifiable(record.tags),
      );

      trace.steps.add(step);
      return const TraceOperationResult.ok();
    } catch (e) {
      return TraceOperationResult.failure('recordStep threw: $e');
    }
  }

  // ── captureSnapshot ───────────────────────────────────────────

  TraceOperationResult captureSnapshot(
      String traceId, String label, Map<String, dynamic> data) {
    try {
      final trace = _openTraces[traceId];
      if (trace == null) {
        return TraceOperationResult.failure(
            'No open trace "$traceId" for snapshot.');
      }
      if (trace.status != TraceStatus.open) {
        return TraceOperationResult.failure(
            'Trace "$traceId" is ${trace.status.name}; '
            'cannot capture snapshot.');
      }
      if (label.trim().isEmpty) {
        return const TraceOperationResult.failure(
            'Snapshot label must not be empty.');
      }
      if (trace.snapshots.length >= _maxSnapshotsPerTrace) {
        return TraceOperationResult.failure(
            'Trace "$traceId" has reached the snapshot limit '
            '($_maxSnapshotsPerTrace).');
      }

      final safe = _sanitiseSnapshot(data);
      trace.snapshots.add(SnapshotCapture(
        snapshotId: _DIdGen.next('snap'),
        traceId: traceId,
        label: label,
        capturedAt: DateTime.now().toUtc(),
        data: Map.unmodifiable(safe),
        stepSequenceAtCapture: trace.nextSequenceIndex,
      ));

      return const TraceOperationResult.ok();
    } catch (e) {
      return TraceOperationResult.failure('captureSnapshot threw: $e');
    }
  }

  // ── finalizeTrace ──────────────────────────────────────────────

  DebugTraceResult? finalizeTrace(String traceId) {
    try {
      final trace = _openTraces[traceId];
      if (trace == null) return null;

      trace.status = TraceStatus.finalized;
      _openTraces.remove(traceId);

      final errorNodes = _buildErrorNodes(trace);
      final timestamps =
          trace.steps.map((s) => s.timestamp).toList(growable: false);

      final overallSuccess =
          trace.steps.every((s) => !s.isFailure);

      Duration? totalDuration;
      if (trace.steps.isNotEmpty) {
        final first = trace.steps.first.timestamp;
        final last = trace.steps.last.timestamp;
        totalDuration = last.difference(first);
      }

      final result = DebugTraceResult(
        traceId: traceId,
        origin: trace.origin,
        actionType: trace.actionType,
        executionSteps: List.unmodifiable(trace.steps),
        timestamps: List.unmodifiable(timestamps),
        overallSuccess: overallSuccess,
        errorNodes: List.unmodifiable(errorNodes),
        snapshots: List.unmodifiable(trace.snapshots),
        totalDuration: totalDuration,
        status: TraceStatus.finalized,
        callHierarchy:
            Map.unmodifiable(_buildCallHierarchy(trace)),
      );

      if (_finalizedTraces.length >= _maxFinalizedTraces) {
        _finalizedTraces.remove(_finalizedTraces.keys.first);
      }
      _finalizedTraces[traceId] = result;
      return result;
    } catch (_) {
      return null;
    }
  }

  // ── exportTrace ───────────────────────────────────────────────

  ExportResult exportTrace(String traceId,
      {String format = 'json'}) {
    try {
      if (!_kExportFormats.contains(format.toLowerCase())) {
        return ExportResult.failure(traceId,
            'Unsupported export format "$format". '
            'Supported: ${_kExportFormats.join(', ')}.');
      }

      DebugTraceResult? result = _finalizedTraces[traceId];

      if (result == null) {
        final open = _openTraces[traceId];
        if (open != null) {
          result = finalizeTrace(traceId);
        }
      }

      if (result == null) {
        return ExportResult.failure(traceId,
            'Trace "$traceId" not found in open or finalized traces.');
      }

      final payload = format.toLowerCase() == 'json'
          ? _toJson(result)
          : _toText(result);

      return ExportResult.ok(
        traceId: traceId,
        format: format.toLowerCase(),
        payload: payload,
      );
    } catch (e) {
      return ExportResult.failure(traceId, 'exportTrace threw: $e');
    }
  }

  // ── Read accessors (non-mutating) ─────────────────────────────

  bool isTraceOpen(String traceId) => _openTraces.containsKey(traceId);
  bool isTraceFinalized(String traceId) =>
      _finalizedTraces.containsKey(traceId);

  int get openTraceCount => _openTraces.length;
  int get finalizedTraceCount => _finalizedTraces.length;

  DebugTraceResult? getResult(String traceId) =>
      _finalizedTraces[traceId];

  List<String> get openTraceIds =>
      List.unmodifiable(_openTraces.keys);

  List<ExecutionStep> stepsForTrace(String traceId) {
    final open = _openTraces[traceId];
    if (open != null) return List.unmodifiable(open.steps);
    return _finalizedTraces[traceId]?.executionSteps ?? const [];
  }

  List<SnapshotCapture> snapshotsForTrace(String traceId) {
    final open = _openTraces[traceId];
    if (open != null) return List.unmodifiable(open.snapshots);
    return _finalizedTraces[traceId]?.snapshots ?? const [];
  }

  // ── Private helpers ───────────────────────────────────────────

  String? _validateRequest(DebugTraceRequest request) {
    if (request.traceId.trim().isEmpty) {
      return 'DebugTraceRequest.traceId must not be empty.';
    }
    if (request.actionType.trim().isEmpty) {
      return 'DebugTraceRequest.actionType must not be empty.';
    }
    const forbiddenKeys = {
      'layerengine', 'historyengine', 'renderengine',
      'storageengine', 'buildcontext', 'canvas', 'widget',
    };
    for (final key in request.contextSnapshot.keys) {
      if (forbiddenKeys.contains(key.toLowerCase())) {
        return 'DebugTraceRequest.contextSnapshot key "$key" references '
            'a forbidden engine or context object.';
      }
    }
    return null;
  }

  Map<String, dynamic> _sanitiseSnapshot(Map<String, dynamic> raw) {
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

  List<ErrorNode> _buildErrorNodes(_ActiveTrace trace) {
    final nodes = <ErrorNode>[];
    for (final step in trace.steps) {
      if (!step.isFailure) continue;

      // Determine which subsequent steps may have been affected.
      final affected = trace.steps
          .where((s) =>
              s.sequenceIndex > step.sequenceIndex &&
              s.origin == step.origin)
          .map((s) => s.stepId)
          .toList();

      final severity = step.outcome == StepOutcome.timeout
          ? TraceSeverity.error
          : TraceSeverity.critical;

      nodes.add(ErrorNode(
        nodeId: _DIdGen.next('err'),
        traceId: trace.traceId,
        stepId: step.stepId,
        origin: step.origin,
        actionType: step.actionType,
        errorMessage: step.errorMessage ??
            'Step failed with outcome: ${step.outcome.name}',
        severity: severity,
        detectedAt: step.timestamp,
        affectedStepIds: List.unmodifiable(affected),
      ));
    }
    return nodes;
  }

  Map<String, dynamic> _buildCallHierarchy(_ActiveTrace trace) {
    // Group steps by origin engine to reconstruct the interaction timeline.
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final step in trace.steps) {
      final key = step.origin.name;
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add({
        'stepId': step.stepId,
        'sequenceIndex': step.sequenceIndex,
        'actionType': step.actionType,
        'outcome': step.outcome.name,
        'timestamp': step.timestamp.toIso8601String(),
      });
    }

    return {
      'traceId': trace.traceId,
      'rootOrigin': trace.origin.name,
      'rootAction': trace.actionType,
      'engineCallSequence': trace.steps
          .map((s) => s.origin.name)
          .toList(growable: false),
      'byEngine': grouped,
      'stepCount': trace.steps.length,
    };
  }

  String _toJson(DebugTraceResult result) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(result.toMap());
  }

  String _toText(DebugTraceResult result) {
    final buf = StringBuffer();
    buf.writeln('=== DEBUG TRACE REPORT ===');
    buf.writeln('traceId    : ${result.traceId}');
    buf.writeln('origin     : ${result.origin.name}');
    buf.writeln('action     : ${result.actionType}');
    buf.writeln('status     : ${result.status.name}');
    buf.writeln('success    : ${result.overallSuccess}');
    buf.writeln('steps      : ${result.executionSteps.length}');
    buf.writeln('errors     : ${result.errorNodes.length}');
    buf.writeln('snapshots  : ${result.snapshots.length}');
    if (result.totalDuration != null) {
      buf.writeln(
          'duration   : ${(result.totalDuration!.inMicroseconds / 1000.0).toStringAsFixed(3)}ms');
    }
    buf.writeln('');
    buf.writeln('--- STEPS ---');
    for (final step in result.executionSteps) {
      buf.writeln('[${step.sequenceIndex}] ${step.label} '
          '(${step.origin.name}) → ${step.outcome.name}');
      if (step.errorMessage != null) {
        buf.writeln('    ⚠ ${step.errorMessage}');
      }
    }
    if (result.errorNodes.isNotEmpty) {
      buf.writeln('');
      buf.writeln('--- ERROR NODES ---');
      for (final node in result.errorNodes) {
        buf.writeln('[${node.severity.name.toUpperCase()}] '
            '${node.origin.name}::${node.actionType}');
        buf.writeln('  ${node.errorMessage}');
        if (node.affectedStepIds.isNotEmpty) {
          buf.writeln('  affected: ${node.affectedStepIds.join(', ')}');
        }
      }
    }
    buf.writeln('=== END OF TRACE ===');
    return buf.toString();
  }
}
