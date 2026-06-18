// ui/theme/z_canvas_theme.dart
//
// PHASE-12 — Z-CANVAS Theme System (FILE-1)
//
// ===========================================================================
// OWNERSHIP CONTRACT
// ===========================================================================
//
// WHAT THIS FILE CAN DO:
//   • Define all color tokens (light + dark palettes)
//   • Define the full typography scale
//   • Define the 8pt spacing system
//   • Define border radius tokens
//   • Define shadow / elevation presets
//   • Define brand identity constants
//   • Export fully configured Flutter ThemeData for light + dark modes
//
// WHAT THIS FILE CANNOT DO:
//   ❌ Contain any Widget
//   ❌ Contain any layout logic
//   ❌ Contain any animation behavior
//   ❌ Contain any interaction logic
//   ❌ Access any engine, controller, or state
//   ❌ Hardcode colors anywhere outside this file
//
// AUTHORITY: DESIGN DNA — every color, typeface, spacing, and radius token
//   in the entire app originates here. No UI file may hardcode values.
// ===========================================================================

import 'package:flutter/material.dart';

// ===========================================================================
// SECTION 1 — BRAND IDENTITY CONSTANTS
// ===========================================================================

/// Z-CANVAS brand identity tokens.
///
/// Use these string constants wherever the product name appears.
/// Never inline brand strings in UI files.
abstract final class ZBrand {
  /// Primary product name.
  static const String appName = 'Z-CANVAS';

  /// Engine identity label shown in technical contexts.
  static const String engineLabel = 'ZYNQUAR ENGINE';

  /// Company / platform name.
  static const String companyName = 'Zynquar';

  /// Full product name used in app bars and splash screens.
  static const String fullName = 'Z-CANVAS by Zynquar';

  /// Optional footer signature.
  static const String poweredBy = 'Powered by Zynquar';

  /// Tagline used in marketing / onboarding contexts.
  static const String tagline = 'Design without limits.';

  /// App version label token (update at release time).
  static const String versionLabel = 'v1.0';
}

// ===========================================================================
// SECTION 2 — COLOR TOKENS
// ===========================================================================

/// Light mode color palette for Z-CANVAS.
///
/// All token names match their semantic role.
/// No raw Color literals should appear outside this class in any UI file.
abstract final class ZColorsLight {
  // ── Brand primaries ──────────────────────────────────────────────────────

  /// Main brand purple — primary interactive color.
  static const Color primary = Color(0xFF5B4CF5);

  /// Slightly darker primary — pressed / active state.
  static const Color primaryVariant = Color(0xFF4839D9);

  /// Primary with low opacity — backgrounds, highlights.
  static const Color primarySubtle = Color(0xFFEEEBFF);

  /// On-primary — text/icons rendered on a primary surface.
  static const Color onPrimary = Color(0xFFFFFFFF);

  // ── Secondary ────────────────────────────────────────────────────────────

  /// Secondary teal — complementary actions, AI features.
  static const Color secondary = Color(0xFF00BFA6);

  /// Secondary variant — pressed state.
  static const Color secondaryVariant = Color(0xFF00A693);

  /// On-secondary — text/icons on secondary surfaces.
  static const Color onSecondary = Color(0xFFFFFFFF);

  // ── Accent ───────────────────────────────────────────────────────────────

  /// Accent gold — rewards, highlights, premium indicators.
  static const Color accent = Color(0xFFFFC107);

  /// Accent amber variant — pressed state.
  static const Color accentVariant = Color(0xFFFFB300);

  /// On-accent — text/icons on accent surfaces.
  static const Color onAccent = Color(0xFF1A1A2E);

  // ── Surfaces ─────────────────────────────────────────────────────────────

  /// App background — main scaffold background.
  static const Color background = Color(0xFFF6F7FB);

  /// Card / panel surface — elevated from background.
  static const Color surface = Color(0xFFFFFFFF);

  /// Panel surface — toolbars, side panels.
  static const Color surfacePanel = Color(0xFFF0F1F7);

  /// Canvas working area background.
  static const Color canvasBackground = Color(0xFFE8EAF0);

  /// Elevated surface (dialogs, bottom sheets).
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  // ── On-surfaces ──────────────────────────────────────────────────────────

  /// Primary text on background.
  static const Color onBackground = Color(0xFF1A1A2E);

  /// Primary text on surface.
  static const Color onSurface = Color(0xFF1A1A2E);

  /// Secondary / muted text.
  static const Color onSurfaceSubtle = Color(0xFF8A8FAB);

  /// Disabled text / placeholder text.
  static const Color onSurfaceDisabled = Color(0xFFBEC2D4);

  // ── Semantic ─────────────────────────────────────────────────────────────

  /// Success state (saved, complete).
  static const Color success = Color(0xFF1DB954);

  /// Warning state (unsaved, caution).
  static const Color warning = Color(0xFFFFA726);

  /// Error / destructive state.
  static const Color error = Color(0xFFE53935);

  /// On-error — text/icons on error surfaces.
  static const Color onError = Color(0xFFFFFFFF);

  // ── Structural ───────────────────────────────────────────────────────────

  /// Dividers, borders, separators.
  static const Color divider = Color(0xFFE0E2EC);

  /// Input field border (unfocused).
  static const Color inputBorder = Color(0xFFD4D7E5);

  /// Input field border (focused).
  static const Color inputBorderFocused = Color(0xFF5B4CF5);

  /// Selection highlight (text selection, chip active).
  static const Color selection = Color(0xFFEEEBFF);

  // ── Overlay ──────────────────────────────────────────────────────────────

  /// Scrim for modals, bottom sheets.
  static const Color scrim = Color(0x8C000000);

  /// Shadow base color.
  static const Color shadow = Color(0x1A1A1A2E);
}

/// Dark mode color palette for Z-CANVAS.
abstract final class ZColorsDark {
  // ── Brand primaries ──────────────────────────────────────────────────────

  static const Color primary = Color(0xFF7C6AF7);
  static const Color primaryVariant = Color(0xFF9585FF);
  static const Color primarySubtle = Color(0xFF2A2450);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // ── Secondary ────────────────────────────────────────────────────────────

  static const Color secondary = Color(0xFF1DE9D0);
  static const Color secondaryVariant = Color(0xFF00BFA6);
  static const Color onSecondary = Color(0xFF0D1117);

  // ── Accent ───────────────────────────────────────────────────────────────

  static const Color accent = Color(0xFFFFD54F);
  static const Color accentVariant = Color(0xFFFFC107);
  static const Color onAccent = Color(0xFF0D1117);

  // ── Surfaces ─────────────────────────────────────────────────────────────

  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color surfacePanel = Color(0xFF1C2230);
  static const Color canvasBackground = Color(0xFF111820);
  static const Color surfaceElevated = Color(0xFF21262D);

  // ── On-surfaces ──────────────────────────────────────────────────────────

  static const Color onBackground = Color(0xFFE6EDF3);
  static const Color onSurface = Color(0xFFE6EDF3);
  static const Color onSurfaceSubtle = Color(0xFF8B949E);
  static const Color onSurfaceDisabled = Color(0xFF484F58);

  // ── Semantic ─────────────────────────────────────────────────────────────

  static const Color success = Color(0xFF3FB950);
  static const Color warning = Color(0xFFD29922);
  static const Color error = Color(0xFFF85149);
  static const Color onError = Color(0xFFFFFFFF);

  // ── Structural ───────────────────────────────────────────────────────────

  static const Color divider = Color(0xFF30363D);
  static const Color inputBorder = Color(0xFF30363D);
  static const Color inputBorderFocused = Color(0xFF7C6AF7);
  static const Color selection = Color(0xFF2A2450);

  // ── Overlay ──────────────────────────────────────────────────────────────

  static const Color scrim = Color(0xCC000000);
  static const Color shadow = Color(0x33000000);
}

// ===========================================================================
// SECTION 3 — TYPOGRAPHY SCALE
// ===========================================================================

/// Z-CANVAS typography constants.
///
/// All font family and weight constants.
/// Use [ZTheme.lightTextTheme] / [ZTheme.darkTextTheme] for full TextTheme.
abstract final class ZTypeface {
  /// Display / heading typeface.
  static const String displayFamily = 'Inter';

  /// Body / UI typeface.
  static const String bodyFamily = 'Inter';

  /// Monospace typeface (code, hex values).
  static const String monoFamily = 'JetBrains Mono';

  // ── Font weights ──────────────────────────────────────────────────────────

  static const FontWeight weightLight = FontWeight.w300;
  static const FontWeight weightRegular = FontWeight.w400;
  static const FontWeight weightMedium = FontWeight.w500;
  static const FontWeight weightSemiBold = FontWeight.w600;
  static const FontWeight weightBold = FontWeight.w700;
  static const FontWeight weightExtraBold = FontWeight.w800;
  static const FontWeight weightBlack = FontWeight.w900;

  // ── Font sizes (px) ───────────────────────────────────────────────────────

  static const double sizeDisplay = 48;
  static const double sizeH1 = 36;
  static const double sizeH2 = 28;
  static const double sizeH3 = 22;
  static const double sizeH4 = 18;
  static const double sizeTitleLarge = 16;
  static const double sizeTitleMedium = 15;
  static const double sizeTitleSmall = 14;
  static const double sizeBodyLarge = 16;
  static const double sizeBodyMedium = 14;
  static const double sizeBodySmall = 13;
  static const double sizeLabelLarge = 14;
  static const double sizeLabelMedium = 12;
  static const double sizeLabelSmall = 11;
  static const double sizeCaption = 10;

  // ── Line heights ──────────────────────────────────────────────────────────

  static const double lineHeightTight = 1.2;
  static const double lineHeightNormal = 1.45;
  static const double lineHeightRelaxed = 1.6;

  // ── Letter spacing ────────────────────────────────────────────────────────

  static const double trackingTight = -0.5;
  static const double trackingNormal = 0;
  static const double trackingWide = 0.5;
  static const double trackingWider = 1.0;
  static const double trackingWidest = 2.0;
}

/// Constructs the Z-CANVAS TextTheme for a given color palette.
TextTheme _buildTextTheme(Color onBackground, Color onSurface, Color subtle) {
  return TextTheme(
    // Display
    displayLarge: TextStyle(
      fontFamily: ZTypeface.displayFamily,
      fontSize: ZTypeface.sizeDisplay,
      fontWeight: ZTypeface.weightBlack,
      color: onBackground,
      letterSpacing: ZTypeface.trackingTight,
      height: ZTypeface.lineHeightTight,
    ),
    // H1
    displayMedium: TextStyle(
      fontFamily: ZTypeface.displayFamily,
      fontSize: ZTypeface.sizeH1,
      fontWeight: ZTypeface.weightExtraBold,
      color: onBackground,
      letterSpacing: ZTypeface.trackingTight,
      height: ZTypeface.lineHeightTight,
    ),
    // H2
    displaySmall: TextStyle(
      fontFamily: ZTypeface.displayFamily,
      fontSize: ZTypeface.sizeH2,
      fontWeight: ZTypeface.weightBold,
      color: onBackground,
      letterSpacing: ZTypeface.trackingNormal,
      height: ZTypeface.lineHeightTight,
    ),
    // H3
    headlineLarge: TextStyle(
      fontFamily: ZTypeface.displayFamily,
      fontSize: ZTypeface.sizeH3,
      fontWeight: ZTypeface.weightBold,
      color: onBackground,
      letterSpacing: ZTypeface.trackingNormal,
      height: ZTypeface.lineHeightNormal,
    ),
    // H4
    headlineMedium: TextStyle(
      fontFamily: ZTypeface.displayFamily,
      fontSize: ZTypeface.sizeH4,
      fontWeight: ZTypeface.weightSemiBold,
      color: onBackground,
      letterSpacing: ZTypeface.trackingNormal,
      height: ZTypeface.lineHeightNormal,
    ),
    // H5
    headlineSmall: TextStyle(
      fontFamily: ZTypeface.displayFamily,
      fontSize: ZTypeface.sizeTitleLarge,
      fontWeight: ZTypeface.weightSemiBold,
      color: onBackground,
      height: ZTypeface.lineHeightNormal,
    ),
    // Title Large
    titleLarge: TextStyle(
      fontFamily: ZTypeface.bodyFamily,
      fontSize: ZTypeface.sizeTitleLarge,
      fontWeight: ZTypeface.weightSemiBold,
      color: onSurface,
      height: ZTypeface.lineHeightNormal,
    ),
    // Title Medium
    titleMedium: TextStyle(
      fontFamily: ZTypeface.bodyFamily,
      fontSize: ZTypeface.sizeTitleMedium,
      fontWeight: ZTypeface.weightMedium,
      color: onSurface,
      height: ZTypeface.lineHeightNormal,
    ),
    // Title Small
    titleSmall: TextStyle(
      fontFamily: ZTypeface.bodyFamily,
      fontSize: ZTypeface.sizeTitleSmall,
      fontWeight: ZTypeface.weightMedium,
      color: onSurface,
      height: ZTypeface.lineHeightNormal,
    ),
    // Body Large
    bodyLarge: TextStyle(
      fontFamily: ZTypeface.bodyFamily,
      fontSize: ZTypeface.sizeBodyLarge,
      fontWeight: ZTypeface.weightRegular,
      color: onSurface,
      height: ZTypeface.lineHeightRelaxed,
    ),
    // Body Medium
    bodyMedium: TextStyle(
      fontFamily: ZTypeface.bodyFamily,
      fontSize: ZTypeface.sizeBodyMedium,
      fontWeight: ZTypeface.weightRegular,
      color: onSurface,
      height: ZTypeface.lineHeightRelaxed,
    ),
    // Body Small
    bodySmall: TextStyle(
      fontFamily: ZTypeface.bodyFamily,
      fontSize: ZTypeface.sizeBodySmall,
      fontWeight: ZTypeface.weightRegular,
      color: subtle,
      height: ZTypeface.lineHeightRelaxed,
    ),
    // Label Large
    labelLarge: TextStyle(
      fontFamily: ZTypeface.bodyFamily,
      fontSize: ZTypeface.sizeLabelLarge,
      fontWeight: ZTypeface.weightSemiBold,
      color: onSurface,
      letterSpacing: ZTypeface.trackingNormal,
    ),
    // Label Medium
    labelMedium: TextStyle(
      fontFamily: ZTypeface.bodyFamily,
      fontSize: ZTypeface.sizeLabelMedium,
      fontWeight: ZTypeface.weightMedium,
      color: onSurface,
      letterSpacing: ZTypeface.trackingWide,
    ),
    // Caption
    labelSmall: TextStyle(
      fontFamily: ZTypeface.bodyFamily,
      fontSize: ZTypeface.sizeLabelSmall,
      fontWeight: ZTypeface.weightMedium,
      color: subtle,
      letterSpacing: ZTypeface.trackingWide,
    ),
  );
}

// ===========================================================================
// SECTION 4 — SPACING SYSTEM (8pt grid)
// ===========================================================================

/// Z-CANVAS 8-point spacing grid.
///
/// Every margin, padding, and gap in the app uses one of these tokens.
/// No arbitrary pixel values allowed in UI files.
abstract final class ZSpacing {
  // Base unit = 8pt
  static const double unit = 8;

  // ── Canonical steps ───────────────────────────────────────────────────────

  /// 2pt — micro gap (icon + label)
  static const double xxs = 2;

  /// 4pt — tight gap (chips, dense lists)
  static const double xs = 4;

  /// 8pt — base unit (standard inner gap)
  static const double sm = 8;

  /// 12pt — medium-small (card padding, form rows)
  static const double md = 12;

  /// 16pt — standard (default horizontal padding)
  static const double lg = 16;

  /// 20pt — comfortable section gap
  static const double xl = 20;

  /// 24pt — section spacer
  static const double xxl = 24;

  /// 32pt — large section gap
  static const double xxxl = 32;

  /// 40pt — hero section spacing
  static const double xxxxl = 40;

  /// 48pt — display-level breathing room
  static const double huge = 48;

  /// 64pt — page-level vertical rhythm
  static const double massive = 64;

  // ── Semantic aliases ──────────────────────────────────────────────────────

  /// Icon-to-label gap.
  static const double iconGap = xs;

  /// Default button internal horizontal padding.
  static const double buttonPaddingH = xl;

  /// Default button internal vertical padding.
  static const double buttonPaddingV = md;

  /// Standard card content padding.
  static const double cardPadding = lg;

  /// Panel internal padding (side panels, bottom sheets).
  static const double panelPadding = lg;

  /// Screen edge margin (horizontal safe padding).
  static const double screenEdge = xl;

  /// Section vertical spacing.
  static const double sectionGap = xxl;

  /// Form row spacing.
  static const double formRowGap = md;

  /// List item vertical padding.
  static const double listItemPaddingV = sm;

  // ── Inset helpers (EdgeInsets factories) ─────────────────────────────────

  static EdgeInsets get cardInsets =>
      const EdgeInsets.all(cardPadding);

  static EdgeInsets get panelInsets =>
      const EdgeInsets.all(panelPadding);

  static EdgeInsets get screenInsets =>
      const EdgeInsets.symmetric(horizontal: screenEdge);

  static EdgeInsets get buttonInsets => const EdgeInsets.symmetric(
        horizontal: buttonPaddingH,
        vertical: buttonPaddingV,
      );

  static EdgeInsets get formRowInsets =>
      EdgeInsets.symmetric(vertical: formRowGap / 2);
}

// ===========================================================================
// SECTION 5 — BORDER RADIUS SYSTEM
// ===========================================================================

/// Z-CANVAS border radius tokens — "soft UI" language.
///
/// Never use raw BorderRadius.circular(N) in UI files.
abstract final class ZRadius {
  /// Sharp corners (data tables, code blocks).
  static const double none = 0;

  /// Barely rounded (input underlines, rule lines).
  static const double xs = 2;

  /// Tight rounding (chips, tags, badges).
  static const double sm = 6;

  /// Standard rounding (buttons, inputs, cards).
  static const double md = 10;

  /// Comfortable rounding (panels, drawers).
  static const double lg = 14;

  /// Generous rounding (bottom sheets, modals, hero cards).
  static const double xl = 20;

  /// Full pill (toggle chips, progress bars).
  static const double pill = 100;

  /// Full circle (avatars, FABs, icon badges).
  static const double circle = 999;

  // ── BorderRadius shorthands ──────────────────────────────────────────────

  static BorderRadius get xsBorder =>
      BorderRadius.circular(xs);

  static BorderRadius get smBorder =>
      BorderRadius.circular(sm);

  static BorderRadius get mdBorder =>
      BorderRadius.circular(md);

  static BorderRadius get lgBorder =>
      BorderRadius.circular(lg);

  static BorderRadius get xlBorder =>
      BorderRadius.circular(xl);

  static BorderRadius get pillBorder =>
      BorderRadius.circular(pill);

  static BorderRadius get topOnlyLg => const BorderRadius.vertical(
        top: Radius.circular(lg),
      );

  static BorderRadius get topOnlyXl => const BorderRadius.vertical(
        top: Radius.circular(xl),
      );
}

// ===========================================================================
// SECTION 6 — SHADOW / ELEVATION PRESETS
// ===========================================================================

/// Z-CANVAS shadow presets.
///
/// Match Flutter's elevation scale semantically but with brand-tuned values.
/// Use by name; never construct BoxShadow inline in UI files.
abstract final class ZShadow {
  // ── Light mode shadows ────────────────────────────────────────────────────

  /// No shadow — flat / inset elements.
  static const List<BoxShadow> none = [];

  /// Hairline — subtle card lift (1dp equivalent).
  static const List<BoxShadow> xs = [
    BoxShadow(
      color: Color(0x0A1A1A2E),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  /// Low — standard card elevation (2dp equivalent).
  static const List<BoxShadow> sm = [
    BoxShadow(
      color: Color(0x121A1A2E),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// Medium — floating panels, dropdowns (4dp equivalent).
  static const List<BoxShadow> md = [
    BoxShadow(
      color: Color(0x161A1A2E),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x081A1A2E),
      blurRadius: 6,
      offset: Offset(0, 1),
    ),
  ];

  /// High — modals, dialogs (8dp equivalent).
  static const List<BoxShadow> lg = [
    BoxShadow(
      color: Color(0x201A1A2E),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x101A1A2E),
      blurRadius: 8,
      offset: Offset(0, 3),
    ),
  ];

  /// Very high — command palette, spotlight overlays (16dp equivalent).
  static const List<BoxShadow> xl = [
    BoxShadow(
      color: Color(0x2A1A1A2E),
      blurRadius: 48,
      offset: Offset(0, 16),
    ),
    BoxShadow(
      color: Color(0x141A1A2E),
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];

  // ── Colored primary glow (for focused/active primary elements) ────────────

  /// Primary color glow — used on focused primary buttons, active cards.
  static const List<BoxShadow> primaryGlow = [
    BoxShadow(
      color: Color(0x3A5B4CF5),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  /// Secondary / AI teal glow — AI Copilot panel, suggestion chips.
  static const List<BoxShadow> secondaryGlow = [
    BoxShadow(
      color: Color(0x3000BFA6),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  // ── Dark mode shadow overrides ────────────────────────────────────────────

  /// Dark mode medium shadow.
  static const List<BoxShadow> mdDark = [
    BoxShadow(
      color: Color(0x40000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x20000000),
      blurRadius: 6,
      offset: Offset(0, 1),
    ),
  ];

  /// Dark mode high shadow.
  static const List<BoxShadow> lgDark = [
    BoxShadow(
      color: Color(0x60000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x30000000),
      blurRadius: 8,
      offset: Offset(0, 3),
    ),
  ];
}

// ===========================================================================
// SECTION 7 — DURATION & CURVE CONSTANTS
// (Owned here as they are design tokens, not animation logic)
// ===========================================================================

/// Z-CANVAS motion duration tokens.
///
/// Animation logic lives in `ui/animations/ui_motion_engine.dart`.
/// Duration values are design system constants — they live here.
abstract final class ZDuration {
  /// Instant — no perceptible delay (state-only swaps).
  static const Duration instant = Duration(milliseconds: 50);

  /// Micro — icon morphs, color transitions.
  static const Duration micro = Duration(milliseconds: 100);

  /// Fast — button feedback, chip transitions.
  static const Duration fast = Duration(milliseconds: 180);

  /// Standard — panel open/close, page transitions.
  static const Duration standard = Duration(milliseconds: 260);

  /// Comfortable — hero transitions, modal entry.
  static const Duration comfortable = Duration(milliseconds: 340);

  /// Slow — full-page wipes, onboarding reveals.
  static const Duration slow = Duration(milliseconds: 480);

  /// Extra slow — splash / logo reveal only.
  static const Duration extraSlow = Duration(milliseconds: 720);
}

/// Z-CANVAS curve tokens.
abstract final class ZCurve {
  /// Standard ease — most transitions.
  static const Curve standard = Curves.easeInOut;

  /// Ease out — things entering the screen.
  static const Curve enter = Curves.easeOutCubic;

  /// Ease in — things leaving the screen.
  static const Curve exit = Curves.easeInCubic;

  /// Decelerate — elements decelerating into place.
  static const Curve decelerate = Curves.decelerate;

  /// Overshoot spring — reward pops, success feedback.
  static const Curve spring = Curves.elasticOut;

  /// Linear — looping animations (spinners, shimmer).
  static const Curve linear = Curves.linear;
}

// ===========================================================================
// SECTION 8 — COMPONENT STYLE CONSTANTS
// (Shared sizing constants for components)
// ===========================================================================

/// Component sizing constants used by [ui/components/z_ui_components.dart].
abstract final class ZSize {
  // ── Icon sizes ────────────────────────────────────────────────────────────
  static const double iconXs = 12;
  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;
  static const double iconXl = 32;
  static const double iconHero = 48;

  // ── Button heights ────────────────────────────────────────────────────────
  static const double buttonSmHeight = 32;
  static const double buttonMdHeight = 44;
  static const double buttonLgHeight = 52;

  // ── Input heights ─────────────────────────────────────────────────────────
  static const double inputHeight = 48;
  static const double inputHeightSm = 40;
  static const double inputHeightLg = 56;

  // ── Avatar / badge sizes ──────────────────────────────────────────────────
  static const double avatarSm = 28;
  static const double avatarMd = 36;
  static const double avatarLg = 48;
  static const double badgeSm = 16;
  static const double badgeMd = 20;

  // ── Panel widths ──────────────────────────────────────────────────────────
  static const double leftPanelWidth = 220;
  static const double leftPanelNarrow = 180;
  static const double rightPanelWidth = 240;
  static const double toolbarHeight = 44;
  static const double appBarHeight = 56;
  static const double bottomBarHeight = 44;
  static const double aiChatPanelHeight = 200;

  // ── Card dimensions ───────────────────────────────────────────────────────
  static const double cardMinHeight = 120;
  static const double projectCardAspect = 1.2;
  static const double templateCardWidth = 120;
  static const double templateCardHeight = 160;

  // ── Canvas placeholder ────────────────────────────────────────────────────
  static const double canvasPlaceholderWidth = 560;
  static const double canvasPlaceholderHeight = 360;

  // ── Divider ───────────────────────────────────────────────────────────────
  static const double dividerThickness = 1;
  static const double dividerIndent = 0;
}

// ===========================================================================
// SECTION 9 — Z-CANVAS THEME BUILDER
// ===========================================================================

/// Z-CANVAS ThemeData factory.
///
/// Call [ZTheme.light()] and [ZTheme.dark()] to get fully configured
/// Flutter ThemeData instances. Pass one to MaterialApp.theme / darkTheme.
///
/// Never construct ThemeData inline in any screen or component file.
abstract final class ZTheme {
  // ── Light TextTheme ───────────────────────────────────────────────────────

  static TextTheme get lightTextTheme => _buildTextTheme(
        ZColorsLight.onBackground,
        ZColorsLight.onSurface,
        ZColorsLight.onSurfaceSubtle,
      );

  // ── Dark TextTheme ────────────────────────────────────────────────────────

  static TextTheme get darkTextTheme => _buildTextTheme(
        ZColorsDark.onBackground,
        ZColorsDark.onSurface,
        ZColorsDark.onSurfaceSubtle,
      );

  // ── Light ColorScheme ─────────────────────────────────────────────────────

  static ColorScheme get lightColorScheme => const ColorScheme(
        brightness: Brightness.light,
        primary: ZColorsLight.primary,
        onPrimary: ZColorsLight.onPrimary,
        primaryContainer: ZColorsLight.primarySubtle,
        onPrimaryContainer: ZColorsLight.primaryVariant,
        secondary: ZColorsLight.secondary,
        onSecondary: ZColorsLight.onSecondary,
        secondaryContainer: Color(0xFFCCF5F1),
        onSecondaryContainer: ZColorsLight.secondaryVariant,
        tertiary: ZColorsLight.accent,
        onTertiary: ZColorsLight.onAccent,
        tertiaryContainer: Color(0xFFFFF3CD),
        onTertiaryContainer: Color(0xFF663C00),
        error: ZColorsLight.error,
        onError: ZColorsLight.onError,
        errorContainer: Color(0xFFFFDAD6),
        onErrorContainer: Color(0xFF410002),
        surface: ZColorsLight.surface,
        onSurface: ZColorsLight.onSurface,
        surfaceContainerHighest: ZColorsLight.surfacePanel,
        onSurfaceVariant: ZColorsLight.onSurfaceSubtle,
        outline: ZColorsLight.divider,
        outlineVariant: ZColorsLight.inputBorder,
        shadow: ZColorsLight.shadow,
        scrim: ZColorsLight.scrim,
        inverseSurface: ZColorsDark.surface,
        onInverseSurface: ZColorsDark.onSurface,
        inversePrimary: ZColorsDark.primary,
      );

  // ── Dark ColorScheme ──────────────────────────────────────────────────────

  static ColorScheme get darkColorScheme => const ColorScheme(
        brightness: Brightness.dark,
        primary: ZColorsDark.primary,
        onPrimary: ZColorsDark.onPrimary,
        primaryContainer: ZColorsDark.primarySubtle,
        onPrimaryContainer: ZColorsDark.primaryVariant,
        secondary: ZColorsDark.secondary,
        onSecondary: ZColorsDark.onSecondary,
        secondaryContainer: Color(0xFF00403A),
        onSecondaryContainer: ZColorsDark.secondaryVariant,
        tertiary: ZColorsDark.accent,
        onTertiary: ZColorsDark.onAccent,
        tertiaryContainer: Color(0xFF3A2E00),
        onTertiaryContainer: ZColorsDark.accent,
        error: ZColorsDark.error,
        onError: ZColorsDark.onError,
        errorContainer: Color(0xFF93000A),
        onErrorContainer: Color(0xFFFFDAD6),
        surface: ZColorsDark.surface,
        onSurface: ZColorsDark.onSurface,
        surfaceContainerHighest: ZColorsDark.surfacePanel,
        onSurfaceVariant: ZColorsDark.onSurfaceSubtle,
        outline: ZColorsDark.divider,
        outlineVariant: ZColorsDark.inputBorder,
        shadow: ZColorsDark.shadow,
        scrim: ZColorsDark.scrim,
        inverseSurface: ZColorsLight.surface,
        onInverseSurface: ZColorsLight.onSurface,
        inversePrimary: ZColorsLight.primary,
      );

  // ── ThemeData: Light ──────────────────────────────────────────────────────

  /// Returns the fully configured light ThemeData for Z-CANVAS.
  static ThemeData light() => _buildTheme(
        colorScheme: lightColorScheme,
        textTheme: lightTextTheme,
        background: ZColorsLight.background,
        surface: ZColorsLight.surface,
        divider: ZColorsLight.divider,
        onSurface: ZColorsLight.onSurface,
        onSurfaceSubtle: ZColorsLight.onSurfaceSubtle,
      );

  // ── ThemeData: Dark ───────────────────────────────────────────────────────

  /// Returns the fully configured dark ThemeData for Z-CANVAS.
  static ThemeData dark() => _buildTheme(
        colorScheme: darkColorScheme,
        textTheme: darkTextTheme,
        background: ZColorsDark.background,
        surface: ZColorsDark.surface,
        divider: ZColorsDark.divider,
        onSurface: ZColorsDark.onSurface,
        onSurfaceSubtle: ZColorsDark.onSurfaceSubtle,
      );

  // ── Internal builder ──────────────────────────────────────────────────────

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required Color background,
    required Color surface,
    required Color divider,
    required Color onSurface,
    required Color onSurfaceSubtle,
  }) {
    final isLight = colorScheme.brightness == Brightness.light;
    final primary = colorScheme.primary;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: background,

      // ── AppBar ────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontWeight: ZTypeface.weightSemiBold,
          color: onSurface,
        ),
        iconTheme: IconThemeData(
          color: onSurface,
          size: ZSize.iconLg,
        ),
      ),

      // ── Card ──────────────────────────────────────────────────────────────
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: ZRadius.lgBorder,
          side: BorderSide(color: divider),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Filled Button ─────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(88, ZSize.buttonMdHeight),
          padding: ZSpacing.buttonInsets,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: ZTypeface.weightSemiBold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: ZRadius.mdBorder,
          ),
        ),
      ),

      // ── Outlined Button ───────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(88, ZSize.buttonMdHeight),
          padding: ZSpacing.buttonInsets,
          side: BorderSide(color: primary),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: ZTypeface.weightSemiBold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: ZRadius.mdBorder,
          ),
        ),
      ),

      // ── Text Button ───────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          padding: ZSpacing.buttonInsets,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: ZTypeface.weightSemiBold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: ZRadius.mdBorder,
          ),
        ),
      ),

      // ── Icon Button ───────────────────────────────────────────────────────
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: onSurface,
          minimumSize: const Size(ZSize.buttonMdHeight, ZSize.buttonMdHeight),
          shape: RoundedRectangleBorder(
            borderRadius: ZRadius.smBorder,
          ),
        ),
      ),

      // ── Input Decoration ──────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ZSpacing.lg,
          vertical: ZSpacing.md,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: onSurfaceSubtle),
        border: OutlineInputBorder(
          borderRadius: ZRadius.mdBorder,
          borderSide: BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: ZRadius.mdBorder,
          borderSide: BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: ZRadius.mdBorder,
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: ZRadius.mdBorder,
          borderSide: BorderSide(color: colorScheme.error),
        ),
        isDense: true,
      ),

      // ── Chip ──────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: colorScheme.primaryContainer,
        disabledColor: isLight
            ? ZColorsLight.onSurfaceDisabled
            : ZColorsDark.onSurfaceDisabled,
        labelStyle: textTheme.labelMedium?.copyWith(color: onSurface),
        side: BorderSide(color: divider),
        shape: RoundedRectangleBorder(borderRadius: ZRadius.pillBorder),
        padding: const EdgeInsets.symmetric(
          horizontal: ZSpacing.sm,
          vertical: ZSpacing.xs,
        ),
      ),

      // ── Bottom Navigation Bar ─────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            fontWeight: isSelected
                ? ZTypeface.weightSemiBold
                : ZTypeface.weightRegular,
            color: isSelected ? primary : onSurfaceSubtle,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: isSelected ? primary : onSurfaceSubtle,
            size: ZSize.iconLg,
          );
        }),
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: divider,
        thickness: ZSize.dividerThickness,
        space: ZSize.dividerThickness,
      ),

      // ── Slider ────────────────────────────────────────────────────────────
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        inactiveTrackColor: divider,
        thumbColor: primary,
        overlayColor: primary.withOpacity(0.12),
        trackHeight: 4,
      ),

      // ── Progress Indicator ────────────────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: divider,
        circularTrackColor: divider,
      ),

      // ── Tooltip ───────────────────────────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isLight
              ? ZColorsLight.onSurface.withOpacity(0.92)
              : ZColorsDark.surface,
          borderRadius: ZRadius.smBorder,
        ),
        textStyle: textTheme.labelSmall?.copyWith(
          color: isLight ? Colors.white : ZColorsDark.onSurface,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: ZSpacing.sm,
          vertical: ZSpacing.xs,
        ),
        waitDuration: const Duration(milliseconds: 600),
      ),

      // ── Bottom Sheet ──────────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: ZRadius.topOnlyXl),
        modalBackgroundColor: surface,
        showDragHandle: true,
        dragHandleColor: divider,
        elevation: 8,
      ),

      // ── Dialog ────────────────────────────────────────────────────────────
      dialogTheme: DialogTheme(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: ZRadius.xlBorder),
        titleTextStyle: textTheme.headlineMedium,
        contentTextStyle: textTheme.bodyMedium,
        elevation: 16,
      ),

      // ── Snack Bar ─────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isLight
            ? ZColorsLight.onSurface
            : ZColorsDark.surfaceElevated,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: isLight ? Colors.white : ZColorsDark.onSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: ZRadius.mdBorder),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),

      // ── Dropdown ──────────────────────────────────────────────────────────
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: textTheme.bodyMedium?.copyWith(color: onSurface),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(surface),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: ZRadius.mdBorder),
          ),
          elevation: const WidgetStatePropertyAll(8),
        ),
      ),

      // ── Filter Chip (effects panel) ───────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
        focusElevation: 6,
        hoverElevation: 6,
        shape: RoundedRectangleBorder(borderRadius: ZRadius.lgBorder),
      ),

      // ── Switch / Checkbox / Radio ─────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return onSurfaceSubtle;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary.withOpacity(0.3);
          }
          return divider;
        }),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(colorScheme.onPrimary),
        side: BorderSide(color: divider, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: ZRadius.xsBorder),
      ),
    );
  }
}

// ===========================================================================
// SECTION 10 — THEME EXTENSION (custom tokens on BuildContext)
// ===========================================================================

/// Z-CANVAS custom theme extension.
///
/// Attach to ThemeData.extensions so any widget can access brand tokens
/// via [Theme.of(context).extension<ZThemeExtension>()].
final class ZThemeExtension extends ThemeExtension<ZThemeExtension> {
  const ZThemeExtension({
    required this.canvasBackground,
    required this.surfacePanel,
    required this.onSurfaceSubtle,
    required this.onSurfaceDisabled,
    required this.divider,
    required this.success,
    required this.warning,
    required this.accent,
    required this.primarySubtle,
    required this.shadowMd,
    required this.shadowLg,
    required this.primaryGlow,
  });

  final Color canvasBackground;
  final Color surfacePanel;
  final Color onSurfaceSubtle;
  final Color onSurfaceDisabled;
  final Color divider;
  final Color success;
  final Color warning;
  final Color accent;
  final Color primarySubtle;
  final List<BoxShadow> shadowMd;
  final List<BoxShadow> shadowLg;
  final List<BoxShadow> primaryGlow;

  /// Light extension instance.
  static const ZThemeExtension light = ZThemeExtension(
    canvasBackground: ZColorsLight.canvasBackground,
    surfacePanel: ZColorsLight.surfacePanel,
    onSurfaceSubtle: ZColorsLight.onSurfaceSubtle,
    onSurfaceDisabled: ZColorsLight.onSurfaceDisabled,
    divider: ZColorsLight.divider,
    success: ZColorsLight.success,
    warning: ZColorsLight.warning,
    accent: ZColorsLight.accent,
    primarySubtle: ZColorsLight.primarySubtle,
    shadowMd: ZShadow.md,
    shadowLg: ZShadow.lg,
    primaryGlow: ZShadow.primaryGlow,
  );

  /// Dark extension instance.
  static const ZThemeExtension dark = ZThemeExtension(
    canvasBackground: ZColorsDark.canvasBackground,
    surfacePanel: ZColorsDark.surfacePanel,
    onSurfaceSubtle: ZColorsDark.onSurfaceSubtle,
    onSurfaceDisabled: ZColorsDark.onSurfaceDisabled,
    divider: ZColorsDark.divider,
    success: ZColorsDark.success,
    warning: ZColorsDark.warning,
    accent: ZColorsDark.accent,
    primarySubtle: ZColorsDark.primarySubtle,
    shadowMd: ZShadow.mdDark,
    shadowLg: ZShadow.lgDark,
    primaryGlow: ZShadow.primaryGlow,
  );

  @override
  ZThemeExtension copyWith({
    Color? canvasBackground,
    Color? surfacePanel,
    Color? onSurfaceSubtle,
    Color? onSurfaceDisabled,
    Color? divider,
    Color? success,
    Color? warning,
    Color? accent,
    Color? primarySubtle,
    List<BoxShadow>? shadowMd,
    List<BoxShadow>? shadowLg,
    List<BoxShadow>? primaryGlow,
  }) {
    return ZThemeExtension(
      canvasBackground: canvasBackground ?? this.canvasBackground,
      surfacePanel: surfacePanel ?? this.surfacePanel,
      onSurfaceSubtle: onSurfaceSubtle ?? this.onSurfaceSubtle,
      onSurfaceDisabled: onSurfaceDisabled ?? this.onSurfaceDisabled,
      divider: divider ?? this.divider,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      accent: accent ?? this.accent,
      primarySubtle: primarySubtle ?? this.primarySubtle,
      shadowMd: shadowMd ?? this.shadowMd,
      shadowLg: shadowLg ?? this.shadowLg,
      primaryGlow: primaryGlow ?? this.primaryGlow,
    );
  }

  @override
  ZThemeExtension lerp(ZThemeExtension? other, double t) {
    if (other == null) return this;
    return ZThemeExtension(
      canvasBackground: Color.lerp(canvasBackground, other.canvasBackground, t)!,
      surfacePanel: Color.lerp(surfacePanel, other.surfacePanel, t)!,
      onSurfaceSubtle: Color.lerp(onSurfaceSubtle, other.onSurfaceSubtle, t)!,
      onSurfaceDisabled:
          Color.lerp(onSurfaceDisabled, other.onSurfaceDisabled, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      primarySubtle: Color.lerp(primarySubtle, other.primarySubtle, t)!,
      shadowMd: t < 0.5 ? shadowMd : other.shadowMd,
      shadowLg: t < 0.5 ? shadowLg : other.shadowLg,
      primaryGlow: t < 0.5 ? primaryGlow : other.primaryGlow,
    );
  }
}

// ===========================================================================
// SECTION 11 — MATERIAL APP WIRING HELPER
// ===========================================================================

/// Convenience factory that produces both ThemeData values with extensions
/// pre-attached, ready for [MaterialApp.theme] / [MaterialApp.darkTheme].
abstract final class ZThemeWiring {
  /// Light ThemeData with [ZThemeExtension] attached.
  static ThemeData get lightTheme => ZTheme.light().copyWith(
        extensions: [ZThemeExtension.light],
      );

  /// Dark ThemeData with [ZThemeExtension] attached.
  static ThemeData get darkTheme => ZTheme.dark().copyWith(
        extensions: [ZThemeExtension.dark],
      );
}
