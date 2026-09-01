import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/user_session_service.dart';
import '../../services/cabuyao_barangay_service.dart';
import '../../theme/app_colors.dart';

class LocationSettingsScreen extends StatefulWidget {
  const LocationSettingsScreen({super.key});

  @override
  State<LocationSettingsScreen> createState() => _LocationSettingsScreenState();
}

class _LocationSettingsScreenState extends State<LocationSettingsScreen> {
  final _firestore = FirebaseFirestore.instance;
  bool _detecting = false;

  Future<void> _openSearch({
    required _LocationTarget target,
    String? petId,
    String? currentLocation,
  }) async {
    final selected = await Navigator.push<_BarangayLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => SearchLocationScreen(currentLocation: currentLocation),
      ),
    );

    if (selected == null || !mounted) return;

    await _saveLocation(selected, target: target, petId: petId);
  }

  Future<void> _detectLocation() async {
    setState(() => _detecting = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        _showMessage('Please enable GPS, then tap Detect again.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showMessage('Location permission is required to update this.');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
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
      var locationName = await CabuyaoBarangayService.fromCoordinates(
        position.latitude,
        position.longitude,
      );
      locationName ??= CabuyaoBarangayService.fromPlacemark(place);
      if (locationName == null) {
        _showMessage('Breedr is available in Cabuyao only.');
        return;
      }

      final detected = _BarangayLocation(
        name: locationName,
        city: '',
        latitude: position.latitude,
        longitude: position.longitude,
        distanceText: 'current position',
        assetColor: const Color(0xFFB992E8),
      );

      await _saveLocation(detected, target: _LocationTarget.user);
      _showMessage('Location updated.');
    } catch (_) {
      _showMessage('Unable to detect your location. Please try again.');
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  Future<void> _saveLocation(
    _BarangayLocation location, {
    required _LocationTarget target,
    String? petId,
  }) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) {
      _showMessage('Please sign in again before updating your location.');
      return;
    }

    var latitude = location.latitude;
    var longitude = location.longitude;
    if (latitude == 0 && longitude == 0) {
      final coordinates =
          await CabuyaoBarangayService.representativeCoordinatesFor(
            location.displayName,
          );
      latitude = coordinates?.$1 ?? latitude;
      longitude = coordinates?.$2 ?? longitude;
    }
    final canonical = CabuyaoBarangayService.canonicalName(
      location.displayName,
    );
    final locationName = canonical == null
        ? location.displayName
        : CabuyaoBarangayService.format(canonical);
    final payload = {
      'locationName': locationName,
      'barangay': canonical ?? location.name,
      'city': 'Cabuyao Laguna',
      'latitude': latitude,
      'longitude': longitude,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (target == _LocationTarget.user) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(payload, SetOptions(merge: true));
      } else if (target == _LocationTarget.allPets) {
        final pets = await _firestore
            .collection('pets')
            .where('ownerId', isEqualTo: user.uid)
            .get();
        final batch = _firestore.batch();
        for (final pet in pets.docs) {
          batch.set(pet.reference, payload, SetOptions(merge: true));
        }
        await batch.commit();
      } else if (target == _LocationTarget.pet && petId != null) {
        await _firestore
            .collection('pets')
            .doc(petId)
            .set(payload, SetOptions(merge: true));
      }

      if (!mounted) return;
      _showMessage('Location saved.');
    } on FirebaseException catch (error) {
      final message = error.code == 'permission-denied'
          ? 'Unable to update this location because permission is missing.'
          : 'Unable to save location. Please try again.';
      _showMessage(message);
    } catch (_) {
      _showMessage('Unable to save location. Please try again.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = UserSessionService.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please sign in again.')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FB),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _firestore.collection('users').doc(user.uid).snapshots(),
          builder: (context, userSnapshot) {
            final userData = userSnapshot.data?.data() ?? {};
            final locationName =
                userData['locationName'] as String? ?? 'Location not set';
            final latitude = (userData['latitude'] as num?)?.toDouble();
            final longitude = (userData['longitude'] as num?)?.toDouble();

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore
                  .collection('pets')
                  .where('ownerId', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, petsSnapshot) {
                final pets = petsSnapshot.data?.docs ?? [];

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(
                                    Icons.arrow_back,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Location Setting',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            const _SectionTitle(
                              icon: Icons.location_on,
                              title: 'Your Location',
                            ),
                            const SizedBox(height: 12),
                            _LocationMapCard(
                              locationName: locationName,
                              latitude: latitude,
                              longitude: longitude,
                            ),
                            const SizedBox(height: 28),
                            const _SmallLabel('UPDATE LOCATION'),
                            const SizedBox(height: 4),
                            _ActionRow(
                              title: _detecting
                                  ? 'Finding your location...'
                                  : 'Detect current location',
                              subtitle:
                                  'Use GPS to update your current position',
                              trailing: _detecting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.my_location,
                                      color: AppColors.primary,
                                    ),
                              onTap: _detecting ? null : _detectLocation,
                            ),
                            const SizedBox(height: 28),
                            const _SectionTitle(
                              icon: Icons.location_on,
                              title: 'My Pets Location',
                            ),
                            const SizedBox(height: 12),
                            _PetsLocationCard(
                              pets: pets,
                              onApplyAll: pets.isEmpty
                                  ? null
                                  : () => _openSearch(
                                      target: _LocationTarget.allPets,
                                      currentLocation: locationName,
                                    ),
                              onPetTap: (pet) => _openSearch(
                                target: _LocationTarget.pet,
                                petId: pet.id,
                                currentLocation:
                                    pet.data()['locationName'] as String?,
                              ),
                            ),
                            const SizedBox(height: 120),
                            const _PrivacyNote(),
                          ],
                        ),
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

class SearchLocationScreen extends StatefulWidget {
  final String? currentLocation;

  const SearchLocationScreen({super.key, this.currentLocation});

  @override
  State<SearchLocationScreen> createState() => _SearchLocationScreenState();
}

class _SearchLocationScreenState extends State<SearchLocationScreen> {
  final _controller = TextEditingController();
  String _query = '';
  _BarangayLocation? _selected;

  List<_BarangayLocation> get _filtered {
    if (_query.trim().isEmpty) return _cabuyaoBarangays;
    final needle = _query.trim().toLowerCase();
    return _cabuyaoBarangays
        .where(
          (location) =>
              location.name.toLowerCase().contains(needle) ||
              location.city.toLowerCase().contains(needle),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _selected =
        _cabuyaoBarangays
            .where((location) => location.displayName == widget.currentLocation)
            .isNotEmpty
        ? _cabuyaoBarangays.firstWhere(
            (location) => location.displayName == widget.currentLocation,
          )
        : null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 18, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Search Location',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Barangay',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: Color(0xFF777777)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _query.isEmpty
                    ? 'Showing result for "barangay" across all barangay'
                    : 'Showing result for "$_query" across all barangay',
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF999999),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE8EF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary, width: 1),
                  ),
                  child: _filtered.isEmpty
                      ? const _EmptyLocationSearch()
                      : ListView.separated(
                          itemCount: _filtered.length,
                          separatorBuilder: (_, _) => const Divider(
                            height: 1,
                            color: Color(0xFFFFCAD5),
                          ),
                          itemBuilder: (context, index) {
                            final location = _filtered[index];
                            final isSelected = selected?.name == location.name;
                            return _BarangayTile(
                              location: location,
                              selected: isSelected,
                              current:
                                  location.displayName ==
                                  widget.currentLocation,
                              onTap: () => setState(() {
                                _selected = location;
                              }),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: selected == null
                      ? null
                      : () => Navigator.pop(context, selected),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: const Color(0xFFFFB9C3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'SET THIS AS LOCATION',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationMapCard extends StatelessWidget {
  final String locationName;
  final double? latitude;
  final double? longitude;

  const _LocationMapCard({
    required this.locationName,
    required this.latitude,
    required this.longitude,
  });

  @override
  Widget build(BuildContext context) {
    final display = locationName.trim().isEmpty
        ? 'Location not set'
        : locationName;
    final parts = display.split(',').map((part) => part.trim()).toList();
    final title = parts.isNotEmpty ? parts.first : display;
    final subtitle = parts.length > 1
        ? parts.skip(1).join(', ')
        : 'Cabuyao, Laguna';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: SizedBox(
              height: 126,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset('assets/images/Location.png', fit: BoxFit.cover),
                  Container(color: Colors.white.withValues(alpha: 0.52)),
                  const Center(
                    child: Icon(
                      Icons.location_on,
                      color: AppColors.primary,
                      size: 72,
                    ),
                  ),
                  const Positioned(
                    left: 12,
                    bottom: 8,
                    child: Text(
                      'Google',
                      style: TextStyle(
                        color: Color(0xFF4285F4),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF6E6372),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF777777),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  latitude == null || longitude == null
                      ? 'Coordinates not set'
                      : '${latitude!.toStringAsFixed(4)} N, ${longitude!.toStringAsFixed(4)} E',
                  style: const TextStyle(
                    color: Color(0xFF777777),
                    fontSize: 13,
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

class _PetsLocationCard extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> pets;
  final VoidCallback? onApplyAll;
  final ValueChanged<QueryDocumentSnapshot<Map<String, dynamic>>> onPetTap;

  const _PetsLocationCard({
    required this.pets,
    required this.onApplyAll,
    required this.onPetTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Per-pet location',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Tap a pet to change its location',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF999999),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onApplyAll,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    backgroundColor: const Color(0xFFFFDDE6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    pets.isEmpty ? '0 pets' : '${pets.length} pets',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (pets.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 18, 18, 24),
              child: Text(
                'No pets yet. Pets you register will appear here.',
                style: TextStyle(color: Color(0xFF777777)),
              ),
            )
          else
            ...pets.map((pet) {
              final data = pet.data();
              final name = data['name'] as String? ?? 'Pet';
              final breed = data['breed'] as String? ?? '';
              final photo =
                  data['petProfilePhoto'] as String? ??
                  data['profilePhoto'] as String? ??
                  '';
              final location =
                  data['locationName'] as String? ?? 'Location not set';
              return _PetLocationRow(
                name: name,
                breed: breed,
                location: location,
                photoUrl: photo,
                species: data['species'] as String? ?? '',
                onTap: () => onPetTap(pet),
              );
            }),
        ],
      ),
    );
  }
}

class _PetLocationRow extends StatelessWidget {
  final String name;
  final String breed;
  final String location;
  final String photoUrl;
  final String species;
  final VoidCallback onTap;

  const _PetLocationRow({
    required this.name,
    required this.breed,
    required this.location,
    required this.photoUrl,
    required this.species,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            _PetAvatar(photoUrl: photoUrl, species: species),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                      children: [
                        if (breed.isNotEmpty)
                          TextSpan(
                            text: '  •  $breed',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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
}

class _BarangayTile extends StatelessWidget {
  final _BarangayLocation location;
  final bool selected;
  final bool current;
  final VoidCallback onTap;

  const _BarangayTile({
    required this.location,
    required this.selected,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? const Color(0xFFFFDDE6) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: location.assetColor.withValues(alpha: 0.28),
              child: Icon(Icons.location_city, color: location.assetColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          location.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (current)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4EA3FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Current',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    location.city,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF777777),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 11,
                        color: Color(0xFF777777),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        location.distanceText,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF777777),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _PetAvatar extends StatelessWidget {
  final String photoUrl;
  final String species;

  const _PetAvatar({required this.photoUrl, required this.species});

  @override
  Widget build(BuildContext context) {
    final icon = species.toLowerCase() == 'cat'
        ? Icons.cruelty_free
        : Icons.pets;

    return CircleAvatar(
      radius: 25,
      backgroundColor: const Color(0xFFFFCAD5),
      child: CircleAvatar(
        radius: 22,
        backgroundColor: const Color(0xFFFFF0F4),
        backgroundImage: photoUrl.isEmpty ? null : NetworkImage(photoUrl),
        child: photoUrl.isEmpty
            ? Icon(icon, color: AppColors.primary, size: 24)
            : null,
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _ActionRow({
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF888888),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                const Icon(Icons.chevron_right, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF111111),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SmallLabel extends StatelessWidget {
  final String text;

  const _SmallLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF888888),
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEF3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, color: Color(0xFF999999), size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Only your municipality is shown to other users. Your exact coordinates and full address are never shared publicly.',
              style: TextStyle(
                color: Color(0xFF888888),
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLocationSearch extends StatelessWidget {
  const _EmptyLocationSearch();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No barangay found. Try a different search.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF777777)),
        ),
      ),
    );
  }
}

class _BarangayLocation {
  final String name;
  final String city;
  final double latitude;
  final double longitude;
  final String distanceText;
  final Color assetColor;

  const _BarangayLocation({
    required this.name,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.distanceText,
    required this.assetColor,
  });

  String get displayName => city.trim().isEmpty ? name : '$name, $city';
}

enum _LocationTarget { user, allPets, pet }

final _cabuyaoBarangays = CabuyaoBarangayService.barangays
    .map(
      (barangay) => _BarangayLocation(
        name: CabuyaoBarangayService.format(barangay),
        city: '',
        latitude: 0,
        longitude: 0,
        distanceText: 'Cabuyao Laguna',
        assetColor: const Color(0xFFB992E8),
      ),
    )
    .toList(growable: false);
