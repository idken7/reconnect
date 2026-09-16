import 'package:flutter/material.dart';

/// A labeled choice field: a themed [DropdownButtonFormField], on every
/// platform.
class AdaptivePicker<T> extends StatelessWidget {
  const AdaptivePicker({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: [
        for (final item in items)
          DropdownMenuItem(value: item, child: Text(labelBuilder(item))),
      ],
      onChanged: enabled
          ? (item) {
              if (item != null) onChanged(item);
            }
          : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
