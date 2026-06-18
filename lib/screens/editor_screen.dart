// screens/editor_screen.dart
//
// PHASE-11 — Editor Screen (Main Workspace UI)
//
// ===========================================================================
// OWNERSHIP CONTRACT
// ===========================================================================
//
// WHAT THIS FILE CAN DO:
//   • Build the full Canva-style 3-panel workspace widget tree
//   • Display read-only data passed in via constructor
//   • Capture user input and forward intent to EditorController
//   • Hold ephemeral UI state (zoom level, panel visibility, tab index,
//     preview mode toggle, AI chat text input, panel collapsed state)
//   • Accept canvas content as a read-only Widget from EditorController
//   • Provide responsive layout via LayoutBuilder
//     (Mobile → bottom sheets / Tablet → 2-col / Desktop → 3-col)
//
// WHAT THIS FILE CANNOT DO:
//   ❌ Modify any layer
//   ❌ Mutate history
//   ❌ Access Canvas or RenderEngine directly
//   ❌ Call any engine
//   ❌ Store design data
//   ❌ Decide business or navigation flow independently
//
// ALL INTERACTION FLOWS THROUGH:
//   EditorController (via EditorScreenDelegate) — the only gate.
// ===========================================================================

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// SECTION 1 — EDITORCONTROLLER DELEGATE INTERFACE
// ---------------------------------------------------------------------------

/// Intent contract that EditorController must implement to receive all
/// interaction signals from EditorScreen.
abstract interface class EditorScreenDelegate {
  // ── AppBar actions ──────────────────────────────────────────────────────
  void onNavigateBack();
  void onUndo();
  void onRedo();
  void onSave();
  void onExport();
  void onAIAssistRequested();
  void onTogglePreviewMode();

  // ── Left Panel — Tool actions ────────────────────────────────────────────
  void onAddText();
  void onAddImage();
  void onAddShape(ShapeType shape);

  // ── Left Panel — Layer intents (read-only selection) ────────────────────
  void onLayerSelected(String layerId);
  void onLayerVisibilityToggled(String layerId);
  void onLayerLockToggled(String layerId);

  // ── Left Panel — History intents (read-only navigation) ─────────────────
  void onHistoryEntrySelected(String entryId);

  // ── Right Panel — Property intents ──────────────────────────────────────
  void onFontFamilyChanged(String fontFamily);
  void onFontSizeChanged(double size);
  void onFontWeightChanged(bool isBold);
  void onFontItalicChanged(bool isItalic);
  void onColorChanged(EditorColorTarget target, Color color);
  void onOpacityChanged(double opacity);
  void onEffectToggled(String effectId, bool enabled);
  void onAlignmentChanged(EditorAlignment alignment);

  // ── Bottom Bar — AI Chat ─────────────────────────────────────────────────
  void onAIChatMessageSent(String message);
  void onAISuggestionAccepted(String suggestionId);

  // ── Bottom Bar — Quick Actions ───────────────────────────────────────────
  void onQuickAction(EditorQuickAction action);

  // ── Canvas — Zoom / Pan (UI state forwarded as informational intent) ─────
  void onZoomChanged(double scale);
  void onCanvasTapped(Offset position);

  // ── Overlay ──────────────────────────────────────────────────────────────
  void onRewardsOverlayDismissed();
  void onPluginSidebarRequested();     // future hook — UI placeholder
  void onAutomationDashboardRequested(); // future hook — UI placeholder
  void onRobotAssistantRequested();    // future hook — UI placeholder
}

// ---------------------------------------------------------------------------
// SECTION 2 — SUPPORTING ENUMERATIONS
// ---------------------------------------------------------------------------

/// Shape types available in the Tool Panel. UI classification only.
enum ShapeType { rectangle, circle, triangle, line, polygon, star }

/// Which color target a color picker change applies to.
enum EditorColorTarget { fill, stroke, background }

/// Text/layer alignment intent.
enum EditorAlignment { left, center, right, top, middle, bottom }

/// Quick actions available in the bottom bar.
enum EditorQuickAction {
  duplicate,
  delete,
  group,
  ungroup,
  bringForward,
  sendBackward,
  flipHorizontal,
  flipVertical,
}

/// Left panel tab index.
enum _LeftPanelTab { tools, layers, history }

// ---------------------------------------------------------------------------
// SECTION 3 — READ-ONLY VIEW MODELS
// ---------------------------------------------------------------------------

/// Read-only project metadata for the AppBar.
final class EditorProjectViewModel {
  const EditorProjectViewModel({
    required this.title,
    this.isSaved = true,
    this.canUndo = false,
    this.canRedo = false,
    this.isPreviewMode = false,
  });

  final String title;
  final bool isSaved;
  final bool canUndo;
  final bool canRedo;
  final bool isPreviewMode;
}

/// Read-only layer item for the Layers Tab.
final class LayerItemViewModel {
  const LayerItemViewModel({
    required this.layerId,
    required this.label,
    required this.type,
    this.isVisible = true,
    this.isLocked = false,
    this.isSelected = false,
    this.depth = 0,
  });

  final String layerId;
  final String label;
  final String type;
  final bool isVisible;
  final bool isLocked;
  final bool isSelected;
  final int depth;
}

/// Read-only history entry for the History Tab.
final class HistoryEntryViewModel {
  const HistoryEntryViewModel({
    required this.entryId,
    required this.label,
    required this.timestampLabel,
    this.isActive = false,
  });

  final String entryId;
  final String label;
  final String timestampLabel;
  final bool isActive;
}

/// Read-only properties for the selected element (right panel).
final class SelectionPropertiesViewModel {
  const SelectionPropertiesViewModel({
    this.fontFamily,
    this.fontSize,
    this.isBold = false,
    this.isItalic = false,
    this.fillColor,
    this.strokeColor,
    this.opacity = 1.0,
    this.activeEffects = const [],
    this.elementType,
  });

  final String? fontFamily;
  final double? fontSize;
  final bool isBold;
  final bool isItalic;
  final Color? fillColor;
  final Color? strokeColor;

  /// 0.0 – 1.0
  final double opacity;
  final List<String> activeEffects;
  final String? elementType;

  bool get hasTextProperties => fontFamily != null || fontSize != null;
  bool get hasColorProperties => fillColor != null || strokeColor != null;
}

/// Read-only AI suggestion for the bottom bar.
final class AISuggestionViewModel {
  const AISuggestionViewModel({
    required this.suggestionId,
    required this.label,
    this.icon,
  });

  final String suggestionId;
  final String label;
  final IconData? icon;
}

/// Read-only rewards overlay data.
final class RewardsOverlayViewModel {
  const RewardsOverlayViewModel({
    required this.message,
    required this.coinsEarned,
    this.badgeLabel,
  });

  final String message;
  final int coinsEarned;
  final String? badgeLabel;
}

// ---------------------------------------------------------------------------
// SECTION 4 — EDITOR SCREEN
// ---------------------------------------------------------------------------

/// EditorScreen — PHASE-11 Main Workspace UI (Canva-style)
///
/// Pure visual shell. Composes the 3-panel workspace and routes all
/// user interaction to [delegate] (EditorController).
///
/// Holds only ephemeral UI state: panel visibility, tab, zoom, AI chat text,
/// preview mode overlay, bottom bar expansion.
class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.delegate,
    required this.project,
    this.canvasContent,
    this.layers = const [],
    this.historyEntries = const [],
    this.selectionProperties,
    this.aiSuggestions = const [],
    this.rewardsOverlay,
  });

  /// EditorController — receives every intent from this screen.
  final EditorScreenDelegate delegate;

  /// Read-only project metadata.
  final EditorProjectViewModel project;

  /// Canvas widget provided by RenderEngine (via EditorController).
  /// The screen renders it as-is. null shows an empty canvas placeholder.
  final Widget? canvasContent;

  /// Read-only layer list for the Layers Tab.
  final List<LayerItemViewModel> layers;

  /// Read-only history for the History Tab.
  final List<HistoryEntryViewModel> historyEntries;

  /// Read-only selection properties for the right panel. null = no selection.
  final SelectionPropertiesViewModel? selectionProperties;

  /// Read-only AI suggestions for the bottom bar.
  final List<AISuggestionViewModel> aiSuggestions;

  /// Non-null triggers the rewards overlay.
  final RewardsOverlayViewModel? rewardsOverlay;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen>
    with TickerProviderStateMixin {
  // Ephemeral UI state — permitted per PHASE-11 State Ownership Rule.
  _LeftPanelTab _leftTab = _LeftPanelTab.tools;
  bool _showAIChat = false;
  bool _previewMode = false;
  bool _showRewardsOverlay = true;
  double _zoomLevel = 1.0;
  final TextEditingController _aiChatController = TextEditingController();
  late final AnimationController _overlayAnim;

  @override
  void initState() {
    super.initState();
    _overlayAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: widget.rewardsOverlay != null ? 1.0 : 0.0,
    );
    _previewMode = widget.project.isPreviewMode;
  }

  @override
  void didUpdateWidget(EditorScreen old) {
    super.didUpdateWidget(old);
    if (widget.rewardsOverlay != null && old.rewardsOverlay == null) {
      _showRewardsOverlay = true;
      _overlayAnim.forward();
    }
    _previewMode = widget.project.isPreviewMode;
  }

  @override
  void dispose() {
    _aiChatController.dispose();
    _overlayAnim.dispose();
    super.dispose();
  }

  void _handleZoom(double delta) {
    final next = (_zoomLevel + delta).clamp(0.25, 4.0);
    setState(() => _zoomLevel = next);
    widget.delegate.onZoomChanged(next);
  }

  void _sendAIMessage() {
    final text = _aiChatController.text.trim();
    if (text.isEmpty) return;
    widget.delegate.onAIChatMessageSent(text);
    _aiChatController.clear();
  }

  void _dismissRewardsOverlay() {
    _overlayAnim.reverse().then((_) {
      if (mounted) setState(() => _showRewardsOverlay = false);
    });
    widget.delegate.onRewardsOverlayDismissed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _EdColors.canvasBg,
      appBar: _previewMode ? null : _buildAppBar(),
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 1024) {
                  return _DesktopLayout(state: this);
                } else if (constraints.maxWidth >= 600) {
                  return _TabletLayout(state: this);
                } else {
                  return _MobileLayout(state: this);
                }
              },
            ),
            // Preview mode overlay
            if (_previewMode) _PreviewModeOverlay(delegate: widget.delegate),
            // Rewards overlay
            if (widget.rewardsOverlay != null && _showRewardsOverlay)
              _RewardsOverlay(
                data: widget.rewardsOverlay!,
                animation: _overlayAnim,
                onDismiss: _dismissRewardsOverlay,
              ),
            // Future-ready: Floating Robot Assistant slot
            const _RobotAssistantSlot(),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // AppBar
  // -------------------------------------------------------------------------

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _EdColors.surface,
      elevation: 0,
      scrolledUnderElevation: 1,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        color: _EdColors.onSurface,
        onPressed: widget.delegate.onNavigateBack,
        tooltip: 'Back',
      ),
      title: _ProjectTitleChip(
        title: widget.project.title,
        isSaved: widget.project.isSaved,
      ),
      centerTitle: false,
      actions: [
        // Undo
        IconButton(
          icon: const Icon(Icons.undo_rounded),
          color: widget.project.canUndo
              ? _EdColors.onSurface
              : _EdColors.onSurfaceSubtle,
          tooltip: 'Undo',
          onPressed:
              widget.project.canUndo ? widget.delegate.onUndo : null,
        ),
        // Redo
        IconButton(
          icon: const Icon(Icons.redo_rounded),
          color: widget.project.canRedo
              ? _EdColors.onSurface
              : _EdColors.onSurfaceSubtle,
          tooltip: 'Redo',
          onPressed:
              widget.project.canRedo ? widget.delegate.onRedo : null,
        ),
        const SizedBox(width: 4),
        // AI Assist Button
        _AppBarIconTextButton(
          icon: Icons.auto_awesome_rounded,
          label: 'AI',
          color: _EdColors.accent,
          onPressed: widget.delegate.onAIAssistRequested,
          tooltip: 'AI Assist',
        ),
        // Preview Toggle
        _AppBarIconTextButton(
          icon: _previewMode ? Icons.edit_outlined : Icons.play_arrow_rounded,
          label: _previewMode ? 'Edit' : 'Preview',
          onPressed: widget.delegate.onTogglePreviewMode,
          tooltip: _previewMode ? 'Back to Edit' : 'Preview',
        ),
        // Export
        _AppBarIconTextButton(
          icon: Icons.file_upload_outlined,
          label: 'Export',
          onPressed: widget.delegate.onExport,
          tooltip: 'Export',
        ),
        // Save
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _EdColors.primary,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: widget.delegate.onSave,
            icon: Icon(
              widget.project.isSaved
                  ? Icons.check_rounded
                  : Icons.save_alt_rounded,
              size: 16,
            ),
            label: Text(
              widget.project.isSaved ? 'Saved' : 'Save',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// SECTION 5 — RESPONSIVE LAYOUTS
// ---------------------------------------------------------------------------

/// Desktop (≥1024): 3-panel — Left | Center Canvas | Right
class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({required this.state});

  final _EditorScreenState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              // Left Panel (fixed width)
              _LeftPanel(state: state, width: 220),
              const VerticalDivider(width: 1),
              // Center Canvas
              Expanded(
                child: _CenterCanvasRegion(state: state),
              ),
              const VerticalDivider(width: 1),
              // Right Panel (fixed width)
              _RightPanel(state: state, width: 240),
            ],
          ),
        ),
        const Divider(height: 1),
        // Bottom Bar
        _BottomBar(state: state),
      ],
    );
  }
}

/// Tablet (600–1023): 2-panel — Left | Canvas (right panel in bottom sheet)
class _TabletLayout extends StatelessWidget {
  const _TabletLayout({required this.state});

  final _EditorScreenState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              // Left Panel (narrower)
              _LeftPanel(state: state, width: 180),
              const VerticalDivider(width: 1),
              // Center Canvas with collapsed right panel button
              Expanded(
                child: Stack(
                  children: [
                    _CenterCanvasRegion(state: state),
                    // Right panel access button (floating)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: _PropertiesFab(
                        onTap: () => _showRightPanelSheet(context, state),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        _BottomBar(state: state),
      ],
    );
  }

  void _showRightPanelSheet(
      BuildContext context, _EditorScreenState state) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _EdColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SizedBox(
        height: 480,
        child: _RightPanel(state: state, width: double.infinity),
      ),
    );
  }
}

/// Mobile (<600): full-screen canvas, panels in bottom sheets.
class _MobileLayout extends StatelessWidget {
  const _MobileLayout({required this.state});

  final _EditorScreenState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Mini tool row
        _MobileToolRow(state: state),
        const Divider(height: 1),
        // Canvas fills remaining space
        Expanded(child: _CenterCanvasRegion(state: state)),
        const Divider(height: 1),
        // Bottom Bar
        _BottomBar(state: state),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// SECTION 6 — LEFT PANEL
// ---------------------------------------------------------------------------

class _LeftPanel extends StatelessWidget {
  const _LeftPanel({required this.state, required this.width});

  final _EditorScreenState state;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      color: _EdColors.panel,
      child: Column(
        children: [
          // Tab bar
          _LeftPanelTabBar(state: state),
          const Divider(height: 1),
          // Tab content
          Expanded(
            child: IndexedStack(
              index: state._leftTab.index,
              children: [
                _ToolsTab(state: state),
                _LayersTab(state: state),
                _HistoryTab(state: state),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeftPanelTabBar extends StatelessWidget {
  const _LeftPanelTabBar({required this.state});

  final _EditorScreenState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _LeftPanelTab.values.map((tab) {
        final selected = state._leftTab == tab;
        return Expanded(
          child: GestureDetector(
            onTap: () => state.setState(() => state._leftTab = tab),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color:
                        selected ? _EdColors.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Center(
                child: Text(
                  _tabLabel(tab),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: selected
                            ? _EdColors.primary
                            : _EdColors.onSurfaceSubtle,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _tabLabel(_LeftPanelTab tab) {
    switch (tab) {
      case _LeftPanelTab.tools:
        return 'Tools';
      case _LeftPanelTab.layers:
        return 'Layers';
      case _LeftPanelTab.history:
        return 'History';
    }
  }
}

// ── Tools Tab ────────────────────────────────────────────────────────────────

class _ToolsTab extends StatelessWidget {
  const _ToolsTab({required this.state});

  final _EditorScreenState state;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ToolSectionLabel(label: 'Insert'),
          const SizedBox(height: 8),
          // Add Text / Image
          Row(
            children: [
              Expanded(
                child: _ToolButton(
                  icon: Icons.text_fields_rounded,
                  label: 'Text',
                  onTap: state.widget.delegate.onAddText,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ToolButton(
                  icon: Icons.image_outlined,
                  label: 'Image',
                  onTap: state.widget.delegate.onAddImage,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ToolSectionLabel(label: 'Shapes'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ShapeType.values.map((s) {
              return _ShapeToolButton(
                shape: s,
                onTap: () => state.widget.delegate.onAddShape(s),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          _ToolSectionLabel(label: 'Quick Actions'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              EditorQuickAction.duplicate,
              EditorQuickAction.group,
              EditorQuickAction.bringForward,
              EditorQuickAction.sendBackward,
            ].map((a) {
              return _QuickActionChip(
                action: a,
                onTap: () => state.widget.delegate.onQuickAction(a),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          // Future-ready: Plugin Sidebar slot
          _FutureSlotButton(
            icon: Icons.extension_outlined,
            label: 'Plugins',
            onTap: state.widget.delegate.onPluginSidebarRequested,
          ),
          const SizedBox(height: 8),
          // Future-ready: Automation Dashboard slot
          _FutureSlotButton(
            icon: Icons.smart_toy_outlined,
            label: 'Automation',
            onTap: state.widget.delegate.onAutomationDashboardRequested,
          ),
        ],
      ),
    );
  }
}

// ── Layers Tab ────────────────────────────────────────────────────────────────

class _LayersTab extends StatelessWidget {
  const _LayersTab({required this.state});

  final _EditorScreenState state;

  @override
  Widget build(BuildContext context) {
    final layers = state.widget.layers;

    if (layers.isEmpty) {
      return const _EmptyPanelPlaceholder(
        icon: Icons.layers_outlined,
        message: 'No layers yet',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: layers.length,
      itemBuilder: (context, index) => _LayerRow(
        item: layers[index],
        delegate: state.widget.delegate,
      ),
    );
  }
}

class _LayerRow extends StatelessWidget {
  const _LayerRow({required this.item, required this.delegate});

  final LayerItemViewModel item;
  final EditorScreenDelegate delegate;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => delegate.onLayerSelected(item.layerId),
      child: Container(
        padding: EdgeInsets.only(
          left: 12.0 + item.depth * 12.0,
          right: 8,
          top: 6,
          bottom: 6,
        ),
        decoration: BoxDecoration(
          color: item.isSelected
              ? _EdColors.primary.withOpacity(0.08)
              : null,
          border: item.isSelected
              ? const Border(
                  left: BorderSide(color: _EdColors.primary, width: 2))
              : null,
        ),
        child: Row(
          children: [
            Icon(_layerIcon(item.type),
                size: 14, color: _EdColors.onSurfaceSubtle),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                item.label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: item.isSelected
                          ? _EdColors.primary
                          : _EdColors.onSurface,
                      fontWeight: item.isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Visibility toggle (intent only)
            GestureDetector(
              onTap: () => delegate.onLayerVisibilityToggled(item.layerId),
              child: Icon(
                item.isVisible
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 14,
                color: _EdColors.onSurfaceSubtle,
              ),
            ),
            const SizedBox(width: 6),
            // Lock toggle (intent only)
            GestureDetector(
              onTap: () => delegate.onLayerLockToggled(item.layerId),
              child: Icon(
                item.isLocked
                    ? Icons.lock_outline_rounded
                    : Icons.lock_open_rounded,
                size: 14,
                color: item.isLocked
                    ? _EdColors.primary
                    : _EdColors.onSurfaceSubtle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _layerIcon(String type) {
    switch (type.toLowerCase()) {
      case 'text':
        return Icons.text_fields_rounded;
      case 'image':
        return Icons.image_outlined;
      case 'shape':
        return Icons.crop_square_rounded;
      case 'group':
        return Icons.folder_outlined;
      default:
        return Icons.layers_outlined;
    }
  }
}

// ── History Tab ────────────────────────────────────────────────────────────────

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.state});

  final _EditorScreenState state;

  @override
  Widget build(BuildContext context) {
    final entries = state.widget.historyEntries;

    if (entries.isEmpty) {
      return const _EmptyPanelPlaceholder(
        icon: Icons.history_rounded,
        message: 'No history yet',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: entries.length,
      itemBuilder: (context, index) => _HistoryRow(
        entry: entries[index],
        onTap: () => state.widget.delegate
            .onHistoryEntrySelected(entries[index].entryId),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry, required this.onTap});

  final HistoryEntryViewModel entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: entry.isActive
                    ? _EdColors.primary
                    : _EdColors.onSurfaceSubtle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: entry.isActive
                              ? _EdColors.primary
                              : _EdColors.onSurface,
                          fontWeight: entry.isActive
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    entry.timestampLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _EdColors.onSurfaceSubtle,
                          fontSize: 10,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SECTION 7 — CENTER CANVAS REGION
// ---------------------------------------------------------------------------

class _CenterCanvasRegion extends StatelessWidget {
  const _CenterCanvasRegion({required this.state});

  final _EditorScreenState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Zoom control strip
        _ZoomControlStrip(state: state),
        // Canvas viewport
        Expanded(
          child: GestureDetector(
            onTapUp: (details) => state.widget.delegate
                .onCanvasTapped(details.localPosition),
            child: Container(
              color: _EdColors.canvasBg,
              child: Center(
                child: state.widget.canvasContent ??
                    const _CanvasEmptyPlaceholder(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ZoomControlStrip extends StatelessWidget {
  const _ZoomControlStrip({required this.state});

  final _EditorScreenState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      color: _EdColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Zoom out
          _ZoomButton(
            icon: Icons.remove_rounded,
            onTap: () => state._handleZoom(-0.1),
          ),
          const SizedBox(width: 4),
          // Zoom label
          SizedBox(
            width: 48,
            child: Text(
              '${(state._zoomLevel * 100).round()}%',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _EdColors.onSurfaceSubtle,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          // Zoom in
          _ZoomButton(
            icon: Icons.add_rounded,
            onTap: () => state._handleZoom(0.1),
          ),
          const SizedBox(width: 8),
          // Reset zoom
          GestureDetector(
            onTap: () {
              state.setState(() => state._zoomLevel = 1.0);
              state.widget.delegate.onZoomChanged(1.0);
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _EdColors.divider,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Reset',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _EdColors.onSurfaceSubtle,
                      fontSize: 10,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 16, color: _EdColors.onSurfaceSubtle),
      ),
    );
  }
}

class _CanvasEmptyPlaceholder extends StatelessWidget {
  const _CanvasEmptyPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 560,
      height: 360,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.crop_square_rounded,
                size: 40, color: _EdColors.divider),
            const SizedBox(height: 12),
            Text(
              'Canvas',
              style: TextStyle(
                  color: _EdColors.onSurfaceSubtle,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              'RenderEngine output will appear here',
              style: TextStyle(
                  color: _EdColors.onSurfaceSubtle, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SECTION 8 — RIGHT PANEL (Properties)
// ---------------------------------------------------------------------------

class _RightPanel extends StatelessWidget {
  const _RightPanel({required this.state, required this.width});

  final _EditorScreenState state;
  final double width;

  @override
  Widget build(BuildContext context) {
    final props = state.widget.selectionProperties;

    return Container(
      width: width == double.infinity ? null : width,
      color: _EdColors.panel,
      child: props == null
          ? const _EmptyPanelPlaceholder(
              icon: Icons.tune_rounded,
              message: 'Select an element\nto view properties',
            )
          : _PropertiesContent(props: props, delegate: state.widget.delegate),
    );
  }
}

class _PropertiesContent extends StatelessWidget {
  const _PropertiesContent({
    required this.props,
    required this.delegate,
  });

  final SelectionPropertiesViewModel props;
  final EditorScreenDelegate delegate;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section: Font (if applicable)
          if (props.hasTextProperties) ...[
            _PropSectionLabel(label: 'Typography'),
            const SizedBox(height: 10),
            _FontFamilyRow(props: props, delegate: delegate),
            const SizedBox(height: 8),
            _FontSizeRow(props: props, delegate: delegate),
            const SizedBox(height: 8),
            _FontStyleRow(props: props, delegate: delegate),
            const SizedBox(height: 16),
          ],
          // Section: Alignment
          _PropSectionLabel(label: 'Alignment'),
          const SizedBox(height: 10),
          _AlignmentRow(delegate: delegate),
          const SizedBox(height: 16),
          // Section: Colors
          if (props.hasColorProperties) ...[
            _PropSectionLabel(label: 'Colors'),
            const SizedBox(height: 10),
            if (props.fillColor != null)
              _ColorRow(
                label: 'Fill',
                color: props.fillColor!,
                target: EditorColorTarget.fill,
                delegate: delegate,
              ),
            if (props.strokeColor != null) ...[
              const SizedBox(height: 8),
              _ColorRow(
                label: 'Stroke',
                color: props.strokeColor!,
                target: EditorColorTarget.stroke,
                delegate: delegate,
              ),
            ],
            const SizedBox(height: 16),
          ],
          // Section: Opacity
          _PropSectionLabel(label: 'Opacity'),
          const SizedBox(height: 8),
          _OpacitySlider(opacity: props.opacity, delegate: delegate),
          const SizedBox(height: 16),
          // Section: Effects
          _PropSectionLabel(label: 'Effects'),
          const SizedBox(height: 10),
          _EffectsSection(props: props, delegate: delegate),
        ],
      ),
    );
  }
}

// ── Property sub-widgets ──────────────────────────────────────────────────────

class _FontFamilyRow extends StatelessWidget {
  const _FontFamilyRow({required this.props, required this.delegate});

  final SelectionPropertiesViewModel props;
  final EditorScreenDelegate delegate;

  static const List<String> _fonts = [
    'Inter', 'Roboto', 'Poppins', 'Playfair Display', 'Montserrat',
  ];

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: _fonts.contains(props.fontFamily) ? props.fontFamily : null,
      hint: Text(props.fontFamily ?? 'Font family',
          style: TextStyle(color: _EdColors.onSurfaceSubtle, fontSize: 13)),
      decoration: _propInputDecoration('Font Family'),
      items: _fonts
          .map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 13))))
          .toList(),
      onChanged: (v) {
        if (v != null) delegate.onFontFamilyChanged(v);
      },
      dropdownColor: _EdColors.surface,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
    );
  }
}

class _FontSizeRow extends StatelessWidget {
  const _FontSizeRow({required this.props, required this.delegate});

  final SelectionPropertiesViewModel props;
  final EditorScreenDelegate delegate;

  static const List<double> _sizes = [8, 10, 12, 14, 16, 18, 24, 32, 48, 64, 96];

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<double>(
      value: _sizes.contains(props.fontSize) ? props.fontSize : null,
      hint: Text(props.fontSize != null ? '${props.fontSize}px' : 'Size',
          style: TextStyle(color: _EdColors.onSurfaceSubtle, fontSize: 13)),
      decoration: _propInputDecoration('Font Size'),
      items: _sizes
          .map((s) => DropdownMenuItem(
              value: s,
              child: Text('${s.toInt()}px', style: const TextStyle(fontSize: 13))))
          .toList(),
      onChanged: (v) {
        if (v != null) delegate.onFontSizeChanged(v);
      },
      dropdownColor: _EdColors.surface,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
    );
  }
}

class _FontStyleRow extends StatelessWidget {
  const _FontStyleRow({required this.props, required this.delegate});

  final SelectionPropertiesViewModel props;
  final EditorScreenDelegate delegate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StyleToggleButton(
          label: 'B',
          isActive: props.isBold,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          onTap: () => delegate.onFontWeightChanged(!props.isBold),
          tooltip: 'Bold',
        ),
        const SizedBox(width: 8),
        _StyleToggleButton(
          label: 'I',
          isActive: props.isItalic,
          style: const TextStyle(
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
              fontSize: 13),
          onTap: () => delegate.onFontItalicChanged(!props.isItalic),
          tooltip: 'Italic',
        ),
      ],
    );
  }
}

class _AlignmentRow extends StatelessWidget {
  const _AlignmentRow({required this.delegate});

  final EditorScreenDelegate delegate;

  static const _alignments = [
    (EditorAlignment.left, Icons.format_align_left_rounded),
    (EditorAlignment.center, Icons.format_align_center_rounded),
    (EditorAlignment.right, Icons.format_align_right_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _alignments.map((pair) {
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: GestureDetector(
            onTap: () => delegate.onAlignmentChanged(pair.$1),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                border: Border.all(color: _EdColors.divider),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(pair.$2, size: 14, color: _EdColors.onSurface),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.label,
    required this.color,
    required this.target,
    required this.delegate,
  });

  final String label;
  final Color color;
  final EditorColorTarget target;
  final EditorScreenDelegate delegate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          // Opens a color picker intent — actual color picker is provided
          // by EditorController after receiving the intent.
          onTap: () => delegate.onColorChanged(target, color),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: _EdColors.divider),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _EdColors.onSurface,
              ),
        ),
        const Spacer(),
        Text(
          '#${color.value.toRadixString(16).toUpperCase().padLeft(8, '0').substring(2)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _EdColors.onSurfaceSubtle,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
        ),
      ],
    );
  }
}

class _OpacitySlider extends StatelessWidget {
  const _OpacitySlider({required this.opacity, required this.delegate});

  final double opacity;
  final EditorScreenDelegate delegate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: opacity.clamp(0.0, 1.0),
            min: 0,
            max: 1,
            divisions: 100,
            activeColor: _EdColors.primary,
            inactiveColor: _EdColors.divider,
            onChanged: delegate.onOpacityChanged,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '${(opacity * 100).round()}%',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _EdColors.onSurfaceSubtle,
                ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _EffectsSection extends StatelessWidget {
  const _EffectsSection({required this.props, required this.delegate});

  final SelectionPropertiesViewModel props;
  final EditorScreenDelegate delegate;

  static const _availableEffects = [
    'Shadow', 'Blur', 'Glow', 'Outline', 'Gradient',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _availableEffects.map((effect) {
        final isActive = props.activeEffects.contains(effect.toLowerCase());
        return FilterChip(
          label: Text(
            effect,
            style: TextStyle(
              fontSize: 11,
              color: isActive ? _EdColors.primary : _EdColors.onSurface,
              fontWeight:
                  isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          selected: isActive,
          selectedColor: _EdColors.primary.withOpacity(0.1),
          checkmarkColor: _EdColors.primary,
          side: BorderSide(
            color: isActive ? _EdColors.primary : _EdColors.divider,
          ),
          backgroundColor: _EdColors.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          visualDensity: VisualDensity.compact,
          onSelected: (enabled) =>
              delegate.onEffectToggled(effect.toLowerCase(), enabled),
        );
      }).toList(),
    );
  }
}

InputDecoration _propInputDecoration(String label) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
          color: _EdColors.onSurfaceSubtle, fontSize: 11),
      filled: true,
      fillColor: _EdColors.surface,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _EdColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _EdColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _EdColors.primary, width: 1.5),
      ),
      isDense: true,
    );

// ---------------------------------------------------------------------------
// SECTION 9 — BOTTOM BAR (AI Chat · Suggestions · Quick Actions)
// ---------------------------------------------------------------------------

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.state});

  final _EditorScreenState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _EdColors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // AI Chat panel (collapsible)
          if (state._showAIChat)
            _AIChatPanel(state: state),
          // Suggestions strip
          if (state.widget.aiSuggestions.isNotEmpty)
            _SuggestionsStrip(state: state),
          // Quick actions + toggle bar
          _QuickActionsBar(state: state),
        ],
      ),
    );
  }
}

class _QuickActionsBar extends StatelessWidget {
  const _QuickActionsBar({required this.state});

  final _EditorScreenState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // AI Chat toggle
          _BottomBarChip(
            icon: Icons.chat_outlined,
            label: 'AI Chat',
            isActive: state._showAIChat,
            onTap: () =>
                state.setState(() => state._showAIChat = !state._showAIChat),
          ),
          const SizedBox(width: 6),
          // Quick action chips
          ...[
            EditorQuickAction.delete,
            EditorQuickAction.duplicate,
            EditorQuickAction.flipHorizontal,
          ].map((a) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _BottomBarChip(
                  icon: _quickActionIcon(a),
                  label: _quickActionLabel(a),
                  onTap: () => state.widget.delegate.onQuickAction(a),
                ),
              )),
          const Spacer(),
          // Future-ready: Robot assistant slot
          _FutureIconButton(
            icon: Icons.smart_toy_outlined,
            tooltip: 'Robot Assistant (coming soon)',
            onTap: state.widget.delegate.onRobotAssistantRequested,
          ),
        ],
      ),
    );
  }

  IconData _quickActionIcon(EditorQuickAction action) {
    switch (action) {
      case EditorQuickAction.delete:
        return Icons.delete_outline_rounded;
      case EditorQuickAction.duplicate:
        return Icons.copy_outlined;
      case EditorQuickAction.flipHorizontal:
        return Icons.flip_rounded;
      default:
        return Icons.auto_fix_high_rounded;
    }
  }

  String _quickActionLabel(EditorQuickAction action) {
    switch (action) {
      case EditorQuickAction.delete:
        return 'Delete';
      case EditorQuickAction.duplicate:
        return 'Duplicate';
      case EditorQuickAction.flipHorizontal:
        return 'Flip';
      default:
        return action.name;
    }
  }
}

class _AIChatPanel extends StatelessWidget {
  const _AIChatPanel({required this.state});

  final _EditorScreenState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: const BoxDecoration(
        color: _EdColors.surface,
        border: Border(top: BorderSide(color: _EdColors.divider)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 14, color: _EdColors.accent),
              const SizedBox(width: 6),
              Text(
                'AI Copilot',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _EdColors.onSurface,
                    ),
              ),
              const Spacer(),
              // Future-ready: AI Copilot expansion slot
              Text(
                'Powered by AI',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _EdColors.onSurfaceSubtle,
                      fontSize: 10,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _EdColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(10),
              child: Center(
                child: Text(
                  'Ask AI to help design, generate, or modify elements...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _EdColors.onSurfaceSubtle,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: state._aiChatController,
                  style: const TextStyle(
                      color: _EdColors.onSurface, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Ask AI...',
                    hintStyle: const TextStyle(
                        color: _EdColors.onSurfaceSubtle, fontSize: 13),
                    filled: true,
                    fillColor: _EdColors.background,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: _EdColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: _EdColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: _EdColors.primary, width: 1.5),
                    ),
                    isDense: true,
                  ),
                  onSubmitted: (_) => state._sendAIMessage(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: state._sendAIMessage,
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: _EdColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.send_rounded,
                      size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuggestionsStrip extends StatelessWidget {
  const _SuggestionsStrip({required this.state});

  final _EditorScreenState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: const BoxDecoration(
        color: _EdColors.background,
        border: Border(top: BorderSide(color: _EdColors.divider)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        itemCount: state.widget.aiSuggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final s = state.widget.aiSuggestions[index];
          return GestureDetector(
            onTap: () => state.widget.delegate
                .onAISuggestionAccepted(s.suggestionId),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _EdColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _EdColors.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (s.icon != null) ...[
                    Icon(s.icon, size: 12, color: _EdColors.accent),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    s.label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: _EdColors.onSurface,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SECTION 10 — FLOATING OVERLAY SYSTEM
// ---------------------------------------------------------------------------

/// Preview mode full-screen overlay.
class _PreviewModeOverlay extends StatelessWidget {
  const _PreviewModeOverlay({required this.delegate});

  final EditorScreenDelegate delegate;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.72),
        child: Stack(
          children: [
            Center(
              child: Text(
                'Preview Mode',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 2,
                    ),
              ),
            ),
            // Exit preview
            Positioned(
              top: 16,
              right: 16,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _EdColors.onSurface,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: delegate.onTogglePreviewMode,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Back to Edit',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rewards badge overlay — dismissable, animated.
class _RewardsOverlay extends StatelessWidget {
  const _RewardsOverlay({
    required this.data,
    required this.animation,
    required this.onDismiss,
  });

  final RewardsOverlayViewModel data;
  final AnimationController animation;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.5),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: _EdColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      color: _EdColors.gold, size: 28),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          data.message,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _EdColors.onSurface,
                          ),
                        ),
                        Text(
                          '+${data.coinsEarned} coins'
                          '${data.badgeLabel != null ? ' · ${data.badgeLabel}' : ''}',
                          style: TextStyle(
                            color: _EdColors.onSurfaceSubtle,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: onDismiss,
                    child: const Icon(Icons.close_rounded,
                        size: 18, color: _EdColors.onSurfaceSubtle),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Future-ready: Floating Robot Assistant slot (UI placeholder, no execution).
class _RobotAssistantSlot extends StatelessWidget {
  const _RobotAssistantSlot();

  @override
  Widget build(BuildContext context) {
    // Reserved UI space. Activated when Robot Assistant is introduced.
    return const SizedBox.shrink();
  }
}

// ---------------------------------------------------------------------------
// SECTION 11 — MOBILE TOOL ROW
// ---------------------------------------------------------------------------

/// Compact tool strip for mobile layout (replaces left panel).
class _MobileToolRow extends StatelessWidget {
  const _MobileToolRow({required this.state});

  final _EditorScreenState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: _EdColors.panel,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        children: [
          _MobileToolChip(
              icon: Icons.text_fields_rounded,
              label: 'Text',
              onTap: state.widget.delegate.onAddText),
          const SizedBox(width: 6),
          _MobileToolChip(
              icon: Icons.image_outlined,
              label: 'Image',
              onTap: state.widget.delegate.onAddImage),
          const SizedBox(width: 6),
          _MobileToolChip(
              icon: Icons.crop_square_rounded,
              label: 'Shape',
              onTap: () =>
                  state.widget.delegate.onAddShape(ShapeType.rectangle)),
          const SizedBox(width: 6),
          _MobileToolChip(
            icon: Icons.tune_rounded,
            label: 'Properties',
            onTap: () => _showPropertiesSheet(context, state),
          ),
          const SizedBox(width: 6),
          _MobileToolChip(
            icon: Icons.layers_outlined,
            label: 'Layers',
            onTap: () => _showLayersSheet(context, state),
          ),
        ],
      ),
    );
  }

  void _showPropertiesSheet(BuildContext context, _EditorScreenState state) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _EdColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, controller) => _RightPanel(
          state: state,
          width: double.infinity,
        ),
      ),
    );
  }

  void _showLayersSheet(BuildContext context, _EditorScreenState state) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _EdColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SizedBox(
        height: 400,
        child: _LayersTab(state: state),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SECTION 12 — SHARED PRIVATE WIDGETS
// ---------------------------------------------------------------------------

class _ProjectTitleChip extends StatelessWidget {
  const _ProjectTitleChip({required this.title, required this.isSaved});

  final String title;
  final bool isSaved;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: _EdColors.onSurface,
              ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(width: 6),
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSaved ? _EdColors.accent : _EdColors.gold,
          ),
        ),
      ],
    );
  }
}

class _AppBarIconTextButton extends StatelessWidget {
  const _AppBarIconTextButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.tooltip,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final String tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? _EdColors.onSurface;
    return Tooltip(
      message: tooltip,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: c,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          visualDensity: VisualDensity.compact,
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 16, color: c),
        label: Text(label,
            style: TextStyle(
                fontSize: 12, color: c, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: _EdColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _EdColors.divider),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: _EdColors.primary),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 11,
                  color: _EdColors.onSurface,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShapeToolButton extends StatelessWidget {
  const _ShapeToolButton({required this.shape, required this.onTap});

  final ShapeType shape;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 36,
        decoration: BoxDecoration(
          color: _EdColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _EdColors.divider),
        ),
        child: Center(
          child: Icon(_shapeIcon(shape),
              size: 16, color: _EdColors.onSurfaceSubtle),
        ),
      ),
    );
  }

  IconData _shapeIcon(ShapeType shape) {
    switch (shape) {
      case ShapeType.rectangle:
        return Icons.crop_square_rounded;
      case ShapeType.circle:
        return Icons.circle_outlined;
      case ShapeType.triangle:
        return Icons.change_history_rounded;
      case ShapeType.line:
        return Icons.horizontal_rule_rounded;
      case ShapeType.polygon:
        return Icons.pentagon_outlined;
      case ShapeType.star:
        return Icons.star_outline_rounded;
    }
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({required this.action, required this.onTap});

  final EditorQuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _EdColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _EdColors.divider),
        ),
        child: Text(
          action.name,
          style: const TextStyle(
              fontSize: 11,
              color: _EdColors.onSurface,
              fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _FutureSlotButton extends StatelessWidget {
  const _FutureSlotButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _EdColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: _EdColors.primary.withOpacity(0.2),
              style: BorderStyle.solid),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: _EdColors.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: _EdColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            const Text(
              'Soon',
              style: TextStyle(
                  fontSize: 10, color: _EdColors.onSurfaceSubtle),
            ),
          ],
        ),
      ),
    );
  }
}

class _FutureIconButton extends StatelessWidget {
  const _FutureIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _EdColors.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: _EdColors.primary),
        ),
      ),
    );
  }
}

class _PropertiesFab extends StatelessWidget {
  const _PropertiesFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _EdColors.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.tune_rounded,
            size: 18, color: _EdColors.primary),
      ),
    );
  }
}

class _ToolSectionLabel extends StatelessWidget {
  const _ToolSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: _EdColors.onSurfaceSubtle,
            fontWeight: FontWeight.w700,
            fontSize: 10,
            letterSpacing: 0.8,
          ),
    );
  }
}

class _PropSectionLabel extends StatelessWidget {
  const _PropSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: _EdColors.onSurfaceSubtle,
            fontWeight: FontWeight.w700,
            fontSize: 10,
            letterSpacing: 0.6,
          ),
    );
  }
}

class _StyleToggleButton extends StatelessWidget {
  const _StyleToggleButton({
    required this.label,
    required this.isActive,
    required this.style,
    required this.onTap,
    required this.tooltip,
  });

  final String label;
  final bool isActive;
  final TextStyle style;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 28,
          decoration: BoxDecoration(
            color: isActive
                ? _EdColors.primary.withOpacity(0.1)
                : _EdColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color:
                  isActive ? _EdColors.primary : _EdColors.divider,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: style.copyWith(
                color: isActive ? _EdColors.primary : _EdColors.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBarChip extends StatelessWidget {
  const _BottomBarChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? _EdColors.primary.withOpacity(0.1)
              : _EdColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? _EdColors.primary : _EdColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 12,
                color: isActive
                    ? _EdColors.primary
                    : _EdColors.onSurfaceSubtle),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive
                    ? _EdColors.primary
                    : _EdColors.onSurface,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileToolChip extends StatelessWidget {
  const _MobileToolChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: _EdColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _EdColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: _EdColors.primary),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 11,
                  color: _EdColors.onSurface,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPanelPlaceholder extends StatelessWidget {
  const _EmptyPanelPlaceholder({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28, color: _EdColors.onSurfaceSubtle),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _EdColors.onSurfaceSubtle,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SECTION 13 — DESIGN TOKENS
// ---------------------------------------------------------------------------

abstract final class _EdColors {
  static const Color primary = Color(0xFF5B4CF5);
  static const Color accent = Color(0xFF00BFA6);
  static const Color gold = Color(0xFFFFC107);
  static const Color canvasBg = Color(0xFFE8EAF0);
  static const Color background = Color(0xFFF6F7FB);
  static const Color surface = Colors.white;
  static const Color panel = Color(0xFFF0F1F7);
  static const Color onBackground = Color(0xFF1A1A2E);
  static const Color onSurface = Color(0xFF1A1A2E);
  static const Color onSurfaceSubtle = Color(0xFF8A8FAB);
  static const Color divider = Color(0xFFE0E2EC);
}
