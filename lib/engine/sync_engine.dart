// ignore_for_file: avoid_catches_without_on_clauses

// ============================================================
// SyncEngine — Phase-4 Cloud Communication Authority
// ============================================================
// OWNS: cloud upload/download, template sync, banner sync,
//       design metadata sync, account sync, premium sync.
// MUST NOT: modify layers, history, render state, storage
//           directly, canvas, AI, TemplateEngine, or UI.
// OFFLINE LAW: all failures are isolated — core editor must
//              continue to work with no network present.
// ONLY COMMUNICATES WITH: EditorController (results returned
//                         upward; never calls down to engines).
// ============================================================

import 'dart:async';

// ── Sync types ────────────────────────────────────────────────
enum SyncType {
  templateSync,
  bannerSync,
  designSync,
  accountSync,
  premiumSync,
}

extension SyncTypeLabel on SyncType {
  String get label {
    switch (this) {
      case SyncType.templateSync: return 'template_sync';
      case SyncType.bannerSync:   return 'banner_sync';
      case SyncType.designSync:   return 'design_sync';
      case SyncType.accountSync:  return 'account_sync';
      case SyncType.premiumSync:  return 'premium_sync';
    }
  }

  static SyncType? fromLabel(String raw) {
    const map = {
      'template_sync': SyncType.templateSync,
      'banner_sync':   SyncType.bannerSync,
      'design_sync':   SyncType.designSync,
      'account_sync':  SyncType.accountSync,
      'premium_sync':  SyncType.premiumSync,
    };
    return map[raw.toLowerCase().trim()];
  }
}

// ── Sync status ───────────────────────────────────────────────
enum SyncStatus {
  pending,
  inProgress,
  completed,
  failed,
  skippedOffline,
  skippedNoAuth,
}

// ── Connectivity state ────────────────────────────────────────
enum ConnectivityState { online, offline, unknown }

// ── Online data record — mandatory contract fields ────────────
class SyncRecord {
  final String syncId;
  final String deviceId;
  final String userId;
  final DateTime timestamp;
  final SyncType syncType;
  final Map<String, dynamic> payload;
  final SyncStatus status;

  const SyncRecord({
    required this.syncId,
    required this.deviceId,
    required this.userId,
    required this.timestamp,
    required this.syncType,
    required this.payload,
    required this.status,
  });

  Map<String, dynamic> toMap() => {
        'syncId': syncId,
        'deviceId': deviceId,
        'userId': userId,
        'timestamp': timestamp.toIso8601String(),
        'syncType': syncType.label,
        'payload': payload,
        'status': status.name,
      };

  SyncRecord copyWith({SyncStatus? status}) => SyncRecord(
        syncId: syncId,
        deviceId: deviceId,
        userId: userId,
        timestamp: timestamp,
        syncType: syncType,
        payload: payload,
        status: status ?? this.status,
      );
}

// ── Sync request ──────────────────────────────────────────────
class SyncRequest {
  final String requestId;
  final SyncType syncType;
  final String deviceId;
  final String userId;
  final Map<String, dynamic> metadata;
  final DateTime requestedAt;

  const SyncRequest({
    required this.requestId,
    required this.syncType,
    required this.deviceId,
    required this.userId,
    this.metadata = const {},
    required this.requestedAt,
  });
}

// ── Sync result ───────────────────────────────────────────────
class SyncResult {
  final bool success;
  final SyncStatus status;
  final SyncRecord? record;
  final List<Map<String, dynamic>> receivedPayloads;
  final List<String> errors;
  final List<String> warnings;
  final bool wasOffline;

  const SyncResult._({
    required this.success,
    required this.status,
    this.record,
    this.receivedPayloads = const [],
    this.errors = const [],
    this.warnings = const [],
    this.wasOffline = false,
  });

  factory SyncResult.completed({
    required SyncRecord record,
    List<Map<String, dynamic>> receivedPayloads = const [],
    List<String> warnings = const [],
  }) =>
      SyncResult._(
        success: true,
        status: SyncStatus.completed,
        record: record,
        receivedPayloads: receivedPayloads,
        warnings: warnings,
      );

  factory SyncResult.skippedOffline({
    required SyncType syncType,
    List<String> warnings = const [],
  }) =>
      SyncResult._(
        success: true, // offline skip is NOT a failure
        status: SyncStatus.skippedOffline,
        wasOffline: true,
        warnings: [
          'Sync skipped: device is offline. '
              'Core editor continues unaffected.',
          ...warnings,
        ],
      );

  factory SyncResult.skippedNoAuth({List<String> warnings = const []}) =>
      SyncResult._(
        success: true, // auth absent is NOT a fatal failure
        status: SyncStatus.skippedNoAuth,
        warnings: [
          'Sync skipped: no authenticated user. '
              'Core editor continues unaffected.',
          ...warnings,
        ],
      );

  factory SyncResult.failure({
    required List<String> errors,
    SyncRecord? record,
    List<String> warnings = const [],
  }) =>
      SyncResult._(
        success: false,
        status: SyncStatus.failed,
        record: record,
        errors: errors,
        warnings: warnings,
      );
}

// ── Sync validation result ────────────────────────────────────
class SyncValidationResult {
  final bool valid;
  final List<String> errors;
  final List<String> warnings;

  const SyncValidationResult.ok({this.warnings = const []})
      : valid = true,
        errors = const [];

  const SyncValidationResult.fail(this.errors,
      {this.warnings = const []})
      : valid = false;
}

// ── Abstract cloud client ─────────────────────────────────────
// SyncEngine never performs raw HTTP calls; it delegates to this
// interface. Implementations may wrap http, dio, or a mock.
// This keeps SyncEngine testable and platform-agnostic.
abstract class CloudClient {
  /// Upload a sync record to the cloud.
  Future<CloudResponse> upload(SyncRecord record);

  /// Download a list of cloud items for a given sync type.
  Future<CloudResponse> download(SyncType syncType, Map<String, String> params);

  /// Check whether the client can reach the cloud right now.
  Future<ConnectivityState> checkConnectivity();
}

class CloudResponse {
  final bool ok;
  final int statusCode;
  final List<Map<String, dynamic>> items;
  final String? errorMessage;

  const CloudResponse({
    required this.ok,
    required this.statusCode,
    this.items = const [],
    this.errorMessage,
  });

  factory CloudResponse.networkError(String message) => CloudResponse(
        ok: false,
        statusCode: 0,
        errorMessage: message,
      );
}

// ── No-op offline cloud client (safe default) ─────────────────
// Returns offline/skipped responses immediately without any I/O.
class OfflineCloudClient implements CloudClient {
  const OfflineCloudClient();

  @override
  Future<ConnectivityState> checkConnectivity() async =>
      ConnectivityState.offline;

  @override
  Future<CloudResponse> upload(SyncRecord record) async =>
      const CloudResponse(ok: false, statusCode: 0,
          errorMessage: 'No network — using offline client.');

  @override
  Future<CloudResponse> download(
          SyncType syncType, Map<String, String> params) async =>
      const CloudResponse(ok: false, statusCode: 0,
          errorMessage: 'No network — using offline client.');
}

// ── UUID-like ID generator ─────────────────────────────────────
class _SyncIdGen {
  static int _counter = 0;

  static String next(String prefix) {
    final ts = DateTime.now().microsecondsSinceEpoch;
    _counter = (_counter + 1) % 0xFFFF;
    return '$prefix-$ts-$_counter';
  }
}

// ── SyncEngine ────────────────────────────────────────────────
class SyncEngine {
  final CloudClient _client;
  final String deviceId;

  /// Pending records awaiting upload (retained for retry on reconnect).
  final List<SyncRecord> _pendingQueue = [];

  SyncEngine({
    required this.deviceId,
    CloudClient? client,
  }) : _client = client ?? const OfflineCloudClient();

  // ── Connectivity probe ────────────────────────────────────────

  Future<ConnectivityState> checkConnectivity() async {
    try {
      return await _client
          .checkConnectivity()
          .timeout(const Duration(seconds: 5),
              onTimeout: () => ConnectivityState.unknown);
    } catch (_) {
      return ConnectivityState.offline;
    }
  }

  bool get hasPendingItems => _pendingQueue.isNotEmpty;
  List<SyncRecord> get pendingQueue => List.unmodifiable(_pendingQueue);

  // ── Template sync ─────────────────────────────────────────────

  /// Downloads available templates from the cloud.
  /// Returns `skippedOffline` gracefully — editor is never blocked.
  Future<SyncResult> syncTemplates(SyncRequest request) async {
    final validation = validateSyncRequest(request, SyncType.templateSync);
    if (!validation.valid) {
      return SyncResult.failure(errors: validation.errors,
          warnings: validation.warnings);
    }

    final connectivity = await checkConnectivity();
    if (connectivity == ConnectivityState.offline) {
      return SyncResult.skippedOffline(syncType: SyncType.templateSync);
    }

    if (request.userId.trim().isEmpty) {
      return SyncResult.skippedNoAuth();
    }

    return _performDownloadSync(
      request: request,
      syncType: SyncType.templateSync,
      params: {
        'userId': request.userId,
        'deviceId': deviceId,
        ...request.metadata.map((k, v) => MapEntry(k, v.toString())),
      },
    );
  }

  // ── Banner sync ───────────────────────────────────────────────

  /// Downloads available banners from the cloud.
  Future<SyncResult> syncBanners(SyncRequest request) async {
    final validation = validateSyncRequest(request, SyncType.bannerSync);
    if (!validation.valid) {
      return SyncResult.failure(errors: validation.errors,
          warnings: validation.warnings);
    }

    final connectivity = await checkConnectivity();
    if (connectivity == ConnectivityState.offline) {
      return SyncResult.skippedOffline(syncType: SyncType.bannerSync);
    }

    if (request.userId.trim().isEmpty) {
      return SyncResult.skippedNoAuth();
    }

    return _performDownloadSync(
      request: request,
      syncType: SyncType.bannerSync,
      params: {
        'userId': request.userId,
        'deviceId': deviceId,
        ...request.metadata.map((k, v) => MapEntry(k, v.toString())),
      },
    );
  }

  // ── Cloud design sync ─────────────────────────────────────────

  /// Uploads design metadata to the cloud.
  /// NEVER uploads layer state — only metadata is transmitted.
  Future<SyncResult> syncCloudDesigns(
      SyncRequest request, Map<String, dynamic> designMetadata) async {
    final validation = validateSyncRequest(request, SyncType.designSync);
    if (!validation.valid) {
      return SyncResult.failure(errors: validation.errors,
          warnings: validation.warnings);
    }

    final metaValidation = _validateDesignMetadata(designMetadata);
    if (!metaValidation.valid) {
      return SyncResult.failure(errors: metaValidation.errors,
          warnings: metaValidation.warnings);
    }

    final connectivity = await checkConnectivity();
    if (connectivity == ConnectivityState.offline) {
      // Queue the record for retry when connectivity is restored.
      final queued = _buildRecord(
        request: request,
        syncType: SyncType.designSync,
        payload: designMetadata,
        status: SyncStatus.pending,
      );
      _pendingQueue.add(queued);
      return SyncResult.skippedOffline(
        syncType: SyncType.designSync,
        warnings: ['Design metadata queued for upload when online.'],
      );
    }

    if (request.userId.trim().isEmpty) {
      return SyncResult.skippedNoAuth();
    }

    return _performUploadSync(
      request: request,
      syncType: SyncType.designSync,
      payload: designMetadata,
    );
  }

  // ── Account sync ──────────────────────────────────────────────

  /// Downloads account data and cloud configs for the user.
  Future<SyncResult> syncAccount(SyncRequest request) async {
    final validation = validateSyncRequest(request, SyncType.accountSync);
    if (!validation.valid) {
      return SyncResult.failure(errors: validation.errors,
          warnings: validation.warnings);
    }

    final connectivity = await checkConnectivity();
    if (connectivity == ConnectivityState.offline) {
      return SyncResult.skippedOffline(syncType: SyncType.accountSync);
    }

    if (request.userId.trim().isEmpty) {
      return SyncResult.skippedNoAuth();
    }

    return _performDownloadSync(
      request: request,
      syncType: SyncType.accountSync,
      params: {
        'userId': request.userId,
        'deviceId': deviceId,
      },
    );
  }

  // ── Premium sync ──────────────────────────────────────────────

  /// Downloads premium status and entitlements for the user.
  Future<SyncResult> syncPremiumStatus(SyncRequest request) async {
    final validation = validateSyncRequest(request, SyncType.premiumSync);
    if (!validation.valid) {
      return SyncResult.failure(errors: validation.errors,
          warnings: validation.warnings);
    }

    final connectivity = await checkConnectivity();
    if (connectivity == ConnectivityState.offline) {
      return SyncResult.skippedOffline(syncType: SyncType.premiumSync);
    }

    if (request.userId.trim().isEmpty) {
      return SyncResult.skippedNoAuth();
    }

    return _performDownloadSync(
      request: request,
      syncType: SyncType.premiumSync,
      params: {
        'userId': request.userId,
        'deviceId': deviceId,
      },
    );
  }

  // ── Retry pending queue ────────────────────────────────────────

  /// Retries all queued records. Should be called by EditorController
  /// when connectivity is detected. Failed items remain in queue.
  Future<List<SyncResult>> retryPendingQueue(String userId) async {
    if (_pendingQueue.isEmpty) return [];

    final connectivity = await checkConnectivity();
    if (connectivity == ConnectivityState.offline) {
      return [SyncResult.skippedOffline(syncType: SyncType.designSync)];
    }

    final results = <SyncResult>[];
    final completed = <SyncRecord>[];

    for (final record in List.of(_pendingQueue)) {
      try {
        final updated = record.copyWith(status: SyncStatus.inProgress);
        final response = await _client
            .upload(updated)
            .timeout(const Duration(seconds: 30),
                onTimeout: () =>
                    CloudResponse.networkError('Upload timed out.'));

        if (response.ok) {
          completed.add(record);
          results.add(SyncResult.completed(
              record: record.copyWith(status: SyncStatus.completed)));
        } else {
          results.add(SyncResult.failure(
              record: record.copyWith(status: SyncStatus.failed),
              errors: [
                response.errorMessage ??
                    'Cloud returned status ${response.statusCode}.'
              ]));
        }
      } catch (e) {
        results.add(SyncResult.failure(
            record: record.copyWith(status: SyncStatus.failed),
            errors: ['Retry failed: $e']));
      }
    }

    // Remove only successfully uploaded records.
    _pendingQueue.removeWhere((r) => completed.contains(r));

    return results;
  }

  // ── Validation ────────────────────────────────────────────────

  SyncValidationResult validateSyncRequest(
      SyncRequest request, SyncType expectedType) {
    final errors = <String>[];
    final warnings = <String>[];

    if (request.requestId.trim().isEmpty) {
      errors.add('SyncRequest.requestId must not be empty.');
    }
    if (request.deviceId.trim().isEmpty) {
      errors.add('SyncRequest.deviceId must not be empty.');
    }
    if (request.syncType != expectedType) {
      errors.add(
          'SyncRequest.syncType "${request.syncType.label}" does not match '
          'expected type "${expectedType.label}".');
    }
    if (request.userId.trim().isEmpty) {
      warnings.add(
          'SyncRequest.userId is empty — sync will be skipped (no auth).');
    }

    // Payload safety: metadata must not reference forbidden engines.
    const forbidden = [
      'layerengine', 'historyengine', 'renderengine',
      'storageengine', 'aiengine', 'templateengine',
      'buildcontext', 'canvas', 'widget',
    ];
    for (final key in request.metadata.keys) {
      if (forbidden.contains(key.toLowerCase())) {
        errors.add('SyncRequest.metadata key "$key" references a forbidden '
            'engine or context object.');
      }
    }

    if (errors.isEmpty) {
      return SyncValidationResult.ok(warnings: warnings);
    }
    return SyncValidationResult.fail(errors, warnings: warnings);
  }

  SyncValidationResult _validateDesignMetadata(
      Map<String, dynamic> metadata) {
    final errors = <String>[];
    final warnings = <String>[];

    if (metadata.isEmpty) {
      errors.add('Design metadata payload must not be empty.');
    }

    // Forbidden: layer state, history, render state must never leave device.
    const bannedKeys = [
      'layers', 'layerstate', 'history', 'undostack', 'redostack',
      'renderinstructions', 'rendertree', 'canvas', 'buildcontext',
    ];
    for (final key in metadata.keys) {
      if (bannedKeys.contains(key.toLowerCase())) {
        errors.add(
            'Design metadata must not include "$key". '
            'Layer state, history, and render data must never be synced.');
      }
    }

    // Required identity fields.
    if (!metadata.containsKey('designId') ||
        (metadata['designId'] as String?)?.trim().isEmpty == true) {
      errors.add('Design metadata must include a non-empty "designId".');
    }
    if (!metadata.containsKey('title')) {
      warnings.add('Design metadata missing "title" field.');
    }

    if (errors.isEmpty) {
      return SyncValidationResult.ok(warnings: warnings);
    }
    return SyncValidationResult.fail(errors, warnings: warnings);
  }

  // ── Private pipeline helpers ──────────────────────────────────

  Future<SyncResult> _performUploadSync({
    required SyncRequest request,
    required SyncType syncType,
    required Map<String, dynamic> payload,
  }) async {
    final record = _buildRecord(
      request: request,
      syncType: syncType,
      payload: payload,
      status: SyncStatus.inProgress,
    );

    try {
      final response = await _client
          .upload(record)
          .timeout(const Duration(seconds: 30),
              onTimeout: () =>
                  CloudResponse.networkError('Upload timed out after 30s.'));

      if (response.ok) {
        final done = record.copyWith(status: SyncStatus.completed);
        return SyncResult.completed(record: done);
      }

      final failed = record.copyWith(status: SyncStatus.failed);
      return SyncResult.failure(
        record: failed,
        errors: [
          response.errorMessage ??
              'Cloud upload failed with status ${response.statusCode}.',
        ],
      );
    } catch (e) {
      final failed = record.copyWith(status: SyncStatus.failed);
      return SyncResult.failure(
        record: failed,
        errors: ['Upload exception: $e'],
      );
    }
  }

  Future<SyncResult> _performDownloadSync({
    required SyncRequest request,
    required SyncType syncType,
    required Map<String, String> params,
  }) async {
    final record = _buildRecord(
      request: request,
      syncType: syncType,
      payload: {'params': params},
      status: SyncStatus.inProgress,
    );

    try {
      final response = await _client
          .download(syncType, params)
          .timeout(const Duration(seconds: 30),
              onTimeout: () =>
                  CloudResponse.networkError('Download timed out after 30s.'));

      if (response.ok) {
        final done = record.copyWith(status: SyncStatus.completed);
        return SyncResult.completed(
          record: done,
          receivedPayloads: response.items,
        );
      }

      final failed = record.copyWith(status: SyncStatus.failed);
      return SyncResult.failure(
        record: failed,
        errors: [
          response.errorMessage ??
              'Cloud download failed with status ${response.statusCode}.',
        ],
      );
    } catch (e) {
      final failed = record.copyWith(status: SyncStatus.failed);
      return SyncResult.failure(
        record: failed,
        errors: ['Download exception: $e'],
      );
    }
  }

  SyncRecord _buildRecord({
    required SyncRequest request,
    required SyncType syncType,
    required Map<String, dynamic> payload,
    required SyncStatus status,
  }) {
    return SyncRecord(
      syncId: _SyncIdGen.next(syncType.label),
      deviceId: deviceId,
      userId: request.userId,
      timestamp: DateTime.now().toUtc(),
      syncType: syncType,
      payload: Map<String, dynamic>.unmodifiable(payload),
      status: status,
    );
  }
}
