import 'package:flutter/material.dart';

import '../models.dart';

class PreferenceSelectorWidget extends StatelessWidget {
  const PreferenceSelectorWidget({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final ReconnectPreference selected;
  final ValueChanged<ReconnectPreference> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final pref in ReconnectPreference.values) ...[
          _PreferenceButton(
            preference: pref,
            isSelected: selected == pref,
            onTap: () => onChanged(pref),
          ),
        ],
      ],
    );
  }
}

class _PreferenceButton extends StatelessWidget {
  const _PreferenceButton({
    required this.preference,
    required this.isSelected,
    required this.onTap,
  });

  final ReconnectPreference preference;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: isSelected
                ? Border.all(
                    color: preference.color,
                    width: 2,
                  )
                : Border.all(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
            borderRadius: BorderRadius.circular(12),
            color: isSelected
                ? preference.color.withOpacity(0.1)
                : Colors.transparent,
          ),
          child: Tooltip(
            message: preference.label,
            child: Text(
              preference.emoji,
              style: const TextStyle(fontSize: 28),
            ),
          ),
        ),
      ),
    );
  }
}
