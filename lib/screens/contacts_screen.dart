import 'package:flutter/material.dart';

import '../models.dart';
import '../services/birthday_reminder_service.dart';
import '../theme/reconnect_theme.dart';
import '../widgets/adaptive_buttons.dart';
import '../widgets/message_preview_sheet.dart';
import 'contact_detail_screen.dart';

const _laneOrder = [
  ReconnectPreference.loveToSee,
  ReconnectPreference.like,
  ReconnectPreference.neutral,
  ReconnectPreference.dislike,
  ReconnectPreference.ratherAvoid,
];

const _laneTitles = {
  ReconnectPreference.loveToSee: 'Love to see',
  ReconnectPreference.like: 'Like',
  ReconnectPreference.neutral: 'Neutral',
  ReconnectPreference.dislike: 'Dislike',
  ReconnectPreference.ratherAvoid: 'Rather avoid',
};

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({
    super.key,
    required this.contactsImported,
    required this.contacts,
    required this.isImporting,
    required this.statusMessage,
    required this.onImportContacts,
    required this.onPreferenceChanged,
    this.nearbyContactIds = const <String>{},
  });

  final bool contactsImported;
  final List<ReconnectContact> contacts;
  final bool isImporting;
  final String? statusMessage;
  final VoidCallback onImportContacts;
  final void Function(String contactId, ReconnectPreference preference) onPreferenceChanged;
  final Set<String> nearbyContactIds;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _birthdayService = BirthdayReminderService();
  String _searchQuery = '';

  List<ReconnectContact> get _visibleContacts {
    if (_searchQuery.isEmpty) return widget.contacts;
    final query = _searchQuery.toLowerCase();
    return widget.contacts
        .where((c) => c.name.toLowerCase().contains(query) || c.email.toLowerCase().contains(query))
        .toList(growable: false);
  }

  void _sayHappyBirthday(ReconnectContact contact) {
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => MessagePreviewSheet(
        title: 'Say happy birthday',
        recipientName: contact.name,
        initialMessage: "Happy birthday, ${contact.name.split(' ').first}! Hope you're having a great one. 🎉",
        confirmLabel: 'Send',
        confirmIcon: Icons.send_rounded,
      ),
    ).then((message) {
      if (message == null || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sent to ${contact.name}!')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.contactsImported) {
      return Scaffold(
        body: SafeArea(
          child: _EmptyState(onImportContacts: widget.onImportContacts, isImporting: widget.isImporting),
        ),
      );
    }

    final visibleContacts = _visibleContacts;
    final birthdayContacts = _birthdayService.getUpcomingBirthdays(widget.contacts, daysAhead: 31);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Contacts', style: Theme.of(context).textTheme.headlineMedium),
                        Text(
                          '${widget.contacts.length} people',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: ReconnectColors.mutedText),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (widget.statusMessage != null) ...[
                      _StatusCard(message: widget.statusMessage!),
                      const SizedBox(height: 12),
                    ],
                    _SearchField(
                      value: _searchQuery,
                      onChanged: (value) => setState(() => _searchQuery = value),
                    ),
                    const SizedBox(height: 18),
                    if (birthdayContacts.isNotEmpty) ...[
                      _BirthdaysRow(
                        contacts: birthdayContacts,
                        service: _birthdayService,
                        onSayHappyBirthday: _sayHappyBirthday,
                      ),
                      const SizedBox(height: 22),
                    ],
                    Text(
                      "Drag someone into a lane to rank them. It's private — only you see this.",
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: ReconnectColors.mutedText, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            if (visibleContacts.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No contacts match "$_searchQuery"',
                      style: TextStyle(color: ReconnectColors.mutedText, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                sliver: SliverList.list(
                  children: [
                    for (final preference in _laneOrder)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _TierLane(
                          preference: preference,
                          contacts: visibleContacts.where((c) => c.preference == preference).toList(growable: false),
                          nearbyContactIds: widget.nearbyContactIds,
                          onDropped: (contact) => widget.onPreferenceChanged(contact.id, preference),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ReconnectColors.hairline),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: ReconnectColors.mutedTextStrong),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              controller: TextEditingController.fromValue(
                TextEditingValue(text: value, selection: TextSelection.collapsed(offset: value.length)),
              ),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                hintText: 'Search contacts',
                hintStyle: TextStyle(fontWeight: FontWeight.w600, color: ReconnectColors.mutedText),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BirthdaysRow extends StatelessWidget {
  const _BirthdaysRow({required this.contacts, required this.service, required this.onSayHappyBirthday});

  final List<ReconnectContact> contacts;
  final BirthdayReminderService service;
  final ValueChanged<ReconnectContact> onSayHappyBirthday;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('🎁', style: TextStyle(fontSize: 15)),
            const SizedBox(width: 8),
            Text('Birthdays this month', style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 156,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: contacts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final contact = contacts[index];
              final days = service.getDaysUntilBirthday(contact.birthday!);
              return _BirthdayCard(
                contact: contact,
                daysLabel: days == 0 ? 'Today!' : 'In $days days',
                onTap: () => onSayHappyBirthday(contact),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BirthdayCard extends StatelessWidget {
  const _BirthdayCard({required this.contact, required this.daysLabel, required this.onTap});

  final ReconnectContact contact;
  final String daysLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tierStyleLove.background,
        border: Border.all(color: tierStyleLove.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(initial: _initialOf(contact.name), color: ReconnectColors.accent, size: 36, fontSize: 14),
          const SizedBox(height: 8),
          Text(
            contact.name,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(daysLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFFB98A67))),
          const Spacer(),
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(color: ReconnectColors.accent, borderRadius: BorderRadius.circular(10)),
              child: const Text(
                'Say happy birthday',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TierLane extends StatelessWidget {
  const _TierLane({
    required this.preference,
    required this.contacts,
    required this.nearbyContactIds,
    required this.onDropped,
  });

  final ReconnectPreference preference;
  final List<ReconnectContact> contacts;
  final Set<String> nearbyContactIds;
  final ValueChanged<ReconnectContact> onDropped;

  @override
  Widget build(BuildContext context) {
    final tier = preference.tierStyle;

    return DragTarget<ReconnectContact>(
      onWillAcceptWithDetails: (details) => details.data.preference != preference,
      onAcceptWithDetails: (details) => onDropped(details.data),
      builder: (context, candidateData, rejectedData) {
        final highlighted = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tier.background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: highlighted ? tier.color : tier.border, width: highlighted ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(preference.emoji, style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 8),
                  Text(_laneTitles[preference]!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const Spacer(),
                  Text(
                    contacts.length == 1 ? '1 person' : '${contacts.length} people',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: ReconnectColors.mutedText),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 52,
                child: contacts.isEmpty
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Drop someone here',
                          style: TextStyle(color: tier.color.withValues(alpha: 0.5), fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: contacts.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) => _ContactChip(
                          contact: contacts[index],
                          tierColor: tier.color,
                          nearby: nearbyContactIds.contains(contacts[index].id),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ContactChip extends StatelessWidget {
  const _ContactChip({required this.contact, required this.tierColor, required this.nearby});

  final ReconnectContact contact;
  final Color tierColor;
  final bool nearby;

  Widget _chip({required bool dimmed}) {
    return Opacity(
      opacity: dimmed ? 0.25 : 1.0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 3, offset: const Offset(0, 1))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Avatar(initial: _initialOf(contact.name), color: tierColor, size: 30, fontSize: 12),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(contact.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text(
                  contact.lastSeen,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10, color: ReconnectColors.mutedTextStrong),
                ),
              ],
            ),
            if (nearby) ...[
              const SizedBox(width: 6),
              const Text('📍', style: TextStyle(fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => ContactDetailScreen(contact: contact)),
      ),
      // affinity: vertical means a vertical drag (toward another lane) is
      // claimed immediately, no long-press needed — matching the mockup's
      // instant drag — while a horizontal drag is left alone so the lane's
      // own horizontal ListView still scrolls normally.
      child: Draggable<ReconnectContact>(
        data: contact,
        affinity: Axis.vertical,
        feedback: Material(color: Colors.transparent, child: _chip(dimmed: false)),
        childWhenDragging: _chip(dimmed: true),
        child: _chip(dimmed: false),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial, required this.color, required this.size, required this.fontSize});

  final String initial;
  final Color color;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        initial,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: fontSize),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ReconnectColors.chipBackground, borderRadius: BorderRadius.circular(14)),
      child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
            const Text('👥', style: TextStyle(fontSize: 56)),
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
              style: TextStyle(color: ReconnectColors.mutedText, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            AdaptiveFilledButton.icon(
              onPressed: isImporting ? null : onImportContacts,
              icon: const Icon(Icons.people_alt_rounded),
              label: Text(isImporting ? 'Importing contacts...' : 'Import contacts'),
            ),
          ],
        ),
      ),
    );
  }
}

String _initialOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final first = parts.first[0];
  final second = parts.length > 1 ? parts.last[0] : '';
  return (first + second).toUpperCase();
}
