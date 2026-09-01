import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/breedr_network_image.dart';

class ReturnedPetsScreen extends StatelessWidget {
  const ReturnedPetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4F7),
      appBar: _returnAppBar(context, 'Returned Pets'),
      body: userId == null
          ? const _ReturnEmpty(
              icon: Icons.lock_outline,
              title: 'Please sign in again',
              message: 'Your return history will appear after you sign in.',
            )
          : _ReturnedPetsBody(userId: userId),
    );
  }
}

class _ReturnedPetsBody extends StatelessWidget {
  final String userId;

  const _ReturnedPetsBody({required this.userId});

  @override
  Widget build(BuildContext context) {
    final collection = FirebaseFirestore.instance.collection(
      'adoptionReturnRequests',
    );
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: collection.where('filedBy', isEqualTo: userId).snapshots(),
      builder: (context, filedSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: collection.where('ownerId', isEqualTo: userId).snapshots(),
          builder: (context, ownerSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('returnedPets')
                  .where('participantIds', arrayContains: userId)
                  .snapshots(),
              builder: (context, legacySnapshot) {
                final snapshots = [
                  filedSnapshot,
                  ownerSnapshot,
                  legacySnapshot,
                ];
                if (snapshots.any((snapshot) => snapshot.hasError)) {
                  return const _ReturnEmpty(
                    icon: Icons.cloud_off_outlined,
                    title: 'Returns could not be loaded',
                    message: 'Check your connection and try again.',
                  );
                }
                if (snapshots.any((snapshot) => !snapshot.hasData)) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                final records = <String, _ReturnRecord>{};
                for (final document in filedSnapshot.data!.docs) {
                  records[document.id] = _ReturnRecord.fromRequest(document);
                }
                for (final document in ownerSnapshot.data!.docs) {
                  records[document.id] = _ReturnRecord.fromRequest(document);
                }
                for (final document in legacySnapshot.data!.docs) {
                  final legacy = _ReturnRecord.fromReturnedPet(document);
                  records.putIfAbsent(legacy.returnRequestId, () => legacy);
                }
                final returns = records.values.toList()
                  ..sort((a, b) => b.sortDate.compareTo(a.sortDate));

                return ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  children: [
                    const Text(
                      'Return requests you\'ve filed or received and their current stage. This updates automatically once an admin makes a decision — no need to check in.',
                      style: TextStyle(
                        color: Color(0xFF948A9B),
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (returns.isEmpty)
                      const _ReturnEmpty(
                        icon: Icons.assignment_return_outlined,
                        title: 'No return requests yet',
                        message:
                            'Return requests connected to your adoptions will appear here.',
                      )
                    else
                      ...returns.map(
                        (record) => Padding(
                          padding: const EdgeInsets.only(bottom: 13),
                          child: _ReturnListCard(record: record),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ReturnListCard extends StatelessWidget {
  final _ReturnRecord record;

  const _ReturnListCard({required this.record});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ReturnPetVisual>(
      future: _resolvePetVisual(record),
      builder: (context, snapshot) {
        final visual = snapshot.data ?? _ReturnPetVisual.fallback(record);
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    _ReturnDetailScreen(record: record, initialVisual: visual),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE9DDE2)),
              ),
              child: Row(
                children: [
                  BreedrNetworkImage(
                    imageUrl: visual.photoUrl,
                    width: 58,
                    height: 58,
                    borderRadius: BorderRadius.circular(12),
                    fallback: const ColoredBox(
                      color: Color(0xFFFFE4EB),
                      child: Center(
                        child: Icon(Icons.pets, color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Return: ${visual.petName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF27222D),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${record.reasonLabel} · ${_formatDate(record.createdAt)}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF948A9B),
                            fontSize: 12,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ReturnStatusBadge(record: record),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReturnDetailScreen extends StatelessWidget {
  final _ReturnRecord record;
  final _ReturnPetVisual initialVisual;

  const _ReturnDetailScreen({
    required this.record,
    required this.initialVisual,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF1F5),
      appBar: _returnAppBar(context, 'Return Detail'),
      body: FutureBuilder<_ReturnPetVisual>(
        future: _resolvePetVisual(record),
        initialData: initialVisual,
        builder: (context, snapshot) {
          final visual = snapshot.data ?? initialVisual;
          return ListView(
            padding: const EdgeInsets.fromLTRB(28, 16, 28, 36),
            children: [
              BreedrNetworkImage(
                imageUrl: visual.photoUrl,
                width: double.infinity,
                height: 220,
                borderRadius: BorderRadius.circular(22),
                fallback: const ColoredBox(
                  color: Color(0xFFFFE2E9),
                  child: Center(
                    child: Icon(Icons.pets, size: 72, color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _ReturnSummary(record: record, petName: visual.petName),
              const SizedBox(height: 20),
              const _SectionTitle('RETURN TIMELINE'),
              const SizedBox(height: 9),
              _ReturnTimeline(record: record),
              const SizedBox(height: 22),
              const _SectionTitle('RETURN DETAILS'),
              const SizedBox(height: 9),
              _SoftDetailBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Reason: ',
                            style: TextStyle(
                              color: Color(0xFFE83E4E),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          TextSpan(text: record.reasonLabel),
                        ],
                      ),
                      style: const TextStyle(
                        color: Color(0xFF5E5664),
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      record.description.isEmpty
                          ? 'No additional details were provided.'
                          : record.description,
                      style: const TextStyle(
                        color: Color(0xFF5E5664),
                        fontSize: 14,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const _SectionTitle('ADMIN DECISION'),
              const SizedBox(height: 9),
              _DecisionCard(record: record, petName: visual.petName),
              const SizedBox(height: 22),
              _SectionTitle(record.decisionSectionTitle),
              const SizedBox(height: 9),
              _SoftDetailBox(
                child: Text(
                  record.decisionExplanation(visual.petName),
                  style: const TextStyle(
                    color: Color(0xFF5E5664),
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReturnSummary extends StatelessWidget {
  final _ReturnRecord record;
  final String petName;

  const _ReturnSummary({required this.record, required this.petName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9DDE2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('ADOPTION RETURN'),
          const SizedBox(height: 7),
          Text(
            petName,
            style: const TextStyle(
              color: Color(0xFF2C2631),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 7,
            runSpacing: 5,
            children: [
              Text(
                'Filed ${_formatDate(record.createdAt)} ·',
                style: const TextStyle(color: Color(0xFF948A9B), fontSize: 13),
              ),
              _ReturnStatusBadge(record: record),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReturnTimeline extends StatelessWidget {
  final _ReturnRecord record;

  const _ReturnTimeline({required this.record});

  @override
  Widget build(BuildContext context) {
    final decided = record.isApproved || record.isDenied;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9DDE2)),
      ),
      child: Column(
        children: [
          _TimelineRow(
            title: 'Request filed',
            subtitle: _formatDate(record.createdAt),
            active: true,
            showLine: true,
          ),
          const _TimelineRow(
            title: 'Under review',
            subtitle: 'Checked against the 30-day protection window',
            active: true,
            showLine: true,
          ),
          _TimelineRow(
            title: record.isDenied
                ? 'Rejected'
                : record.isApproved
                ? 'Approved'
                : 'Decision pending',
            subtitle: decided
                ? _formatDate(record.resolvedAt)
                : 'Waiting for an admin decision',
            active: decided,
            showLine: false,
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool active;
  final bool showLine;

  const _TimelineRow({
    required this.title,
    required this.subtitle,
    required this.active,
    required this.showLine,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF279E69) : const Color(0xFFD9D1D7);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 27,
            child: Column(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                if (showLine)
                  Expanded(child: Container(width: 2, color: color)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF2C2631),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF948A9B),
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DecisionCard extends StatelessWidget {
  final _ReturnRecord record;
  final String petName;

  const _DecisionCard({required this.record, required this.petName});

  @override
  Widget build(BuildContext context) {
    final decision = record.isDenied
        ? 'Rejected'
        : record.isApproved
        ? 'Approved'
        : 'Under review';
    final handover = record.isDenied
        ? 'N/A — request denied'
        : record.isCompleted
        ? 'Completed — $petName picked up by original owner'
        : record.isApproved
        ? 'Waiting for both parties'
        : 'Not started';
    final completion = record.isDenied
        ? 'Closed, no return'
        : record.isCompleted
        ? 'Return complete'
        : record.isApproved
        ? 'Awaiting handover'
        : 'Awaiting decision';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9DDE2)),
      ),
      child: Column(
        children: [
          _DecisionRow(label: 'Decision', value: decision),
          _DecisionRow(
            label: 'Date decided',
            value: record.resolvedAt == null
                ? 'Pending'
                : _formatDate(record.resolvedAt),
          ),
          _DecisionRow(label: 'Pet handover status', value: handover),
          _DecisionRow(
            label: 'Return completion',
            value: completion,
            divider: false,
          ),
        ],
      ),
    );
  }
}

class _DecisionRow extends StatelessWidget {
  final String label;
  final String value;
  final bool divider;

  const _DecisionRow({
    required this.label,
    required this.value,
    this.divider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: divider
            ? const Border(bottom: BorderSide(color: Color(0xFFE9DDE2)))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF948A9B), fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF2C2631),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftDetailBox extends StatelessWidget {
  final Widget child;

  const _SoftDetailBox({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7F9),
      borderRadius: BorderRadius.circular(18),
    ),
    child: child,
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Color(0xFF918799),
      fontSize: 12,
      fontWeight: FontWeight.w900,
    ),
  );
}

class _ReturnStatusBadge extends StatelessWidget {
  final _ReturnRecord record;

  const _ReturnStatusBadge({required this.record});

  @override
  Widget build(BuildContext context) {
    final color = record.isApproved
        ? const Color(0xFF279E69)
        : record.isDenied
        ? const Color(0xFF8E8795)
        : const Color(0xFFC58A23);
    final background = record.isApproved
        ? const Color(0xFFE3F6EB)
        : record.isDenied
        ? const Color(0xFFF0EDF2)
        : const Color(0xFFFFF1D8);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        record.statusLabel,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ReturnEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _ReturnEmpty({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9DDE2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 38),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF948A9B), fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class _ReturnRecord {
  final String returnRequestId;
  final String conversationId;
  final String adoptionRequestId;
  final String petId;
  final String petName;
  final String reason;
  final String description;
  final String adminStatus;
  final String status;
  final String adminNote;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final DateTime? completedAt;

  const _ReturnRecord({
    required this.returnRequestId,
    required this.conversationId,
    required this.adoptionRequestId,
    required this.petId,
    required this.petName,
    required this.reason,
    required this.description,
    required this.adminStatus,
    required this.status,
    required this.adminNote,
    required this.createdAt,
    required this.resolvedAt,
    required this.completedAt,
  });

  factory _ReturnRecord.fromRequest(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return _ReturnRecord(
      returnRequestId: data['returnRequestId']?.toString() ?? document.id,
      conversationId: data['conversationId']?.toString() ?? '',
      adoptionRequestId: data['requestId']?.toString() ?? '',
      petId: data['petId']?.toString() ?? '',
      petName: data['petName']?.toString() ?? 'Pet',
      reason: data['reason']?.toString() ?? 'Other',
      description: data['description']?.toString().trim() ?? '',
      adminStatus:
          (data['adminStatus'] ?? data['adminDecision'] ?? data['status'])
              ?.toString()
              .toLowerCase() ??
          'pending',
      status: data['status']?.toString().toLowerCase() ?? 'pending',
      adminNote: data['adminNote']?.toString().trim() ?? '',
      createdAt: _dateFrom(data['createdAt']) ?? DateTime(1970),
      resolvedAt: _dateFrom(data['resolvedAt']),
      completedAt: _dateFrom(data['completedAt']),
    );
  }

  factory _ReturnRecord.fromReturnedPet(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return _ReturnRecord(
      returnRequestId: data['returnRequestId']?.toString() ?? document.id,
      conversationId: data['conversationId']?.toString() ?? '',
      adoptionRequestId: data['adoptionRequestId']?.toString() ?? '',
      petId: data['petId']?.toString() ?? '',
      petName: data['petName']?.toString() ?? 'Pet',
      reason: 'Approved return',
      description: '',
      adminStatus: 'approved',
      status: 'completed',
      adminNote: '',
      createdAt:
          _dateFrom(data['createdAt']) ??
          _dateFrom(data['completedAt']) ??
          DateTime(1970),
      resolvedAt: _dateFrom(data['completedAt']),
      completedAt: _dateFrom(data['completedAt']),
    );
  }

  bool get isDenied =>
      adminStatus == 'denied' ||
      adminStatus == 'rejected' ||
      status == 'denied' ||
      status == 'rejected';
  bool get isApproved =>
      !isDenied &&
      (adminStatus == 'approved' ||
          status == 'approved' ||
          status == 'completed');
  bool get isCompleted => status == 'completed' || completedAt != null;
  DateTime get sortDate => completedAt ?? resolvedAt ?? createdAt;

  String get statusLabel => isDenied
      ? 'Denied'
      : isApproved
      ? 'Approved'
      : 'Under review';
  String get reasonLabel {
    final normalized = reason.replaceAll('_', ' ').trim();
    if (normalized.isEmpty) return 'Other';
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  String get decisionSectionTitle => isDenied
      ? 'REASON FOR REJECTION'
      : isApproved
      ? 'REASON FOR APPROVAL'
      : 'ADMIN REVIEW';

  String decisionExplanation(String resolvedPetName) {
    if (adminNote.isNotEmpty) return adminNote;
    if (isDenied) {
      return 'The return request was reviewed and did not meet the requirements for approval. The adoption remains in effect.';
    }
    if (isCompleted) {
      return '$resolvedPetName has been returned to the original owner and the adoption record is now closed.';
    }
    if (isApproved) {
      return 'The return was approved. Both parties must arrange and confirm the physical handover.';
    }
    return 'The Breedr Team is reviewing the submitted return details and evidence.';
  }
}

class _ReturnPetVisual {
  final String petName;
  final String photoUrl;

  const _ReturnPetVisual({required this.petName, required this.photoUrl});

  factory _ReturnPetVisual.fallback(_ReturnRecord record) =>
      _ReturnPetVisual(petName: record.petName, photoUrl: '');
}

Future<_ReturnPetVisual> _resolvePetVisual(_ReturnRecord record) async {
  var name = record.petName;
  var photo = '';
  final firestore = FirebaseFirestore.instance;

  if (record.petId.isNotEmpty) {
    final pet = await firestore.collection('pets').doc(record.petId).get();
    final data = pet.data();
    name = _firstText(data, const ['name', 'petName'], name);
    photo = _firstText(data, const [
      'petProfilePhoto',
      'profilePhoto',
      'photoUrl',
    ], photo);
  }
  if ((photo.isEmpty || name == 'Pet') && record.adoptionRequestId.isNotEmpty) {
    final request = await firestore
        .collection('adoptionRequests')
        .doc(record.adoptionRequestId)
        .get();
    final snapshot = Map<String, dynamic>.from(
      request.data()?['petSnapshot'] as Map? ?? const {},
    );
    name = _firstText(snapshot, const ['name', 'petName'], name);
    photo = _firstText(snapshot, const [
      'petProfilePhoto',
      'profilePhoto',
      'photoUrl',
    ], photo);
  }
  if (photo.isEmpty && record.conversationId.isNotEmpty) {
    final conversation = await firestore
        .collection('conversations')
        .doc(record.conversationId)
        .get();
    final data = conversation.data() ?? const <String, dynamic>{};
    final names = Map<String, dynamic>.from(
      data['petNames'] as Map? ?? const {},
    );
    final photos = Map<String, dynamic>.from(
      data['petPhotos'] as Map? ?? const {},
    );
    name = _text(names[record.petId], name);
    photo = _text(photos[record.petId], photo);
  }
  return _ReturnPetVisual(petName: name, photoUrl: photo);
}

String _firstText(
  Map<String, dynamic>? data,
  List<String> keys,
  String fallback,
) {
  if (data == null) return fallback;
  for (final key in keys) {
    final value = _text(data[key], '');
    if (value.isNotEmpty) return value;
  }
  return fallback;
}

String _text(Object? value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

DateTime? _dateFrom(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String _formatDate(DateTime? date) {
  if (date == null || date.year <= 1970) return 'Date unavailable';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

PreferredSizeWidget _returnAppBar(BuildContext context, String title) {
  return AppBar(
    backgroundColor: const Color(0xFFFFF7F9),
    elevation: 0,
    toolbarHeight: 78,
    automaticallyImplyLeading: false,
    titleSpacing: 22,
    title: Row(
      children: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 2,
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.chevron_left, color: AppColors.primary),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF27222D),
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}
