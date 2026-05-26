import 'package:flutter/material.dart';

export 'models/activity_suggestion.dart';
export 'models/conversation_starter.dart';
export 'models/spin_history.dart';
export 'models/suggestion_rating.dart';

enum ReconnectPreference { loveToSee, neutral, ratherAvoid }

extension ReconnectPreferenceLabel on ReconnectPreference {
  String get label {
    switch (this) {
      case ReconnectPreference.loveToSee:
        return 'People I\'d love to see';
      case ReconnectPreference.neutral:
        return 'Neutral';
      case ReconnectPreference.ratherAvoid:
        return 'People I\'d rather avoid';
    }
  }

  String get shortLabel {
    switch (this) {
      case ReconnectPreference.loveToSee:
        return 'Love';
      case ReconnectPreference.neutral:
        return 'Neutral';
      case ReconnectPreference.ratherAvoid:
        return 'Avoid';
    }
  }

  int get sortWeight {
    switch (this) {
      case ReconnectPreference.loveToSee:
        return 0;
      case ReconnectPreference.neutral:
        return 1;
      case ReconnectPreference.ratherAvoid:
        return 2;
    }
  }

  Color get color {
    switch (this) {
      case ReconnectPreference.loveToSee:
        return const Color(0xFF1976D2);
      case ReconnectPreference.neutral:
        return const Color(0xFF607D8B);
      case ReconnectPreference.ratherAvoid:
        return const Color(0xFFE57373);
    }
  }
}

class ReconnectProfile {
  const ReconnectProfile({
    required this.name,
    required this.email,
    required this.phone,
    required this.homeCity,
    required this.bio,
    this.birthday,
  });

  factory ReconnectProfile.fromJson(Map<String, dynamic> json) {
    return ReconnectProfile(
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      homeCity: json['homeCity'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      birthday: json['birthday'] != null ? DateTime.tryParse(json['birthday'] as String) : null,
    );
  }

  final String name;
  final String email;
  final String phone;
  final String homeCity;
  final String bio;
  final DateTime? birthday;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'homeCity': homeCity,
      'bio': bio,
      'birthday': birthday?.toIso8601String(),
    };
  }

  ReconnectProfile copyWith({
    String? name,
    String? email,
    String? phone,
    String? homeCity,
    String? bio,
    DateTime? birthday,
  }) {
    return ReconnectProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      homeCity: homeCity ?? this.homeCity,
      bio: bio ?? this.bio,
      birthday: birthday ?? this.birthday,
    );
  }
}

class ReconnectContact {
  const ReconnectContact({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.isOnApp,
    required this.lastSeen,
    required this.availableIn,
    required this.preference,
    this.birthday,
    this.lastContacted,
  });

  factory ReconnectContact.fromJson(Map<String, dynamic> json) {
    return ReconnectContact(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      isOnApp: json['isOnApp'] as bool? ?? false,
      lastSeen: json['lastSeen'] as String? ?? '',
      availableIn: (json['availableIn'] as List<dynamic>? ?? const <dynamic>[])
          .map((entry) => entry.toString())
          .toList(growable: false),
      preference: ReconnectPreference.values.firstWhere(
        (value) => value.name == (json['preference'] as String? ?? ''),
        orElse: () => ReconnectPreference.neutral,
      ),
      birthday: json['birthday'] != null ? DateTime.tryParse(json['birthday'] as String) : null,
      lastContacted: json['lastContacted'] != null ? DateTime.tryParse(json['lastContacted'] as String) : null,
    );
  }

  final String id;
  final String name;
  final String email;
  final String phone;
  final bool isOnApp;
  final String lastSeen;
  final List<String> availableIn;
  final ReconnectPreference preference;
  final DateTime? birthday;
  final DateTime? lastContacted;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'isOnApp': isOnApp,
      'lastSeen': lastSeen,
      'availableIn': availableIn,
      'preference': preference.name,
      'birthday': birthday?.toIso8601String(),
      'lastContacted': lastContacted?.toIso8601String(),
    };
  }

  ReconnectContact copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    bool? isOnApp,
    String? lastSeen,
    List<String>? availableIn,
    ReconnectPreference? preference,
    DateTime? birthday,
    DateTime? lastContacted,
  }) {
    return ReconnectContact(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      isOnApp: isOnApp ?? this.isOnApp,
      lastSeen: lastSeen ?? this.lastSeen,
      availableIn: availableIn ?? this.availableIn,
      preference: preference ?? this.preference,
      birthday: birthday ?? this.birthday,
      lastContacted: lastContacted ?? this.lastContacted,
    );
  }
}

class NearbySuggestion {
  const NearbySuggestion({
    required this.contact,
    required this.reason,
    required this.distanceLabel,
  });

  factory NearbySuggestion.fromJson(Map<String, dynamic> json) {
    return NearbySuggestion(
      contact: ReconnectContact.fromJson(json['contact'] as Map<String, dynamic>? ?? const <String, dynamic>{}),
      reason: json['reason'] as String? ?? '',
      distanceLabel: json['distanceLabel'] as String? ?? '',
    );
  }

  final ReconnectContact contact;
  final String reason;
  final String distanceLabel;

  Map<String, dynamic> toJson() {
    return {
      'contact': contact.toJson(),
      'reason': reason,
      'distanceLabel': distanceLabel,
    };
  }
}

class ReconnectDashboardData {
  const ReconnectDashboardData({
    required this.profile,
    required this.supportedLocations,
    required this.currentLocation,
    required this.contactsImported,
    required this.contacts,
    required this.suggestions,
  });

  factory ReconnectDashboardData.fromJson(Map<String, dynamic> json) {
    return ReconnectDashboardData(
      profile: ReconnectProfile.fromJson(json['profile'] as Map<String, dynamic>? ?? const <String, dynamic>{}),
      supportedLocations: (json['supportedLocations'] as List<dynamic>? ?? const <dynamic>[])
          .map((entry) => entry.toString())
          .toList(growable: false),
      currentLocation: json['currentLocation'] as String? ?? '',
      contactsImported: json['contactsImported'] as bool? ?? false,
      contacts: (json['contacts'] as List<dynamic>? ?? const <dynamic>[])
          .map((entry) => ReconnectContact.fromJson(entry as Map<String, dynamic>))
          .toList(growable: false),
      suggestions: (json['suggestions'] as List<dynamic>? ?? const <dynamic>[])
          .map((entry) => NearbySuggestion.fromJson(entry as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final ReconnectProfile profile;
  final List<String> supportedLocations;
  final String currentLocation;
  final bool contactsImported;
  final List<ReconnectContact> contacts;
  final List<NearbySuggestion> suggestions;

  Map<String, dynamic> toJson() {
    return {
      'profile': profile.toJson(),
      'supportedLocations': supportedLocations,
      'currentLocation': currentLocation,
      'contactsImported': contactsImported,
      'contacts': contacts.map((contact) => contact.toJson()).toList(growable: false),
      'suggestions': suggestions.map((suggestion) => suggestion.toJson()).toList(growable: false),
    };
  }

  ReconnectDashboardData copyWith({
    ReconnectProfile? profile,
    List<String>? supportedLocations,
    String? currentLocation,
    bool? contactsImported,
    List<ReconnectContact>? contacts,
    List<NearbySuggestion>? suggestions,
  }) {
    return ReconnectDashboardData(
      profile: profile ?? this.profile,
      supportedLocations: supportedLocations ?? this.supportedLocations,
      currentLocation: currentLocation ?? this.currentLocation,
      contactsImported: contactsImported ?? this.contactsImported,
      contacts: contacts ?? this.contacts,
      suggestions: suggestions ?? this.suggestions,
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.profile,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final accessToken = (json['accessToken'] as String?) ?? (json['token'] as String?) ?? '';
    return AuthSession(
      accessToken: accessToken,
      refreshToken: json['refreshToken'] as String? ?? '',
      accessTokenExpiresAt: DateTime.tryParse(json['accessTokenExpiresAt'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc().add(const Duration(minutes: 15)),
      profile: ReconnectProfile.fromJson(json['profile'] as Map<String, dynamic>? ?? const <String, dynamic>{}),
    );
  }

  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;
  final ReconnectProfile profile;

  bool get hasRefreshToken => refreshToken.isNotEmpty;
  bool get isExpired => DateTime.now().toUtc().isAfter(accessTokenExpiresAt);

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'accessTokenExpiresAt': accessTokenExpiresAt.toIso8601String(),
      'profile': profile.toJson(),
    };
  }
}

class MatchCandidate {
  const MatchCandidate({
    required this.name,
    this.status,
    this.contact,
  });

  factory MatchCandidate.fromJson(Map<String, dynamic> json) {
    return MatchCandidate(
      name: json['name'] as String? ?? '',
      status: json['status'] as String?,
      contact: json.containsKey('id') ? ReconnectContact.fromJson(json) : null,
    );
  }

  final String name;
  final String? status;
  final ReconnectContact? contact;
}

class ContactMatches {
  const ContactMatches({
    required this.mutual,
    required this.oneWay,
    required this.notOnApp,
  });

  factory ContactMatches.fromJson(Map<String, dynamic> json) {
    return ContactMatches(
      mutual: (json['mutual'] as List<dynamic>? ?? const <dynamic>[])
          .map((entry) => MatchCandidate.fromJson(entry as Map<String, dynamic>))
          .toList(growable: false),
      oneWay: (json['oneWay'] as List<dynamic>? ?? const <dynamic>[])
          .map((entry) => MatchCandidate.fromJson(entry as Map<String, dynamic>))
          .toList(growable: false),
      notOnApp: (json['notOnApp'] as List<dynamic>? ?? const <dynamic>[])
          .map((entry) => MatchCandidate.fromJson(entry as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final List<MatchCandidate> mutual;
  final List<MatchCandidate> oneWay;
  final List<MatchCandidate> notOnApp;

  static const empty = ContactMatches(
    mutual: <MatchCandidate>[],
    oneWay: <MatchCandidate>[],
    notOnApp: <MatchCandidate>[],
  );
}
