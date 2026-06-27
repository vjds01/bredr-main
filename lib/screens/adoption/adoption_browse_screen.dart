import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/adoption_models.dart';
import '../../services/adoption_service.dart';
import '../../services/user_session_service.dart';
import '../../theme/app_colors.dart';
import 'adoption_request_detail_screen.dart';
import 'owner_adoption_request_detail_screen.dart';
import 'pet_adoption_profile_screen.dart';

class AdoptionBrowseScreen extends StatefulWidget {
  final ValueListenable<int>? activationSignal;

  const AdoptionBrowseScreen({
    super.key,
    this.activationSignal,
  });

  @override
  State<AdoptionBrowseScreen> createState() => _AdoptionBrowseScreenState();
}

class _AdoptionBrowseScreenState extends State<AdoptionBrowseScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _showLocationSearch = true;
  int _loadingRun = 0;
  _AdoptionFilter _filter = const _AdoptionFilter();
  _ListingQuickFilter _listingFilter = _ListingQuickFilter.all;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    widget.activationSignal?.addListener(_handleActivation);
    _startLocationSearch();
  }

  @override
  void dispose() {
    widget.activationSignal?.removeListener(_handleActivation);
    _tabController.dispose();
    super.dispose();
  }

  void _handleActivation() {
    if (_tabController.index == 0) {
      _startLocationSearch();
    }
  }

  void _startLocationSearch() {
    final run = ++_loadingRun;
    if (mounted) setState(() => _showLocationSearch = true);
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (!mounted || run != _loadingRun) return;
      setState(() => _showLocationSearch = false);
    });
  }

  Future<void> _showFilterSheet(List<AdoptionListing> listings) async {
    final filter = await showModalBottomSheet<_AdoptionFilter>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AdoptionFilterSheet(
        initialFilter: _filter,
        listings: listings,
      ),
    );
    if (filter == null || !mounted) return;
    setState(() => _filter = filter);
    _startLocationSearch();
  }

  @override
  Widget build(BuildContext context) {
    final user = UserSessionService.instance.currentUser;
    if (user == null) {
      return const Center(
        child: _AdoptionEmptyState(
          icon: Icons.lock_outline,
          title: 'Please sign in first',
          message: 'Your adoption activity will appear after you sign in.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F8),
      body: SafeArea(
        child: Column(
          children: [
            _AdoptionHeader(
              favoritePetIds:
                  AdoptionService.instance.watchFavoritePetIds(
                purpose: 'adoption',
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF222222),
              unselectedLabelColor: const Color(0xFF555555),
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
              indicatorColor: AppColors.primary,
              indicatorWeight: 2,
              tabs: const [
                Tab(text: 'Browse'),
                Tab(text: 'My Request'),
                Tab(text: 'My Listings'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _BrowseTab(
                    filter: _filter,
                    showLocationSearch: _showLocationSearch,
                    onShowFilter: _showFilterSheet,
                  ),
                  const _MyRequestsTab(),
                  _MyListingsTab(
                    selectedFilter: _listingFilter,
                    onFilterChanged: (filter) {
                      setState(() => _listingFilter = filter);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdoptionHeader extends StatelessWidget {
  final Stream<Set<String>> favoritePetIds;

  const _AdoptionHeader({required this.favoritePetIds});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 14, 4),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'ADOPTION',
              style: TextStyle(
                color: Color(0xFF111111),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          StreamBuilder<Set<String>>(
            stream: favoritePetIds,
            initialData: const {},
            builder: (context, snapshot) {
              final count = snapshot.data?.length ?? 0;
              return Tooltip(
                message: 'Saved adoption listings',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _showSavedListings(context),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: const Color(0xFFE59AEC),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: AppColors.primary,
                          size: 23,
                        ),
                      ),
                      Positioned(
                        right: -3,
                        top: -4,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 20),
                          height: 20,
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            borderRadius:
                                BorderRadius.all(Radius.circular(10)),
                          ),
                          child: Text(
                            count > 99 ? '99+' : '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const Positioned(
                        right: -2,
                        bottom: -1,
                        child: CircleAvatar(
                          radius: 9,
                          backgroundColor: Color(0xFFB16CEA),
                          child: Icon(Icons.add, size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showSavedListings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFF7FA),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.82,
        child: _SavedListingsSheet(),
      ),
    );
  }
}

class _SavedListingsSheet extends StatelessWidget {
  const _SavedListingsSheet();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Set<String>>(
      stream: AdoptionService.instance.watchFavoritePetIds(
        purpose: 'adoption',
      ),
      initialData: const {},
      builder: (context, favoriteSnapshot) {
        final favoriteIds = favoriteSnapshot.data ?? const <String>{};
        return StreamBuilder<List<AdoptionListing>>(
          stream: AdoptionService.instance.watchAvailableListings(),
          builder: (context, listingSnapshot) {
            final listings = (listingSnapshot.data ?? const <AdoptionListing>[])
                .where((listing) => favoriteIds.contains(listing.id))
                .toList();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                      const Expanded(
                        child: Text(
                          'Saved Listings',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: listings.isEmpty
                      ? const _AdoptionEmptyState(
                          icon: Icons.favorite_border,
                          title: 'No saved listings yet',
                          message:
                              'Pets you save from Browse will appear here.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: listings.length,
                          itemBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _AdoptionListingCard(
                              listing: listings[index],
                              isFavorite: true,
                            ),
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _BrowseTab extends StatelessWidget {
  final _AdoptionFilter filter;
  final bool showLocationSearch;
  final Future<void> Function(List<AdoptionListing>) onShowFilter;

  const _BrowseTab({
    required this.filter,
    required this.showLocationSearch,
    required this.onShowFilter,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdoptionListing>>(
      stream: AdoptionService.instance.watchAvailableListings(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _AdoptionEmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Adoption listings are unavailable',
            message: 'Check your connection and try again.',
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final allListings = snapshot.data!;
        final listings =
            allListings.where(filter.matches).toList(growable: false);

        if (showLocationSearch) {
          return const _AdoptionLocationSearch();
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${listings.length} ${listings.length == 1 ? 'pet' : 'pets'} available',
                      style: const TextStyle(
                        color: Color(0xFF777777),
                        fontSize: 11,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onShowFilter(allListings),
                    icon: const Icon(Icons.tune, size: 17),
                    label: const Text('Filter'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF444444),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFDDDDDD)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: listings.isEmpty
                  ? _AdoptionEmptyState(
                      icon: Icons.pets,
                      title: allListings.isEmpty
                          ? 'No adoption listings nearby'
                          : 'No pets match these filters',
                      message: allListings.isEmpty
                          ? 'New adoption listings will appear here when they become available.'
                          : 'Try changing the breed, age, price, or verification filters.',
                    )
                  : StreamBuilder<Set<String>>(
                      stream:
                          AdoptionService.instance.watchFavoritePetIds(
                        purpose: 'adoption',
                      ),
                      initialData: const {},
                      builder: (context, favoriteSnapshot) {
                        final favorites =
                            favoriteSnapshot.data ?? const <String>{};
                        return ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 2, 16, 28),
                          itemCount: listings.length,
                          itemBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _AdoptionListingCard(
                              listing: listings[index],
                              isFavorite:
                                  favorites.contains(listings[index].id),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _AdoptionLocationSearch extends StatelessWidget {
  const _AdoptionLocationSearch();

  @override
  Widget build(BuildContext context) {
    final userId = UserSessionService.instance.currentUser?.uid;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/Location.png',
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const ColoredBox(
            color: Color(0xFFFFE9EF),
          ),
        ),
        Container(color: Colors.white.withValues(alpha: 0.42)),
        const Positioned(
          left: 18,
          top: 100,
          child: _MapPetPin(species: 'cat'),
        ),
        const Positioned(
          right: 14,
          top: 205,
          child: _MapPetPin(species: 'dog'),
        ),
        const Positioned(
          left: 30,
          bottom: 80,
          child: _MapPetPin(species: 'cat'),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: userId == null
                    ? null
                    : FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .snapshots(),
                builder: (context, snapshot) {
                  final photo =
                      snapshot.data?.data()?['profilePhoto'] as String? ?? '';
                  return Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFFC8D3),
                      border: Border.all(
                        color: AppColors.primary,
                        width: 5,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: photo.isEmpty
                        ? const Icon(
                            Icons.person,
                            size: 66,
                            color: Colors.white,
                          )
                        : Image.network(
                            photo,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.person,
                              size: 66,
                              color: Colors.white,
                            ),
                          ),
                  );
                },
              ),
              const SizedBox(height: 18),
              const Text(
                'Finding pets near you...',
                style: TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MapPetPin extends StatelessWidget {
  final String species;

  const _MapPetPin({required this.species});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFFE3EA),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 5),
        ],
      ),
      child: Icon(
        species == 'cat' ? Icons.cruelty_free : Icons.pets,
        color: AppColors.primary,
      ),
    );
  }
}

class _AdoptionListingCard extends StatefulWidget {
  final AdoptionListing listing;
  final bool isFavorite;

  const _AdoptionListingCard({
    required this.listing,
    required this.isFavorite,
  });

  @override
  State<_AdoptionListingCard> createState() => _AdoptionListingCardState();
}

class _AdoptionListingCardState extends State<_AdoptionListingCard> {
  bool _saving = false;

  Future<void> _toggleFavorite() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final saved =
          await AdoptionService.instance.toggleFavorite(widget.listing.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? '${widget.listing.name} was saved to Favorites.'
                : '${widget.listing.name} was removed from Favorites.',
          ),
        ),
      );
    } on AdoptionServiceException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openProfile() {
    AdoptionService.instance.recordListingView(widget.listing.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PetAdoptionProfileScreen(
          listingId: widget.listing.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    return InkWell(
      onTap: _openProfile,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 188,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _PetImage(
                    url: listing.profilePhoto,
                    species: listing.species,
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: _AdoptionTypeBadge(listing: listing),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: IconButton.filled(
                      tooltip: widget.isFavorite
                          ? 'Remove from Favorites'
                          : 'Save to Favorites',
                      onPressed: _saving ? null : _toggleFavorite,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                      ),
                      icon: Icon(
                        widget.isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          listing.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (listing.isForSale)
                        Text(
                          'PHP ${_formatPrice(listing.price ?? 0)}',
                          style: const TextStyle(
                            color: Color(0xFF1478D4),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      listing.breed,
                      listing.breedSize,
                      listing.gender,
                      listing.age,
                    ].where((value) => value.trim().isNotEmpty).join('  |  '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF333333),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 13,
                        color: Color(0xFF777777),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          listing.locationName.isEmpty
                              ? 'Location not available'
                              : listing.locationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF777777),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 6,
                    children: [
                      if (listing.vetVerified)
                        const _InfoChip(
                          text: 'Vet Verified',
                          color: Color(0xFF57BCEB),
                        ),
                      if (listing.color.isNotEmpty)
                        _InfoChip(
                          text: listing.color,
                          color: const Color(0xFFFFDFE6),
                        ),
                      _InfoChip(
                        text: listing.isForSale ? 'For Sale' : 'Free',
                        color: const Color(0xFFFFE9BB),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _OwnerAvatar(url: listing.ownerPhoto),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          listing.ownerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyRequestsTab extends StatelessWidget {
  const _MyRequestsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdoptionRequest>>(
      stream: AdoptionService.instance.watchMyRequests(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _AdoptionEmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Requests are unavailable',
            message: 'Check your connection and try again.',
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        final requests = snapshot.data!;
        if (requests.isEmpty) {
          return const _AdoptionEmptyState(
            icon: Icons.assignment_outlined,
            title: 'No adoption requests yet',
            message:
                'Requests you submit from adoption listings will appear here.',
          );
        }
        final approved = requests
            .where((request) =>
                request.status == AdoptionRequestStatus.approved)
            .toList();
        final others = requests
            .where((request) =>
                request.status != AdoptionRequestStatus.approved)
            .toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            if (approved.isNotEmpty) ...[
              Text(
                'Approved Requests (${approved.length})',
                style: const TextStyle(
                  color: Color(0xFF777777),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),
              ...approved.map(
                (request) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _ApplicantRequestCard(request: request),
                ),
              ),
            ],
            if (others.isNotEmpty) ...[
              Text(
                'Other Requests (${others.length})',
                style: const TextStyle(
                  color: Color(0xFF777777),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),
              ...others.map(
                (request) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _ApplicantRequestCard(request: request),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ApplicantRequestCard extends StatelessWidget {
  final AdoptionRequest request;

  const _ApplicantRequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final pet = request.petSnapshot;
    final photo = pet['petProfilePhoto'] as String? ?? '';
    final name = pet['name'] as String? ?? 'Pet';
    final type = pet['adoptionType'] as String? ?? 'free';
    final price = (pet['price'] as num?)?.toDouble();
    final status = _requestPresentation(request.status);
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdoptionRequestDetailScreen(
              requestId: request.id,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 7,
              offset: Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 120,
              width: double.infinity,
              child: _PetImage(
                url: photo,
                species: pet['species'] as String? ?? '',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
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
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (type == 'forSale' && price != null)
                        Text(
                          'PHP ${_formatPrice(price)}',
                          style: const TextStyle(
                            color: Color(0xFF1478D4),
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      else
                        const _InfoChip(
                          text: 'Free',
                          color: Color(0xFFFFE9BB),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: status.background,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      children: [
                        Icon(status.icon, size: 17, color: status.color),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            status.message,
                            style: TextStyle(
                              color: status.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: Color(0xFF777777),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRequestSummary(
    BuildContext context,
    AdoptionRequest request,
  ) {
    final status = _requestPresentation(request.status);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFF7FA),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(status.icon, color: status.color, size: 38),
              const SizedBox(height: 10),
              Text(
                status.message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: status.color,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _requestHelpText(request.status),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              if (request.status == AdoptionRequestStatus.pending ||
                  request.status == AdoptionRequestStatus.underReview) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmWithdrawal(context, request);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                    ),
                    child: const Text('Withdraw Request'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmWithdrawal(
    BuildContext context,
    AdoptionRequest request,
  ) async {
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
            'Your submitted answers will remain read-only, and this request '
            'cannot be restored after withdrawal.',
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
    }
  }
}

class _MyListingsTab extends StatelessWidget {
  final _ListingQuickFilter selectedFilter;
  final ValueChanged<_ListingQuickFilter> onFilterChanged;

  const _MyListingsTab({
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdoptionListing>>(
      stream: AdoptionService.instance.watchMyListings(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _AdoptionEmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Listings are unavailable',
            message: 'Check your connection and try again.',
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        final allListings = snapshot.data!;
        final listings = allListings
            .where((listing) => selectedFilter.matches(listing))
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: _ListingQuickFilter.values
                    .map(
                      (filter) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(filter.label),
                          selected: selectedFilter == filter,
                          onSelected: (_) => onFilterChanged(filter),
                          selectedColor: Colors.white,
                          backgroundColor: const Color(0xFFFFDFE6),
                          side: selectedFilter == filter
                              ? const BorderSide(
                                  color: Color(0xFF222222),
                                  width: 1.5,
                                )
                              : BorderSide.none,
                          showCheckmark: false,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
              child: Text(
                'Your Listings (${listings.length})',
                style: const TextStyle(
                  color: Color(0xFF777777),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            Expanded(
              child: listings.isEmpty
                  ? _AdoptionEmptyState(
                      icon: Icons.home_outlined,
                      title: allListings.isEmpty
                          ? 'No adoption listings yet'
                          : 'No listings match this filter',
                      message: allListings.isEmpty
                          ? 'Pets you list for adoption will appear here.'
                          : 'Choose another filter to see your listings.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                      itemCount: listings.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _OwnerListingCard(
                          listing: listings[index],
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _OwnerListingCard extends StatelessWidget {
  final AdoptionListing listing;

  const _OwnerListingCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 145,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _PetImage(
                  url: listing.profilePhoto,
                  species: listing.species,
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: _AdoptionTypeBadge(listing: listing),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        listing.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (listing.isForSale)
                      Text(
                        'PHP ${_formatPrice(listing.price ?? 0)}',
                        style: const TextStyle(
                          color: Color(0xFF1478D4),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    listing.breed,
                    listing.breedSize,
                    listing.gender,
                    listing.age,
                  ].where((value) => value.isNotEmpty).join('  |  '),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  children: [
                    if (listing.vetVerified)
                      const _InfoChip(
                        text: 'Vet Verified',
                        color: Color(0xFF57BCEB),
                      ),
                    if (listing.color.isNotEmpty)
                      _InfoChip(
                        text: listing.color,
                        color: const Color(0xFFFFDFE6),
                      ),
                    _InfoChip(
                      text: _listingStatusLabel(listing.status),
                      color: listing.status == AdoptionListingStatus.reserved
                          ? const Color(0xFFFFE2AF)
                          : const Color(0xFFDDF5DE),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    StreamBuilder<int>(
                      stream: AdoptionService.instance
                          .watchListingViewCount(listing.id),
                      initialData: 0,
                      builder: (_, snapshot) => _Metric(
                        icon: Icons.visibility_outlined,
                        value: snapshot.data ?? 0,
                        label: 'views',
                      ),
                    ),
                    const SizedBox(width: 18),
                    StreamBuilder<int>(
                      stream: AdoptionService.instance
                          .watchActiveRequestCount(listing.id),
                      initialData: 0,
                      builder: (_, snapshot) => _Metric(
                        icon: Icons.favorite,
                        value: snapshot.data ?? 0,
                        label: 'requests',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _showListingRequests(
                      context,
                      listing,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: Text(
                      listing.status == AdoptionListingStatus.reserved
                          ? 'ADOPTION READY TO COMPLETE'
                          : 'REVIEW REQUESTS',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showListingRequests(
    BuildContext context,
    AdoptionListing listing,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFF7FA),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.88,
        child: _ListingRequestsSheet(listing: listing),
      ),
    );
  }
}

class _ListingRequestsSheet extends StatelessWidget {
  final AdoptionListing listing;

  const _ListingRequestsSheet({required this.listing});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdoptionRequest>>(
      stream: AdoptionService.instance.watchRequestsForListing(listing.id),
      builder: (context, snapshot) {
        final requests = snapshot.data ?? const <AdoptionRequest>[];
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 14, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.primary,
                    ),
                  ),
                  _OwnerAvatar(url: listing.profilePhoto),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "${listing.name}'s Requests",
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '${requests.length} applicants',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : requests.isEmpty
                  ? const _AdoptionEmptyState(
                      icon: Icons.assignment_ind_outlined,
                      title: 'No adoption requests yet',
                      message:
                          'Applicants will appear here after submitting their answers.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: requests.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _OwnerRequestCard(
                          request: requests[index],
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _OwnerRequestCard extends StatelessWidget {
  final AdoptionRequest request;

  const _OwnerRequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final applicant = request.applicantSnapshot;
    final name = applicant['fullName'] as String? ?? 'Applicant';
    final photo = applicant['profilePhoto'] as String? ?? '';
    final status = _requestPresentation(request.status);
    return InkWell(
      onTap: () {
        AdoptionService.instance.markRequestUnderReview(request.id).catchError(
          (_) {},
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OwnerAdoptionRequestDetailScreen(
              requestId: request.id,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFFD4DC)),
        ),
        child: Row(
          children: [
            _OwnerAvatar(url: photo, size: 58),
            const SizedBox(width: 12),
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
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    applicant['locationName'] as String? ??
                        'Location not available',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF777777),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 5,
                    children: [
                      _InfoChip(
                        text: applicant['homeType'] as String? ??
                            'Home not set',
                        color: const Color(0xFFFFE4EA),
                      ),
                      if (applicant['childrenAtHome'] == true)
                        const _InfoChip(
                          text: 'Has kids',
                          color: Color(0xFFFFE4EA),
                        ),
                      if (applicant['otherPetsAtHome'] == true)
                        const _InfoChip(
                          text: 'Has pets',
                          color: Color(0xFFFFE4EA),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: status.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _ownerRequestStatusMessage(request.status),
                      style: TextStyle(
                        color: status.color,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  void _showApplicantAnswers(
    BuildContext context,
    AdoptionRequest request,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFF7FA),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: _ApplicantAnswersSheet(request: request),
      ),
    );
  }
}

class _ApplicantAnswersSheet extends StatefulWidget {
  final AdoptionRequest request;

  const _ApplicantAnswersSheet({required this.request});

  @override
  State<_ApplicantAnswersSheet> createState() => _ApplicantAnswersSheetState();
}

class _ApplicantAnswersSheetState extends State<_ApplicantAnswersSheet> {
  bool _processing = false;

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
      Navigator.pop(context);
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
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final applicant = request.applicantSnapshot;
    final canDecide = request.status == AdoptionRequestStatus.pending ||
        request.status == AdoptionRequestStatus.underReview;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 12, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
              ),
              _OwnerAvatar(
                url: applicant['profilePhoto'] as String? ?? '',
                size: 52,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  applicant['fullName'] as String? ?? 'Applicant',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
            children: [
              const Text(
                'INTERVIEW ANSWERS',
                style: TextStyle(
                  color: Color(0xFF555555),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              if (request.answers.isEmpty)
                const _AdoptionEmptyState(
                  icon: Icons.question_answer_outlined,
                  title: 'No interview questions',
                  message:
                      'This listing did not include interview questions. Review the applicant profile before deciding.',
                )
              else
                ...request.answers.map(
                  (answer) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFFAFC0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            answer.questionText,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            answer.value?.toString() ?? 'No answer',
                            style: const TextStyle(
                              color: Color(0xFF555555),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (canDecide)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _processing ? null : () => _decide(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF51C64B),
                      ),
                      child: const Text('APPROVE'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _processing ? null : () => _decide(false),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      child: const Text('DECLINE'),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _AdoptionFilterSheet extends StatefulWidget {
  final _AdoptionFilter initialFilter;
  final List<AdoptionListing> listings;

  const _AdoptionFilterSheet({
    required this.initialFilter,
    required this.listings,
  });

  @override
  State<_AdoptionFilterSheet> createState() =>
      _AdoptionFilterSheetState();
}

class _AdoptionFilterSheetState extends State<_AdoptionFilterSheet> {
  late String _species = widget.initialFilter.species;
  late String? _breed = widget.initialFilter.breed;
  late int? _minAgeWeeks = widget.initialFilter.minAgeWeeks;
  late int? _maxAgeWeeks = widget.initialFilter.maxAgeWeeks;
  late bool _vaccinatedOnly = widget.initialFilter.vaccinatedOnly;
  late bool _vetVerifiedOnly = widget.initialFilter.vetVerifiedOnly;
  late AdoptionType? _adoptionType = widget.initialFilter.adoptionType;
  late double? _minPrice = widget.initialFilter.minPrice;
  late double? _maxPrice = widget.initialFilter.maxPrice;
  String? _error;

  List<String> get _availableBreeds {
    final species = _species.toLowerCase();
    final breeds = widget.listings
        .where((listing) =>
            species == 'all' ||
            listing.species.toLowerCase() == species.toLowerCase())
        .map((listing) => listing.breed.trim())
        .where((breed) => breed.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final fallback =
        species == 'cat' ? _catBreeds : species == 'dog' ? _dogBreeds : [];
    for (final breed in fallback) {
      if (!breeds.contains(breed)) breeds.add(breed);
    }
    return breeds;
  }

  Future<void> _selectBreed() async {
    final selected = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BreedPickerSheet(
        breeds: _availableBreeds,
        selectedBreed: _breed,
      ),
    );
    if (!mounted) return;
    setState(() => _breed = selected);
  }

  void _apply() {
    if (_minAgeWeeks != null && _minAgeWeeks! < 8) {
      setState(() {
        _error = 'Pets must be at least 8 weeks old for adoption.';
      });
      return;
    }
    if (_minAgeWeeks != null &&
        _maxAgeWeeks != null &&
        _minAgeWeeks! > _maxAgeWeeks!) {
      setState(() {
        _error =
            'Minimum adoption age cannot be greater than maximum age.';
      });
      return;
    }
    if ((_minPrice != null && _minPrice! < 0) ||
        (_maxPrice != null && _maxPrice! < 0)) {
      setState(() => _error = 'Price values cannot be negative.');
      return;
    }
    if (_minPrice != null &&
        _maxPrice != null &&
        _minPrice! > _maxPrice!) {
      setState(() {
        _error = 'Minimum price cannot be greater than maximum price.';
      });
      return;
    }
    Navigator.pop(
      context,
      _AdoptionFilter(
        species: _species,
        breed: _breed,
        minAgeWeeks: _minAgeWeeks,
        maxAgeWeeks: _maxAgeWeeks,
        vaccinatedOnly: _vaccinatedOnly,
        vetVerifiedOnly: _vetVerifiedOnly,
        adoptionType: _adoptionType,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.96,
      minChildSize: 0.65,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Filter Adoption',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _apply,
                  child: const Text('DONE'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _FilterLabel('Species'),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'All', label: Text('All')),
                ButtonSegment(value: 'Dog', label: Text('Dogs')),
                ButtonSegment(value: 'Cat', label: Text('Cats')),
              ],
              selected: {_species},
              onSelectionChanged: (selection) {
                setState(() {
                  _species = selection.first;
                  _breed = null;
                });
              },
            ),
            const SizedBox(height: 22),
            const _FilterLabel('Breed'),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _selectBreed,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(_breed ?? 'Any Breed'),
              ),
            ),
            const SizedBox(height: 22),
            const _FilterLabel('Age Range'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _AgeInput(
                    label: 'Min',
                    initialWeeks: _minAgeWeeks,
                    onChanged: (value) => _minAgeWeeks = value,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AgeInput(
                    label: 'Max',
                    initialWeeks: _maxAgeWeeks,
                    onChanged: (value) => _maxAgeWeeks = value,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const _FilterLabel('Adoption Type'),
            const SizedBox(height: 8),
            SegmentedButton<AdoptionType?>(
              segments: const [
                ButtonSegment(value: null, label: Text('All')),
                ButtonSegment(
                  value: AdoptionType.free,
                  label: Text('Free'),
                ),
                ButtonSegment(
                  value: AdoptionType.forSale,
                  label: Text('For Sale'),
                ),
              ],
              selected: {_adoptionType},
              onSelectionChanged: (selection) {
                setState(() => _adoptionType = selection.first);
              },
            ),
            if (_adoptionType != AdoptionType.free) ...[
              const SizedBox(height: 18),
              const _FilterLabel('Price Range'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _NumberField(
                      label: 'Minimum',
                      initialValue: _minPrice,
                      onChanged: (value) => _minPrice = value,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _NumberField(
                      label: 'Maximum',
                      initialValue: _maxPrice,
                      onChanged: (value) => _maxPrice = value,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 22),
            const _FilterLabel('Requirements'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Vaccinated Only',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle:
                  const Text('Show only pets with vaccination records'),
              value: _vaccinatedOnly,
              activeTrackColor: AppColors.primary,
              onChanged: (value) {
                setState(() => _vaccinatedOnly = value);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Vet Verified Only',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Show only vet-verified profiles'),
              value: _vetVerifiedOnly,
              activeTrackColor: AppColors.primary,
              onChanged: (value) {
                setState(() => _vetVerifiedOnly = value);
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE3E7),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: AppColors.primary),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _apply,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text(
                  'APPLY ADOPTION FILTER',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreedPickerSheet extends StatefulWidget {
  final List<String> breeds;
  final String? selectedBreed;

  const _BreedPickerSheet({
    required this.breeds,
    required this.selectedBreed,
  });

  @override
  State<_BreedPickerSheet> createState() => _BreedPickerSheetState();
}

class _BreedPickerSheetState extends State<_BreedPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final breeds = widget.breeds
        .where(
          (breed) => breed.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    return DraggableScrollableSheet(
      initialChildSize: 0.76,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select Breed',
                    style: TextStyle(
                      color: Color(0xFFFF8B2B),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(
                    context,
                    widget.selectedBreed,
                  ),
                  child: const Text('DONE'),
                ),
              ],
            ),
            TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'Search breed name...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('Any Breed'),
              trailing: widget.selectedBreed == null
                  ? const Icon(Icons.check_circle, color: Color(0xFFFFA64D))
                  : null,
              onTap: () => Navigator.pop(context),
            ),
            Expanded(
              child: ListView.separated(
                controller: controller,
                itemCount: breeds.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final breed = breeds[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFFE4EA),
                      child: Icon(Icons.pets, color: AppColors.primary),
                    ),
                    title: Text(breed),
                    trailing: breed == widget.selectedBreed
                        ? const Icon(
                            Icons.check_circle,
                            color: Color(0xFFFFA64D),
                          )
                        : const Icon(
                            Icons.radio_button_unchecked,
                            color: Color(0xFFFFA64D),
                          ),
                    onTap: () => Navigator.pop(context, breed),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgeInput extends StatefulWidget {
  final String label;
  final int? initialWeeks;
  final ValueChanged<int?> onChanged;

  const _AgeInput({
    required this.label,
    required this.initialWeeks,
    required this.onChanged,
  });

  @override
  State<_AgeInput> createState() => _AgeInputState();
}

class _AgeInputState extends State<_AgeInput> {
  late final TextEditingController _controller;
  String _unit = 'months';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    if (widget.initialWeeks != null) {
      _unit = 'weeks';
      _controller.text = '${widget.initialWeeks}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _emit() {
    final value = double.tryParse(_controller.text.trim());
    if (value == null) {
      widget.onChanged(null);
      return;
    }
    widget.onChanged(_ageValueToWeeks(value, _unit));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _emit(),
                decoration: const InputDecoration(
                  hintText: 'Age',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 6),
            DropdownButton<String>(
              value: _unit,
              items: const [
                DropdownMenuItem(value: 'weeks', child: Text('weeks')),
                DropdownMenuItem(value: 'months', child: Text('months')),
                DropdownMenuItem(value: 'years', child: Text('years')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _unit = value);
                _emit();
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _NumberField extends StatefulWidget {
  final String label;
  final double? initialValue;
  final ValueChanged<double?> onChanged;

  const _NumberField({
    required this.label,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue?.toStringAsFixed(0) ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (value) => widget.onChanged(
        double.tryParse(value.replaceAll(',', '').trim()),
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        prefixText: 'PHP ',
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _AdoptionFilter {
  final String species;
  final String? breed;
  final int? minAgeWeeks;
  final int? maxAgeWeeks;
  final bool vaccinatedOnly;
  final bool vetVerifiedOnly;
  final AdoptionType? adoptionType;
  final double? minPrice;
  final double? maxPrice;

  const _AdoptionFilter({
    this.species = 'All',
    this.breed,
    this.minAgeWeeks,
    this.maxAgeWeeks,
    this.vaccinatedOnly = false,
    this.vetVerifiedOnly = false,
    this.adoptionType,
    this.minPrice,
    this.maxPrice,
  });

  bool matches(AdoptionListing listing) {
    if (species != 'All' &&
        listing.species.toLowerCase() != species.toLowerCase()) {
      return false;
    }
    if (breed != null &&
        listing.breed.toLowerCase() != breed!.toLowerCase()) {
      return false;
    }
    final ageWeeks = _parseAgeInWeeks(listing.age);
    if (minAgeWeeks != null &&
        (ageWeeks == null || ageWeeks < minAgeWeeks!)) {
      return false;
    }
    if (maxAgeWeeks != null &&
        (ageWeeks == null || ageWeeks > maxAgeWeeks!)) {
      return false;
    }
    final vaccinated = listing.healthRecords.any((record) {
      final type = record['type']?.toString().toLowerCase() ?? '';
      return type.contains('vaccin');
    });
    if (vaccinatedOnly && !vaccinated) return false;
    if (vetVerifiedOnly && !listing.vetVerified) return false;
    if (adoptionType != null && listing.adoptionType != adoptionType) {
      return false;
    }
    if (listing.isForSale) {
      final price = listing.price ?? 0;
      if (minPrice != null && price < minPrice!) return false;
      if (maxPrice != null && price > maxPrice!) return false;
    } else if (minPrice != null && minPrice! > 0) {
      return false;
    }
    return true;
  }
}

enum _ListingQuickFilter { all, dogs, cats, free, forSale }

extension on _ListingQuickFilter {
  String get label {
    switch (this) {
      case _ListingQuickFilter.all:
        return 'All';
      case _ListingQuickFilter.dogs:
        return 'Dogs';
      case _ListingQuickFilter.cats:
        return 'Cats';
      case _ListingQuickFilter.free:
        return 'Free';
      case _ListingQuickFilter.forSale:
        return 'For Sale';
    }
  }

  bool matches(AdoptionListing listing) {
    switch (this) {
      case _ListingQuickFilter.all:
        return true;
      case _ListingQuickFilter.dogs:
        return listing.species.toLowerCase() == 'dog';
      case _ListingQuickFilter.cats:
        return listing.species.toLowerCase() == 'cat';
      case _ListingQuickFilter.free:
        return !listing.isForSale;
      case _ListingQuickFilter.forSale:
        return listing.isForSale;
    }
  }
}

class _AdoptionEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _AdoptionEmptyState({
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
              child: Icon(icon, size: 43, color: AppColors.primary),
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

class _PetImage extends StatelessWidget {
  final String url;
  final String species;

  const _PetImage({
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
          size: 58,
        ),
      ),
    );
  }
}

class _AdoptionTypeBadge extends StatelessWidget {
  final AdoptionListing listing;

  const _AdoptionTypeBadge({required this.listing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: listing.isForSale
            ? const Color(0xFF2389E8)
            : AppColors.primary,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        listing.isForSale ? 'FOR SALE' : 'FREE',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String text;
  final Color color;

  const _InfoChip({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF555555),
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _OwnerAvatar extends StatelessWidget {
  final String url;
  final double size;

  const _OwnerAvatar({
    required this.url,
    this.size = 34,
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

class _Metric extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;

  const _Metric({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.primary),
        const SizedBox(width: 4),
        Text(
          '$value $label',
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _FilterLabel extends StatelessWidget {
  final String text;

  const _FilterLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
    );
  }
}

class _RequestPresentation {
  final String message;
  final IconData icon;
  final Color color;
  final Color background;

  const _RequestPresentation({
    required this.message,
    required this.icon,
    required this.color,
    required this.background,
  });
}

String _requestHelpText(AdoptionRequestStatus status) {
  switch (status) {
    case AdoptionRequestStatus.pending:
      return 'The pet owner has received your request and has not reviewed it yet.';
    case AdoptionRequestStatus.underReview:
      return 'The pet owner is currently reviewing your submitted answers.';
    case AdoptionRequestStatus.approved:
      return 'Your request was approved. The adoption conversation is ready for both parties.';
    case AdoptionRequestStatus.rejected:
      return 'The pet owner declined this request. You can continue browsing other available pets.';
    case AdoptionRequestStatus.withdrawn:
      return 'You withdrew this adoption request.';
    case AdoptionRequestStatus.completed:
      return 'This adoption request has been completed.';
  }
}

String _firebaseActionMessage(FirebaseException error) {
  switch (error.code) {
    case 'permission-denied':
      return 'Breedr could not update this request. Please sign in again or '
          'check that the latest Firestore rules are deployed.';
    case 'unavailable':
      return 'The service is temporarily unavailable. Check your connection '
          'and try again.';
    case 'deadline-exceeded':
      return 'The request took too long to complete. Please try again.';
    default:
      return error.message?.trim().isNotEmpty == true
          ? error.message!
          : 'The request could not be updated. Please try again.';
  }
}

_RequestPresentation _requestPresentation(AdoptionRequestStatus status) {
  switch (status) {
    case AdoptionRequestStatus.approved:
      return const _RequestPresentation(
        message: 'The owner approved your request',
        icon: Icons.check_circle,
        color: Color(0xFF3BAA42),
        background: Color(0xFFE5F8E4),
      );
    case AdoptionRequestStatus.underReview:
      return const _RequestPresentation(
        message: 'The owner is still reviewing your answers',
        icon: Icons.visibility,
        color: Color(0xFFB27B17),
        background: Color(0xFFFFEDC2),
      );
    case AdoptionRequestStatus.pending:
      return const _RequestPresentation(
        message: 'Waiting for the owner to respond',
        icon: Icons.schedule,
        color: Color(0xFF9A8054),
        background: Color(0xFFF5E8CF),
      );
    case AdoptionRequestStatus.rejected:
      return const _RequestPresentation(
        message: 'The owner declined your request',
        icon: Icons.sentiment_dissatisfied,
        color: AppColors.primary,
        background: Color(0xFFFFE3E7),
      );
    case AdoptionRequestStatus.withdrawn:
      return const _RequestPresentation(
        message: 'You withdrew this adoption request',
        icon: Icons.undo,
        color: Color(0xFF777777),
        background: Color(0xFFF0F0F0),
      );
    case AdoptionRequestStatus.completed:
      return const _RequestPresentation(
        message: 'This adoption has been completed',
        icon: Icons.home,
        color: Color(0xFF3BAA42),
        background: Color(0xFFE5F8E4),
      );
  }
}

String _listingStatusLabel(AdoptionListingStatus status) {
  switch (status) {
    case AdoptionListingStatus.active:
      return 'Active';
    case AdoptionListingStatus.reserved:
      return 'Reserved';
    case AdoptionListingStatus.adopted:
      return 'Adopted';
    case AdoptionListingStatus.paused:
      return 'Paused';
    case AdoptionListingStatus.removed:
      return 'Removed';
  }
}

String _ownerRequestStatusMessage(AdoptionRequestStatus status) {
  switch (status) {
    case AdoptionRequestStatus.approved:
      return 'You approved this request';
    case AdoptionRequestStatus.underReview:
      return 'You are reviewing this request';
    case AdoptionRequestStatus.pending:
      return 'Waiting for your response';
    case AdoptionRequestStatus.rejected:
      return 'You declined this request';
    case AdoptionRequestStatus.withdrawn:
      return 'The applicant withdrew this request';
    case AdoptionRequestStatus.completed:
      return 'This adoption is completed';
  }
}

int? _parseAgeInWeeks(String ageText) {
  final normalized = ageText.toLowerCase().trim();
  final numberMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(normalized);
  if (numberMatch == null) return null;
  final value = double.tryParse(numberMatch.group(1)!);
  if (value == null || value <= 0) return null;
  if (normalized.contains('week')) return value.round();
  if (normalized.contains('month')) return (value * 4.345).round();
  if (normalized.contains('year')) return (value * 52.143).round();
  return null;
}

int _ageValueToWeeks(double value, String unit) {
  switch (unit) {
    case 'years':
      return (value * 52.143).round();
    case 'months':
      return (value * 4.345).round();
    default:
      return value.round();
  }
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

const _dogBreeds = [
  'American Shih Tzu',
  'Aspin',
  'Beagle',
  'Chihuahua',
  'Dachshund',
  'German Shepherd',
  'Golden Retriever',
  'Husky',
  'Labrador Retriever',
  'Pomeranian',
  'Poodle',
  'Pug',
  'Shiba Inu',
];

const _catBreeds = [
  'Bengal',
  'British Shorthair',
  'Maine Coon',
  'Persian',
  'Persian Cat',
  'Ragdoll',
  'Russian Blue',
  'Siamese',
  'Sphynx',
];
