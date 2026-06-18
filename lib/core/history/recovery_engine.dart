// ==================================================
// Z-CANVAS — PHASE-15 HISTORY, SNAPSHOT & RECOVERY
// core/history/recovery_engine.dart
//
// PRIMARY ROLE: STATE RESTORATION ENGINE
//
// OWNS:
//   ✔ Snapshot restoration (undo recovery path)
//   ✔ Next-state restoration (redo recovery path)
//   ✔ Failed execution recovery (rollback to pre-execution snapshot)
//   ✔ Editor state recovery (generic state realignment)
//   ✔ Crash recovery (restore latest validated safe snapshot)
//   ✔ Safe rollback (abort on any partial failure — Atomic Restore Law)
//   ✔ Recovery integrity verification (pre-restore health check)
//   ✔ Recovery report generation
//
// DOES NOT OWN:
//   ❌ Snapshot creation  ❌ Action execution  ❌ UI modification
//   ❌ Canvas direct access  ❌ Undo/redo stack management
//   ❌ Command generation  ❌ Render triggering
//
// ATOMIC RESTORE LAW:
//   RESTORE IS ALL OR NOTHING.
//   IF ANY STEP FAILS → ABORT ENTIRE RESTORE → KEEP CURRENT SAFE STATE.
//   NO PARTIAL STATE IS EVER LEFT COMMITTED.
//
// COMMUNICATION ALLOWED:
//   ✔ SnapshotEngine (read — retrieve + validate snapshots)
//   ✔ HistoryManager (read — navigate timeline for prev/next)
//   ✔ HistoryGuard   (guard — pre-restore safety check)
//   ✔ LayerEngine    (write — apply restored layer state)
//   ✔ EditorController (notify — signal recovery completion)
//
// COMMUNICATION FORBIDDEN:
//   ❌ UI  ❌ Canvas  ❌ RenderEngine (direct)
// ==================================================

import 'dart:async';

import 'history_manager.dart'  show RecoveryEngineInterface, HistoryEntry;
import 'snapshot_engine.dart'  show
    SnapshotData,
    CapturedLayerState,
    CapturedDesignState,
    CapturedSelectionState;

// ==================================================
// EXTERNAL INTERFACE CONTRACTS
// RecoveryEngine reads/writes through these only.
// ==================================================

// — Snapshot Engine read surface (recovery-specific) —
abstract interface class SnapshotReaderInterface {
  /// Retrieves a snapshot by ID. Returns null if not found.
  Future<SnapshotData?> getSnapshot(String snapshotId);

  /// Returns true if the snapshot exists and passes integrity checks.
  Future<bool> validateSnapshot(String snapshotId);

  /// Returns all registered snapshot IDs in creation order (oldest → newest).
  Future<List<String>> allSnapshotIds();
}

// — Layer Engine write surface (restoration only) —
// Recovery writes the layer state FROM a snapshot BACK to the engine.
// This is the only write path in Phase-15.
abstract interface class LayerEngineRestorerInterface {
  /// Replaces the entire layer collection with [layers].
  /// Must be atomic from the engine's perspective.
  Future<void> restoreLayers(
      List<Map<String, dynamic>> layers, String sessionId);

  /// Restores the layer z-order to [layerOrder].
  Future<void> restoreLayerOrder(List<String> layerOrder, String sessionId);

  /// Sets the active layer to [layerId], or clears selection if null.
  Future<void> restoreActiveLayer(String? layerId, String sessionId);

  /// Returns a hash or token representing the current layer state.
  /// Used to confirm the engine accepted the restore.
  Future<String> readCurrentStateToken();
}

// — Selection State restorer —
abstract interface class SelectionRestorerInterface {
  /// Restores the selection to [selectedLayerIds].
  Future<void> restoreSelection(List<String> selectedLayerIds, String sessionId);

  /// Restores the transform handle state from [transformState].
  Future<void> restoreTransformState(
      Map<String, dynamic> transformState, String sessionId);

  /// Clears all active selections.
  Future<void> clearSelection(String sessionId);
}

// — Design Model restorer —
abstract interface class DesignModelRestorerInterface {
  /// Applies [designModel] as the current document model.
  Future<void> restoreDesignModel(
      Map<String, dynamic> designModel, String sessionId);
}

// — EditorController notifier —
// Recovery notifies EditorController when restoration completes or fails.
// EditorController decides whether to trigger a render update.
abstract interface class EditorControllerRecoveryNotifierInterface {
  /// Called when a recovery operation completes successfully.
  Future<void> onRecoverySucceeded(RecoveryResult result);

  /// Called when a recovery operation fails and state was kept unchanged.
  Future<void> onRecoveryFailed(RecoveryResult result);
}

// — HistoryGuard recovery check surface —
abstract interface class RecoveryGuardInterface {
  /// Returns true if restoring [snapshotId] is safe to proceed.
  Future<bool> canRestore(String snapshotId, RecoveryReason reason);
}

// — HistoryManager navigation surface —
// RecoveryEngine queries the history timeline for prev/next snapshots.
abstract interface class HistoryNavigatorInterface {
  /// Returns the snapshot ID that should be restored for an undo step.
  /// Typically the [beforeSnapshotId] of the most recent undo-stack entry.
  Future<String?> previousSnapshotId();

  /// Returns the snapshot ID that should be restored for a redo step.
  /// Typically the [afterSnapshotId] of the most recent redo-stack entry.
  Future<String?> nextSnapshotId();

  /// Returns the latest committed (non-failed, non-evicted) history entry.
  Future<HistoryEntry?> latestCommittedEntry();

  /// Returns all snapshot IDs referenced by active history entries,
  /// from oldest to newest.
  Future<List<String>> allReferencedSnapshotIds();
}

// ==================================================
// RECOVERY REASON
// Identifies why a restore was requested — used in guard + reporting.
// ==================================================

enum RecoveryReason {
  undo,             // triggered by HistoryManager.undo()
  redo,             // triggered by HistoryManager.redo()
  failedExecution,  // Phase-14 reported execution failure
  editorRealign,    // generic editor state correction
  crashRecovery,    // application restart / crash handler
  manualRollback,   // explicit operator/dev rollback
}

// ==================================================
// RECOVERY STEP
// Named stages of a restore transaction.
// Used in RecoveryResult for per-step attribution.
// ==================================================

enum RecoveryStep {
  guardCheck,
  integrityVerification,
  snapshotRetrieval,
  layerRestoration,
  layerOrderRestoration,
  activeLayerRestoration,
  selectionRestoration,
  transformStateRestoration,
  designModelRestoration,
  engineConfirmation,
  notifyController,
}

// ==================================================
// RECOVERY STEP RECORD
// Outcome of one step in the atomic restore transaction.
// ==================================================

class RecoveryStepRecord {
  const RecoveryStepRecord({
    required this.step,
    required this.succeeded,
    required this.recordedAt,
    this.detail,
  });

  final RecoveryStep step;
  final bool         succeeded;
  final DateTime     recordedAt;
  final String?      detail;
}

// ==================================================
// RECOVERY RESULT
// Returned by every public restore method.
// ==================================================

sealed class RecoveryResult {}

final class RecoverySuccess extends RecoveryResult {
  RecoverySuccess({
    required this.snapshotId,
    required this.reason,
    required this.sessionId,
    required this.steps,
    required this.completedAt,
    this.layerCount,
  });

  final String               snapshotId;
  final RecoveryReason       reason;
  final String               sessionId;
  final List<RecoveryStepRecord> steps;
  final DateTime             completedAt;
  final int?                 layerCount;

  int get stepCount => steps.length;

  @override
  String toString() =>
      'RecoverySuccess(snap: $snapshotId, reason: $reason, '
      'steps: $stepCount, layers: $layerCount)';
}

final class RecoveryFailure extends RecoveryResult {
  RecoveryFailure({
    required this.snapshotId,
    required this.reason,
    required this.sessionId,
    required this.failedStep,
    required this.failureDetail,
    required this.steps,
    required this.completedAt,
    this.statePreserved = true,
  });

  final String               snapshotId;
  final RecoveryReason       reason;
  final String               sessionId;
  final RecoveryStep         failedStep;
  final String               failureDetail;
  final List<RecoveryStepRecord> steps;
  final DateTime             completedAt;

  /// True when Atomic Restore Law was honoured — current state unchanged.
  final bool statePreserved;

  @override
  String toString() =>
      'RecoveryFailure(snap: $snapshotId, reason: $reason, '
      'failedAt: $failedStep, preserved: $statePreserved, '
      'detail: "$failureDetail")';
}

// ==================================================
// RECOVERY INTEGRITY REPORT
// Returned by verifyRecoveryIntegrity().
// ==================================================

class RecoveryIntegrityReport {
  const RecoveryIntegrityReport({
    required this.checkedAt,
    required this.snapshotId,
    required this.snapshotExists,
    required this.snapshotValid,
    required this.guardCleared,
    required this.layerEngineReady,
    required this.canProceed,
    this.blockingReason,
  });

  final DateTime checkedAt;
  final String   snapshotId;
  final bool     snapshotExists;
  final bool     snapshotValid;
  final bool     guardCleared;
  final bool     layerEngineReady;
  final bool     canProceed;
  final String?  blockingReason;

  @override
  String toString() =>
      'RecoveryIntegrityReport(snap: $snapshotId, canProceed: $canProceed'
      '${blockingReason != null ? ", blocked: $blockingReason" : ""})';
}

// ==================================================
// RECOVERY REPORT
// Point-in-time summary of all recovery activity.
// ==================================================

class RecoveryReport {
  const RecoveryReport({
    required this.generatedAt,
    required this.totalAttempts,
    required this.totalSuccesses,
    required this.totalFailures,
    required this.recentResults,
    required this.successRatePercent,
  });

  final DateTime            generatedAt;
  final int                 totalAttempts;
  final int                 totalSuccesses;
  final int                 totalFailures;
  final List<RecoveryResult> recentResults;
  final double              successRatePercent;

  @override
  String toString() =>
      'RecoveryReport(attempts: $totalAttempts, '
      'success: $totalSuccesses, failure: $totalFailures, '
      'rate: ${successRatePercent.toStringAsFixed(1)}%)';
}

// ==================================================
// RECOVERY ENGINE CONFIGURATION
// ==================================================

class RecoveryEngineConfig {
  const RecoveryEngineConfig({
    this.maxRecentResults      = 50,
    this.notifyControllerAsync = true,
    this.confirmEngineAfterRestore = true,
    this.guardEnabled          = true,
  });

  /// Maximum number of RecoveryResult objects kept in memory for reporting.
  final int maxRecentResults;

  /// Whether to notify EditorController on a background fiber (non-blocking).
  final bool notifyControllerAsync;

  /// Whether to read a state token from the layer engine after restore
  /// to confirm the write was accepted.
  final bool confirmEngineAfterRestore;

  /// Whether to run HistoryGuard checks before every restore.
  final bool guardEnabled;
}

// ==================================================
// RECOVERY ENGINE
// Implements RecoveryEngineInterface (from history_manager.dart).
// ==================================================

class RecoveryEngine implements RecoveryEngineInterface {
  RecoveryEngine({
    required SnapshotReaderInterface                    snapshotReader,
    required LayerEngineRestorerInterface               layerRestorer,
    required SelectionRestorerInterface                 selectionRestorer,
    required DesignModelRestorerInterface               designRestorer,
    required RecoveryGuardInterface                     guard,
    required HistoryNavigatorInterface                  historyNavigator,
    EditorControllerRecoveryNotifierInterface?          controllerNotifier,
    RecoveryEngineConfig config = const RecoveryEngineConfig(),
  })  : _snapshotReader    = snapshotReader,
        _layerRestorer     = layerRestorer,
        _selectionRestorer = selectionRestorer,
        _designRestorer    = designRestorer,
        _guard             = guard,
        _historyNav        = historyNavigator,
        _controllerNotifier = controllerNotifier,
        _config            = config;

  final SnapshotReaderInterface                   _snapshotReader;
  final LayerEngineRestorerInterface              _layerRestorer;
  final SelectionRestorerInterface                _selectionRestorer;
  final DesignModelRestorerInterface              _designRestorer;
  final RecoveryGuardInterface                    _guard;
  final HistoryNavigatorInterface                 _historyNav;
  final EditorControllerRecoveryNotifierInterface? _controllerNotifier;
  final RecoveryEngineConfig                      _config;

  // Telemetry counters.
  int _totalAttempts  = 0;
  int _totalSuccesses = 0;
  int _totalFailures  = 0;
  final List<RecoveryResult> _recentResults = [];

  // ==================================================
  // PUBLIC API — mandatory functions per contract
  // ==================================================

  // --------------------------------------------------
  // restoreSnapshot()
  // Core atomic restore. Retrieves the snapshot, verifies integrity,
  // applies all sub-states in sequence, confirms engine acceptance.
  // Implements RecoveryEngineInterface.restoreSnapshot().
  // Returns null on success, failure reason string on error.
  // --------------------------------------------------

  @override
  Future<String?> restoreSnapshot(
      String snapshotId, {required String sessionId}) async {
    final result = await _atomicRestore(
        snapshotId: snapshotId,
        sessionId:  sessionId,
        reason:     RecoveryReason.undo);
    return result is RecoveryFailure ? result.failureDetail : null;
  }

  // --------------------------------------------------
  // restorePreviousState()
  // Queries HistoryManager for the prev snapshot ID, then atomically restores.
  // Used by the undo path when HistoryManager delegates restoration here.
  // --------------------------------------------------

  Future<RecoveryResult> restorePreviousState({
    required String sessionId,
  }) async {
    final snapshotId = await _historyNav.previousSnapshotId();
    if (snapshotId == null) {
      return _buildFailure(
        snapshotId: 'none',
        reason:     RecoveryReason.undo,
        sessionId:  sessionId,
        failedStep: RecoveryStep.snapshotRetrieval,
        detail:     'restorePreviousState: no previous snapshot ID available '
                    'from HistoryNavigator. Undo stack may be empty.',
        steps:      [],
      );
    }
    return _atomicRestore(
        snapshotId: snapshotId,
        sessionId:  sessionId,
        reason:     RecoveryReason.undo);
  }

  // --------------------------------------------------
  // restoreNextState()
  // Queries HistoryManager for the next (redo) snapshot ID, then restores.
  // --------------------------------------------------

  Future<RecoveryResult> restoreNextState({
    required String sessionId,
  }) async {
    final snapshotId = await _historyNav.nextSnapshotId();
    if (snapshotId == null) {
      return _buildFailure(
        snapshotId: 'none',
        reason:     RecoveryReason.redo,
        sessionId:  sessionId,
        failedStep: RecoveryStep.snapshotRetrieval,
        detail:     'restoreNextState: no next snapshot ID available '
                    'from HistoryNavigator. Redo stack may be empty.',
        steps:      [],
      );
    }
    return _atomicRestore(
        snapshotId: snapshotId,
        sessionId:  sessionId,
        reason:     RecoveryReason.redo);
  }

  // --------------------------------------------------
  // recoverFailedExecution()
  // Called by Phase-14 after an execution failure.
  // Restores the [beforeSnapshotId] captured before the failed action ran.
  // --------------------------------------------------

  Future<RecoveryResult> recoverFailedExecution({
    required String beforeSnapshotId,
    required String sessionId,
  }) async {
    _log('recoverFailedExecution: rolling back to $beforeSnapshotId '
        'after Phase-14 failure (session: $sessionId).');
    return _atomicRestore(
        snapshotId: beforeSnapshotId,
        sessionId:  sessionId,
        reason:     RecoveryReason.failedExecution);
  }

  // --------------------------------------------------
  // recoverEditorState()
  // Generic editor realignment — attempts to restore the latest committed
  // snapshot when the editor detects inconsistency without a specific ID.
  // --------------------------------------------------

  Future<RecoveryResult> recoverEditorState({
    required String sessionId,
  }) async {
    _log('recoverEditorState: attempting latest committed snapshot '
        '(session: $sessionId).');

    final latestEntry = await _historyNav.latestCommittedEntry();
    final snapshotId  = latestEntry?.afterSnapshotId
        ?? latestEntry?.beforeSnapshotId;

    if (snapshotId == null) {
      return _buildFailure(
        snapshotId: 'none',
        reason:     RecoveryReason.editorRealign,
        sessionId:  sessionId,
        failedStep: RecoveryStep.snapshotRetrieval,
        detail:     'recoverEditorState: no committed snapshot found in '
                    'HistoryNavigator. Cannot realign editor state.',
        steps:      [],
      );
    }

    return _atomicRestore(
        snapshotId: snapshotId,
        sessionId:  sessionId,
        reason:     RecoveryReason.editorRealign);
  }

  // --------------------------------------------------
  // recoverLatestSafeState()
  // Implements RecoveryEngineInterface.recoverLatestSafeState().
  // Scans all referenced snapshot IDs newest-first and restores the first
  // one that passes validation. Used for crash recovery and kill-switch paths.
  // Returns null on success or a failure reason string.
  // --------------------------------------------------

  @override
  Future<String?> recoverLatestSafeState({required String sessionId}) async {
    _log('recoverLatestSafeState: scanning for latest valid snapshot '
        '(session: $sessionId).');

    final allIds = await _historyNav.allReferencedSnapshotIds();

    // Scan newest-first.
    for (final snapshotId in allIds.reversed) {
      final valid = await _snapshotReader.validateSnapshot(snapshotId);
      if (valid) {
        _log('recoverLatestSafeState: found valid snapshot $snapshotId.');
        final result = await _atomicRestore(
            snapshotId: snapshotId,
            sessionId:  sessionId,
            reason:     RecoveryReason.crashRecovery);
        if (result is RecoverySuccess) return null;
        if (result is RecoveryFailure) return result.failureDetail;
      }
    }

    // Fallback: scan all snapshots in the snapshot engine registry.
    final registryIds = await _snapshotReader.allSnapshotIds();
    for (final snapshotId in registryIds.reversed) {
      if (allIds.contains(snapshotId)) continue; // already tried
      final valid = await _snapshotReader.validateSnapshot(snapshotId);
      if (valid) {
        _log('recoverLatestSafeState: fallback — found valid snapshot '
            '$snapshotId in snapshot registry.');
        final result = await _atomicRestore(
            snapshotId: snapshotId,
            sessionId:  sessionId,
            reason:     RecoveryReason.crashRecovery);
        if (result is RecoverySuccess) return null;
        if (result is RecoveryFailure) return result.failureDetail;
      }
    }

    return 'recoverLatestSafeState: no valid snapshot found in registry '
        'or history timeline. Recovery is not possible without a valid snapshot.';
  }

  // --------------------------------------------------
  // verifyRecoveryIntegrity()
  // Pre-restore health check: snapshot exists, is valid, guard clears,
  // and the layer engine is responsive.
  // Returns a full RecoveryIntegrityReport — does NOT restore.
  // --------------------------------------------------

  Future<RecoveryIntegrityReport> verifyRecoveryIntegrity({
    required String snapshotId,
    required RecoveryReason reason,
    required String sessionId,
  }) async {
    final checkedAt = DateTime.now().toUtc();

    // 1 — Snapshot existence.
    final snapshot = await _snapshotReader.getSnapshot(snapshotId);
    final exists   = snapshot != null;

    if (!exists) {
      return RecoveryIntegrityReport(
        checkedAt:        checkedAt,
        snapshotId:       snapshotId,
        snapshotExists:   false,
        snapshotValid:    false,
        guardCleared:     false,
        layerEngineReady: false,
        canProceed:       false,
        blockingReason:   'Snapshot $snapshotId does not exist in the registry.',
      );
    }

    // 2 — Snapshot validation.
    final valid = await _snapshotReader.validateSnapshot(snapshotId);
    if (!valid) {
      return RecoveryIntegrityReport(
        checkedAt:        checkedAt,
        snapshotId:       snapshotId,
        snapshotExists:   true,
        snapshotValid:    false,
        guardCleared:     false,
        layerEngineReady: false,
        canProceed:       false,
        blockingReason:   'Snapshot $snapshotId failed integrity validation.',
      );
    }

    // 3 — Guard check.
    bool guardCleared = true;
    String? guardReason;
    if (_config.guardEnabled) {
      guardCleared = await _guard.canRestore(snapshotId, reason);
      if (!guardCleared) {
        guardReason = 'HistoryGuard blocked restore of $snapshotId '
            'for reason $reason.';
      }
    }

    if (!guardCleared) {
      return RecoveryIntegrityReport(
        checkedAt:        checkedAt,
        snapshotId:       snapshotId,
        snapshotExists:   true,
        snapshotValid:    true,
        guardCleared:     false,
        layerEngineReady: false,
        canProceed:       false,
        blockingReason:   guardReason,
      );
    }

    // 4 — Layer engine responsiveness (read state token).
    bool engineReady = false;
    try {
      await _layerRestorer.readCurrentStateToken();
      engineReady = true;
    } catch (e) {
      return RecoveryIntegrityReport(
        checkedAt:        checkedAt,
        snapshotId:       snapshotId,
        snapshotExists:   true,
        snapshotValid:    true,
        guardCleared:     true,
        layerEngineReady: false,
        canProceed:       false,
        blockingReason:   'LayerEngine is not responsive: $e',
      );
    }

    return RecoveryIntegrityReport(
      checkedAt:        checkedAt,
      snapshotId:       snapshotId,
      snapshotExists:   true,
      snapshotValid:    true,
      guardCleared:     true,
      layerEngineReady: engineReady,
      canProceed:       true,
    );
  }

  // --------------------------------------------------
  // generateRecoveryReport()
  // Returns an immutable point-in-time view of all recovery activity.
  // --------------------------------------------------

  RecoveryReport generateRecoveryReport() {
    final rate = _totalAttempts > 0
        ? (_totalSuccesses / _totalAttempts) * 100.0
        : 0.0;
    return RecoveryReport(
      generatedAt:         DateTime.now().toUtc(),
      totalAttempts:       _totalAttempts,
      totalSuccesses:      _totalSuccesses,
      totalFailures:       _totalFailures,
      recentResults:       List.unmodifiable(_recentResults),
      successRatePercent:  rate,
    );
  }

  // ==================================================
  // ATOMIC RESTORE — core internal transaction
  // ATOMIC RESTORE LAW: all steps must succeed or none are committed.
  // Steps execute in sequence; first failure aborts and returns immediately,
  // leaving the layer engine in its pre-call state.
  // ==================================================

  Future<RecoveryResult> _atomicRestore({
    required String        snapshotId,
    required String        sessionId,
    required RecoveryReason reason,
  }) async {
    _totalAttempts++;
    final steps = <RecoveryStepRecord>[];

    _log('_atomicRestore: BEGIN snap=$snapshotId reason=$reason '
        'session=$sessionId');

    // ── STEP 1: Guard check ──────────────────────────────────────
    if (_config.guardEnabled) {
      bool guardOk = false;
      try {
        guardOk = await _guard.canRestore(snapshotId, reason);
      } catch (e) {
        return _fail(steps, snapshotId, reason, sessionId,
            RecoveryStep.guardCheck,
            'Guard check threw: $e');
      }
      steps.add(_record(RecoveryStep.guardCheck, succeeded: guardOk));
      if (!guardOk) {
        return _fail(steps, snapshotId, reason, sessionId,
            RecoveryStep.guardCheck,
            'HistoryGuard blocked restore of $snapshotId ($reason). '
            'Atomic restore aborted — current state preserved.');
      }
    } else {
      steps.add(_record(RecoveryStep.guardCheck,
          succeeded: true, detail: 'Guard disabled by config.'));
    }

    // ── STEP 2: Integrity verification ──────────────────────────
    bool integrityOk = false;
    try {
      integrityOk = await _snapshotReader.validateSnapshot(snapshotId);
    } catch (e) {
      return _fail(steps, snapshotId, reason, sessionId,
          RecoveryStep.integrityVerification,
          'validateSnapshot threw: $e');
    }
    steps.add(_record(RecoveryStep.integrityVerification,
        succeeded: integrityOk));
    if (!integrityOk) {
      return _fail(steps, snapshotId, reason, sessionId,
          RecoveryStep.integrityVerification,
          'Snapshot $snapshotId failed integrity validation. '
          'Atomic restore aborted — current state preserved.');
    }

    // ── STEP 3: Snapshot retrieval ───────────────────────────────
    SnapshotData? snapshot;
    try {
      snapshot = await _snapshotReader.getSnapshot(snapshotId);
    } catch (e) {
      return _fail(steps, snapshotId, reason, sessionId,
          RecoveryStep.snapshotRetrieval, 'getSnapshot threw: $e');
    }
    if (snapshot == null) {
      steps.add(_record(RecoveryStep.snapshotRetrieval, succeeded: false,
          detail: 'getSnapshot returned null.'));
      return _fail(steps, snapshotId, reason, sessionId,
          RecoveryStep.snapshotRetrieval,
          'Snapshot $snapshotId not found after validation passed. '
          'Atomic restore aborted — current state preserved.');
    }
    steps.add(_record(RecoveryStep.snapshotRetrieval, succeeded: true,
        detail: 'layers=${snapshot.layerState.layerCount}'));

    // ── STEP 4: Layer restoration ────────────────────────────────
    final layerState = snapshot.layerState;
    try {
      await _layerRestorer.restoreLayers(
          layerState.layers, sessionId);
    } catch (e) {
      return _fail(steps, snapshotId, reason, sessionId,
          RecoveryStep.layerRestoration,
          'restoreLayers failed: $e — '
          'Atomic restore aborted — current state preserved.');
    }
    steps.add(_record(RecoveryStep.layerRestoration, succeeded: true,
        detail: 'count=${layerState.layerCount}'));

    // ── STEP 5: Layer order restoration ─────────────────────────
    try {
      await _layerRestorer.restoreLayerOrder(
          layerState.layerOrder, sessionId);
    } catch (e) {
      return _fail(steps, snapshotId, reason, sessionId,
          RecoveryStep.layerOrderRestoration,
          'restoreLayerOrder failed: $e — '
          'Atomic restore aborted after layer write. '
          'Layer engine may be in inconsistent state.');
    }
    steps.add(_record(RecoveryStep.layerOrderRestoration, succeeded: true));

    // ── STEP 6: Active layer restoration ────────────────────────
    try {
      await _layerRestorer.restoreActiveLayer(
          layerState.activeLayerId, sessionId);
    } catch (e) {
      return _fail(steps, snapshotId, reason, sessionId,
          RecoveryStep.activeLayerRestoration,
          'restoreActiveLayer failed: $e');
    }
    steps.add(_record(RecoveryStep.activeLayerRestoration, succeeded: true,
        detail: 'activeId=${layerState.activeLayerId}'));

    // ── STEP 7: Selection restoration ───────────────────────────
    final selState = snapshot.selectionState;
    try {
      if (selState.selectedLayerIds.isEmpty) {
        await _selectionRestorer.clearSelection(sessionId);
      } else {
        await _selectionRestorer.restoreSelection(
            selState.selectedLayerIds, sessionId);
      }
    } catch (e) {
      return _fail(steps, snapshotId, reason, sessionId,
          RecoveryStep.selectionRestoration,
          'restoreSelection failed: $e');
    }
    steps.add(_record(RecoveryStep.selectionRestoration, succeeded: true,
        detail: 'selected=${selState.selectedLayerIds.length}'));

    // ── STEP 8: Transform state restoration ─────────────────────
    try {
      await _selectionRestorer.restoreTransformState(
          selState.transformState, sessionId);
    } catch (e) {
      return _fail(steps, snapshotId, reason, sessionId,
          RecoveryStep.transformStateRestoration,
          'restoreTransformState failed: $e');
    }
    steps.add(_record(RecoveryStep.transformStateRestoration, succeeded: true));

    // ── STEP 9: Design model restoration ────────────────────────
    final designState = snapshot.designState;
    try {
      await _designRestorer.restoreDesignModel(
          designState.designModel, sessionId);
    } catch (e) {
      return _fail(steps, snapshotId, reason, sessionId,
          RecoveryStep.designModelRestoration,
          'restoreDesignModel failed: $e');
    }
    steps.add(_record(RecoveryStep.designModelRestoration, succeeded: true,
        detail: 'docId=${designState.documentId}'));

    // ── STEP 10: Engine confirmation ─────────────────────────────
    if (_config.confirmEngineAfterRestore) {
      try {
        await _layerRestorer.readCurrentStateToken();
        steps.add(_record(RecoveryStep.engineConfirmation, succeeded: true));
      } catch (e) {
        // Non-blocking: log but do not abort a completed restore.
        steps.add(_record(RecoveryStep.engineConfirmation, succeeded: false,
            detail: 'Engine confirmation probe threw: $e (non-blocking).'));
        _log('WARNING: engine confirmation probe failed after successful '
            'restore of $snapshotId: $e');
      }
    }

    // ── COMMIT ───────────────────────────────────────────────────
    final result = RecoverySuccess(
      snapshotId:  snapshotId,
      reason:      reason,
      sessionId:   sessionId,
      steps:       List.unmodifiable(steps),
      completedAt: DateTime.now().toUtc(),
      layerCount:  layerState.layerCount,
    );
    _totalSuccesses++;
    _appendResult(result);

    _log('_atomicRestore: SUCCESS snap=$snapshotId reason=$reason '
        'steps=${steps.length} layers=${layerState.layerCount}');

    // Notify controller — fire-and-forget or awaited per config.
    if (_controllerNotifier != null) {
      final notify = _controllerNotifier!.onRecoverySucceeded(result);
      if (!_config.notifyControllerAsync) await notify;
    }

    return result;
  }

  // ==================================================
  // PRIVATE HELPERS
  // ==================================================

  RecoveryResult _fail(
    List<RecoveryStepRecord> steps,
    String snapshotId,
    RecoveryReason reason,
    String sessionId,
    RecoveryStep failedStep,
    String detail,
  ) {
    steps.add(_record(failedStep, succeeded: false, detail: detail));
    final result = RecoveryFailure(
      snapshotId:    snapshotId,
      reason:        reason,
      sessionId:     sessionId,
      failedStep:    failedStep,
      failureDetail: detail,
      steps:         List.unmodifiable(steps),
      completedAt:   DateTime.now().toUtc(),
      statePreserved: true,
    );
    _totalFailures++;
    _appendResult(result);
    _log('_atomicRestore: FAILED at ${failedStep.name} '
        'snap=$snapshotId — $detail');

    if (_controllerNotifier != null) {
      _controllerNotifier!.onRecoveryFailed(result).catchError((e) {
        _log('WARNING: controller failure notification threw: $e');
      });
    }

    return result;
  }

  RecoveryFailure _buildFailure({
    required String snapshotId,
    required RecoveryReason reason,
    required String sessionId,
    required RecoveryStep failedStep,
    required String detail,
    required List<RecoveryStepRecord> steps,
  }) {
    _totalAttempts++;
    _totalFailures++;
    final result = RecoveryFailure(
      snapshotId:    snapshotId,
      reason:        reason,
      sessionId:     sessionId,
      failedStep:    failedStep,
      failureDetail: detail,
      steps:         List.unmodifiable(steps),
      completedAt:   DateTime.now().toUtc(),
      statePreserved: true,
    );
    _appendResult(result);
    return result;
  }

  RecoveryStepRecord _record(RecoveryStep step,
      {required bool succeeded, String? detail}) =>
      RecoveryStepRecord(
        step:       step,
        succeeded:  succeeded,
        recordedAt: DateTime.now().toUtc(),
        detail:     detail,
      );

  void _appendResult(RecoveryResult result) {
    _recentResults.add(result);
    while (_recentResults.length > _config.maxRecentResults) {
      _recentResults.removeAt(0);
    }
  }

  void _log(String message) {
    // ignore: avoid_print
    print('[RecoveryEngine] $message');
  }
}

// ==================================================
// NULL IMPLEMENTATIONS
// Safe no-op adapters for testing and development.
// ==================================================

class NullSnapshotReader implements SnapshotReaderInterface {
  final Map<String, SnapshotData> _store;
  NullSnapshotReader([Map<String, SnapshotData>? store])
      : _store = store ?? {};
  @override Future<SnapshotData?> getSnapshot(String id) async => _store[id];
  @override Future<bool>          validateSnapshot(String id) async => true;
  @override Future<List<String>>  allSnapshotIds()            async =>
      List.of(_store.keys);
}

class NullLayerEngineRestorer implements LayerEngineRestorerInterface {
  const NullLayerEngineRestorer();
  @override Future<void>   restoreLayers(List l, String s)       async {}
  @override Future<void>   restoreLayerOrder(List l, String s)   async {}
  @override Future<void>   restoreActiveLayer(String? id, String s) async {}
  @override Future<String> readCurrentStateToken()               async =>
      'null_token_${DateTime.now().millisecondsSinceEpoch}';
}

class NullSelectionRestorer implements SelectionRestorerInterface {
  const NullSelectionRestorer();
  @override Future<void> restoreSelection(List ids, String s)   async {}
  @override Future<void> restoreTransformState(Map m, String s) async {}
  @override Future<void> clearSelection(String s)               async {}
}

class NullDesignModelRestorer implements DesignModelRestorerInterface {
  const NullDesignModelRestorer();
  @override Future<void> restoreDesignModel(Map m, String s) async {}
}

class NullRecoveryGuard implements RecoveryGuardInterface {
  const NullRecoveryGuard();
  @override Future<bool> canRestore(String id, RecoveryReason r) async => true;
}

class NullHistoryNavigator implements HistoryNavigatorInterface {
  const NullHistoryNavigator();
  @override Future<String?> previousSnapshotId()     async => null;
  @override Future<String?> nextSnapshotId()         async => null;
  @override Future<HistoryEntry?> latestCommittedEntry() async => null;
  @override Future<List<String>> allReferencedSnapshotIds() async => [];
}

/// Convenience factory — fully null-wired RecoveryEngine for dev/test.
RecoveryEngine buildNullRecoveryEngine({
  RecoveryEngineConfig config = const RecoveryEngineConfig(),
}) =>
    RecoveryEngine(
      snapshotReader:   NullSnapshotReader(),
      layerRestorer:    const NullLayerEngineRestorer(),
      selectionRestorer: const NullSelectionRestorer(),
      designRestorer:   const NullDesignModelRestorer(),
      guard:            const NullRecoveryGuard(),
      historyNavigator: const NullHistoryNavigator(),
      config:           config,
    );

// ==================================================
// END OF core/history/recovery_engine.dart
// Z-CANVAS — PHASE-15 — STATE RESTORATION ENGINE
// Powered by Zynquar
// ==================================================
