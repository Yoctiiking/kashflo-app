import 'package:flutter/material.dart';

/// Sélecteur de catégorie qui, si "Autre" est choisi, révèle un champ texte
/// optionnel pour saisir une catégorie personnalisée. Aligné sur
/// components/CategorySelect.tsx côté web.
class CategorySelect extends StatefulWidget {
  final List<String> categories;
  final String? value;
  final ValueChanged<String> onChanged;
  final String label;

  const CategorySelect({
    super.key,
    required this.categories,
    required this.value,
    required this.onChanged,
    this.label = 'Catégorie',
  });

  @override
  State<CategorySelect> createState() => _CategorySelectState();
}

class _CategorySelectState extends State<CategorySelect> {
  late String? _selected;
  late final TextEditingController _customController;

  bool get _isKnown =>
      widget.value == null || widget.categories.contains(widget.value);

  @override
  void initState() {
    super.initState();
    _selected = _isKnown ? widget.value : 'Autre';
    _customController = TextEditingController(
      text: _isKnown ? '' : widget.value,
    );
  }

  @override
  void didUpdateWidget(covariant CategorySelect oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se resynchronise quand la liste de catégories change (ex: bascule
    // dépense/revenu) ou que la valeur change depuis l'extérieur.
    if (oldWidget.categories != widget.categories ||
        oldWidget.value != widget.value) {
      _selected = _isKnown ? widget.value : 'Autre';
      final newCustomText = _isKnown ? '' : (widget.value ?? '');
      // Muter le TextEditingController ici notifierait immédiatement le
      // TextFormField parent, qui appellerait Form.setState() alors que le
      // widget est encore en train d'être reconstruit (on est dans
      // didUpdateWidget). On diffère donc la mise à jour après la frame en
      // cours.
      if (_customController.text != newCustomText) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _customController.text = newCustomText;
        });
      }
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _handleSelectChange(String next) {
    setState(() => _selected = next);
    widget.onChanged(
      next == 'Autre'
          ? (_customController.text.trim().isEmpty
                ? 'Autre'
                : _customController.text.trim())
          : next,
    );
  }

  void _handleCustomChange(String next) {
    widget.onChanged(next.trim().isEmpty ? 'Autre' : next.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selected,
          decoration: InputDecoration(labelText: widget.label),
          hint: const Text('Sélectionner...'),
          items: widget.categories
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (value) {
            if (value != null) _handleSelectChange(value);
          },
        ),
        if (_selected == 'Autre') ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: _customController,
            decoration: const InputDecoration(
              labelText: 'Préciser la catégorie (optionnel)',
            ),
            onChanged: _handleCustomChange,
          ),
        ],
      ],
    );
  }
}
