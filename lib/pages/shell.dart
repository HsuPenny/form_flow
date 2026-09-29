import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'create_form_page.dart';
import 'fill_form_page.dart';
import 'overview_page.dart';
import 'settings_page.dart';
import 'tracking_page.dart';

enum AppSection { overview, tracking, settings }

extension on AppSection {
  String get label => switch (this) {
    AppSection.overview => '表單總覽',
    AppSection.tracking => '回覆追蹤',
    AppSection.settings => '個人設定',
  };

  BrandGlyph get icon => switch (this) {
    AppSection.overview => BrandGlyph.forms,
    AppSection.tracking => BrandGlyph.tracking,
    AppSection.settings => BrandGlyph.profile,
  };
}

/// Lets pages navigate inside the shell (keeping the sidebar / bottom bar).
class ShellNav extends InheritedWidget {
  const ShellNav({super.key, required this.state, required super.child});

  final AppShellState state;

  static AppShellState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellNav>()!.state;

  @override
  bool updateShouldNotify(ShellNav oldWidget) => false;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  AppSection _section = AppSection.overview;
  Widget? _subPage;

  void goTo(AppSection section) => setState(() {
    _section = section;
    _subPage = null;
  });

  void openForm(FormItem form) => setState(() {
    _subPage = FillFormPage(form: form, key: ValueKey(form.id));
  });

  void openCreate() => setState(() {
    _subPage = const CreateFormPage(key: ValueKey('create'));
  });

  void openEdit(FormItem draft) => setState(() {
    _subPage = CreateFormPage(draft: draft, key: ValueKey('edit-${draft.id}'));
  });

  void closeSubPage() => setState(() {
    _subPage = null;
  });

  List<AppSection> _sections(AppState app) => app.isAdmin
      ? AppSection.values
      : [AppSection.overview, AppSection.settings];

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final sections = _sections(app);
    if (!sections.contains(_section)) _section = AppSection.overview;

    final content =
        _subPage ??
        switch (_section) {
          AppSection.overview => const OverviewPage(),
          AppSection.tracking => const TrackingPage(),
          AppSection.settings => const SettingsPage(),
        };

    final wide = isWide(context);
    // Switch instantly: a cross-fade makes both pages half-transparent
    // mid-way, which reads as a color flash.
    final body = KeyedSubtree(
      key: ValueKey('${_section.name}-${_subPage?.key}'),
      child: content,
    );

    return ShellNav(
      state: this,
      child: PopScope(
        canPop: _subPage == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) closeSubPage();
        },
        child: Scaffold(
          extendBody: true,
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [AppColors.shellTint, AppColors.background],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: wide
                  ? Row(
                      children: [
                        _Sidebar(
                          sections: sections,
                          current: _section,
                          onSelect: goTo,
                        ),
                        Expanded(child: body),
                      ],
                    )
                  : body,
            ),
          ),
          // On wide screens the overview header shows this action instead.
          floatingActionButton:
              !wide &&
                  app.isAdmin &&
                  _subPage == null &&
                  _section == AppSection.overview
              ? FloatingActionButton.extended(
                  onPressed: openCreate,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('建立表單'),
                )
              : null,
          // Create and fill have their own fixed action bar at the bottom.
          bottomNavigationBar:
              wide || _subPage is CreateFormPage || _subPage is FillFormPage
              ? null
              : _BottomBar(
                  sections: sections,
                  current: _section,
                  onSelect: goTo,
                ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.sections,
    required this.current,
    required this.onSelect,
  });

  final List<AppSection> sections;
  final AppSection current;
  final ValueChanged<AppSection> onSelect;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Container(
      width: 248,
      decoration: const BoxDecoration(
        color: AppColors.sidebar,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandHeader(),
          const SizedBox(height: 32),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow('Workspace'),
                SizedBox(height: 6),
                Text(
                  'Northstar Studio',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          for (final s in sections) _navItem(s),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Avatar(app.initials),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.displayName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      app.role!.label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: app.logout,
            icon: const Icon(Icons.logout, size: 16),
            label: const Text('登出'),
          ),
        ],
      ),
    );
  }

  Widget _navItem(AppSection s) {
    final selected = s == current;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppColors.muted : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: () => onSelect(s),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border(
                left: BorderSide(
                  color: selected ? AppColors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Row(
              children: [
                BrandIcon(
                  s.icon,
                  size: 18,
                  color: selected
                      ? AppColors.primaryDeep
                      : AppColors.foreground,
                  fill: selected ? 1 : 0,
                ),
                const SizedBox(width: 10),
                Text(
                  s.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Floating bottom navigation used on narrow screens. A single orange
/// indicator slides to the active item; no ripple, so no gray flash.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.sections,
    required this.current,
    required this.onSelect,
  });

  final List<AppSection> sections;
  final AppSection current;
  final ValueChanged<AppSection> onSelect;

  static const _duration = Duration(milliseconds: 220);
  static const _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final n = sections.length;
    final index = sections.indexOf(current);
    final base = DefaultTextStyle.of(context).style;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.foreground.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedAlign(
                duration: _duration,
                curve: _curve,
                alignment: Alignment(n == 1 ? 0 : -1 + 2 * index / (n - 1), 0),
                child: FractionallySizedBox(
                  widthFactor: 1 / n,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (final s in sections)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSelect(s),
                      // One 0→1 value drives both the color and the
                      // outline→solid icon, so they change in step.
                      child: TweenAnimationBuilder<double>(
                        duration: _duration,
                        curve: _curve,
                        tween: Tween(end: s == current ? 1 : 0),
                        builder: (context, t, _) {
                          final color = Color.lerp(
                            AppColors.foreground,
                            AppColors.primaryDeep,
                            t,
                          );
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                BrandIcon(
                                  s.icon,
                                  size: 20,
                                  color: color,
                                  fill: t,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  s.label,
                                  style: base.copyWith(
                                    fontSize: 11,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
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
