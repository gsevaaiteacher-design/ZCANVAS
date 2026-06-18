// screens/home_screen.dart
//
// PHASE-11 — Home Screen (Home Dashboard UI)
//
// ===========================================================================
// OWNERSHIP CONTRACT
// ===========================================================================
//
// WHAT THIS FILE CAN DO:
//   • Build the Home Dashboard widget tree (pure visual composition)
//   • Display read-only data passed in via constructor
//   • Capture user input and forward intent to EditorController
//   • Hold ephemeral UI state (bottom nav index, scroll position)
//   • Provide responsive layout via LayoutBuilder
//
// WHAT THIS FILE CANNOT DO:
//   ❌ Call any engine directly
//   ❌ Access Canvas
//   ❌ Modify layers, history, or storage
//   ❌ Execute AI, export, render, or sync logic
//   ❌ Own system state (layers, design data, canvas state)
//   ❌ Decide business or navigation flow independently
//
// ALL INTERACTION FLOWS THROUGH:
//   EditorController (via HomeScreenDelegate) — the only gate.
// ===========================================================================

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// SECTION 1 — EDITORCONTROLLER DELEGATE INTERFACE
//
// HomeScreen talks to EditorController exclusively through this interface.
// EditorController implements HomeScreenDelegate; HomeScreen never imports
// a concrete engine or controller class.
// ---------------------------------------------------------------------------

/// Intent contract that EditorController must implement to receive all
/// interaction signals from HomeScreen.
///
/// HomeScreen is prohibited from making decisions. It forwards intent only.
abstract interface class HomeScreenDelegate {
  // Navigation intents
  void onNavigateToNewDesign();
  void onNavigateToAICreate();
  void onNavigateToTemplates();
  void onNavigateToProject(String projectId);
  void onNavigateToSettings();
  void onNavigateToProfile();

  // Bottom nav intent
  void onBottomNavSelected(int index);
}

// ---------------------------------------------------------------------------
// SECTION 2 — READ-ONLY VIEW MODELS
//
// Plain data holders. No logic, no mutation. Passed in from outside.
// ---------------------------------------------------------------------------

/// Read-only display model for a recent project card.
final class ProjectViewModel {
  const ProjectViewModel({
    required this.projectId,
    required this.title,
    required this.lastEditedLabel,
    this.thumbnailColor,
  });

  final String projectId;
  final String title;
  final String lastEditedLabel;
  final Color? thumbnailColor;
}

/// Read-only display model for the rewards panel.
final class RewardsViewModel {
  const RewardsViewModel({
    required this.coins,
    required this.badgeCount,
    required this.progressPercent,
    this.progressLabel = '',
  });

  final int coins;
  final int badgeCount;

  /// 0.0 – 1.0
  final double progressPercent;
  final String progressLabel;
}

// ---------------------------------------------------------------------------
// SECTION 3 — HOME SCREEN
// ---------------------------------------------------------------------------

/// HomeScreen — PHASE-11 Home Dashboard UI
///
/// Pure visual shell. Composes the dashboard widget tree and routes all
/// user interaction to [delegate] (EditorController).
///
/// Holds only ephemeral UI state: bottom navigation index.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.delegate,
    this.recentProjects = const [],
    this.rewards = const RewardsViewModel(
      coins: 0,
      badgeCount: 0,
      progressPercent: 0,
    ),
  });

  /// The EditorController that handles all intents from this screen.
  final HomeScreenDelegate delegate;

  /// Read-only list of recent projects to display. May be empty.
  final List<ProjectViewModel> recentProjects;

  /// Read-only rewards data to display.
  final RewardsViewModel rewards;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Ephemeral UI state only — permitted per PHASE-11 State Ownership Rule.
  int _bottomNavIndex = 0;

  void _handleBottomNavTap(int index) {
    setState(() => _bottomNavIndex = index);
    widget.delegate.onBottomNavSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AppColors.background,
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;
            return isWide
                ? _WideHomeBody(
                    delegate: widget.delegate,
                    recentProjects: widget.recentProjects,
                    rewards: widget.rewards,
                  )
                : _NarrowHomeBody(
                    delegate: widget.delegate,
                    recentProjects: widget.recentProjects,
                    rewards: widget.rewards,
                  );
          },
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  // -------------------------------------------------------------------------
  // AppBar
  // -------------------------------------------------------------------------

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: _AppColors.surface,
      elevation: 0,
      scrolledUnderElevation: 1,
      title: const _AppBarLogo(),
      actions: [
        // Future-ready: Voice input placeholder slot
        const _FutureReadySlot(label: 'Voice'),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          color: _AppColors.onSurface,
          tooltip: 'Settings',
          onPressed: widget.delegate.onNavigateToSettings,
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: widget.delegate.onNavigateToProfile,
            child: const CircleAvatar(
              radius: 17,
              backgroundColor: _AppColors.primary,
              child: Icon(Icons.person_outline, size: 18, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Bottom Navigation Bar
  // -------------------------------------------------------------------------

  Widget _buildBottomNavBar() {
    return NavigationBar(
      backgroundColor: _AppColors.surface,
      selectedIndex: _bottomNavIndex,
      onDestinationSelected: _handleBottomNavTap,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.grid_view_outlined),
          selectedIcon: Icon(Icons.grid_view),
          label: 'Projects',
        ),
        NavigationDestination(
          icon: Icon(Icons.add_circle_outline),
          selectedIcon: Icon(Icons.add_circle),
          label: 'Create',
        ),
        NavigationDestination(
          icon: Icon(Icons.star_outline),
          selectedIcon: Icon(Icons.star),
          label: 'Rewards',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// SECTION 4 — RESPONSIVE BODY LAYOUTS
// ---------------------------------------------------------------------------

/// Narrow (mobile) layout: single scrollable column.
class _NarrowHomeBody extends StatelessWidget {
  const _NarrowHomeBody({
    required this.delegate,
    required this.recentProjects,
    required this.rewards,
  });

  final HomeScreenDelegate delegate;
  final List<ProjectViewModel> recentProjects;
  final RewardsViewModel rewards;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        SliverToBoxAdapter(
          child: _HeroActionsSection(delegate: delegate),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
        SliverToBoxAdapter(
          child: _SectionHeader(title: 'Recent Projects'),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        _RecentProjectsGrid(
          projects: recentProjects,
          delegate: delegate,
          crossAxisCount: 2,
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
        SliverToBoxAdapter(
          child: _RewardsPanel(rewards: rewards),
        ),
        // Future-ready: Floating Robot Assistant slot
        const SliverToBoxAdapter(child: _FutureReadyBanner()),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

/// Wide (tablet / desktop) layout: hero actions full-width, two-column below.
class _WideHomeBody extends StatelessWidget {
  const _WideHomeBody({
    required this.delegate,
    required this.recentProjects,
    required this.rewards,
  });

  final HomeScreenDelegate delegate;
  final List<ProjectViewModel> recentProjects;
  final RewardsViewModel rewards;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
        SliverToBoxAdapter(
          child: _HeroActionsSection(delegate: delegate),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
        SliverToBoxAdapter(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: 24),
              // Left: recent projects
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(title: 'Recent Projects'),
                    const SizedBox(height: 12),
                    _RecentProjectsInlineGrid(
                      projects: recentProjects,
                      delegate: delegate,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Right: rewards
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(title: 'Rewards'),
                    const SizedBox(height: 12),
                    _RewardsPanel(rewards: rewards),
                  ],
                ),
              ),
              const SizedBox(width: 24),
            ],
          ),
        ),
        const SliverToBoxAdapter(child: _FutureReadyBanner()),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// SECTION 5 — TOP SECTION: HERO ACTIONS
// ---------------------------------------------------------------------------

/// Three primary action buttons: New Design, AI Create, Templates.
class _HeroActionsSection extends StatelessWidget {
  const _HeroActionsSection({required this.delegate});

  final HomeScreenDelegate delegate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What will you create today?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _AppColors.onBackground,
                ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _PrimaryActionButton(
                  icon: Icons.add_rounded,
                  label: 'New Design',
                  onPressed: delegate.onNavigateToNewDesign,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PrimaryActionButton(
                  icon: Icons.auto_awesome_rounded,
                  label: 'AI Create',
                  color: _AppColors.accent,
                  onPressed: delegate.onNavigateToAICreate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SecondaryActionButton(
                  icon: Icons.grid_view_rounded,
                  label: 'Templates',
                  onPressed: delegate.onNavigateToTemplates,
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
// SECTION 6 — RECENT PROJECTS GRID
// ---------------------------------------------------------------------------

class _RecentProjectsGrid extends StatelessWidget {
  const _RecentProjectsGrid({
    required this.projects,
    required this.delegate,
    this.crossAxisCount = 2,
  });

  final List<ProjectViewModel> projects;
  final HomeScreenDelegate delegate;
  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) {
      return const SliverToBoxAdapter(child: _EmptyProjectsPlaceholder());
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _ProjectCard(
            project: projects[index],
            onTap: () => delegate.onNavigateToProject(projects[index].projectId),
          ),
          childCount: projects.length,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
        ),
      ),
    );
  }
}

/// Inline (non-sliver) grid for the wide layout.
class _RecentProjectsInlineGrid extends StatelessWidget {
  const _RecentProjectsInlineGrid({
    required this.projects,
    required this.delegate,
  });

  final List<ProjectViewModel> projects;
  final HomeScreenDelegate delegate;

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) {
      return const _EmptyProjectsPlaceholder();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: projects.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemBuilder: (context, index) => _ProjectCard(
        project: projects[index],
        onTap: () => delegate.onNavigateToProject(projects[index].projectId),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SECTION 7 — REWARDS PANEL
// ---------------------------------------------------------------------------

class _RewardsPanel extends StatelessWidget {
  const _RewardsPanel({required this.rewards});

  final RewardsViewModel rewards;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: _AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _AppColors.divider),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events_rounded,
                    color: _AppColors.gold, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Your Rewards',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _AppColors.onSurface,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Coins
                Expanded(
                  child: _RewardStatTile(
                    icon: Icons.monetization_on_rounded,
                    iconColor: _AppColors.gold,
                    label: 'Coins',
                    value: rewards.coins.toString(),
                  ),
                ),
                // Badges
                Expanded(
                  child: _RewardStatTile(
                    icon: Icons.military_tech_rounded,
                    iconColor: _AppColors.accent,
                    label: 'Badges',
                    value: rewards.badgeCount.toString(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      rewards.progressLabel.isNotEmpty
                          ? rewards.progressLabel
                          : 'Level Progress',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _AppColors.onSurfaceSubtle,
                          ),
                    ),
                    Text(
                      '${(rewards.progressPercent * 100).toInt()}%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: rewards.progressPercent.clamp(0.0, 1.0),
                    backgroundColor: _AppColors.divider,
                    color: _AppColors.primary,
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SECTION 8 — SHARED PRIVATE WIDGETS
// ---------------------------------------------------------------------------

class _AppBarLogo extends StatelessWidget {
  const _AppBarLogo();

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Z-CANVAS ',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: _AppColors.primary,
                  letterSpacing: 0.5,
                ),
          ),
          TextSpan(
            text: 'by Zynquar',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _AppColors.onSurfaceSubtle,
                  fontWeight: FontWeight.w400,
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: _AppColors.onBackground,
            ),
      ),
    );
  }
}

/// Primary call-to-action button.
class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final buttonColor = color ?? _AppColors.primary;
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: buttonColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size.fromHeight(52),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Secondary (outlined) action button.
class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: _AppColors.primary,
        side: const BorderSide(color: _AppColors.primary),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size.fromHeight(52),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Project card showing thumbnail and metadata.
class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project, required this.onTap});

  final ProjectViewModel project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _AppColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail area
            Expanded(
              child: Container(
                color: project.thumbnailColor ?? _AppColors.primary.withOpacity(0.15),
                child: Center(
                  child: Icon(
                    Icons.image_outlined,
                    size: 32,
                    color: project.thumbnailColor != null
                        ? project.thumbnailColor!.withOpacity(0.6)
                        : _AppColors.primary.withOpacity(0.4),
                  ),
                ),
              ),
            ),
            // Card footer
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _AppColors.onSurface,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    project.lastEditedLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _AppColors.onSurfaceSubtle,
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

/// Reward stat tile used inside RewardsPanel.
class _RewardStatTile extends StatelessWidget {
  const _RewardStatTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _AppColors.onSurface,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _AppColors.onSurfaceSubtle,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Shown when there are no recent projects.
class _EmptyProjectsPlaceholder extends StatelessWidget {
  const _EmptyProjectsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: _AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _AppColors.divider, style: BorderStyle.solid),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_open_outlined,
                  size: 32, color: _AppColors.onSurfaceSubtle),
              const SizedBox(height: 8),
              Text(
                'No recent projects yet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _AppColors.onSurfaceSubtle,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// UI-only placeholder for future features (Voice, Robot, etc.).
/// Contains no logic — visual slot reservation only.
class _FutureReadySlot extends StatelessWidget {
  const _FutureReadySlot({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    // Invisible slot — rendered only when feature is activated.
    // Reserves space in the widget tree for future voice / robot hooks.
    return const SizedBox.shrink();
  }
}

/// Advisory banner shown at the bottom of the scroll for future features.
class _FutureReadyBanner extends StatelessWidget {
  const _FutureReadyBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _AppColors.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _AppColors.primary.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            const Icon(Icons.rocket_launch_outlined,
                color: _AppColors.primary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Voice Assistant · AI Copilot · Robot Assistant — coming soon',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _AppColors.primary,
                      fontWeight: FontWeight.w500,
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
// SECTION 9 — DESIGN TOKENS
// ---------------------------------------------------------------------------

/// App-level colour tokens used exclusively within this file.
/// No business meaning — purely visual.
abstract final class _AppColors {
  static const Color primary = Color(0xFF5B4CF5);
  static const Color accent = Color(0xFF00BFA6);
  static const Color gold = Color(0xFFFFC107);
  static const Color background = Color(0xFFF6F7FB);
  static const Color surface = Colors.white;
  static const Color onBackground = Color(0xFF1A1A2E);
  static const Color onSurface = Color(0xFF1A1A2E);
  static const Color onSurfaceSubtle = Color(0xFF8A8FAB);
  static const Color divider = Color(0xFFE8EAF0);
}
