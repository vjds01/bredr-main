import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/breeding_match_service.dart';
import '../../theme/app_colors.dart';
import '../owner/owner_ratings_screen.dart';

class OwnerProfileScreen extends StatefulWidget {
  final String ownerId;
  final String fallbackName;
  final String fallbackPhoto;

  const OwnerProfileScreen({
    super.key,
    required this.ownerId,
    this.fallbackName = 'Pet Owner',
    this.fallbackPhoto = '',
  });

  @override
  State<OwnerProfileScreen> createState() => _OwnerProfileScreenState();
}

class _OwnerProfileScreenState extends State<OwnerProfileScreen> {
  final PageController _photoController = PageController(viewportFraction: 0.68);
  int _photoIndex = 0;

  @override
  void dispose() {
    _photoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7FA),
        foregroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.ownerId)
            .snapshots(),
        builder: (context, ownerSnapshot) {
          if (ownerSnapshot.hasError) {
            return const _OwnerEmpty(
              icon: Icons.cloud_off_outlined,
              title: 'Profile unavailable',
              message: 'Check your connection and try again.',
            );
          }
          if (!ownerSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          final data = ownerSnapshot.data?.data();
          if (data == null) {
            return const _OwnerEmpty(
              icon: Icons.person_off_outlined,
              title: 'Profile unavailable',
              message: 'This pet owner profile could not be found.',
            );
          }
          return _profile(data);
        },
      ),
    );
  }

  Widget _profile(Map<String, dynamic> data) {
    final name =
        data['fullName'] as String? ?? widget.fallbackName;
    final photo =
        data['profilePhoto'] as String? ?? widget.fallbackPhoto;
    final userName = data['userName'] as String? ?? '';
    final location = data['locationName'] as String? ?? 'Location not set';
    final bio = data['bio'] as String? ??
        'This pet owner has not added an introduction yet.';
    final homeType = data['homeType'] as String? ?? 'Not set';
    final hasKids = data['childrenAtHome'] as bool? ?? false;
    final hasPets = data['otherPetsAtHome'] as bool? ?? false;
    final images =
        (data['additionalImages'] as List?)?.whereType<String>().toList() ??
            const <String>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: const Color(0xFFFFD9E1),
              backgroundImage: photo.isEmpty ? null : NetworkImage(photo),
              child: photo.isEmpty
                  ? const Icon(
                      Icons.person,
                      size: 45,
                      color: AppColors.primary,
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (userName.isNotEmpty)
                    Text(
                      '@$userName',
                      style: const TextStyle(
                        color: Color(0xFF777777),
                        fontSize: 11,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          location,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 7,
          children: [
            _OwnerTag(homeType),
            if (hasKids) const _OwnerTag('Has kids'),
            if (hasPets) const _OwnerTag('Has pets'),
          ],
        ),
        const SizedBox(height: 20),
        _OwnerStats(ownerId: widget.ownerId),
        const SizedBox(height: 22),
        const _OwnerSectionTitle('ABOUT ME'),
        const SizedBox(height: 9),
        _OwnerBox(child: Text(bio, textAlign: TextAlign.center)),
        const SizedBox(height: 22),
        const _OwnerSectionTitle('HOME INFORMATION'),
        const SizedBox(height: 9),
        _OwnerBox(
          child: Column(
            children: [
              _OwnerInfoRow('Home Type', homeType),
              _OwnerInfoRow('Location', location),
              _OwnerInfoRow('Pets at Home', hasPets ? 'YES' : 'NO'),
              _OwnerInfoRow('Kids at Home', hasKids ? 'YES' : 'NO'),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: _OwnerSectionTitle('MORE PHOTOS OF THE OWNER'),
            ),
            Text(
              images.isEmpty
                  ? '0 / 0'
                  : '${_photoIndex + 1} / ${images.length}',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (images.isEmpty)
          const _OwnerEmpty(
            icon: Icons.photo_outlined,
            title: 'No additional photos',
            message: 'This owner has not shared more photos yet.',
            compact: true,
          )
        else
          SizedBox(
            height: 270,
            child: PageView.builder(
              controller: _photoController,
              itemCount: images.length,
              onPageChanged: (index) {
                setState(() => _photoIndex = index);
              },
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    images[index],
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: Color(0xFFFFE4EA),
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.primary,
                        size: 50,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 22),
        const _OwnerSectionTitle('ADOPTION RATINGS'),
        const SizedBox(height: 9),
        _AdoptionRatingsCard(
          ownerId: widget.ownerId,
          ownerName: name,
          ownerPhoto: photo,
        ),
      ],
    );
  }
}

class _OwnerStats extends StatelessWidget {
  final String ownerId;

  const _OwnerStats({required this.ownerId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: BreedingMatchService.instance
          .watchPublishedReviewsForUser(ownerId),
      builder: (context, reviewSnapshot) {
        final reviews = reviewSnapshot.data?.docs ?? const [];
        final adoption = reviews
            .where((document) => document.data()['purpose'] == 'adoption')
            .toList();
        final breeding = reviews
            .where((document) => document.data()['purpose'] == 'breeding')
            .toList();
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('pets')
              .where('ownerId', isEqualTo: ownerId)
              .snapshots(),
          builder: (context, petSnapshot) {
            return Row(
              children: [
                Expanded(
                  child: _Stat(
                    value: _average(adoption),
                    label: 'Adoption Rating',
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _Stat(
                    value: _average(breeding),
                    label: 'Breeder Rating',
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _Stat(
                    value: '${petSnapshot.data?.docs.length ?? 0}',
                    label: 'Pets Listed',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _average(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> reviews,
  ) {
    final ratings = reviews
        .map((document) => document.data()['overall'])
        .whereType<num>()
        .map((value) => value.toDouble())
        .toList();
    if (ratings.isEmpty) return 'New';
    return (ratings.reduce((a, b) => a + b) / ratings.length)
        .toStringAsFixed(1);
  }
}

class _AdoptionRatingsCard extends StatelessWidget {
  final String ownerId;
  final String ownerName;
  final String ownerPhoto;

  const _AdoptionRatingsCard({
    required this.ownerId,
    required this.ownerName,
    required this.ownerPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: BreedingMatchService.instance
          .watchPublishedReviewsForUser(ownerId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _OwnerEmpty(
            icon: Icons.cloud_off_outlined,
            title: 'Ratings unavailable',
            message: 'Reviews could not be loaded right now.',
            compact: true,
          );
        }
        final reviews = (snapshot.data?.docs ?? const [])
            .where((document) => document.data()['purpose'] == 'adoption')
            .toList();
        final ratings = reviews
            .map((document) => document.data()['overall'])
            .whereType<num>()
            .map((value) => value.toDouble())
            .toList();
        final average = ratings.isEmpty
            ? null
            : ratings.reduce((a, b) => a + b) / ratings.length;
        return InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OwnerRatingsScreen(
                ownerId: ownerId,
                fallbackName: ownerName,
                fallbackPhoto: ownerPhoto,
                initialFilter: OwnerReviewFilter.adoption,
              ),
            ),
          ),
          borderRadius: BorderRadius.circular(7),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE4EA),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: const Color(0xFFFFAFC0)),
            ),
            child: Row(
              children: [
                Column(
                  children: [
                    Text(
                      average?.toStringAsFixed(1) ?? 'New',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      ratings.isEmpty
                          ? 'No reviews yet'
                          : '${ratings.length} ${ratings.length == 1 ? 'review' : 'reviews'}',
                      style: const TextStyle(
                        color: Color(0xFF777777),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'View all adoption reviews',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.primary),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFFB5C2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _OwnerTag extends StatelessWidget {
  final String text;

  const _OwnerTag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE4EA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(fontSize: 10)),
    );
  }
}

class _OwnerBox extends StatelessWidget {
  final Widget child;

  const _OwnerBox({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F4),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFAAAAAA)),
      ),
      child: child,
    );
  }
}

class _OwnerInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _OwnerInfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerSectionTitle extends StatelessWidget {
  final String text;

  const _OwnerSectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF555555),
        fontSize: 12,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _OwnerEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final bool compact;

  const _OwnerEmpty({
    required this.icon,
    required this.title,
    required this.message,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 18 : 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 34 : 58, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF777777),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
