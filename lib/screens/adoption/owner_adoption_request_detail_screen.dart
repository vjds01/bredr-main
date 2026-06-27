import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/adoption_models.dart';
import '../../services/adoption_service.dart';
import '../../theme/app_colors.dart';
import '../chat/chats_screen.dart';
import 'owner_profile_screen.dart';

class OwnerAdoptionRequestDetailScreen extends StatelessWidget {
  final String requestId;

  const OwnerAdoptionRequestDetailScreen({
    super.key,
    required this.requestId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),
      body: SafeArea(
        child: StreamBuilder<AdoptionRequest?>(
          stream: AdoptionService.instance.watchRequest(requestId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const _EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'Request unavailable',
                message: 'Check your connection and try again.',
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            final request = snapshot.data;
            if (request == null) {
              return const _EmptyState(
                icon: Icons.assignment_outlined,
                title: 'Request not found',
                message: 'This adoption request may no longer be available.',
              );
            }
            return _OwnerRequestBody(request: request);
          },
        ),
      ),
    );
  }
}

class _OwnerRequestBody extends StatelessWidget {
  final AdoptionRequest request;

  const _OwnerRequestBody({required this.request});

  @override
  Widget build(BuildContext context) {
    final applicant = request.applicantSnapshot;
    final pet = request.petSnapshot;
    final applicantName = _text(applicant['fullName'], fallback: 'Applicant');
    final petName = _text(pet['name'], fallback: 'this pet');
    final status = _StatusInfo.forStatus(request.status);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                ),
                _Avatar(
                  url: _text(applicant['profilePhoto']),
                  size: 54,
                  fallback: Icons.person,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        applicantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Request to adopt $petName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusPill(info: status),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              [
                _ApplicantCard(request: request),
                const SizedBox(height: 18),
                const _SectionTitle('INTERVIEW ANSWERS'),
                const SizedBox(height: 10),
                if (request.answers.isEmpty)
                  const _EmptyInline(
                    icon: Icons.question_answer_outlined,
                    title: 'No interview questions',
                    message:
                        'This listing did not include questions. You can still approve or decline this applicant.',
                  )
                else
                  ...request.answers.map(
                    (answer) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AnswerCard(answer: answer),
                    ),
                  ),
                const SizedBox(height: 12),
                const _InfoNote(
                  text:
                      'Approving opens an adoption chat with this applicant. Payment or meetup details must be arranged outside Breedr.',
                ),
                const SizedBox(height: 18),
                _OwnerDecisionActions(request: request),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ApplicantCard extends StatelessWidget {
  final AdoptionRequest request;

  const _ApplicantCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final applicant = request.applicantSnapshot;
    final name = _text(applicant['fullName'], fallback: 'Applicant');
    final location = _text(
      applicant['locationName'],
      fallback: 'Location not available',
    );
    final photo = _text(applicant['profilePhoto']);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OwnerProfileScreen(
            ownerId: request.applicantId,
            fallbackName: name,
            fallbackPhoto: photo,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x16000000),
              blurRadius: 9,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _Avatar(
              url: photo,
              size: 76,
              fallback: Icons.person,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Color(0xFF777777),
                        size: 14,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF777777),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _Chip(
                        text: _text(
                          applicant['homeType'],
                          fallback: 'Home not set',
                        ),
                      ),
                      _Chip(
                        text: applicant['childrenAtHome'] == true
                            ? 'Has kids'
                            : 'No kids',
                      ),
                      _Chip(
                        text: applicant['otherPetsAtHome'] == true
                            ? 'Has pets'
                            : 'No pets',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _OwnerDecisionActions extends StatefulWidget {
  final AdoptionRequest request;

  const _OwnerDecisionActions({required this.request});

  @override
  State<_OwnerDecisionActions> createState() => _OwnerDecisionActionsState();
}

class _OwnerDecisionActionsState extends State<_OwnerDecisionActions> {
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final canDecide = request.status == AdoptionRequestStatus.pending ||
        request.status == AdoptionRequestStatus.underReview;

    if (canDecide) {
      return Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: _processing ? null : () => _confirmDecision(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF51C64B),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: const Text('APPROVE'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: _processing ? null : () => _confirmDecision(false),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: const Text('DECLINE'),
            ),
          ),
        ],
      );
    }

    if (request.status == AdoptionRequestStatus.approved) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _processing ? null : _openChat,
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('OPEN ADOPTION CHAT'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 13),
          ),
        ),
      );
    }

    return _InfoNote(text: _StatusInfo.forStatus(request.status).ownerMessage);
  }

  Future<void> _confirmDecision(bool approve) async {
    final request = widget.request;
    final applicantName = _text(
      request.applicantSnapshot['fullName'],
      fallback: 'this applicant',
    );
    final petName = _text(request.petSnapshot['name'], fallback: 'this pet');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          approve ? 'Approve $applicantName?' : 'Decline $applicantName?',
        ),
        content: Text(
          approve
              ? 'This will reserve $petName for $applicantName, open an adoption chat, and decline other active requests for this listing.'
              : 'This will notify $applicantName that their adoption request was declined.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor:
                  approve ? const Color(0xFF51C64B) : AppColors.primary,
            ),
            child: Text(approve ? 'Approve' : 'Decline'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _decide(approve);
  }

  Future<void> _decide(bool approve) async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      if (approve) {
        await AdoptionService.instance.approveRequest(widget.request.id);
      } else {
        await AdoptionService.instance.declineRequest(widget.request.id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'The adoption request was approved.'
                : 'The adoption request was declined.',
          ),
        ),
      );
    } on AdoptionServiceException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_firebaseActionMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _openChat() async {
    final request = widget.request;
    final conversationId = request.conversationId ??
        AdoptionService.instance.conversationId(request.id);
    setState(() => _processing = true);
    try {
      final conversation = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .get();
      final data = conversation.data();
      if (!mounted) return;
      if (data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This adoption chat is unavailable.')),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatConversationScreen(
            matchId: conversationId,
            otherPetName: _text(
              request.petSnapshot['name'],
              fallback: 'Adoption Chat',
            ),
            otherPetPhoto: _text(request.petSnapshot['petProfilePhoto']),
            otherOwnerId: request.applicantId,
            otherParticipantLabel: 'Adopter',
          ),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_firebaseActionMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }
}

class _AnswerCard extends StatelessWidget {
  final AdoptionAnswer answer;

  const _AnswerCard({required this.answer});

  @override
  Widget build(BuildContext context) {
    final style = _AnswerStyle.forType(answer.type);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: style.color, width: 1.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: style.color,
                child: Text(
                  '${answer.order + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _MiniPill(
                text: style.label,
                color: style.background,
                textColor: style.color,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            answer.questionText,
            style: const TextStyle(
              color: Color(0xFF333333),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          if (answer.type == 'rating')
            Row(
              children: List.generate(
                5,
                (index) {
                  final rating = (answer.value as num?)?.round() ?? 0;
                  return Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    color: const Color(0xFFFFD12E),
                    size: 24,
                  );
                },
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8FA),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _answerText(answer.value),
                style: const TextStyle(
                  color: Color(0xFF444444),
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final _StatusInfo info;

  const _StatusPill({required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: info.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        info.label,
        style: TextStyle(
          color: info.color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;

  const _Chip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE4EA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF555555),
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;

  const _MiniPill({
    required this.text,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  final String text;

  const _InfoNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F2FF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, color: Color(0xFF258DFF)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF555555),
                fontSize: 11,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyInline extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyInline({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFD4DC)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 36),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF444444),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF777777), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
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
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFE3EA),
              ),
              child: Icon(icon, size: 42, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF444444),
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF777777), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String url;
  final double size;
  final IconData fallback;

  const _Avatar({
    required this.url,
    required this.size,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFFFDDE5),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? Icon(fallback, color: AppColors.primary)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Icon(fallback, color: AppColors.primary),
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF555555),
        fontSize: 13,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _AnswerStyle {
  final String label;
  final Color color;
  final Color background;

  const _AnswerStyle({
    required this.label,
    required this.color,
    required this.background,
  });

  static _AnswerStyle forType(String type) {
    switch (type) {
      case 'multipleChoice':
        return const _AnswerStyle(
          label: 'Multiple Choice',
          color: Color(0xFFFF87A1),
          background: Color(0xFFFFE4EA),
        );
      case 'yesNo':
        return const _AnswerStyle(
          label: 'Yes / No',
          color: Color(0xFF258DFF),
          background: Color(0xFFE5F2FF),
        );
      case 'rating':
        return const _AnswerStyle(
          label: '1 - 5 Rating',
          color: Color(0xFF56BE57),
          background: Color(0xFFE5F7E5),
        );
      default:
        return const _AnswerStyle(
          label: 'Text Answer',
          color: Color(0xFFFFA845),
          background: Color(0xFFFFEBCF),
        );
    }
  }
}

class _StatusInfo {
  final String label;
  final String ownerMessage;
  final Color color;
  final Color background;

  const _StatusInfo({
    required this.label,
    required this.ownerMessage,
    required this.color,
    required this.background,
  });

  static _StatusInfo forStatus(AdoptionRequestStatus status) {
    switch (status) {
      case AdoptionRequestStatus.approved:
        return const _StatusInfo(
          label: 'Approved',
          ownerMessage:
              'This request has been approved. You can continue the adoption conversation from chat.',
          color: Color(0xFF36A842),
          background: Color(0xFFE4F9E4),
        );
      case AdoptionRequestStatus.underReview:
        return const _StatusInfo(
          label: 'Under Review',
          ownerMessage: 'You are currently reviewing this request.',
          color: Color(0xFFC18A20),
          background: Color(0xFFFFEBC2),
        );
      case AdoptionRequestStatus.pending:
        return const _StatusInfo(
          label: 'Pending',
          ownerMessage: 'This request is waiting for your decision.',
          color: Color(0xFF9A8054),
          background: Color(0xFFF4E5CC),
        );
      case AdoptionRequestStatus.rejected:
        return const _StatusInfo(
          label: 'Declined',
          ownerMessage: 'This request has already been declined.',
          color: AppColors.primary,
          background: Color(0xFFFFE3E7),
        );
      case AdoptionRequestStatus.withdrawn:
        return const _StatusInfo(
          label: 'Withdrawn',
          ownerMessage: 'The applicant withdrew this request.',
          color: Color(0xFF777777),
          background: Color(0xFFF0F0F0),
        );
      case AdoptionRequestStatus.completed:
        return const _StatusInfo(
          label: 'Completed',
          ownerMessage: 'This adoption has been completed.',
          color: Color(0xFF36A842),
          background: Color(0xFFE4F9E4),
        );
    }
  }
}

String _text(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _answerText(dynamic value) {
  if (value == true) return 'Yes';
  if (value == false) return 'No';
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? 'No answer' : text;
}

String _firebaseActionMessage(FirebaseException error) {
  switch (error.code) {
    case 'permission-denied':
      return 'Breedr could not update this request. Please sign in again or check that the latest Firestore rules are deployed.';
    case 'unavailable':
      return 'The service is temporarily unavailable. Check your connection and try again.';
    case 'deadline-exceeded':
      return 'The request took too long to complete. Please try again.';
    default:
      return error.message?.trim().isNotEmpty == true
          ? error.message!
          : 'The request could not be updated. Please try again.';
  }
}
