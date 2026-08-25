import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_session_service.dart';

class ModerationGuidance {
  final String title;
  final String body;

  const ModerationGuidance({required this.title, required this.body});
}

class ModerationState {
  final String status;
  final String action;
  final String note;
  final String category;
  final String severity;
  final DateTime? actionAt;
  final DateTime? seenAt;
  final DateTime? suspensionEndsAt;
  final List<Map<String, dynamic>> history;

  const ModerationState({
    required this.status,
    required this.action,
    required this.note,
    required this.category,
    required this.severity,
    this.actionAt,
    this.seenAt,
    this.suspensionEndsAt,
    this.history = const [],
  });

  factory ModerationState.fromUserData(Map<String, dynamic> data) {
    final rawStatus = _readString(
      data['moderationStatus'] ?? data['status'],
    ).toLowerCase();
    final rawHistory = data['moderationHistory'];

    return ModerationState(
      status: rawStatus.isEmpty || rawStatus == 'published'
          ? 'active'
          : rawStatus,
      action: _readString(data['lastModerationAction']),
      note: _readString(
        data['lastModerationUserNote'] ?? data['lastModerationNote'],
      ),
      category: _readString(
        data['lastModerationCategory'] ??
            data['moderationCategory'] ??
            data['lastModerationReason'],
      ),
      severity: _readString(
        data['lastModerationSeverity'] ?? data['moderationSeverity'],
      ),
      actionAt: _readDate(
        data['lastModerationAt'] ??
            data['resolvedAt'] ??
            data['updatedAt'] ??
            data['createdAt'],
      ),
      seenAt: _readDate(data['lastModerationSeenAt']),
      suspensionEndsAt: _readDate(
        data['suspensionEndsAt'] ?? data['moderationEndsAt'],
      ),
      history: rawHistory is List
          ? rawHistory
                .whereType<Map>()
                .map((entry) => Map<String, dynamic>.from(entry))
                .toList()
                .reversed
                .toList()
          : const [],
    );
  }

  bool get isWarning => status == 'warned' || status == 'warning';

  bool get isSuspended =>
      status == 'suspended' || status == 'suspend' || status == 'restricted';

  bool get isBanned =>
      status == 'banned' || status == 'ban' || status == 'disabled';

  bool get isBlocked => isSuspended || isBanned;

  bool get isPermanent => isBanned || action.toLowerCase().contains('ban');

  bool get shouldShowWarning {
    if (!isWarning) return false;
    if (seenAt == null || actionAt == null) return true;
    return seenAt!.isBefore(actionAt!);
  }

  String get title {
    if (isPermanent) return 'Account permanently disabled';
    if (isSuspended) return 'Account temporarily suspended';
    if (isWarning) return 'Warning';
    return 'Account status';
  }

  String get body {
    if (note.isNotEmpty) return note;
    if (isPermanent) {
      return 'Following an administrative review, your account has been permanently disabled because it violated our reporting policies.';
    }
    if (isSuspended) {
      return 'The Breedr Team has temporarily suspended your account while you are unable to access Breedr services.';
    }
    if (isWarning) {
      return 'The Breedr Team reviewed your account activity and issued a formal warning. Please correct the reported issue immediately.';
    }
    return 'Your account is active.';
  }

  String get badge {
    if (isPermanent) return 'Permanently disabled';
    if (isSuspended) return 'Suspended';
    if (isWarning) return 'Warning';
    return 'Active';
  }

  ModerationGuidance get guidance => moderationGuidanceFor(category);

  bool get isActive => !isWarning && !isBlocked;
}

ModerationGuidance moderationGuidanceFor(String category) {
  final key = category.trim().toLowerCase();
  for (final entry in _guidanceByCategory.entries) {
    if (key == entry.key || key.contains(entry.key)) return entry.value;
  }
  return const ModerationGuidance(
    title: 'How to avoid this in the future',
    body:
        'Please keep your profile, listings, and conversations accurate, respectful, and within Breedr. Repeated reports that are verified may result in stronger administrative action.',
  );
}

const _guidanceByCategory = <String, ModerationGuidance>{
  'suspicious or scam behavior': ModerationGuidance(
    title: 'How to avoid this in the future',
    body:
        "Conduct all conversations, payment arrangements, reservations, and adoption or breeding discussions through Breedr's official messaging system whenever possible. Avoid requesting personal information or asking users to complete transactions outside the platform. Maintaining transparent and honest communication helps protect you and other users. If similar reports are verified in the future, stronger administrative action may be taken against your account.",
  ),
  'fake or impersonating account': ModerationGuidance(
    title: 'How to avoid this in the future',
    body:
        "Ensure that your profile contains accurate and truthful information. Do not use another person's identity, photographs, or personal details without permission. Keep your account information updated so other users can confidently verify your identity. Repeated reports involving false or misleading profile information may result in more severe administrative action.",
  ),
  'harassment or abusive behavior': ModerationGuidance(
    title: 'How to avoid this in the future',
    body:
        'Always communicate respectfully with other users. Avoid using offensive, threatening, discriminatory, or inappropriate language in messages, comments, or any interactions within the platform. Maintaining respectful communication helps create a safe environment for everyone. Continued reports of inappropriate behavior may result in stronger administrative action.',
  ),
  'animal abuse or neglect': ModerationGuidance(
    title: 'How to avoid this in the future',
    body:
        'Ensure that every pet under your care receives proper food, shelter, medical attention, and humane treatment. Only post pets that are being responsibly cared for and accurately represented. Reports involving animal welfare are treated seriously and may lead to increased administrative action if similar concerns arise again.',
  ),
  'misleading pet information': ModerationGuidance(
    title: 'How to avoid this in the future',
    body:
        'Always provide complete, accurate, and up-to-date information about your pets, including their breed, age, vaccination records, health condition, and other relevant details. Honest and accurate listings help users make informed decisions and reduce misunderstandings. Repeated reports involving inaccurate pet information may result in stronger administrative action.',
  ),
  'fake or misleading listing': ModerationGuidance(
    title: 'How to avoid this in the future',
    body:
        "Ensure that every pet listing accurately represents the pet being offered. Use genuine photographs and provide truthful information regarding the pet's condition, breed, age, health records, and availability. Listings that contain misleading or inaccurate information may be removed and repeated violations may lead to stronger administrative action.",
  ),
  'suspected animal abuse or neglect': ModerationGuidance(
    title: 'How to avoid this in the future',
    body:
        "Only create listings for pets that are receiving appropriate care and are kept in safe and healthy living conditions. Ensure that all photos and information accurately reflect the pet's current condition. Reports concerning animal welfare are reviewed carefully and repeated concerns may result in more severe administrative action.",
  ),
  'scam or fraudulent activity': ModerationGuidance(
    title: 'How to avoid this in the future',
    body:
        'Conduct all adoption, breeding, reservation, and payment discussions honestly and transparently. Avoid requesting payments through suspicious methods or providing misleading transaction information. Keeping all interactions clear and truthful helps maintain trust within Breedr. Verified repeated reports may result in stronger administrative action.',
  ),
  'inappropriate or offensive content': ModerationGuidance(
    title: 'How to avoid this in the future',
    body:
        'Ensure that all listing photos, descriptions, and uploaded content remain appropriate, respectful, and directly related to the pet being listed. Remove any misleading, offensive, or unrelated content before publishing your listing. Repeated reports involving inappropriate content may result in stronger administrative action.',
  ),
  'prohibited breed or illegal sale': ModerationGuidance(
    title: 'How to avoid this in the future',
    body:
        'Before creating a listing, ensure that the pet and transaction comply with applicable laws and Breedr policies regarding animal ownership and sales. Do not post listings involving prohibited breeds, restricted animals, or unlawful transactions. Continued reports involving prohibited or illegal listings may result in stronger administrative action.',
  ),
};

class ModerationService {
  ModerationService._();

  static final ModerationService instance = ModerationService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<ModerationState?> getCurrentUserModeration() async {
    final profile = await UserSessionService.instance.getCurrentUserProfile();
    final data = profile?.data();
    if (data == null) return null;

    final role = _readString(data['role']).toLowerCase();
    if (role == 'admin') return null;

    final state = ModerationState.fromUserData(data);
    if (state.isSuspended &&
        state.suspensionEndsAt != null &&
        !DateTime.now().isBefore(state.suspensionEndsAt!)) {
      await _markCurrentUserActive();
      return null;
    }
    return state.isActive ? null : state;
  }

  Future<void> acknowledgeCurrentWarning() async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'lastModerationSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Acknowledgement is only a convenience marker; never block the user.
    }
  }

  Future<void> _markCurrentUserActive() async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) return;

    try {
      final pets = await _firestore
          .collection('pets')
          .where('ownerId', isEqualTo: user.uid)
          .get();
      final batch = _firestore.batch();
      batch.set(_firestore.collection('users').doc(user.uid), {
        'moderationStatus': 'active',
        'moderationEndsAt': FieldValue.delete(),
        'suspensionEndsAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      for (final pet in pets.docs) {
        final data = pet.data();
        if ((data['moderationListingStatus'] ?? '').toString() != 'hidden') {
          continue;
        }
        batch.set(pet.reference, {
          'moderationListingStatus': 'active',
          'moderationHiddenUntil': FieldValue.delete(),
          'moderationSourceAction': FieldValue.delete(),
          'moderationHiddenReason': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (_) {
      // If this update fails, avoid locking users out past the local expiry.
    }
  }
}

String _readString(dynamic value) => value?.toString().trim() ?? '';

DateTime? _readDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
