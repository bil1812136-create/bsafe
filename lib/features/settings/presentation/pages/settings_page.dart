import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bsafe_app/core/providers/language_provider.dart';
import 'package:bsafe_app/core/theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageNotifierProvider);
    final isEn = lang.isEnglish;

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.t('settings')),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        children: [
          // ── User card ──────────────────────────────────────────────
          _UserCard(isEn: isEn),
          const SizedBox(height: 8),

          // ── General section ────────────────────────────────────────
          _SectionHeader(title: isEn ? 'General' : '一般'),
          _SettingsTile(
            icon: Icons.language_rounded,
            iconColor: Colors.blue,
            title: lang.t('language'),
            trailing: Text(
              isEn ? lang.t('english') : lang.t('chinese'),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
            onTap: () => _showLanguagePicker(context, ref),
          ),
          const _Divider(),

          // ── App section ────────────────────────────────────────────
          _SectionHeader(title: isEn ? 'App' : '應用'),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            iconColor: Colors.teal,
            title: isEn ? 'Version' : '版本',
            trailing: Text(
              '1.0.0',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
            onTap: null,
          ),
          const _Divider(),
          _SettingsTile(
            icon: Icons.shield_outlined,
            iconColor: Colors.deepPurple,
            title: isEn ? 'Privacy Policy' : '隱私政策',
            onTap: () {},
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Consumer(
        builder: (ctx, modalRef, _) {
          final current = modalRef.watch(languageNotifierProvider);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    current.t('language'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  RadioGroup<AppLanguage>(
                    groupValue: current.language,
                    onChanged: (v) {
                      if (v != null) {
                        modalRef
                            .read(languageNotifierProvider.notifier)
                            .setLanguage(v);
                        Navigator.pop(ctx);
                      }
                    },
                    child: Column(
                      children: [
                        RadioListTile<AppLanguage>(
                          value: AppLanguage.zh,
                          title: Text(current.t('chinese')),
                        ),
                        RadioListTile<AppLanguage>(
                          value: AppLanguage.en,
                          title: Text(current.t('english')),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── User card ────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final bool isEn;
  const _UserCard({required this.isEn});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
            child: Icon(Icons.person_rounded,
                size: 34, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEn ? 'Guest User' : '訪客用戶',
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isEn ? 'Inspector' : '檢查員',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade500,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Settings tile ────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    this.iconColor = Colors.blueGrey,
    required this.title,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null) trailing!,
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                color: Colors.grey.shade400, size: 20),
          ],
        ],
      ),
      onTap: onTap,
    );
  }
}

// ── Divider ──────────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 68, endIndent: 16);
  }
}
