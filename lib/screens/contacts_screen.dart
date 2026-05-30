import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import '../widgets/birthday_reminder_card.dart';
import '../widgets/preference_selector.dart';

enum SortOption {
  nameAZ('Name (A-Z)'),
  preferenceOrder('Preference (Love → Avoid)'),
  lastContactedRecent('Last Contacted (Recent first)'),
  lastContactedOld('Last Contacted (Older first)'),
  appStatusOn('On App First'),
  appStatusOff('Not on App First');

  const SortOption(this.label);
  final String label;
}

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({
    super.key,
    required this.contactsImported,
    required this.contacts,
    required this.isImporting,
    required this.statusMessage,
    required this.onImportContacts,
    required this.onPreferenceChanged,
  });

  final bool contactsImported;
  final List<ReconnectContact> contacts;
  final bool isImporting;
  final String? statusMessage;
  final VoidCallback onImportContacts;
  final void Function(String contactId, ReconnectPreference preference) onPreferenceChanged;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  static const String _sortOptionKey = 'contacts_sort_option';
  static const String _filterSearchKey = 'contacts_filter_search';
  static const String _filterPreferencesKey = 'contacts_filter_preferences';
  static const String _filterAppStatusKey = 'contacts_filter_app_status';

  late SortOption _currentSort;
  String _searchQuery = '';
  Set<ReconnectPreference> _filteredPreferences = {};
  bool? _filterAppStatus; // null = no filter, true = on app, false = not on app
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadFilterPreferences();
  }

  Future<void> _loadFilterPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final sortName = prefs.getString(_sortOptionKey) ?? 'nameAZ';
      _currentSort = SortOption.values.firstWhere(
        (opt) => opt.name == sortName,
        orElse: () => SortOption.nameAZ,
      );
      _searchQuery = prefs.getString(_filterSearchKey) ?? '';
      final prefString = prefs.getString(_filterPreferencesKey) ?? '';
      _filteredPreferences = prefString.isEmpty
          ? {}
          : prefString.split(',').map((p) => ReconnectPreference.values.firstWhere((pref) => pref.name == p)).toSet();
      _filterAppStatus = prefs.getBool(_filterAppStatusKey);
      _isInitialized = true;
    });
  }

  Future<void> _saveFilterPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sortOptionKey, _currentSort.name);
    await prefs.setString(_filterSearchKey, _searchQuery);
    await prefs.setString(_filterPreferencesKey, _filteredPreferences.map((p) => p.name).join(','));
    if (_filterAppStatus == null) {
      await prefs.remove(_filterAppStatusKey);
    } else {
      await prefs.setBool(_filterAppStatusKey, _filterAppStatus!);
    }
  }

  List<ReconnectContact> _getFilteredAndSortedContacts() {
    var filtered = widget.contacts;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase()) || c.email.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Apply preference filter
    if (_filteredPreferences.isNotEmpty) {
      filtered = filtered.where((c) => _filteredPreferences.contains(c.preference)).toList();
    }

    // Apply app status filter
    if (_filterAppStatus != null) {
      filtered = filtered.where((c) => c.isOnApp == _filterAppStatus).toList();
    }

    // Apply sorting
    switch (_currentSort) {
      case SortOption.nameAZ:
        filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case SortOption.preferenceOrder:
        filtered.sort((a, b) => a.preference.sortWeight.compareTo(b.preference.sortWeight));
      case SortOption.lastContactedRecent:
        filtered.sort((a, b) {
          final aDate = a.lastContacted ?? DateTime(2000);
          final bDate = b.lastContacted ?? DateTime(2000);
          return bDate.compareTo(aDate); // recent first
        });
      case SortOption.lastContactedOld:
        filtered.sort((a, b) {
          final aDate = a.lastContacted ?? DateTime(2000);
          final bDate = b.lastContacted ?? DateTime(2000);
          return aDate.compareTo(bDate); // older first
        });
      case SortOption.appStatusOn:
        filtered.sort((a, b) {
          if (a.isOnApp != b.isOnApp) {
            return b.isOnApp ? 1 : -1; // on app first
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      case SortOption.appStatusOff:
        filtered.sort((a, b) {
          if (a.isOnApp != b.isOnApp) {
            return a.isOnApp ? 1 : -1; // not on app first
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
    }

    return filtered;
  }

  void _showSortFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        builder: (context, scrollController) => _SortFilterBottomSheet(
          currentSort: _currentSort,
          searchQuery: _searchQuery,
          filteredPreferences: _filteredPreferences,
          filterAppStatus: _filterAppStatus,
          onSortChanged: (sort) {
            setState(() => _currentSort = sort);
            _saveFilterPreferences();
          },
          onSearchChanged: (query) {
            setState(() => _searchQuery = query);
            _saveFilterPreferences();
          },
          onPreferenceFilterChanged: (preferences) {
            setState(() => _filteredPreferences = preferences);
            _saveFilterPreferences();
          },
          onAppStatusFilterChanged: (status) {
            setState(() => _filterAppStatus = status);
            _saveFilterPreferences();
          },
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _clearAllFilters() {
    setState(() {
      _currentSort = SortOption.nameAZ;
      _searchQuery = '';
      _filteredPreferences = {};
      _filterAppStatus = null;
    });
    _saveFilterPreferences();
  }

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty || _filteredPreferences.isNotEmpty || _filterAppStatus != null || _currentSort != SortOption.nameAZ;

  @override
  Widget build(BuildContext context) {
    if (!widget.contactsImported) {
      return _EmptyState(
        onImportContacts: widget.onImportContacts,
        isImporting: widget.isImporting,
      );
    }

    if (!_isInitialized) {
      return const SizedBox.expand();
    }

    final filteredContacts = _getFilteredAndSortedContacts();

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.statusMessage != null) ...[
              _StatusCard(message: widget.statusMessage!),
              const SizedBox(height: 12),
            ],
            // Birthday reminders
            BirthdayReminderCard(contacts: widget.contacts),
            const SizedBox(height: 16),
            Text(
              'Who is already on Reconnect',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Rank people from "love to see" to "rather avoid" so the app can make better suggestions without exposing those preferences.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (filteredContacts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 48,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No contacts match your filters',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              )
            else
              for (final contact in filteredContacts) ...[
                _ContactCard(
                  contact: contact,
                  onPreferenceChanged: (preference) => widget.onPreferenceChanged(contact.id, preference),
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_hasActiveFilters)
                Tooltip(
                  message: 'Clear all filters',
                  child: IconButton(
                    icon: const Icon(Icons.clear_all),
                    onPressed: _clearAllFilters,
                  ),
                ),
              Tooltip(
                message: 'Sort and filter',
                child: IconButton(
                  icon: Icon(_hasActiveFilters ? Icons.filter_list_alt : Icons.filter_list_outlined),
                  onPressed: _showSortFilterBottomSheet,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SortFilterBottomSheet extends StatefulWidget {
  const _SortFilterBottomSheet({
    required this.currentSort,
    required this.searchQuery,
    required this.filteredPreferences,
    required this.filterAppStatus,
    required this.onSortChanged,
    required this.onSearchChanged,
    required this.onPreferenceFilterChanged,
    required this.onAppStatusFilterChanged,
    required this.scrollController,
  });

  final SortOption currentSort;
  final String searchQuery;
  final Set<ReconnectPreference> filteredPreferences;
  final bool? filterAppStatus;
  final ValueChanged<SortOption> onSortChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Set<ReconnectPreference>> onPreferenceFilterChanged;
  final ValueChanged<bool?> onAppStatusFilterChanged;
  final ScrollController scrollController;

  @override
  State<_SortFilterBottomSheet> createState() => _SortFilterBottomSheetState();
}

class _SortFilterBottomSheetState extends State<_SortFilterBottomSheet> {
  late TextEditingController _searchController;
  late Set<ReconnectPreference> _selectedPreferences;
  late bool? _selectedAppStatus;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
    _selectedPreferences = Set.from(widget.filteredPreferences);
    _selectedAppStatus = widget.filterAppStatus;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        controller: widget.scrollController,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar for dragging
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Sort & Filter',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              // Search field
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search by name or email',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            widget.onSearchChanged('');
                            setState(() {});
                          },
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (value) {
                  widget.onSearchChanged(value);
                  setState(() {});
                },
              ),
              const SizedBox(height: 16),
              // Sort options
              Text(
                'Sort by',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              for (final option in SortOption.values)
                RadioListTile<SortOption>(
                  title: Text(option.label),
                  value: option,
                  groupValue: widget.currentSort,
                  onChanged: (value) {
                    if (value != null) {
                      widget.onSortChanged(value);
                    }
                  },
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              const SizedBox(height: 16),
              // Preference filter
              Text(
                'Filter by preference',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final pref in ReconnectPreference.values)
                    FilterChip(
                      label: Text('${pref.emoji} ${pref.shortLabel}'),
                      selected: _selectedPreferences.contains(pref),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedPreferences.add(pref);
                          } else {
                            _selectedPreferences.remove(pref);
                          }
                        });
                        widget.onPreferenceFilterChanged(_selectedPreferences);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // App status filter
              Text(
                'Filter by app status',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<bool?>(
                      segments: const <ButtonSegment<bool?>>[
                        ButtonSegment<bool?>(
                          value: null,
                          label: Text('All'),
                        ),
                        ButtonSegment<bool?>(
                          value: true,
                          label: Text('On App'),
                        ),
                        ButtonSegment<bool?>(
                          value: false,
                          label: Text('Not on App'),
                        ),
                      ],
                      selected: <bool?>{_selectedAppStatus},
                      onSelectionChanged: (Set<bool?> newSelection) {
                        setState(() {
                          _selectedAppStatus = newSelection.first;
                        });
                        widget.onAppStatusFilterChanged(_selectedAppStatus);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onImportContacts, required this.isImporting});

  final VoidCallback onImportContacts;
  final bool isImporting;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.import_contacts_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Import contacts to discover who is on the app.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'This first pass keeps contact matching local in the product flow and only surfaces people who have already joined.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: isImporting ? null : onImportContacts,
              icon: const Icon(Icons.contacts),
              label: Text(isImporting ? 'Importing contacts...' : 'Import contacts'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.contact, required this.onPreferenceChanged});

  final ReconnectContact contact;
  final ValueChanged<ReconnectPreference> onPreferenceChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Tooltip(
                        message: 'Time since last contact',
                        child: Text(
                          contact.lastSeen,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: contact.isOnApp ? 'On app' : 'Not on app',
                  child: Icon(
                    contact.isOnApp ? Icons.verified_outlined : Icons.person_search_outlined,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            PreferenceSelectorWidget(
              selected: contact.preference,
              onChanged: onPreferenceChanged,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Available in: ${contact.availableIn.join(', ')}',
                  child: Text(
                    contact.availableIn.join(', '),
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message),
      ),
    );
  }
}
