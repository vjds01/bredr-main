import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/adoption_models.dart';
import '../../services/adoption_service.dart';
import '../../theme/app_colors.dart';
import '../chat/chats_screen.dart';
import 'owner_profile_screen.dart';

class AdoptionRequestDetailScreen extends StatelessWidget {
  final String requestId;

  const AdoptionRequestDetailScreen({
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
              return const _RequestEmptyState(
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
              return const _RequestEmptyState(
                icon: Icons.assignment_outlined,
                title: 'Request not found',
                message: 'This adoption request may no longer be available.',
              );
            }
            return _RequestDetailBody(request: request);
          },
        ),
      ),
    );
  }
}

class _RequestDetailBody extends StatelessWidget {
  final AdoptionRequest request;

  const _RequestDetailBody({required this.request});

  @override
  Widget build(BuildContext context) {
    final pet = request.petSnapshot;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(request.ownerId)
          .snapshots(),
      builder: (context, ownerSnapshot) {
        final ownerData = ownerSnapshot.data?.data();
        final petName = _text(pet['name'], fallback: 'Pet');
        final ownerName = _text(
          pet['ownerName'],
          fallback: _ownerDisplayName(ownerData),
        );
        final ownerPhoto = _text(
          pet['ownerPhoto'],
          fallback: _ownerPhoto(ownerData),
        );
        final photo = _text(pet['petProfilePhoto']);
        final species = _text(pet['species']);
        final profile = _StatusProfile.forStatus(request.status, ownerName);

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: _NetworkPetImage(url: photo, species: species),
                  ),
                  Container(
                    height: 200,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x33000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 8,
                    child: IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 14,
                    bottom: 14,
                    child: _StatusBadge(profile: profile),
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
                    Transform.translate(
                      offset: const Offset(0, -12),
                      child: _PetSummaryCard(request: request),
                    ),
                    const SizedBox(height: 4),
                    _StatusMessageCard(
                      request: request,
                      profile: profile,
                    ),
                    const SizedBox(height: 18),
                    const _SectionTitle('YOUR SUBMITTED ANSWERS'),
                    const SizedBox(height: 10),
                    if (request.answers.isEmpty)
                      const _SoftNote(
                        icon: Icons.info_outline,
                        text:
                            'This request did not include interview questions from the owner.',
                      )
                    else
                      ...request.answers.map(
                        (answer) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _AnswerCard(answer: answer),
                        ),
                      ),
                    const SizedBox(height: 10),
                    const _SoftNote(
                      icon: Icons.lock_outline,
                      text:
                          'You cannot edit your answers after submitting. If the owner has questions, you can reach out once approved.',
                    ),
                    const SizedBox(height: 22),
                    Text(
                      "$petName's Owner",
                      style: const TextStyle(
                        color: Color(0xFF555555),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _OwnerCard(
                      ownerId: request.ownerId,
                      ownerName: ownerName,
                      ownerPhoto: ownerPhoto,
                    ),
                    const SizedBox(height: 18),
                    _PrimaryAction(
                      request: request,
                      ownerName: ownerName,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PetSummaryCard extends StatelessWidget {
  final AdoptionRequest request;

  const _PetSummaryCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final pet = request.petSnapshot;
    final name = _text(pet['name'], fallback: 'Pet');
    final type = _text(pet['adoptionType'], fallback: 'free');
    final price = (pet['price'] as num?)?.toDouble();
    final photo = _text(pet['petProfilePhoto']);
    final species = _text(pet['species']);
    final details = [
      _text(pet['breed']),
      _text(pet['gender']),
      _text(pet['age']),
      _text(pet['locationName']),
    ].where((value) => value.isNotEmpty).join(' • ');

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFE2E8),
              border: Border.all(color: Colors.white, width: 3),
            ),
            clipBehavior: Clip.antiAlias,
            child: _NetworkPetImage(url: photo, species: species),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (type == 'forSale' && price != null)
                      _SmallPill(
                        text: 'PHP ${_formatPrice(price)}',
                        color: const Color(0xFFE4F2FF),
                        textColor: const Color(0xFF1478D4),
                      )
                    else
                      const _SmallPill(
                        text: 'FREE',
                        color: Color(0xFFFFE5EC),
                        textColor: AppColors.primary,
                      ),
                  ],
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    details,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF444444),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 9),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    if (pet['vetVerified'] == true)
                      const _SmallPill(
                        text: 'Vet Verified',
                        color: Color(0xFFD6EEFF),
                        textColor: Color(0xFF2389E8),
                      ),
                    if (_text(pet['color']).isNotEmpty)
                      _SmallPill(
                        text: _text(pet['color']),
                        color: const Color(0xFFFFE5EC),
                        textColor: const Color(0xFF555555),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusMessageCard extends StatelessWidget {
  final AdoptionRequest request;
  final _StatusProfile profile;

  const _StatusMessageCard({
    required this.request,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: profile.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: profile.color.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(profile.icon, color: profile.color, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.title,
                  style: TextStyle(
                    color: profile.color,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  profile.message,
                  style: const TextStyle(
                    color: Color(0xFF555555),
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
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

class _AnswerCard extends StatelessWidget {
  final AdoptionAnswer answer;

  const _AnswerCard({required this.answer});

  @override
  Widget build(BuildContext context) {
    final style = _QuestionTypeStyle.forType(answer.type);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: style.color, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: style.color,
                child: Text(
                  '${answer.order + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SmallPill(
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
          _AnswerValue(answer: answer),
        ],
      ),
    );
  }
}

class _AnswerValue extends StatelessWidget {
  final AdoptionAnswer answer;

  const _AnswerValue({required this.answer});

  @override
  Widget build(BuildContext context) {
    if (answer.type == 'rating') {
      final rating = (answer.value as num?)?.round() ?? 0;
      return Row(
        children: List.generate(
          5,
          (index) => Icon(
            index < rating ? Icons.star : Icons.star_border,
            color: const Color(0xFFFFD12E),
            size: 25,
          ),
        ),
      );
    }

    final value = answer.value;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8FA),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        value == true
            ? 'Yes'
            : value == false
                ? 'No'
                : (value?.toString() ?? ''),
        style: const TextStyle(
          color: Color(0xFF333333),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      ),
    );
  }
}

class _OwnerCard extends StatelessWidget {
  final String ownerId;
  final String ownerName;
  final String ownerPhoto;

  const _OwnerCard({
    required this.ownerId,
    required this.ownerName,
    required this.ownerPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OwnerProfileScreen(
              ownerId: ownerId,
              fallbackName: ownerName,
              fallbackPhoto: ownerPhoto,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            _OwnerAvatar(url: ownerPhoto),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                ownerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF555555)),
          ],
        ),
      ),
    );
  }
}

class _PrimaryAction extends StatefulWidget {
  final AdoptionRequest request;
  final String ownerName;

  const _PrimaryAction({
    required this.request,
    required this.ownerName,
  });

  @override
  State<_PrimaryAction> createState() => _PrimaryActionState();
}

class _PrimaryActionState extends State<_PrimaryAction> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    switch (request.status) {
      case AdoptionRequestStatus.approved:
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _busy ? null : () => _openChat(context, request),
            icon: const Icon(Icons.chat_bubble_outline),
            label: Text(
              'OPEN CHAT WITH ${widget.ownerName.toUpperCase()}',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        );
      case AdoptionRequestStatus.pending:
      case AdoptionRequestStatus.underReview:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFFFFCDD4),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Text(
                'Withdraw Request\nCannot be restored after being deleted.',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 9),
            FilledButton(
              onPressed: _busy ? null : () => _withdraw(context, request),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: const Text('WITHDRAW REQUEST'),
            ),
          ],
        );
      case AdoptionRequestStatus.rejected:
        return SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            child: const Text('BROWSE OTHER PETS'),
          ),
        );
      case AdoptionRequestStatus.withdrawn:
      case AdoptionRequestStatus.completed:
        return const SizedBox.shrink();
    }
  }

  Future<void> _openChat(
    BuildContext context,
    AdoptionRequest request,
  ) async {
    final conversationId = request.conversationId ??
        AdoptionService.instance.conversationId(request.id);
    setState(() => _busy = true);
    try {
      final conversation = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .get();
      final data = conversation.data();
      if (!context.mounted) return;
      if (data == null || data['status'] == 'unmatched') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This adoption chat is not available right now.'),
          ),
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
            otherOwnerId: request.ownerId,
          ),
        ),
      );
    } on FirebaseException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_firebaseActionMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withdraw(
    BuildContext context,
    AdoptionRequest request,
  ) async {
    setState(() => _busy = true);
    try {
      final eligibility =
          await AdoptionService.instance.validateWithdrawal(request.id);
      if (!context.mounted) return;
      if (!eligibility.allowed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              eligibility.reason ?? 'This request cannot be withdrawn.',
            ),
          ),
        );
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Withdraw adoption request?'),
          content: const Text(
            'Your answers will remain read-only, and this request cannot be restored after withdrawal.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep Request'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Withdraw'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      await AdoptionService.instance.withdrawRequest(request.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your adoption request was withdrawn.')),
      );
    } on AdoptionServiceException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } on FirebaseException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_firebaseActionMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final _StatusProfile profile;

  const _StatusBadge({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: profile.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: profile.color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(profile.icon, color: profile.color, size: 13),
          const SizedBox(width: 4),
          Text(
            profile.badge,
            style: TextStyle(
              color: profile.color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;

  const _SmallPill({
    required this.text,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
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

class _SoftNote extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SoftNote({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEF2),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF777777),
                fontSize: 10,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerAvatar extends StatelessWidget {
  final String url;

  const _OwnerAvatar({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFFFDDE5),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? const Icon(Icons.person, color: AppColors.primary)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.person, color: AppColors.primary),
            ),
    );
  }
}

class _NetworkPetImage extends StatelessWidget {
  final String url;
  final String species;

  const _NetworkPetImage({
    required this.url,
    required this.species,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _PetPlaceholder(species: species);
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _PetPlaceholder(species: species),
    );
  }
}

class _PetPlaceholder extends StatelessWidget {
  final String species;

  const _PetPlaceholder({required this.species});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFFFE6EC),
      child: Center(
        child: Icon(
          species.toLowerCase() == 'cat' ? Icons.cruelty_free : Icons.pets,
          color: AppColors.primary,
          size: 54,
        ),
      ),
    );
  }
}

class _RequestEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _RequestEmptyState({
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
              style: const TextStyle(
                color: Color(0xFF777777),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionTypeStyle {
  final String label;
  final Color color;
  final Color background;

  const _QuestionTypeStyle({
    required this.label,
    required this.color,
    required this.background,
  });

  static _QuestionTypeStyle forType(String type) {
    switch (type) {
      case 'multipleChoice':
        return const _QuestionTypeStyle(
          label: 'Multiple Choice',
          color: Color(0xFFFF87A1),
          background: Color(0xFFFFE4EA),
        );
      case 'yesNo':
        return const _QuestionTypeStyle(
          label: 'Yes / No',
          color: Color(0xFF258DFF),
          background: Color(0xFFE5F2FF),
        );
      case 'rating':
        return const _QuestionTypeStyle(
          label: '1 - 5 Rating',
          color: Color(0xFF56BE57),
          background: Color(0xFFE5F7E5),
        );
      default:
        return const _QuestionTypeStyle(
          label: 'Text Answer',
          color: Color(0xFFFFA845),
          background: Color(0xFFFFEBCF),
        );
    }
  }
}

class _StatusProfile {
  final String title;
  final String message;
  final String badge;
  final IconData icon;
  final Color color;
  final Color background;

  const _StatusProfile({
    required this.title,
    required this.message,
    required this.badge,
    required this.icon,
    required this.color,
    required this.background,
  });

  static _StatusProfile forStatus(
    AdoptionRequestStatus status,
    String ownerName,
  ) {
    switch (status) {
      case AdoptionRequestStatus.approved:
        return _StatusProfile(
          title: '$ownerName approved your request!',
          message:
              'A chat has been opened. You can now arrange the meetup with $ownerName.',
          badge: 'Interview Approved',
          icon: Icons.check_circle,
          color: const Color(0xFF36A842),
          background: const Color(0xFFE4F9E4),
        );
      case AdoptionRequestStatus.underReview:
        return _StatusProfile(
          title: '$ownerName is reviewing your answers',
          message:
              '$ownerName will approve or decline your request soon. You will get a notification when they respond.',
          badge: 'Under Review',
          icon: Icons.visibility,
          color: const Color(0xFFC18A20),
          background: const Color(0xFFFFEBC2),
        );
      case AdoptionRequestStatus.pending:
        return _StatusProfile(
          title: 'Waiting for $ownerName to respond',
          message:
              'Your request has been submitted. The owner has not reviewed it yet.',
          badge: 'Pending',
          icon: Icons.schedule,
          color: const Color(0xFF9A8054),
          background: const Color(0xFFF4E5CC),
        );
      case AdoptionRequestStatus.rejected:
        return _StatusProfile(
          title: '$ownerName declined your request',
          message:
              'Please do not worry. You can browse other pets that are available for adoption.',
          badge: 'Declined',
          icon: Icons.sentiment_dissatisfied,
          color: AppColors.primary,
          background: const Color(0xFFFFE3E7),
        );
      case AdoptionRequestStatus.withdrawn:
        return const _StatusProfile(
          title: 'Request withdrawn',
          message: 'You withdrew this adoption request.',
          badge: 'Withdrawn',
          icon: Icons.undo,
          color: Color(0xFF777777),
          background: Color(0xFFF0F0F0),
        );
      case AdoptionRequestStatus.completed:
        return const _StatusProfile(
          title: 'Adoption completed',
          message: 'This adoption request has been completed.',
          badge: 'Completed',
          icon: Icons.home,
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

String _ownerDisplayName(Map<String, dynamic>? data) {
  if (data == null) return 'Pet owner';
  for (final key in [
    'fullName',
    'name',
    'displayName',
    'display_name',
    'userName',
    'username',
  ]) {
    final value = data[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return 'Pet owner';
}

String _ownerPhoto(Map<String, dynamic>? data) {
  if (data == null) return '';
  for (final key in ['profilePhoto', 'photoURL', 'photoUrl']) {
    final value = data[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}

String _formatPrice(num value) {
  final digits = value.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[index]);
  }
  return buffer.toString();
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
