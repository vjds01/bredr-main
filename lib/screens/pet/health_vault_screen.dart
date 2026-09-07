import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/cloudinary_service.dart';
import '../../services/user_session_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/breedr_network_image.dart';

class HealthVaultScreen extends StatefulWidget {
  final String? initialPetId;

  const HealthVaultScreen({super.key, this.initialPetId});

  @override
  State<HealthVaultScreen> createState() => _HealthVaultScreenState();
}

class _HealthVaultScreenState extends State<HealthVaultScreen> {
  final _cloudinary = CloudinaryService();
  String? _selectedPetId;

  @override
  void initState() {
    super.initState();
    _selectedPetId = widget.initialPetId;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _petsStream() {
    final userId = UserSessionService.instance.currentUser?.uid;
    if (userId == null) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }

    return FirebaseFirestore.instance
        .collection('pets')
        .where('ownerId', isEqualTo: userId)
        .snapshots();
  }

  Future<void> _openEditor({
    required DocumentSnapshot<Map<String, dynamic>> pet,
    Map<String, dynamic>? record,
    int? index,
  }) async {
    final petDataBeforeEdit = pet.data() ?? const <String, dynamic>{};
    if (_isAdoptedHealthPet(petDataBeforeEdit)) {
      _showAdoptedPetMessage();
      return;
    }

    final result = await showModalBottomSheet<_HealthRecordEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HealthRecordEditorDialog(initialRecord: record),
    );
    if (result == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Uploading health record...')));

    try {
      final freshPet = await pet.reference.get();
      final petData = freshPet.data() ?? const <String, dynamic>{};
      if (_isAdoptedHealthPet(petData)) {
        _showAdoptedPetMessage();
        return;
      }
      final records = (petData['healthRecords'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      final fileUrl = result.file == null
          ? (record?['fileUrl'] as String? ?? '')
          : await _cloudinary.uploadImageOrThrow(result.file!);
      final updatedRecord = {
        'recordId': record?['recordId']?.toString().isNotEmpty == true
            ? record!['recordId']
            : '${pet.id}_${DateTime.now().microsecondsSinceEpoch}',
        'type': result.type,
        'otherType': result.otherType,
        'fileName': result.fileName,
        'fileUrl': fileUrl,
        'dateIssued': result.dateIssued,
        'nextUpdate': result.nextUpdate,
        'veterinarian': result.veterinarian,
        'clinic': result.clinic,
        'verificationStatus': 'pending',
        'updatedAt': Timestamp.now(),
      };

      if (index == null) {
        records.add(updatedRecord);
      } else if (index >= 0 && index < records.length) {
        records[index] = updatedRecord;
      }

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final latestPet = await transaction.get(pet.reference);
        if (_isAdoptedHealthPet(latestPet.data() ?? const {})) {
          throw StateError('adopted-pet-read-only');
        }
        transaction.update(pet.reference, {
          'healthRecords': records,
          'hasHealthRecords': records.isNotEmpty,
          'vetVerified': records.any(
            (item) => item['verificationStatus'] == 'verified',
          ),
          'verifiedHealthRecordCount': records
              .where((item) => item['verificationStatus'] == 'verified')
              .length,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Health record saved.')));
    } catch (error) {
      debugPrint('Health record save failed: $error');
      if (!mounted) return;
      if (error is StateError && error.message == 'adopted-pet-read-only') {
        _showAdoptedPetMessage();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save the health record. Please try again.'),
        ),
      );
    }
  }

  void _showAdoptedPetMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'This pet has already been adopted. Its health records are read-only.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _petsStream(),
          builder: (context, snapshot) {
            final pets = snapshot.data?.docs.toList() ?? [];
            pets.sort((a, b) {
              final aName = (a.data()['name'] as String? ?? '').toLowerCase();
              final bName = (b.data()['name'] as String? ?? '').toLowerCase();
              return aName.compareTo(bName);
            });

            if (_selectedPetId == null && pets.isNotEmpty) {
              _selectedPetId = pets.first.id;
            }

            final selectedPet = pets
                .where((pet) => pet.id == _selectedPetId)
                .firstOrNull;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 18, 26, 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Health Vault',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  )
                else if (pets.isEmpty)
                  const Expanded(child: _HealthVaultEmptyState())
                else ...[
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 42),
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (context, index) {
                        final pet = pets[index];
                        final data = pet.data();
                        return _HealthPetTab(
                          name: data['name'] as String? ?? 'Pet',
                          photoUrl: data['petProfilePhoto'] as String? ?? '',
                          selected: pet.id == selectedPet?.id,
                          onTap: () => setState(() => _selectedPetId = pet.id),
                        );
                      },
                      separatorBuilder: (_, _) => const SizedBox(width: 18),
                      itemCount: pets.length,
                    ),
                  ),
                  Expanded(
                    child: selectedPet == null
                        ? const SizedBox.shrink()
                        : _HealthVaultPetBody(
                            pet: selectedPet,
                            onAdd: _isAdoptedHealthPet(selectedPet.data())
                                ? null
                                : () => _openEditor(pet: selectedPet),
                            onReplace: _isAdoptedHealthPet(selectedPet.data())
                                ? null
                                : (record, index) => _openEditor(
                                    pet: selectedPet,
                                    record: record,
                                    index: index,
                                  ),
                          ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HealthVaultPetBody extends StatelessWidget {
  final DocumentSnapshot<Map<String, dynamic>> pet;
  final VoidCallback? onAdd;
  final void Function(Map<String, dynamic> record, int index)? onReplace;

  const _HealthVaultPetBody({
    required this.pet,
    required this.onAdd,
    required this.onReplace,
  });

  @override
  Widget build(BuildContext context) {
    final data = pet.data() ?? const <String, dynamic>{};
    final records = (data['healthRecords'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final dueSoon = records.firstWhere(
      (record) =>
          record['verificationStatus'] == 'verified' &&
          _isDueSoonRecord(record),
      orElse: () => const <String, dynamic>{},
    );
    final readOnly = _isAdoptedHealthPet(data);

    return ListView(
      padding: const EdgeInsets.fromLTRB(42, 0, 42, 28),
      children: [
        if (readOnly) ...[
          const _AdoptedHealthReadOnlyNotice(),
          const SizedBox(height: 14),
        ],
        if (dueSoon.isNotEmpty) ...[
          _HealthDueSoonBanner(record: dueSoon),
          const SizedBox(height: 22),
        ],
        if (records.isEmpty)
          const _HealthNoRecordsCard()
        else
          ...records.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _HealthVaultRecordCard(
                record: entry.value,
                onView: () =>
                    _showHealthRecordPreview(context, record: entry.value),
                onReplace: onReplace == null
                    ? null
                    : () => onReplace!(entry.value, entry.key),
              ),
            ),
          ),
        const SizedBox(height: 6),
        if (onAdd != null) _HealthAddButton(onTap: onAdd!),
      ],
    );
  }
}

class _AdoptedHealthReadOnlyNotice extends StatelessWidget {
  const _AdoptedHealthReadOnlyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEDF1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFB5C2)),
      ),
      child: const Text(
        'This pet has already been adopted. Existing health records can be viewed but can no longer be changed.',
        style: TextStyle(
          color: Color(0xFF9A4454),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

bool _isAdoptedHealthPet(Map<String, dynamic> data) {
  return (data['status'] ?? '').toString().trim().toLowerCase() == 'adopted' ||
      (data['adoptionStatus'] ?? '').toString().trim().toLowerCase() ==
          'adopted';
}

class _HealthPetTab extends StatelessWidget {
  final String name;
  final String photoUrl;
  final bool selected;
  final VoidCallback onTap;

  const _HealthPetTab({
    required this.name,
    required this.photoUrl,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFCDD5),
                border: Border.all(
                  color: selected ? AppColors.primary : Colors.white,
                  width: 3,
                ),
                boxShadow: selected
                    ? const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: ClipOval(
                child: BreedrNetworkImage(
                  imageUrl: photoUrl,
                  width: 62,
                  height: 62,
                  fallback: const _PetFallbackIcon(),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? AppColors.primary : const Color(0xFF222222),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthDueSoonBanner extends StatelessWidget {
  final Map<String, dynamic> record;

  const _HealthDueSoonBanner({required this.record});

  @override
  Widget build(BuildContext context) {
    final nextUpdate = _recordNextUpdate(record);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1DA),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFF9800)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.health_and_safety_outlined,
            color: Color(0xFFFF9800),
            size: 58,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vet Verified - Due Soon',
                  style: TextStyle(
                    color: Color(0xFFFF9800),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  nextUpdate.isEmpty
                      ? 'A health record is due soon. Upload a new record to keep the badge.'
                      : 'Next health update: $nextUpdate. Upload a new record when it is ready.',
                  style: const TextStyle(
                    color: Color(0xFFFF8A00),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthVaultRecordCard extends StatelessWidget {
  final Map<String, dynamic> record;
  final VoidCallback onView;
  final VoidCallback? onReplace;

  const _HealthVaultRecordCard({
    required this.record,
    required this.onView,
    required this.onReplace,
  });

  @override
  Widget build(BuildContext context) {
    final rawType = record['type'] as String? ?? 'Health Record';
    final otherType = record['otherType']?.toString().trim() ?? '';
    final type = rawType == 'Other' && otherType.isNotEmpty
        ? otherType
        : rawType;
    final fileName = record['fileName'] as String? ?? '';
    final dateIssued = record['dateIssued'] as String? ?? '';
    final nextUpdate = _recordNextUpdate(record);
    final dueSoon = _isDueSoonRecord(record);
    final verificationStatus =
        record['verificationStatus']?.toString() ?? 'pending';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1D78FF), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.description_outlined,
                color: Color(0xFF1D78FF),
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type,
                      style: const TextStyle(
                        color: Color(0xFF222222),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      fileName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF777777),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const _HealthMiniDocument(),
              const SizedBox(width: 10),
              _HealthStatusPill(
                label: verificationStatus == 'verified'
                    ? (dueSoon ? 'Due Soon' : 'Verified')
                    : verificationStatus == 'rejected'
                    ? 'Rejected'
                    : verificationStatus == 'replacement_requested'
                    ? 'Replace'
                    : 'Pending',
                dueSoon: dueSoon || verificationStatus != 'verified',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HealthDateBox(label: 'DATE ISSUED', value: dateIssued),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: _HealthDateBox(label: 'NEXT UPDATE', value: nextUpdate),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HealthBlueButton(
                  icon: Icons.visibility,
                  label: 'VIEW',
                  onTap: onView,
                ),
              ),
              if (onReplace != null) ...[
                const SizedBox(width: 18),
                Expanded(
                  child: _HealthBlueButton(
                    icon: Icons.sync,
                    label: 'REPLACE',
                    onTap: onReplace!,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _HealthMiniDocument extends StatelessWidget {
  const _HealthMiniDocument();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFEFFFEF),
        border: Border.all(color: const Color(0xFFAAAAAA)),
      ),
      child: const Center(
        child: Text(
          'VACC',
          style: TextStyle(
            color: Color(0xFF56C14A),
            fontSize: 8,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _HealthStatusPill extends StatelessWidget {
  final String label;
  final bool dueSoon;

  const _HealthStatusPill({required this.label, required this.dueSoon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: dueSoon ? const Color(0xFFFFDDE6) : const Color(0xFFD9F7D8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: dueSoon ? AppColors.primary : const Color(0xFF299B28),
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _HealthDateBox extends StatelessWidget {
  final String label;
  final String value;

  const _HealthDateBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFFB5C9DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF555555),
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? 'Not set' : value,
            style: const TextStyle(
              color: Color(0xFF222222),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthBlueButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HealthBlueButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0050B4),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _HealthAddButton extends StatelessWidget {
  final VoidCallback onTap;

  const _HealthAddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF0050B4), width: 1.5),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle, color: Color(0xFF0050B4), size: 28),
            SizedBox(width: 12),
            Text(
              'Add pet health record',
              style: TextStyle(
                color: Color(0xFF0050B4),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthNoRecordsCard extends StatelessWidget {
  const _HealthNoRecordsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFB5C2)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.medical_information_outlined,
            color: AppColors.primary,
            size: 46,
          ),
          SizedBox(height: 8),
          Text(
            'No health records yet',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Add vaccination, deworming, or clinic records here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF777777)),
          ),
        ],
      ),
    );
  }
}

class _HealthVaultEmptyState extends StatelessWidget {
  const _HealthVaultEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pets, color: AppColors.primary, size: 58),
            SizedBox(height: 12),
            Text(
              'No pets yet',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Your pet health records will appear here once you add a pet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF777777)),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthRecordEditResult {
  final String type;
  final String otherType;
  final String fileName;
  final File? file;
  final String dateIssued;
  final String nextUpdate;
  final String veterinarian;
  final String clinic;

  const _HealthRecordEditResult({
    required this.type,
    required this.otherType,
    required this.fileName,
    required this.file,
    required this.dateIssued,
    required this.nextUpdate,
    required this.veterinarian,
    required this.clinic,
  });
}

class _HealthRecordEditorDialog extends StatefulWidget {
  final Map<String, dynamic>? initialRecord;

  const _HealthRecordEditorDialog({this.initialRecord});

  @override
  State<_HealthRecordEditorDialog> createState() =>
      _HealthRecordEditorDialogState();
}

class _HealthRecordEditorDialogState extends State<_HealthRecordEditorDialog> {
  final _dateController = TextEditingController();
  final _nextUpdateController = TextEditingController();
  final _vetController = TextEditingController();
  final _clinicController = TextEditingController();
  final _otherTypeController = TextEditingController();
  String _type = 'Vaccination';
  String _fileName = '';
  File? _file;
  bool _validationAttempted = false;

  static const _types = [
    'Vaccination',
    'Deworming',
    'Vet Checkup',
    'DNA check',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final record = widget.initialRecord;
    if (record == null) return;
    final savedType = record['type'] as String? ?? _type;
    if (_types.contains(savedType)) {
      _type = savedType;
      _otherTypeController.text = record['otherType']?.toString() ?? '';
    } else {
      _type = 'Other';
      _otherTypeController.text = savedType;
    }
    _fileName = record['fileName'] as String? ?? '';
    _dateController.text = record['dateIssued'] as String? ?? '';
    _nextUpdateController.text = _recordNextUpdate(record);
    _vetController.text = record['veterinarian'] as String? ?? '';
    _clinicController.text = record['clinic'] as String? ?? '';
  }

  @override
  void dispose() {
    _dateController.dispose();
    _nextUpdateController.dispose();
    _vetController.dispose();
    _clinicController.dispose();
    _otherTypeController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _parseHealthDate(_dateController.text) ??
          _parseNamedHealthDate(_dateController.text) ??
          now,
      firstDate: DateTime(now.year - 30),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    setState(() {
      _dateController.text = _formatHealthDate(picked);
      _nextUpdateController.text = _formatHealthDate(
        DateTime(picked.year + 1, picked.month, picked.day),
      );
    });
  }

  Future<void> _pickNextUpdate() async {
    final now = DateTime.now();
    final initial =
        _parseHealthDate(_nextUpdateController.text) ??
        _parseNamedHealthDate(_nextUpdateController.text) ??
        now.add(const Duration(days: 365));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now,
      lastDate: DateTime(now.year + 20),
    );
    if (picked == null) return;
    setState(() => _nextUpdateController.text = _formatHealthDate(picked));
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png'],
        allowMultiple: false,
        withData: false,
      );
      final file = result?.files.single;
      final path = file?.path;
      if (path == null || path.isEmpty) return;
      setState(() {
        _file = File(path);
        _fileName = file?.name ?? path.split(Platform.pathSeparator).last;
      });
    } catch (error) {
      debugPrint('Health file picker failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open files. Please try again.'),
        ),
      );
    }
  }

  Future<void> _takePhoto() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
    );
    if (photo == null) return;
    setState(() {
      _file = File(photo.path);
      _fileName = photo.name;
    });
  }

  void _submit() {
    setState(() => _validationAttempted = true);
    if (_fileName.isEmpty ||
        _dateController.text.trim().isEmpty ||
        _nextUpdateController.text.trim().isEmpty ||
        _vetController.text.trim().isEmpty ||
        _clinicController.text.trim().isEmpty ||
        (_type == 'Other' && _otherTypeController.text.trim().isEmpty)) {
      return;
    }

    showDialog<bool>(
      context: context,
      builder: (_) => _HealthVerificationDialog(
        onConfirm: () => Navigator.pop(context, true),
      ),
    ).then((confirmed) {
      if (confirmed != true || !mounted) return;
      Navigator.pop(
        context,
        _HealthRecordEditResult(
          type: _type,
          otherType: _type == 'Other' ? _otherTypeController.text.trim() : '',
          fileName: _fileName,
          file: _file,
          dateIssued: _dateController.text.trim(),
          nextUpdate: _nextUpdateController.text.trim(),
          veterinarian: _vetController.text.trim(),
          clinic: _clinicController.text.trim(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.94,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              color: Color(0xFF0050B4),
              padding: const EdgeInsets.fromLTRB(22, 14, 12, 14),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'ADD HEALTH RECORD',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(26, 24, 26, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _HealthEditorLabel('DOCUMENT TYPE'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: _types.map((type) {
                        final selected = _type == type;
                        return ChoiceChip(
                          label: Text(type),
                          selected: selected,
                          selectedColor: const Color(0xFFD8EAFF),
                          backgroundColor: const Color(0xFFEAF3FF),
                          labelStyle: const TextStyle(
                            color: Color(0xFF0050B4),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                          showCheckmark: false,
                          side: BorderSide.none,
                          onSelected: (_) => setState(() => _type = type),
                        );
                      }).toList(),
                    ),
                    if (_type == 'Other') ...[
                      const SizedBox(height: 10),
                      _HealthEditorField(
                        controller: _otherTypeController,
                        hint: 'Specify health record...',
                        errorText:
                            _validationAttempted &&
                                _otherTypeController.text.trim().isEmpty
                            ? 'Specific health record is required.'
                            : null,
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const _HealthEditorLabel('UPLOAD FILE'),
                    const SizedBox(height: 8),
                    _HealthUploadBox(
                      fileName: _fileName,
                      file: _file,
                      existingUrl:
                          widget.initialRecord?['fileUrl'] as String? ?? '',
                      onUpload: _pickFile,
                      onTakePhoto: _takePhoto,
                      onDelete: () => setState(() {
                        _file = null;
                        _fileName = '';
                      }),
                    ),
                    const SizedBox(height: 12),
                    const _HealthEditorLabel('DATE ISSUED'),
                    const SizedBox(height: 8),
                    _HealthEditorField(
                      controller: _dateController,
                      hint: 'mm/dd/yyyy',
                      readOnly: true,
                      onTap: _pickDate,
                      suffix: Icons.calendar_month_outlined,
                      errorText:
                          _validationAttempted &&
                              _dateController.text.trim().isEmpty
                          ? 'Date Issued is required.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    const _HealthEditorLabel('NEXT UPDATE'),
                    const SizedBox(height: 8),
                    _HealthEditorField(
                      controller: _nextUpdateController,
                      hint: 'Select next update date',
                      readOnly: true,
                      onTap: _pickNextUpdate,
                      suffix: Icons.event_repeat_outlined,
                      errorText:
                          _validationAttempted &&
                              _nextUpdateController.text.trim().isEmpty
                          ? 'Next Update is required.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    const _HealthEditorLabel('ISSUED BY'),
                    const SizedBox(height: 5),
                    const Text(
                      'Name of the veterinarian',
                      style: TextStyle(color: Color(0xFF777777), fontSize: 10),
                    ),
                    const SizedBox(height: 5),
                    _HealthEditorField(
                      controller: _vetController,
                      hint: 'Enter name of veterinarian...',
                      errorText:
                          _validationAttempted &&
                              _vetController.text.trim().isEmpty
                          ? 'Veterinarian name is required.'
                          : null,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Name of the veterinary clinic',
                      style: TextStyle(color: Color(0xFF777777), fontSize: 10),
                    ),
                    const SizedBox(height: 5),
                    _HealthEditorField(
                      controller: _clinicController,
                      hint: 'Select veterinary clinic...',
                      readOnly: true,
                      suffix: Icons.search,
                      onTap: () async {
                        final clinic = await showDialog<String>(
                          context: context,
                          builder: (_) => const _ClinicPickerDialog(),
                        );
                        if (clinic != null) {
                          setState(() => _clinicController.text = clinic);
                        }
                      },
                      errorText:
                          _validationAttempted &&
                              _clinicController.text.trim().isEmpty
                          ? 'Veterinary clinic is required.'
                          : null,
                    ),
                    if (_validationAttempted &&
                        (_fileName.isEmpty ||
                            _dateController.text.trim().isEmpty ||
                            _nextUpdateController.text.trim().isEmpty ||
                            _vetController.text.trim().isEmpty ||
                            _clinicController.text.trim().isEmpty ||
                            (_type == 'Other' &&
                                _otherTypeController.text.trim().isEmpty))) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE5E8),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE04455)),
                        ),
                        child: const Text(
                          'Please complete all required health-record information.',
                          style: TextStyle(
                            color: Color(0xFFB32635),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0050B4),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: const Text(
                          'SAVE HEALTH RECORD',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthEditorLabel extends StatelessWidget {
  final String text;

  const _HealthEditorLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF444444),
        fontSize: 10,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _HealthEditorField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool readOnly;
  final VoidCallback? onTap;
  final IconData? suffix;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const _HealthEditorField({
    required this.controller,
    required this.hint,
    this.readOnly = false,
    this.onTap,
    this.suffix,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 11),
        suffixIcon: suffix == null
            ? null
            : Icon(suffix, color: const Color(0xFF0050B4), size: 18),
        errorText: errorText,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 11,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFF1D78FF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFF0050B4), width: 1.5),
        ),
      ),
    );
  }
}

class _HealthUploadBox extends StatelessWidget {
  final String fileName;
  final File? file;
  final String existingUrl;
  final VoidCallback onUpload;
  final VoidCallback onTakePhoto;
  final VoidCallback onDelete;

  const _HealthUploadBox({
    required this.fileName,
    required this.file,
    required this.existingUrl,
    required this.onUpload,
    required this.onTakePhoto,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasFile = fileName.isNotEmpty || existingUrl.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF1D78FF)),
      ),
      child: hasFile
          ? Row(
              children: [
                const _HealthMiniDocument(),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    fileName.isEmpty ? 'Uploaded health record' : fileName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF222222),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Column(
                  children: [
                    _TinyHealthAction(
                      label: 'UPLOAD',
                      color: const Color(0xFF56C14A),
                      onTap: onUpload,
                    ),
                    const SizedBox(height: 5),
                    _TinyHealthAction(
                      label: 'DELETE',
                      color: AppColors.primary,
                      onTap: onDelete,
                    ),
                  ],
                ),
              ],
            )
          : Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onUpload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3D8BFF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text('UPLOAD A PHOTO'),
                  ),
                ),
                OutlinedButton(
                  onPressed: onTakePhoto,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0050B4),
                    side: const BorderSide(color: Color(0xFF0050B4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text('TAKE A PHOTO'),
                ),
              ],
            ),
    );
  }
}

class _TinyHealthAction extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _TinyHealthAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 58,
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 8,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ClinicPickerDialog extends StatefulWidget {
  const _ClinicPickerDialog();

  @override
  State<_ClinicPickerDialog> createState() => _ClinicPickerDialogState();
}

class _ClinicPickerDialogState extends State<_ClinicPickerDialog> {
  final _searchController = TextEditingController();

  static const _clinics = [
    'Cabuyao Animal Clinic',
    'Silo Veterinary Cabuyao',
    'ABC Advance Care Animal Bite Clinic',
    'Hayop Kalinga Veterinary Clinic',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final results = query.isEmpty
        ? _clinics
        : _clinics
              .where((clinic) => clinic.toLowerCase().contains(query))
              .toList();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF0050B4), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select veterinary clinic',
                    style: TextStyle(
                      color: Color(0xFF0050B4),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('DONE'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: Color(0xFF0050B4)),
                hintText: 'Search veterinary clinic...',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${results.length} RESULT${results.length == 1 ? '' : 'S'} FOUND',
              style: const TextStyle(
                color: Color(0xFF444444),
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: results.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: Color(0xFFE8E8E8)),
                itemBuilder: (context, index) {
                  final clinic = results[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFFEAF3FF),
                      child: Icon(
                        Icons.local_hospital,
                        color: Color(0xFF0050B4),
                      ),
                    ),
                    title: Text(
                      clinic,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    subtitle: const Text(
                      'Cabuyao City, Laguna',
                      style: TextStyle(fontSize: 9),
                    ),
                    trailing: const Icon(
                      Icons.radio_button_unchecked,
                      color: Color(0xFF0050B4),
                    ),
                    onTap: () => Navigator.pop(context, clinic),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthVerificationDialog extends StatelessWidget {
  final VoidCallback onConfirm;

  const _HealthVerificationDialog({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: const Text(
        'Submit this document for verification?',
        textAlign: TextAlign.center,
      ),
      content: const Text(
        'Once uploaded, it will be reviewed by a licensed veterinarian to ensure your pet health information is accurate.',
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0050B4),
              foregroundColor: Colors.white,
            ),
            child: const Text('UPLOAD FOR VERIFICATION'),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
        ),
      ],
    );
  }
}

class _PetFallbackIcon extends StatelessWidget {
  const _PetFallbackIcon();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.pets, color: AppColors.primary, size: 32);
  }
}

class _HealthPreviewFallback extends StatelessWidget {
  const _HealthPreviewFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      color: const Color(0xFFEAF3FF),
      child: const Center(
        child: Icon(
          Icons.description_outlined,
          color: Color(0xFF0050B4),
          size: 54,
        ),
      ),
    );
  }
}

void _showHealthRecordPreview(
  BuildContext context, {
  required Map<String, dynamic> record,
}) {
  final fileUrl = record['fileUrl'] as String? ?? '';
  showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    record['fileName'] as String? ?? 'Health record',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.cancel, color: Color(0xFF1D78FF)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: BreedrNetworkImage(
                imageUrl: fileUrl,
                fit: BoxFit.cover,
                fallback: const _HealthPreviewFallback(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

DateTime? _parseHealthDate(String value) {
  final parts = value.split('/');
  if (parts.length != 3) return null;
  final month = int.tryParse(parts[0]);
  final day = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (month == null || day == null || year == null) return null;
  return DateTime(year, month, day);
}

String _formatHealthDate(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String _suggestedNextUpdate(String dateIssued) {
  final issued =
      _parseHealthDate(dateIssued) ?? _parseNamedHealthDate(dateIssued);
  if (issued == null) return '';
  return _formatHealthDate(DateTime(issued.year + 1, issued.month, issued.day));
}

DateTime? _parseNamedHealthDate(String value) {
  const months = {
    'january': 1,
    'february': 2,
    'march': 3,
    'april': 4,
    'may': 5,
    'june': 6,
    'july': 7,
    'august': 8,
    'september': 9,
    'october': 10,
    'november': 11,
    'december': 12,
  };
  final match = RegExp(
    r'^([A-Za-z]+)\s+(\d{1,2}),\s*(\d{4})$',
  ).firstMatch(value.trim());
  if (match == null) return null;
  final month = months[match.group(1)!.toLowerCase()];
  final day = int.tryParse(match.group(2)!);
  final year = int.tryParse(match.group(3)!);
  if (month == null || day == null || year == null) return null;
  return DateTime(year, month, day);
}

bool _isDueSoonRecord(Map<String, dynamic> record) {
  final rawDue = _recordNextUpdate(record);
  final due = _parseNamedHealthDate(rawDue) ?? _parseHealthDate(rawDue);
  if (due == null) return false;
  final now = DateTime.now();
  return due.difference(now).inDays <= 45;
}

String _recordNextUpdate(Map<String, dynamic> record) {
  final stored =
      (record['nextUpdate'] ?? record['nextDue'])?.toString().trim() ?? '';
  if (stored.isNotEmpty) return stored;
  return _suggestedNextUpdate(record['dateIssued']?.toString() ?? '');
}
