import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../services/cloudinary_service.dart';
import '../services/breeding_match_service.dart';
import '../services/presence_service.dart';
import '../services/user_session_service.dart';
import '../theme/app_colors.dart';
import '../widgets/breedr_network_image.dart';
import 'adoption/adoption_browse_screen.dart';
import 'auth/get_started_screen.dart';
import 'breeding/breeding_screen.dart';
import 'chat/chats_screen.dart';
import 'notifications/notifications_screen.dart';
import 'owner/owner_ratings_screen.dart';
import 'pet/health_vault_screen.dart';
import 'pet/location_settings_screen.dart';
import 'pet/pet_registration_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final ValueNotifier<int> _breedingActivation = ValueNotifier<int>(0);
  final ValueNotifier<int> _adoptionActivation = ValueNotifier<int>(0);

  late final List<Widget> _tabs = [
    BreedingScreen(activationSignal: _breedingActivation),
    AdoptionBrowseScreen(activationSignal: _adoptionActivation),
    const ChatsScreen(),
    const NotificationsScreen(),
    _ProfileTab(onLogout: _logout),
  ];

  @override
  void initState() {
    super.initState();
    PresenceService.instance.start().catchError((Object error) {
      debugPrint('Presence service could not start: $error');
    });
    BreedingMatchService.instance
        .processPendingCompletionsForCurrentUser()
        .catchError((Object error) {
      debugPrint('Pending completion check failed: $error');
    });
    BreedingMatchService.instance
        .processReviewReleasesForCurrentUser()
        .catchError((Object error) {
      debugPrint('Review release check failed: $error');
    });
  }

  @override
  void dispose() {
    _breedingActivation.dispose();
    _adoptionActivation.dispose();
    PresenceService.instance.stop().catchError((Object error) {
      debugPrint('Presence service could not stop: $error');
    });
    super.dispose();
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to use Breedr.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    await PresenceService.instance.stop();
    await UserSessionService.instance.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const GetStartedScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabs,
      ),
      bottomNavigationBar: _HomeBottomNav(
        selectedIndex: _selectedIndex,
        onTap: (index) {
          if (index == 0) {
            _breedingActivation.value++;
          } else if (index == 1) {
            _adoptionActivation.value++;
          }
          setState(() => _selectedIndex = index);
        },
      ),
    );
  }
}

class _HomeBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _HomeBottomNav({
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const items = [
      _NavItem(icon: Icons.favorite, label: 'Breeding'),
      _NavItem(icon: Icons.pets, label: 'Adoption'),
      _NavItem(icon: Icons.chat_bubble_outline, label: 'Chat'),
      _NavItem(icon: Icons.notifications_outlined, label: 'Notif'),
      _NavItem(icon: Icons.person_outline, label: 'Profile'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = index == selectedIndex;

              return GestureDetector(
                onTap: () => onTap(index),
                child: SizedBox(
                  width: 64,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        size: 24,
                        color: isSelected
                            ? AppColors.primary
                            : const Color(0xFF888888),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected
                              ? AppColors.primary
                              : const Color(0xFF888888),
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.label,
  });
}

class _ProfileTab extends StatefulWidget {
  final Future<void> Function() onLogout;

  const _ProfileTab({
    required this.onLogout,
  });

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  Future<DocumentSnapshot<Map<String, dynamic>>?>? _profileFuture;

  void _refreshProfile() {
    final user = UserSessionService.instance.currentUser;
    setState(() {
      _profileFuture =
          user == null ? null : UserSessionService.instance.getCurrentUserProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = UserSessionService.instance.currentUser;
    _profileFuture ??=
        user == null ? null : UserSessionService.instance.getCurrentUserProfile();

    return SafeArea(
      child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          final data = snapshot.data?.data();
          final fullName =
              data?['fullName'] as String? ?? user?.displayName ?? 'Breedr User';
          final bio = data?['bio'] as String? ??
              'Tell other pet owners a little about yourself.';
          final homeType = data?['homeType'] as String? ?? 'Not set';
          final locationName =
              data?['locationName'] as String? ?? 'Location not set';
          final hasKids = data?['childrenAtHome'] as bool? ?? false;
          final hasPets = data?['otherPetsAtHome'] as bool? ?? false;
          final photoUrl =
              data?['profilePhoto'] as String? ?? user?.photoURL ?? '';
          final additionalImages =
              (data?['additionalImages'] as List?)?.cast<String>() ??
                  const <String>[];

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: const Text(
                    'Profile',
                    style: TextStyle(
                      color: Color(0xFF444444),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _ProfileHero(
                  data: data,
                  ownerId: user?.uid ?? '',
                  onLogout: widget.onLogout,
                  onProfileUpdated: _refreshProfile,
                  fullName: fullName,
                  bio: bio,
                  homeType: homeType,
                  locationName: locationName,
                  hasKids: hasKids,
                  hasPets: hasPets,
                  photoUrl: photoUrl,
                  additionalImages: additionalImages,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final Map<String, dynamic>? data;
  final String ownerId;
  final Future<void> Function() onLogout;
  final VoidCallback onProfileUpdated;
  final String fullName;
  final String bio;
  final String homeType;
  final String locationName;
  final bool hasKids;
  final bool hasPets;
  final String photoUrl;
  final List<String> additionalImages;

  const _ProfileHero({
    required this.data,
    required this.ownerId,
    required this.onLogout,
    required this.onProfileUpdated,
    required this.fullName,
    required this.bio,
    required this.homeType,
    required this.locationName,
    required this.hasKids,
    required this.hasPets,
    required this.photoUrl,
    required this.additionalImages,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundUrl = additionalImages.isNotEmpty ? additionalImages.first : '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 210,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                BreedrNetworkImage(
                  imageUrl: backgroundUrl,
                  fallback: const _ProfileCoverFallback(),
                ),
                Positioned(
                  right: 14,
                  top: 14,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: const CircleBorder(),
                    elevation: 4,
                    child: IconButton(
                      tooltip: 'Settings',
                      onPressed: () async {
                        final updated = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _SettingsScreen(
                              data: data,
                              onLogout: onLogout,
                            ),
                          ),
                        );
                        if (updated == true && context.mounted) {
                          onProfileUpdated();
                        }
                      },
                      icon: const Icon(
                        Icons.settings,
                        color: AppColors.primary,
                        size: 27,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -42),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileAvatar(photoUrl: photoUrl, size: 104),
                  const SizedBox(height: 8),
                  Text(
                    fullName,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 14, color: Color(0xFF555555)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          locationName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF555555),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _ProfileTag(homeType),
                      if (hasKids) const _ProfileTag('Has kids'),
                      if (hasPets) const _ProfileTag('Has pets'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const _DividerLine(),
                  const SizedBox(height: 14),
                  const _SectionTitle('ABOUT ME'),
                  const SizedBox(height: 10),
                  _AboutBox(text: bio),
                  const SizedBox(height: 22),
                  const _SectionTitle('HOME INFORMATION'),
                  const SizedBox(height: 10),
                  _InfoBox(
                    rows: [
                      _InfoRow('Home Type', homeType),
                      _InfoRow('Location', locationName),
                      _InfoRow('Pets at Home', hasPets ? 'YES' : 'NO'),
                      _InfoRow('Kids at Home', hasKids ? 'YES' : 'NO'),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const _DividerLine(),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const _SectionTitle('MORE PHOTOS OF YOU'),
                      const Spacer(),
                      Text(
                        additionalImages.isEmpty
                            ? '0 / 10'
                            : '1 / ${additionalImages.length}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _MoreUserPhotos(images: additionalImages),
                  const SizedBox(height: 22),
                  const _DividerLine(),
                  const SizedBox(height: 14),
                  const _SectionTitle('MY RATINGS & REVIEWS'),
                  const SizedBox(height: 10),
                  _OwnRatingsCard(
                    ownerId: ownerId,
                    ownerName: fullName,
                    ownerPhoto: photoUrl,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnRatingsCard extends StatelessWidget {
  final String ownerId;
  final String ownerName;
  final String ownerPhoto;

  const _OwnRatingsCard({
    required this.ownerId,
    required this.ownerName,
    required this.ownerPhoto,
  });

  @override
  Widget build(BuildContext context) {
    if (ownerId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: BreedingMatchService.instance
          .watchPublishedReviewsForUser(ownerId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _RatingsMessage(
            icon: Icons.cloud_off_outlined,
            title: 'Ratings are unavailable',
            message: 'Your reviews could not be loaded right now.',
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 112,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final reviews = snapshot.data!.docs;
        final breedingCount = reviews
            .where((review) => review.data()['purpose'] == 'breeding')
            .length;
        final adoptionCount = reviews
            .where((review) => review.data()['purpose'] == 'adoption')
            .length;
        final ratings = reviews
            .map((review) => review.data()['overall'])
            .whereType<num>()
            .map((rating) => rating.toDouble())
            .toList();

        if (ratings.isEmpty) {
          return InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _openOwnRatings(context),
            child: const _RatingsMessage(
              icon: Icons.rate_review_outlined,
              title: 'No reviews yet',
              message:
                  'Reviews from completed breeding and adoption transactions '
                  'will appear here.',
            ),
          );
        }

        final average =
            ratings.reduce((total, rating) => total + rating) / ratings.length;

        return InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => _openOwnRatings(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F5),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFFFB5C2)),
            ),
            child: Row(
              children: [
                Column(
                  children: [
                    Text(
                      average.toStringAsFixed(1),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        5,
                        (index) => Icon(
                          index < average.round()
                              ? Icons.star
                              : Icons.star_border,
                          size: 16,
                          color: const Color(0xFFFFC107),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${ratings.length} ${ratings.length == 1 ? 'review' : 'reviews'}',
                      style: const TextStyle(
                        color: Color(0xFF777777),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RatingCountRow(
                        label: 'Breeding',
                        count: breedingCount,
                      ),
                      const SizedBox(height: 8),
                      _RatingCountRow(
                        label: 'Adoption',
                        count: adoptionCount,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'View all reviews',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openOwnRatings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OwnerRatingsScreen(
          ownerId: ownerId,
          fallbackName: ownerName,
          fallbackPhoto: ownerPhoto,
        ),
      ),
    );
  }
}

class _RatingCountRow extends StatelessWidget {
  final String label;
  final int count;

  const _RatingCountRow({
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF555555),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          '$count',
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _RatingsMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _RatingsMessage({
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
        color: const Color(0xFFFFF7FA),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFFCDD6)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF444444),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF777777),
                    fontSize: 11,
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

class _SettingsScreen extends StatelessWidget {
  final Map<String, dynamic>? data;
  final Future<void> Function()? onLogout;

  const _SettingsScreen({
    this.data,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final user = UserSessionService.instance.currentUser;
    final fullName =
        data?['fullName'] as String? ?? user?.displayName ?? 'Breedr User';
    final userName = data?['userName'] as String? ?? '';
    final locationName =
        data?['locationName'] as String? ?? 'Location not set';
    final photoUrl =
        data?['profilePhoto'] as String? ?? user?.photoURL ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back,
                        color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'SETTINGS',
                    style: TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  _ProfileAvatar(photoUrl: photoUrl, size: 72),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            if (userName.isNotEmpty)
                              _MiniMeta(icon: Icons.alternate_email, text: userName),
                            _MiniMeta(
                                icon: Icons.location_on_outlined,
                                text: locationName),
                          ],
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final updated = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _EditProfileScreen(data: data),
                        ),
                      );
                      if (updated == true && context.mounted) {
                        Navigator.pop(context, true);
                      }
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit Profile'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF222222),
                      backgroundColor: const Color(0xFFFFDDE6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const _SettingsSectionLabel('PET OWNER ACTIONS'),
              _SettingsTile(
                icon: Icons.pets,
                label: 'My Pets',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const _MyPetsScreen()),
                ),
              ),
              _SettingsTile(
                icon: Icons.local_hospital,
                label: 'Health Vault',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HealthVaultScreen()),
                ),
              ),
              _SettingsTile(
                icon: Icons.location_on,
                label: 'Location',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LocationSettingsScreen(),
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.storefront,
                label: 'Breeding Status',
                onTap: () {},
              ),
              const SizedBox(height: 10),
              const _SettingsSectionLabel('NOTIFICATION'),
              _SettingSwitch(
                preferenceKey: 'breedingLikes',
                title: 'Breeding Likes',
                subtitle: 'When someone likes your pet',
                initialValue: _notificationPreference(
                  data,
                  'breedingLikes',
                ),
              ),
              _SettingSwitch(
                preferenceKey: 'adoptionRequests',
                title: 'Adoption Requests',
                subtitle: 'When an adopter answers your questions',
                initialValue: _notificationPreference(
                  data,
                  'adoptionRequests',
                ),
              ),
              _SettingSwitch(
                preferenceKey: 'newMessages',
                title: 'New Messages',
                subtitle: 'Chat notifications',
                initialValue: _notificationPreference(
                  data,
                  'newMessages',
                ),
              ),
              _SettingSwitch(
                preferenceKey: 'petHealth',
                title: 'Pet Health',
                subtitle: 'Vaccination & document renewals',
                initialValue: _notificationPreference(
                  data,
                  'petHealth',
                ),
              ),
              const SizedBox(height: 10),
              const _SettingsSectionLabel('PRIVACY'),
              _ActivityStatusSwitch(
                initialValue:
                    data?['showActivityStatus'] as bool? ?? true,
              ),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: onLogout == null ? null : () => onLogout!(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text(
                    'LOGOUT',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

bool _notificationPreference(
  Map<String, dynamic>? data,
  String key,
) {
  final preferences = Map<String, dynamic>.from(
    data?['notificationPreferences'] as Map? ?? const <String, dynamic>{},
  );
  return preferences[key] as bool? ?? true;
}

class _EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? data;

  const _EditProfileScreen({
    required this.data,
  });

  @override
  State<_EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<_EditProfileScreen> {
  static const int _maxAdditionalPhotos = 10;

  final _aboutController = TextEditingController();
  final _locationController = TextEditingController();
  final _picker = ImagePicker();
  final _cloudinary = CloudinaryService();

  final List<String> _homeTypes = const [
    'House with Yard',
    'Farm',
    'Apartment / Condo',
    'Townhouse',
    'House (No Yard)',
  ];

  String _homeType = 'House with Yard';
  bool _childrenAtHome = false;
  bool _otherPetsAtHome = false;
  bool _saving = false;
  bool _detectingLocation = false;

  String _profilePhotoUrl = '';
  double? _latitude;
  double? _longitude;
  File? _profilePhotoFile;
  late List<String> _additionalImageUrls;
  final List<File> _additionalImageFiles = [];

  int get _totalAdditionalPhotos =>
      _additionalImageUrls.length + _additionalImageFiles.length;

  @override
  void initState() {
    super.initState();
    final data = widget.data;

    _aboutController.text = data?['bio'] as String? ?? '';
    _locationController.text = data?['locationName'] as String? ?? '';
    _homeType = data?['homeType'] as String? ?? _homeTypes.first;
    if (!_homeTypes.contains(_homeType)) {
      _homeType = _homeTypes.first;
    }
    _childrenAtHome = data?['childrenAtHome'] as bool? ?? false;
    _otherPetsAtHome = data?['otherPetsAtHome'] as bool? ?? false;
    _latitude = (data?['latitude'] as num?)?.toDouble();
    _longitude = (data?['longitude'] as num?)?.toDouble();
    _profilePhotoUrl = data?['profilePhoto'] as String? ??
        UserSessionService.instance.currentUser?.photoURL ??
        '';
    _additionalImageUrls =
        (data?['additionalImages'] as List?)?.cast<String>() ?? [];
  }

  @override
  void dispose() {
    _aboutController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<ImageSource?> _chooseImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0D0D5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: const Icon(Icons.photo_library,
                      color: AppColors.primary),
                  title: const Text('Choose from gallery'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                ListTile(
                  leading:
                      const Icon(Icons.photo_camera, color: AppColors.primary),
                  title: const Text('Take a photo'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickProfilePhoto() async {
    final source = await _chooseImageSource();
    if (source == null) return;

    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 75,
    );

    if (picked == null || !mounted) return;

    setState(() => _profilePhotoFile = File(picked.path));
  }

  Future<void> _pickAdditionalPhoto() async {
    if (_totalAdditionalPhotos >= _maxAdditionalPhotos) {
      _showMessage('You can upload up to 10 additional photos.');
      return;
    }

    final source = await _chooseImageSource();
    if (source == null) return;

    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 75,
    );

    if (picked == null || !mounted) return;

    setState(() => _additionalImageFiles.add(File(picked.path)));
  }

  Future<void> _detectLocation() async {
    setState(() => _detectingLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        if (!mounted) return;
        _showMessage('Please enable GPS, then tap Detect again.');
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        _showMessage('Location permission is required to update this.');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        if (!mounted) return;
        _showMessage(
          'Please allow location permission in settings, then come back.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final place = placemarks.isNotEmpty ? placemarks.first : null;
      final locationName = [
        place?.subLocality,
        place?.locality,
      ].whereType<String>().where((part) => part.trim().isNotEmpty).join(', ');

      if (!mounted) return;

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationController.text = locationName.isNotEmpty
            ? locationName
            : '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      });

      _showMessage('Location detected.');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Unable to detect your location. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _detectingLocation = false);
      }
    }
  }

  Future<void> _saveChanges() async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) {
      _showMessage('Please sign in again before saving changes.');
      return;
    }

    setState(() => _saving = true);

    try {
      var profilePhotoUrl = _profilePhotoUrl;

      if (_profilePhotoFile != null) {
        final uploaded = await _cloudinary.uploadImage(_profilePhotoFile!);
        if (uploaded != null && uploaded.isNotEmpty) {
          profilePhotoUrl = uploaded;
        }
      }

      final additionalImageUrls = List<String>.from(_additionalImageUrls);

      for (final file in _additionalImageFiles) {
        final uploaded = await _cloudinary.uploadImage(file);
        if (uploaded != null && uploaded.isNotEmpty) {
          additionalImageUrls.add(uploaded);
        }
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'bio': _aboutController.text.trim(),
        'homeType': _homeType,
        'childrenAtHome': _childrenAtHome,
        'otherPetsAtHome': _otherPetsAtHome,
        'locationName': _locationController.text.trim(),
        'latitude': _latitude,
        'longitude': _longitude,
        'profilePhoto': profilePhotoUrl,
        'additionalImages': additionalImageUrls,
        'hasProfilePhoto': profilePhotoUrl.isNotEmpty,
        'profileCompleted': profilePhotoUrl.isNotEmpty &&
            _aboutController.text.trim().isNotEmpty &&
            _homeType.isNotEmpty &&
            _locationController.text.trim().isNotEmpty,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Unable to save profile changes. Please try again.');
      setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.pop(context, false),
                          icon: const Icon(Icons.arrow_back,
                              color: AppColors.primary, size: 28),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'EDIT PROFILE',
                          style: TextStyle(
                            color: Color(0xFF111111),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const _EditSectionHeader(
                      icon: Icons.image,
                      title: 'CHANGE PROFILE PHOTO',
                    ),
                    const SizedBox(height: 12),
                    _ProfilePhotoEditor(
                      photoUrl: _profilePhotoUrl,
                      photoFile: _profilePhotoFile,
                      onUpload: _pickProfilePhoto,
                      onTakePhoto: _pickProfilePhoto,
                    ),
                    const SizedBox(height: 8),
                    const _EditHint(
                      text:
                          'A profile photo helps pet owners recognize and trust you. Appears on your profile, chats, listings, and your profile page.',
                    ),
                    const SizedBox(height: 28),
                    const _EditSectionHeader(
                      icon: Icons.location_on,
                      title: 'YOUR LOCATION',
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _locationController,
                      readOnly: true,
                      decoration: _editInputDecoration(
                        prefixIcon: Icons.location_on_outlined,
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: TextButton.icon(
                            onPressed:
                                _detectingLocation ? null : _detectLocation,
                            icon: _detectingLocation
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.my_location, size: 14),
                            label: Text(
                              _detectingLocation ? 'Detecting' : 'Detect',
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              textStyle: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const _EditHint(
                      text:
                          'Only your city or municipality is shown to others. Your exact address is never shared.',
                    ),
                    const SizedBox(height: 28),
                    const _EditSectionHeader(
                      icon: Icons.home,
                      title: 'TYPE OF HOME',
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _homeTypes
                          .map(
                            (type) => ChoiceChip(
                              label: Text(type),
                              selected: _homeType == type,
                              selectedColor: const Color(0xFFFFCDD5),
                              backgroundColor: const Color(0xFFFFE4EB),
                              side: BorderSide(
                                color: _homeType == type
                                    ? AppColors.primary
                                    : Colors.transparent,
                              ),
                              labelStyle: TextStyle(
                                color: const Color(0xFF222222),
                                fontSize: 11,
                                fontWeight: _homeType == type
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                              onSelected: (_) =>
                                  setState(() => _homeType = type),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    const _EditHint(
                      text: 'Helps match you with pets suited to your living space.',
                    ),
                    const SizedBox(height: 28),
                    const _EditSectionHeader(
                      icon: Icons.home_work,
                      title: 'HOUSEHOLD',
                    ),
                    const SizedBox(height: 10),
                    _EditToggleRow(
                      title: 'Children at home',
                      subtitle: 'Helps match kid-friendly pets',
                      value: _childrenAtHome,
                      onChanged: (value) =>
                          setState(() => _childrenAtHome = value),
                    ),
                    _EditToggleRow(
                      title: 'Other pets at home',
                      subtitle: 'Helps match pet-friendly pets',
                      value: _otherPetsAtHome,
                      onChanged: (value) =>
                          setState(() => _otherPetsAtHome = value),
                    ),
                    const SizedBox(height: 24),
                    const _EditSectionHeader(
                      icon: Icons.article,
                      title: 'ABOUT ME',
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _aboutController,
                      minLines: 5,
                      maxLines: 7,
                      textInputAction: TextInputAction.newline,
                      decoration: _editInputDecoration(),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        const Expanded(
                          child: _EditSectionHeader(
                            icon: Icons.add_photo_alternate,
                            title: 'UPLOAD ADDITIONAL PHOTOS',
                          ),
                        ),
                        Text(
                          '$_totalAdditionalPhotos / $_maxAdditionalPhotos',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _AdditionalPhotoEditor(
                      existingUrls: _additionalImageUrls,
                      localFiles: _additionalImageFiles,
                      onAdd: _pickAdditionalPhoto,
                      onRemoveExisting: (index) {
                        setState(() => _additionalImageUrls.removeAt(index));
                      },
                      onRemoveLocal: (index) {
                        setState(() => _additionalImageFiles.removeAt(index));
                      },
                    ),
                    const SizedBox(height: 8),
                    const _EditHint(
                      text:
                          'You may add up to 10 additional photos of yourself, your home, or your pets. The first upload will be used as the background of your profile.',
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(28, 14, 28, 22),
              color: const Color(0xFFFFF0F5),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'SAVE CHANGES',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed:
                            _saving ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(
                              color: AppColors.primary, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text(
                          'DISCARD',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
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

  InputDecoration _editInputDecoration({
    IconData? prefixIcon,
    String? suffixText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      prefixIcon:
          prefixIcon == null ? null : Icon(prefixIcon, color: Colors.grey),
      suffixIcon: suffixIcon ??
          (suffixText == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    widthFactor: 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAEAEA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        suffixText,
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                )),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFFFB8C6)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFFFB8C6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}

class _EditSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _EditSectionHeader({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF555555)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF444444),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _EditHint extends StatelessWidget {
  final String text;

  const _EditHint({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE8EE),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline,
              size: 14, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF888888),
                fontSize: 10,
                height: 1.35,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePhotoEditor extends StatelessWidget {
  final String photoUrl;
  final File? photoFile;
  final VoidCallback onUpload;
  final VoidCallback onTakePhoto;

  const _ProfilePhotoEditor({
    required this.photoUrl,
    required this.photoFile,
    required this.onUpload,
    required this.onTakePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: AppColors.primary,
          width: 1.4,
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB6C4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _ProfilePhotoPreview(
                    photoUrl: photoUrl,
                    photoFile: photoFile,
                  ),
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF8FA1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo_camera,
                    color: Colors.white, size: 15),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 160,
            height: 32,
            child: ElevatedButton(
              onPressed: onUpload,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text(
                'UPLOAD A PHOTO',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 160,
            height: 32,
            child: OutlinedButton(
              onPressed: onTakePhoto,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text(
                'TAKE A PHOTO',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add in png & jpg format only - max 5 mb',
            style: TextStyle(
              color: Color(0xFF777777),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePhotoPreview extends StatelessWidget {
  final String photoUrl;
  final File? photoFile;

  const _ProfilePhotoPreview({
    required this.photoUrl,
    required this.photoFile,
  });

  @override
  Widget build(BuildContext context) {
    if (photoFile != null) {
      return Image.file(photoFile!, fit: BoxFit.cover);
    }

    return BreedrNetworkImage(
      imageUrl: photoUrl,
      fallback: const Icon(Icons.person, color: Colors.white, size: 48),
    );
  }
}

class _EditToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _EditToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: Colors.white,
            activeTrackColor: AppColors.primary,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFB6AEB3),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _AdditionalPhotoEditor extends StatelessWidget {
  final List<String> existingUrls;
  final List<File> localFiles;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemoveExisting;
  final ValueChanged<int> onRemoveLocal;

  const _AdditionalPhotoEditor({
    required this.existingUrls,
    required this.localFiles,
    required this.onAdd,
    required this.onRemoveExisting,
    required this.onRemoveLocal,
  });

  @override
  Widget build(BuildContext context) {
    final itemCount = existingUrls.length + localFiles.length + 1;

    return SizedBox(
      height: 250,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          if (index == itemCount - 1) {
            return _AddAdditionalPhotoCard(onTap: onAdd);
          }

          final isExisting = index < existingUrls.length;
          final localIndex = index - existingUrls.length;

          return _EditableAdditionalPhotoCard(
            imageUrl: isExisting ? existingUrls[index] : null,
            imageFile: isExisting ? null : localFiles[localIndex],
            onRemove: () {
              if (isExisting) {
                onRemoveExisting(index);
              } else {
                onRemoveLocal(localIndex);
              }
            },
          );
        },
      ),
    );
  }
}

class _EditableAdditionalPhotoCard extends StatelessWidget {
  final String? imageUrl;
  final File? imageFile;
  final VoidCallback onRemove;

  const _EditableAdditionalPhotoCard({
    required this.imageUrl,
    required this.imageFile,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: imageFile != null
                  ? Image.file(imageFile!, fit: BoxFit.cover)
                  : BreedrNetworkImage(
                      imageUrl: imageUrl ?? '',
                      fallback: const _ProfileCoverFallback(),
                    ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddAdditionalPhotoCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddAdditionalPhotoCard({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 170,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.primary, width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: AppColors.primary, size: 56),
            SizedBox(height: 10),
            Text(
              'Add photo',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyPetsScreen extends StatefulWidget {
  const _MyPetsScreen();

  @override
  State<_MyPetsScreen> createState() => _MyPetsScreenState();
}

class _MyPetsScreenState extends State<_MyPetsScreen> {
  String _filter = 'All';

  Query<Map<String, dynamic>> _query(String uid) {
    return FirebaseFirestore.instance
        .collection('pets')
        .where('ownerId', isEqualTo: uid);
  }

  @override
  Widget build(BuildContext context) {
    final uid = UserSessionService.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back,
                        color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'My Pets',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: ['All', 'Breeding', 'Adoption']
                    .map(
                      (filter) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: _filter == filter,
                          selectedColor: const Color(0xFFFFDDE6),
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: _filter == filter
                                ? const Color(0xFF222222)
                                : Colors.transparent,
                            width: 1.5,
                          ),
                          onSelected: (_) => setState(() => _filter = filter),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: uid == null
                    ? const Center(child: Text('Please log in first.'))
                    : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _query(uid).snapshots(),
                        builder: (context, snapshot) {
                          final docs = snapshot.data?.docs ?? [];
                          final pets = _filter == 'All'
                              ? docs
                              : docs.where((doc) {
                                  final purpose =
                                      doc.data()['purpose'] as String? ?? '';
                                  return purpose == _filter.toLowerCase();
                                }).toList();

                          return GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: 0.62,
                            ),
                            itemCount: pets.length + 1,
                            itemBuilder: (context, index) {
                              if (index == pets.length) {
                                return const _AddPetCard();
                              }

                              return _MyPetCard(
                                petId: pets[index].id,
                                data: pets[index].data(),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyPetCard extends StatelessWidget {
  final String petId;
  final Map<String, dynamic> data;

  const _MyPetCard({
    required this.petId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? 'Pet';
    final breed = data['breed'] as String? ?? '';
    final purpose = data['purpose'] as String? ?? '';
    final status = data['status'] as String? ?? purpose;
    final displayStatus = status == 'published' ? purpose : status;
    final photoUrl = (data['petProfilePhoto'] as String?) ??
        (data['profilePhoto'] as String?) ??
        '';

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _MyPetPreviewScreen(data: data),
        ),
      ),
      child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.primary, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.grey.shade700),
              onSelected: (value) => _confirmStatusChange(context, value),
              itemBuilder: (context) {
                if (status == 'matched' || status == 'adopted') {
                  return const [];
                }

                if (purpose == 'breeding') {
                  return const [
                    PopupMenuItem(
                      value: 'matched',
                      child: Text('Mark as matched'),
                    ),
                  ];
                }

                return const [
                  PopupMenuItem(
                    value: 'adopted',
                    child: Text('Mark as adopted'),
                  ),
                ];
              },
            ),
          ),
          const SizedBox(height: 2),
          _PetAvatar(photoUrl: photoUrl),
          const SizedBox(height: 6),
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
          Text(
            breed,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF222222),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _PurposePill(label: displayStatus),
        ],
      ),
      ),
    );
  }

  Future<void> _confirmStatusChange(BuildContext context, String status) async {
    final isMatched = status == 'matched';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isMatched
              ? 'Mark this pet as matched?'
              : 'Are you sure you want to mark this pet as adopted?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          isMatched
              ? 'It will no longer be available for breeding.'
              : 'This pet will be removed from listings and will no longer be available for adoption.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await FirebaseFirestore.instance.collection('pets').doc(petId).update({
      'status': status,
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

class _AddPetCard extends StatelessWidget {
  const _AddPetCard();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PetRegistrationScreen()),
      ),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.primary, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: AppColors.primary, size: 58),
            SizedBox(height: 18),
            Text(
              'Add new Pet',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyPetPreviewScreen extends StatelessWidget {
  final Map<String, dynamic> data;

  const _MyPetPreviewScreen({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? 'Pet';
    final species = data['species'] as String? ?? '';
    final breed = data['breed'] as String? ?? '';
    final age = data['age'] as String? ?? '';
    final gender = data['gender'] as String? ?? '';
    final color = data['color'] as String? ?? '';
    final size = data['breedSize'] as String? ?? '';
    final about = data['about'] as String? ?? '';
    final purpose = data['purpose'] as String? ?? '';
    final status = data['status'] as String? ?? purpose;
    final displayStatus = status == 'published' ? purpose : status;
    final location = data['locationName'] as String? ?? '';
    final photoUrl = (data['petProfilePhoto'] as String?) ??
        (data['profilePhoto'] as String?) ??
        '';
    final images = (data['additionalImages'] as List?)?.cast<String>() ??
        const <String>[];
    final records = (data['healthRecords'] as List?) ?? const [];
    final adoption = data['adoptionDetails'] as Map<String, dynamic>?;
    final price = adoption?['price'];

    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: AppColors.primary),
              ),
              const SizedBox(height: 10),
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: SizedBox(
                      height: purpose == 'adoption' ? 250 : 420,
                      width: double.infinity,
                      child: BreedrNetworkImage(
                        imageUrl: photoUrl,
                        fallback: const _PetProfileFallbackBlock(),
                      ),
                    ),
                  ),
                  if (purpose == 'adoption' && price != null)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: _PreviewBadge('PHP ${price.toString()}'),
                    ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '$breed | $age',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          location,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _PreviewBadge(displayStatus),
                            if (color.isNotEmpty) _PreviewBadge(color),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _PreviewGrid(rows: {
                'Species': species,
                'Breed': breed,
                'Age': age,
                'Gender': gender,
                'Color': color,
                'Size': size,
              }),
              const SizedBox(height: 20),
              _PreviewSectionTitle('ABOUT ${name.toUpperCase()}'),
              const SizedBox(height: 10),
              _PreviewBubble(text: about),
              const SizedBox(height: 20),
              _PreviewSectionTitle('${name.toUpperCase()} PET HEALTH RECORD'),
              const SizedBox(height: 10),
              if (records.isEmpty)
                const Text('No health records added yet.')
              else
                ...records.map((record) {
                  final map = record as Map<String, dynamic>;
                  return _PreviewHealthRow(record: map);
                }),
              if (images.isNotEmpty) ...[
                const SizedBox(height: 20),
                _PreviewSectionTitle('MORE PHOTOS OF ${name.toUpperCase()}'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 230,
                  child: PageView.builder(
                    controller: PageController(viewportFraction: 0.65),
                    itemCount: images.length,
                    itemBuilder: (_, index) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: BreedrNetworkImage(imageUrl: images[index]),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PetProfileFallbackBlock extends StatelessWidget {
  const _PetProfileFallbackBlock();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFCDD5),
      child: const Center(
        child: Icon(Icons.pets, size: 72, color: AppColors.primary),
      ),
    );
  }
}

class _PreviewBadge extends StatelessWidget {
  final String text;
  const _PreviewBadge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PreviewSectionTitle extends StatelessWidget {
  final String text;
  const _PreviewSectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF555555),
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _PreviewGrid extends StatelessWidget {
  final Map<String, String> rows;
  const _PreviewGrid({required this.rows});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 3.2,
      children: rows.entries
          .map(
            (entry) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.key,
                    style: const TextStyle(
                        color: Color(0xFF888888), fontSize: 11)),
                Text(entry.value,
                    style: const TextStyle(
                        color: Color(0xFF111111),
                        fontWeight: FontWeight.w700)),
              ],
            ),
          )
          .toList(),
    );
  }
}

class _PreviewBubble extends StatelessWidget {
  final String text;
  const _PreviewBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: const Color(0xFF3D8BFF), width: 2),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PreviewHealthRow extends StatelessWidget {
  final Map<String, dynamic> record;
  const _PreviewHealthRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final type = record['type'] as String? ?? 'Record';
    final file = record['fileName'] as String? ?? '';
    final fileUrl = record['fileUrl'] as String? ?? '';
    final dateIssued = record['dateIssued'] as String? ?? '';
    final clinic = record['clinic'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF3D8BFF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.description_outlined,
              color: Color(0xFF3D8BFF)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(file,
                    style: const TextStyle(
                        color: Color(0xFF888888), fontSize: 11)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showRecordPreview(
              context,
              type: type,
              fileName: file,
              fileUrl: fileUrl,
              dateIssued: dateIssued,
              clinic: clinic,
            ),
            child: const _PreviewBadge('VIEW'),
          ),
        ],
      ),
    );
  }

  void _showRecordPreview(
    BuildContext context, {
    required String type,
    required String fileName,
    required String fileUrl,
    required String dateIssued,
    required String clinic,
  }) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      type,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(fileName,
                  style: const TextStyle(color: Color(0xFF666666))),
              if (dateIssued.isNotEmpty)
                Text('Issued: $dateIssued',
                    style: const TextStyle(color: Color(0xFF666666))),
              if (clinic.isNotEmpty)
                Text('Clinic: $clinic',
                    style: const TextStyle(color: Color(0xFF666666))),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BreedrNetworkImage(
                  imageUrl: fileUrl,
                  fit: BoxFit.cover,
                  fallback: const _HealthPreviewFallback(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthPreviewFallback extends StatelessWidget {
  const _HealthPreviewFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      color: const Color(0xFFEAF3FF),
      child: const Center(
        child: Icon(
          Icons.description_outlined,
          size: 54,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _ProfileFallbackIcon extends StatelessWidget {
  const _ProfileFallbackIcon();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.person,
      color: AppColors.primary,
      size: 56,
    );
  }
}

class _ProfileCoverFallback extends StatelessWidget {
  const _ProfileCoverFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFDDE6),
      child: const Center(
        child: Icon(Icons.pets, color: AppColors.primary, size: 64),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String photoUrl;
  final double size;

  const _ProfileAvatar({
    required this.photoUrl,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFFCDD5),
        border: Border.all(color: AppColors.primary, width: 3),
      ),
      child: ClipOval(
        child: BreedrNetworkImage(
          imageUrl: photoUrl,
          width: size,
          height: size,
          fallback: const _ProfileFallbackIcon(),
        ),
      ),
    );
  }
}

class _PetAvatar extends StatelessWidget {
  final String photoUrl;

  const _PetAvatar({
    required this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFFCDD5),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: ClipOval(
        child: BreedrNetworkImage(
          imageUrl: photoUrl,
          width: 72,
          height: 72,
          fallback: const _PetFallbackIcon(),
        ),
      ),
    );
  }
}

class _PetFallbackIcon extends StatelessWidget {
  const _PetFallbackIcon();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.pets, color: AppColors.primary, size: 34);
  }
}

class _ProfileTag extends StatelessWidget {
  final String label;

  const _ProfileTag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF4A4A4A)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF333333),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DividerLine extends StatelessWidget {
  const _DividerLine();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: const Color(0xFFD9D0D3));
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
        color: Color(0xFF444444),
        fontSize: 12,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _AboutBox extends StatelessWidget {
  final String text;

  const _AboutBox({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(42, 22, 28, 22),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6F8),
        border: Border.all(color: const Color(0xFF777777)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF111111),
          fontSize: 13,
          fontWeight: FontWeight.w700,
          fontStyle: FontStyle.italic,
          height: 1.6,
        ),
      ),
    );
  }
}

class _InfoRow {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);
}

class _InfoBox extends StatelessWidget {
  final List<_InfoRow> rows;

  const _InfoBox({
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6F8),
        border: Border.all(color: const Color(0xFF777777)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: rows
            .map(
              (row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.label,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF222222),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.value,
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF111111),
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _MoreUserPhotos extends StatelessWidget {
  final List<String> images;

  const _MoreUserPhotos({
    required this.images,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return const SizedBox(
        height: 140,
        child: Center(
          child: Text(
            'No extra photos yet.',
            style: TextStyle(color: Color(0xFF777777)),
          ),
        ),
      );
    }

    return SizedBox(
      height: 210,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.62),
        itemCount: images.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BreedrNetworkImage(
                imageUrl: images[index],
                fallback: const _ProfileCoverFallback(),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MiniMeta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniMeta({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF888888)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF777777),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _SettingsSectionLabel extends StatelessWidget {
  final String label;

  const _SettingsSectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF888888),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.primary),
      onTap: onTap,
    );
  }
}

class _SettingSwitch extends StatefulWidget {
  final String preferenceKey;
  final String title;
  final String subtitle;
  final bool initialValue;

  const _SettingSwitch({
    required this.preferenceKey,
    required this.title,
    required this.subtitle,
    required this.initialValue,
  });

  @override
  State<_SettingSwitch> createState() => _SettingSwitchState();
}

class _SettingSwitchState extends State<_SettingSwitch> {
  late bool _value;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  Future<void> _update(bool next) async {
    if (_saving) return;

    final user = UserSessionService.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in again.')),
      );
      return;
    }

    setState(() {
      _value = next;
      _saving = true;
    });

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'notificationPreferences': {
            widget.preferenceKey: next,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (error) {
      debugPrint('Notification preference update failed: $error');
      if (!mounted) return;
      setState(() => _value = !next);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update notification settings.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      activeThumbColor: Colors.white,
      activeTrackColor: AppColors.primary,
      title: Text(
        widget.title,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(
        widget.subtitle,
        style: const TextStyle(
          color: Color(0xFF777777),
          fontSize: 9,
          fontStyle: FontStyle.italic,
        ),
      ),
      value: _value,
      onChanged: _saving ? null : _update,
    );
  }
}

class _ActivityStatusSwitch extends StatefulWidget {
  final bool initialValue;

  const _ActivityStatusSwitch({
    required this.initialValue,
  });

  @override
  State<_ActivityStatusSwitch> createState() =>
      _ActivityStatusSwitchState();
}

class _ActivityStatusSwitchState extends State<_ActivityStatusSwitch> {
  late bool _value;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  Future<void> _update(bool next) async {
    if (_saving) return;
    setState(() {
      _value = next;
      _saving = true;
    });

    try {
      await PresenceService.instance.updateActivityVisibility(next);
    } catch (error) {
      if (!mounted) return;
      setState(() => _value = !next);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update activity status.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      activeThumbColor: Colors.white,
      activeTrackColor: AppColors.primary,
      title: const Text(
        'Show Activity Status',
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: const Text(
        'When disabled, you will not see other owners activity status either.',
        style: TextStyle(
          color: Color(0xFF777777),
          fontSize: 9,
          fontStyle: FontStyle.italic,
        ),
      ),
      value: _value,
      onChanged: _saving ? null : _update,
    );
  }
}

class _PurposePill extends StatelessWidget {
  final String label;

  const _PurposePill({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final text = label.isEmpty
        ? 'Pet'
        : label[0].toUpperCase() + label.substring(1).toLowerCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFDDE6),
        border: Border.all(color: const Color(0xFF222222)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF222222),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
