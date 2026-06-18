// ignore_for_file: avoid_catches_without_on_clauses

import 'dart:async';
import 'dart:math';
import 'automation_engine.dart' show CommandObject;

// ── Plugin status ─────────────────────────────────────────────
enum PluginStatus {
  registered,
  active,
  suspended,
  revoked,
  timedOut,
  executionError,
  permissionDenied,
  versionRejected,
}

// ── Plugin log level ──────────────────────────────────────────
enum PluginLogLevel { info, warning, error }

// ── Plugin log entry ──────────────────────────────────────────
class PluginLogEntry {
  final DateTime timestamp;
  final PluginLogLevel level;
  final String message;
  final String pluginId;

  const PluginLogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    required this.pluginId,
  });

  @override
  String toString() =>
      '[${timestamp.toIso8601String()}] [${level.name.toUpperCase()}] '
      '[$pluginId] $message';
}

// ── Permission scopes ─────────────────────────────────────────
enum PluginPermission {
  readDesignMeta,
  readLayerIds,
  addLayer,
  updateLayer,
  deleteLayer,
  moveLayer,
  resizeLayer,
  rotateLayer,
  changeColor,
  changeFont,
  showLayer,
  hideLayer,
  lockLayer,
  unlockLayer,
  applyTemplate,
  batchUpdate,
  reorderLayers,
  selectLayer,
  clearSelection,
  duplicateLayer,
}

extension PluginPermissionLabel on PluginPermission {
  String get label => name;
}

// ── Plugin version ─────────────────────────────────────────────
class PluginVersion {
  final int major;
  final int minor;
  final int patch;

  const PluginVersion(this.major, this.minor, this.patch);

  bool isCompatibleWith(PluginVersion minimum) {
    if (major != minimum.major) return major > minimum.major;
    if (minor != minimum.minor) return minor > minimum.minor;
    return patch >= minimum.patch;
  }

  @override
  String toString() => '$major.$minor.$patch';
}

// ── Security context ──────────────────────────────────────────
class PluginSecurityContext {
  final String issuedTo;
  final DateTime expiresAt;
  final Set<PluginPermission> grantedPermissions;
  final bool sandboxed;

  const PluginSecurityContext({
    required this.issuedTo,
    required this.expiresAt,
    required this.grantedPermissions,
    this.sandboxed = true,
  });

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

  bool hasPermission(PluginPermission permission) =>
      grantedPermissions.contains(permission);
}

// ── Plugin manifest ────────────────────────────────────────────
class PluginManifest {
  final String pluginId;
  final String name;
  final String author;
  final PluginVersion version;
  final PluginVersion minimumEngineVersion;
  final Set<PluginPermission> requiredPermissions;
  final Set<String> supportedActionTypes;
  final Duration executionTimeout;

  const PluginManifest({
    required this.pluginId,
    required this.name,
    required this.author,
    required this.version,
    required this.minimumEngineVersion,
    required this.requiredPermissions,
    required this.supportedActionTypes,
    this.executionTimeout = const Duration(seconds: 10),
  });
}

// ── Plugin request ─────────────────────────────────────────────
class PluginRequest {
  final String requestId;
  final String pluginId;
  final String actionType;
  final Map<String, dynamic> payload;
  final PluginSecurityContext securityContext;

  const PluginRequest({
    required this.requestId,
    required this.pluginId,
    required this.actionType,
    required this.payload,
    required this.securityContext,
  });
}

// ── Plugin result ──────────────────────────────────────────────
class PluginResult {
  final bool success;
  final String pluginId;
  final String requestId;
  final List<CommandObject> commands;
  final List<PluginLogEntry> logs;
  final PluginStatus status;
  final List<String> errors;

  const PluginResult({
    required this.success,
    required this.pluginId,
    required this.requestId,
    required this.commands,
    required this.logs,
    required this.status,
    this.errors = const [],
  });

  factory PluginResult.denied({
    required String pluginId,
    required String requestId,
    required String reason,
    required List<PluginLogEntry> logs,
  }) =>
      PluginResult(
        success: false,
        pluginId: pluginId,
        requestId: requestId,
        commands: const [],
        logs: logs,
        status: PluginStatus.permissionDenied,
        errors: [reason],
      );

  factory PluginResult.timedOut({
    required String pluginId,
    required String requestId,
    required List<PluginLogEntry> logs,
  }) =>
      PluginResult(
        success: false,
        pluginId: pluginId,
        requestId: requestId,
        commands: const [],
        logs: logs,
        status: PluginStatus.timedOut,
        errors: ['Plugin "$pluginId" execution timed out.'],
      );

  factory PluginResult.failure({
    required String pluginId,
    required String requestId,
    required List<String> errors,
    required List<PluginLogEntry> logs,
    PluginStatus status = PluginStatus.executionError,
  }) =>
      PluginResult(
        success: false,
        pluginId: pluginId,
        requestId: requestId,
        commands: const [],
        logs: logs,
        status: status,
        errors: errors,
      );
}

// ── Plugin validation result ──────────────────────────────────
class PluginValidationResult {
  final bool valid;
  final List<String> errors;
  final List<String> warnings;

  const PluginValidationResult.ok({this.warnings = const []})
      : valid = true,
        errors = const [];

  const PluginValidationResult.fail(this.errors,
      {this.warnings = const []})
      : valid = false;
}

// ── Sandbox execution context (no engine references) ──────────
class _SandboxContext {
  final String pluginId;
  final String actionType;
  final Map<String, dynamic> payload;
  final Set<PluginPermission> allowedPermissions;
  final Set<String> allowedActionTypes;

  const _SandboxContext({
    required this.pluginId,
    required this.actionType,
    required this.payload,
    required this.allowedPermissions,
    required this.allowedActionTypes,
  });

  bool canEmit(String commandType) =>
      allowedActionTypes.contains(commandType);

  bool hasPermission(PluginPermission permission) =>
      allowedPermissions.contains(permission);
}

// ── Sandbox result ────────────────────────────────────────────
class _SandboxResult {
  final bool success;
  final List<CommandObject> commands;
  final List<String> errors;

  const _SandboxResult({
    required this.success,
    required this.commands,
    this.errors = const [],
  });
}

// ── ID generator ──────────────────────────────────────────────
class _PIdGen {
  static final Random _rng = Random.secure();

  static String next(String prefix) {
    final bytes = List<int>.generate(8, (_) => _rng.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '$prefix-$hex-${DateTime.now().microsecondsSinceEpoch}';
  }
}

// ── Engine version ────────────────────────────────────────────
const PluginVersion _kEngineVersion = PluginVersion(5, 0, 0);

// ── PluginEngine ──────────────────────────────────────────────
class PluginEngine {
  static const String _engineId = 'PluginEngine';

  final Map<String, PluginManifest> _registry = {};
  final Set<String> _revokedPlugins = {};
  final Set<String> _suspendedPlugins = {};

  // ── registerPlugin ────────────────────────────────────────────

  PluginValidationResult registerPlugin(PluginManifest manifest) {
    final validation = _validateManifest(manifest);
    if (!validation.valid) return validation;

    if (_revokedPlugins.contains(manifest.pluginId)) {
      return PluginValidationResult.fail([
        'Plugin "${manifest.pluginId}" has been revoked and cannot be '
            're-registered in this session.'
      ]);
    }

    _registry[manifest.pluginId] = manifest;
    return PluginValidationResult.ok(warnings: validation.warnings);
  }

  // ── revokePlugin ──────────────────────────────────────────────

  bool revokePlugin(String pluginId) {
    if (!_registry.containsKey(pluginId)) return false;
    _registry.remove(pluginId);
    _revokedPlugins.add(pluginId);
    _suspendedPlugins.remove(pluginId);
    return true;
  }

  // ── validatePlugin ────────────────────────────────────────────

  PluginValidationResult validatePlugin(
      PluginRequest request) {
    final errors = <String>[];
    final warnings = <String>[];

    if (request.requestId.trim().isEmpty) {
      errors.add('PluginRequest.requestId must not be empty.');
    }
    if (request.pluginId.trim().isEmpty) {
      errors.add('PluginRequest.pluginId must not be empty.');
    }
    if (request.actionType.trim().isEmpty) {
      errors.add('PluginRequest.actionType must not be empty.');
    }

    if (_revokedPlugins.contains(request.pluginId)) {
      errors.add('Plugin "${request.pluginId}" has been revoked.');
    }
    if (_suspendedPlugins.contains(request.pluginId)) {
      errors.add('Plugin "${request.pluginId}" is suspended.');
    }

    final manifest = _registry[request.pluginId];
    if (manifest == null) {
      errors.add(
          'Plugin "${request.pluginId}" is not registered. '
          'Call registerPlugin() first.');
    } else {
      // Version check.
      if (!manifest.minimumEngineVersion.isCompatibleWith(
          PluginVersion(0, 0, 0))) {
        // Engine must meet plugin's minimum requirement.
        if (!_kEngineVersion
            .isCompatibleWith(manifest.minimumEngineVersion)) {
          errors.add(
              'Plugin "${request.pluginId}" requires engine >= '
              '${manifest.minimumEngineVersion}; '
              'current engine is $_kEngineVersion.');
        }
      }

      // Action type check.
      if (!manifest.supportedActionTypes.contains(request.actionType)) {
        errors.add(
            'Plugin "${request.pluginId}" does not support actionType '
            '"${request.actionType}". '
            'Supported: ${manifest.supportedActionTypes.join(', ')}.');
      }
    }

    // Security context checks.
    if (request.securityContext.isExpired) {
      errors.add(
          'SecurityContext for plugin "${request.pluginId}" is expired '
          '(expired at ${request.securityContext.expiresAt.toIso8601String()}).');
    }
    if (request.securityContext.issuedTo != request.pluginId) {
      errors.add(
          'SecurityContext.issuedTo "${request.securityContext.issuedTo}" '
          'does not match pluginId "${request.pluginId}".');
    }
    if (!request.securityContext.sandboxed) {
      errors.add(
          'Plugin "${request.pluginId}" must run in a sandboxed '
          'SecurityContext (sandboxed=false is rejected).');
    }

    // Payload safety.
    _validatePayloadSafety(request.pluginId, request.payload,
        errors, warnings);

    if (errors.isEmpty) {
      return PluginValidationResult.ok(warnings: warnings);
    }
    return PluginValidationResult.fail(errors, warnings: warnings);
  }

  // ── isPluginAllowed ────────────────────────────────────────────

  bool isPluginAllowed(
      String pluginId, PluginPermission permission,
      PluginSecurityContext securityContext) {
    if (_revokedPlugins.contains(pluginId)) return false;
    if (_suspendedPlugins.contains(pluginId)) return false;
    if (!_registry.containsKey(pluginId)) return false;

    final manifest = _registry[pluginId]!;

    // Plugin must have declared the permission in its manifest.
    if (!manifest.requiredPermissions.contains(permission)) return false;

    // Security context must grant it.
    if (!securityContext.hasPermission(permission)) return false;

    // Context must not be expired.
    if (securityContext.isExpired) return false;

    return true;
  }

  // ── executePlugin ─────────────────────────────────────────────

  Future<PluginResult> executePlugin(PluginRequest request) async {
    final logs = <PluginLogEntry>[];

    void log(PluginLogLevel level, String message) {
      logs.add(PluginLogEntry(
        timestamp: DateTime.now().toUtc(),
        level: level,
        message: message,
        pluginId: request.pluginId,
      ));
    }

    try {
      log(PluginLogLevel.info,
          'Execution request received for action "${request.actionType}".');

      // Full validation gate.
      final validation = validatePlugin(request);
      if (!validation.valid) {
        for (final e in validation.errors) {
          log(PluginLogLevel.error, e);
        }
        return PluginResult.denied(
          pluginId: request.pluginId,
          requestId: request.requestId,
          reason: validation.errors.join(' | '),
          logs: logs,
        );
      }

      for (final w in validation.warnings) {
        log(PluginLogLevel.warning, w);
      }

      final manifest = _registry[request.pluginId]!;

      // Verify permission scope for this action.
      final requiredPermission =
          _actionTypeToPermission(request.actionType);
      if (requiredPermission != null &&
          !isPluginAllowed(
              request.pluginId, requiredPermission,
              request.securityContext)) {
        final msg =
            'Plugin "${request.pluginId}" lacks permission '
            '"${requiredPermission.label}" for action '
            '"${request.actionType}".';
        log(PluginLogLevel.error, msg);
        return PluginResult.denied(
          pluginId: request.pluginId,
          requestId: request.requestId,
          reason: msg,
          logs: logs,
        );
      }

      log(PluginLogLevel.info,
          'Permission scope check passed. Entering sandbox.');

      // Build sandbox context — no engine references pass through.
      final sandboxCtx = _SandboxContext(
        pluginId: request.pluginId,
        actionType: request.actionType,
        payload: Map<String, dynamic>.unmodifiable(request.payload),
        allowedPermissions: Set.unmodifiable(
            request.securityContext.grantedPermissions
                .intersection(manifest.requiredPermissions)),
        allowedActionTypes:
            Set.unmodifiable(manifest.supportedActionTypes),
      );

      // Run inside sandbox with timeout.
      final sandboxResult = await sandboxExecute(
        context: sandboxCtx,
        timeout: manifest.executionTimeout,
      );

      if (!sandboxResult.success) {
        for (final e in sandboxResult.errors) {
          log(PluginLogLevel.error, e);
        }
        return PluginResult.failure(
          pluginId: request.pluginId,
          requestId: request.requestId,
          errors: sandboxResult.errors,
          logs: logs,
        );
      }

      // Validate output commands.
      final outputValidation = _validateOutputCommands(
          sandboxResult.commands, sandboxCtx, logs);
      if (!outputValidation.valid) {
        for (final e in outputValidation.errors) {
          log(PluginLogLevel.error, e);
        }
        return PluginResult.failure(
          pluginId: request.pluginId,
          requestId: request.requestId,
          errors: outputValidation.errors,
          logs: logs,
        );
      }

      log(PluginLogLevel.info,
          'Execution complete. Emitting ${sandboxResult.commands.length} '
          'command(s) to EditorController.');

      return PluginResult(
        success: true,
        pluginId: request.pluginId,
        requestId: request.requestId,
        commands: List.unmodifiable(sandboxResult.commands),
        logs: logs,
        status: PluginStatus.active,
      );
    } on TimeoutException {
      logs.add(PluginLogEntry(
        timestamp: DateTime.now().toUtc(),
        level: PluginLogLevel.error,
        message: 'Execution timed out.',
        pluginId: request.pluginId,
      ));
      _suspendedPlugins.add(request.pluginId);
      return PluginResult.timedOut(
        pluginId: request.pluginId,
        requestId: request.requestId,
        logs: logs,
      );
    } catch (e) {
      logs.add(PluginLogEntry(
        timestamp: DateTime.now().toUtc(),
        level: PluginLogLevel.error,
        message: 'Unexpected sandbox error: $e',
        pluginId: request.pluginId,
      ));
      return PluginResult.failure(
        pluginId: request.pluginId,
        requestId: request.requestId,
        errors: ['Unexpected sandbox error: $e'],
        logs: logs,
      );
    }
  }

  // ── sandboxExecute ─────────────────────────────────────────────

  Future<_SandboxResult> sandboxExecute({
    required _SandboxContext context,
    required Duration timeout,
  }) async {
    // Wrap computation in Future.microtask for isolation from the
    // call stack.  No engine references enter this scope.
    final Future<_SandboxResult> computation =
        Future.microtask(() => _computeCommands(context));

    return computation.timeout(
      timeout,
      onTimeout: () => _SandboxResult(
        success: false,
        commands: const [],
        errors: ['Sandbox timed out after ${timeout.inSeconds}s.'],
      ),
    );
  }

  // ── Private sandbox computation ───────────────────────────────

  _SandboxResult _computeCommands(_SandboxContext context) {
    try {
      if (!context.canEmit(context.actionType)) {
        return _SandboxResult(
          success: false,
          errors: [
            'Sandbox: actionType "${context.actionType}" is not in the '
                'plugin\'s allowed action set.'
          ],
        );
      }

      final now = DateTime.now().toUtc();
      final commandId = _PIdGen.next('plg-cmd');

      // Strip any forbidden keys from payload before embedding.
      final safePayload = _sanitisePayload(context.payload);

      final cmd = CommandObject(
        commandId: commandId,
        commandType: context.actionType,
        target: safePayload['targetLayerId'] as String?,
        payload: Map<String, dynamic>.unmodifiable({
          ...safePayload,
          'pluginId': context.pluginId,
          'sandboxed': true,
        }),
        timestamp: now,
        priority: _deriveCommandPriority(context.actionType),
        requiresConfirmation:
            _actionRequiresConfirmation(context.actionType),
        sourceEngine: _engineId,
      );

      return _SandboxResult(success: true, commands: [cmd]);
    } catch (e) {
      return _SandboxResult(
        success: false,
        errors: ['Command computation failed: $e'],
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────

  PluginValidationResult _validateManifest(PluginManifest manifest) {
    final errors = <String>[];
    final warnings = <String>[];

    if (manifest.pluginId.trim().isEmpty) {
      errors.add('PluginManifest.pluginId must not be empty.');
    }
    if (manifest.name.trim().isEmpty) {
      errors.add('PluginManifest.name must not be empty.');
    }
    if (manifest.author.trim().isEmpty) {
      warnings.add('PluginManifest.author is empty.');
    }
    if (manifest.requiredPermissions.isEmpty) {
      errors.add(
          'PluginManifest.requiredPermissions must not be empty. '
          'Declare at least one permission scope.');
    }
    if (manifest.supportedActionTypes.isEmpty) {
      errors.add(
          'PluginManifest.supportedActionTypes must not be empty.');
    }

    // Version compatibility.
    if (!_kEngineVersion.isCompatibleWith(manifest.minimumEngineVersion)) {
      errors.add(
          'Plugin "${manifest.pluginId}" requires engine >= '
          '${manifest.minimumEngineVersion}; '
          'current engine version is $_kEngineVersion. '
          'Update the plugin or the engine.');
    }

    // Timeout sanity.
    if (manifest.executionTimeout.inSeconds < 1) {
      errors.add(
          'PluginManifest.executionTimeout must be >= 1 second '
          '(got ${manifest.executionTimeout.inMilliseconds}ms).');
    }
    if (manifest.executionTimeout.inSeconds > 60) {
      warnings.add(
          'PluginManifest.executionTimeout is ${manifest.executionTimeout.inSeconds}s; '
          'recommend keeping under 60s for responsiveness.');
    }

    // Forbidden engine names in pluginId.
    const forbidden = [
      'layerengine', 'historyengine', 'renderengine',
      'storageengine', 'aiengine', 'templateengine',
      'syncengine', 'exportengine',
    ];
    if (forbidden.contains(manifest.pluginId.toLowerCase())) {
      errors.add(
          'PluginManifest.pluginId "${manifest.pluginId}" is a reserved '
          'engine identifier.');
    }

    if (errors.isEmpty) {
      return PluginValidationResult.ok(warnings: warnings);
    }
    return PluginValidationResult.fail(errors, warnings: warnings);
  }

  void _validatePayloadSafety(
      String pluginId,
      Map<String, dynamic> payload,
      List<String> errors,
      List<String> warnings) {
    const forbidden = [
      'layerengine', 'historyengine', 'renderengine',
      'storageengine', 'aiengine', 'templateengine',
      'syncengine', 'exportengine', 'buildcontext',
      'canvas', 'widget',
    ];
    for (final key in payload.keys) {
      if (forbidden.contains(key.toLowerCase())) {
        errors.add(
            'Plugin "$pluginId" payload key "$key" references a '
            'forbidden engine or context object.');
      }
      final v = payload[key];
      final safe = v == null ||
          v is num ||
          v is String ||
          v is bool ||
          (v is List && v.every((e) => e is num || e is String || e is bool)) ||
          v is Map<String, dynamic>;
      if (!safe) {
        errors.add(
            'Plugin "$pluginId" payload["$key"] contains '
            'non-serialisable type ${v.runtimeType}. '
            'Only primitives and plain maps are allowed.');
      }
    }
  }

  Map<String, dynamic> _sanitisePayload(Map<String, dynamic> raw) {
    const forbidden = {
      'layerengine', 'historyengine', 'renderengine',
      'storageengine', 'aiengine', 'templateengine',
      'syncengine', 'exportengine', 'buildcontext',
      'canvas', 'widget',
    };
    return Map<String, dynamic>.fromEntries(
      raw.entries.where(
          (e) => !forbidden.contains(e.key.toLowerCase())),
    );
  }

  PluginValidationResult _validateOutputCommands(
      List<CommandObject> commands,
      _SandboxContext context,
      List<PluginLogEntry> logs) {
    final errors = <String>[];
    final seenIds = <String>{};

    for (final cmd in commands) {
      if (cmd.commandId.trim().isEmpty) {
        errors.add('Output CommandObject has empty commandId.');
      } else if (!seenIds.add(cmd.commandId)) {
        errors.add(
            'Duplicate commandId "${cmd.commandId}" in plugin output.');
      }
      if (cmd.commandType.trim().isEmpty) {
        errors.add('CommandObject "${cmd.commandId}" has empty commandType.');
      } else if (!context.canEmit(cmd.commandType)) {
        errors.add(
            'CommandObject "${cmd.commandId}" emits commandType '
            '"${cmd.commandType}" which is outside the plugin\'s '
            'allowed action set.');
      }
      if (cmd.sourceEngine != _engineId) {
        errors.add(
            'CommandObject "${cmd.commandId}" sourceEngine is '
            '"${cmd.sourceEngine}" (must be "$_engineId").');
      }
      if (cmd.priority < 1 || cmd.priority > 10) {
        logs.add(PluginLogEntry(
          timestamp: DateTime.now().toUtc(),
          level: PluginLogLevel.warning,
          message: 'CommandObject "${cmd.commandId}" priority '
              '${cmd.priority} is outside [1, 10].',
          pluginId: context.pluginId,
        ));
      }
    }

    if (errors.isEmpty) return PluginValidationResult.ok();
    return PluginValidationResult.fail(errors);
  }

  PluginPermission? _actionTypeToPermission(String actionType) {
    const map = <String, PluginPermission>{
      'add_layer':       PluginPermission.addLayer,
      'update_layer':    PluginPermission.updateLayer,
      'delete_layer':    PluginPermission.deleteLayer,
      'move_layer':      PluginPermission.moveLayer,
      'resize_layer':    PluginPermission.resizeLayer,
      'rotate_layer':    PluginPermission.rotateLayer,
      'change_color':    PluginPermission.changeColor,
      'change_font':     PluginPermission.changeFont,
      'show_layer':      PluginPermission.showLayer,
      'hide_layer':      PluginPermission.hideLayer,
      'lock_layer':      PluginPermission.lockLayer,
      'unlock_layer':    PluginPermission.unlockLayer,
      'apply_template':  PluginPermission.applyTemplate,
      'batch_update':    PluginPermission.batchUpdate,
      'reorder_layers':  PluginPermission.reorderLayers,
      'select_layer':    PluginPermission.selectLayer,
      'clear_selection': PluginPermission.clearSelection,
      'duplicate_layer': PluginPermission.duplicateLayer,
    };
    return map[actionType];
  }

  int _deriveCommandPriority(String actionType) {
    const critical = {'delete_layer', 'batch_update', 'reorder_layers'};
    const high = {'add_layer', 'apply_template', 'duplicate_layer'};
    if (critical.contains(actionType)) return 9;
    if (high.contains(actionType)) return 7;
    return 5;
  }

  bool _actionRequiresConfirmation(String actionType) {
    const confirmRequired = {
      'delete_layer', 'batch_update', 'reorder_layers', 'apply_template',
    };
    return confirmRequired.contains(actionType);
  }
}
