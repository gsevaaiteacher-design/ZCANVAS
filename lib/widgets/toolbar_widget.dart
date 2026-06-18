// ==========================================================
// widgets/toolbar_widget.dart
// PHASE-17 — ZERO GAP WIDGET ARCHITECTURE CONTRACT
// FILE 2 OF 4: toolbar_widget.dart
// ==========================================================
//
// PURPOSE (FIXED): SEND USER COMMANDS ONLY.
//
// ALLOWED COMMAND TYPES (ENUM ONLY — NO OTHERS):
//   "UNDO"         "REDO"         "DELETE_LAYER"
//   "MOVE_TOOL"    "SELECT_TOOL"  "ZOOM_IN"
//   "ZOOM_OUT"
//
// OUTPUT RULE — ON ANY BUTTON CLICK:
//   COMMAND {
//     type:      ENUM_COMMAND,
//     payload:   "",
//     target:    "EDITOR",
//     timestamp: NOW
//   }
//
// ALLOWED STATE ONLY:
//   { activeTool: STRING_ENUM, isPressed: BOOLEAN }
//
// FORBIDDEN:
//   ✖ EXECUTE ACTION LOCALLY    ✖ MODIFY STATE
//   ✖ CALL ENGINE               ✖ COMPUTE LOGIC
//   ✖ CREATE NEW COMMAND TYPES
//
// COMMUNICATION FLOW:
//   ToolbarWidget
//       → EditorController.sendCommand()
//       → ENGINE LAYER
//       → RenderEngine
//       → Canvas
// ==========================================================

import 'package:flutter/material.dart';

import '../controllers/editor_controller.dart';

// ---------------------------------------------------------------------------
// COMMAND TYPE ENUM — strict, no additions allowed
// ---------------------------------------------------------------------------

/// Exhaustive list of toolbar command types.
///
/// NO OTHER VALUE MAY BE ADDED.
/// Contract: PHASE-17, FILE 2, "ALLOWED COMMAND TYPES (ENUM ONLY)".
enum ToolbarCommandType {
  undo,
  redo,
  deleteLayer,
  moveTool,
  selectTool,
  zoomIn,
  zoomOut;

  /// Wire name sent in the COMMAND.type field — must match contract strings.
  String get wireName {
    switch (this) {
      case ToolbarCommandType.undo:
        return 'UNDO';
      case ToolbarCommandType.redo:
        return 'REDO';
      case ToolbarCommandType.deleteLayer:
        return 'DELETE_LAYER';
      case ToolbarCommandType.moveTool:
        return 'MOVE_TOOL';
      case ToolbarCommandType.selectTool:
        return 'SELECT_TOOL';
      case ToolbarCommandType.zoomIn:
        return 'ZOOM_IN';
      case ToolbarCommandType.zoomOut:
        return 'ZOOM_OUT';
    }
  }
}

// ---------------------------------------------------------------------------
// TOOLBAR COMMAND — strict PHASE-17 command format
// ---------------------------------------------------------------------------

/// Contract-compliant command emitted on every toolbar button press.
///
/// COMMAND {
///   type:      STRING_ENUM,
///   payload:   "",          ← always empty for toolbar commands
///   target:    "EDITOR",
///   timestamp: INTEGER
/// }
@immutable
class ToolbarCommand {
  const ToolbarCommand({
    required this.type,
    required this.timestamp,
  });

  final String type;
  final String payload = '';   // always empty — contract mandates ""
  final String target  = 'EDITOR';
  final int    timestamp;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'type':      type,
        'payload':   payload,
        'target':    target,
        'timestamp': timestamp,
      };
}

// ---------------------------------------------------------------------------
// TOOLBAR WIDGET
// ---------------------------------------------------------------------------

/// Command-only toolbar for Z-CANVAS.
///
/// RESPONSIBILITIES (fixed by contract):
///   ✔ Render one button per allowed command type.
///   ✔ On press, build a [ToolbarCommand] and call
///     [EditorController.sendCommand] — nothing else.
///
/// FORBIDDEN (hard block):
///   ✖ Execute any action locally.
///   ✖ Modify state beyond activeTool / isPressed.
///   ✖ Call any engine.
///   ✖ Compute any logic.
///   ✖ Create command types outside the enum.
class ToolbarWidget extends StatefulWidget {
  const ToolbarWidget({
    super.key,
    required this.editorController,
  });

  /// The sole channel through which commands leave this widget.
  final EditorController editorController;

  @override
  State<ToolbarWidget> createState() => _ToolbarWidgetState();
}

class _ToolbarWidgetState extends State<ToolbarWidget> {
  // -------------------------------------------------------------------------
  // ALLOWED STATE ONLY:
  //   activeTool: STRING_ENUM
  //   isPressed:  BOOLEAN
  // NO OTHER STATE IS ALLOWED.
  // -------------------------------------------------------------------------

  String _activeTool = ToolbarCommandType.selectTool.wireName;
  bool   _isPressed  = false;

  // -------------------------------------------------------------------------
  // COMMAND DISPATCH — single path, no local logic
  // -------------------------------------------------------------------------

  /// Converts a [ToolbarCommandType] into a contract-compliant
  /// [ToolbarCommand] and forwards it to [EditorController.sendCommand].
  ///
  /// This is the ONLY action taken on button press.
  void _sendCommand(ToolbarCommandType commandType) {
    // Update allowed UI state when the command is a tool-selection type.
    if (_isToolCommand(commandType)) {
      setState(() => _activeTool = commandType.wireName);
    }

    // Build and dispatch — no local execution, no logic.
    final ToolbarCommand command = ToolbarCommand(
      type:      commandType.wireName,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    widget.editorController.sendCommand(command);
  }

  /// Returns true if [type] selects a persistent tool mode.
  ///
  /// Used ONLY to update the [_activeTool] UI state.
  /// No engine logic is computed here.
  bool _isToolCommand(ToolbarCommandType type) {
    return type == ToolbarCommandType.moveTool ||
           type == ToolbarCommandType.selectTool;
  }

  // -------------------------------------------------------------------------
  // BUILD
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1C1C1E),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // ── History group ──────────────────────────────────────────────
          _ToolbarGroup(
            children: <Widget>[
              _ToolbarButton(
                commandType:  ToolbarCommandType.undo,
                icon:         Icons.undo,
                label:        'Undo',
                isActive:     false,
                isPressed:    _isPressed,
                onTap:        _sendCommand,
                onPressStart: () => setState(() => _isPressed = true),
                onPressEnd:   () => setState(() => _isPressed = false),
              ),
              _ToolbarButton(
                commandType:  ToolbarCommandType.redo,
                icon:         Icons.redo,
                label:        'Redo',
                isActive:     false,
                isPressed:    _isPressed,
                onTap:        _sendCommand,
                onPressStart: () => setState(() => _isPressed = true),
                onPressEnd:   () => setState(() => _isPressed = false),
              ),
            ],
          ),

          _Divider(),

          // ── Tool group ─────────────────────────────────────────────────
          _ToolbarGroup(
            children: <Widget>[
              _ToolbarButton(
                commandType:  ToolbarCommandType.selectTool,
                icon:         Icons.touch_app_outlined,
                label:        'Select',
                isActive:     _activeTool == ToolbarCommandType.selectTool.wireName,
                isPressed:    _isPressed,
                onTap:        _sendCommand,
                onPressStart: () => setState(() => _isPressed = true),
                onPressEnd:   () => setState(() => _isPressed = false),
              ),
              _ToolbarButton(
                commandType:  ToolbarCommandType.moveTool,
                icon:         Icons.open_with,
                label:        'Move',
                isActive:     _activeTool == ToolbarCommandType.moveTool.wireName,
                isPressed:    _isPressed,
                onTap:        _sendCommand,
                onPressStart: () => setState(() => _isPressed = true),
                onPressEnd:   () => setState(() => _isPressed = false),
              ),
            ],
          ),

          _Divider(),

          // ── Zoom group ─────────────────────────────────────────────────
          _ToolbarGroup(
            children: <Widget>[
              _ToolbarButton(
                commandType:  ToolbarCommandType.zoomIn,
                icon:         Icons.zoom_in,
                label:        'Zoom In',
                isActive:     false,
                isPressed:    _isPressed,
                onTap:        _sendCommand,
                onPressStart: () => setState(() => _isPressed = true),
                onPressEnd:   () => setState(() => _isPressed = false),
              ),
              _ToolbarButton(
                commandType:  ToolbarCommandType.zoomOut,
                icon:         Icons.zoom_out,
                label:        'Zoom Out',
                isActive:     false,
                isPressed:    _isPressed,
                onTap:        _sendCommand,
                onPressStart: () => setState(() => _isPressed = true),
                onPressEnd:   () => setState(() => _isPressed = false),
              ),
            ],
          ),

          _Divider(),

          // ── Destructive group ──────────────────────────────────────────
          _ToolbarGroup(
            children: <Widget>[
              _ToolbarButton(
                commandType:  ToolbarCommandType.deleteLayer,
                icon:         Icons.delete_outline,
                label:        'Delete',
                isActive:     false,
                isPressed:    _isPressed,
                isDestructive: true,
                onTap:        _sendCommand,
                onPressStart: () => setState(() => _isPressed = true),
                onPressEnd:   () => setState(() => _isPressed = false),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// INTERNAL WIDGETS — layout helpers, no logic
// ---------------------------------------------------------------------------

/// Groups a set of toolbar buttons with consistent padding.
class _ToolbarGroup extends StatelessWidget {
  const _ToolbarGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

/// Visual separator between toolbar groups.
class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      color: const Color(0xFF2C2C2E),
    );
  }
}

// ---------------------------------------------------------------------------
// TOOLBAR BUTTON
// ---------------------------------------------------------------------------

/// Single toolbar button.
///
/// RESPONSIBILITIES (fixed):
///   ✔ Render icon + label.
///   ✔ Report press events to [_ToolbarWidgetState] for isPressed UI state.
///   ✔ Call [onTap] with the assigned [commandType] on release.
///
/// FORBIDDEN:
///   ✖ Execute any command logic.
///   ✖ Modify any state other than visual press feedback.
///   ✖ Create new command types.
///   ✖ Access engines.
class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.commandType,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.isPressed,
    required this.onTap,
    required this.onPressStart,
    required this.onPressEnd,
    this.isDestructive = false,
  });

  final ToolbarCommandType                    commandType;
  final IconData                              icon;
  final String                               label;
  final bool                                 isActive;
  final bool                                 isPressed;
  final void Function(ToolbarCommandType)    onTap;
  final VoidCallback                         onPressStart;
  final VoidCallback                         onPressEnd;
  final bool                                 isDestructive;

  Color get _activeColor    => const Color(0xFF6C63FF);
  Color get _destructiveColor => const Color(0xFFE53935);
  Color get _defaultColor   => const Color(0xFF8E8E93);
  Color get _pressedColor   => const Color(0xFF48484A);

  Color get _iconColor {
    if (isDestructive) return _destructiveColor;
    if (isActive)      return _activeColor;
    return _defaultColor;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => onPressStart(),
      onTapUp:     (_) { onPressEnd(); onTap(commandType); },
      onTapCancel: ()  => onPressEnd(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width:  48,
        height: 48,
        margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
        decoration: BoxDecoration(
          color: isActive
              ? _activeColor.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Tooltip(
          message: label,
          preferBelow: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 20, color: _iconColor),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: _iconColor,
                  fontSize: 8,
                  fontWeight:
                      isActive ? FontWeight.w600 : FontWeight.w400,
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================================
// END OF FILE — widgets/toolbar_widget.dart
// ==========================================================
