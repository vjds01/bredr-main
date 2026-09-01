import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/adoption_models.dart';
import '../../services/adoption_service.dart';
import '../../theme/app_colors.dart';

class AdoptionApplicationScreen extends StatefulWidget {
  final AdoptionListing listing;

  const AdoptionApplicationScreen({super.key, required this.listing});

  @override
  State<AdoptionApplicationScreen> createState() =>
      _AdoptionApplicationScreenState();
}

class _AdoptionApplicationScreenState extends State<AdoptionApplicationScreen> {
  final Map<String, dynamic> _answers = {};
  final Map<String, TextEditingController> _textControllers = {};
  int _step = 0;
  bool _submitting = false;

  List<AdoptionQuestion> get _questions => widget.listing.questions;

  @override
  void initState() {
    super.initState();
    for (final question in _questions) {
      if (question.type == 'textAnswer') {
        _textControllers[question.id] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _validationMessage() {
    for (final question in _questions) {
      if (!question.required) continue;
      final value = _answers[question.id];
      final valid = switch (value) {
        String text => text.trim().isNotEmpty,
        num rating => rating >= 1 && rating <= 5,
        bool _ => true,
        _ => false,
      };
      if (!valid) return 'Please answer question ${question.order + 1}.';
    }
    return null;
  }

  void _continueToReview() {
    for (final entry in _textControllers.entries) {
      _answers[entry.key] = entry.value.text.trim();
    }
    final message = _validationMessage();
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    setState(() => _step = 1);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final eligibility = await AdoptionService.instance
          .validateListingForRequest(widget.listing.id);
      if (!eligibility.allowed) {
        throw AdoptionServiceException(
          eligibility.reason ?? 'This listing is no longer available.',
        );
      }

      final answers = _questions
          .where((question) => _answers.containsKey(question.id))
          .map(
            (question) => AdoptionAnswer(
              questionId: question.id,
              questionText: question.text,
              type: question.type,
              value: _answers[question.id],
              order: question.order,
            ),
          )
          .toList();
      await AdoptionService.instance.submitRequest(
        petId: widget.listing.id,
        answers: answers,
      );
      if (!mounted) return;
      setState(() => _step = 2);
    } on AdoptionServiceException catch (error) {
      if (!mounted) return;
      _showError(error.message);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      _showError(_firebaseMessage(error));
    } catch (error) {
      if (!mounted) return;
      _showError('The request could not be submitted. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_step == 2) return _success();
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7FA),
        elevation: 0,
        foregroundColor: AppColors.primary,
        title: Text(
          _step == 0 ? 'INTERVIEW' : 'REVIEW & SUBMIT',
          style: const TextStyle(
            color: Color(0xFF111111),
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: Column(
        children: [
          _ProgressHeader(step: _step + 1),
          Expanded(child: _step == 0 ? _questionForm() : _review()),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _submitting
                      ? null
                      : _step == 0
                      ? _continueToReview
                      : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_step == 0 ? 'Continue' : 'Submit Request'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _questionForm() {
    if (_questions.isEmpty) {
      return const _ApplicationMessage(
        icon: Icons.assignment_turned_in_outlined,
        title: 'No interview questions',
        message:
            'The owner did not add interview questions. You can continue and submit your request.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      itemCount: _questions.length,
      itemBuilder: (context, index) {
        final question = _questions[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _QuestionCard(
            number: index + 1,
            question: question,
            value: _answers[question.id],
            textController: _textControllers[question.id],
            onChanged: (value) {
              setState(() => _answers[question.id] = value);
            },
          ),
        );
      },
    );
  }

  Widget _review() {
    if (_questions.isEmpty) {
      return const _ApplicationMessage(
        icon: Icons.fact_check_outlined,
        title: 'Ready to submit',
        message:
            'Confirm your request below. The owner will receive it immediately.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        const Text(
          'Double-check your answers before sending your request.',
          style: TextStyle(color: Color(0xFF777777), fontSize: 12),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < _questions.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _AnswerReviewCard(
              number: index + 1,
              question: _questions[index],
              answer: _answers[_questions[index].id],
            ),
          ),
        TextButton.icon(
          onPressed: () => setState(() => _step = 0),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit Answers'),
        ),
      ],
    );
  }

  Widget _success() {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 130,
                height: 130,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFFD9E1),
                ),
                child: const Icon(
                  Icons.assignment_turned_in,
                  size: 70,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 26),
              const Text(
                'Request Submitted!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your adoption request for ${widget.listing.name} has been sent. Please wait for the owner to review your answers.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF555555),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text('Back to Adoption'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final int step;

  const _ProgressHeader({required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 10),
      child: Column(
        children: [
          Row(
            children: List.generate(
              3,
              (index) => Expanded(
                child: Container(
                  height: 5,
                  margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: index < step
                        ? AppColors.primary
                        : const Color(0xFFFFC8D3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Step $step of 3',
              style: const TextStyle(color: AppColors.primary, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final int number;
  final AdoptionQuestion question;
  final dynamic value;
  final TextEditingController? textController;
  final ValueChanged<dynamic> onChanged;

  const _QuestionCard({
    required this.number,
    required this.question,
    required this.value,
    required this.textController,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = _questionColor(question.type);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color, width: 1.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: color,
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _questionTypeLabel(question.type),
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            question.text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          _answerControl(color),
          if (question.required) ...[
            const SizedBox(height: 8),
            Text('required', style: TextStyle(color: color, fontSize: 9)),
          ],
        ],
      ),
    );
  }

  Widget _answerControl(Color color) {
    switch (question.type) {
      case 'multipleChoice':
        return RadioGroup<String>(
          groupValue: value as String?,
          onChanged: onChanged,
          child: Column(
            children: question.options
                .map(
                  (option) => RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: option,
                    activeColor: color,
                    title: Text(
                      option,
                      softWrap: true,
                      style: const TextStyle(fontSize: 11, height: 1.25),
                    ),
                  ),
                )
                .toList(),
          ),
        );
      case 'yesNo':
        return Wrap(
          spacing: 10,
          children: [
            ChoiceChip(
              label: const Text('Yes'),
              selected: value == true,
              onSelected: (_) => onChanged(true),
            ),
            ChoiceChip(
              label: const Text('No'),
              selected: value == false,
              onSelected: (_) => onChanged(false),
            ),
          ],
        );
      case 'rating':
        return Row(
          children: List.generate(
            5,
            (index) => IconButton(
              onPressed: () => onChanged(index + 1),
              icon: Icon(
                (value as num? ?? 0) >= index + 1
                    ? Icons.star
                    : Icons.star_border,
                color: const Color(0xFFFFC107),
              ),
            ),
          ),
        );
      default:
        return TextField(
          controller: textController,
          minLines: 3,
          maxLines: 6,
          onChanged: onChanged,
          decoration: const InputDecoration(
            hintText: 'Your answer',
            border: OutlineInputBorder(),
          ),
        );
    }
  }
}

class _AnswerReviewCard extends StatelessWidget {
  final int number;
  final AdoptionQuestion question;
  final dynamic answer;

  const _AnswerReviewCard({
    required this.number,
    required this.question,
    required this.answer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: _questionColor(question.type)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number. ${question.text}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            answer is bool
                ? (answer ? 'Yes' : 'No')
                : '${answer ?? 'No answer'}',
            style: const TextStyle(color: Color(0xFF555555), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ApplicationMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _ApplicationMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 60, color: AppColors.primary),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF666666), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

Color _questionColor(String type) {
  switch (type) {
    case 'multipleChoice':
      return const Color(0xFFFF8DA4);
    case 'textAnswer':
      return const Color(0xFFFFA13D);
    case 'yesNo':
      return const Color(0xFF3189F5);
    case 'rating':
      return const Color(0xFF54B94D);
    default:
      return AppColors.primary;
  }
}

String _questionTypeLabel(String type) {
  switch (type) {
    case 'multipleChoice':
      return 'Multiple Choice';
    case 'textAnswer':
      return 'Text Answer';
    case 'yesNo':
      return 'Yes / No';
    case 'rating':
      return '1 - 5 Rating';
    default:
      return 'Question';
  }
}

String _firebaseMessage(FirebaseException error) {
  switch (error.code) {
    case 'permission-denied':
      return 'Breedr could not submit this request. Check that the latest Firestore rules are deployed.';
    case 'unavailable':
      return 'The service is temporarily unavailable. Check your connection and try again.';
    case 'deadline-exceeded':
      return 'The request took too long to submit. Please try again.';
    default:
      return error.message?.trim().isNotEmpty == true
          ? error.message!
          : 'The request could not be submitted. Please try again.';
  }
}
