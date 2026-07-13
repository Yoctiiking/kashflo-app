import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_lock_provider.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  String? _error;
  bool _biometricAttempted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appLock = context.read<AppLockProvider>();
    if (!_biometricAttempted && appLock.canUseBiometrics) {
      _biometricAttempted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometrics());
    }
  }

  Future<void> _tryBiometrics() async {
    await context.read<AppLockProvider>().unlockWithBiometrics();
  }

  Future<void> _onDigit(String digit) async {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += digit;
      _error = null;
    });

    if (_pin.length == 4) {
      final appLock = context.read<AppLockProvider>();
      final ok = await appLock.verifyPin(_pin);
      if (ok) {
        appLock.unlock();
      } else {
        setState(() {
          _error = 'Code incorrect';
          _pin = '';
        });
      }
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            const Icon(Icons.lock_outline, size: 48),
            const SizedBox(height: 16),
            Text(
              'KashFlo verrouillé',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _pin.length;
                return Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 20,
              child: _error != null
                  ? Text(_error!, style: const TextStyle(color: Colors.red))
                  : null,
            ),
            const Spacer(flex: 2),
            _NumberPad(onDigit: _onDigit, onBackspace: _onBackspace),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _NumberPad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  const _NumberPad({required this.onDigit, required this.onBackspace});

  Widget _key(
    BuildContext context, {
    String? label,
    Widget? child,
    VoidCallback? onTap,
  }) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(36),
          onTap: onTap,
          child: Center(
            child:
                child ??
                Text(
                  label ?? '',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row
                .map((d) => _key(context, label: d, onTap: () => onDigit(d)))
                .toList(),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 72, height: 72),
            _key(context, label: '0', onTap: () => onDigit('0')),
            _key(
              context,
              child: const Icon(Icons.backspace_outlined, size: 22),
              onTap: onBackspace,
            ),
          ],
        ),
      ],
    );
  }
}
