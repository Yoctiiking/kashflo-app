import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../providers/currency_provider.dart';

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
                  onTap: () => _showEditNameDialog(context, profile.displayName),
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
                  subtitle: Text(_currencies[profile.currency] ?? profile.currency),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showCurrencyPicker(context, profile.currency),
                ),
              ),
              const SizedBox(height: 24),
              _SectionHeader('Compte'),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
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
              await context.read<UserProfileProvider>().updateDisplayName(uid, newName);
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
                await context.read<UserProfileProvider>().updateCurrency(uid, value);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
            );
          }).toList(),
        ),
      ),
    );
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