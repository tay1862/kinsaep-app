import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinsaep_pos/app/theme.dart';
import 'package:kinsaep_pos/core/utils/currency_util.dart';
import 'package:kinsaep_pos/core/providers/app_providers.dart';

class ModifierEditor extends ConsumerStatefulWidget {
  final String initialModifiers;
  final Function(String modifiersJson) onSave;

  const ModifierEditor({
    super.key,
    required this.initialModifiers,
    required this.onSave,
  });

  @override
  ConsumerState<ModifierEditor> createState() => _ModifierEditorState();
}

class _ModifierEditorState extends ConsumerState<ModifierEditor> {
  List<Map<String, dynamic>> _groups = [];

  @override
  void initState() {
    super.initState();
    try {
      final parsed = jsonDecode(widget.initialModifiers);
      if (parsed is List) {
        _groups = List<Map<String, dynamic>>.from(parsed.map((x) => Map<String, dynamic>.from(x)));
      }
    } catch (e) {
      _groups = [];
    }
  }

  void _addGroup() {
    setState(() {
      _groups.add({
        'name': 'New Option Group',
        'options': [
          {'name': 'Option 1', 'price': 0.0}
        ]
      });
    });
  }

  void _addOption(int groupIndex) {
    setState(() {
      final options = List<Map<String, dynamic>>.from(_groups[groupIndex]['options'] ?? []);
      options.add({'name': 'New Option', 'price': 0.0});
      _groups[groupIndex]['options'] = options;
    });
  }

  void _removeGroup(int index) {
    setState(() {
      _groups.removeAt(index);
    });
  }

  void _removeOption(int groupIndex, int optionIndex) {
    setState(() {
      final options = List<Map<String, dynamic>>.from(_groups[groupIndex]['options']);
      options.removeAt(optionIndex);
      _groups[groupIndex]['options'] = options;
    });
  }

  Future<void> _editGroupName(int index) async {
    final controller = TextEditingController(text: _groups[index]['name']);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Group Name'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Save')),
        ],
      )
    );
    if (newName != null && newName.isNotEmpty) {
      setState(() => _groups[index]['name'] = newName);
    }
  }

  Future<void> _editOption(int groupIndex, int optIndex) async {
    final option = _groups[groupIndex]['options'][optIndex];
    final nameCtrl = TextEditingController(text: option['name']);
    final priceCtrl = TextEditingController(text: option['price'].toString());

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Option'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Extra Price')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () {
            final price = double.tryParse(priceCtrl.text) ?? 0.0;
            Navigator.pop(ctx, {'name': nameCtrl.text, 'price': price});
          }, child: const Text('Save')),
        ],
      )
    );

    if (result != null) {
      setState(() {
        _groups[groupIndex]['options'][optIndex] = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);
    
    return Scaffold(
      backgroundColor: KinsaepTheme.surface,
      appBar: AppBar(
        title: const Text('Modifiers & Options'),
        backgroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () {
              widget.onSave(jsonEncode(_groups));
              Navigator.pop(context);
            },
            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _groups.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.tune_rounded, size: 64, color: KinsaepTheme.border),
                  const SizedBox(height: 16),
                  const Text('No modifiers added', style: TextStyle(
                    fontSize: 18, color: KinsaepTheme.textSecondary, fontWeight: FontWeight.w600,
                  )),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _addGroup,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Option Group'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _groups.length + 1,
              itemBuilder: (context, index) {
                if (index == _groups.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: OutlinedButton.icon(
                      onPressed: _addGroup,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Option Group'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  );
                }

                final group = _groups[index];
                final options = group['options'] as List;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: KinsaepTheme.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _editGroupName(index),
                                child: Text(
                                  group['name'],
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => _removeGroup(index),
                              icon: const Icon(Icons.delete_outline_rounded, color: KinsaepTheme.error),
                            ),
                          ],
                        ),
                        const Divider(),
                        ...List.generate(options.length, (optIndex) {
                          final opt = options[optIndex];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(opt['name']),
                            subtitle: Text('+ ${CurrencyUtil.format(opt['price'] ?? 0.0, currency)}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded, size: 20),
                                  onPressed: () => _editOption(index, optIndex),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline_rounded, size: 20, color: KinsaepTheme.error),
                                  onPressed: () => _removeOption(index, optIndex),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => _addOption(index),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Option'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
