import 'package:flutter_contacts/flutter_contacts.dart';

class ImportedDeviceContact {
  const ImportedDeviceContact({
    required this.displayName,
    required this.emails,
    required this.phones,
  });

  final String displayName;
  final List<String> emails;
  final List<String> phones;

  Map<String, dynamic> toJson() {
    return {
      'name': displayName,
      'emails': emails,
      'phones': phones,
    };
  }
}

class ContactImportException implements Exception {
  const ContactImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ContactImportService {
  const ContactImportService();

  Future<List<ImportedDeviceContact>> importContacts() async {
    final permissionGranted = await FlutterContacts.requestPermission(readonly: true);
    if (!permissionGranted) {
      throw const ContactImportException('Contacts permission was not granted.');
    }

    final contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: false,
    );

    return contacts
        .map(_toImportedContact)
        .where((contact) => contact.displayName.trim().isNotEmpty || contact.emails.isNotEmpty || contact.phones.isNotEmpty)
        .toList(growable: false);
  }

  ImportedDeviceContact _toImportedContact(Contact contact) {
    final emails = contact.emails
        .map((email) => email.address.trim().toLowerCase())
        .where((email) => email.isNotEmpty)
        .toSet()
        .toList(growable: false);

    final phones = contact.phones
        .map((phone) => _normalizePhone(phone.normalizedNumber.isNotEmpty ? phone.normalizedNumber : phone.number))
        .where((phone) => phone.isNotEmpty)
        .toSet()
        .toList(growable: false);

    return ImportedDeviceContact(
      displayName: contact.displayName.trim(),
      emails: emails,
      phones: phones,
    );
  }

  String _normalizePhone(String input) {
    return input.replaceAll(RegExp(r'[^0-9+]'), '');
  }
}
