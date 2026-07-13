import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_lock_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../lock/pin_entry_sheet.dart';

const _currencies = {
  'CAD': 'Dollar canadien (CAD)',
  'USD': 'Dollar américain (USD)',
  'EUR': 'Euro (EUR)',
  'GBP': 'Livre sterling (GBP)',
  'CHF': 'Franc suisse (CHF)',
  'XOF': 'Franc CFA (XOF)',
};

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: Consumer<UserProfileProvider>(
        builder: (context, profileProvider, _) {
          if (profileProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final profile = profileProvider.profile;
          if (profile == null) {
            return const Center(child: Text('Erreur de chargement du profil'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionHeader('Profil'),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Nom d\'affichage'),
                  subtitle: Text(profile.displayName),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      _showEditNameDialog(context, profile.displayName),
                ),
              ),
              Card(
                margin: const EdgeInsets.only(top: 8),
                child: ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Email'),
                  subtitle: Text(profile.email),
                ),
              ),
              const SizedBox(height: 24),
              _SectionHeader('Devise'),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.attach_money),
                  title: const Text('Devise d\'affichage'),
                  subtitle: Text(
                    _currencies[profile.currency] ?? profile.currency,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showCurrencyPicker(context, profile.currency),
                ),
              ),
              const SizedBox(height: 24),
              _SectionHeader('Sécurité'),
              Consumer<AppLockProvider>(
                builder: (context, appLock, _) {
                  return Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          secondary: const Icon(Icons.lock_outline),
                          title: const Text('Verrouiller l\'application'),
                          subtitle: const Text(
                            'Code ou biométrie à chaque ouverture',
                          ),
                          value: appLock.isEnabled,
                          onChanged: (value) => value
                              ? _enableLock(context)
                              : _disableLock(context),
                        ),
                        if (appLock.isEnabled)
                          ListTile(
                            leading: const Icon(Icons.password),
                            title: const Text('Modifier le code'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _changePin(context),
                          ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              _SectionHeader('Compte'),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Déconnexion',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () => context.read<AuthProvider>().logout(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Modifier le nom'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nom d\'affichage'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              final uid = context.read<AuthProvider>().user!.uid;
              await context.read<UserProfileProvider>().updateDisplayName(
                uid,
                newName,
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context, String currentCurrency) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _currencies.entries.map((entry) {
            return RadioListTile<String>(
              title: Text(entry.value),
              value: entry.key,
              groupValue: currentCurrency,
              onChanged: (value) async {
                if (value == null) return;
                final uid = context.read<AuthProvider>().user!.uid;
                await context.read<UserProfileProvider>().updateCurrency(
                  uid,
                  value,
                );
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _enableLock(BuildContext context) async {
    final pin1 = await showPinEntrySheet(context, title: 'Crée un code');
    if (pin1 == null || !context.mounted) return;

    final pin2 = await showPinEntrySheet(context, title: 'Confirme le code');
    if (pin2 == null || !context.mounted) return;

    if (pin1 != pin2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Les codes ne correspondent pas')),
      );
      return;
    }

    await context.read<AppLockProvider>().setupPin(pin1);
  }

  Future<void> _disableLock(BuildContext context) async {
    final pin = await showPinEntrySheet(
      context,
      title: 'Entre ton code pour désactiver',
    );
    if (pin == null || !context.mounted) return;

    final ok = await context.read<AppLockProvider>().disable(pin);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Code incorrect')));
    }
  }

  Future<void> _changePin(BuildContext context) async {
    final currentPin = await showPinEntrySheet(context, title: 'Code actuel');
    if (currentPin == null || !context.mounted) return;

    final newPin1 = await showPinEntrySheet(context, title: 'Nouveau code');
    if (newPin1 == null || !context.mounted) return;

    final newPin2 = await showPinEntrySheet(
      context,
      title: 'Confirme le nouveau code',
    );
    if (newPin2 == null || !context.mounted) return;

    if (newPin1 != newPin2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Les codes ne correspondent pas')),
      );
      return;
    }

    final ok = await context.read<AppLockProvider>().changePin(
      currentPin,
      newPin1,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Code modifié' : 'Code actuel incorrect')),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
