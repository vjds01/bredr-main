import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_colors.dart';
import '../../models/pet_listing_data.dart';
import '../../services/pet_registration_draft_service.dart';
import 'pet_review_screen.dart';

// Colors from design
const _blue = Color(0xFF0050B4);
const _lightBlue = Color(0xFF5399F0);
const _green = Color(0xFF56C14A);
const _red = Color(0xFFF43845);
const _orange = Color(0xFFF2AA58);

class HealthRecord {
  final String type;
  final String fileName;
  final File? file;
  final String dateIssued;
  final String veterinarian;
  final String clinic;

  HealthRecord({
    required this.type,
    required this.fileName,
    this.file,
    this.dateIssued = '',
    this.veterinarian = '',
    this.clinic = '',
  });
}

class PetHealthRecordScreen extends StatefulWidget {
  final PetListingData petData;

  const PetHealthRecordScreen({
    super.key,
    required this.petData,
  });

  @override
  State<PetHealthRecordScreen> createState() => _PetHealthRecordScreenState();
}

class _PetHealthRecordScreenState extends State<PetHealthRecordScreen> {
  final List<HealthRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _records.addAll(widget.petData.healthRecords.map(_fromPetHealthRecord));
  }

  void _openAddRecord() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddHealthRecordSheet(
        onSave: (r) {
          setState(() => _records.add(r));
          _saveDraft();
        },
      ),
    );
  }

  void _removeRecord(int i) {
    setState(() => _records.removeAt(i));
    _saveDraft();
  }

  void _replaceRecord(int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddHealthRecordSheet(
        initialRecord: _records[index],
        onSave: (r) {
          setState(() => _records[index] = r);
          _saveDraft();
        },
      ),
    );
  }

  void _viewRecord(HealthRecord record) {
    showDialog(
      context: context,
      builder: (_) => _HealthRecordPreviewDialog(record: record),
    );
  }

  List<PetHealthRecordData> _petHealthRecords() {
    return _records
        .map(
          (record) => PetHealthRecordData(
            type: record.type,
            fileName: record.fileName,
            file: record.file,
            dateIssued: record.dateIssued,
            veterinarian: record.veterinarian,
            clinic: record.clinic,
          ),
        )
        .toList();
  }

  HealthRecord _fromPetHealthRecord(PetHealthRecordData record) {
    return HealthRecord(
      type: record.type,
      fileName: record.fileName,
      file: record.file,
      dateIssued: record.dateIssued,
      veterinarian: record.veterinarian,
      clinic: record.clinic,
    );
  }

  PetListingData _updatedPetData() {
    return widget.petData.copyWith(healthRecords: _petHealthRecords());
  }

  Future<void> _saveDraft() async {
    await PetRegistrationDraftService.instance.saveDraft(_updatedPetData());
  }

  void _goNext() {
    final updatedData = _updatedPetData();
    PetRegistrationDraftService.instance.saveDraft(updatedData);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PetReviewScreen(
          petData: updatedData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios,
                            color: AppColors.primary, size: 20),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PetStepBar(currentStep: 4),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text('Step 4 of 5',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(height: 20),
                    // Title
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 4,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Add Pet Health\nRecord',
                                    style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                        height: 1.2)),
                                SizedBox(height: 6),
                                Text(
                                  "Provide your pet's health information to ensure safe and responsible adoption",
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF666666),
                                      height: 1.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Section header
                    Row(children: const [
                      Icon(Icons.description_outlined,
                          size: 18, color: _blue),
                      SizedBox(width: 8),
                      Text('UPLOAD PET HEALTH RECORD',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF444444),
                              letterSpacing: 0.8)),
                    ]),
                    const SizedBox(height: 12),
                    // Records list
                    ..._records.asMap().entries.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _RecordCard(
                            record: e.value,
                            onView: () => _viewRecord(e.value),
                            onReplace: () => _replaceRecord(e.key),
                            onRemove: () => _removeRecord(e.key),
                          ),
                        )),
                    // Add record dashed button
                    _DashedButton(
                      label: 'Add pet health record',
                      icon: Icons.add_circle,
                      color: _blue,
                      onTap: _openAddRecord,
                    ),
                    const SizedBox(height: 24),
                    // Vet Verified Badge info
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F0FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _lightBlue.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: _lightBlue,
                            ),
                            child: const Icon(Icons.verified,
                                color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('VET VERIFIED BADGE',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _blue,
                                        letterSpacing: 0.6)),
                                SizedBox(height: 4),
                                Text(
                                  'Upload atleast 1 pet health record to earn the Vet - Verified Badge. This badge builds trust with other users and increases match rate.',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF555555),
                                      height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _goNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Continue to next step →',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Record Card ───────────────────────────────────────────────────

class _RecordCard extends StatelessWidget {
  final HealthRecord record;
  final VoidCallback onView;
  final VoidCallback onReplace;
  final VoidCallback onRemove;
  const _RecordCard({
    required this.record,
    required this.onView,
    required this.onReplace,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        children: [
          // File icon with VACC label
          Container(
            width: 52,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFF0FFF0),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _green.withValues(alpha: 0.4)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: _green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('VACC',
                      style: TextStyle(
                          fontSize: 7,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 4),
                const Icon(Icons.description_outlined,
                    size: 20, color: _green),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Name + filename
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.type,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333))),
                Text(record.fileName,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF888888))),
                const SizedBox(height: 8),
                // Action chips
                Wrap(spacing: 6, children: [
                  _ActionChip(
                      label: 'VIEW',
                      icon: Icons.visibility_outlined,
                      color: _lightBlue,
                      onTap: onView),
                  _ActionChip(
                      label: 'REPLACE',
                      icon: Icons.refresh,
                      color: _green,
                      onTap: onReplace),
                  _ActionChip(
                      label: 'DELETE',
                      icon: Icons.delete_outline,
                      color: _red,
                      onTap: onRemove),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _ActionChip(
      {required this.label,
      required this.icon,
      required this.color,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 9,
                  color: color,
                  fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}

// ── Add Health Record Sheet ───────────────────────────────────────

class _AddHealthRecordSheet extends StatefulWidget {
  final ValueChanged<HealthRecord> onSave;
  final HealthRecord? initialRecord;
  const _AddHealthRecordSheet({
    required this.onSave,
    this.initialRecord,
  });

  @override
  State<_AddHealthRecordSheet> createState() =>
      _AddHealthRecordSheetState();
}

class _HealthRecordPreviewDialog extends StatelessWidget {
  final HealthRecord record;

  const _HealthRecordPreviewDialog({
    required this.record,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.type,
                    style: const TextStyle(
                      color: _blue,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(record.fileName,
                style: const TextStyle(color: Color(0xFF666666))),
            if (record.dateIssued.isNotEmpty)
              Text('Issued: ${record.dateIssued}',
                  style: const TextStyle(color: Color(0xFF666666))),
            if (record.clinic.isNotEmpty)
              Text('Clinic: ${record.clinic}',
                  style: const TextStyle(color: Color(0xFF666666))),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: record.file != null
                  ? Image.file(record.file!, fit: BoxFit.cover)
                  : Container(
                      height: 180,
                      color: const Color(0xFFEAF3FF),
                      child: const Center(
                        child: Icon(Icons.description_outlined,
                            size: 54, color: _blue),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddHealthRecordSheetState extends State<_AddHealthRecordSheet> {
  String? _docType = 'Vaccination';
  File? _file;
  String _fileName = '';
  final _dateCtrl = TextEditingController();
  final _vetCtrl = TextEditingController();
  final _clinicCtrl = TextEditingController();
  bool _showVerifyDialog = false;

  final _docTypes = [
    'Vaccination',
    'Deworming',
    'Vet Checkup',
    'DNA check',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialRecord;
    if (initial == null) return;

    _docType = initial.type;
    _file = initial.file;
    _fileName = initial.fileName;
    _dateCtrl.text = initial.dateIssued;
    _vetCtrl.text = initial.veterinarian;
    _clinicCtrl.text = initial.clinic;
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _vetCtrl.dispose();
    _clinicCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_file == null ||
        _dateCtrl.text.trim().isEmpty ||
        _clinicCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload a record, select a date, and choose a clinic.'),
        ),
      );
      return;
    }

    setState(() => _showVerifyDialog = true);
  }

  void _confirmSave() {
    widget.onSave(HealthRecord(
      type: _docType ?? 'Vaccination',
      fileName: _fileName,
      file: _file,
      dateIssued: _dateCtrl.text.trim(),
      veterinarian: _vetCtrl.text.trim(),
      clinic: _clinicCtrl.text.trim(),
    ));
    Navigator.pop(context);
  }

  Future<void> _pickFromCamera() async {
    final xFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (xFile == null) return;

    setState(() {
      _file = File(xFile.path);
      _fileName = xFile.name;
    });
  }

  Future<void> _pickFromFiles() async {
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open files. Please try again.'),
        ),
      );
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 30),
      lastDate: now,
    );

    if (picked == null) return;

    setState(() {
      _dateCtrl.text =
          '${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  decoration: const BoxDecoration(
                    color: _blue,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(children: [
                    const Text('ADD HEALTH RECORD',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white24,
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ]),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(20),
                    children: [
                      // DOCUMENT TYPE
                      const _SheetLabel('DOCUMENT TYPE'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _docTypes.map((t) {
                          final sel = _docType == t;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _docType = t),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: sel
                                    ? _blue.withValues(alpha: 0.1)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: sel
                                      ? _blue
                                      : const Color(0xFFDDDDDD),
                                  width: sel ? 2 : 1,
                                ),
                              ),
                              child: Text(t,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: sel
                                          ? _blue
                                          : const Color(0xFF555555),
                                      fontWeight: sel
                                          ? FontWeight.bold
                                          : FontWeight.normal)),
                            ),
                          );
                        }).toList(),
                      ),
                      if (_docType == 'Other') ...[
                        const SizedBox(height: 10),
                        _BlueTextField(
                            hint: 'Specify Record Type...'),
                      ],
                      const SizedBox(height: 20),
                      // UPLOAD FILE
                      const _SheetLabel('UPLOAD FILE'),
                      const SizedBox(height: 10),
                      if (_file != null)
                        _UploadedFileCard(
                          fileName: _fileName,
                          onReplace: _pickFromFiles,
                          onDelete: () =>
                              setState(() {
                                _file = null;
                                _fileName = '';
                              }),
                        )
                      else
                        _UploadFileArea(
                          onUpload: _pickFromFiles,
                          onCamera: _pickFromCamera,
                        ),
                      const SizedBox(height: 20),
                      // DATE ISSUED
                      const _SheetLabel('DATE ISSUED'),
                      const SizedBox(height: 10),
                      _BlueTextField(
                        hint: 'mm/dd/yyyy',
                        controller: _dateCtrl,
                        readOnly: true,
                        onTap: _pickDate,
                        suffixIcon: const Icon(Icons.calendar_month_outlined,
                            color: _blue, size: 20),
                      ),
                      const SizedBox(height: 20),
                      // ISSUED BY
                      const _SheetLabel('ISSUED BY'),
                      const SizedBox(height: 4),
                      const Text('Name of the veterinarian',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF888888))),
                      const SizedBox(height: 8),
                      _BlueTextField(
                        hint: 'Enter name of veterinarian...',
                        controller: _vetCtrl,
                      ),
                      const SizedBox(height: 12),
                      const Text('Name of the veterinary clinic',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF888888))),
                      const SizedBox(height: 8),
                      _BlueTextField(
                        hint: 'Select veterinary clinic...',
                        controller: _clinicCtrl,
                        suffixIcon: const Icon(Icons.search,
                            color: _blue, size: 20),
                        readOnly: true,
                        onTap: () => _showClinicPicker(context),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _blue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('SAVE HEALTH RECORD',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
            // Verify dialog overlay
            if (_showVerifyDialog)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: _VerifyDialog(
                      onUpload: _confirmSave,
                      onCancel: () =>
                          setState(() => _showVerifyDialog = false),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showClinicPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ClinicPickerSheet(
        onSelect: (clinic) =>
            setState(() => _clinicCtrl.text = clinic),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────

class _SheetLabel extends StatelessWidget {
  final String text;
  const _SheetLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
            letterSpacing: 0.8));
  }
}

class _BlueTextField extends StatelessWidget {
  final String hint;
  final TextEditingController? controller;
  final Widget? suffixIcon;
  final bool readOnly;
  final VoidCallback? onTap;
  const _BlueTextField({
    required this.hint,
    this.controller,
    this.suffixIcon,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _blue.withValues(alpha: 0.4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _blue.withValues(alpha: 0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _blue, width: 1.5),
        ),
      ),
    );
  }
}

class _UploadedFileCard extends StatelessWidget {
  final String fileName;
  final VoidCallback onReplace;
  final VoidCallback onDelete;
  const _UploadedFileCard({
    required this.fileName,
    required this.onReplace,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _green.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        // VACC doc icon
        Container(
          width: 52,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _green.withValues(alpha: 0.4)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('VACC',
                    style: TextStyle(
                        fontSize: 7,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 4),
              const Icon(Icons.description_outlined,
                  size: 20, color: _green),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333))),
              const Text('Uploaded · 1.2 Mb · JPG',
                  style: TextStyle(
                      fontSize: 11, color: Color(0xFF888888))),
              const SizedBox(height: 8),
              Row(children: [
                _SmallBtn(
                    label: 'UPLOAD',
                    icon: Icons.upload,
                    color: _green,
                    onTap: onReplace),
                const SizedBox(width: 6),
                _SmallBtn(
                    label: 'DELETE',
                    icon: Icons.delete_outline,
                    color: _red,
                    onTap: onDelete),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _SmallBtn(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: Colors.white),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}

class _UploadFileArea extends StatelessWidget {
  final VoidCallback onUpload;
  final VoidCallback onCamera;
  const _UploadFileArea({
    required this.onUpload,
    required this.onCamera,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _blue.withValues(alpha: 0.4)),
      ),
      child: Column(children: [
        const Icon(Icons.upload_file_outlined, size: 40, color: _blue),
        const SizedBox(height: 12),
        const Text('Upload health record',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF444444))),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 40,
          child: ElevatedButton(
            onPressed: onUpload,
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('UPLOAD A PHOTO',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 38,
          child: OutlinedButton(
            onPressed: onCamera,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _blue, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('TAKE A PHOTO',
                style: TextStyle(
                    fontSize: 12,
                    color: _blue,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}

// ── Verify Dialog ─────────────────────────────────────────────────

class _VerifyDialog extends StatelessWidget {
  final VoidCallback onUpload;
  final VoidCallback onCancel;
  const _VerifyDialog({required this.onUpload, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // VACC preview card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE8F5E9), Color(0xFFFFF8E1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _green,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('VACC',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.pets,
                        color: Colors.white, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(height: 8, color: const Color(0xFFDDDDDD)),
              const SizedBox(height: 6),
              Container(height: 8, color: const Color(0xFFEEEEEE)),
              const SizedBox(height: 6),
              Container(height: 8, color: const Color(0xFFEEEEEE)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                    ),
                    child: const Icon(Icons.check,
                        color: Colors.white, size: 18),
                  ),
                  Row(children: const [
                    Icon(Icons.pets, size: 16, color: AppColors.primary),
                    SizedBox(width: 4),
                    Icon(Icons.pets, size: 12, color: Color(0xFFFFB3C1)),
                  ]),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 20),
          const Text('Submit this document for\nverification?',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF222222))),
          const SizedBox(height: 8),
          const Text(
            'Once uploaded, it will be reviewed by a licensed veterinarian to ensure your pet\'s health information is accurate.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                color: Color(0xFF888888),
                height: 1.4),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: onUpload,
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('UPLOAD FOR VERIFICATION',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFDDDDDD)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('CANCEL',
                  style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF555555),
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Clinic Picker Sheet ───────────────────────────────────────────

class _ClinicPickerSheet extends StatefulWidget {
  final ValueChanged<String> onSelect;
  const _ClinicPickerSheet({required this.onSelect});
  @override
  State<_ClinicPickerSheet> createState() => _ClinicPickerSheetState();
}

class _ClinicPickerSheetState extends State<_ClinicPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _selected;

  static const _clinics = [
    _ClinicItem('Cabuyao Animal Clinic', 'Cabuyao City, Laguna'),
    _ClinicItem('Sitio Beterinaryo Cabuyao',
        'Centennial Plaza Building National Highway, not full listed Barangay, Cabuyao City'),
    _ClinicItem('ABC Advance Care Animal Bite Clinic',
        'Sala Cabuyao City'),
    _ClinicItem('Hayop Kalinga Veterinary Clinic',
        'Corner Suki No. 2127 2nd Street, Cabuyao, Laguna'),
  ];

  List<_ClinicItem> get _filtered => _query.isEmpty
      ? _clinics
      : _clinics
          .where((c) =>
              c.name.toLowerCase().contains(_query.toLowerCase()))
          .toList();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(children: [
          Row(children: [
            const Text('Select veterinary clinic',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _blue)),
            const Spacer(),
            GestureDetector(
              onTap: () {
                if (_selected != null) widget.onSelect(_selected!);
                Navigator.pop(context);
              },
              child: const Text('DONE',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _blue)),
            ),
          ]),
          const SizedBox(height: 12),
          // Search
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _blue.withValues(alpha: 0.3)),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search veterinary clinic...',
                hintStyle:
                    TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
                prefixIcon:
                    Icon(Icons.search, color: _blue, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _query.isEmpty
                  ? 'Showing result for "cl" across all veterinary clinics in Cabuyao'
                  : '${_filtered.length} RESULTS FOUND',
              style: const TextStyle(
                  fontSize: 10, color: Color(0xFF888888)),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              controller: scrollCtrl,
              itemCount: _filtered.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
              itemBuilder: (_, i) {
                final c = _filtered[i];
                final isSel = _selected == c.name;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFE3F0FF),
                    child: const Icon(Icons.local_hospital_outlined,
                        color: _blue, size: 20),
                  ),
                  title: Text(c.name,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333))),
                  subtitle: Text(c.address,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF888888))),
                  trailing: isSel
                      ? Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: _blue,
                          ),
                          child: const Icon(Icons.check,
                              color: Colors.white, size: 14),
                        )
                      : Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFFDDDDDD),
                                width: 1.5),
                          ),
                        ),
                  onTap: () => setState(() => _selected = c.name),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}

class _ClinicItem {
  final String name;
  final String address;
  const _ClinicItem(this.name, this.address);
}

// ── Shared Widgets ────────────────────────────────────────────────

class _DashedButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  const _DashedButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color = _blue,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter:
            _DashedRectPainter(color: color, radius: 12, dashW: 6, gapW: 4),
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double dashW;
  final double gapW;
  const _DashedRectPainter(
      {required this.color,
      required this.radius,
      required this.dashW,
      required this.gapW});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        final end = (d + dashW).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(d, end), paint);
        d += dashW + gapW;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 5-step progress bar
class _PetStepBar extends StatelessWidget {
  final int currentStep;
  const _PetStepBar({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Stack(alignment: Alignment.center, children: [
        Positioned.fill(
          child: Row(children: [
            const SizedBox(width: 28),
            Expanded(child: _StepLine(active: currentStep > 1)),
            const SizedBox(width: 56),
            Expanded(child: _StepLine(active: currentStep > 2)),
            const SizedBox(width: 56),
            Expanded(child: _StepLine(active: currentStep > 3)),
            const SizedBox(width: 56),
            Expanded(child: _StepLine(active: currentStep > 4)),
            const SizedBox(width: 28),
          ]),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (int i = 1; i <= 5; i++)
              _StepDot(step: i, current: currentStep),
          ],
        ),
      ]),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int step;
  final int current;
  const _StepDot({required this.step, required this.current});
  @override
  Widget build(BuildContext context) {
    final isActive = step <= current;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? AppColors.primary : const Color(0xFFFFF0F5),
        border: Border.all(
          color: isActive ? AppColors.primary : const Color(0xFFFFB3C1),
          width: isActive ? 0 : 2,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.45),
                    blurRadius: 18,
                    spreadRadius: 2)
              ]
            : [],
      ),
      child: Icon(Icons.pets,
          size: 22,
          color: isActive ? Colors.white : const Color(0xFFFFB3C1)),
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool active;
  const _StepLine({required this.active});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : const Color(0xFFFFCDD5),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
