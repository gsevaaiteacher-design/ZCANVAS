// screens/generator_screen.dart
//
// PHASE-11 — Generator Screen (Intent Creation UI)
//
// ===========================================================================
// OWNERSHIP CONTRACT
// ===========================================================================
//
// WHAT THIS FILE CAN DO:
//   • Build the Generator form widget tree (pure visual composition)
//   • Hold ephemeral UI state: text input, selector choices, scroll position
//   • Capture form inputs and forward structured intent to EditorController
//   • Display read-only template cards passed in via constructor
//   • Provide a Voice Button UI placeholder (no execution — future hook only)
//   • Provide responsive layout via LayoutBuilder
//
// WHAT THIS FILE CANNOT DO:
//   ❌ Call TemplateEngine directly
//   ❌ Execute AI processing
//   ❌ Access Canvas or RenderEngine
//   ❌ Modify layers, history, or storage
//   ❌ Own design data or template data
//   ❌ Decide navigation or business flow independently
//
// ALL INTERACTION FLOWS THROUGH:
//   EditorController (via GeneratorScreenDelegate) — the only gate.
// ===========================================================================

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// SECTION 1 — EDITORCONTROLLER DELEGATE INTERFACE
// ---------------------------------------------------------------------------

/// Intent contract that EditorController must implement to receive all
/// interaction signals from GeneratorScreen.
abstract interface class GeneratorScreenDelegate {
  /// User tapped Back — navigate away from Generator.
  void onNavigateBack();

  /// User tapped Generate with the current form state.
  ///
  /// [request] is a pure data object built from ephemeral UI state.
  /// EditorController decides what to do with it.
  void onGenerateDesign(GeneratorRequest request);

  /// User tapped Use Template for [templateId].
  void onUseTemplate(String templateId);

  /// User tapped the Voice Button — future hook; no execution today.
  void onVoiceInputRequested();
}

// ---------------------------------------------------------------------------
// SECTION 2 — GENERATOR REQUEST (intent payload, no logic)
// ---------------------------------------------------------------------------

/// Pure data object assembled from ephemeral form state.
///
/// Passed to [GeneratorScreenDelegate.onGenerateDesign].
/// Contains no logic, no engine references, no mutations.
final class GeneratorRequest {
  const GeneratorRequest({
    required this.prompt,
    this.category,
    this.ratio,
    this.style,
    this.language,
  });

  final String prompt;
  final String? category;
  final String? ratio;
  final String? style;
  final String? language;

  bool get hasPrompt => prompt.trim().isNotEmpty;

  @override
  String toString() =>
      'GeneratorRequest(prompt: "$prompt", category: $category, '
      'ratio: $ratio, style: $style, language: $language)';
}

// ---------------------------------------------------------------------------
// SECTION 3 — READ-ONLY VIEW MODELS
// ---------------------------------------------------------------------------

/// Read-only display model for a template preview card.
final class TemplateViewModel {
  const TemplateViewModel({
    required this.templateId,
    required this.title,
    this.category,
    this.previewColor,
  });

  final String templateId;
  final String title;
  final String? category;
  final Color? previewColor;
}

// ---------------------------------------------------------------------------
// SECTION 4 — SELECTOR OPTION MODEL
// ---------------------------------------------------------------------------

/// A single option entry for any selector (category, ratio, style, language).
final class SelectorOption {
  const SelectorOption({required this.value, required this.label, this.icon});

  final String value;
  final String label;
  final IconData? icon;
}

// ---------------------------------------------------------------------------
// SECTION 5 — DEFAULT SELECTOR OPTIONS (UI display data only)
// ---------------------------------------------------------------------------

abstract final class _DefaultOptions {
  static const List<SelectorOption> categories = [
    SelectorOption(value: 'social', label: 'Social Post', icon: Icons.photo_outlined),
    SelectorOption(value: 'presentation', label: 'Presentation', icon: Icons.slideshow_outlined),
    SelectorOption(value: 'poster', label: 'Poster', icon: Icons.photo_size_select_large_outlined),
    SelectorOption(value: 'logo', label: 'Logo', icon: Icons.star_outline),
    SelectorOption(value: 'banner', label: 'Banner', icon: Icons.view_headline_outlined),
    SelectorOption(value: 'card', label: 'Card', icon: Icons.credit_card_outlined),
  ];

  static const List<SelectorOption> ratios = [
    SelectorOption(value: '1:1', label: '1:1 Square'),
    SelectorOption(value: '16:9', label: '16:9 Wide'),
    SelectorOption(value: '9:16', label: '9:16 Portrait'),
    SelectorOption(value: '4:3', label: '4:3 Classic'),
    SelectorOption(value: 'A4', label: 'A4 Print'),
    SelectorOption(value: 'custom', label: 'Custom'),
  ];

  static const List<SelectorOption> styles = [
    SelectorOption(value: 'minimal', label: 'Minimal'),
    SelectorOption(value: 'bold', label: 'Bold'),
    SelectorOption(value: 'elegant', label: 'Elegant'),
    SelectorOption(value: 'playful', label: 'Playful'),
    SelectorOption(value: 'corporate', label: 'Corporate'),
    SelectorOption(value: 'artistic', label: 'Artistic'),
  ];

  static const List<SelectorOption> languages = [
    SelectorOption(value: 'en', label: 'English'),
    SelectorOption(value: 'ar', label: 'Arabic'),
    SelectorOption(value: 'fr', label: 'French'),
    SelectorOption(value: 'es', label: 'Spanish'),
    SelectorOption(value: 'de', label: 'German'),
    SelectorOption(value: 'zh', label: 'Chinese'),
  ];
}

// ---------------------------------------------------------------------------
// SECTION 6 — GENERATOR SCREEN
// ---------------------------------------------------------------------------

/// GeneratorScreen — PHASE-11 Intent Creation UI
///
/// User defines their design intent (category, ratio, style, language, prompt)
/// and either generates via AI or selects a template.
///
/// All actions route exclusively to [delegate] (EditorController).
/// Holds only ephemeral form state.
class GeneratorScreen extends StatefulWidget {
  const GeneratorScreen({
    super.key,
    required this.delegate,
    this.templates = const [],
    this.categoryOptions = _DefaultOptions.categories,
    this.ratioOptions = _DefaultOptions.ratios,
    this.styleOptions = _DefaultOptions.styles,
    this.languageOptions = _DefaultOptions.languages,
  });

  final GeneratorScreenDelegate delegate;

  /// Read-only template list for the preview carousel. May be empty.
  final List<TemplateViewModel> templates;

  /// Configurable selector options (defaults provided).
  final List<SelectorOption> categoryOptions;
  final List<SelectorOption> ratioOptions;
  final List<SelectorOption> styleOptions;
  final List<SelectorOption> languageOptions;

  @override
  State<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<GeneratorScreen> {
  // Ephemeral UI state — permitted per PHASE-11 State Ownership Rule.
  final TextEditingController _promptController = TextEditingController();
  String? _selectedCategory;
  String? _selectedRatio;
  String? _selectedStyle;
  String? _selectedLanguage;
  bool _isPromptFocused = false;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  // Assembles the current form state into a pure intent payload.
  GeneratorRequest _buildRequest() => GeneratorRequest(
        prompt: _promptController.text,
        category: _selectedCategory,
        ratio: _selectedRatio,
        style: _selectedStyle,
        language: _selectedLanguage,
      );

  void _handleGenerate() {
    widget.delegate.onGenerateDesign(_buildRequest());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _GenColors.background,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;
            return isWide
                ? _WideGeneratorBody(
                    state: this,
                    constraints: constraints,
                  )
                : _NarrowGeneratorBody(state: this);
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _GenColors.surface,
      elevation: 0,
      scrolledUnderElevation: 1,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        color: _GenColors.onSurface,
        onPressed: widget.delegate.onNavigateBack,
        tooltip: 'Back',
      ),
      title: Text(
        'Create Design',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: _GenColors.onSurface,
          fontSize: 18,
        ),
      ),
      centerTitle: false,
    );
  }
}

// ---------------------------------------------------------------------------
// SECTION 7 — RESPONSIVE BODY LAYOUTS
// ---------------------------------------------------------------------------

class _NarrowGeneratorBody extends StatelessWidget {
  const _NarrowGeneratorBody({required this.state});

  final _GeneratorScreenState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(
                child: _FormSection(state: state),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(
                child: _PromptInputSection(state: state),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(
                child: _TemplateSectionHeader(
                  hasTemplates: state.widget.templates.isNotEmpty,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: _TemplateCarousel(
                  templates: state.widget.templates,
                  delegate: state.widget.delegate,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
        _ActionBar(
          onGenerate: state._handleGenerate,
          delegate: state.widget.delegate,
        ),
      ],
    );
  }
}

class _WideGeneratorBody extends StatelessWidget {
  const _WideGeneratorBody({
    required this.state,
    required this.constraints,
  });

  final _GeneratorScreenState state;
  final BoxConstraints constraints;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: form + prompt + actions
        SizedBox(
          width: constraints.maxWidth * 0.5,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      _FormSection(state: state),
                      const SizedBox(height: 20),
                      _PromptInputSection(state: state),
                    ],
                  ),
                ),
              ),
              _ActionBar(
                onGenerate: state._handleGenerate,
                delegate: state.widget.delegate,
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        // Right: template carousel (vertical)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: _TemplateSectionHeader(
                  hasTemplates: state.widget.templates.isNotEmpty,
                ),
              ),
              Expanded(
                child: _TemplateVerticalList(
                  templates: state.widget.templates,
                  delegate: state.widget.delegate,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// SECTION 8 — FORM SECTION (Category · Ratio · Style · Language)
// ---------------------------------------------------------------------------

class _FormSection extends StatelessWidget {
  const _FormSection({required this.state});

  final _GeneratorScreenState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Selector
          _SelectorField(
            label: 'Category',
            hint: 'Select design type',
            icon: Icons.category_outlined,
            options: state.widget.categoryOptions,
            selectedValue: state._selectedCategory,
            onChanged: (val) =>
                state.setState(() => state._selectedCategory = val),
          ),
          const SizedBox(height: 14),
          // Ratio Selector
          _SelectorField(
            label: 'Canvas Ratio',
            hint: 'Select ratio',
            icon: Icons.aspect_ratio_outlined,
            options: state.widget.ratioOptions,
            selectedValue: state._selectedRatio,
            onChanged: (val) =>
                state.setState(() => state._selectedRatio = val),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Style Selector
              Expanded(
                child: _SelectorField(
                  label: 'Style',
                  hint: 'Style',
                  icon: Icons.palette_outlined,
                  options: state.widget.styleOptions,
                  selectedValue: state._selectedStyle,
                  onChanged: (val) =>
                      state.setState(() => state._selectedStyle = val),
                ),
              ),
              const SizedBox(width: 12),
              // Language Selector
              Expanded(
                child: _SelectorField(
                  label: 'Language',
                  hint: 'Language',
                  icon: Icons.language_outlined,
                  options: state.widget.languageOptions,
                  selectedValue: state._selectedLanguage,
                  onChanged: (val) =>
                      state.setState(() => state._selectedLanguage = val),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SECTION 9 — PROMPT INPUT SECTION
// ---------------------------------------------------------------------------

class _PromptInputSection extends StatelessWidget {
  const _PromptInputSection({required this.state});

  final _GeneratorScreenState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Describe your design',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _GenColors.onBackground,
                ),
          ),
          const SizedBox(height: 8),
          Focus(
            onFocusChange: (focused) =>
                state.setState(() => state._isPromptFocused = focused),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: _GenColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: state._isPromptFocused
                      ? _GenColors.primary
                      : _GenColors.divider,
                  width: state._isPromptFocused ? 1.5 : 1,
                ),
                boxShadow: state._isPromptFocused
                    ? [
                        BoxShadow(
                          color: _GenColors.primary.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Stack(
                children: [
                  TextField(
                    controller: state._promptController,
                    maxLines: 4,
                    minLines: 3,
                    style: TextStyle(color: _GenColors.onSurface, fontSize: 14),
                    decoration: InputDecoration(
                      hintText:
                          'e.g. A modern logo for a tech startup with blue and gold colors...',
                      hintStyle: TextStyle(
                          color: _GenColors.onSurfaceSubtle, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.fromLTRB(16, 14, 48, 14),
                    ),
                  ),
                  // Voice Button — UI-only placeholder, no execution
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: _VoiceButton(
                      onPressed: state.widget.delegate.onVoiceInputRequested,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'Voice input coming soon',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _GenColors.onSurfaceSubtle,
                    fontSize: 11,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SECTION 10 — TEMPLATE CAROUSEL (horizontal, mobile)
// ---------------------------------------------------------------------------

class _TemplateSectionHeader extends StatelessWidget {
  const _TemplateSectionHeader({required this.hasTemplates});

  final bool hasTemplates;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          const Icon(Icons.grid_view_rounded, size: 16, color: _GenColors.primary),
          const SizedBox(width: 6),
          Text(
            'Template Preview',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _GenColors.onBackground,
                ),
          ),
          if (!hasTemplates) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _GenColors.divider,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'No templates',
                style: TextStyle(
                  fontSize: 10,
                  color: _GenColors.onSurfaceSubtle,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TemplateCarousel extends StatelessWidget {
  const _TemplateCarousel({
    required this.templates,
    required this.delegate,
  });

  final List<TemplateViewModel> templates;
  final GeneratorScreenDelegate delegate;

  @override
  Widget build(BuildContext context) {
    if (templates.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: _EmptyTemplatesPlaceholder(),
      );
    }

    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: templates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _TemplateCard(
          template: templates[index],
          onTap: () => delegate.onUseTemplate(templates[index].templateId),
        ),
      ),
    );
  }
}

/// Vertical list for the wide layout right panel.
class _TemplateVerticalList extends StatelessWidget {
  const _TemplateVerticalList({
    required this.templates,
    required this.delegate,
  });

  final List<TemplateViewModel> templates;
  final GeneratorScreenDelegate delegate;

  @override
  Widget build(BuildContext context) {
    if (templates.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: _EmptyTemplatesPlaceholder(),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: templates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _TemplateCard(
        template: templates[index],
        onTap: () => delegate.onUseTemplate(templates[index].templateId),
        isVertical: true,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SECTION 11 — ACTION BAR
// ---------------------------------------------------------------------------

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.onGenerate,
    required this.delegate,
  });

  final VoidCallback onGenerate;
  final GeneratorScreenDelegate delegate;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _GenColors.surface,
        border: Border(top: BorderSide(color: _GenColors.divider)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Row(
        children: [
          // Use Template Button
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _GenColors.primary,
                side: const BorderSide(color: _GenColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                // Routes intent to EditorController to pick/browse templates
                delegate.onUseTemplate('browse');
              },
              icon: const Icon(Icons.grid_view_outlined, size: 18),
              label: const Text(
                'Use Template',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Generate Button
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _GenColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onGenerate,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text(
                'Generate Design',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SECTION 12 — SHARED PRIVATE WIDGETS
// ---------------------------------------------------------------------------

/// Dropdown selector field used for Category, Ratio, Style, Language.
class _SelectorField extends StatelessWidget {
  const _SelectorField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final IconData icon;
  final List<SelectorOption> options;
  final String? selectedValue;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: _GenColors.onBackground,
              ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: selectedValue,
          hint: Text(
            hint,
            style: TextStyle(color: _GenColors.onSurfaceSubtle, fontSize: 14),
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: _GenColors.onSurfaceSubtle),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: _GenColors.primary),
            filled: true,
            fillColor: _GenColors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _GenColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _GenColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: _GenColors.primary, width: 1.5),
            ),
          ),
          items: options
              .map((o) => DropdownMenuItem<String>(
                    value: o.value,
                    child: Row(
                      children: [
                        if (o.icon != null) ...[
                          Icon(o.icon, size: 15,
                              color: _GenColors.onSurfaceSubtle),
                          const SizedBox(width: 8),
                        ],
                        Text(o.label,
                            style: TextStyle(
                                fontSize: 14, color: _GenColors.onSurface)),
                      ],
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
          dropdownColor: _GenColors.surface,
        ),
      ],
    );
  }
}

/// Voice Button — UI-only placeholder. No execution. No engine access.
class _VoiceButton extends StatelessWidget {
  const _VoiceButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Voice input (coming soon)',
      child: Material(
        color: _GenColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(
              Icons.mic_outlined,
              size: 18,
              color: _GenColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Template preview card.
class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.onTap,
    this.isVertical = false,
  });

  final TemplateViewModel template;
  final VoidCallback onTap;
  final bool isVertical;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isVertical ? null : 120,
        decoration: BoxDecoration(
          color: _GenColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _GenColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: isVertical
            ? _VerticalTemplateContent(template: template)
            : _HorizontalTemplateContent(template: template),
      ),
    );
  }
}

class _HorizontalTemplateContent extends StatelessWidget {
  const _HorizontalTemplateContent({required this.template});

  final TemplateViewModel template;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            color: template.previewColor ?? _GenColors.primary.withOpacity(0.12),
            child: Center(
              child: Icon(Icons.image_outlined,
                  size: 28,
                  color: (template.previewColor ?? _GenColors.primary)
                      .withOpacity(0.5)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                template.title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _GenColors.onSurface,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (template.category != null)
                Text(
                  template.category!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _GenColors.onSurfaceSubtle,
                        fontSize: 10,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VerticalTemplateContent extends StatelessWidget {
  const _VerticalTemplateContent({required this.template});

  final TemplateViewModel template;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 72,
          height: 72,
          color: template.previewColor ?? _GenColors.primary.withOpacity(0.12),
          child: Center(
            child: Icon(Icons.image_outlined,
                size: 24,
                color: (template.previewColor ?? _GenColors.primary)
                    .withOpacity(0.5)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  template.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _GenColors.onSurface,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (template.category != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    template.category!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _GenColors.onSurfaceSubtle,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(right: 12),
          child: Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: _GenColors.onSurfaceSubtle),
        ),
      ],
    );
  }
}

class _EmptyTemplatesPlaceholder extends StatelessWidget {
  const _EmptyTemplatesPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: _GenColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _GenColors.divider),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.grid_view_outlined,
                size: 28, color: _GenColors.onSurfaceSubtle),
            const SizedBox(height: 6),
            Text(
              'No templates available',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _GenColors.onSurfaceSubtle,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SECTION 13 — DESIGN TOKENS
// ---------------------------------------------------------------------------

abstract final class _GenColors {
  static const Color primary = Color(0xFF5B4CF5);
  static const Color background = Color(0xFFF6F7FB);
  static const Color surface = Colors.white;
  static const Color onBackground = Color(0xFF1A1A2E);
  static const Color onSurface = Color(0xFF1A1A2E);
  static const Color onSurfaceSubtle = Color(0xFF8A8FAB);
  static const Color divider = Color(0xFFE8EAF0);
}
