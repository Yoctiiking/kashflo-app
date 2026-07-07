import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shared_budgets_provider.dart';

class JoinSharedBudgetDialog extends StatefulWidget {
  const JoinSharedBudgetDialog({super.key});

  @override
  State<JoinSharedBudgetDialog> createState() => _JoinSharedBudgetDialogState();
}

class _JoinSharedBudgetDialogState extends State<JoinSharedBudgetDialog> {
  final _linkController = TextEditingController();
  bool _isJoining = false;
  String? _error;

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final input = _linkController.text.trim();
    final parsed = _parseInviteLink(input);

    if (parsed == null) {
      setState(() => _error = 'Lien invalide');
      return;
    }

    setState(() {
      _isJoining = true;
      _error = null;
    });

    final uid = context.read<AuthProvider>().user!.uid;
    final result = await context.read<SharedBudgetsProvider>().joinWithInvite(
      parsed.budgetId,
      parsed.code,
      uid,
    );

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _isJoining = false;
        _error = result.error;
      });
      return;
    }

    Navigator.pop(context);
    context.push('/shared-budgets/${parsed.budgetId}');
  }

  /// Extrait budgetId et code d'un lien ou code d'invitation.
  /// Format : {budgetId}--{inviteCode}, tel que généré par createSharedBudgetInvite
  /// sur le web, utilisé dans /join-budget/{code}.
  ({String budgetId, String code})? _parseInviteLink(String input) {
    if (input.isEmpty) return null;

    // Si c'est un lien complet, on ne garde que le dernier segment de chemin
    String raw = input;
    final uri = Uri.tryParse(input);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      raw = uri.pathSegments.last;
    }

    final parts = raw.split('--');
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
      return null;
    }

    return (budgetId: parts[0], code: parts[1]);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rejoindre un budget partagé'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _linkController,
            decoration: InputDecoration(
              labelText: 'Lien ou code d\'invitation',
              hintText: 'Colle le lien reçu ou le code',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _isJoining ? null : _join,
          child: _isJoining
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Rejoindre'),
        ),
      ],
    );
  }
}
