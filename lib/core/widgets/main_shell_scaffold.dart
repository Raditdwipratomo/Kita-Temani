import 'package:flutter/material.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';
import 'package:kitatemani/core/widgets/owl_mascot.dart';

class MainShellScaffold extends StatelessWidget {
  const MainShellScaffold({
    required this.currentIndex,
    required this.onTabSelected,
    required this.onPanicPressed,
    required this.body,
    this.isCounselorMode = false,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onPanicPressed;
  final Widget body;
  final bool isCounselorMode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: body,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.cardWhite,
          border: Border(
            top: BorderSide(color: AppColors.borderHairline, width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SizedBox(
                height: 70,
                child: Row(
                  children: isCounselorMode
                      ? [
                          _NavBarItem(
                            icon: Icons.space_dashboard_outlined,
                            activeIcon: Icons.space_dashboard_rounded,
                            label: 'Dashboard',
                            selected: currentIndex == 0,
                            onTap: () => onTabSelected(0),
                          ),
                          _NavBarItem(
                            icon: Icons.assignment_outlined,
                            activeIcon: Icons.assignment_rounded,
                            label: 'Pantau',
                            selected: currentIndex == 1,
                            onTap: () => onTabSelected(1),
                          ),
                          _NavBarItem(
                            icon: Icons.menu_book_outlined,
                            activeIcon: Icons.menu_book_rounded,
                            label: 'Artikel',
                            selected: currentIndex == 2,
                            onTap: () => onTabSelected(2),
                          ),
                          _NavBarItem(
                            icon: Icons.person_outline_rounded,
                            activeIcon: Icons.person_rounded,
                            label: 'Profil',
                            selected: currentIndex == 3,
                            onTap: () => onTabSelected(3),
                          ),
                        ]
                      : [
                          _NavBarItem(
                            icon: Icons.home_outlined,
                            activeIcon: Icons.home_rounded,
                            label: 'Beranda',
                            selected: currentIndex == 0,
                            onTap: () => onTabSelected(0),
                          ),
                          _NavBarItem(
                            icon: Icons.chat_bubble_outline_rounded,
                            activeIcon: Icons.chat_bubble_rounded,
                            iconBuilder: (color) => OwlGlyphIcon(
                              size: 22,
                              color: color,
                            ),
                            label: 'Curhai',
                            selected: currentIndex == 1,
                            onTap: () => onTabSelected(1),
                          ),
                          Expanded(
                            child: _SosDockButton(onTap: onPanicPressed),
                          ),
                          _NavBarItem(
                            icon: Icons.description_outlined,
                            activeIcon: Icons.description_rounded,
                            label: 'Laporan',
                            selected: currentIndex == 2,
                            onTap: () => onTabSelected(2),
                          ),
                          _NavBarItem(
                            icon: Icons.person_outline_rounded,
                            activeIcon: Icons.person_rounded,
                            label: 'Profil',
                            selected: currentIndex == 3,
                            onTap: () => onTabSelected(3),
                          ),
                        ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SosDockButton extends StatelessWidget {
  const _SosDockButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Darurat',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppColors.panicActiveGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppColors.sosShadow,
              ),
              child: const Icon(
                Icons.emergency_share_outlined,
                color: Colors.white,
                size: 19,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Darurat',
              style: AppTextStyles.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.darurat,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.iconBuilder,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget Function(Color color)? iconBuilder;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.biruTinta : AppColors.inkSlate;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            if (selected)
              Container(
                width: 28,
                height: 2.5,
                decoration: const BoxDecoration(
                  color: AppColors.biruTinta,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(3),
                  ),
                ),
              ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (iconBuilder != null)
                    iconBuilder!(color)
                  else
                    Icon(
                      selected ? activeIcon : icon,
                      size: 22,
                      color: color,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.inter(
                      fontSize: 11.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: color,
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
