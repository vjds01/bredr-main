import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/breedr_network_image.dart';

enum _GivenReviewFilter { all, breeding, adoption }

class ReviewsGivenScreen extends StatefulWidget {
  const ReviewsGivenScreen({super.key});

  @override
  State<ReviewsGivenScreen> createState() => _ReviewsGivenScreenState();
}

class _ReviewsGivenScreenState extends State<ReviewsGivenScreen> {
  _GivenReviewFilter _filter = _GivenReviewFilter.all;

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7FA),
        foregroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          'Reviews Given',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: userId == null
          ? const _MessageState(
              icon: Icons.lock_outline,
              title: 'Please sign in again',
              body: 'Your submitted reviews will appear after you sign in.',
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('reviews')
                  .where('reviewerId', isEqualTo: userId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const _MessageState(
                    icon: Icons.error_outline,
                    title: 'Reviews could not be loaded',
                    body: 'Check your connection and try again.',
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }
                final all =
                    snapshot.data!.docs.map(_GivenReview.fromDocument).toList()
                      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                final visible = all.where((review) {
                  return switch (_filter) {
                    _GivenReviewFilter.all => true,
                    _GivenReviewFilter.breeding => review.purpose == 'breeding',
                    _GivenReviewFilter.adoption => review.purpose == 'adoption',
                  };
                }).toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: [
                    const Text(
                      'Reviews you have shared after completed Breeding and Adoption transactions.',
                      style: TextStyle(
                        color: Color(0xFF777777),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'All',
                            selected: _filter == _GivenReviewFilter.all,
                            onTap: () => setState(
                              () => _filter = _GivenReviewFilter.all,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Breeding',
                            icon: Icons.pets,
                            selected: _filter == _GivenReviewFilter.breeding,
                            onTap: () => setState(
                              () => _filter = _GivenReviewFilter.breeding,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Adoption',
                            icon: Icons.home_outlined,
                            selected: _filter == _GivenReviewFilter.adoption,
                            onTap: () => setState(
                              () => _filter = _GivenReviewFilter.adoption,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (visible.isEmpty)
                      _MessageState(
                        icon: Icons.rate_review_outlined,
                        title: all.isEmpty
                            ? 'No reviews given yet'
                            : 'No ${_filter.name} reviews yet',
                        body:
                            'Reviews become available after a completed transaction.',
                      )
                    else
                      ...visible.map(
                        (review) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _GivenReviewCard(review: review),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class _GivenReviewCard extends StatelessWidget {
  final _GivenReview review;

  const _GivenReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(review.reviewedUserId)
          .get(),
      builder: (context, snapshot) {
        final recipient = snapshot.data?.data();
        final name = recipient?['fullName']?.toString().trim();
        final photo = recipient?['profilePhoto']?.toString() ?? '';
        return InkWell(
          onTap: () => _showReviewDetail(
            context,
            review,
            name?.isNotEmpty == true ? name! : 'Breedr user',
            photo,
          ),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFFCDD5)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12FE5062),
                  blurRadius: 12,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Avatar(photoUrl: photo, size: 46),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name?.isNotEmpty == true ? name! : 'Breedr user',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            review.purpose == 'breeding'
                                ? 'Breeding review'
                                : 'Adoption review',
                            style: const TextStyle(
                              color: Color(0xFF888888),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.primary),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Stars(rating: review.overall),
                    const SizedBox(width: 7),
                    Text(
                      '${review.overall}.0',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const Spacer(),
                    _StatusBadge(review: review),
                  ],
                ),
                if (review.text.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    review.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF555555),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  review.formattedDate,
                  style: const TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

void _showReviewDetail(
  BuildContext context,
  _GivenReview review,
  String recipientName,
  String recipientPhoto,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFFFF7FA),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .72,
      maxChildSize: .92,
      minChildSize: .5,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 32),
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFFFCDD5),
                borderRadius: BorderRadius.circular(9),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Review Details',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _Avatar(photoUrl: recipientPhoto, size: 54),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipientName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      review.purpose == 'breeding'
                          ? 'Breeding transaction'
                          : 'Adoption transaction',
                      style: const TextStyle(color: Color(0xFF777777)),
                    ),
                  ],
                ),
              ),
              _StatusBadge(review: review),
            ],
          ),
          const SizedBox(height: 22),
          _DetailRating(label: 'Overall', rating: review.overall),
          _DetailRating(label: 'Communication', rating: review.communication),
          _DetailRating(
            label: 'Care & responsibility',
            rating: review.careResponsibility,
          ),
          _DetailRating(label: 'Transparency', rating: review.transparency),
          _DetailRating(label: 'Reliability', rating: review.reliability),
          const SizedBox(height: 14),
          const Text(
            'Your review',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(
            review.text.isEmpty ? 'No written feedback provided.' : review.text,
            style: const TextStyle(color: Color(0xFF555555), height: 1.45),
          ),
          if (review.recommendation.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Recommendation: ${review.recommendation}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
          if (review.photoUrls.isNotEmpty) ...[
            const SizedBox(height: 18),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: review.photoUrls.length,
                separatorBuilder: (_, index) => const SizedBox(width: 8),
                itemBuilder: (_, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BreedrNetworkImage(
                    imageUrl: review.photoUrls[index],
                    width: 92,
                    height: 92,
                    fit: BoxFit.cover,
                    fallback: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            'Submitted ${review.formattedDate}',
            style: const TextStyle(color: Color(0xFF888888), fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

class _DetailRating extends StatelessWidget {
  final String label;
  final int rating;

  const _DetailRating({required this.label, required this.rating});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
        _Stars(rating: rating),
      ],
    ),
  );
}

class _GivenReview {
  final String reviewedUserId;
  final String purpose;
  final int overall;
  final int communication;
  final int careResponsibility;
  final int transparency;
  final int reliability;
  final String recommendation;
  final String text;
  final List<String> photoUrls;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime? visibleAfter;

  const _GivenReview({
    required this.reviewedUserId,
    required this.purpose,
    required this.overall,
    required this.communication,
    required this.careResponsibility,
    required this.transparency,
    required this.reliability,
    required this.recommendation,
    required this.text,
    required this.photoUrls,
    required this.isPublished,
    required this.createdAt,
    required this.visibleAfter,
  });

  factory _GivenReview.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    int rating(String key) =>
        ((data[key] as num?)?.round() ?? 0).clamp(0, 5).toInt();
    final created = data['createdAt'] as Timestamp?;
    final completed = data['completedAt'] as Timestamp?;
    return _GivenReview(
      reviewedUserId: data['reviewedUserId']?.toString() ?? '',
      purpose: (data['purpose']?.toString() ?? 'breeding').toLowerCase(),
      overall: rating('overall'),
      communication: rating('communication'),
      careResponsibility: rating('careResponsibility'),
      transparency: rating('transparency'),
      reliability: rating('reliability'),
      recommendation: data['recommendation']?.toString() ?? '',
      text: data['reviewText']?.toString() ?? '',
      photoUrls:
          (data['photoUrls'] as List?)
              ?.map((item) => item.toString())
              .toList() ??
          const [],
      isPublished: data['isPublished'] == true,
      createdAt:
          created?.toDate() ??
          completed?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      visibleAfter: (data['visibleAfter'] as Timestamp?)?.toDate(),
    );
  }

  String get formattedDate => _formatDate(createdAt);
}

class _StatusBadge extends StatelessWidget {
  final _GivenReview review;

  const _StatusBadge({required this.review});

  @override
  Widget build(BuildContext context) {
    final released =
        review.visibleAfter != null &&
        !DateTime.now().isBefore(review.visibleAfter!);
    final published = review.isPublished || released;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: published ? const Color(0xFFE4F7E8) : const Color(0xFFFFF1D8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        published ? 'Published' : 'Pending publication',
        style: TextStyle(
          color: published ? const Color(0xFF2FA756) : const Color(0xFFC58A23),
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(22),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFFFE1E8) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? AppColors.primary : const Color(0xFFFFCDD5),
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.primary : const Color(0xFF555555),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Avatar extends StatelessWidget {
  final String photoUrl;
  final double size;

  const _Avatar({required this.photoUrl, required this.size});

  @override
  Widget build(BuildContext context) => ClipOval(
    child: Container(
      width: size,
      height: size,
      color: const Color(0xFFFFE1E8),
      child: BreedrNetworkImage(
        imageUrl: photoUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fallback: const Icon(Icons.person, color: AppColors.primary),
      ),
    ),
  );
}

class _Stars extends StatelessWidget {
  final int rating;

  const _Stars({required this.rating});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(
      5,
      (index) => Icon(
        index < rating ? Icons.star : Icons.star_border,
        color: const Color(0xFFFFD83D),
        size: 16,
      ),
    ),
  );
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFCDD5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 36),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF777777), fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

String _formatDate(DateTime date) {
  if (date.millisecondsSinceEpoch == 0) return 'Date unavailable';
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
