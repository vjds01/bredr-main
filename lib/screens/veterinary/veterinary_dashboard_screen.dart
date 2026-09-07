import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/user_session_service.dart';
import '../../widgets/breedr_network_image.dart';
import '../auth/get_started_screen.dart';

class VeterinaryDashboardScreen extends StatefulWidget {
  const VeterinaryDashboardScreen({super.key});

  @override
  State<VeterinaryDashboardScreen> createState() =>
      _VeterinaryDashboardScreenState();
}

class _VeterinaryDashboardScreenState extends State<VeterinaryDashboardScreen> {
  final _searchController = TextEditingController();
  String _filter = 'pending';
  bool _saving = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _decide(_VerificationItem item, String status) async {
    if (_saving) return;
    final requiresNote = status != 'verified';
    final note = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _VerificationDecisionDialog(
        status: status,
        requiresNote: requiresNote,
      ),
    );
    if (note == null || !mounted) return;

    final user = UserSessionService.instance.currentUser;
    if (user == null || item.ownerId == user.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot verify your own pet record.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final petReference = FirebaseFirestore.instance
          .collection('pets')
          .doc(item.petId);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final pet = await transaction.get(petReference);
        final data = pet.data();
        if (data == null) throw StateError('Pet record no longer exists.');
        final records = (data['healthRecords'] as List? ?? const [])
            .map((value) => Map<String, dynamic>.from(value as Map))
            .toList();
        final index = records.indexWhere(
          (record) => item.recordId.isNotEmpty
              ? record['recordId'] == item.recordId
              : record['fileUrl'] == item.fileUrl &&
                    record['dateIssued'] == item.dateIssued,
        );
        if (index < 0) throw StateError('Health record was replaced.');
        records[index] = {
          ...records[index],
          'verificationStatus': status,
          'verificationNote': note,
          'verifiedBy': user.uid,
          'verifiedByName': user.displayName ?? 'Veterinary Reviewer',
          // Server timestamp sentinels cannot be nested inside an array value.
          'verifiedAt': Timestamp.now(),
        };
        final verifiedCount = records
            .where((record) => record['verificationStatus'] == 'verified')
            .length;
        transaction.update(petReference, {
          'healthRecords': records,
          'vetVerified': verifiedCount > 0,
          'verifiedHealthRecordCount': verifiedCount,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final notification = FirebaseFirestore.instance
            .collection('notifications')
            .doc();
        transaction.set(notification, {
          'notificationId': notification.id,
          'recipientId': item.ownerId,
          'actorId': user.uid,
          'petId': item.petId,
          'petName': item.petName,
          'type': 'health_record_$status',
          'purpose': 'health',
          'title': status == 'verified'
              ? 'Health record verified'
              : status == 'rejected'
              ? 'Health record rejected'
              : 'Health record replacement requested',
          'message': note.isEmpty
              ? '${item.displayType} for ${item.petName} was verified.'
              : note,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        final activity = FirebaseFirestore.instance
            .collection('veterinaryActivity')
            .doc();
        transaction.set(activity, {
          'veterinaryAdminId': user.uid,
          'petId': item.petId,
          'recordId': item.recordId,
          'action': status,
          'note': note,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification decision saved.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save decision: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'Are you sure you want to leave the Veterinary Admin console?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await UserSessionService.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const GetStartedScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4F7),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Health Verifications'),
            Text(
              'Veterinary Reviewer',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('pets').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final query = _searchController.text.trim().toLowerCase();
          final items =
              snapshot.data!.docs
                  .expand(_VerificationItem.fromPet)
                  .where((item) => _filter == 'all' || item.status == _filter)
                  .where((item) => query.isEmpty || item.matches(query))
                  .toList()
                ..sort((a, b) => a.submittedAt.compareTo(b.submittedAt));
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search pet, record, veterinarian, or clinic',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close),
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SegmentedButton<String>(
                  expandedInsets: EdgeInsets.zero,
                  segments: const [
                    ButtonSegment(
                      value: 'pending',
                      label: FittedBox(child: Text('Pending')),
                    ),
                    ButtonSegment(
                      value: 'verified',
                      label: FittedBox(child: Text('Verified')),
                    ),
                    ButtonSegment(
                      value: 'rejected',
                      label: FittedBox(child: Text('Rejected')),
                    ),
                    ButtonSegment(
                      value: 'all',
                      label: FittedBox(child: Text('All')),
                    ),
                  ],
                  style: const ButtonStyle(
                    textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
                    padding: WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                  selected: {_filter},
                  onSelectionChanged: (value) =>
                      setState(() => _filter = value.first),
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text(
                          query.isEmpty
                              ? 'No health records here.'
                              : 'No health records match your search.',
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: items.length,
                        itemBuilder: (_, index) => _VerificationCard(
                          item: items[index],
                          enabled: !_saving,
                          onDecision: (status) => _decide(items[index], status),
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

class _VerificationDecisionDialog extends StatefulWidget {
  final String status;
  final bool requiresNote;

  const _VerificationDecisionDialog({
    required this.status,
    required this.requiresNote,
  });

  @override
  State<_VerificationDecisionDialog> createState() =>
      _VerificationDecisionDialogState();
}

class _VerificationDecisionDialogState
    extends State<_VerificationDecisionDialog> {
  final _noteController = TextEditingController();
  bool _showError = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.status == 'verified'
            ? 'Verify health record?'
            : widget.status == 'rejected'
            ? 'Reject health record?'
            : 'Request replacement?',
      ),
      content: TextField(
        controller: _noteController,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: widget.requiresNote
              ? 'Explanation (required)'
              : 'Veterinary note (optional)',
          errorText: _showError ? 'Please enter an explanation.' : null,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) {
          if (_showError) setState(() => _showError = false);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final note = _noteController.text.trim();
            if (widget.requiresNote && note.isEmpty) {
              setState(() => _showError = true);
              return;
            }
            Navigator.pop(context, note);
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

class _VerificationCard extends StatelessWidget {
  final _VerificationItem item;
  final bool enabled;
  final ValueChanged<String> onDecision;

  const _VerificationCard({
    required this.item,
    required this.enabled,
    required this.onDecision,
  });

  void _showFullRecord(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5,
                  child: Center(
                    child: BreedrNetworkImage(
                      imageUrl: item.fileUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.contain,
                      fallback: const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white70,
                        size: 72,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filled(
                  tooltip: 'Close document',
                  onPressed: () => Navigator.pop(dialogContext),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.close),
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 18,
                child: Text(
                  'Pinch to zoom • Drag to move',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.petName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('${item.displayType} · ${item.dateIssued}'),
            Text('${item.veterinarian} · ${item.clinic}'),
            const SizedBox(height: 10),
            Semantics(
              button: true,
              label: 'View ${item.displayType} for ${item.petName}',
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _showFullRecord(context),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: BreedrNetworkImage(
                        imageUrl: item.fileUrl,
                        height: 180,
                        width: double.infinity,
                        fallback: const Center(
                          child: Icon(Icons.description, size: 48),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.fullscreen,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (item.status == 'pending')
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: enabled ? () => onDecision('rejected') : null,
                    child: const Text('Reject'),
                  ),
                  OutlinedButton(
                    onPressed: enabled
                        ? () => onDecision('replacement_requested')
                        : null,
                    child: const Text('Request replacement'),
                  ),
                  FilledButton(
                    onPressed: enabled ? () => onDecision('verified') : null,
                    child: const Text('Verify'),
                  ),
                ],
              )
            else
              Chip(label: Text(item.status.replaceAll('_', ' '))),
          ],
        ),
      ),
    );
  }
}

class _VerificationItem {
  final String petId;
  final String petName;
  final String ownerId;
  final String recordId;
  final String type;
  final String otherType;
  final String fileUrl;
  final String dateIssued;
  final String veterinarian;
  final String clinic;
  final String status;
  final DateTime submittedAt;

  const _VerificationItem({
    required this.petId,
    required this.petName,
    required this.ownerId,
    required this.recordId,
    required this.type,
    required this.otherType,
    required this.fileUrl,
    required this.dateIssued,
    required this.veterinarian,
    required this.clinic,
    required this.status,
    required this.submittedAt,
  });

  String get displayType =>
      type == 'Other' && otherType.isNotEmpty ? otherType : type;

  bool matches(String query) {
    return [
      petName,
      displayType,
      veterinarian,
      clinic,
      dateIssued,
    ].any((value) => value.toLowerCase().contains(query));
  }

  static Iterable<_VerificationItem> fromPet(
    QueryDocumentSnapshot<Map<String, dynamic>> pet,
  ) {
    final data = pet.data();
    final records = data['healthRecords'] as List? ?? const [];
    return records.asMap().entries.map((entry) {
      final record = Map<String, dynamic>.from(entry.value as Map);
      final timestamp = record['updatedAt'] as Timestamp?;
      return _VerificationItem(
        petId: pet.id,
        petName: data['name']?.toString() ?? 'Pet',
        ownerId: data['ownerId']?.toString() ?? '',
        recordId: record['recordId']?.toString() ?? '',
        type: record['type']?.toString() ?? 'Health record',
        otherType: record['otherType']?.toString().trim() ?? '',
        fileUrl: record['fileUrl']?.toString() ?? '',
        dateIssued: record['dateIssued']?.toString() ?? '',
        veterinarian: record['veterinarian']?.toString() ?? '',
        clinic: record['clinic']?.toString() ?? '',
        status: record['verificationStatus']?.toString() ?? 'pending',
        submittedAt: timestamp?.toDate() ?? DateTime(2000, 1, 1),
      );
    });
  }
}
