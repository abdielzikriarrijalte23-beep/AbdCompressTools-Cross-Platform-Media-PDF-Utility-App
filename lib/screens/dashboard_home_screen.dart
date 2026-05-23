import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../widgets/theme_switcher.dart';
import 'compress_pdf_screen.dart';
import 'compress_video_screen.dart';
import 'convert_from_pdf_screen.dart';
import 'convert_to_pdf_screen.dart';
import 'edit_pdf_screen.dart';
import 'history_screen.dart';
import 'merge_pdf_screen.dart';
import 'pdf_from_images_screen.dart';
import 'pdf_viewer_screen.dart';
import 'repair_pdf_screen.dart';
import 'sign_pdf_screen_refactored.dart';
import 'split_pdf_screen.dart';

class DashboardHomeScreen extends StatelessWidget {
  const DashboardHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 720;
    final background = isDark
        ? const Color(0xFF050506)
        : const Color(0xFFF4F5F7);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 32 : 20,
                isDesktop ? 28 : 18,
                isDesktop ? 32 : 20,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: _HomeHeader(isDark: isDark, isDesktop: isDesktop),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 32 : 20,
                22,
                isDesktop ? 32 : 20,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: _PrimaryAction(
                  onTap: () => _open(context, const PdfViewerScreen()),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 32 : 20,
                24,
                isDesktop ? 32 : 20,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: _QuickActions(isDark: isDark),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 32 : 20,
                28,
                isDesktop ? 32 : 20,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: _SectionTitle(
                  title: 'Tools',
                  actionLabel: 'v${AppConfig.appVersion}',
                  isDark: isDark,
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 32 : 20,
                12,
                isDesktop ? 32 : 20,
                24,
              ),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = _features[index];
                  return _ToolTile(
                    item: item,
                    isDark: isDark,
                    onTap: () => _open(context, item.screen),
                  );
                }, childCount: _features.length),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isDesktop ? 4 : 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: isDesktop ? 1.35 : 1.02,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _HomeHeader extends StatelessWidget {
  final bool isDark;
  final bool isDesktop;

  const _HomeHeader({required this.isDark, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : const Color(0xFF111113);
    final muted = isDark ? const Color(0xFF9B9CA3) : const Color(0xFF70727A);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C1C20) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _softShadow(isDark),
                    ),
                    padding: const EdgeInsets.all(7),
                    child: Image.asset(
                      'asset/app_img/ABdSukaPDF.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    AppConfig.appTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Your PDF workspace',
                style: TextStyle(
                  fontSize: isDesktop ? 44 : 34,
                  height: 1.02,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'View, compress, convert, edit, merge and sign files offline.',
                style: TextStyle(
                  fontSize: isDesktop ? 16 : 14,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const ThemeSwitcher(compact: true),
      ],
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  final VoidCallback onTap;

  const _PrimaryAction({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            color: AppConfig.primaryColor,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppConfig.primaryColor.withValues(alpha: 0.28),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  height: 54,
                  width: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Open PDF',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Pick a document and start working',
                        style: TextStyle(
                          color: Color(0xD9FFFFFF),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final bool isDark;

  const _QuickActions({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionItem(
        title: 'Video',
        icon: Icons.movie_filter_rounded,
        color: const Color(0xFFFF375F),
        screen: const CompressVideoScreen(),
      ),
      _ActionItem(
        title: 'PDF',
        icon: Icons.compress_rounded,
        color: const Color(0xFFFF8A00),
        screen: const CompressPdfScreen(),
      ),
      _ActionItem(
        title: 'Convert',
        icon: Icons.sync_alt_rounded,
        color: const Color(0xFF0A84FF),
        screen: const ConvertFromPdfScreen(),
      ),
      _ActionItem(
        title: 'Edit',
        icon: Icons.edit_rounded,
        color: const Color(0xFFAF52DE),
        screen: const EditPdfScreen(),
      ),
      _ActionItem(
        title: 'History',
        icon: Icons.history_rounded,
        color: const Color(0xFF34C759),
        screen: const HistoryScreen(),
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          Expanded(
            child: _QuickActionButton(
              item: actions[i],
              isDark: isDark,
              onTap: () => DashboardHomeScreen._open(context, actions[i].screen),
            ),
          ),
          if (i != actions.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final _ActionItem item;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.item,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF17181C) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: _softShadow(isDark),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, color: item.color, size: 25),
              const SizedBox(height: 8),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF18191D),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String actionLabel;
  final bool isDark;

  const _SectionTitle({
    required this.title,
    required this.actionLabel,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF111113),
            ),
          ),
        ),
        Text(
          actionLabel,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isDark ? const Color(0xFF8D8F98) : const Color(0xFF72747D),
          ),
        ),
      ],
    );
  }
}

class _ToolTile extends StatelessWidget {
  final _FeatureItem item;
  final bool isDark;
  final VoidCallback onTap;

  const _ToolTile({
    required this.item,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF17181C) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: _softShadow(isDark),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: isDark ? 0.18 : 0.12),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(item.icon, color: item.color, size: 25),
                ),
                const Spacer(),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF15161A),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFF9B9CA3)
                        : const Color(0xFF73757E),
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

class _ActionItem {
  final String title;
  final IconData icon;
  final Color color;
  final Widget screen;

  const _ActionItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.screen,
  });
}

class _FeatureItem extends _ActionItem {
  final String description;

  const _FeatureItem({
    required super.title,
    required this.description,
    required super.icon,
    required super.color,
    required super.screen,
  });
}

final List<_FeatureItem> _features = [
  _FeatureItem(
    title: 'MPEG Video',
    description: 'Compression simulator',
    icon: Icons.movie_filter_rounded,
    color: const Color(0xFFFF375F),
    screen: const CompressVideoScreen(),
  ),
  _FeatureItem(
    title: 'Merge PDF',
    description: 'Combine files',
    icon: Icons.call_merge_rounded,
    color: const Color(0xFF0A84FF),
    screen: const MergePdfScreen(),
  ),
  _FeatureItem(
    title: 'Split PDF',
    description: 'Extract pages',
    icon: Icons.content_cut_rounded,
    color: const Color(0xFFFF375F),
    screen: const SplitPdfScreen(),
  ),
  _FeatureItem(
    title: 'To PDF',
    description: 'Create documents',
    icon: Icons.file_present_rounded,
    color: const Color(0xFF30D158),
    screen: const ConvertToPdfScreen(),
  ),
  _FeatureItem(
    title: 'Images',
    description: 'Photo to PDF',
    icon: Icons.image_rounded,
    color: const Color(0xFFFF9F0A),
    screen: const PdfFromImagesScreen(),
  ),
  _FeatureItem(
    title: 'From PDF',
    description: 'Export formats',
    icon: Icons.ios_share_rounded,
    color: const Color(0xFF64D2FF),
    screen: const ConvertFromPdfScreen(),
  ),
  _FeatureItem(
    title: 'Sign PDF',
    description: 'Add signatures',
    icon: Icons.draw_rounded,
    color: const Color(0xFFBF5AF2),
    screen: const SignPdfScreenRefactored(),
  ),
  _FeatureItem(
    title: 'Repair PDF',
    description: 'Fix files',
    icon: Icons.auto_fix_high_rounded,
    color: const Color(0xFFFF453A),
    screen: const RepairPdfScreen(),
  ),
  _FeatureItem(
    title: 'History',
    description: 'Recent files',
    icon: Icons.history_rounded,
    color: const Color(0xFF32D74B),
    screen: const HistoryScreen(),
  ),
];

List<BoxShadow> _softShadow(bool isDark) {
  if (isDark) return const [];
  return [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 22,
      offset: const Offset(0, 10),
    ),
  ];
}
