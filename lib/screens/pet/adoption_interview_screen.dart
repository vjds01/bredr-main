import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../models/pet_listing_data.dart';
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
        onSave: (q) => setState(() => _questions.add(q)),
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
        onSave: (updated) => setState(() => _questions[index] = updated),
      ),
    );
  }

  void _openStandardLibrary() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => const _StandardQuestionsLibrary()),
    );
  }

  void _removeQuestion(int index) {
    setState(() => _questions.removeAt(index));
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

  void _goNext() {
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PetHealthRecordScreen(
          petData: widget.petData.copyWith(
            interviewQuestions: questions,
          ),
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
                children: question.choices.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    Container(
                      width: 16, height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _typeColor, width: 1.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(c, style: const TextStyle(fontSize: 12, color: Color(0xFF555555))),
                  ]),
                )).toList(),
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
  final _filters = ['All', 'Living', 'Experience', 'Care', 'Commitment'];

  @override
  Widget build(BuildContext context) {
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
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
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
