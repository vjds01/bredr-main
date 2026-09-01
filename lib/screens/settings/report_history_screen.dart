import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/user_session_service.dart';
import '../../theme/app_colors.dart';

class ReportHistoryScreen extends StatelessWidget {
  const ReportHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = UserSessionService.instance.currentUser?.uid;
    if (userId == null) {
      return const Scaffold(body: Center(child: Text('Please sign in again.')));
    }
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7FA),
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.primary,
        title: const Text(
          'Report History',
          style: TextStyle(
            color: Color(0xFF222222),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .where('reporterId', isEqualTo: userId)
            .snapshots(),
        builder: (context, reportSnapshot) {
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .snapshots(),
            builder: (context, userSnapshot) {
              if (reportSnapshot.hasError) {
                return const _ReportEmpty(
                  icon: Icons.cloud_off_outlined,
                  title: 'Unable to load report history',
                  message: 'Check your connection and try again.',
                );
              }
              if (!reportSnapshot.hasData || !userSnapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }
              final items = <_ReportHistoryItem>[
                ...reportSnapshot.data!.docs.map(
                  (doc) => _ReportHistoryItem.filed(doc.id, doc.data()),
                ),
                ...((userSnapshot.data!.data()?['moderationHistory'] as List? ??
                        const [])
                    .whereType<Map>()
                    .map(
                      (entry) => _ReportHistoryItem.received(
                        Map<String, dynamic>.from(entry),
                      ),
                    )),
              ]..sort((a, b) => b.date.compareTo(a.date));
              if (items.isEmpty) {
                return const _ReportEmpty(
                  icon: Icons.flag_outlined,
                  title: 'No reports yet',
                  message:
                      'Reports you file and resolved reports about your account will appear here.',
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                children: [
                  const Text(
                    "Every report you've filed, and where it stands. Status updates automatically once an admin reviews it.",
                    style: TextStyle(
                      color: Color(0xFF8A8290),
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  for (final item in items) ...[
                    _ReportHistoryCard(item: item),
                    const SizedBox(height: 14),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ReportHistoryCard extends StatelessWidget {
  final _ReportHistoryItem item;

  const _ReportHistoryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => _ReportDetailScreen(item: item),
        ),
      ),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFFFD7DF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFFFDFE7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                item.isProfile ? Icons.person_outline : Icons.flag_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF222222),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${item.reason} • ${_date(item.date)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF8A8290),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _StatusBadge(status: item.status),
          ],
        ),
      ),
    );
  }
}

class _ReportDetailScreen extends StatelessWidget {
  final _ReportHistoryItem item;

  const _ReportDetailScreen({required this.item});

  @override
  Widget build(BuildContext context) {
    final resolved = item.isResolved;
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7FA),
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.primary,
        title: const Text(
          'Report Detail',
          style: TextStyle(
            color: Color(0xFF222222),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 34),
        children: [
          _DetailBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.isProfile ? 'PROFILE REPORT' : 'PET LISTING REPORT',
                  style: const TextStyle(
                    color: Color(0xFF8A8290),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.reason,
                  style: const TextStyle(color: Color(0xFF8A8290)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _DetailLabel('CURRENT STATUS'),
          const SizedBox(height: 8),
          _DetailBox(
            child: Row(
              children: [
                const Expanded(child: Text('Status')),
                _StatusBadge(status: item.status),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _DetailLabel('RESOLUTION TIMELINE'),
          const SizedBox(height: 8),
          _DetailBox(
            child: Column(
              children: [
                _TimelineStep(
                  label: 'Report filed',
                  detail: _date(item.date),
                  complete: true,
                ),
                const _TimelineStep(
                  label: 'Under review',
                  detail: 'An admin is checking the details',
                  complete: true,
                ),
                _TimelineStep(
                  label: item.status == 'dismissed' ? 'Dismissed' : 'Resolved',
                  detail: resolved
                      ? _date(item.resolvedAt ?? item.date)
                      : 'Pending',
                  complete: resolved,
                  last: true,
                ),
              ],
            ),
          ),
          if (item.detail.isNotEmpty) ...[
            const SizedBox(height: 18),
            const _DetailLabel('REASON YOU FILED THIS REPORT'),
            const SizedBox(height: 8),
            _DetailBox(
              child: Text(item.detail, style: const TextStyle(height: 1.45)),
            ),
          ],
          if (resolved && item.adminAction.isNotEmpty) ...[
            const SizedBox(height: 18),
            const _DetailLabel('FINAL DECISION'),
            const SizedBox(height: 8),
            _DetailBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.adminAction,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  if (item.adminNote.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(item.adminNote, style: const TextStyle(height: 1.45)),
                  ],
                ],
              ),
            ),
          ],
          if (!resolved) ...[
            const SizedBox(height: 18),
            const _DetailBox(
              color: Color(0xFFFFF7FA),
              child: Text(
                "We typically review reports within 48 hours. You'll see an update here as soon as a decision is made.",
                style: TextStyle(color: Color(0xFF8A8290), height: 1.4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReportHistoryItem {
  final String id;
  final String title;
  final String reason;
  final String detail;
  final String status;
  final String adminAction;
  final String adminNote;
  final bool isProfile;
  final DateTime date;
  final DateTime? resolvedAt;

  const _ReportHistoryItem({
    required this.id,
    required this.title,
    required this.reason,
    required this.detail,
    required this.status,
    required this.adminAction,
    required this.adminNote,
    required this.isProfile,
    required this.date,
    this.resolvedAt,
  });

  bool get isResolved => status == 'resolved' || status == 'dismissed';

  factory _ReportHistoryItem.filed(String id, Map<String, dynamic> data) {
    final target = Map<String, dynamic>.from(
      data['targetSnapshot'] as Map? ?? const {},
    );
    final type = (data['type'] ?? '').toString();
    final status = (data['status'] ?? 'pending').toString().toLowerCase();
    final adminAction = (data['adminAction'] ?? '').toString();
    final targetName = _first(target, const [
      'petName',
      'name',
      'displayName',
      'ownerName',
      'fullName',
    ]);
    return _ReportHistoryItem(
      id: id,
      title:
          'Reported: ${type == 'user' ? 'Profile — ' : ''}${targetName.isEmpty ? 'Breedr listing' : targetName}',
      reason: (data['reason'] ?? 'Report submitted').toString(),
      detail: (data['detail'] ?? '').toString(),
      status: adminAction.toLowerCase().contains('dismiss')
          ? 'dismissed'
          : status == 'pending'
          ? 'under_review'
          : status,
      adminAction: adminAction,
      adminNote: (data['userNote'] ?? '').toString(),
      isProfile: type == 'user',
      date: _timestamp(data['createdAt']),
      resolvedAt: data['resolvedAt'] is Timestamp
          ? (data['resolvedAt'] as Timestamp).toDate()
          : null,
    );
  }

  factory _ReportHistoryItem.received(Map<String, dynamic> data) {
    return _ReportHistoryItem(
      id: 'received_${_timestamp(data['createdAt']).millisecondsSinceEpoch}',
      title: 'Report about your account',
      reason: (data['category'] ?? data['severity'] ?? 'Account review')
          .toString(),
      detail: '',
      status: 'resolved',
      adminAction: (data['action'] ?? 'Resolved').toString(),
      adminNote: (data['userNote'] ?? '').toString(),
      isProfile: true,
      date: _timestamp(data['createdAt']),
      resolvedAt: _timestamp(data['createdAt']),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final resolved = status == 'resolved';
    final dismissed = status == 'dismissed';
    final color = resolved
        ? const Color(0xFF299E68)
        : dismissed
        ? const Color(0xFF777777)
        : const Color(0xFFB27B17);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        resolved
            ? 'Resolved'
            : dismissed
            ? 'Dismissed'
            : 'Under review',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final String label;
  final String detail;
  final bool complete;
  final bool last;
  const _TimelineStep({
    required this.label,
    required this.detail,
    required this.complete,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = complete ? const Color(0xFF299E68) : const Color(0xFFE8DDE1);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                CircleAvatar(radius: 8, backgroundColor: color),
                if (!last) Expanded(child: Container(width: 2, color: color)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    detail,
                    style: const TextStyle(
                      color: Color(0xFF8A8290),
                      fontSize: 11,
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

class _DetailBox extends StatelessWidget {
  final Widget child;
  final Color color;
  const _DetailBox({required this.child, this.color = Colors.white});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFFFDCE3)),
    ),
    child: child,
  );
}

class _DetailLabel extends StatelessWidget {
  final String text;
  const _DetailLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Color(0xFF8A8290),
      fontSize: 10,
      fontWeight: FontWeight.w900,
    ),
  );
}

class _ReportEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _ReportEmpty({
    required this.icon,
    required this.title,
    required this.message,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 52),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF777777)),
          ),
        ],
      ),
    ),
  );
}

String _first(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}

DateTime _timestamp(Object? value) => value is Timestamp
    ? value.toDate()
    : DateTime.fromMillisecondsSinceEpoch(0);

String _date(DateTime value) {
  if (value.millisecondsSinceEpoch == 0) return 'Date unavailable';
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
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}
