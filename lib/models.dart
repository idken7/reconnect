import 'package:flutter/material.dart';

import 'theme/reconnect_theme.dart';
import 'utils/relative_time.dart';

export 'models/activity_suggestion.dart';
export 'models/conversation_starter.dart';
export 'models/spin_history.dart';
export 'models/suggestion_rating.dart';

enum ReconnectPreference { loveToSee, like, neutral, dislike, ratherAvoid }

extension ReconnectPreferenceLabel on ReconnectPreference {
  String get label {
    switch (this) {
      case ReconnectPreference.loveToSee:
        return 'People I\'d love to see';
      case ReconnectPreference.like:
        return 'People I like';
      case ReconnectPreference.neutral:
        return 'Neutral';
      case ReconnectPreference.dislike:
        return 'People I\'d rather not see';
      case ReconnectPreference.ratherAvoid:
        return 'People I\'d rather avoid';
    }
  }

  String get shortLabel {
    switch (this) {
      case ReconnectPreference.loveToSee:
        return 'Love';
      case ReconnectPreference.like:
        return 'Like';
      case ReconnectPreference.neutral:
        return 'Neutral';
      case ReconnectPreference.dislike:
        return 'Dislike';
      case ReconnectPreference.ratherAvoid:
        return 'Avoid';
    }
  }

  String get emoji {
    switch (this) {
      case ReconnectPreference.loveToSee:
        return '😍';
      case ReconnectPreference.like:
        return '🙂';
      case ReconnectPreference.neutral:
        return '😐';
      case ReconnectPreference.dislike:
        return '😕';
      case ReconnectPreference.ratherAvoid:
        return '☹️';
    }
  }

  int get sortWeight {
    switch (this) {
      case ReconnectPreference.loveToSee:
        return 0;
      case ReconnectPreference.like:
        return 1;
      case ReconnectPreference.neutral:
        return 2;
      case ReconnectPreference.dislike:
        return 3;
      case ReconnectPreference.ratherAvoid:
        return 4;
    }
  }

  Color get color => tierStyle.color;

  /// The tier's full color/background/border trio, used by the Contacts
  /// drag-and-drop lanes and the spin wheel.
  TierStyle get tierStyle {
    switch (this) {
      case ReconnectPreference.loveToSee:
        return tierStyleLove;
      case ReconnectPreference.like:
        return tierStyleLike;
      case ReconnectPreference.neutral:
        return tierStyleNeutral;
      case ReconnectPreference.dislike:
        return tierStyleDislike;
      case ReconnectPreference.ratherAvoid:
        return tierStyleAvoid;
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
    this.profileImageUrl = '',
    this.birthday,
    this.emailVerified = false,
    this.phoneVerified = false,
    this.locationShared = false,
  });

  factory ReconnectProfile.fromJson(Map<String, dynamic> json) {
    return ReconnectProfile(
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      homeCity: json['homeCity'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      profileImageUrl: json['profileImageUrl'] as String? ?? '',
      birthday: json['birthday'] != null ? DateTime.tryParse(json['birthday'] as String) : null,
      emailVerified: json['emailVerified'] as bool? ?? false,
      phoneVerified: json['phoneVerified'] as bool? ?? false,
      locationShared: json['locationShared'] as bool? ?? false,
    );
  }

  final String name;
  final String email;
  final String phone;
  final String homeCity;
  final String bio;
  final String profileImageUrl;
  final DateTime? birthday;
  final bool emailVerified;
  final bool phoneVerified;
  final bool locationShared;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'homeCity': homeCity,
      'bio': bio,
      'profileImageUrl': profileImageUrl,
      'birthday': birthday?.toIso8601String(),
      'emailVerified': emailVerified,
      'phoneVerified': phoneVerified,
      'locationShared': locationShared,
    };
  }

  ReconnectProfile copyWith({
    String? name,
    String? email,
    String? phone,
    String? homeCity,
    String? bio,
    String? profileImageUrl,
    DateTime? birthday,
    bool? emailVerified,
    bool? phoneVerified,
    bool? locationShared,
  }) {
    return ReconnectProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      homeCity: homeCity ?? this.homeCity,
      bio: bio ?? this.bio,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      birthday: birthday ?? this.birthday,
      emailVerified: emailVerified ?? this.emailVerified,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      locationShared: locationShared ?? this.locationShared,
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
    this.lastSeenAt,
    this.mutual = false,
  });

  factory ReconnectContact.fromJson(Map<String, dynamic> json) {
    return ReconnectContact(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      isOnApp: json['isOnApp'] as bool? ?? false,
      lastSeen: json['lastSeen'] as String? ?? '',
      lastSeenAt: json['lastSeenAt'] != null ? DateTime.tryParse(json['lastSeenAt'] as String) : null,
      mutual: json['mutual'] as bool? ?? false,
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

  /// Legacy free-text "last seen" string. Prefer [lastSeenLabel].
  final String lastSeen;

  /// When the matched user was last seen (server timestamp), if known.
  final DateTime? lastSeenAt;
  final bool mutual;
  final List<String> availableIn;
  final ReconnectPreference preference;
  final DateTime? birthday;
  final DateTime? lastContacted;

  /// Human readable "last seen" text: relative time derived from
  /// [lastSeenAt] (e.g. "2 weeks ago"), else the legacy string, else "Unknown".
  String get lastSeenLabel {
    if (lastSeenAt != null) {
      return formatRelativeTime(lastSeenAt);
    }
    return lastSeen.isNotEmpty ? lastSeen : 'Unknown';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'isOnApp': isOnApp,
      'mutual': mutual,
      'lastSeen': lastSeen,
      'lastSeenAt': lastSeenAt?.toUtc().toIso8601String(),
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
    DateTime? lastSeenAt,
    bool? mutual,
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
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      mutual: mutual ?? this.mutual,
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
    this.sharedLocations = const <String>[],
    this.timeSinceLastSeen = '',
  });

  factory NearbySuggestion.fromJson(Map<String, dynamic> json) {
    return NearbySuggestion(
      contact: ReconnectContact.fromJson(json['contact'] as Map<String, dynamic>? ?? const <String, dynamic>{}),
      reason: json['reason'] as String? ?? '',
      distanceLabel: json['distanceLabel'] as String? ?? '',
      sharedLocations: (json['sharedLocations'] as List<dynamic>? ?? const <dynamic>[])
          .map((entry) => entry.toString())
          .toList(growable: false),
      timeSinceLastSeen: json['timeSinceLastSeen'] as String? ?? '',
    );
  }

  final ReconnectContact contact;
  final String reason;
  final String distanceLabel;
  final List<String> sharedLocations;
  final String timeSinceLastSeen;

  Map<String, dynamic> toJson() {
    return {
      'contact': contact.toJson(),
      'reason': reason,
      'distanceLabel': distanceLabel,
      'sharedLocations': sharedLocations,
      'timeSinceLastSeen': timeSinceLastSeen,
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
      status: _statusLabel(json['status'] as String?),
      contact: json.containsKey('id') ? ReconnectContact.fromJson(json) : null,
    );
  }

  final String name;
  final String? status;
  final ReconnectContact? contact;

  /// The API reports `notOnApp`; the UI shows a friendly label.
  static String? _statusLabel(String? status) => status == 'notOnApp' ? 'Not on app' : status;
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
