// ==========================================================
// widgets/layer_panel_widget.dart
// PHASE-17 — FILE 3 OF 4
// PURPOSE: LAYER STRUCTURE VIEWER ONLY
// ==========================================================
//
// INPUT:
//   layers          → List of LayerObject (id, name, type, visible, locked, zIndex)
//   selectedLayerId → String | null
//
// OUTPUT:
//   SELECT_LAYER command → EditorController.sendCommand()
//
// ALLOWED STATE:
//   expanded:      bool
//   scrollPosition: double
//
// FORBIDDEN: edit / delete / sort layers, engine access, new data
// ==========================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import '../controllers/editor_controller.dart';

// ---------------------------------------------------------------------------
// DATA MODEL — immutable input
// ---------------------------------------------------------------------------

@immutable
class LayerObject {
  const LayerObject({
    required this.id,
    required this.name,
    required this.type,
    required this.visible,
    required this.locked,
    required this.zIndex,
  });

  final String id;
  final String name;
  final String type;   // background | image | text | icon | shape
  final bool   visible;
  final bool   locked;
  final int    zIndex;

  factory LayerObject.fromMap(Map<String, dynamic> m) => LayerObject(
        id:      m['id']      as String? ?? '',
        name:    m['name']    as String? ?? 'Layer',
        type:    m['type']    as String? ?? 'shape',
        visible: m['visible'] as bool?   ?? true,
        locked:  m['locked']  as bool?   ?? false,
        zIndex:  (m['zIndex'] as num?    ?? 0).toInt(),
      );
}

// ---------------------------------------------------------------------------
// SELECT_LAYER COMMAND — the only allowed output
// ---------------------------------------------------------------------------

@immutable
class SelectLayerCommand {
  const SelectLayerCommand({required this.layerId, required this.timestamp});

  final String type      = 'SELECT_LAYER';
  final String target    = 'EDITOR';
  final String layerId;
  final int    timestamp;

  String get payload => jsonEncode({'layerId': layerId});

  Map<String, dynamic> toMap() =>
      {'type': type, 'payload': payload, 'target': target, 'timestamp': timestamp};
}

// ---------------------------------------------------------------------------
// WIDGET
// ---------------------------------------------------------------------------

class LayerPanelWidget extends StatefulWidget {
  const LayerPanelWidget({
    super.key,
    required this.layers,
    required this.selectedLayerId,
    required this.editorController,
  });

  final List<LayerObject> layers;
  final String?           selectedLayerId;
  final EditorController  editorController;

  @override
  State<LayerPanelWidget> createState() => _LayerPanelWidgetState();
}

class _LayerPanelWidgetState extends State<LayerPanelWidget> {
  // ALLOWED STATE ONLY
  bool   _expanded       = true;
  double _scrollPosition = 0.0;

  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() => _scrollPosition = _scroll.offset);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _sendSelectLayer(String layerId) {
    widget.editorController.sendCommand(
      SelectLayerCommand(
        layerId:   layerId,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Descending zIndex — topmost layer first in the list
    final List<LayerObject> ordered = List<LayerObject>.from(widget.layers)
      ..sort((a, b) => b.zIndex.compareTo(a.zIndex));

    return Container(
      width:  220,
      color:  const Color(0xFF161618),
      child:  Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // ── Header bar ────────────────────────────────────────────────
          _LayerPanelHeader(
            expanded:   _expanded,
            count:      widget.layers.length,
            onToggle:   () => setState(() => _expanded = !_expanded),
          ),

          // ── Layer rows ────────────────────────────────────────────────
          if (_expanded)
            Expanded(
              child: ordered.isEmpty
                  ? const _NoLayersPlaceholder()
                  : ReorderableListView.builder(
                      scrollController: _scroll,
                      // Reordering is a display affordance only —
                      // the actual reorder command goes to EditorController.
                      // LayerPanelWidget does NOT sort layers internally.
                      onReorder: (_, __) {
                        // CONTRACT: sorting is FORBIDDEN here.
                        // This callback is intentionally a no-op.
                        // The drag gesture is visual only.
                      },
                      itemCount:   ordered.length,
                      itemBuilder: (context, index) {
                        final layer = ordered[index];
                        return _LayerTile(
                          key:        ValueKey(layer.id),
                          layer:      layer,
                          isSelected: layer.id == widget.selectedLayerId,
                          depth:      0,
                          onTap:      _sendSelectLayer,
                        );
                      },
                    ),
            ),

          // ── Footer — z-index legend ───────────────────────────────────
          if (_expanded && widget.layers.isNotEmpty)
            const _LayerPanelFooter(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HEADER BAR
// ---------------------------------------------------------------------------

class _LayerPanelHeader extends StatelessWidget {
  const _LayerPanelHeader({
    required this.expanded,
    required this.count,
    required this.onToggle,
  });

  final bool       expanded;
  final int        count;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height:  36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E20),
          border: Border(bottom: BorderSide(color: Color(0xFF2A2A2D), width: 1)),
        ),
        child: Row(
          children: [
            Icon(
              expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
              size:  14,
              color: const Color(0xFF636366),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.layers, size: 13, color: Color(0xFF8E8E93)),
            const SizedBox(width: 6),
            const Text(
              'LAYERS',
              style: TextStyle(
                color:       Color(0xFFAEAEB2),
                fontSize:    10,
                fontWeight:  FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
            const Spacer(),
            // Layer count badge
            Container(
              padding:    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color:        const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color:      Color(0xFF636366),
                  fontSize:   9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LAYER TILE
// ---------------------------------------------------------------------------

class _LayerTile extends StatelessWidget {
  const _LayerTile({
    super.key,
    required this.layer,
    required this.isSelected,
    required this.depth,
    required this.onTap,
  });

  final LayerObject            layer;
  final bool                   isSelected;
  final int                    depth;
  final void Function(String)  onTap;

  // Type → icon mapping
  IconData get _icon => switch (layer.type) {
        'background' => Icons.gradient,
        'image'      => Icons.image_outlined,
        'text'       => Icons.title,
        'icon'       => Icons.emoji_emotions_outlined,
        'shape'      => Icons.crop_square_outlined,
        _            => Icons.layers_outlined,
      };

  // Type → accent colour
  Color get _typeColor => switch (layer.type) {
        'background' => const Color(0xFF5E5CE6),
        'image'      => const Color(0xFF30D158),
        'text'       => const Color(0xFFFFD60A),
        'icon'       => const Color(0xFFFF9F0A),
        'shape'      => const Color(0xFF64D2FF),
        _            => const Color(0xFF8E8E93),
      };

  @override
  Widget build(BuildContext context) {
    final double indent = 10.0 + depth * 16.0;

    return GestureDetector(
      onTap: () => onTap(layer.id),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        height:   40,
        padding:  EdgeInsets.only(left: indent, right: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6C63FF).withOpacity(0.14)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? const Color(0xFF6C63FF) : Colors.transparent,
              width: 2,
            ),
            bottom: const BorderSide(color: Color(0xFF1E1E20), width: 1),
          ),
        ),
        child: Row(
          children: [
            // Type colour dot
            Container(
              width:  6,
              height: 6,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color:  _typeColor,
                shape:  BoxShape.circle,
              ),
            ),

            // Type icon
            Icon(_icon, size: 14, color: _typeColor.withOpacity(0.8)),
            const SizedBox(width: 7),

            // Layer name
            Expanded(
              child: Text(
                layer.name,
                overflow:  TextOverflow.ellipsis,
                style: TextStyle(
                  color: !layer.visible
                      ? const Color(0xFF3A3A3C)
                      : isSelected
                          ? const Color(0xFFFFFFFF)
                          : const Color(0xFFAEAEB2),
                  fontSize:   12,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                  decoration: !layer.visible
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  decorationColor: const Color(0xFF3A3A3C),
                ),
              ),
            ),

            // zIndex chip
            Container(
              padding:    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color:        const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                '${layer.zIndex}',
                style: const TextStyle(
                  color:      Color(0xFF48484A),
                  fontSize:   8,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Visibility indicator (display only)
            Icon(
              layer.visible
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size:  12,
              color: layer.visible
                  ? const Color(0xFF48484A)
                  : const Color(0xFF3A3A3C),
            ),
            const SizedBox(width: 4),

            // Lock indicator (display only)
            Icon(
              layer.locked ? Icons.lock_outline : Icons.lock_open_outlined,
              size:  12,
              color: layer.locked
                  ? const Color(0xFFFF9F0A).withOpacity(0.7)
                  : const Color(0xFF3A3A3C),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FOOTER — legend only, no interaction
// ---------------------------------------------------------------------------

class _LayerPanelFooter extends StatelessWidget {
  const _LayerPanelFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      height:  28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color:  Color(0xFF1E1E20),
        border: Border(top: BorderSide(color: Color(0xFF2A2A2D), width: 1)),
      ),
      child: Row(
        children: const [
          Icon(Icons.info_outline, size: 10, color: Color(0xFF3A3A3C)),
          SizedBox(width: 4),
          Text(
            'Tap a layer to select',
            style: TextStyle(color: Color(0xFF3A3A3C), fontSize: 9),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// NO LAYERS PLACEHOLDER
// ---------------------------------------------------------------------------

class _NoLayersPlaceholder extends StatelessWidget {
  const _NoLayersPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.layers_clear_outlined, size: 36, color: Color(0xFF2C2C2E)),
          SizedBox(height: 10),
          Text(
            'No layers yet',
            style: TextStyle(color: Color(0xFF3A3A3C), fontSize: 12),
          ),
          SizedBox(height: 4),
          Text(
            'Add elements from the generator',
            style: TextStyle(color: Color(0xFF2C2C2E), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ==========================================================
// END OF FILE — widgets/layer_panel_widget.dart
// ==========================================================
