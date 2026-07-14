import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_profile_provider.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<String>? _expenseCategories;
  List<String>? _incomeCategories;
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    final uid = context.read<AuthProvider>().user!.uid;
    final provider = context.read<UserProfileProvider>();
    await provider.updateCategories(uid, 'expense', _expenseCategories!);
    await provider.updateCategories(uid, 'income', _incomeCategories!);

    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Catégories enregistrées')));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProfileProvider>(
      builder: (context, profileProvider, _) {
        final profile = profileProvider.profile;
        if (profile == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!_initialized) {
          _expenseCategories = List.of(profile.expenseCategories);
          _incomeCategories = List.of(profile.incomeCategories);
          _initialized = true;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Catégories'),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Dépenses'),
                Tab(text: 'Revenus'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _CategoryListEditor(
                categories: _expenseCategories!,
                onChanged: (list) => setState(() => _expenseCategories = list),
              ),
              _CategoryListEditor(
                categories: _incomeCategories!,
                onChanged: (list) => setState(() => _incomeCategories = list),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Enregistrer'),
            ),
          ),
        );
      },
    );
  }
}

class _CategoryListEditor extends StatefulWidget {
  final List<String> categories;
  final ValueChanged<List<String>> onChanged;

  const _CategoryListEditor({
    required this.categories,
    required this.onChanged,
  });

  @override
  State<_CategoryListEditor> createState() => _CategoryListEditorState();
}

class _CategoryListEditorState extends State<_CategoryListEditor> {
  final _addController = TextEditingController();
  int? _renamingIndex;
  final _renameController = TextEditingController();

  @override
  void dispose() {
    _addController.dispose();
    _renameController.dispose();
    super.dispose();
  }

  void _startRename(int index) {
    setState(() {
      _renamingIndex = index;
      _renameController.text = widget.categories[index];
    });
  }

  void _confirmRename() {
    final index = _renamingIndex;
    if (index == null) return;
    final newValue = _renameController.text.trim();
    if (newValue.isEmpty) {
      setState(() => _renamingIndex = null);
      return;
    }
    final updated = List.of(widget.categories);
    updated[index] = newValue;
    setState(() => _renamingIndex = null);
    widget.onChanged(updated);
  }

  void _delete(int index) {
    final updated = List.of(widget.categories)..removeAt(index);
    widget.onChanged(updated);
  }

  void _add() {
    final value = _addController.text.trim();
    if (value.isEmpty || widget.categories.contains(value)) {
      _addController.clear();
      return;
    }
    final updated = List.of(widget.categories);
    final autreIndex = updated.indexOf('Autre');
    if (autreIndex != -1) {
      updated.insert(autreIndex, value);
    } else {
      updated.add(value);
    }
    _addController.clear();
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: widget.categories.length,
            itemBuilder: (context, index) {
              final category = widget.categories[index];
              final isProtected = category == 'Autre';

              if (_renamingIndex == index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _renameController,
                          autofocus: true,
                          decoration: const InputDecoration(isDense: true),
                          onSubmitted: (_) => _confirmRename(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: _confirmRename,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _renamingIndex = null),
                      ),
                    ],
                  ),
                );
              }

              return ListTile(
                title: Text(category),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: isProtected ? null : () => _startRename(index),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: isProtected ? null : () => _delete(index),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addController,
                  decoration: const InputDecoration(
                    labelText: 'Nouvelle catégorie',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(icon: const Icon(Icons.add), onPressed: _add),
            ],
          ),
        ),
      ],
    );
  }
}
