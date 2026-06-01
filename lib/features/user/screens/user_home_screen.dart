import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../state/providers/auth_provider.dart';
import 'user_order_tab.dart';
import 'user_history_tab.dart';
import 'user_profile_tab.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  int _currentIndex = 0;
  int _activeOrderCount = 0;

  final _supabase = Supabase.instance.client;

  final List<Widget> _tabs = const [
    UserOrderTab(),
    UserHistoryTab(),
    UserProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBadges());
  }

  Future<void> _loadBadges() async {
    try {
      final user = context.read<AuthProvider>().currentUser;
      if (user == null) return;

      final res = await _supabase
          .from('orders')
          .select('id')
          .eq('user_id', user.id)
          .inFilter('status', [
            'menunggu',
            'diterima',
            'menuju_lokasi',
            'dalam_perjalanan',
            'sampai_tujuan',
          ]);

      if (mounted) {
        setState(() => _activeOrderCount = (res as List).length);
      }
    } catch (_) {
      // Badge hanya pemanis UI; jangan ganggu halaman kalau query gagal.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.inventory_2_outlined,
                  selectedIcon: Icons.inventory_2_rounded,
                  label: 'Pesan',
                  selected: _currentIndex == 0,
                  badgeCount: _activeOrderCount,
                  onTap: () {
                    setState(() => _currentIndex = 0);
                    _loadBadges();
                  },
                ),
                _NavItem(
                  icon: Icons.receipt_long_outlined,
                  selectedIcon: Icons.receipt_long_rounded,
                  label: 'Order',
                  selected: _currentIndex == 1,
                  badgeCount: _activeOrderCount,
                  onTap: () {
                    setState(() => _currentIndex = 1);
                    _loadBadges();
                  },
                ),
                _NavItem(
                  icon: Icons.person_outline_rounded,
                  selectedIcon: Icons.person_rounded,
                  label: 'Profil',
                  selected: _currentIndex == 2,
                  onTap: () => setState(() => _currentIndex = 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    this.badgeCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: selected ? 58 : 46,
                  height: selected ? 58 : 46,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.grey200,
                    borderRadius: BorderRadius.circular(selected ? 16 : 10),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.22),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ]
                        : [],
                  ),
                  child: Icon(
                    selected ? selectedIcon : icon,
                    color: selected ? AppColors.white : AppColors.grey500,
                    size: selected ? 30 : 24,
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -3,
                    top: -5,
                    child: _Badge(count: badgeCount),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.grey400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(AppDimens.radiusRound),
        border: Border.all(color: AppColors.white, width: 1.5),
      ),
      child: Text(
        '+${count > 9 ? '9' : count}',
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
