// ignore_for_file: avoid_catches_without_on_clauses

// ============================================================
// TemplateEngine — Phase-4 Blueprint Generator Authority
// ============================================================
// OWNS: layout blueprint generation, template structure,
//       spacing rules, ratio mapping, theme tokens,
//       preset configurations.
// MUST NOT: create LayerModels, call LayerEngine,
//           HistoryEngine, RenderEngine, StorageEngine,
//           SyncEngine, AIEngine, or touch any UI/widget.
// OUTPUT: TemplateBlueprint ONLY.
// ONLY COMMUNICATES WITH: EditorController.
// ============================================================

// ── Template categories ───────────────────────────────────────
enum TemplateCategory {
  socialMedia,
  presentation,
  poster,
  banner,
  flyer,
  card,
  certificate,
  thumbnail,
  infographic,
  advertisement,
}

// ── Supported aspect ratios ───────────────────────────────────
enum TemplateRatio {
  square,          // 1:1
  landscape,       // 16:9
  portrait,        // 9:16
  classic,         // 4:3
  cinematic,       // 21:9
  a4Portrait,      // 1:1.414
  a4Landscape,     // 1.414:1
  twitter,         // 2:1
  instagram,       // 4:5
  custom,
}

// ── Placeholder zone types ────────────────────────────────────
enum ZoneType {
  text,
  image,
  icon,
  shape,
  background,
  frame,
  sticker,
  overlay,
}

// ── Alignment values ──────────────────────────────────────────
enum ZoneAlignment {
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  center,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

// ── Theme token types ─────────────────────────────────────────
enum TokenType {
  color,
  fontSize,
  fontFamily,
  fontWeight,
  borderRadius,
  spacing,
  opacity,
  shadow,
}

// ── Responsive break points ───────────────────────────────────
enum BreakPoint {
  mobile,
  tablet,
  desktop,
}

// ── Theme token ───────────────────────────────────────────────
class ThemeToken {
  final String key;
  final TokenType type;
  final dynamic value;
  final String? description;

  const ThemeToken({
    required this.key,
    required this.type,
    required this.value,
    this.description,
  });

  Map<String, dynamic> toMap() => {
        'key': key,
        'type': type.name,
        'value': value,
        'description': description,
      };
}

// ── Theme definition ──────────────────────────────────────────
class ThemeDefinition {
  final String themeId;
  final String name;
  final List<ThemeToken> tokens;

  const ThemeDefinition({
    required this.themeId,
    required this.name,
    required this.tokens,
  });

  ThemeToken? token(String key) {
    try {
      return tokens.firstWhere((t) => t.key == key);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toMap() => {
        'themeId': themeId,
        'name': name,
        'tokens': tokens.map((t) => t.toMap()).toList(),
      };
}

// ── Placeholder zone ──────────────────────────────────────────
// Defines WHERE a layer will eventually go — not the layer itself.
class PlaceholderZone {
  final String zoneId;
  final ZoneType zoneType;
  final String label;
  final double xPercent;   // 0.0–1.0 relative to canvas width
  final double yPercent;   // 0.0–1.0 relative to canvas height
  final double widthPercent;
  final double heightPercent;
  final ZoneAlignment alignment;
  final int zIndex;
  final bool optional;
  final Map<String, dynamic> hints;

  const PlaceholderZone({
    required this.zoneId,
    required this.zoneType,
    required this.label,
    required this.xPercent,
    required this.yPercent,
    required this.widthPercent,
    required this.heightPercent,
    required this.alignment,
    required this.zIndex,
    this.optional = false,
    this.hints = const {},
  });

  Map<String, dynamic> toMap() => {
        'zoneId': zoneId,
        'zoneType': zoneType.name,
        'label': label,
        'xPercent': xPercent,
        'yPercent': yPercent,
        'widthPercent': widthPercent,
        'heightPercent': heightPercent,
        'alignment': alignment.name,
        'zIndex': zIndex,
        'optional': optional,
        'hints': hints,
      };
}

// ── Layout structure ──────────────────────────────────────────
class LayoutStructure {
  final String layoutId;
  final TemplateRatio ratio;
  final double canvasWidth;
  final double canvasHeight;
  final List<PlaceholderZone> zones;
  final Map<String, double> margins;   // top, right, bottom, left
  final Map<String, double> gutters;   // columnGap, rowGap

  const LayoutStructure({
    required this.layoutId,
    required this.ratio,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.zones,
    this.margins = const {},
    this.gutters = const {},
  });

  Map<String, dynamic> toMap() => {
        'layoutId': layoutId,
        'ratio': ratio.name,
        'canvasWidth': canvasWidth,
        'canvasHeight': canvasHeight,
        'zones': zones.map((z) => z.toMap()).toList(),
        'margins': margins,
        'gutters': gutters,
      };
}

// ── Style rules ───────────────────────────────────────────────
class StyleRules {
  final ThemeDefinition theme;
  final Map<String, dynamic> typographyScale;
  final Map<String, dynamic> colorPalette;
  final Map<String, double> spacingScale;
  final Map<String, double> borderRadiusScale;

  const StyleRules({
    required this.theme,
    required this.typographyScale,
    required this.colorPalette,
    required this.spacingScale,
    required this.borderRadiusScale,
  });

  Map<String, dynamic> toMap() => {
        'theme': theme.toMap(),
        'typographyScale': typographyScale,
        'colorPalette': colorPalette,
        'spacingScale': spacingScale,
        'borderRadiusScale': borderRadiusScale,
      };
}

// ── Positioning hints ─────────────────────────────────────────
class PositioningHints {
  final Map<String, ZoneAlignment> zoneAlignmentOverrides;
  final Map<String, double> zoneOpacityHints;
  final Map<String, double> zoneRotationHints;
  final bool snapToGrid;
  final double gridSize;

  const PositioningHints({
    this.zoneAlignmentOverrides = const {},
    this.zoneOpacityHints = const {},
    this.zoneRotationHints = const {},
    this.snapToGrid = false,
    this.gridSize = 8.0,
  });

  Map<String, dynamic> toMap() => {
        'zoneAlignmentOverrides':
            zoneAlignmentOverrides.map((k, v) => MapEntry(k, v.name)),
        'zoneOpacityHints': zoneOpacityHints,
        'zoneRotationHints': zoneRotationHints,
        'snapToGrid': snapToGrid,
        'gridSize': gridSize,
      };
}

// ── Responsive behaviour rules ────────────────────────────────
class ResponsiveRule {
  final BreakPoint breakPoint;
  final Map<String, double> zoneScaleOverrides;   // zoneId → scale factor
  final Map<String, bool> zoneVisibilityOverrides; // zoneId → visible
  final Map<String, ZoneAlignment> alignmentOverrides;

  const ResponsiveRule({
    required this.breakPoint,
    this.zoneScaleOverrides = const {},
    this.zoneVisibilityOverrides = const {},
    this.alignmentOverrides = const {},
  });

  Map<String, dynamic> toMap() => {
        'breakPoint': breakPoint.name,
        'zoneScaleOverrides': zoneScaleOverrides,
        'zoneVisibilityOverrides': zoneVisibilityOverrides,
        'alignmentOverrides':
            alignmentOverrides.map((k, v) => MapEntry(k, v.name)),
      };
}

// ── Template blueprint ────────────────────────────────────────
// The ONLY output of TemplateEngine.
// EditorController reads this and issues LayerEngine actions.
class TemplateBlueprint {
  final String blueprintId;
  final String templateId;
  final String templateName;
  final TemplateCategory category;
  final int version;
  final DateTime generatedAt;
  final LayoutStructure layoutStructure;
  final StyleRules styleRules;
  final PositioningHints positioningHints;
  final List<ResponsiveRule> responsiveBehavior;
  final Map<String, dynamic> metadata;

  const TemplateBlueprint({
    required this.blueprintId,
    required this.templateId,
    required this.templateName,
    required this.category,
    required this.version,
    required this.generatedAt,
    required this.layoutStructure,
    required this.styleRules,
    required this.positioningHints,
    required this.responsiveBehavior,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() => {
        'blueprintId': blueprintId,
        'templateId': templateId,
        'templateName': templateName,
        'category': category.name,
        'version': version,
        'generatedAt': generatedAt.toIso8601String(),
        'layoutStructure': layoutStructure.toMap(),
        'styleRules': styleRules.toMap(),
        'positioningHints': positioningHints.toMap(),
        'responsiveBehavior':
            responsiveBehavior.map((r) => r.toMap()).toList(),
        'metadata': metadata,
      };
}

// ── Template request ──────────────────────────────────────────
class TemplateRequest {
  final String requestId;
  final String templateId;
  final TemplateCategory category;
  final TemplateRatio ratio;
  final String themeId;
  final int version;
  final Map<String, dynamic> overrides;

  const TemplateRequest({
    required this.requestId,
    required this.templateId,
    required this.category,
    required this.ratio,
    required this.themeId,
    required this.version,
    this.overrides = const {},
  });
}

// ── Template result ───────────────────────────────────────────
class TemplateResult {
  final bool success;
  final TemplateBlueprint? blueprint;
  final List<String> errors;
  final List<String> warnings;

  const TemplateResult._({
    required this.success,
    this.blueprint,
    this.errors = const [],
    this.warnings = const [],
  });

  factory TemplateResult.ok(TemplateBlueprint blueprint,
          {List<String> warnings = const []}) =>
      TemplateResult._(
          success: true, blueprint: blueprint, warnings: warnings);

  factory TemplateResult.failure(List<String> errors,
          {List<String> warnings = const []}) =>
      TemplateResult._(success: false, errors: errors, warnings: warnings);
}

// ── Validation result ─────────────────────────────────────────
class TemplateValidationResult {
  final bool valid;
  final List<String> errors;
  final List<String> warnings;

  const TemplateValidationResult.ok({this.warnings = const []})
      : valid = true,
        errors = const [];

  const TemplateValidationResult.fail(this.errors,
      {this.warnings = const []})
      : valid = false;
}

// ── Built-in theme registry ───────────────────────────────────
// Themes that TemplateEngine ships with.
// Consumers may extend by passing a full ThemeDefinition via overrides.
class _ThemeRegistry {
  static const String _defaultThemeId = 'default';

  static final Map<String, ThemeDefinition> _themes = {
    _defaultThemeId: ThemeDefinition(
      themeId: _defaultThemeId,
      name: 'Default',
      tokens: [
        ThemeToken(key: 'color.primary', type: TokenType.color, value: '#1A73E8'),
        ThemeToken(key: 'color.secondary', type: TokenType.color, value: '#34A853'),
        ThemeToken(key: 'color.background', type: TokenType.color, value: '#FFFFFF'),
        ThemeToken(key: 'color.surface', type: TokenType.color, value: '#F8F9FA'),
        ThemeToken(key: 'color.text', type: TokenType.color, value: '#202124'),
        ThemeToken(key: 'color.muted', type: TokenType.color, value: '#5F6368'),
        ThemeToken(key: 'font.body', type: TokenType.fontFamily, value: 'Roboto'),
        ThemeToken(key: 'font.heading', type: TokenType.fontFamily, value: 'Roboto'),
        ThemeToken(key: 'fontSize.xs', type: TokenType.fontSize, value: 10.0),
        ThemeToken(key: 'fontSize.sm', type: TokenType.fontSize, value: 12.0),
        ThemeToken(key: 'fontSize.md', type: TokenType.fontSize, value: 16.0),
        ThemeToken(key: 'fontSize.lg', type: TokenType.fontSize, value: 24.0),
        ThemeToken(key: 'fontSize.xl', type: TokenType.fontSize, value: 36.0),
        ThemeToken(key: 'spacing.xs', type: TokenType.spacing, value: 4.0),
        ThemeToken(key: 'spacing.sm', type: TokenType.spacing, value: 8.0),
        ThemeToken(key: 'spacing.md', type: TokenType.spacing, value: 16.0),
        ThemeToken(key: 'spacing.lg', type: TokenType.spacing, value: 24.0),
        ThemeToken(key: 'spacing.xl', type: TokenType.spacing, value: 32.0),
        ThemeToken(key: 'borderRadius.sm', type: TokenType.borderRadius, value: 4.0),
        ThemeToken(key: 'borderRadius.md', type: TokenType.borderRadius, value: 8.0),
        ThemeToken(key: 'borderRadius.lg', type: TokenType.borderRadius, value: 16.0),
      ],
    ),
    'dark': ThemeDefinition(
      themeId: 'dark',
      name: 'Dark',
      tokens: [
        ThemeToken(key: 'color.primary', type: TokenType.color, value: '#8AB4F8'),
        ThemeToken(key: 'color.secondary', type: TokenType.color, value: '#81C995'),
        ThemeToken(key: 'color.background', type: TokenType.color, value: '#202124'),
        ThemeToken(key: 'color.surface', type: TokenType.color, value: '#2D2E31'),
        ThemeToken(key: 'color.text', type: TokenType.color, value: '#E8EAED'),
        ThemeToken(key: 'color.muted', type: TokenType.color, value: '#9AA0A6'),
        ThemeToken(key: 'font.body', type: TokenType.fontFamily, value: 'Roboto'),
        ThemeToken(key: 'font.heading', type: TokenType.fontFamily, value: 'Roboto'),
        ThemeToken(key: 'fontSize.xs', type: TokenType.fontSize, value: 10.0),
        ThemeToken(key: 'fontSize.sm', type: TokenType.fontSize, value: 12.0),
        ThemeToken(key: 'fontSize.md', type: TokenType.fontSize, value: 16.0),
        ThemeToken(key: 'fontSize.lg', type: TokenType.fontSize, value: 24.0),
        ThemeToken(key: 'fontSize.xl', type: TokenType.fontSize, value: 36.0),
        ThemeToken(key: 'spacing.xs', type: TokenType.spacing, value: 4.0),
        ThemeToken(key: 'spacing.sm', type: TokenType.spacing, value: 8.0),
        ThemeToken(key: 'spacing.md', type: TokenType.spacing, value: 16.0),
        ThemeToken(key: 'spacing.lg', type: TokenType.spacing, value: 24.0),
        ThemeToken(key: 'spacing.xl', type: TokenType.spacing, value: 32.0),
        ThemeToken(key: 'borderRadius.sm', type: TokenType.borderRadius, value: 4.0),
        ThemeToken(key: 'borderRadius.md', type: TokenType.borderRadius, value: 8.0),
        ThemeToken(key: 'borderRadius.lg', type: TokenType.borderRadius, value: 16.0),
      ],
    ),
    'minimal': ThemeDefinition(
      themeId: 'minimal',
      name: 'Minimal',
      tokens: [
        ThemeToken(key: 'color.primary', type: TokenType.color, value: '#000000'),
        ThemeToken(key: 'color.secondary', type: TokenType.color, value: '#444444'),
        ThemeToken(key: 'color.background', type: TokenType.color, value: '#FFFFFF'),
        ThemeToken(key: 'color.surface', type: TokenType.color, value: '#FAFAFA'),
        ThemeToken(key: 'color.text', type: TokenType.color, value: '#111111'),
        ThemeToken(key: 'color.muted', type: TokenType.color, value: '#888888'),
        ThemeToken(key: 'font.body', type: TokenType.fontFamily, value: 'Inter'),
        ThemeToken(key: 'font.heading', type: TokenType.fontFamily, value: 'Inter'),
        ThemeToken(key: 'fontSize.xs', type: TokenType.fontSize, value: 10.0),
        ThemeToken(key: 'fontSize.sm', type: TokenType.fontSize, value: 12.0),
        ThemeToken(key: 'fontSize.md', type: TokenType.fontSize, value: 16.0),
        ThemeToken(key: 'fontSize.lg', type: TokenType.fontSize, value: 24.0),
        ThemeToken(key: 'fontSize.xl', type: TokenType.fontSize, value: 36.0),
        ThemeToken(key: 'spacing.xs', type: TokenType.spacing, value: 4.0),
        ThemeToken(key: 'spacing.sm', type: TokenType.spacing, value: 8.0),
        ThemeToken(key: 'spacing.md', type: TokenType.spacing, value: 16.0),
        ThemeToken(key: 'spacing.lg', type: TokenType.spacing, value: 24.0),
        ThemeToken(key: 'spacing.xl', type: TokenType.spacing, value: 32.0),
        ThemeToken(key: 'borderRadius.sm', type: TokenType.borderRadius, value: 0.0),
        ThemeToken(key: 'borderRadius.md', type: TokenType.borderRadius, value: 0.0),
        ThemeToken(key: 'borderRadius.lg', type: TokenType.borderRadius, value: 0.0),
      ],
    ),
  };

  static ThemeDefinition? resolve(String themeId) => _themes[themeId];
  static bool contains(String themeId) => _themes.containsKey(themeId);
  static List<String> get knownIds => _themes.keys.toList();
}

// ── Ratio dimension registry ──────────────────────────────────
class _RatioDimensions {
  static const Map<TemplateRatio, (double, double)> _dimensions = {
    TemplateRatio.square:       (1080, 1080),
    TemplateRatio.landscape:    (1920, 1080),
    TemplateRatio.portrait:     (1080, 1920),
    TemplateRatio.classic:      (1440, 1080),
    TemplateRatio.cinematic:    (2520, 1080),
    TemplateRatio.a4Portrait:   (794,  1123),
    TemplateRatio.a4Landscape:  (1123, 794),
    TemplateRatio.twitter:      (1500, 750),
    TemplateRatio.instagram:    (1080, 1350),
    TemplateRatio.custom:       (1920, 1080),
  };

  static (double, double) of(TemplateRatio ratio) =>
      _dimensions[ratio] ?? (1920, 1080);
}

// ── Preset zone layouts ───────────────────────────────────────
class _PresetZones {
  static List<PlaceholderZone> forCategory(TemplateCategory category) {
    switch (category) {
      case TemplateCategory.socialMedia:
        return _socialMediaZones();
      case TemplateCategory.presentation:
        return _presentationZones();
      case TemplateCategory.poster:
        return _posterZones();
      case TemplateCategory.banner:
        return _bannerZones();
      case TemplateCategory.flyer:
        return _flyerZones();
      case TemplateCategory.card:
        return _cardZones();
      case TemplateCategory.certificate:
        return _certificateZones();
      case TemplateCategory.thumbnail:
        return _thumbnailZones();
      case TemplateCategory.infographic:
        return _infographicZones();
      case TemplateCategory.advertisement:
        return _advertisementZones();
    }
  }

  static List<PlaceholderZone> _socialMediaZones() => [
        const PlaceholderZone(
          zoneId: 'background', zoneType: ZoneType.background,
          label: 'Background', xPercent: 0, yPercent: 0,
          widthPercent: 1, heightPercent: 1,
          alignment: ZoneAlignment.center, zIndex: 0,
        ),
        const PlaceholderZone(
          zoneId: 'headline', zoneType: ZoneType.text,
          label: 'Headline', xPercent: 0.1, yPercent: 0.35,
          widthPercent: 0.8, heightPercent: 0.15,
          alignment: ZoneAlignment.center, zIndex: 2,
          hints: {'fontSize': 'xl', 'fontWeight': 'bold'},
        ),
        const PlaceholderZone(
          zoneId: 'subtext', zoneType: ZoneType.text,
          label: 'Subtext', xPercent: 0.15, yPercent: 0.52,
          widthPercent: 0.7, heightPercent: 0.1,
          alignment: ZoneAlignment.center, zIndex: 3,
          hints: {'fontSize': 'md', 'fontWeight': 'regular'},
        ),
        const PlaceholderZone(
          zoneId: 'image', zoneType: ZoneType.image,
          label: 'Main Image', xPercent: 0.1, yPercent: 0.05,
          widthPercent: 0.8, heightPercent: 0.28,
          alignment: ZoneAlignment.topCenter, zIndex: 1,
          optional: true,
        ),
        const PlaceholderZone(
          zoneId: 'logo', zoneType: ZoneType.icon,
          label: 'Logo', xPercent: 0.38, yPercent: 0.82,
          widthPercent: 0.24, heightPercent: 0.08,
          alignment: ZoneAlignment.bottomCenter, zIndex: 4,
          optional: true,
        ),
      ];

  static List<PlaceholderZone> _presentationZones() => [
        const PlaceholderZone(
          zoneId: 'background', zoneType: ZoneType.background,
          label: 'Slide Background', xPercent: 0, yPercent: 0,
          widthPercent: 1, heightPercent: 1,
          alignment: ZoneAlignment.center, zIndex: 0,
        ),
        const PlaceholderZone(
          zoneId: 'title', zoneType: ZoneType.text,
          label: 'Title', xPercent: 0.08, yPercent: 0.08,
          widthPercent: 0.84, heightPercent: 0.2,
          alignment: ZoneAlignment.topLeft, zIndex: 2,
          hints: {'fontSize': 'xl', 'fontWeight': 'bold'},
        ),
        const PlaceholderZone(
          zoneId: 'body', zoneType: ZoneType.text,
          label: 'Body Text', xPercent: 0.08, yPercent: 0.35,
          widthPercent: 0.84, heightPercent: 0.45,
          alignment: ZoneAlignment.centerLeft, zIndex: 3,
          hints: {'fontSize': 'md', 'fontWeight': 'regular'},
        ),
        const PlaceholderZone(
          zoneId: 'footer', zoneType: ZoneType.text,
          label: 'Footer', xPercent: 0.08, yPercent: 0.88,
          widthPercent: 0.84, heightPercent: 0.07,
          alignment: ZoneAlignment.bottomLeft, zIndex: 4,
          hints: {'fontSize': 'sm', 'fontWeight': 'regular'},
          optional: true,
        ),
        const PlaceholderZone(
          zoneId: 'accent', zoneType: ZoneType.shape,
          label: 'Accent Shape', xPercent: 0, yPercent: 0,
          widthPercent: 0.04, heightPercent: 1,
          alignment: ZoneAlignment.centerLeft, zIndex: 1,
          optional: true,
        ),
      ];

  static List<PlaceholderZone> _posterZones() => [
        const PlaceholderZone(
          zoneId: 'background', zoneType: ZoneType.background,
          label: 'Poster Background', xPercent: 0, yPercent: 0,
          widthPercent: 1, heightPercent: 1,
          alignment: ZoneAlignment.center, zIndex: 0,
        ),
        const PlaceholderZone(
          zoneId: 'hero_image', zoneType: ZoneType.image,
          label: 'Hero Image', xPercent: 0, yPercent: 0,
          widthPercent: 1, heightPercent: 0.55,
          alignment: ZoneAlignment.topCenter, zIndex: 1,
        ),
        const PlaceholderZone(
          zoneId: 'title', zoneType: ZoneType.text,
          label: 'Title', xPercent: 0.08, yPercent: 0.58,
          widthPercent: 0.84, heightPercent: 0.15,
          alignment: ZoneAlignment.topCenter, zIndex: 2,
          hints: {'fontSize': 'xl', 'fontWeight': 'bold'},
        ),
        const PlaceholderZone(
          zoneId: 'subtitle', zoneType: ZoneType.text,
          label: 'Subtitle', xPercent: 0.1, yPercent: 0.74,
          widthPercent: 0.8, heightPercent: 0.1,
          alignment: ZoneAlignment.center, zIndex: 3,
          hints: {'fontSize': 'lg'},
          optional: true,
        ),
        const PlaceholderZone(
          zoneId: 'details', zoneType: ZoneType.text,
          label: 'Details', xPercent: 0.1, yPercent: 0.86,
          widthPercent: 0.8, heightPercent: 0.08,
          alignment: ZoneAlignment.bottomCenter, zIndex: 4,
          hints: {'fontSize': 'sm'},
          optional: true,
        ),
      ];

  static List<PlaceholderZone> _bannerZones() => [
        const PlaceholderZone(
          zoneId: 'background', zoneType: ZoneType.background,
          label: 'Banner Background', xPercent: 0, yPercent: 0,
          widthPercent: 1, heightPercent: 1,
          alignment: ZoneAlignment.center, zIndex: 0,
        ),
        const PlaceholderZone(
          zoneId: 'brand', zoneType: ZoneType.icon,
          label: 'Brand / Logo', xPercent: 0.02, yPercent: 0.15,
          widthPercent: 0.12, heightPercent: 0.7,
          alignment: ZoneAlignment.centerLeft, zIndex: 2,
          optional: true,
        ),
        const PlaceholderZone(
          zoneId: 'headline', zoneType: ZoneType.text,
          label: 'Headline', xPercent: 0.18, yPercent: 0.1,
          widthPercent: 0.5, heightPercent: 0.45,
          alignment: ZoneAlignment.centerLeft, zIndex: 3,
          hints: {'fontSize': 'xl', 'fontWeight': 'bold'},
        ),
        const PlaceholderZone(
          zoneId: 'cta', zoneType: ZoneType.shape,
          label: 'Call-to-Action', xPercent: 0.18, yPercent: 0.6,
          widthPercent: 0.2, heightPercent: 0.25,
          alignment: ZoneAlignment.centerLeft, zIndex: 4,
        ),
        const PlaceholderZone(
          zoneId: 'image', zoneType: ZoneType.image,
          label: 'Visual', xPercent: 0.72, yPercent: 0,
          widthPercent: 0.28, heightPercent: 1,
          alignment: ZoneAlignment.centerRight, zIndex: 1,
          optional: true,
        ),
      ];

  static List<PlaceholderZone> _flyerZones() => [
        const PlaceholderZone(
          zoneId: 'background', zoneType: ZoneType.background,
          label: 'Flyer Background', xPercent: 0, yPercent: 0,
          widthPercent: 1, heightPercent: 1,
          alignment: ZoneAlignment.center, zIndex: 0,
        ),
        const PlaceholderZone(
          zoneId: 'title', zoneType: ZoneType.text,
          label: 'Title', xPercent: 0.08, yPercent: 0.06,
          widthPercent: 0.84, heightPercent: 0.16,
          alignment: ZoneAlignment.topCenter, zIndex: 2,
          hints: {'fontSize': 'xl', 'fontWeight': 'bold'},
        ),
        const PlaceholderZone(
          zoneId: 'image', zoneType: ZoneType.image,
          label: 'Feature Image', xPercent: 0.1, yPercent: 0.24,
          widthPercent: 0.8, heightPercent: 0.35,
          alignment: ZoneAlignment.center, zIndex: 1,
        ),
        const PlaceholderZone(
          zoneId: 'body', zoneType: ZoneType.text,
          label: 'Description', xPercent: 0.08, yPercent: 0.62,
          widthPercent: 0.84, heightPercent: 0.2,
          alignment: ZoneAlignment.centerLeft, zIndex: 3,
          hints: {'fontSize': 'md'},
        ),
        const PlaceholderZone(
          zoneId: 'contact', zoneType: ZoneType.text,
          label: 'Contact / CTA', xPercent: 0.08, yPercent: 0.85,
          widthPercent: 0.84, heightPercent: 0.1,
          alignment: ZoneAlignment.bottomCenter, zIndex: 4,
          hints: {'fontSize': 'sm'},
          optional: true,
        ),
      ];

  static List<PlaceholderZone> _cardZones() => [
        const PlaceholderZone(
          zoneId: 'background', zoneType: ZoneType.background,
          label: 'Card Background', xPercent: 0, yPercent: 0,
          widthPercent: 1, heightPercent: 1,
          alignment: ZoneAlignment.center, zIndex: 0,
        ),
        const PlaceholderZone(
          zoneId: 'avatar', zoneType: ZoneType.image,
          label: 'Avatar / Photo', xPercent: 0.35, yPercent: 0.08,
          widthPercent: 0.3, heightPercent: 0.3,
          alignment: ZoneAlignment.topCenter, zIndex: 1,
          optional: true,
        ),
        const PlaceholderZone(
          zoneId: 'name', zoneType: ZoneType.text,
          label: 'Name', xPercent: 0.1, yPercent: 0.42,
          widthPercent: 0.8, heightPercent: 0.15,
          alignment: ZoneAlignment.center, zIndex: 2,
          hints: {'fontSize': 'lg', 'fontWeight': 'bold'},
        ),
        const PlaceholderZone(
          zoneId: 'role', zoneType: ZoneType.text,
          label: 'Role / Title', xPercent: 0.1, yPercent: 0.58,
          widthPercent: 0.8, heightPercent: 0.1,
          alignment: ZoneAlignment.center, zIndex: 3,
          hints: {'fontSize': 'sm'},
          optional: true,
        ),
        const PlaceholderZone(
          zoneId: 'details', zoneType: ZoneType.text,
          label: 'Contact Details', xPercent: 0.1, yPercent: 0.72,
          widthPercent: 0.8, heightPercent: 0.2,
          alignment: ZoneAlignment.bottomCenter, zIndex: 4,
          hints: {'fontSize': 'xs'},
          optional: true,
        ),
      ];

  static List<PlaceholderZone> _certificateZones() => [
        const PlaceholderZone(
          zoneId: 'background', zoneType: ZoneType.background,
          label: 'Certificate Background', xPercent: 0, yPercent: 0,
          widthPercent: 1, heightPercent: 1,
          alignment: ZoneAlignment.center, zIndex: 0,
        ),
        const PlaceholderZone(
          zoneId: 'border', zoneType: ZoneType.frame,
          label: 'Decorative Border', xPercent: 0.02, yPercent: 0.02,
          widthPercent: 0.96, heightPercent: 0.96,
          alignment: ZoneAlignment.center, zIndex: 1,
          optional: true,
        ),
        const PlaceholderZone(
          zoneId: 'cert_title', zoneType: ZoneType.text,
          label: 'Certificate Title', xPercent: 0.1, yPercent: 0.08,
          widthPercent: 0.8, heightPercent: 0.15,
          alignment: ZoneAlignment.topCenter, zIndex: 2,
          hints: {'fontSize': 'xl', 'fontWeight': 'bold'},
        ),
        const PlaceholderZone(
          zoneId: 'recipient', zoneType: ZoneType.text,
          label: 'Recipient Name', xPercent: 0.1, yPercent: 0.35,
          widthPercent: 0.8, heightPercent: 0.15,
          alignment: ZoneAlignment.center, zIndex: 3,
          hints: {'fontSize': 'xl'},
        ),
        const PlaceholderZone(
          zoneId: 'body', zoneType: ZoneType.text,
          label: 'Body Text', xPercent: 0.1, yPercent: 0.52,
          widthPercent: 0.8, heightPercent: 0.2,
          alignment: ZoneAlignment.center, zIndex: 4,
          hints: {'fontSize': 'md'},
        ),
        const PlaceholderZone(
          zoneId: 'signature', zoneType: ZoneType.image,
          label: 'Signature', xPercent: 0.62, yPercent: 0.8,
          widthPercent: 0.25, heightPercent: 0.12,
          alignment: ZoneAlignment.bottomRight, zIndex: 5,
          optional: true,
        ),
        const PlaceholderZone(
          zoneId: 'date', zoneType: ZoneType.text,
          label: 'Date', xPercent: 0.1, yPercent: 0.86,
          widthPercent: 0.3, heightPercent: 0.07,
          alignment: ZoneAlignment.bottomLeft, zIndex: 6,
          hints: {'fontSize': 'sm'},
          optional: true,
        ),
      ];

  static List<PlaceholderZone> _thumbnailZones() => [
        const PlaceholderZone(
          zoneId: 'background', zoneType: ZoneType.background,
          label: 'Thumbnail Background', xPercent: 0, yPercent: 0,
          widthPercent: 1, heightPercent: 1,
          alignment: ZoneAlignment.center, zIndex: 0,
        ),
        const PlaceholderZone(
          zoneId: 'main_image', zoneType: ZoneType.image,
          label: 'Main Visual', xPercent: 0, yPercent: 0,
          widthPercent: 1, heightPercent: 1,
          alignment: ZoneAlignment.center, zIndex: 1,
          optional: true,
        ),
        const PlaceholderZone(
          zoneId: 'overlay', zoneType: ZoneType.overlay,
          label: 'Overlay', xPercent: 0, yPercent: 0.5,
          widthPercent: 1, heightPercent: 0.5,
          alignment: ZoneAlignment.bottomCenter, zIndex: 2,
          optional: true,
        ),
        const PlaceholderZone(
          zoneId: 'title', zoneType: ZoneType.text,
          label: 'Title', xPercent: 0.05, yPercent: 0.55,
          widthPercent: 0.9, heightPercent: 0.3,
          alignment: ZoneAlignment.bottomLeft, zIndex: 3,
          hints: {'fontSize': 'xl', 'fontWeight': 'bold'},
        ),
        const PlaceholderZone(
          zoneId: 'badge', zoneType: ZoneType.shape,
          label: 'Badge', xPercent: 0.02, yPercent: 0.04,
          widthPercent: 0.2, heightPercent: 0.15,
          alignment: ZoneAlignment.topLeft, zIndex: 4,
          optional: true,
        ),
      ];

  static List<PlaceholderZone> _infographicZones() => [
        const PlaceholderZone(
          zoneId: 'background', zoneType: ZoneType.background,
          label: 'Infographic Background', xPercent: 0, yPercent: 0,
          widthPercent: 1, heightPercent: 1,
          alignment: ZoneAlignment.center, zIndex: 0,
        ),
        const PlaceholderZone(
          zoneId: 'header', zoneType: ZoneType.text,
          label: 'Header Title', xPercent: 0.05, yPercent: 0.03,
          widthPercent: 0.9, heightPercent: 0.12,
          alignment: ZoneAlignment.topCenter, zIndex: 2,
          hints: {'fontSize': 'xl', 'fontWeight': 'bold'},
        ),
        const PlaceholderZone(
          zoneId: 'section_1', zoneType: ZoneType.shape,
          label: 'Section 1', xPercent: 0.05, yPercent: 0.18,
          widthPercent: 0.27, heightPercent: 0.35,
          alignment: ZoneAlignment.topLeft, zIndex: 1,
        ),
        const PlaceholderZone(
          zoneId: 'section_2', zoneType: ZoneType.shape,
          label: 'Section 2', xPercent: 0.365, yPercent: 0.18,
          widthPercent: 0.27, heightPercent: 0.35,
          alignment: ZoneAlignment.topCenter, zIndex: 1,
        ),
        const PlaceholderZone(
          zoneId: 'section_3', zoneType: ZoneType.shape,
          label: 'Section 3', xPercent: 0.68, yPercent: 0.18,
          widthPercent: 0.27, heightPercent: 0.35,
          alignment: ZoneAlignment.topRight, zIndex: 1,
        ),
        const PlaceholderZone(
          zoneId: 'chart', zoneType: ZoneType.image,
          label: 'Chart / Data Visual', xPercent: 0.05, yPercent: 0.57,
          widthPercent: 0.9, heightPercent: 0.3,
          alignment: ZoneAlignment.center, zIndex: 2,
          optional: true,
        ),
        const PlaceholderZone(
          zoneId: 'footer', zoneType: ZoneType.text,
          label: 'Footer / Source', xPercent: 0.05, yPercent: 0.9,
          widthPercent: 0.9, heightPercent: 0.07,
          alignment: ZoneAlignment.bottomCenter, zIndex: 3,
          hints: {'fontSize': 'xs'},
          optional: true,
        ),
      ];

  static List<PlaceholderZone> _advertisementZones() => [
        const PlaceholderZone(
          zoneId: 'background', zoneType: ZoneType.background,
          label: 'Ad Background', xPercent: 0, yPercent: 0,
          widthPercent: 1, heightPercent: 1,
          alignment: ZoneAlignment.center, zIndex: 0,
        ),
        const PlaceholderZone(
          zoneId: 'product_image', zoneType: ZoneType.image,
          label: 'Product Image', xPercent: 0.5, yPercent: 0.05,
          widthPercent: 0.48, heightPercent: 0.65,
          alignment: ZoneAlignment.topRight, zIndex: 1,
        ),
        const PlaceholderZone(
          zoneId: 'headline', zoneType: ZoneType.text,
          label: 'Headline', xPercent: 0.05, yPercent: 0.08,
          widthPercent: 0.43, heightPercent: 0.22,
          alignment: ZoneAlignment.topLeft, zIndex: 2,
          hints: {'fontSize': 'xl', 'fontWeight': 'bold'},
        ),
        const PlaceholderZone(
          zoneId: 'tagline', zoneType: ZoneType.text,
          label: 'Tagline', xPercent: 0.05, yPercent: 0.32,
          widthPercent: 0.43, heightPercent: 0.15,
          alignment: ZoneAlignment.centerLeft, zIndex: 3,
          hints: {'fontSize': 'md'},
          optional: true,
        ),
        const PlaceholderZone(
          zoneId: 'cta_button', zoneType: ZoneType.shape,
          label: 'CTA Button', xPercent: 0.05, yPercent: 0.52,
          widthPercent: 0.3, heightPercent: 0.12,
          alignment: ZoneAlignment.centerLeft, zIndex: 4,
        ),
        const PlaceholderZone(
          zoneId: 'logo', zoneType: ZoneType.icon,
          label: 'Brand Logo', xPercent: 0.05, yPercent: 0.76,
          widthPercent: 0.2, heightPercent: 0.12,
          alignment: ZoneAlignment.bottomLeft, zIndex: 5,
          optional: true,
        ),
      ];
}

// ── TemplateEngine ────────────────────────────────────────────
class TemplateEngine {
  static const int _currentTemplateVersion = 1;

  // ── Blueprint generation ─────────────────────────────────────

  TemplateResult generateTemplate(TemplateRequest request) {
    try {
      // Run full validation pipeline before generation.
      final requestValidation = validateTemplateRequest(request);
      if (!requestValidation.valid) {
        return TemplateResult.failure(
          requestValidation.errors,
          warnings: requestValidation.warnings,
        );
      }

      final theme = _resolveTheme(request);
      final (canvasWidth, canvasHeight) = _RatioDimensions.of(request.ratio);
      final zones = _PresetZones.forCategory(request.category);

      final layout = LayoutStructure(
        layoutId: '${request.templateId}_layout',
        ratio: request.ratio,
        canvasWidth: canvasWidth,
        canvasHeight: canvasHeight,
        zones: zones,
        margins: const {
          'top': 40, 'right': 40, 'bottom': 40, 'left': 40,
        },
        gutters: const {'columnGap': 16, 'rowGap': 16},
      );

      final styleRules = StyleRules(
        theme: theme,
        typographyScale: _buildTypographyScale(theme),
        colorPalette: _buildColorPalette(theme),
        spacingScale: _buildSpacingScale(theme),
        borderRadiusScale: _buildBorderRadiusScale(theme),
      );

      final blueprint = TemplateBlueprint(
        blueprintId: '${request.requestId}_bp',
        templateId: request.templateId,
        templateName: _templateName(request.category, request.ratio),
        category: request.category,
        version: _currentTemplateVersion,
        generatedAt: DateTime.now().toUtc(),
        layoutStructure: layout,
        styleRules: styleRules,
        positioningHints: const PositioningHints(
          snapToGrid: true,
          gridSize: 8.0,
        ),
        responsiveBehavior: _buildResponsiveRules(zones),
        metadata: {
          'requestId': request.requestId,
          'themeId': request.themeId,
          'generatedBy': 'TemplateEngine',
        },
      );

      // Validate the generated blueprint before returning.
      final blueprintValidation = validateTemplateBlueprint(blueprint);
      if (!blueprintValidation.valid) {
        return TemplateResult.failure(
          blueprintValidation.errors,
          warnings: blueprintValidation.warnings,
        );
      }

      return TemplateResult.ok(
        blueprint,
        warnings: [
          ...requestValidation.warnings,
          ...blueprintValidation.warnings,
        ],
      );
    } catch (e) {
      return TemplateResult.failure(
          ['Unexpected error during template generation: $e']);
    }
  }

  // ── Request validation ────────────────────────────────────────

  TemplateValidationResult validateTemplateRequest(TemplateRequest request) {
    final errors = <String>[];
    final warnings = <String>[];

    // REJECT IF: category missing (enum is always set, validate ID)
    if (request.requestId.trim().isEmpty) {
      errors.add('TemplateRequest.requestId must not be empty.');
    }
    if (request.templateId.trim().isEmpty) {
      errors.add('TemplateRequest.templateId must not be empty.');
    }

    // REJECT IF: ratio invalid
    if (request.ratio == TemplateRatio.custom) {
      warnings.add(
          'TemplateRatio.custom uses default 1920×1080 dimensions. '
          'Override via TemplateRequest.overrides if custom dimensions are needed.');
    }

    // REJECT IF: theme undefined
    if (!_ThemeRegistry.contains(request.themeId)) {
      final override = request.overrides['theme'];
      if (override is! Map) {
        errors.add(
            'Theme "${request.themeId}" is not defined in the registry and '
            'no override theme map was provided. '
            'Known themes: ${_ThemeRegistry.knownIds.join(', ')}.');
      } else {
        warnings.add(
            'Theme "${request.themeId}" resolved from request.overrides map.');
      }
    }

    // REJECT IF: version mismatch
    if (request.version != _currentTemplateVersion) {
      if (request.version > _currentTemplateVersion) {
        errors.add(
            'TemplateRequest.version ${request.version} exceeds current '
            'engine version $_currentTemplateVersion. Upgrade TemplateEngine.');
      } else {
        warnings.add(
            'TemplateRequest.version ${request.version} is behind current '
            'engine version $_currentTemplateVersion. Blueprint will use '
            'current version.');
      }
    }

    if (errors.isEmpty) {
      return TemplateValidationResult.ok(warnings: warnings);
    }
    return TemplateValidationResult.fail(errors, warnings: warnings);
  }

  // ── Blueprint validation ──────────────────────────────────────

  TemplateValidationResult validateTemplateBlueprint(
      TemplateBlueprint blueprint) {
    final errors = <String>[];
    final warnings = <String>[];

    // REJECT IF: structure corrupted
    if (blueprint.blueprintId.trim().isEmpty) {
      errors.add('TemplateBlueprint.blueprintId must not be empty.');
    }
    if (blueprint.templateId.trim().isEmpty) {
      errors.add('TemplateBlueprint.templateId must not be empty.');
    }

    final layout = blueprint.layoutStructure;

    // Canvas must have valid dimensions.
    if (layout.canvasWidth <= 0) {
      errors.add(
          'LayoutStructure.canvasWidth must be > 0 (got ${layout.canvasWidth}).');
    }
    if (layout.canvasHeight <= 0) {
      errors.add(
          'LayoutStructure.canvasHeight must be > 0 (got ${layout.canvasHeight}).');
    }

    // At least one zone must be present.
    if (layout.zones.isEmpty) {
      errors.add('LayoutStructure must contain at least one PlaceholderZone.');
    }

    // Each zone must have valid relative dimensions.
    final zoneIds = <String>{};
    for (final zone in layout.zones) {
      if (zone.zoneId.trim().isEmpty) {
        errors.add('A PlaceholderZone has an empty zoneId.');
      } else if (!zoneIds.add(zone.zoneId)) {
        errors.add('Duplicate PlaceholderZone zoneId: "${zone.zoneId}".');
      }

      if (zone.xPercent < 0 || zone.xPercent > 1) {
        errors.add(
            'Zone "${zone.zoneId}": xPercent must be in [0.0, 1.0] '
            '(got ${zone.xPercent}).');
      }
      if (zone.yPercent < 0 || zone.yPercent > 1) {
        errors.add(
            'Zone "${zone.zoneId}": yPercent must be in [0.0, 1.0] '
            '(got ${zone.yPercent}).');
      }
      if (zone.widthPercent <= 0 || zone.widthPercent > 1) {
        errors.add(
            'Zone "${zone.zoneId}": widthPercent must be in (0.0, 1.0] '
            '(got ${zone.widthPercent}).');
      }
      if (zone.heightPercent <= 0 || zone.heightPercent > 1) {
        errors.add(
            'Zone "${zone.zoneId}": heightPercent must be in (0.0, 1.0] '
            '(got ${zone.heightPercent}).');
      }
    }

    // Theme must be present.
    if (blueprint.styleRules.theme.themeId.trim().isEmpty) {
      errors.add('StyleRules.theme.themeId must not be empty.');
    }
    if (blueprint.styleRules.theme.tokens.isEmpty) {
      warnings
          .add('StyleRules.theme "${blueprint.styleRules.theme.name}" has no tokens.');
    }

    // REJECT IF: version mismatch
    if (blueprint.version != _currentTemplateVersion) {
      errors.add(
          'TemplateBlueprint.version ${blueprint.version} does not match '
          'current engine version $_currentTemplateVersion.');
    }

    if (errors.isEmpty) {
      return TemplateValidationResult.ok(warnings: warnings);
    }
    return TemplateValidationResult.fail(errors, warnings: warnings);
  }

  // ── Private helpers ───────────────────────────────────────────

  ThemeDefinition _resolveTheme(TemplateRequest request) {
    final registered = _ThemeRegistry.resolve(request.themeId);
    if (registered != null) return registered;

    // Attempt to resolve from overrides map.
    final override = request.overrides['theme'];
    if (override is Map) {
      try {
        final tokenList = <ThemeToken>[];
        final rawTokens = override['tokens'];
        if (rawTokens is List) {
          for (final t in rawTokens) {
            if (t is Map) {
              tokenList.add(ThemeToken(
                key: t['key'] as String? ?? '',
                type: TokenType.values.firstWhere(
                  (e) => e.name == t['type'],
                  orElse: () => TokenType.color,
                ),
                value: t['value'],
                description: t['description'] as String?,
              ));
            }
          }
        }
        return ThemeDefinition(
          themeId: request.themeId,
          name: override['name'] as String? ?? request.themeId,
          tokens: tokenList,
        );
      } catch (_) {
        // Fall through to default.
      }
    }

    return _ThemeRegistry.resolve('default')!;
  }

  String _templateName(TemplateCategory category, TemplateRatio ratio) {
    final cat = category.name
        .replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m.group(0)}')
        .trim()
        .toLowerCase()
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
    final r = ratio.name
        .replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m.group(0)}')
        .trim();
    return '$cat · $r';
  }

  Map<String, dynamic> _buildTypographyScale(ThemeDefinition theme) {
    return {
      'xs': theme.token('fontSize.xs')?.value ?? 10.0,
      'sm': theme.token('fontSize.sm')?.value ?? 12.0,
      'md': theme.token('fontSize.md')?.value ?? 16.0,
      'lg': theme.token('fontSize.lg')?.value ?? 24.0,
      'xl': theme.token('fontSize.xl')?.value ?? 36.0,
      'fontBody': theme.token('font.body')?.value ?? 'Roboto',
      'fontHeading': theme.token('font.heading')?.value ?? 'Roboto',
    };
  }

  Map<String, dynamic> _buildColorPalette(ThemeDefinition theme) {
    return {
      'primary': theme.token('color.primary')?.value ?? '#1A73E8',
      'secondary': theme.token('color.secondary')?.value ?? '#34A853',
      'background': theme.token('color.background')?.value ?? '#FFFFFF',
      'surface': theme.token('color.surface')?.value ?? '#F8F9FA',
      'text': theme.token('color.text')?.value ?? '#202124',
      'muted': theme.token('color.muted')?.value ?? '#5F6368',
    };
  }

  Map<String, double> _buildSpacingScale(ThemeDefinition theme) {
    return {
      'xs': (theme.token('spacing.xs')?.value as num?)?.toDouble() ?? 4.0,
      'sm': (theme.token('spacing.sm')?.value as num?)?.toDouble() ?? 8.0,
      'md': (theme.token('spacing.md')?.value as num?)?.toDouble() ?? 16.0,
      'lg': (theme.token('spacing.lg')?.value as num?)?.toDouble() ?? 24.0,
      'xl': (theme.token('spacing.xl')?.value as num?)?.toDouble() ?? 32.0,
    };
  }

  Map<String, double> _buildBorderRadiusScale(ThemeDefinition theme) {
    return {
      'sm': (theme.token('borderRadius.sm')?.value as num?)?.toDouble() ?? 4.0,
      'md': (theme.token('borderRadius.md')?.value as num?)?.toDouble() ?? 8.0,
      'lg': (theme.token('borderRadius.lg')?.value as num?)?.toDouble() ?? 16.0,
    };
  }

  List<ResponsiveRule> _buildResponsiveRules(List<PlaceholderZone> zones) {
    // Mobile: optional zones hidden; all zones scaled to 0.85.
    final mobileScale = {for (final z in zones) z.zoneId: 0.85};
    final mobileVisibility = {
      for (final z in zones.where((z) => z.optional)) z.zoneId: false,
    };

    // Tablet: slight scale reduction; optional zones remain visible.
    final tabletScale = {for (final z in zones) z.zoneId: 0.92};

    // Desktop: full scale (1.0 is the default; rule still listed for
    // explicit configuration completeness).
    final desktopScale = {for (final z in zones) z.zoneId: 1.0};

    return [
      ResponsiveRule(
        breakPoint: BreakPoint.mobile,
        zoneScaleOverrides: mobileScale,
        zoneVisibilityOverrides: mobileVisibility,
      ),
      ResponsiveRule(
        breakPoint: BreakPoint.tablet,
        zoneScaleOverrides: tabletScale,
      ),
      ResponsiveRule(
        breakPoint: BreakPoint.desktop,
        zoneScaleOverrides: desktopScale,
      ),
    ];
  }
}
