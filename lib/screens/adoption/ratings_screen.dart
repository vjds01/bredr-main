import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class RatingsScreen extends StatefulWidget {
  const RatingsScreen({super.key});

  @override
  State<RatingsScreen> createState() => _RatingsScreenState();
}

class _RatingsScreenState extends State<RatingsScreen> {
  String _filter = 'All';

  final _reviews = [
    _Review(name: 'Jamie Anderson', petName: 'Cooper', rating: 4,
        text: '"Chelsea was so kind and transparent. Rocky arrived healthy and exactly as described. Highly recommended! 🐾"',
        date: 'April 15, 2025', type: 'Adoption'),
    _Review(name: 'Amelia Cruz', petName: 'Luna', rating: 3,
        text: '"Luna is a wonderful, healthy Golden. Chelsea shared all health documents upfront. Great breeding partner!"',
        date: 'May 1, 2026', type: 'Breeding'),
    _Review(name: 'John Bartolome', petName: 'Max', rating: 5,
        text: '"Luna is a wonderful, healthy Golden. Chelsea shared all health documents upfront. Great breeding partner!"',
        date: 'April 28, 2025', type: 'Breeding'),
  ];

  List<_Review> get _filtered {
    if (_filter == 'All') return _reviews;
    return _reviews.where((r) => r.type == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back + title
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios,
                      color: AppColors.primary, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                const Text('Mia Santiago Ratings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                        color: AppColors.primary)),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // Ratings summary card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0F5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFFCDD5))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('ADOPTION RATINGS',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                                color: Color(0xFF444444), letterSpacing: 0.8)),
                        const SizedBox(height: 12),
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Column(children: [
                            const Text('4.9', style: TextStyle(fontSize: 36,
                                fontWeight: FontWeight.bold, color: Color(0xFFF2AA58))),
                            Row(children: List.generate(5, (i) => Icon(
                                i < 4 ? Icons.star : Icons.star_border,
                                size: 16, color: const Color(0xFFF2AA58)))),
                            const Text('28 reviews',
                                style: TextStyle(fontSize: 10, color: Color(0xFF888888))),
                          ]),
                          const SizedBox(width: 16),
                          Expanded(child: Column(children: List.generate(5, (i) {
                            final star = 5 - i;
                            final counts = [23, 4, 1, 0, 0];
                            final count = counts[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(children: [
                                Text('$star', style: const TextStyle(
                                    fontSize: 10, color: Color(0xFF888888))),
                                const SizedBox(width: 4),
                                Expanded(child: SizedBox(
                                  height: 6,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: count / 28,
                                      backgroundColor: const Color(0xFFEEEEEE),
                                      valueColor: const AlwaysStoppedAnimation(
                                          Color(0xFFF2AA58)),
                                    ),
                                  ),
                                )),
                                const SizedBox(width: 4),
                                Text('$count', style: const TextStyle(
                                    fontSize: 10, color: Color(0xFF888888))),
                              ]),
                            );
                          }))),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 16),

                    // Filter chips
                    Row(children: [
                      _FilterChip(label: 'All', selected: _filter == 'All',
                          onTap: () => setState(() => _filter = 'All')),
                      const SizedBox(width: 8),
                      _FilterChip(
                          label: 'Adoption (${_reviews.where((r) => r.type == 'Adoption').length})',
                          selected: _filter == 'Adoption',
                          onTap: () => setState(() => _filter = 'Adoption'),
                          icon: Icons.home_outlined),
                      const SizedBox(width: 8),
                      _FilterChip(
                          label: 'Breeding (${_reviews.where((r) => r.type == 'Breeding').length})',
                          selected: _filter == 'Breeding',
                          onTap: () => setState(() => _filter = 'Breeding'),
                          icon: Icons.pets),
                    ]),
                    const SizedBox(height: 16),

                    // Review cards
                    ..._filtered.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ReviewCard(review: r),
                    )),
                    const SizedBox(height: 24),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  const _FilterChip({required this.label, required this.selected,
      required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFE8EA) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.primary : const Color(0xFFDDDDDD))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 12,
                color: selected ? AppColors.primary : const Color(0xFF888888)),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(
              fontSize: 12,
              color: selected ? AppColors.primary : const Color(0xFF888888),
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
        ]),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final _Review review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFCDD5),
              border: Border.all(color: const Color(0xFFDDDDDD))),
            child: ClipOval(child: Image.asset('assets/images/profile.png',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(Icons.person,
                    color: AppColors.primary, size: 20))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(review.name, style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
            Text('Adopted ${review.petName}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
          ])),
          Row(children: List.generate(5, (i) => Icon(
              i < review.rating ? Icons.star : Icons.star_border,
              size: 14, color: const Color(0xFFF2AA58)))),
        ]),
        const SizedBox(height: 10),
        Text(review.text, style: const TextStyle(
            fontSize: 12, color: Color(0xFF555555), height: 1.5)),
        const SizedBox(height: 8),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: review.type == 'Adoption'
                  ? const Color(0xFFFFE8EA)
                  : const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(review.type == 'Adoption' ? Icons.home_outlined : Icons.pets,
                  size: 10,
                  color: review.type == 'Adoption'
                      ? AppColors.primary
                      : const Color(0xFFF2AA58)),
              const SizedBox(width: 4),
              Text(review.type, style: TextStyle(
                  fontSize: 9,
                  color: review.type == 'Adoption'
                      ? AppColors.primary
                      : const Color(0xFFF2AA58),
                  fontWeight: FontWeight.bold)),
            ]),
          ),
          const Spacer(),
          Text(review.date, style: const TextStyle(
              fontSize: 10, color: Color(0xFF888888))),
        ]),
      ]),
    );
  }
}

class _Review {
  final String name, petName, text, date, type;
  final int rating;
  const _Review({required this.name, required this.petName, required this.rating,
      required this.text, required this.date, required this.type});
}
