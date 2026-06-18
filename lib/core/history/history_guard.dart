// ==================================================
// Z-CANVAS — PHASE-15 HISTORY, SNAPSHOT & RECOVERY
// core/history/history_guard.dart
//
// PRIMARY ROLE: HISTORY PROTECTION LAYER
//
// OWNS:
//   ✔ History entry validation (structure + chain integrity)
//   ✔ Snapshot chain validation (before/after linkage consistency)
//   ✔ Corruption detection (gap, cycle, orphan, status conflict)
//   ✔ Recovery path validation (can a specific snapshot safely be restored)
//   ✔ History limit enforcement (stack depth gates)
//   ✔ Undo integrity verification (target entry is safe to undo)
//   ✔ Redo integrity verification (target entry is safe to redo)
//   ✔ Integrity report generation (full system health snapshot)
//
// DOES NOT OWN:
//   ❌ State mutation  ❌ Recovery execution  ❌ Snapshot creation
//   ❌ Canvas access  ❌ Undo/redo stack management  ❌ UI access
//
// IMPLEMENTS:
//   ✔ HistoryGuardInterface   (from history_manager.dart)
//   ✔ RecoveryGuardInterface  (from recovery_engine.dart)
//
// COMMUNICATION ALLOWED:
//   ✔ HistoryManager (read — stack depth, timeline queries)
//   ✔ SnapshotEngine (read — existence + validity queries)
//
// COMMUNICATION FORBIDDEN:
//   ❌ LayerEngine  ❌ RenderEngine  ❌ Canvas  ❌ ExecutionCore  ❌ UI
// ==================================================

import 'dart:async';

import 'history_manager.dart'
    show HistoryGuardInterface, HistoryEntry, HistoryEntryStatus;
import 'recovery_engine.dart'
    show RecoveryGuardInterface, RecoveryReason;

// ==================================================
// EXTERNAL READ-ONLY QUERY INTERFACES
// HistoryGuard is a pure read-and-decide layer.
// It never writes through any of these interfaces.
// ==================================================

// — History state reader —
abstract interface class HistoryStateQueryInterface {
  /// Current depth of the undo stack.
  Future<int> undoDepth();

  /// Current depth of the redo stack.
  Future<int> redoDepth();

  /// Returns the full chronological timeline (oldest → newest).
  Future<List<HistoryEntry>> timeline();

  /// Returns true if [historyId] exists anywhere in the timeline.
  Future<bool> entryExists(String historyId);

  /// Returns the entry immediately below [historyId] in the undo stack,
  /// or null if [historyId] is the oldest entry.
  Future<HistoryEntry?> entryBefore(String historyId);

  /// Returns the entry immediately above [historyId] in the redo stack,
  /// or null if [historyId] is the top-most redo entry.
  Future<HistoryEntry?> entryAbove(String historyId);
}

// — Snapshot validity reader —
abstract interface class SnapshotValidityQueryInterface {
  /// Returns true if [snapshotId] exists and passes integrity validation.
  Future<bool> isValid(String snapshotId);

  /// Returns true if [snapshotId] exists in the registry (no validation).
  Future<bool> exists(String snapshotId);
}

// — System state guard reader —
abstract interface class SystemStateGuardQueryInterface {
  /// Returns true when the system is fully operational and not mid-shutdown.
  Future<bool> isSystemReady();

  /// Returns true when another recovery or undo/redo operation is already
  /// in progress, which would make a second one unsafe.
  Future<bool> isRecoveryInProgress();
}

// ==================================================
// GUARD CHECK REGISTRY
// Named enumeration of every check the guard can run.
// ==================================================

enum GuardCheck {
  // Entry validation
  entryStructure,         // commandId, historyId, actionType non-empty
  entryStatusConsistency, // status is appropriate for the requested operation
  entryTimestampOrder,    // timestamp is not in the future / not zero

  // Snapshot chain
  beforeSnapshotPresence, // beforeSnapshotId exists if required
  afterSnapshotPresence,  // afterSnapshotId exists if required
  snapshotChainLinkage,   // before → after chain is consistent in timeline

  // Corruption detection
  duplicateEntryDetection,// historyId appears more than once in timeline
  cycleDetection,         // entry references itself in the chain
  orphanDetection,        // snapshot IDs referenced but not in registry

  // Recovery path
  recoverySnapshotValid,  // target snapshot passes full integrity check
  recoverySystemReady,    // no other recovery operation is in progress
  recoveryReasonAllowed,  // the reason code is not blocked by policy

  // History limits
  undoStackDepth,         // undo stack is not empty
  redoStackDepth,         // redo stack is not empty
  registrationCapacity,   // history stack has room for a new entry

  // Undo / redo specific integrity
  undoStatusEligible,     // entry status is `committed` or `redone`
  redoStatusEligible,     // entry status is `undone`
  concurrentOperationBlock, // no other undo/redo is in flight
}

// ==================================================
// GUARD VERDICT
// Result of a single named check.
// ==================================================

enum GuardStatus { passed, blocked, skipped }

class GuardVerdict {
  const GuardVerdict({
    required this.check,
    required this.status,
    this.reason,
  });

  final GuardCheck  check;
  final GuardStatus status;
  final String?     reason;

  bool get passed  => status == GuardStatus.passed;
  bool get blocked => status == GuardStatus.blocked;
  bool get skipped => status == GuardStatus.skipped;

  factory GuardVerdict.pass(GuardCheck c) =>
      GuardVerdict(check: c, status: GuardStatus.passed);

  factory GuardVerdict.block(GuardCheck c, String reason) =>
      GuardVerdict(check: c, status: GuardStatus.blocked, reason: reason);

  factory GuardVerdict.skip(GuardCheck c, String reason) =>
      GuardVerdict(check: c, status: GuardStatus.skipped, reason: reason);

  @override
  String toString() =>
      'GuardVerdict(${check.name}: $status'
      '${reason != null ? ", reason: $reason" : ""})';
}

// ==================================================
// GUARD RESULT
// Complete outcome of a multi-check guard pass.
// ==================================================

class GuardResult {
  const GuardResult({
    required this.cleared,
    required this.verdicts,
    required this.evaluatedAt,
  });

  final bool               cleared;
  final List<GuardVerdict> verdicts;
  final DateTime           evaluatedAt;

  GuardVerdict? get firstBlock =>
      verdicts.cast<GuardVerdict?>().firstWhere(
          (v) => v != null && v.blocked, orElse: () => null);

  String? get blockReason => firstBlock?.reason;

  int get passCount  => verdicts.where((v) => v.passed).length;
  int get blockCount => verdicts.where((v) => v.blocked).length;

  @override
  String toString() =>
      'GuardResult(cleared: $cleared, checks: ${verdicts.length}, '
      'blocked: $blockCount)';
}

// ==================================================
// INTEGRITY REPORT
// Returned by generateIntegrityReport() — full system health view.
// ==================================================

class IntegrityReport {
  const IntegrityReport({
    required this.generatedAt,
    required this.undoDepth,
    required this.redoDepth,
    required this.timelineSize,
    required this.corruptionDetected,
    required this.corruptionDetails,
    required this.orphanedSnapshotIds,
    required this.duplicateEntryIds,
    required this.brokenChainEntryIds,
    required this.canUndo,
    required this.canRedo,
    required this.systemReady,
    required this.overallHealthy,
  });

  final DateTime     generatedAt;
  final int          undoDepth;
  final int          redoDepth;
  final int          timelineSize;
  final bool         corruptionDetected;
  final List<String> corruptionDetails;
  final List<String> orphanedSnapshotIds;
  final List<String> duplicateEntryIds;
  final List<String> brokenChainEntryIds;
  final bool         canUndo;
  final bool         canRedo;
  final bool         systemReady;
  final bool         overallHealthy;

  @override
  String toString() =>
      'IntegrityReport(healthy: $overallHealthy, '
      'undoDepth: $undoDepth, redoDepth: $redoDepth, '
      'corruption: $corruptionDetected, '
      'orphans: ${orphanedSnapshotIds.length})';
}

// ==================================================
// HISTORY GUARD CONFIGURATION
// ==================================================

class HistoryGuardConfig {
  const HistoryGuardConfig({
    this.maxHistorySize            = 100,
    this.maxRedoSize               = 50,
    this.requireSnapshotsForUndo   = true,
    this.requireSnapshotsForRedo   = true,
    this.requireSnapshotsForRegister = false,
    this.blockOnConcurrentOperation = true,
    this.blockForbiddenReasons     = const {},
  });

  /// Matches HistoryManager.maxHistorySize — guard enforces the same cap.
  final int maxHistorySize;

  /// Matches HistoryManager.maxRedoSize.
  final int maxRedoSize;

  /// When true, an undo entry must have a valid beforeSnapshotId.
  final bool requireSnapshotsForUndo;

  /// When true, a redo entry must have a valid afterSnapshotId.
  final bool requireSnapshotsForRedo;

  /// When true, registration is blocked if the entry has no snapshotIds.
  final bool requireSnapshotsForRegister;

  /// Block undo/redo when another operation is already in progress.
  final bool blockOnConcurrentOperation;

  /// Recovery reasons that are unconditionally blocked by policy.
  final Set<RecoveryReason> blockForbiddenReasons;
}

// ==================================================
// HISTORY GUARD
// Implements HistoryGuardInterface + RecoveryGuardInterface.
// Pure read-and-decide — no state mutation.
// ==================================================

class HistoryGuard implements HistoryGuardInterface, RecoveryGuardInterface {
  HistoryGuard({
    required HistoryStateQueryInterface    historyState,
    required SnapshotValidityQueryInterface snapshotValidity,
    required SystemStateGuardQueryInterface systemState,
    HistoryGuardConfig config = const HistoryGuardConfig(),
  })  : _history  = historyState,
        _snapshot = snapshotValidity,
        _system   = systemState,
        _config   = config;

  final HistoryStateQueryInterface     _history;
  final SnapshotValidityQueryInterface _snapshot;
  final SystemStateGuardQueryInterface _system;
  final HistoryGuardConfig             _config;

  // Telemetry (read-only; never exposed as mutable state).
  int _totalUndoChecks    = 0;
  int _totalRedoChecks    = 0;
  int _totalRegisterChecks = 0;
  int _totalRestoreChecks  = 0;
  int _totalBlocks         = 0;
  final List<GuardResult> _recentResults = [];

  // ==================================================
  // HISTORYGUARDINTERFACE IMPLEMENTATION
  // ==================================================

  @override
  Future<bool> canUndo(HistoryEntry entry) async {
    _totalUndoChecks++;
    final result = await verifyUndoIntegrity(entry);
    _recordResult(result);
    return result.cleared;
  }

  @override
  Future<bool> canRedo(HistoryEntry entry) async {
    _totalRedoChecks++;
    final result = await verifyRedoIntegrity(entry);
    _recordResult(result);
    return result.cleared;
  }

  @override
  Future<bool> canRegister(HistoryEntry entry) async {
    _totalRegisterChecks++;
    final result = await validateHistoryEntry(entry,
        operation: _HistoryOperation.register);
    _recordResult(result);
    return result.cleared;
  }

  // ==================================================
  // RECOVERYGUARDINTERFACE IMPLEMENTATION
  // ==================================================

  @override
  Future<bool> canRestore(String snapshotId, RecoveryReason reason) async {
    _totalRestoreChecks++;
    final result = await verifyRecoveryPath(snapshotId, reason);
    _recordResult(result);
    return result.cleared;
  }

  // ==================================================
  // PUBLIC API — mandatory functions per contract
  // ==================================================

  // --------------------------------------------------
  // validateHistoryEntry()
  // Checks the structural integrity of a single HistoryEntry.
  // Used for registration and general timeline health checks.
  // --------------------------------------------------

  Future<GuardResult> validateHistoryEntry(
    HistoryEntry entry, {
    _HistoryOperation operation = _HistoryOperation.register,
  }) async {
    final verdicts = <GuardVerdict>[];

    // Structure: IDs and type must be non-trivial.
    final structureVerdict = _checkEntryStructure(entry);
    verdicts.add(structureVerdict);
    if (structureVerdict.blocked) return _result(verdicts);

    // Status consistency for the requested operation.
    final statusVerdict = _checkEntryStatusConsistency(entry, operation);
    verdicts.add(statusVerdict);
    if (statusVerdict.blocked) return _result(verdicts);

    // Timestamp must be plausible (not zero epoch, not in the future).
    final tsVerdict = await _checkEntryTimestampOrder(entry);
    verdicts.add(tsVerdict);
    if (tsVerdict.blocked) return _result(verdicts);

    // Snapshot presence requirements per operation.
    if (operation == _HistoryOperation.register &&
        _config.requireSnapshotsForRegister) {
      if (entry.beforeSnapshotId == null && entry.afterSnapshotId == null) {
        verdicts.add(GuardVerdict.block(GuardCheck.beforeSnapshotPresence,
            'Registration requires at least one snapshot ID '
            '(before or after) but entry ${entry.historyId} has neither.'));
        return _result(verdicts);
      }
    }

    verdicts.add(GuardVerdict.skip(GuardCheck.beforeSnapshotPresence,
        'Full snapshot validation deferred to specific undo/redo checks.'));
    verdicts.add(GuardVerdict.skip(GuardCheck.afterSnapshotPresence,
        'Full snapshot validation deferred to specific undo/redo checks.'));

    // Capacity check for new registrations.
    if (operation == _HistoryOperation.register) {
      final capVerdict = await _checkRegistrationCapacity();
      verdicts.add(capVerdict);
      if (capVerdict.blocked) return _result(verdicts);
    } else {
      verdicts.add(GuardVerdict.skip(GuardCheck.registrationCapacity,
          'Capacity check only applies to new registrations.'));
    }

    return _result(verdicts);
  }

  // --------------------------------------------------
  // validateSnapshotChain()
  // Verifies that a sequence of entries has a consistent
  // before/after snapshot chain with no gaps or broken links.
  // --------------------------------------------------

  Future<GuardResult> validateSnapshotChain(
      List<HistoryEntry> entries) async {
    final verdicts = <GuardVerdict>[];

    if (entries.isEmpty) {
      verdicts.add(GuardVerdict.skip(GuardCheck.snapshotChainLinkage,
          'Empty entry list — no chain to validate.'));
      return _result(verdicts);
    }

    // Every entry's afterSnapshotId should match the next entry's
    // beforeSnapshotId (where both are non-null).
    final broken = <String>[];
    for (var i = 0; i < entries.length - 1; i++) {
      final curr = entries[i];
      final next = entries[i + 1];
      if (curr.afterSnapshotId != null &&
          next.beforeSnapshotId != null &&
          curr.afterSnapshotId != next.beforeSnapshotId) {
        broken.add('${curr.historyId}→${next.historyId}: '
            'afterSnapshot=${curr.afterSnapshotId} '
            '≠ beforeSnapshot=${next.beforeSnapshotId}');
      }
    }

    if (broken.isNotEmpty) {
      verdicts.add(GuardVerdict.block(GuardCheck.snapshotChainLinkage,
          'Snapshot chain has ${broken.length} broken link(s): '
          '${broken.join("; ")}'));
      return _result(verdicts);
    }

    verdicts.add(GuardVerdict.pass(GuardCheck.snapshotChainLinkage));

    // Validate that every referenced snapshot ID actually exists.
    final orphans = <String>[];
    for (final entry in entries) {
      for (final sid in [entry.beforeSnapshotId, entry.afterSnapshotId]) {
        if (sid != null && !await _snapshot.exists(sid)) {
          orphans.add('$sid (entry: ${entry.historyId})');
        }
      }
    }

    if (orphans.isNotEmpty) {
      verdicts.add(GuardVerdict.block(GuardCheck.orphanDetection,
          '${orphans.length} orphaned snapshot reference(s): '
          '${orphans.join(", ")}'));
    } else {
      verdicts.add(GuardVerdict.pass(GuardCheck.orphanDetection));
    }

    return _result(verdicts);
  }

  // --------------------------------------------------
  // detectCorruption()
  // Scans the full timeline for structural anomalies:
  // duplicate entry IDs, cycle references, orphaned snapshots.
  // --------------------------------------------------

  Future<GuardResult> detectCorruption(List<HistoryEntry> timeline) async {
    final verdicts = <GuardVerdict>[];

    if (timeline.isEmpty) {
      verdicts.add(GuardVerdict.skip(GuardCheck.duplicateEntryDetection,
          'Timeline is empty — no corruption possible.'));
      verdicts.add(GuardVerdict.skip(GuardCheck.cycleDetection,
          'Timeline is empty.'));
      verdicts.add(GuardVerdict.skip(GuardCheck.orphanDetection,
          'Timeline is empty.'));
      return _result(verdicts);
    }

    // — Duplicate historyId detection —
    final seen   = <String>{};
    final dupes  = <String>[];
    for (final entry in timeline) {
      if (!seen.add(entry.historyId)) dupes.add(entry.historyId);
    }
    if (dupes.isNotEmpty) {
      verdicts.add(GuardVerdict.block(GuardCheck.duplicateEntryDetection,
          'Duplicate historyId(s) detected: ${dupes.join(", ")}. '
          'History timeline is corrupted.'));
    } else {
      verdicts.add(GuardVerdict.pass(GuardCheck.duplicateEntryDetection));
    }

    // — Cycle detection: snapshotId appears as both before and after —
    final beforeIds = timeline
        .map((e) => e.beforeSnapshotId)
        .whereType<String>()
        .toSet();
    final afterIds = timeline
        .map((e) => e.afterSnapshotId)
        .whereType<String>()
        .toSet();
    final cycles = beforeIds.intersection(afterIds);

    // A snapshotId appearing in both is only a cycle if it appears in the
    // same entry (self-reference). Cross-entry sharing is valid (snapshot reuse).
    final selfCycles = <String>[];
    for (final entry in timeline) {
      if (entry.beforeSnapshotId != null &&
          entry.beforeSnapshotId == entry.afterSnapshotId) {
        selfCycles.add('${entry.historyId}: '
            'beforeSnapshotId == afterSnapshotId == ${entry.beforeSnapshotId}');
      }
    }
    if (selfCycles.isNotEmpty) {
      verdicts.add(GuardVerdict.block(GuardCheck.cycleDetection,
          'Self-referencing snapshot cycle(s) detected: '
          '${selfCycles.join("; ")}'));
    } else {
      // cycles (cross-entry) is informational — log but don't block.
      verdicts.add(GuardVerdict.pass(GuardCheck.cycleDetection));
    }

    // — Orphan snapshot detection —
    final orphans = <String>[];
    for (final entry in timeline) {
      for (final sid in [entry.beforeSnapshotId, entry.afterSnapshotId]) {
        if (sid != null && !await _snapshot.exists(sid)) {
          orphans.add('$sid (entry: ${entry.historyId})');
        }
      }
    }
    if (orphans.isNotEmpty) {
      verdicts.add(GuardVerdict.block(GuardCheck.orphanDetection,
          '${orphans.length} orphaned snapshot reference(s) found in '
          'timeline: ${orphans.join(", ")}'));
    } else {
      verdicts.add(GuardVerdict.pass(GuardCheck.orphanDetection));
    }

    return _result(verdicts);
  }

  // --------------------------------------------------
  // verifyRecoveryPath()
  // Validates that restoring [snapshotId] for [reason] is safe.
  // Checks: snapshot validity, system readiness, reason policy.
  // --------------------------------------------------

  Future<GuardResult> verifyRecoveryPath(
      String snapshotId, RecoveryReason reason) async {
    final verdicts = <GuardVerdict>[];

    // Policy: certain reasons may be unconditionally blocked.
    if (_config.blockForbiddenReasons.contains(reason)) {
      verdicts.add(GuardVerdict.block(GuardCheck.recoveryReasonAllowed,
          'Recovery reason $reason is blocked by system policy.'));
      return _result(verdicts);
    }
    verdicts.add(GuardVerdict.pass(GuardCheck.recoveryReasonAllowed));

    // System must be ready and not mid-recovery.
    final systemReady = await _system.isSystemReady();
    if (!systemReady) {
      verdicts.add(GuardVerdict.block(GuardCheck.recoverySystemReady,
          'System is not ready — cannot proceed with recovery '
          'for snapshot $snapshotId.'));
      return _result(verdicts);
    }

    if (_config.blockOnConcurrentOperation) {
      final inProgress = await _system.isRecoveryInProgress();
      if (inProgress) {
        verdicts.add(GuardVerdict.block(GuardCheck.recoverySystemReady,
            'Another recovery operation is already in progress. '
            'Concurrent recovery would produce an inconsistent state.'));
        return _result(verdicts);
      }
    }
    verdicts.add(GuardVerdict.pass(GuardCheck.recoverySystemReady));

    // Snapshot must exist and be valid.
    final valid = await _snapshot.isValid(snapshotId);
    if (!valid) {
      verdicts.add(GuardVerdict.block(GuardCheck.recoverySnapshotValid,
          'Snapshot $snapshotId does not exist or failed integrity '
          'validation. Recovery path is blocked.'));
      return _result(verdicts);
    }
    verdicts.add(GuardVerdict.pass(GuardCheck.recoverySnapshotValid));

    return _result(verdicts);
  }

  // --------------------------------------------------
  // enforceHistoryLimits()
  // Checks whether the stacks are within configured limits.
  // Returns a GuardResult that callers can inspect or act on.
  // Does NOT trim the stacks — that is HistoryManager's responsibility.
  // --------------------------------------------------

  Future<GuardResult> enforceHistoryLimits() async {
    final verdicts = <GuardVerdict>[];

    final undoDepth = await _history.undoDepth();
    final redoDepth = await _history.redoDepth();

    if (undoDepth > _config.maxHistorySize) {
      verdicts.add(GuardVerdict.block(GuardCheck.registrationCapacity,
          'Undo stack depth $undoDepth exceeds configured maximum '
          '${_config.maxHistorySize}. '
          'HistoryManager must call trimHistory() before registering '
          'new entries.'));
    } else {
      verdicts.add(GuardVerdict.pass(GuardCheck.registrationCapacity));
    }

    if (redoDepth > _config.maxRedoSize) {
      verdicts.add(GuardVerdict.block(GuardCheck.redoStackDepth,
          'Redo stack depth $redoDepth exceeds configured maximum '
          '${_config.maxRedoSize}. '
          'HistoryManager should evict oldest redo entries.'));
    } else {
      verdicts.add(GuardVerdict.pass(GuardCheck.redoStackDepth));
    }

    return _result(verdicts);
  }

  // --------------------------------------------------
  // verifyUndoIntegrity()
  // Full integrity check for an entry about to be undone.
  // --------------------------------------------------

  Future<GuardResult> verifyUndoIntegrity(HistoryEntry entry) async {
    final verdicts = <GuardVerdict>[];

    // Status must allow undo: only `committed` and `redone` are eligible.
    final eligible = entry.status == HistoryEntryStatus.committed ||
        entry.status == HistoryEntryStatus.redone;
    if (!eligible) {
      verdicts.add(GuardVerdict.block(GuardCheck.undoStatusEligible,
          'Entry ${entry.historyId} has status ${entry.status} — '
          'only "committed" and "redone" entries can be undone. '
          'Undo blocked.'));
      return _result(verdicts);
    }
    verdicts.add(GuardVerdict.pass(GuardCheck.undoStatusEligible));

    // Undo stack must be non-empty.
    final depth = await _history.undoDepth();
    if (depth == 0) {
      verdicts.add(GuardVerdict.block(GuardCheck.undoStackDepth,
          'Undo stack is empty — nothing to undo.'));
      return _result(verdicts);
    }
    verdicts.add(GuardVerdict.pass(GuardCheck.undoStackDepth));

    // Concurrent operation guard.
    if (_config.blockOnConcurrentOperation) {
      final inProgress = await _system.isRecoveryInProgress();
      if (inProgress) {
        verdicts.add(GuardVerdict.block(GuardCheck.concurrentOperationBlock,
            'Another undo/redo/recovery operation is already in progress. '
            'Concurrent operations are blocked to prevent state corruption.'));
        return _result(verdicts);
      }
    }
    verdicts.add(GuardVerdict.pass(GuardCheck.concurrentOperationBlock));

    // The beforeSnapshotId must be present and valid.
    if (_config.requireSnapshotsForUndo) {
      final sid = entry.beforeSnapshotId;
      if (sid == null) {
        verdicts.add(GuardVerdict.block(GuardCheck.beforeSnapshotPresence,
            'Undo entry ${entry.historyId} has no beforeSnapshotId. '
            'Cannot restore to pre-action state — undo blocked.'));
        return _result(verdicts);
      }
      final valid = await _snapshot.isValid(sid);
      if (!valid) {
        verdicts.add(GuardVerdict.block(GuardCheck.beforeSnapshotPresence,
            'beforeSnapshotId "$sid" for entry ${entry.historyId} '
            'does not exist or failed integrity validation. '
            'Undo blocked to prevent restoring corrupted state.'));
        return _result(verdicts);
      }
      verdicts.add(GuardVerdict.pass(GuardCheck.beforeSnapshotPresence));
    } else {
      verdicts.add(GuardVerdict.skip(GuardCheck.beforeSnapshotPresence,
          'Snapshot requirement for undo disabled by config.'));
    }

    // System must be ready.
    final ready = await _system.isSystemReady();
    if (!ready) {
      verdicts.add(GuardVerdict.block(GuardCheck.recoverySystemReady,
          'System is not ready — undo operation blocked.'));
      return _result(verdicts);
    }
    verdicts.add(GuardVerdict.pass(GuardCheck.recoverySystemReady));

    return _result(verdicts);
  }

  // --------------------------------------------------
  // verifyRedoIntegrity()
  // Full integrity check for an entry about to be redone.
  // --------------------------------------------------

  Future<GuardResult> verifyRedoIntegrity(HistoryEntry entry) async {
    final verdicts = <GuardVerdict>[];

    // Status must be `undone` for redo eligibility.
    if (entry.status != HistoryEntryStatus.undone) {
      verdicts.add(GuardVerdict.block(GuardCheck.redoStatusEligible,
          'Entry ${entry.historyId} has status ${entry.status} — '
          'only "undone" entries can be redone. '
          'Redo blocked.'));
      return _result(verdicts);
    }
    verdicts.add(GuardVerdict.pass(GuardCheck.redoStatusEligible));

    // Redo stack must be non-empty.
    final depth = await _history.redoDepth();
    if (depth == 0) {
      verdicts.add(GuardVerdict.block(GuardCheck.redoStackDepth,
          'Redo stack is empty — nothing to redo.'));
      return _result(verdicts);
    }
    verdicts.add(GuardVerdict.pass(GuardCheck.redoStackDepth));

    // Concurrent operation guard.
    if (_config.blockOnConcurrentOperation) {
      final inProgress = await _system.isRecoveryInProgress();
      if (inProgress) {
        verdicts.add(GuardVerdict.block(GuardCheck.concurrentOperationBlock,
            'Another undo/redo/recovery operation is already in progress. '
            'Concurrent operations are blocked to prevent state corruption.'));
        return _result(verdicts);
      }
    }
    verdicts.add(GuardVerdict.pass(GuardCheck.concurrentOperationBlock));

    // The afterSnapshotId must be present and valid.
    if (_config.requireSnapshotsForRedo) {
      final sid = entry.afterSnapshotId;
      if (sid == null) {
        verdicts.add(GuardVerdict.block(GuardCheck.afterSnapshotPresence,
            'Redo entry ${entry.historyId} has no afterSnapshotId. '
            'Cannot restore post-action state — redo blocked.'));
        return _result(verdicts);
      }
      final valid = await _snapshot.isValid(sid);
      if (!valid) {
        verdicts.add(GuardVerdict.block(GuardCheck.afterSnapshotPresence,
            'afterSnapshotId "$sid" for entry ${entry.historyId} '
            'does not exist or failed integrity validation. '
            'Redo blocked to prevent restoring corrupted state.'));
        return _result(verdicts);
      }
      verdicts.add(GuardVerdict.pass(GuardCheck.afterSnapshotPresence));
    } else {
      verdicts.add(GuardVerdict.skip(GuardCheck.afterSnapshotPresence,
          'Snapshot requirement for redo disabled by config.'));
    }

    // System must be ready.
    final ready = await _system.isSystemReady();
    if (!ready) {
      verdicts.add(GuardVerdict.block(GuardCheck.recoverySystemReady,
          'System is not ready — redo operation blocked.'));
      return _result(verdicts);
    }
    verdicts.add(GuardVerdict.pass(GuardCheck.recoverySystemReady));

    return _result(verdicts);
  }

  // --------------------------------------------------
  // generateIntegrityReport()
  // Full system health snapshot across all guard dimensions.
  // Does NOT mutate any state.
  // --------------------------------------------------

  Future<IntegrityReport> generateIntegrityReport() async {
    final checkedAt  = DateTime.now().toUtc();
    final timeline   = await _history.timeline();
    final undoDepth  = await _history.undoDepth();
    final redoDepth  = await _history.redoDepth();
    final systemReady = await _system.isSystemReady();

    // Run full corruption scan.
    final corruptionResult = await detectCorruption(timeline);
    final corruptionDetected = !corruptionResult.cleared;
    final corruptionDetails = corruptionResult.verdicts
        .where((v) => v.blocked)
        .map((v) => '${v.check.name}: ${v.reason ?? "no detail"}')
        .toList();

    // Collect orphaned snapshot IDs from corruption verdicts.
    final orphanVerdict = corruptionResult.verdicts
        .cast<GuardVerdict?>()
        .firstWhere((v) => v?.check == GuardCheck.orphanDetection,
            orElse: () => null);
    final orphanedIds = orphanVerdict?.blocked == true
        ? _extractIds(orphanVerdict!.reason ?? '')
        : <String>[];

    // Collect duplicate entry IDs.
    final dupeVerdict = corruptionResult.verdicts
        .cast<GuardVerdict?>()
        .firstWhere((v) => v?.check == GuardCheck.duplicateEntryDetection,
            orElse: () => null);
    final duplicateIds = dupeVerdict?.blocked == true
        ? _extractIds(dupeVerdict!.reason ?? '')
        : <String>[];

    // Check snapshot chain.
    final chainResult   = await validateSnapshotChain(timeline);
    final brokenChainVerdict = chainResult.verdicts
        .cast<GuardVerdict?>()
        .firstWhere((v) => v?.check == GuardCheck.snapshotChainLinkage &&
            v?.blocked == true, orElse: () => null);
    final brokenChainIds = brokenChainVerdict != null
        ? _extractIds(brokenChainVerdict.reason ?? '')
        : <String>[];

    final overallHealthy = !corruptionDetected &&
        brokenChainIds.isEmpty &&
        systemReady;

    return IntegrityReport(
      generatedAt:         checkedAt,
      undoDepth:           undoDepth,
      redoDepth:           redoDepth,
      timelineSize:        timeline.length,
      corruptionDetected:  corruptionDetected,
      corruptionDetails:   List.unmodifiable(corruptionDetails),
      orphanedSnapshotIds: List.unmodifiable(orphanedIds),
      duplicateEntryIds:   List.unmodifiable(duplicateIds),
      brokenChainEntryIds: List.unmodifiable(brokenChainIds),
      canUndo:             undoDepth > 0,
      canRedo:             redoDepth > 0,
      systemReady:         systemReady,
      overallHealthy:      overallHealthy,
    );
  }

  // ==================================================
  // PRIVATE CHECK HELPERS
  // ==================================================

  GuardVerdict _checkEntryStructure(HistoryEntry entry) {
    if (entry.historyId.trim().isEmpty) {
      return GuardVerdict.block(GuardCheck.entryStructure,
          'historyId is empty — entry cannot be accepted.');
    }
    if (entry.actionId.trim().isEmpty) {
      return GuardVerdict.block(GuardCheck.entryStructure,
          'actionId is empty in entry ${entry.historyId}.');
    }
    return GuardVerdict.pass(GuardCheck.entryStructure);
  }

  GuardVerdict _checkEntryStatusConsistency(
      HistoryEntry entry, _HistoryOperation operation) {
    switch (operation) {
      case _HistoryOperation.register:
        // Only committed entries should be registered as new actions.
        if (entry.status == HistoryEntryStatus.evicted) {
          return GuardVerdict.block(GuardCheck.entryStatusConsistency,
              'Cannot re-register an evicted entry (${entry.historyId}).');
        }
        return GuardVerdict.pass(GuardCheck.entryStatusConsistency);

      case _HistoryOperation.undo:
        final ok = entry.status == HistoryEntryStatus.committed ||
            entry.status == HistoryEntryStatus.redone;
        return ok
            ? GuardVerdict.pass(GuardCheck.entryStatusConsistency)
            : GuardVerdict.block(GuardCheck.entryStatusConsistency,
                'Entry ${entry.historyId} status ${entry.status} is not '
                'eligible for undo.');

      case _HistoryOperation.redo:
        final ok = entry.status == HistoryEntryStatus.undone;
        return ok
            ? GuardVerdict.pass(GuardCheck.entryStatusConsistency)
            : GuardVerdict.block(GuardCheck.entryStatusConsistency,
                'Entry ${entry.historyId} status ${entry.status} is not '
                'eligible for redo — only "undone" entries can be redone.');
    }
  }

  Future<GuardVerdict> _checkEntryTimestampOrder(HistoryEntry entry) async {
    final epoch   = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final now     = DateTime.now().toUtc();
    const tolerance = Duration(seconds: 5); // clock skew tolerance

    if (entry.timestamp.isBefore(epoch.add(const Duration(seconds: 1)))) {
      return GuardVerdict.block(GuardCheck.entryTimestampOrder,
          'Entry ${entry.historyId} has an invalid timestamp '
          '(${entry.timestamp.toIso8601String()}) — appears to be at or '
          'before the Unix epoch.');
    }
    if (entry.timestamp.isAfter(now.add(tolerance))) {
      return GuardVerdict.block(GuardCheck.entryTimestampOrder,
          'Entry ${entry.historyId} has a future timestamp '
          '(${entry.timestamp.toIso8601String()}) — clock skew exceeds '
          '${tolerance.inSeconds}s tolerance. Entry rejected.');
    }
    return GuardVerdict.pass(GuardCheck.entryTimestampOrder);
  }

  Future<GuardVerdict> _checkRegistrationCapacity() async {
    final depth = await _history.undoDepth();
    if (depth >= _config.maxHistorySize) {
      return GuardVerdict.block(GuardCheck.registrationCapacity,
          'Undo stack is at capacity ($depth/${_config.maxHistorySize}). '
          'HistoryManager must trim before accepting new entries.');
    }
    return GuardVerdict.pass(GuardCheck.registrationCapacity);
  }

  // ==================================================
  // PRIVATE UTILITIES
  // ==================================================

  GuardResult _result(List<GuardVerdict> verdicts) {
    final cleared = verdicts.every((v) => v.passed || v.skipped);
    if (!cleared) _totalBlocks++;
    return GuardResult(
      cleared:     cleared,
      verdicts:    List.unmodifiable(verdicts),
      evaluatedAt: DateTime.now().toUtc(),
    );
  }

  void _recordResult(GuardResult result) {
    _recentResults.add(result);
    if (_recentResults.length > 100) _recentResults.removeAt(0);
  }

  /// Naive ID extractor from a reason string for report purposes.
  /// Extracts quoted strings and tokens before parentheses.
  List<String> _extractIds(String reason) {
    final ids = <String>[];
    // Quoted strings.
    final quoted = RegExp(r'"([^"]+)"');
    ids.addAll(quoted.allMatches(reason).map((m) => m.group(1)!));
    // Also capture tokens like `snap_000001_...` or `hist_...`.
    final tokens = RegExp(r'(?:snap|hist)_\w+');
    ids.addAll(tokens.allMatches(reason).map((m) => m.group(0)!));
    return ids.toSet().toList();
  }

  // ==================================================
  // READ-ONLY TELEMETRY ACCESSORS
  // ==================================================

  int get totalUndoChecks     => _totalUndoChecks;
  int get totalRedoChecks     => _totalRedoChecks;
  int get totalRegisterChecks => _totalRegisterChecks;
  int get totalRestoreChecks  => _totalRestoreChecks;
  int get totalBlocks         => _totalBlocks;

  List<GuardResult> get recentResults => List.unmodifiable(_recentResults);
}

// ==================================================
// INTERNAL OPERATION TYPE
// Used internally to contextualise status consistency checks.
// Not part of the public contract.
// ==================================================

enum _HistoryOperation { register, undo, redo }

// ==================================================
// NULL IMPLEMENTATIONS
// Safe no-op providers for testing and development.
// ==================================================

class NullHistoryStateQuery implements HistoryStateQueryInterface {
  const NullHistoryStateQuery();
  @override Future<int> undoDepth()         async => 0;
  @override Future<int> redoDepth()         async => 0;
  @override Future<List<HistoryEntry>> timeline() async => [];
  @override Future<bool> entryExists(String id) async => false;
  @override Future<HistoryEntry?> entryBefore(String id) async => null;
  @override Future<HistoryEntry?> entryAbove(String id)  async => null;
}

class NullSnapshotValidityQuery implements SnapshotValidityQueryInterface {
  const NullSnapshotValidityQuery();
  @override Future<bool> isValid(String id) async => true;
  @override Future<bool> exists(String id)  async => true;
}

class NullSystemStateGuardQuery implements SystemStateGuardQueryInterface {
  const NullSystemStateGuardQuery();
  @override Future<bool> isSystemReady()          async => true;
  @override Future<bool> isRecoveryInProgress()   async => false;
}

/// Convenience factory — fully null-wired HistoryGuard for dev/test.
HistoryGuard buildNullHistoryGuard({
  HistoryGuardConfig config = const HistoryGuardConfig(),
}) =>
    HistoryGuard(
      historyState:    const NullHistoryStateQuery(),
      snapshotValidity: const NullSnapshotValidityQuery(),
      systemState:     const NullSystemStateGuardQuery(),
      config:          config,
    );

// ==================================================
// END OF core/history/history_guard.dart
// Z-CANVAS — PHASE-15 — HISTORY PROTECTION LAYER
// Powered by Zynquar
// ==================================================
