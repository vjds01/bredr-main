import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../models/pet_listing_data.dart';
import '../../services/pet_registration_draft_service.dart';
import 'pet_health_record_screen.dart';

// Question types
enum QuestionType { multipleChoice, textAnswer, yesNo, rating }

class InterviewQuestion {
  final QuestionType type;
  final String text;
  final List<String> choices;
  final bool required;

  InterviewQuestion({
    required this.type,
    required this.text,
    this.choices = const [],
    this.required = true,
  });
}

class AdoptionInterviewScreen extends StatefulWidget {
  final PetListingData petData;

  const AdoptionInterviewScreen({
    super.key,
    required this.petData,
  });

  @override
  State<AdoptionInterviewScreen> createState() =>
      _AdoptionInterviewScreenState();
}

class _AdoptionInterviewScreenState extends State<AdoptionInterviewScreen> {
  final List<InterviewQuestion> _questions = [];

  @override
  void initState() {
    super.initState();
    _questions.addAll(
      widget.petData.interviewQuestions.map(_fromPetQuestion),
    );
  }

  void _openAddQuestion() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuestionTypeSheet(
        onTypeSelected: (type) {
          Navigator.pop(context);
          _openQuestionEditor(type);
        },
      ),
    );
  }

  void _openQuestionEditor(QuestionType type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuestionEditorSheet(
        type: type,
        onSave: (q) {
          setState(() => _questions.add(q));
          _saveDraft();
        },
      ),
    );
  }

  void _editQuestion(int index) {
    final question = _questions[index];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuestionEditorSheet(
        type: question.type,
        initialQuestion: question,
        onSave: (updated) {
          setState(() => _questions[index] = updated);
          _saveDraft();
        },
      ),
    );
  }

  Future<void> _openStandardLibrary() async {
    final selected = await Navigator.push<List<InterviewQuestion>>(
      context,
      MaterialPageRoute(
        builder: (_) => const _StandardQuestionsLibrary(),
      ),
    );

    if (selected == null || selected.isEmpty) return;

    final remainingSlots = 10 - _questions.length;
    if (remainingSlots <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can add up to 10 questions only.')),
      );
      return;
    }

    final questionsToAdd = selected.take(remainingSlots).toList();

    setState(() => _questions.addAll(questionsToAdd));
    _saveDraft();

    if (selected.length > questionsToAdd.length && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${questionsToAdd.length} questions added. You can add up to 10 questions only.',
          ),
        ),
      );
    }
  }

  void _removeQuestion(int index) {
    setState(() => _questions.removeAt(index));
    _saveDraft();
  }

  String _questionTypeLabel(QuestionType type) {
    switch (type) {
      case QuestionType.multipleChoice:
        return 'multipleChoice';
      case QuestionType.textAnswer:
        return 'textAnswer';
      case QuestionType.yesNo:
        return 'yesNo';
      case QuestionType.rating:
        return 'rating';
    }
  }

  List<PetInterviewQuestion> _petQuestions() {
    final questions = _questions
        .asMap()
        .entries
        .map(
          (entry) => PetInterviewQuestion(
            questionId: 'question_${entry.key}',
            type: _questionTypeLabel(entry.value.type),
            text: entry.value.text,
            choices: entry.value.choices,
            required: entry.value.required,
            order: entry.key,
          ),
        )
        .toList();

    return questions;
  }

  PetListingData _updatedPetData() {
    return widget.petData.copyWith(interviewQuestions: _petQuestions());
  }

  Future<void> _saveDraft() async {
    await PetRegistrationDraftService.instance.saveDraft(_updatedPetData());
  }

  InterviewQuestion _fromPetQuestion(PetInterviewQuestion question) {
    return InterviewQuestion(
      type: _questionTypeFromLabel(question.type),
      text: question.text,
      choices: question.choices,
      required: question.required,
    );
  }

  QuestionType _questionTypeFromLabel(String type) {
    switch (type) {
      case 'multipleChoice':
        return QuestionType.multipleChoice;
      case 'yesNo':
        return QuestionType.yesNo;
      case 'rating':
        return QuestionType.rating;
      case 'textAnswer':
      default:
        return QuestionType.textAnswer;
    }
  }

  void _goNext() {
    final updatedData = _updatedPetData();
    PetRegistrationDraftService.instance.saveDraft(updatedData);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PetHealthRecordScreen(
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
                    _PetStepBar(currentStep: 3),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text('Step 3 of 5',
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
                                Text('Set Adoption\nInterview Questions',
                                    style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                        height: 1.2)),
                                SizedBox(height: 6),
                                Text(
                                  'Set questions that every applicant must answer before sending an adoption request. This helps you find the right home.',
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
                    const SizedBox(height: 20),
                    // Add Interview Question button (dashed)
                    _DashedButton(
                      label: 'Add Interview Question',
                      icon: Icons.add_circle,
                      onTap: _openAddQuestion,
                    ),
                    const SizedBox(height: 12),
                    // Not sure what to ask card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE8EA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFFFCDD5), width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: const [
                            Icon(Icons.help_outline,
                                size: 14, color: AppColors.primary),
                            SizedBox(width: 6),
                            Text('Not sure what to ask?',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary)),
                          ]),
                          const SizedBox(height: 6),
                          const Text(
                            'Use standard questions reviewed and approved by licensed veterinarians and animal welfare experts. They serve as a guide to help you screen adopters responsibly.',
                            style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF888888),
                                height: 1.4),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 36,
                            child: ElevatedButton(
                              onPressed: _openStandardLibrary,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF333333),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(8)),
                              ),
                              child: const Text(
                                  'Browse standard questions',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Questions list or empty state
                    if (_questions.isEmpty) ...[
                      Center(
                        child: Column(children: [
                          const SizedBox(height: 16),
                          Image.asset(
                            'assets/images/Welcome.png',
                            height: 140,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Icon(
                                Icons.assignment_outlined,
                                size: 80,
                                color: Color(0xFFDDDDDD)),
                          ),
                          const SizedBox(height: 16),
                          const Text('No Question Added Yet',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF444444))),
                          const SizedBox(height: 8),
                          const Text(
                            'Tap the button below to add your first\nquestion. You may add up to 10 questions.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF888888),
                                height: 1.5),
                          ),
                          const SizedBox(height: 24),
                        ]),
                      ),
                    ] else ...[
                      ...List.generate(_questions.length, (i) {
                        final q = _questions[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _QuestionCard(
                            index: i + 1,
                            question: q,
                            onEdit: () => _editQuestion(i),
                            onRemove: () => _removeQuestion(i),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      _DashedButton(
                        label: 'Add Interview Question',
                        icon: Icons.add_circle,
                        onTap: _openAddQuestion,
                      ),
                      const SizedBox(height: 20),
                    ],
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

// ── Question Card ─────────────────────────────────────────────────

class _QuestionCard extends StatelessWidget {
  final int index;
  final InterviewQuestion question;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _QuestionCard({
    required this.index,
    required this.question,
    required this.onEdit,
    required this.onRemove,
  });

  Color get _typeColor {
    switch (question.type) {
      case QuestionType.multipleChoice: return const Color(0xFFF43845);
      case QuestionType.textAnswer:    return const Color(0xFFF2AA58);
      case QuestionType.yesNo:         return const Color(0xFF5399F0);
      case QuestionType.rating:        return const Color(0xFF56C14A);
    }
  }

  String get _typeLabel {
    switch (question.type) {
      case QuestionType.multipleChoice: return 'Multiple Choice';
      case QuestionType.textAnswer:     return 'Text Answer';
      case QuestionType.yesNo:          return 'Yes / No';
      case QuestionType.rating:         return '1–5 Rating';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _typeColor.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(children: [
              // Number badge
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: _typeColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text('$index',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              // Type badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_typeLabel,
                    style: TextStyle(
                        fontSize: 10,
                        color: _typeColor,
                        fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onEdit,
                child: Icon(Icons.edit_outlined, size: 18, color: _typeColor),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onRemove,
                child: Icon(Icons.close, size: 18, color: _typeColor),
              ),
            ]),
          ),
          // Question text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(question.text,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF333333))),
          ),
          // Preview content
          if (question.type == QuestionType.multipleChoice &&
              question.choices.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Column(
                children: question.choices
                    .map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              margin: const EdgeInsets.only(top: 1),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _typeColor,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                c,
                                softWrap: true,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.25,
                                  color: Color(0xFF555555),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          if (question.type == QuestionType.textAnswer)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEEEEEE)),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Text('Your Answer...',
                      style: TextStyle(fontSize: 12, color: Color(0xFFBBBBBB))),
                ),
              ),
            ),
          if (question.type == QuestionType.yesNo)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Row(children: [
                _YesNoChip(label: 'Yes', color: _typeColor),
                const SizedBox(width: 8),
                _YesNoChip(label: 'No', color: _typeColor),
              ]),
            ),
          if (question.type == QuestionType.rating)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Row(children: List.generate(5, (i) =>
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.star_border, size: 22, color: _typeColor),
                ))),
            ),
          // Required badge
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('required',
                  style: TextStyle(
                      fontSize: 10,
                      color: _typeColor,
                      fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }
}

class _YesNoChip extends StatelessWidget {
  final String label;
  final Color color;
  const _YesNoChip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Question Type Selector Sheet ──────────────────────────────────

class _QuestionTypeSheet extends StatefulWidget {
  final ValueChanged<QuestionType> onTypeSelected;
  const _QuestionTypeSheet({required this.onTypeSelected});
  @override
  State<_QuestionTypeSheet> createState() => _QuestionTypeSheetState();
}

class _QuestionTypeSheetState extends State<_QuestionTypeSheet> {
  QuestionType? _selected = QuestionType.multipleChoice;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('Add a Question',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF222222))),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Text('CANCEL',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 6),
          const Text('How should the adopter answer this question?',
              style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.0,
            children: [
              _TypeCard(
                type: QuestionType.multipleChoice,
                label: 'Multiple Choice',
                subtitle: 'You provide options to pick from',
                icon: Icons.quiz_outlined,
                color: const Color(0xFFF43845),
                bgColor: const Color(0xFFFFE8EA),
                selected: _selected == QuestionType.multipleChoice,
                onTap: () => setState(() => _selected = QuestionType.multipleChoice),
              ),
              _TypeCard(
                type: QuestionType.textAnswer,
                label: 'Text Answer',
                subtitle: 'You provide options to pick from',
                icon: Icons.edit_note,
                color: const Color(0xFFF2AA58),
                bgColor: const Color(0xFFFFF3E0),
                selected: _selected == QuestionType.textAnswer,
                onTap: () => setState(() => _selected = QuestionType.textAnswer),
              ),
              _TypeCard(
                type: QuestionType.yesNo,
                label: 'Yes / No',
                subtitle: 'Simple yes or no',
                icon: Icons.check_box,
                color: const Color(0xFF5399F0),
                bgColor: const Color(0xFFE3F0FF),
                selected: _selected == QuestionType.yesNo,
                onTap: () => setState(() => _selected = QuestionType.yesNo),
              ),
              _TypeCard(
                type: QuestionType.rating,
                label: '1–5 Rating',
                subtitle: 'They tap a star rating',
                icon: Icons.star_half,
                color: const Color(0xFF56C14A),
                bgColor: const Color(0xFFE8F5E9),
                selected: _selected == QuestionType.rating,
                onTap: () => setState(() => _selected = QuestionType.rating),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _selected != null
                  ? () => widget.onTypeSelected(_selected!)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('SELECT',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final QuestionType type;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final bool selected;
  final VoidCallback onTap;

  const _TypeCard({
    required this.type,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : const Color(0xFFDDDDDD),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? color : Colors.transparent,
                    border: Border.all(
                      color: selected ? color : const Color(0xFF888888),
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.circle, color: Colors.white, size: 10)
                      : null,
                ),
              ],
            ),
            const Spacer(),
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFF888888), height: 1.3)),
          ],
        ),
      ),
    );
  }
}

// ── Question Editor Sheet ─────────────────────────────────────────

class _QuestionEditorSheet extends StatefulWidget {
  final QuestionType type;
  final InterviewQuestion? initialQuestion;
  final ValueChanged<InterviewQuestion> onSave;
  const _QuestionEditorSheet({
    required this.type,
    this.initialQuestion,
    required this.onSave,
  });
  @override
  State<_QuestionEditorSheet> createState() => _QuestionEditorSheetState();
}

class _QuestionEditorSheetState extends State<_QuestionEditorSheet> {
  final _questionCtrl = TextEditingController();
  final List<TextEditingController> _choiceCtrl = [TextEditingController()];
  bool _required = true;
  final _starLabels = ['No Experience', 'Some Experience', 'Very Experience'];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuestion;
    if (initial == null) return;

    _questionCtrl.text = initial.text;
    _required = initial.required;

    if (widget.type == QuestionType.multipleChoice &&
        initial.choices.isNotEmpty) {
      for (final controller in _choiceCtrl) {
        controller.dispose();
      }
      _choiceCtrl
        ..clear()
        ..addAll(initial.choices.map((choice) {
          return TextEditingController(text: choice);
        }));
    }
  }

  Color get _color {
    switch (widget.type) {
      case QuestionType.multipleChoice: return const Color(0xFFF43845);
      case QuestionType.textAnswer:     return const Color(0xFFF2AA58);
      case QuestionType.yesNo:          return const Color(0xFF5399F0);
      case QuestionType.rating:         return const Color(0xFF56C14A);
    }
  }

  String get _typeLabel {
    switch (widget.type) {
      case QuestionType.multipleChoice: return 'Multiple Choice';
      case QuestionType.textAnswer:     return 'Text Answer';
      case QuestionType.yesNo:          return 'Yes / No';
      case QuestionType.rating:         return '1–5 Rating';
    }
  }

  IconData get _typeIcon {
    switch (widget.type) {
      case QuestionType.multipleChoice: return Icons.quiz_outlined;
      case QuestionType.textAnswer:     return Icons.edit_note;
      case QuestionType.yesNo:          return Icons.check_box;
      case QuestionType.rating:         return Icons.star_half;
    }
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    for (final c in _choiceCtrl) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final q = InterviewQuestion(
      type: widget.type,
      text: _questionCtrl.text.isEmpty
          ? 'Untitled Question'
          : _questionCtrl.text,
      choices: widget.type == QuestionType.multipleChoice
          ? _choiceCtrl.map((c) => c.text).where((t) => t.isNotEmpty).toList()
          : [],
      required: _required,
    );
    widget.onSave(q);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          children: [
            // Header
            Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_typeIcon, color: _color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(_typeLabel,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _color)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text('CANCEL',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold)),
              ),
            ]),
            const Divider(height: 24),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                children: [
                  // Question text
                  const Text('QUESTION TEXT',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF444444),
                          letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _questionCtrl,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Enter your question...',
                      hintStyle: const TextStyle(
                          color: Color(0xFFBBBBBB), fontSize: 14),
                      filled: true,
                      fillColor: const Color(0xFFFFF8F9),
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _color.withValues(alpha: 0.4)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _color.withValues(alpha: 0.4)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _color, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Type-specific fields
                  if (widget.type == QuestionType.multipleChoice) ...[
                    const Text('ANSWER CHOICES',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF444444),
                            letterSpacing: 0.8)),
                    const SizedBox(height: 8),
                    ...List.generate(_choiceCtrl.length, (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _choiceCtrl[i],
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Enter choice...',
                              hintStyle: const TextStyle(
                                  color: Color(0xFFBBBBBB), fontSize: 14),
                              filled: true,
                              fillColor: const Color(0xFFFFF8F9),
                              contentPadding: const EdgeInsets.all(14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: _color.withValues(alpha: 0.4)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: _color.withValues(alpha: 0.4)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: _color, width: 1.5),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            if (_choiceCtrl.length > 1) {
                              setState(() {
                                _choiceCtrl[i].dispose();
                                _choiceCtrl.removeAt(i);
                              });
                            }
                          },
                          child: Icon(Icons.close,
                              color: _color, size: 22),
                        ),
                      ]),
                    )),
                    _DashedButton(
                      label: 'Add a choice',
                      icon: Icons.add,
                      onTap: () => setState(
                          () => _choiceCtrl.add(TextEditingController())),
                      color: _color,
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (widget.type == QuestionType.rating) ...[
                    const Text('STAR LABELS (OPTIONAL)',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF444444),
                            letterSpacing: 0.8)),
                    const SizedBox(height: 8),
                    ...List.generate(3, (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            color: _color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text('${i + 1}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(_starLabels[i],
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF555555))),
                          ),
                        ),
                      ]),
                    )),
                    const SizedBox(height: 20),
                  ],
                  // Required toggle
                  Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Required to answer',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF333333))),
                          Text('Cannot submit without answering',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF999999))),
                        ],
                      ),
                    ),
                    Switch(
                      value: _required,
                      onChanged: (v) => setState(() => _required = v),
                      activeThumbColor: _color,
                      activeTrackColor: _color.withValues(alpha: 0.4),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _color,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('SAVE QUESTION',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Standard Questions Library ────────────────────────────────────

class _StandardQuestionsLibrary extends StatefulWidget {
  const _StandardQuestionsLibrary();
  @override
  State<_StandardQuestionsLibrary> createState() =>
      _StandardQuestionsLibraryState();
}

class _StandardQuestionsLibraryState
    extends State<_StandardQuestionsLibrary> {
  String _filter = 'All';
  final Set<int> _selectedQuestionIds = {};
  final _filters = ['All', 'Intention', 'Experience', 'Home', 'Lifestyle'];

  List<_StandardQuestion> get _visibleQuestions {
    if (_filter == 'All') return _standardQuestions;
    return _standardQuestions
        .where((question) => question.category == _filter)
        .toList();
  }

  void _toggleQuestion(_StandardQuestion question) {
    setState(() {
      if (_selectedQuestionIds.contains(question.id)) {
        _selectedQuestionIds.remove(question.id);
      } else {
        _selectedQuestionIds.add(question.id);
      }
    });
  }

  void _addSelectedQuestions() {
    final questions = _standardQuestions
        .where((question) => _selectedQuestionIds.contains(question.id))
        .map((question) => question.toInterviewQuestion())
        .toList();

    Navigator.pop(context, questions);
  }

  @override
  Widget build(BuildContext context) {
    final visibleQuestions = _visibleQuestions;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 8),
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios,
                    size: 14, color: AppColors.primary),
                label: const Text('Back to Set Adoption Interview Questions',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.primary)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Standard Questions\nLibrary',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          height: 1.2)),
                  const SizedBox(height: 16),
                  // Vet-Validated card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F0FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF5399F0).withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0050B4),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(children: [
                              Icon(Icons.diamond_outlined,
                                  size: 10, color: Colors.white),
                              SizedBox(width: 4),
                              Text('Vet-Validated',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ]),
                          ),
                          const SizedBox(width: 8),
                          const Text('by licensed veterinarians',
                              style: TextStyle(
                                  fontSize: 10, color: Color(0xFF888888))),
                        ]),
                        const SizedBox(height: 8),
                        const Text('Suggested Standard Questions',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0050B4))),
                        const SizedBox(height: 6),
                        const Text(
                          'Use standard questions reviewed and approved by licensed veterinarians and animal welfare experts. They serve as a guide to help you screen adopters responsibly.',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF555555),
                              height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('${_standardQuestions.length} questions',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF777777),
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  // Filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filters.map((f) {
                        final sel = _filter == f;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _filter = f),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: sel
                                    ? AppColors.primary
                                    : const Color(0xFFFFF0F5),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: sel
                                        ? AppColors.primary
                                        : const Color(0xFFFFCDD5)),
                              ),
                              child: Text(f,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: sel
                                          ? Colors.white
                                          : AppColors.primary,
                                      fontWeight: FontWeight.w500)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                itemBuilder: (context, index) {
                  final question = visibleQuestions[index];
                  return _StandardQuestionCard(
                    question: question,
                    selected: _selectedQuestionIds.contains(question.id),
                    onTap: () => _toggleQuestion(question),
                  );
                },
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemCount: visibleQuestions.length,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      _selectedQuestionIds.isEmpty ? null : _addSelectedQuestions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.45),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('View Selected  ${_selectedQuestionIds.length}',
                      style: const TextStyle(
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

// ── Shared Widgets ────────────────────────────────────────────────

class _StandardQuestion {
  final int id;
  final String category;
  final QuestionType type;
  final String text;
  final List<String> choices;
  final String? helperText;

  const _StandardQuestion({
    required this.id,
    required this.category,
    required this.type,
    required this.text,
    this.choices = const [],
    this.helperText,
  });

  InterviewQuestion toInterviewQuestion() {
    return InterviewQuestion(
      type: type,
      text: text,
      choices: choices,
      required: true,
    );
  }
}

class _StandardQuestionCard extends StatelessWidget {
  final _StandardQuestion question;
  final bool selected;
  final VoidCallback onTap;

  const _StandardQuestionCard({
    required this.question,
    required this.selected,
    required this.onTap,
  });

  Color get _typeColor {
    switch (question.type) {
      case QuestionType.multipleChoice:
        return const Color(0xFFF43845);
      case QuestionType.textAnswer:
        return const Color(0xFFF2AA58);
      case QuestionType.yesNo:
        return const Color(0xFF5399F0);
      case QuestionType.rating:
        return const Color(0xFF56C14A);
    }
  }

  String get _typeLabel {
    switch (question.type) {
      case QuestionType.multipleChoice:
        return 'Multiple Choice';
      case QuestionType.textAnswer:
        return 'Text Answer';
      case QuestionType.yesNo:
        return 'Yes / No';
      case QuestionType.rating:
        return '1-5 Rating';
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF0F5) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFFFCDD5),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    question.text,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.primary : Colors.white,
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : const Color(0xFFDDDDDD),
                    ),
                  ),
                  child: Icon(
                    selected ? Icons.check : Icons.add,
                    size: 17,
                    color: selected ? Colors.white : const Color(0xFF888888),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _QuestionMetaChip(label: _typeLabel, color: _typeColor),
                const SizedBox(width: 8),
                _QuestionMetaChip(
                  label: question.category,
                  color: AppColors.primary,
                ),
              ],
            ),
            if (question.helperText != null) ...[
              const SizedBox(height: 8),
              Text(
                question.helperText!,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  color: Color(0xFF888888),
                ),
              ),
            ],
            if (question.choices.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...question.choices.take(4).map(
                    (choice) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: _typeColor),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              choice,
                              style: const TextStyle(
                                fontSize: 11,
                                height: 1.25,
                                color: Color(0xFF666666),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              if (question.choices.length > 4)
                Text(
                  '+ ${question.choices.length - 4} more',
                  style: TextStyle(
                    fontSize: 11,
                    color: _typeColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuestionMetaChip extends StatelessWidget {
  final String label;
  final Color color;

  const _QuestionMetaChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

const List<_StandardQuestion> _standardQuestions = [
  _StandardQuestion(
    id: 1,
    category: 'Intention',
    type: QuestionType.multipleChoice,
    text: 'What is your primary reason for wanting to adopt a pet?',
    helperText: 'Tick all that applies.',
    choices: [
      'For companionship / emotional support',
      'For my children / family',
      'As a guard or working animal',
      'I want to give a pet a good home',
      'Other',
    ],
  ),
  _StandardQuestion(
    id: 2,
    category: 'Intention',
    type: QuestionType.yesNo,
    text:
        'Have you discussed the decision to adopt a pet with all members of your household?',
    helperText:
        'If yes, do they all agree and support having a pet at home?',
  ),
  _StandardQuestion(
    id: 3,
    category: 'Intention',
    type: QuestionType.textAnswer,
    text:
        'In your own words, why do you want to adopt a pet at this time?',
    helperText:
        'Be as specific as possible. Include what kind of pet you are looking for and why.',
  ),
  _StandardQuestion(
    id: 4,
    category: 'Intention',
    type: QuestionType.yesNo,
    text:
        'Are you adopting this pet for yourself, or is it intended as a gift for someone else?',
    helperText:
        'If as a gift, does that person know about and agree to receiving a pet?',
  ),
  _StandardQuestion(
    id: 5,
    category: 'Intention',
    type: QuestionType.rating,
    text:
        'On a scale of 1 to 5, how prepared do you feel you are to take on the responsibility of owning a pet right now?',
    helperText: '1 = Not prepared at all. 5 = Fully prepared.',
  ),
  _StandardQuestion(
    id: 6,
    category: 'Experience',
    type: QuestionType.yesNo,
    text: 'Do you have previous experience caring for a dog or a cat?',
    helperText:
        'If yes, how long did you care for the pet, and what happened to it?',
  ),
  _StandardQuestion(
    id: 7,
    category: 'Experience',
    type: QuestionType.multipleChoice,
    text:
        'Which of the following pet care responsibilities have you personally handled before?',
    helperText: 'Tick all that applies.',
    choices: [
      'Feeding and providing fresh water daily',
      'Grooming (bathing, brushing, nail trimming)',
      'Bringing the pet to a veterinarian for checkups or vaccinations',
      'Training or disciplining the pet',
      "Managing the pet's health during illness",
      'None of the above',
    ],
  ),
  _StandardQuestion(
    id: 8,
    category: 'Experience',
    type: QuestionType.rating,
    text:
        'How would you rate your overall knowledge of basic pet care needs (diet, hygiene, health, behavior)?',
    helperText: '1 = No knowledge. 5 = Very knowledgeable.',
  ),
  _StandardQuestion(
    id: 9,
    category: 'Experience',
    type: QuestionType.textAnswer,
    text:
        'If you have previously owned a pet that you were unable to continue caring for, what happened and what did you learn from that experience?',
    helperText:
        'Be honest and specific about what happened and what changed.',
  ),
  _StandardQuestion(
    id: 10,
    category: 'Home',
    type: QuestionType.multipleChoice,
    text: 'What type of home do you currently live in?',
    helperText: 'Tick all that applies.',
    choices: [
      'House with a yard or outdoor space',
      'Apartment or condominium unit',
      'Shared or rented room / boarding house',
      'Other',
    ],
  ),
  _StandardQuestion(
    id: 11,
    category: 'Home',
    type: QuestionType.yesNo,
    text:
        'If you are renting your home, does your landlord or property owner allow pets on the premises?',
  ),
  _StandardQuestion(
    id: 12,
    category: 'Home',
    type: QuestionType.yesNo,
    text:
        'Does anyone in your household have allergies or medical conditions that could be worsened by having a pet at home?',
    helperText: 'If yes, have you consulted a doctor about this?',
  ),
  _StandardQuestion(
    id: 13,
    category: 'Home',
    type: QuestionType.rating,
    text:
        'On a scale of 1 to 5, how suitable would you say your current living space is for housing a pet comfortably?',
    helperText: '1 = Not suitable at all. 5 = Very suitable.',
  ),
  _StandardQuestion(
    id: 14,
    category: 'Home',
    type: QuestionType.textAnswer,
    text:
        'Where will the pet sleep, eat, and spend most of its time? Have you already prepared a dedicated space for it?',
    helperText: 'Describe the specific area or setup you have planned.',
  ),
  _StandardQuestion(
    id: 15,
    category: 'Lifestyle',
    type: QuestionType.yesNo,
    text:
        'Are you aware of the monthly costs involved in owning a pet, including food, veterinary visits, grooming, and supplies?',
    helperText: 'If yes, have you budgeted for these expenses?',
  ),
  _StandardQuestion(
    id: 16,
    category: 'Lifestyle',
    type: QuestionType.multipleChoice,
    text:
        'If you encountered an unexpected veterinary emergency, what would you most likely do?',
    helperText: 'Tick all that applies.',
    choices: [
      'I have savings set aside for this purpose',
      'I would borrow money from family or friends',
      'I am not sure what I would do',
      'Other',
    ],
  ),
  _StandardQuestion(
    id: 17,
    category: 'Lifestyle',
    type: QuestionType.rating,
    text:
        'On a scale of 1 to 5, how committed are you to caring for this pet for its entire lifetime - even through major life changes such as moving, having a new baby, or changes in employment?',
    helperText: '1 = Not committed at all. 5 = Fully committed for life.',
  ),
  _StandardQuestion(
    id: 18,
    category: 'Lifestyle',
    type: QuestionType.yesNo,
    text:
        "Are you willing to send regular updates about the pet's condition, health, and wellbeing to the original owner or shelter after the adoption?",
    helperText:
        'If yes, how often would you be willing to provide updates?',
  ),
  _StandardQuestion(
    id: 19,
    category: 'Lifestyle',
    type: QuestionType.textAnswer,
    text:
        'What would you do if circumstances in your life made it impossible for you to continue caring for the pet in the future?',
    helperText:
        'Examples: relocation abroad, financial hardship, family health emergency.',
  ),
  _StandardQuestion(
    id: 20,
    category: 'Lifestyle',
    type: QuestionType.multipleChoice,
    text:
        'How many hours per day will the pet be left alone at home on a typical day?',
    helperText: 'Tick all that applies.',
    choices: [
      'Less than 2 hours',
      '2 to 4 hours',
      '4 to 6 hours',
      '6 to 8 hours',
      'More than 8 hours',
    ],
  ),
  _StandardQuestion(
    id: 21,
    category: 'Lifestyle',
    type: QuestionType.yesNo,
    text:
        'Do you have a family member, friend, or neighbor who can look after the pet when you are unavailable, traveling, or away for extended periods?',
  ),
  _StandardQuestion(
    id: 22,
    category: 'Lifestyle',
    type: QuestionType.rating,
    text:
        'On a scale of 1 to 5, how active is your daily lifestyle in terms of physical activity and outdoor time?',
    helperText:
        '1 = Mostly sedentary / indoors. 5 = Very active / outdoors daily.',
  ),
  _StandardQuestion(
    id: 23,
    category: 'Lifestyle',
    type: QuestionType.yesNo,
    text:
        'Do you have young children below 10 years old or elderly family members in your household who will regularly interact with the pet?',
    helperText:
        'If yes, have you considered how the pet and these household members will safely interact with each other?',
  ),
  _StandardQuestion(
    id: 24,
    category: 'Lifestyle',
    type: QuestionType.textAnswer,
    text:
        'Is there anything else about your lifestyle, household, or personal situation that you believe is important for us to know when evaluating your qualification as a pet adopter?',
    helperText: 'Feel free to share any additional details.',
  ),
];

class _DashedButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _DashedButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedRectPainter(color: color, radius: 12, dashW: 6, gapW: 4),
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
      width: 44, height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? AppColors.primary : const Color(0xFFFFF0F5),
        border: Border.all(
          color: isActive ? AppColors.primary : const Color(0xFFFFB3C1),
          width: isActive ? 0 : 2,
        ),
        boxShadow: isActive
            ? [BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.45),
                blurRadius: 18, spreadRadius: 2)]
            : [],
      ),
      child: Icon(Icons.pets, size: 22,
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
