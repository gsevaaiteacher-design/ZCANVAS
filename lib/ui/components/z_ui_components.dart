// ui/components/z_ui_components.dart
//
// PHASE-12 — Z-CANVAS Reusable UI Component Library (FILE-2)
//
// ===========================================================================
// OWNERSHIP CONTRACT
// ===========================================================================
//
// WHAT THIS FILE CAN DO:
//   • Define all reusable visual UI components for Z-CANVAS
//   • Hold ephemeral interaction state (press animation, focus, hover)
//   • Emit intent via callback parameters (onTap, onChanged, onSubmit)
//   • Use only tokens from z_canvas_theme.dart (no hardcoded values)
//   • Run shimmer animations for loading skeletons (visual only)
//
// WHAT THIS FILE CANNOT DO:
//   ❌ Execute business logic
//   ❌ Call EditorController or any engine
//   ❌ Modify application state
//   ❌ Navigate independently
//   ❌ Access Canvas, layers, history, or storage
//   ❌ Contain hardcoded color, radius, or spacing values
//
// INTERACTION RULE:
//   On user tap → emit intent callback only.
//   The receiving Phase-11 Screen routes intent to EditorController.
//
// AUTHORITY: REUSABLE VISUAL COMPONENT LIBRARY.
//   Pure rendering. Zero logic. Zero execution.
// ===========================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/z_canvas_theme.dart';

// ===========================================================================
// SECTION 1 — BUTTONS
// ===========================================================================

// ---------------------------------------------------------------------------
// 1A — ZPrimaryButton
// ---------------------------------------------------------------------------

/// Full-width or intrinsic-width primary action button.
///
/// Emits [onPressed] intent only. No execution.
class ZPrimaryButton extends StatelessWidget {
  const ZPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.size = ZButtonSize.medium,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final ZButtonSize size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final heights = _buttonHeight(size);
    final textStyle = _buttonTextStyle(context, size);

    final child = isLoading
        ? SizedBox(
            width: ZSize.iconSm,
            height: ZSize.iconSm,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(cs.onPrimary),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: ZSize.iconSm),
                const SizedBox(width: ZSpacing.xs),
              ],
              Text(label, style: textStyle),
            ],
          );

    final button = FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        minimumSize: Size(0, heights),
        padding: ZSpacing.buttonInsets,
        shape: RoundedRectangleBorder(borderRadius: ZRadius.mdBorder),
        disabledBackgroundColor: cs.onSurface.withOpacity(0.12),
      ),
      onPressed: isLoading ? null : onPressed,
      child: child,
    );

    return isFullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}

// ---------------------------------------------------------------------------
// 1B — ZSecondaryButton
// ---------------------------------------------------------------------------

/// Outlined secondary action button.
class ZSecondaryButton extends StatelessWidget {
  const ZSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isFullWidth = false,
    this.size = ZButtonSize.medium,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isFullWidth;
  final ZButtonSize size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final heights = _buttonHeight(size);
    final textStyle = _buttonTextStyle(context, size);

    final button = OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.primary,
        minimumSize: Size(0, heights),
        padding: ZSpacing.buttonInsets,
        side: BorderSide(color: cs.primary),
        shape: RoundedRectangleBorder(borderRadius: ZRadius.mdBorder),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: ZSize.iconSm),
            const SizedBox(width: ZSpacing.xs),
          ],
          Text(label, style: textStyle),
        ],
      ),
    );

    return isFullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}

// ---------------------------------------------------------------------------
// 1C — ZGhostButton
// ---------------------------------------------------------------------------

/// Ghost (text-only) low-priority action button.
class ZGhostButton extends StatelessWidget {
  const ZGhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.size = ZButtonSize.medium,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ZButtonSize size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.primary;
    final heights = _buttonHeight(size);
    final textStyle = _buttonTextStyle(context, size)?.copyWith(color: c);

    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: c,
        minimumSize: Size(0, heights),
        padding: ZSpacing.buttonInsets,
        shape: RoundedRectangleBorder(borderRadius: ZRadius.mdBorder),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: ZSize.iconSm, color: c),
            const SizedBox(width: ZSpacing.xs),
          ],
          Text(label, style: textStyle),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1D — ZToolbarIconButton
// ---------------------------------------------------------------------------

/// Toolbar-style icon button with optional tooltip and active state.
class ZToolbarIconButton extends StatelessWidget {
  const ZToolbarIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.isActive = false,
    this.isDestructive = false,
    this.size = ZSize.iconMd,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool isActive;
  final bool isDestructive;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<ZThemeExtension>();

    final iconColor = isDestructive
        ? cs.error
        : isActive
            ? cs.primary
            : cs.onSurface;

    final bgColor = isActive
        ? cs.primaryContainer
        : Colors.transparent;

    final button = Material(
      color: bgColor,
      borderRadius: ZRadius.smBorder,
      child: InkWell(
        borderRadius: ZRadius.smBorder,
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(ZSpacing.xs),
          child: Icon(icon, size: size, color: iconColor),
        ),
      ),
    );

    return tooltip != null
        ? Tooltip(message: tooltip!, child: button)
        : button;
  }
}

// ---------------------------------------------------------------------------
// 1E — ZIconTextButton
// ---------------------------------------------------------------------------

/// AppBar-style compact icon + label button.
class ZIconTextButton extends StatelessWidget {
  const ZIconTextButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.onSurface;

    final button = TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: c,
        padding: const EdgeInsets.symmetric(
          horizontal: ZSpacing.sm,
          vertical: ZSpacing.xs,
        ),
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: ZRadius.smBorder),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: ZSize.iconSm, color: c),
      label: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: c,
              fontWeight: ZTypeface.weightMedium,
            ),
      ),
    );

    return tooltip != null
        ? Tooltip(message: tooltip!, child: button)
        : button;
  }
}

// ---------------------------------------------------------------------------
// Button size enum + helpers
// ---------------------------------------------------------------------------

enum ZButtonSize { small, medium, large }

double _buttonHeight(ZButtonSize size) {
  switch (size) {
    case ZButtonSize.small:
      return ZSize.buttonSmHeight;
    case ZButtonSize.medium:
      return ZSize.buttonMdHeight;
    case ZButtonSize.large:
      return ZSize.buttonLgHeight;
  }
}

TextStyle? _buttonTextStyle(BuildContext context, ZButtonSize size) {
  final tt = Theme.of(context).textTheme;
  switch (size) {
    case ZButtonSize.small:
      return tt.labelSmall?.copyWith(fontWeight: ZTypeface.weightSemiBold);
    case ZButtonSize.medium:
      return tt.labelLarge?.copyWith(fontWeight: ZTypeface.weightSemiBold);
    case ZButtonSize.large:
      return tt.titleSmall?.copyWith(fontWeight: ZTypeface.weightSemiBold);
  }
}

// ===========================================================================
// SECTION 2 — CARDS
// ===========================================================================

// ---------------------------------------------------------------------------
// 2A — ZProjectCard
// ---------------------------------------------------------------------------

/// Project thumbnail card — read-only display, tap emits intent.
class ZProjectCard extends StatelessWidget {
  const ZProjectCard({
    super.key,
    required this.title,
    required this.lastEditedLabel,
    required this.onTap,
    this.thumbnailColor,
    this.thumbnailWidget,
    this.width,
    this.aspectRatio = ZSize.projectCardAspect,
  });

  final String title;
  final String lastEditedLabel;
  final VoidCallback onTap;
  final Color? thumbnailColor;
  final Widget? thumbnailWidget;
  final double? width;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<ZThemeExtension>();
    final tt = Theme.of(context).textTheme;

    final thumbBg = thumbnailColor ?? cs.primaryContainer;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: ZRadius.lgBorder,
          border: Border.all(color: ext?.divider ?? cs.outline),
          boxShadow: ZShadow.xs,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            AspectRatio(
              aspectRatio: aspectRatio,
              child: Container(
                color: thumbBg,
                child: thumbnailWidget ??
                    Center(
                      child: Icon(
                        Icons.image_outlined,
                        size: ZSize.iconXl,
                        color: thumbBg.withOpacity(0.6),
                      ),
                    ),
              ),
            ),
            // Footer
            Padding(
              padding: const EdgeInsets.all(ZSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tt.labelLarge?.copyWith(
                      fontWeight: ZTypeface.weightSemiBold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: ZSpacing.xxs),
                  Text(
                    lastEditedLabel,
                    style: tt.labelSmall?.copyWith(
                      color: ext?.onSurfaceSubtle,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
// 2B — ZTemplateCard
// ---------------------------------------------------------------------------

/// Template preview card — horizontal carousel or vertical list style.
class ZTemplateCard extends StatelessWidget {
  const ZTemplateCard({
    super.key,
    required this.title,
    required this.onTap,
    this.category,
    this.previewColor,
    this.previewWidget,
    this.isSelected = false,
    this.layout = ZCardLayout.vertical,
  });

  final String title;
  final VoidCallback onTap;
  final String? category;
  final Color? previewColor;
  final Widget? previewWidget;
  final bool isSelected;
  final ZCardLayout layout;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<ZThemeExtension>();
    final tt = Theme.of(context).textTheme;

    final thumbBg = previewColor ?? cs.primaryContainer;
    final borderColor = isSelected ? cs.primary : (ext?.divider ?? cs.outline);
    final borderWidth = isSelected ? 2.0 : 1.0;

    return GestureDetector(
      onTap: onTap,
      child: layout == ZCardLayout.vertical
          ? _TemplateVertical(
              title: title,
              category: category,
              thumbBg: thumbBg,
              previewWidget: previewWidget,
              borderColor: borderColor,
              borderWidth: borderWidth,
              isSelected: isSelected,
              cs: cs,
              ext: ext,
              tt: tt,
            )
          : _TemplateHorizontal(
              title: title,
              category: category,
              thumbBg: thumbBg,
              previewWidget: previewWidget,
              borderColor: borderColor,
              borderWidth: borderWidth,
              isSelected: isSelected,
              cs: cs,
              ext: ext,
              tt: tt,
            ),
    );
  }
}

class _TemplateVertical extends StatelessWidget {
  const _TemplateVertical({
    required this.title,
    required this.category,
    required this.thumbBg,
    required this.previewWidget,
    required this.borderColor,
    required this.borderWidth,
    required this.isSelected,
    required this.cs,
    required this.ext,
    required this.tt,
  });

  final String title;
  final String? category;
  final Color thumbBg;
  final Widget? previewWidget;
  final Color borderColor;
  final double borderWidth;
  final bool isSelected;
  final ColorScheme cs;
  final ZThemeExtension? ext;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ZSize.templateCardWidth,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: ZRadius.mdBorder,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: ZSize.templateCardHeight * 0.65,
            child: Container(
              color: thumbBg,
              child: previewWidget ??
                  Center(
                    child: Icon(Icons.image_outlined,
                        size: ZSize.iconXl,
                        color: thumbBg.withOpacity(0.5)),
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(ZSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: tt.labelMedium
                        ?.copyWith(fontWeight: ZTypeface.weightSemiBold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (category != null)
                  Text(category!,
                      style: tt.labelSmall
                          ?.copyWith(color: ext?.onSurfaceSubtle, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateHorizontal extends StatelessWidget {
  const _TemplateHorizontal({
    required this.title,
    required this.category,
    required this.thumbBg,
    required this.previewWidget,
    required this.borderColor,
    required this.borderWidth,
    required this.isSelected,
    required this.cs,
    required this.ext,
    required this.tt,
  });

  final String title;
  final String? category;
  final Color thumbBg;
  final Widget? previewWidget;
  final Color borderColor;
  final double borderWidth;
  final bool isSelected;
  final ColorScheme cs;
  final ZThemeExtension? ext;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: ZRadius.mdBorder,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Container(
              color: thumbBg,
              child: previewWidget ??
                  Center(
                    child: Icon(Icons.image_outlined,
                        size: ZSize.iconLg,
                        color: thumbBg.withOpacity(0.5)),
                  ),
            ),
          ),
          const SizedBox(width: ZSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: ZSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title,
                      style: tt.bodyMedium
                          ?.copyWith(fontWeight: ZTypeface.weightSemiBold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (category != null)
                    Text(category!,
                        style: tt.bodySmall
                            ?.copyWith(color: ext?.onSurfaceSubtle),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: ZSpacing.sm),
            child: Icon(Icons.chevron_right_rounded,
                size: ZSize.iconSm, color: ext?.onSurfaceSubtle),
          ),
        ],
      ),
    );
  }
}

enum ZCardLayout { vertical, horizontal }

// ---------------------------------------------------------------------------
// 2C — ZRewardCard
// ---------------------------------------------------------------------------

/// Reward / achievement display card.
class ZRewardCard extends StatelessWidget {
  const ZRewardCard({
    super.key,
    required this.title,
    required this.description,
    required this.coins,
    this.badgeIcon = Icons.emoji_events_rounded,
    this.badgeColor,
    this.isUnlocked = true,
    this.onTap,
  });

  final String title;
  final String description;
  final int coins;
  final IconData badgeIcon;
  final Color? badgeColor;
  final bool isUnlocked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<ZThemeExtension>();
    final tt = Theme.of(context).textTheme;
    final gold = ext?.accent ?? ZColorsLight.accent;
    final badgeC = badgeColor ?? gold;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isUnlocked ? 1.0 : 0.5,
        child: Container(
          padding: ZSpacing.cardInsets,
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: ZRadius.lgBorder,
            border: Border.all(color: ext?.divider ?? cs.outline),
            boxShadow: ZShadow.xs,
          ),
          child: Row(
            children: [
              // Badge icon
              Container(
                width: ZSize.avatarLg,
                height: ZSize.avatarLg,
                decoration: BoxDecoration(
                  color: badgeC.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(badgeIcon, color: badgeC, size: ZSize.iconLg),
              ),
              const SizedBox(width: ZSpacing.md),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: tt.titleSmall
                            ?.copyWith(fontWeight: ZTypeface.weightSemiBold)),
                    const SizedBox(height: ZSpacing.xxs),
                    Text(description,
                        style: tt.bodySmall
                            ?.copyWith(color: ext?.onSurfaceSubtle),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: ZSpacing.sm),
              // Coin badge
              ZCoinBadge(coins: coins, size: ZBadgeSize.small),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// SECTION 3 — INPUT FIELDS
// ===========================================================================

// ---------------------------------------------------------------------------
// 3A — ZSearchField
// ---------------------------------------------------------------------------

/// Search input field with leading search icon and optional clear button.
class ZSearchField extends StatefulWidget {
  const ZSearchField({
    super.key,
    required this.onChanged,
    this.hint = 'Search...',
    this.onClear,
    this.autofocus = false,
    this.controller,
  });

  final ValueChanged<String> onChanged;
  final String hint;
  final VoidCallback? onClear;
  final bool autofocus;
  final TextEditingController? controller;

  @override
  State<ZSearchField> createState() => _ZSearchFieldState();
}

class _ZSearchFieldState extends State<ZSearchField> {
  late final TextEditingController _ctrl;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _ctrl = widget.controller ?? TextEditingController();
    _ctrl.addListener(() {
      final has = _ctrl.text.isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    if (widget.controller == null) _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<ZThemeExtension>();

    return TextField(
      controller: _ctrl,
      autofocus: widget.autofocus,
      onChanged: widget.onChanged,
      style: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(color: cs.onSurface),
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon:
            Icon(Icons.search_rounded, size: ZSize.iconMd, color: ext?.onSurfaceSubtle),
        suffixIcon: _hasText
            ? IconButton(
                icon: Icon(Icons.close_rounded,
                    size: ZSize.iconSm, color: ext?.onSurfaceSubtle),
                onPressed: () {
                  _ctrl.clear();
                  widget.onClear?.call();
                  widget.onChanged('');
                },
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ZSpacing.md,
          vertical: ZSpacing.sm,
        ),
        filled: true,
        fillColor: cs.surface,
        border: OutlineInputBorder(
          borderRadius: ZRadius.pillBorder,
          borderSide: BorderSide(color: ext?.divider ?? cs.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: ZRadius.pillBorder,
          borderSide: BorderSide(color: ext?.divider ?? cs.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: ZRadius.pillBorder,
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        isDense: true,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3B — ZPromptField
// ---------------------------------------------------------------------------

/// Multi-line AI prompt input with voice button slot and character counter.
class ZPromptField extends StatefulWidget {
  const ZPromptField({
    super.key,
    required this.onChanged,
    this.onVoicePressed,
    this.onSubmit,
    this.hint = 'Describe your design...',
    this.maxLines = 4,
    this.minLines = 3,
    this.maxLength,
    this.controller,
  });

  final ValueChanged<String> onChanged;

  /// Voice button intent — UI placeholder only. No execution.
  final VoidCallback? onVoicePressed;

  final ValueChanged<String>? onSubmit;
  final String hint;
  final int maxLines;
  final int minLines;
  final int? maxLength;
  final TextEditingController? controller;

  @override
  State<ZPromptField> createState() => _ZPromptFieldState();
}

class _ZPromptFieldState extends State<ZPromptField> {
  late final TextEditingController _ctrl;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _ctrl = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    if (widget.controller == null) _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<ZThemeExtension>();
    final tt = Theme.of(context).textTheme;

    return Focus(
      onFocusChange: (f) => setState(() => _isFocused = f),
      child: AnimatedContainer(
        duration: ZDuration.fast,
        curve: ZCurve.enter,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: ZRadius.lgBorder,
          border: Border.all(
            color: _isFocused ? cs.primary : (ext?.divider ?? cs.outline),
            width: _isFocused ? 1.5 : 1.0,
          ),
          boxShadow: _isFocused ? ZShadow.primaryGlow : ZShadow.none,
        ),
        child: Stack(
          children: [
            TextField(
              controller: _ctrl,
              maxLines: widget.maxLines,
              minLines: widget.minLines,
              maxLength: widget.maxLength,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmit,
              style: tt.bodyMedium?.copyWith(color: cs.onSurface),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: tt.bodyMedium?.copyWith(
                  color: ext?.onSurfaceSubtle,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.fromLTRB(
                  ZSpacing.lg,
                  ZSpacing.md,
                  ZSpacing.xxxxl + ZSpacing.sm,
                  ZSpacing.md,
                ),
                counterText: '',
              ),
            ),
            // Voice button — UI placeholder, no execution
            if (widget.onVoicePressed != null)
              Positioned(
                right: ZSpacing.xs,
                bottom: ZSpacing.xs,
                child: _VoiceIconButton(onPressed: widget.onVoicePressed!),
              ),
          ],
        ),
      ),
    );
  }
}

class _VoiceIconButton extends StatelessWidget {
  const _VoiceIconButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Voice input (coming soon)',
      child: Material(
        color: cs.primaryContainer,
        borderRadius: ZRadius.smBorder,
        child: InkWell(
          borderRadius: ZRadius.smBorder,
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(ZSpacing.xs),
            child: Icon(Icons.mic_outlined,
                size: ZSize.iconSm, color: cs.primary),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// SECTION 4 — PANELS
// ===========================================================================

// ---------------------------------------------------------------------------
// 4A — ZSidePanel
// ---------------------------------------------------------------------------

/// Side panel container (left or right workspace panel).
class ZSidePanel extends StatelessWidget {
  const ZSidePanel({
    super.key,
    required this.child,
    this.width = ZSize.leftPanelWidth,
    this.header,
    this.footer,
  });

  final Widget child;
  final double width;
  final Widget? header;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<ZThemeExtension>();

    return Container(
      width: width,
      color: ext?.surfacePanel ?? cs.surfaceContainerHighest,
      child: Column(
        children: [
          if (header != null) ...[
            header!,
            Divider(height: 1, color: ext?.divider ?? cs.outline),
          ],
          Expanded(child: child),
          if (footer != null) ...[
            Divider(height: 1, color: ext?.divider ?? cs.outline),
            footer!,
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4B — ZBottomSheet (helper builder)
// ---------------------------------------------------------------------------

/// Shows a Z-CANVAS branded bottom sheet.
///
/// Pure visual wrapper — content + intent callbacks defined by caller.
Future<T?> showZBottomSheet<T>({
  required BuildContext context,
  required Widget child,
  String? title,
  bool isDismissible = true,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isDismissible: isDismissible,
    isScrollControlled: isScrollControlled,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(borderRadius: ZRadius.topOnlyXl),
    builder: (ctx) => _ZBottomSheetContent(title: title, child: child),
  );
}

class _ZBottomSheetContent extends StatelessWidget {
  const _ZBottomSheetContent({this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<ZThemeExtension>();
    final tt = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle
        Padding(
          padding: const EdgeInsets.only(top: ZSpacing.sm),
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: ext?.divider ?? cs.outline,
              borderRadius: ZRadius.pillBorder,
            ),
          ),
        ),
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ZSpacing.screenEdge,
              ZSpacing.md,
              ZSpacing.screenEdge,
              ZSpacing.xs,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title!,
                style: tt.titleMedium
                    ?.copyWith(fontWeight: ZTypeface.weightSemiBold),
              ),
            ),
          ),
          Divider(height: 1, color: ext?.divider ?? cs.outline),
        ],
        child,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 4C — ZModal (dialog-style)
// ---------------------------------------------------------------------------

/// Z-CANVAS branded modal dialog.
///
/// [actions] are pure callback-emitting buttons. No execution inside.
class ZModal extends StatelessWidget {
  const ZModal({
    super.key,
    required this.title,
    required this.content,
    this.actions = const [],
    this.icon,
    this.isDestructive = false,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;
  final IconData? icon;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<ZThemeExtension>();
    final tt = Theme.of(context).textTheme;

    final iconColor = isDestructive ? cs.error : cs.primary;

    return Dialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: ZRadius.xlBorder),
      child: Padding(
        padding: ZSpacing.panelInsets,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Container(
                width: ZSize.avatarLg,
                height: ZSize.avatarLg,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: ZRadius.mdBorder,
                ),
                child: Icon(icon, color: iconColor, size: ZSize.iconLg),
              ),
              const SizedBox(height: ZSpacing.md),
            ],
            Text(title,
                style: tt.headlineMedium
                    ?.copyWith(fontWeight: ZTypeface.weightBold)),
            const SizedBox(height: ZSpacing.sm),
            content,
            if (actions.isNotEmpty) ...[
              const SizedBox(height: ZSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions
                    .map((a) => Padding(
                          padding: const EdgeInsets.only(left: ZSpacing.sm),
                          child: a,
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// SECTION 5 — BADGES & REWARDS
// ===========================================================================

enum ZBadgeSize { small, medium, large }

// ---------------------------------------------------------------------------
// 5A — ZCoinBadge
// ---------------------------------------------------------------------------

/// Coin count badge — gold icon + number.
class ZCoinBadge extends StatelessWidget {
  const ZCoinBadge({
    super.key,
    required this.coins,
    this.size = ZBadgeSize.medium,
  });

  final int coins;
  final ZBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ZThemeExtension>();
    final gold = ext?.accent ?? ZColorsLight.accent;
    final iconSize = _badgeIconSize(size);
    final fontSize = _badgeFontSize(size);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size == ZBadgeSize.small ? ZSpacing.xs : ZSpacing.sm,
        vertical: ZSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: gold.withOpacity(0.12),
        borderRadius: ZRadius.pillBorder,
        border: Border.all(color: gold.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.monetization_on_rounded, color: gold, size: iconSize),
          const SizedBox(width: ZSpacing.xxs),
          Text(
            coins.toString(),
            style: TextStyle(
              fontFamily: ZTypeface.bodyFamily,
              fontSize: fontSize,
              fontWeight: ZTypeface.weightSemiBold,
              color: gold,
            ),
          ),
        ],
      ),
    );
  }

  double _badgeIconSize(ZBadgeSize s) {
    switch (s) {
      case ZBadgeSize.small:
        return ZSize.iconXs;
      case ZBadgeSize.medium:
        return ZSize.iconSm;
      case ZBadgeSize.large:
        return ZSize.iconMd;
    }
  }

  double _badgeFontSize(ZBadgeSize s) {
    switch (s) {
      case ZBadgeSize.small:
        return ZTypeface.sizeCaption;
      case ZBadgeSize.medium:
        return ZTypeface.sizeLabelMedium;
      case ZBadgeSize.large:
        return ZTypeface.sizeLabelLarge;
    }
  }
}

// ---------------------------------------------------------------------------
// 5B — ZLevelBadge
// ---------------------------------------------------------------------------

/// Level / rank badge — shows level number with colored pill.
class ZLevelBadge extends StatelessWidget {
  const ZLevelBadge({
    super.key,
    required this.level,
    this.label,
    this.color,
    this.size = ZBadgeSize.medium,
  });

  final int level;
  final String? label;
  final Color? color;
  final ZBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.primary;
    final fontSize = size == ZBadgeSize.small
        ? ZTypeface.sizeCaption
        : ZTypeface.sizeLabelMedium;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ZSpacing.sm,
        vertical: ZSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: ZRadius.pillBorder,
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Text(
        label ?? 'Lv.$level',
        style: TextStyle(
          fontFamily: ZTypeface.bodyFamily,
          fontSize: fontSize,
          fontWeight: ZTypeface.weightSemiBold,
          color: c,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5C — ZPremiumBadge
// ---------------------------------------------------------------------------

/// Premium / pro indicator badge.
class ZPremiumBadge extends StatelessWidget {
  const ZPremiumBadge({
    super.key,
    this.label = 'PRO',
    this.size = ZBadgeSize.small,
  });

  final String label;
  final ZBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ZThemeExtension>();
    final gold = ext?.accent ?? ZColorsLight.accent;
    final fontSize = size == ZBadgeSize.small
        ? ZTypeface.sizeCaption
        : ZTypeface.sizeLabelMedium;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ZSpacing.xs,
        vertical: ZSpacing.xxs,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gold, gold.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: ZRadius.smBorder,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: ZTypeface.bodyFamily,
          fontSize: fontSize,
          fontWeight: ZTypeface.weightBold,
          color: ZColorsLight.onAccent,
          letterSpacing: ZTypeface.trackingWider,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5D — ZRewardPill
// ---------------------------------------------------------------------------

/// Inline reward event pill ("+50 coins" / "🏆 Badge unlocked").
class ZRewardPill extends StatelessWidget {
  const ZRewardPill({
    super.key,
    required this.label,
    this.icon = Icons.star_rounded,
    this.color,
  });

  final String label;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.primary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ZSpacing.sm,
        vertical: ZSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: ZRadius.pillBorder,
        border: Border.all(color: c.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: ZSize.iconXs, color: c),
          const SizedBox(width: ZSpacing.xxs),
          Text(
            label,
            style: TextStyle(
              fontFamily: ZTypeface.bodyFamily,
              fontSize: ZTypeface.sizeCaption,
              fontWeight: ZTypeface.weightSemiBold,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// SECTION 6 — NAVIGATION CHIPS
// ===========================================================================

// ---------------------------------------------------------------------------
// 6A — ZNavChip
// ---------------------------------------------------------------------------

/// Navigation chip — single-select tab-style chip row entry.
class ZNavChip extends StatelessWidget {
  const ZNavChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.badge,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: ZDuration.fast,
        curve: ZCurve.standard,
        padding: const EdgeInsets.symmetric(
          horizontal: ZSpacing.md,
          vertical: ZSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isSelected ? cs.primaryContainer : Colors.transparent,
          borderRadius: ZRadius.pillBorder,
          border: Border.all(
            color: isSelected ? cs.primary : cs.outline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: ZSize.iconSm,
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: ZSpacing.xs),
            ],
            Text(
              label,
              style: tt.labelMedium?.copyWith(
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
                fontWeight: isSelected
                    ? ZTypeface.weightSemiBold
                    : ZTypeface.weightMedium,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: ZSpacing.xs),
              badge!,
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 6B — ZNavChipRow
// ---------------------------------------------------------------------------

/// Horizontally scrollable row of [ZNavChip] items.
class ZNavChipRow extends StatelessWidget {
  const ZNavChipRow({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    this.padding,
  });

  final List<ZNavChipItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding ??
            const EdgeInsets.symmetric(horizontal: ZSpacing.screenEdge),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: ZSpacing.xs),
        itemBuilder: (context, index) {
          final item = items[index];
          return ZNavChip(
            label: item.label,
            isSelected: index == selectedIndex,
            onTap: () => onSelect(index),
            icon: item.icon,
          );
        },
      ),
    );
  }
}

/// Data model for a [ZNavChipRow] item.
final class ZNavChipItem {
  const ZNavChipItem({required this.label, this.icon});

  final String label;
  final IconData? icon;
}

// ---------------------------------------------------------------------------
// 6C — ZFilterChipButton
// ---------------------------------------------------------------------------

/// Multi-select filter chip (avoids name collision with Flutter FilterChip).
class ZFilterChipButton extends StatelessWidget {
  const ZFilterChipButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onToggle,
    this.icon,
  });

  final String label;
  final bool isSelected;
  final ValueChanged<bool> onToggle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon,
                size: ZSize.iconXs,
                color: isSelected ? cs.primary : cs.onSurfaceVariant),
            const SizedBox(width: ZSpacing.xxs),
          ],
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: isSelected ? cs.primary : cs.onSurface,
              fontWeight: isSelected
                  ? ZTypeface.weightSemiBold
                  : ZTypeface.weightRegular,
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: onToggle,
      selectedColor: cs.primaryContainer,
      checkmarkColor: cs.primary,
      side: BorderSide(color: isSelected ? cs.primary : cs.outline),
      shape: RoundedRectangleBorder(borderRadius: ZRadius.pillBorder),
      backgroundColor: cs.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: ZSpacing.xs,
        vertical: ZSpacing.xxs,
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

// ===========================================================================
// SECTION 7 — LOADING SKELETONS
// ===========================================================================

// ---------------------------------------------------------------------------
// 7A — ZSkeletonBox (base shimmer primitive)
// ---------------------------------------------------------------------------

/// Animated shimmer skeleton box. Pure visual loading placeholder.
class ZSkeletonBox extends StatefulWidget {
  const ZSkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<ZSkeletonBox> createState() => _ZSkeletonBoxState();
}

class _ZSkeletonBoxState extends State<ZSkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _anim = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _ctrl, curve: ZCurve.linear),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<ZThemeExtension>();
    final baseColor = ext?.divider ?? cs.outline;
    final shimmerColor = cs.surface;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? ZRadius.smBorder,
            gradient: LinearGradient(
              begin: Alignment(_anim.value - 1, 0),
              end: Alignment(_anim.value, 0),
              colors: [baseColor, shimmerColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 7B — ZSkeletonText
// ---------------------------------------------------------------------------

/// Skeleton placeholder for a line of text.
class ZSkeletonText extends StatelessWidget {
  const ZSkeletonText({
    super.key,
    this.width,
    this.widthFraction = 1.0,
    this.height = 13,
  });

  final double? width;

  /// Fraction of available width (0.0–1.0).
  final double widthFraction;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = width ?? constraints.maxWidth * widthFraction;
        return ZSkeletonBox(
          width: w,
          height: height,
          borderRadius: ZRadius.smBorder,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 7C — ZSkeletonProjectCard
// ---------------------------------------------------------------------------

/// Full project card skeleton.
class ZSkeletonProjectCard extends StatelessWidget {
  const ZSkeletonProjectCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<ZThemeExtension>();

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: ZRadius.lgBorder,
        border: Border.all(color: ext?.divider ?? cs.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Thumbnail skeleton
          AspectRatio(
            aspectRatio: ZSize.projectCardAspect,
            child: ZSkeletonBox(
              height: double.infinity,
              borderRadius: BorderRadius.zero,
            ),
          ),
          // Footer skeleton
          Padding(
            padding: const EdgeInsets.all(ZSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ZSkeletonText(height: 14),
                SizedBox(height: ZSpacing.xxs),
                ZSkeletonText(widthFraction: 0.6, height: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 7D — ZSkeletonListItem
// ---------------------------------------------------------------------------

/// Skeleton for a generic list row (icon + two text lines).
class ZSkeletonListItem extends StatelessWidget {
  const ZSkeletonListItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ZSpacing.lg,
        vertical: ZSpacing.sm,
      ),
      child: Row(
        children: [
          ZSkeletonBox(
            width: ZSize.avatarMd,
            height: ZSize.avatarMd,
            borderRadius: ZRadius.mdBorder,
          ),
          const SizedBox(width: ZSpacing.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ZSkeletonText(height: 14),
                SizedBox(height: ZSpacing.xxs),
                ZSkeletonText(widthFraction: 0.55, height: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 7E — ZSkeletonGrid
// ---------------------------------------------------------------------------

/// Grid of [count] skeleton project cards.
class ZSkeletonGrid extends StatelessWidget {
  const ZSkeletonGrid({
    super.key,
    this.count = 4,
    this.crossAxisCount = 2,
    this.childAspectRatio = ZSize.projectCardAspect,
    this.padding,
  });

  final int count;
  final int crossAxisCount;
  final double childAspectRatio;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: ZSpacing.screenEdge),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: ZSpacing.sm,
        mainAxisSpacing: ZSpacing.sm,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: count,
      itemBuilder: (_, __) => const ZSkeletonProjectCard(),
    );
  }
}

// ===========================================================================
// SECTION 8 — EMPTY STATES
// ===========================================================================

/// Full empty state component with icon, heading, subtext, and optional CTA.
///
/// Action emits [onActionPressed] intent only. No execution.
class ZEmptyState extends StatelessWidget {
  const ZEmptyState({
    super.key,
    required this.icon,
    required this.heading,
    this.subtext,
    this.actionLabel,
    this.onActionPressed,
    this.compact = false,
  });

  final IconData icon;
  final String heading;
  final String? subtext;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<ZThemeExtension>();
    final tt = Theme.of(context).textTheme;
    final iconSize = compact ? ZSize.iconXl : ZSize.iconHero;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ZSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: iconSize + ZSpacing.xl,
              height: iconSize + ZSpacing.xl,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: iconSize, color: cs.primary),
            ),
            SizedBox(height: compact ? ZSpacing.sm : ZSpacing.lg),
            Text(
              heading,
              style: compact
                  ? tt.titleSmall?.copyWith(fontWeight: ZTypeface.weightSemiBold)
                  : tt.headlineSmall
                      ?.copyWith(fontWeight: ZTypeface.weightSemiBold),
              textAlign: TextAlign.center,
            ),
            if (subtext != null) ...[
              const SizedBox(height: ZSpacing.xs),
              Text(
                subtext!,
                style: tt.bodyMedium
                    ?.copyWith(color: ext?.onSurfaceSubtle),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onActionPressed != null) ...[
              SizedBox(height: compact ? ZSpacing.md : ZSpacing.xl),
              ZPrimaryButton(
                label: actionLabel!,
                onPressed: onActionPressed,
                size: compact ? ZButtonSize.small : ZButtonSize.medium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// SECTION 9 — SECTION HEADER
// ===========================================================================

/// Standardised section heading row with optional trailing action.
class ZSectionHeader extends StatelessWidget {
  const ZSectionHeader({
    super.key,
    required this.title,
    this.trailingLabel,
    this.onTrailingTap,
    this.padding,
  });

  final String title;
  final String? trailingLabel;
  final VoidCallback? onTrailingTap;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: ZSpacing.screenEdge),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: tt.titleMedium
                  ?.copyWith(fontWeight: ZTypeface.weightBold),
            ),
          ),
          if (trailingLabel != null)
            GestureDetector(
              onTap: onTrailingTap,
              child: Text(
                trailingLabel!,
                style: tt.labelMedium?.copyWith(color: cs.primary),
              ),
            ),
        ],
      ),
    );
  }
}

// ===========================================================================
// SECTION 10 — DIVIDER WITH LABEL
// ===========================================================================

/// Horizontal rule with centred text label.
class ZLabeledDivider extends StatelessWidget {
  const ZLabeledDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ZThemeExtension>();
    final tt = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(child: Divider(color: ext?.divider)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ZSpacing.sm),
          child: Text(
            label,
            style: tt.labelSmall?.copyWith(color: ext?.onSurfaceSubtle),
          ),
        ),
        Expanded(child: Divider(color: ext?.divider)),
      ],
    );
  }
}

// ===========================================================================
// SECTION 11 — FUTURE-READY PLACEHOLDER SLOTS
// ===========================================================================

/// Placeholder UI slot for future features.
///
/// Renders a soft "coming soon" banner. Zero execution. Zero logic.
/// Used to reserve space in the widget tree for:
///   - Voice Input Button
///   - AI Copilot Panel
///   - Plugin Marketplace
///   - Automation Dashboard
///   - Advanced Analytics Panel
class ZFutureFeatureSlot extends StatelessWidget {
  const ZFutureFeatureSlot({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
    this.compact = false,
  });

  final String label;
  final IconData icon;

  /// Optional intent callback — forwards "interested" signal. No execution.
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (compact) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ZSpacing.sm,
            vertical: ZSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: ZRadius.pillBorder,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: ZSize.iconXs, color: cs.primary),
              const SizedBox(width: ZSpacing.xxs),
              Text(
                label,
                style: tt.labelSmall?.copyWith(color: cs.primary),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: ZSpacing.md,
          vertical: ZSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withOpacity(0.5),
          borderRadius: ZRadius.mdBorder,
          border: Border.all(color: cs.primary.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: ZSize.iconSm, color: cs.primary),
            const SizedBox(width: ZSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: tt.bodySmall?.copyWith(
                  color: cs.primary,
                  fontWeight: ZTypeface.weightMedium,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: ZSpacing.xs,
                vertical: ZSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: ZRadius.smBorder,
              ),
              child: Text(
                'Soon',
                style: tt.labelSmall?.copyWith(
                  color: cs.primary,
                  fontSize: ZTypeface.sizeCaption,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// SECTION 12 — PROGRESS BAR (rewards / level)
// ===========================================================================

/// Branded linear progress bar for level or rewards progress.
class ZProgressBar extends StatelessWidget {
  const ZProgressBar({
    super.key,
    required this.value,
    this.label,
    this.color,
    this.height = 6,
    this.showPercent = false,
  });

  /// 0.0 – 1.0
  final double value;
  final String? label;
  final Color? color;
  final double height;
  final bool showPercent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<ZThemeExtension>();
    final tt = Theme.of(context).textTheme;
    final c = color ?? cs.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null || showPercent)
          Padding(
            padding: const EdgeInsets.only(bottom: ZSpacing.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (label != null)
                  Text(
                    label!,
                    style: tt.labelSmall
                        ?.copyWith(color: ext?.onSurfaceSubtle),
                  ),
                if (showPercent)
                  Text(
                    '${(value.clamp(0, 1) * 100).round()}%',
                    style: tt.labelSmall?.copyWith(
                      color: c,
                      fontWeight: ZTypeface.weightSemiBold,
                    ),
                  ),
              ],
            ),
          ),
        ClipRRect(
          borderRadius: ZRadius.pillBorder,
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            backgroundColor: ext?.divider,
            valueColor: AlwaysStoppedAnimation(c),
            minHeight: height,
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// SECTION 13 — TOOLTIP WRAPPER
// ===========================================================================

/// Z-CANVAS branded tooltip with delay tuning.
class ZTooltip extends StatelessWidget {
  const ZTooltip({
    super.key,
    required this.message,
    required this.child,
    this.waitDuration = const Duration(milliseconds: 600),
  });

  final String message;
  final Widget child;
  final Duration waitDuration;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      waitDuration: waitDuration,
      child: child,
    );
  }
}
