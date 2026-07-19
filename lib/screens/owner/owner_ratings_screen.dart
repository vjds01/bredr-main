import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/breeding_match_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/breedr_network_image.dart';

enum OwnerReviewFilter { all, adoption, breeding }

class OwnerRatingsScreen extends StatefulWidget {
  final String ownerId;
  final String fallbackName;
  final String fallbackPhoto;
  final OwnerReviewFilter initialFilter;

  const OwnerRatingsScreen({
    super.key,
    required this.ownerId,
    this.fallbackName = 'Pet Owner',
    this.fallbackPhoto = '',
    this.initialFilter = OwnerReviewFilter.all,
  });

  @override
  State<OwnerRatingsScreen> createState() => _OwnerRatingsScreenState();
}

class _OwnerRatingsScreenState extends State<OwnerRatingsScreen> {
  late OwnerReviewFilter _filter = widget.initialFilter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.ownerId)
              .snapshots(),
          builder: (context, ownerSnapshot) {
            final owner = ownerSnapshot.data?.data();
            final ownerName =
                owner?['fullName'] as String? ?? widget.fallbackName;
            final ownerPhoto =
                owner?['profilePhoto'] as String? ?? widget.fallbackPhoto;

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: BreedingMatchService.instance
                  .watchPublishedReviewsForUser(widget.ownerId),
              builder: (context, reviewSnapshot) {
                final reviews = reviewSnapshot.data?.docs
                        .map((document) => _OwnerReview.fromDocument(document))
                        .toList() ??
                    <_OwnerReview>[];
                reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));

                final adoptionReviews = reviews
                    .where((review) => review.purpose == 'adoption')
                    .toList();
                final breedingReviews = reviews
                    .where((review) => review.purpose == 'breeding')
                    .toList();
                final visibleReviews = switch (_filter) {
                  OwnerReviewFilter.adoption => adoptionReviews,
                  OwnerReviewFilter.breeding => breedingReviews,
                  OwnerReviewFilter.all => reviews,
                };

                return Column(
                  children: [
                    _RatingsHeader(ownerName: ownerName),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                        children: [
                          _OwnerSummary(
                            ownerName: ownerName,
                            ownerPhoto: ownerPhoto,
                            reviews: visibleReviews,
                            allReviews: reviews,
                          ),
                          const SizedBox(height: 18),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _FilterPill(
                                  label: 'All (${reviews.length})',
                                  selected: _filter == OwnerReviewFilter.all,
                                  onTap: () => setState(
                                    () => _filter = OwnerReviewFilter.all,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _FilterPill(
                                  label:
                                      'Adoption (${adoptionReviews.length})',
                                  icon: Icons.home_outlined,
                                  selected:
                                      _filter == OwnerReviewFilter.adoption,
                                  onTap: () => setState(
                                    () => _filter = OwnerReviewFilter.adoption,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _FilterPill(
                                  label:
                                      'Breeding (${breedingReviews.length})',
                                  icon: Icons.pets,
                                  selected:
                                      _filter == OwnerReviewFilter.breeding,
                                  onTap: () => setState(
                                    () => _filter = OwnerReviewFilter.breeding,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (visibleReviews.isEmpty)
                            _NoReviewsPlaceholder(filter: _filter)
                          else
                            ...visibleReviews.map(
                              (review) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _ReviewCard(review: review),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _RatingsHeader extends StatelessWidget {
  final String ownerName;

  const _RatingsHeader({required this.ownerName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 18, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.primary),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              '$ownerName Ratings',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerSummary extends StatelessWidget {
  final String ownerName;
  final String ownerPhoto;
  final List<_OwnerReview> reviews;
  final List<_OwnerReview> allReviews;

  const _OwnerSummary({
    required this.ownerName,
    required this.ownerPhoto,
    required this.reviews,
    required this.allReviews,
  });

  @override
  Widget build(BuildContext context) {
    final counts = _ratingCounts(reviews);
    final average = _average(reviews);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE1E8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFB9C5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33FE5062),
            blurRadius: 0,
            offset: Offset(5, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(photoUrl: ownerPhoto, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  ownerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF333333),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 104,
                child: Column(
                  children: [
                    Text(
                      average == null ? 'New' : average.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Color(0xFFF2AA32),
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    _Stars(rating: average?.round() ?? 0, size: 18),
                    const SizedBox(height: 4),
                    Text(
                      '${reviews.length} ${reviews.length == 1 ? 'review' : 'reviews'}',
                      style: const TextStyle(
                        color: Color(0xFF777777),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: List.generate(5, (index) {
                    final star = 5 - index;
                    final count = counts[star] ?? 0;
                    final total = reviews.isEmpty ? 1 : reviews.length;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        children: [
                          Text(
                            '$star',
                            style: const TextStyle(
                              color: Color(0xFF777777),
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: SizedBox(
                              height: 7,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: count / total,
                                  backgroundColor: const Color(0xFFFFF7D9),
                                  color: const Color(0xFFFFDA47),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            count.toString(),
                            style: const TextStyle(
                              color: Color(0xFF777777),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
          if (allReviews.isEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'This owner is still building their public review history.',
              style: TextStyle(
                color: Color(0xFF666666),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Map<int, int> _ratingCounts(List<_OwnerReview> reviews) {
    final counts = {for (var rating = 1; rating <= 5; rating++) rating: 0};
    for (final review in reviews) {
      final rating = review.overall.clamp(1, 5).toInt();
      counts[rating] = (counts[rating] ?? 0) + 1;
    }
    return counts;
  }

  double? _average(List<_OwnerReview> reviews) {
    if (reviews.isEmpty) return null;
    final total = reviews.fold<int>(0, (sum, review) => sum + review.overall);
    return total / reviews.length;
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFE1E8) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFFFCDD5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: AppColors.primary),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.primary : const Color(0xFF777777),
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final _OwnerReview review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(review.reviewerId)
          .snapshots(),
      builder: (context, snapshot) {
        final reviewer = snapshot.data?.data();
        final reviewerName =
            reviewer?['fullName'] as String? ?? 'Breedr owner';
        final reviewerPhoto = reviewer?['profilePhoto'] as String? ?? '';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFFCDD5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Avatar(photoUrl: reviewerPhoto, size: 42),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reviewerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF333333),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          review.purpose == 'adoption'
                              ? 'Adoption review'
                              : 'Breeding review',
                          style: const TextStyle(
                            color: Color(0xFF888888),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _Stars(rating: review.overall, size: 15),
                ],
              ),
              if (review.text.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '"${review.text}"',
                  style: const TextStyle(
                    color: Color(0xFF555555),
                    fontSize: 12,
                    height: 1.45,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  _PurposeBadge(purpose: review.purpose),
                  const Spacer(),
                  Text(
                    review.formattedDate,
                    style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NoReviewsPlaceholder extends StatelessWidget {
  final OwnerReviewFilter filter;

  const _NoReviewsPlaceholder({required this.filter});

  @override
  Widget build(BuildContext context) {
    final label = switch (filter) {
      OwnerReviewFilter.adoption => 'adoption',
      OwnerReviewFilter.breeding => 'breeding',
      OwnerReviewFilter.all => 'public',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCDD5)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.rate_review_outlined,
            color: AppColors.primary,
            size: 34,
          ),
          const SizedBox(height: 10),
          Text(
            'No $label reviews yet',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Reviews will appear here after completed transactions are published.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF777777),
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String photoUrl;
  final double size;

  const _Avatar({
    required this.photoUrl,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFFFCDD5),
      ),
      clipBehavior: Clip.antiAlias,
      child: BreedrNetworkImage(
        imageUrl: photoUrl,
        width: size,
        height: size,
        fallback: const Icon(
          Icons.person,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  final int rating;
  final double size;

  const _Stars({
    required this.rating,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: const Color(0xFFFFD83D),
          size: size,
        );
      }),
    );
  }
}

class _PurposeBadge extends StatelessWidget {
  final String purpose;

  const _PurposeBadge({required this.purpose});

  @override
  Widget build(BuildContext context) {
    final isAdoption = purpose == 'adoption';
    final color = isAdoption ? AppColors.primary : const Color(0xFFF2AA58);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isAdoption ? const Color(0xFFFFE8EA) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isAdoption ? Icons.home_outlined : Icons.pets, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            isAdoption ? 'Adoption' : 'Breeding',
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerReview {
  final String reviewerId;
  final String purpose;
  final int overall;
  final String text;
  final DateTime createdAt;

  const _OwnerReview({
    required this.reviewerId,
    required this.purpose,
    required this.overall,
    required this.text,
    required this.createdAt,
  });

  factory _OwnerReview.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final timestamp = data['createdAt'] as Timestamp?;
    final completedAt = data['completedAt'] as Timestamp?;

    return _OwnerReview(
      reviewerId: data['reviewerId'] as String? ?? '',
      purpose: data['purpose'] as String? ?? 'breeding',
      overall: ((data['overall'] as num?)?.round() ?? 0).clamp(0, 5).toInt(),
      text: data['reviewText'] as String? ?? '',
      createdAt: timestamp?.toDate() ??
          completedAt?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  String get formattedDate {
    if (createdAt.millisecondsSinceEpoch == 0) return '';
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
    return '${months[createdAt.month - 1]} ${createdAt.day}, ${createdAt.year}';
  }
}
