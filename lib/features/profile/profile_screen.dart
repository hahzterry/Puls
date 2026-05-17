import 'package:flutter/material.dart';

import '../../app/puls_app_state.dart';
import '../../core/theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    final isDark = appState.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
        children: [
          const _ProfileHeader(),
          const SizedBox(height: 16),
          const _SettingsGroup(
            title: 'Account',
            children: [
              _SettingsRow(
                icon: Icons.verified_user_outlined,
                title: 'Demo mode',
                subtitle: 'Mock account with simulated balances',
              ),
              _SettingsRow(
                icon: Icons.security_rounded,
                title: 'Verification',
                subtitle: 'Not required for this prototype',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SettingsGroup(
            title: 'Preferences',
            children: [
              _SettingsRow(
                icon: isDark
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
                title: 'Theme',
                subtitle: isDark ? 'Premium dark' : 'Clean light',
                trailing: Switch(
                  value: isDark,
                  onChanged: (_) => appState.toggleThemeMode(),
                ),
              ),
              const _SettingsRow(
                icon: Icons.notifications_none_rounded,
                title: 'Alerts',
                subtitle: 'Price moves and deadlines',
              ),
              const _SettingsRow(
                icon: Icons.speed_rounded,
                title: 'Feed speed',
                subtitle: 'Fast swipe discovery',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: PulsColors.amber.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: PulsColors.amber.withValues(alpha: 0.35)),
            ),
            child: const Text(
              'Puls is a UI prototype. It does not support real accounts, deposits, withdrawals, or trades.',
              style: TextStyle(color: PulsColors.amber, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    final tokens = context.puls;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: PulsColors.blue.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: PulsColors.blue.withValues(alpha: 0.45)),
            ),
            child: const Icon(Icons.person_rounded,
                color: PulsColors.blue, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Puls Demo Trader',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  '@puls_demo',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.puls;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.panelSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.puls;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tokens.panel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tokens.border),
            ),
            child: Icon(icon, color: tokens.muted, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          trailing ?? Icon(Icons.chevron_right_rounded, color: tokens.muted),
        ],
      ),
    );
  }
}
