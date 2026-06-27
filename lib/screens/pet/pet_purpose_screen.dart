import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../models/pet_listing_data.dart';
import 'adoption_interview_screen.dart';
import 'pet_health_record_screen.dart';

class PetPurposeScreen extends StatefulWidget {
  final PetListingData petData;

  const PetPurposeScreen({
    super.key,
    required this.petData,
  });

  @override
  State<PetPurposeScreen> createState() => _PetPurposeScreenState();
}

class _PetPurposeScreenState extends State<PetPurposeScreen> {
  String? _selected; // 'Breeding' or 'Adoption'

  // Breeding prefs
  String _breedingGender = 'Male';
  bool _sameBreedOnly = true;
  bool _vetVerifiedOnly = true;

  // Adoption prefs
  String _adoptionType = 'FREE';
  bool _noOtherPets = true;
  bool _priceNegotiable = true;
  final _priceCtrl = TextEditingController(text: '0.0');

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  PetListingData _updatedPetData() {
    final parsedPrice =
        double.tryParse(_priceCtrl.text.trim().replaceAll(',', '')) ?? 0;

    return widget.petData.copyWith(
      purpose: _selected,
      breedingPreferredGender: _breedingGender,
      sameBreedOnly: _sameBreedOnly,
      vetVerifiedOnly: _vetVerifiedOnly,
      adoptionType: _adoptionType,
      price: _adoptionType == 'FOR SALE' ? parsedPrice : 0,
      noOtherPets: _noOtherPets,
      priceNegotiable: _priceNegotiable,
    );
  }

  void _goNext() {
    if (_selected == null) return;

    final eligibility = _checkEligibility();

    if (eligibility != null) {
      _showEligibilityDialog(eligibility);
      return;
    }

    final updatedData = _updatedPetData();
    final nextScreen = _selected == 'Breeding'
        ? PetHealthRecordScreen(petData: updatedData)
        : AdoptionInterviewScreen(petData: updatedData);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => nextScreen),
    );
  }

  _PurposeEligibilityResult? _checkEligibility() {
    final age = _PetAge.fromText(widget.petData.age);

    if (age == null) return null;

    if (_selected == 'Adoption' && age.totalWeeks < 8) {
      final eligibleDate = DateTime.now().add(
        Duration(days: (8 - age.totalWeeks) * 7),
      );

      return _PurposeEligibilityResult(
        title: 'Too Young for Adoption',
        message:
            '${widget.petData.name} is currently ${widget.petData.age}. Pets must be at least 8 weeks old before they can be adopted.',
        currentAge: widget.petData.age,
        eligibleOn: _formatMonthYear(eligibleDate),
        icon: Icons.calendar_month,
      );
    }

    if (_selected == 'Breeding') {
      if (age.totalMonths >= 108) {
        return _PurposeEligibilityResult(
          title: 'Too Old for Breeding',
          message:
              '${widget.petData.name} is currently ${widget.petData.age}. Breedr recommends that pets are bred within appropriate age limits because fertility and overall health may decline with age.',
          currentAge: widget.petData.age,
          gender: widget.petData.gender,
          breedSize: widget.petData.breedSize,
          icon: Icons.calendar_month,
        );
      }

      final minMonths = _minimumBreedingMonths();

      if (age.totalMonths < minMonths) {
        final remainingMonths = minMonths - age.totalMonths;
        final eligibleDate = DateTime(
          DateTime.now().year,
          DateTime.now().month + remainingMonths,
        );

        return _PurposeEligibilityResult(
          title: 'Too Young for Breeding',
          message:
              '${widget.petData.name} is currently ${widget.petData.age}. To protect your pet\'s health and promote responsible breeding, ${widget.petData.gender.toLowerCase()} pets must be at least $minMonths months old before being listed.',
          currentAge: widget.petData.age,
          gender: widget.petData.gender,
          breedSize: widget.petData.breedSize,
          eligibleOn: _formatMonthYear(eligibleDate),
          icon: Icons.calendar_month,
        );
      }
    }

    return null;
  }

  int _minimumBreedingMonths() {
    final gender = widget.petData.gender.toLowerCase();
    final size = widget.petData.breedSize.toLowerCase();

    if (gender == 'female') return 18;
    if (size == 'large') return 18;

    return 12;
  }

  String _formatMonthYear(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[date.month - 1]} ${date.year}';
  }

  Future<void> _showEligibilityDialog(
    _PurposeEligibilityResult result,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) => _PurposeEligibilityDialog(result: result),
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
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios,
                            color: AppColors.primary, size: 20),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PetStepBar(currentStep: 2),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text('Step 2 of 5',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(height: 20),
                    // Title
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 4,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('What is ${widget.petData.name} for?',
                                    style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary)),
                                const SizedBox(height: 6),
                                Text(
                                  'Select what ${widget.petData.name} is available for. You can only pick one.',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF666666),
                                      height: 1.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Validation note
                    if (_selected == null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE8EA),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(children: [
                          Icon(Icons.info_outline,
                              size: 14, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text('Select atleast one option above to continue.',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFF888888))),
                        ]),
                      ),
                    const SizedBox(height: 16),
                    // Breeding card
                    _PurposeCard(
                      title: 'Breeding',
                      description:
                          '${widget.petData.name} will appear in Breeding Discover for others to swipe.',
                      isSelected: _selected == 'Breeding',
                      onTap: () =>
                          setState(() => _selected = 'Breeding'),
                      expandedContent: _selected == 'Breeding'
                          ? _BreedingPrefs(
                            gender: _breedingGender,
                              petName: widget.petData.name,
                              sameBreedOnly: _sameBreedOnly,
                              vetVerifiedOnly: _vetVerifiedOnly,
                              onGenderChanged: (v) =>
                                  setState(() => _breedingGender = v),
                              onSameBreedChanged: (v) =>
                                  setState(() => _sameBreedOnly = v),
                              onVetVerifiedChanged: (v) =>
                                  setState(() => _vetVerifiedOnly = v),
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    // Adoption card
                    _PurposeCard(
                      title: 'Adoption',
                      description:
                          '${widget.petData.name} will appear in Adoption Listings for others to browse.',
                      isSelected: _selected == 'Adoption',
                      onTap: () =>
                          setState(() => _selected = 'Adoption'),
                      expandedContent: _selected == 'Adoption'
                          ? _AdoptionPrefs(
                              adoptionType: _adoptionType,
                              petName: widget.petData.name,
                              noOtherPets: _noOtherPets,
                              priceNegotiable: _priceNegotiable,
                              priceCtrl: _priceCtrl,
                              onTypeChanged: (v) =>
                                  setState(() => _adoptionType = v),
                              onNoOtherPetsChanged: (v) =>
                                  setState(() => _noOtherPets = v),
                              onNegotiableChanged: (v) =>
                                  setState(() => _priceNegotiable = v),
                            )
                          : null,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _selected != null ? _goNext : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.4),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Continue to next step →',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Purpose Card ──────────────────────────────────────────────────

class _PurposeCard extends StatelessWidget {
  final String title;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget? expandedContent;

  const _PurposeCard({
    required this.title,
    required this.description,
    required this.isSelected,
    required this.onTap,
    this.expandedContent,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFF0F5)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : const Color(0xFFDDDDDD),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Checkbox
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : const Color(0xFF888888),
                        width: 1.5,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check,
                            color: Colors.white, size: 16)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? AppColors.primary
                                    : const Color(0xFF222222))),
                        const SizedBox(height: 4),
                        Text(description,
                            style: TextStyle(
                                fontSize: 13,
                                color: isSelected
                                    ? AppColors.primary
                                    : const Color(0xFF666666),
                                height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (expandedContent != null) ...[
              const Divider(height: 1, color: Color(0xFFFFCDD5)),
              Padding(
                padding: const EdgeInsets.all(16),
                child: expandedContent!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Breeding Preferences ──────────────────────────────────────────

class _BreedingPrefs extends StatelessWidget {
  final String gender;
  final String petName;
  final bool sameBreedOnly;
  final bool vetVerifiedOnly;
  final ValueChanged<String> onGenderChanged;
  final ValueChanged<bool> onSameBreedChanged;
  final ValueChanged<bool> onVetVerifiedChanged;

  const _BreedingPrefs({
    required this.gender,
    required this.petName,
    required this.sameBreedOnly,
    required this.vetVerifiedOnly,
    required this.onGenderChanged,
    required this.onSameBreedChanged,
    required this.onVetVerifiedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Breeding Preferences',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF222222))),
        const SizedBox(height: 4),
        const Text('Looking for a partner that is',
            style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
        const SizedBox(height: 12),
        // Gender chips
        Wrap(spacing: 8, children: [
          _GenderChip(
              label: 'Male',
              icon: Icons.male,
              selected: gender == 'Male',
              onTap: () => onGenderChanged('Male')),
          _GenderChip(
              label: 'Female',
              icon: Icons.female,
              selected: gender == 'Female',
              onTap: () => onGenderChanged('Female')),
          _GenderChip(
              label: 'Any Gender',
              icon: Icons.transgender,
              selected: gender == 'Any Gender',
              onTap: () => onGenderChanged('Any Gender')),
        ]),
        const SizedBox(height: 16),
        _ToggleRow(
          title: 'Same breed only',
          subtitle: 'Only match with the same-breed as $petName',
          value: sameBreedOnly,
          onChanged: onSameBreedChanged,
        ),
        _ToggleRow(
          title: 'Vet - Verified partners only',
          subtitle: 'Only show vet verified pet',
          value: vetVerifiedOnly,
          onChanged: onVetVerifiedChanged,
        ),
        const SizedBox(height: 8),
        _InfoNote(
            'These preferences set your default filter when you open the Breeding tab. You can always change them in the filter settings.'),
      ],
    );
  }
}

// ── Adoption Preferences ──────────────────────────────────────────

class _AdoptionPrefs extends StatelessWidget {
  final String adoptionType;
  final String petName;
  final bool noOtherPets;
  final bool priceNegotiable;
  final TextEditingController priceCtrl;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<bool> onNoOtherPetsChanged;
  final ValueChanged<bool> onNegotiableChanged;

  const _AdoptionPrefs({
    required this.adoptionType,
    required this.petName,
    required this.noOtherPets,
    required this.priceNegotiable,
    required this.priceCtrl,
    required this.onTypeChanged,
    required this.onNoOtherPetsChanged,
    required this.onNegotiableChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Adoption Details',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF222222))),
        const SizedBox(height: 4),
        Text('Is $petName free or for sale?',
            style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
        const SizedBox(height: 12),
        // FREE / FOR SALE chips
        Row(children: [
          _TypeChip(
              label: 'FREE',
              selected: adoptionType == 'FREE',
              onTap: () => onTypeChanged('FREE')),
          const SizedBox(width: 8),
          _TypeChip(
              label: 'FOR SALE',
              selected: adoptionType == 'FOR SALE',
              onTap: () => onTypeChanged('FOR SALE')),
        ]),
        const SizedBox(height: 12),
        if (adoptionType == 'FREE')
          _InfoNote(
              'Free Adoption\n$petName will be listed as FREE. Adopters can request without any payment')
        else ...[
          const Text('SET YOUR ASKING PRICE',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDDDDDD)),
            ),
            child: Row(children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('₱',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333))),
              ),
              Expanded(
                child: TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => onNegotiableChanged(!priceNegotiable),
                child: Container(
                  margin: const EdgeInsets.all(6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: priceNegotiable
                        ? const Color(0xFFE3F2FD)
                        : const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Negotiate',
                      style: TextStyle(
                          fontSize: 11,
                          color: priceNegotiable
                              ? const Color(0xFF1DA1F2)
                              : const Color(0xFF888888),
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          _InfoNote(
              'Payment is handled outside the app during the meetup. Breedr does not process payments'),
          const SizedBox(height: 12),
          _ToggleRow(
            title: 'Price is negotiable',
            subtitle: 'Adopter can send an offer',
            value: priceNegotiable,
            onChanged: onNegotiableChanged,
          ),
        ],
        const SizedBox(height: 16),
        const Text('Adoption Requirements',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF222222))),
        const SizedBox(height: 12),
        _ToggleRow(
          title: 'No other pets at home',
          subtitle: 'For pets that need solo homes',
          value: noOtherPets,
          onChanged: onNoOtherPetsChanged,
        ),
        const SizedBox(height: 8),
        _InfoNote(
            'Free pets get more requests. You still need to review and approve each adopter yourself'),
      ],
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────

class _GenderChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _GenderChip(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected
                  ? AppColors.primary
                  : const Color(0xFFDDDDDD)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 14,
              color: selected ? Colors.white : AppColors.primary),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: selected
                      ? Colors.white
                      : const Color(0xFF444444))),
        ]),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFFE8EA)
              : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected
                  ? AppColors.primary
                  : const Color(0xFFDDDDDD)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: selected
                    ? AppColors.primary
                    : const Color(0xFF888888))),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow(
      {required this.title,
      required this.subtitle,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF333333))),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF999999))),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.primary,
          activeTrackColor: const Color(0xFFFFB3BB),
        ),
      ]),
    );
  }
}

class _InfoNote extends StatelessWidget {
  final String text;
  const _InfoNote(this.text);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
          color: const Color(0xFFFEE8EA),
          borderRadius: BorderRadius.circular(8)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.location_on,
            size: 13, color: AppColors.primary),
        const SizedBox(width: 6),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF888888),
                    height: 1.4))),
      ]),
    );
  }
}

class _PurposeEligibilityResult {
  final String title;
  final String message;
  final String currentAge;
  final String? gender;
  final String? breedSize;
  final String? eligibleOn;
  final IconData icon;

  const _PurposeEligibilityResult({
    required this.title,
    required this.message,
    required this.currentAge,
    this.gender,
    this.breedSize,
    this.eligibleOn,
    required this.icon,
  });
}

class _PurposeEligibilityDialog extends StatelessWidget {
  final _PurposeEligibilityResult result;

  const _PurposeEligibilityDialog({
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: Color(0xFFFFCDD5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.pets,
                color: AppColors.primary,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              result.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF444444),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              result.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 13,
                height: 1.55,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 22),
            _EligibilityInfoCard(
              color: const Color(0xFFFFF0F5),
              borderColor: const Color(0xFFFFCDD5),
              icon: result.icon,
              rows: [
                _EligibilityRow('Current Age', result.currentAge),
                if (result.gender != null)
                  _EligibilityRow('Gender', result.gender!),
                if (result.breedSize != null)
                  _EligibilityRow('Breed Size', result.breedSize!),
              ],
            ),
            if (result.eligibleOn != null) ...[
              const SizedBox(height: 10),
              _EligibilityInfoCard(
                color: const Color(0xFFEFFFF0),
                borderColor: const Color(0xFFC8F1C7),
                icon: Icons.event_available,
                rows: [
                  _EligibilityRow('Eligible on', result.eligibleOn!),
                ],
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  'I Understand',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EligibilityInfoCard extends StatelessWidget {
  final Color color;
  final Color borderColor;
  final IconData icon;
  final List<_EligibilityRow> rows;

  const _EligibilityInfoCard({
    required this.color,
    required this.borderColor,
    required this.icon,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rows
                  .map(
                    (row) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 82,
                            child: Text(
                              row.label,
                              style: const TextStyle(
                                color: Color(0xFF777777),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              row.value,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _EligibilityRow {
  final String label;
  final String value;

  const _EligibilityRow(this.label, this.value);
}

class _PetAge {
  final int amount;
  final String unit;

  const _PetAge({
    required this.amount,
    required this.unit,
  });

  int get totalWeeks {
    if (unit.startsWith('week')) return amount;
    if (unit.startsWith('month')) return amount * 4;
    return amount * 52;
  }

  int get totalMonths {
    if (unit.startsWith('week')) return amount ~/ 4;
    if (unit.startsWith('month')) return amount;
    return amount * 12;
  }

  static _PetAge? fromText(String text) {
    final match = RegExp(r'(\d+)\s+(\w+)').firstMatch(text.toLowerCase());
    if (match == null) return null;

    return _PetAge(
      amount: int.tryParse(match.group(1) ?? '') ?? 0,
      unit: match.group(2) ?? 'month',
    );
  }
}

// 5-step progress bar
class _PetStepBar extends StatelessWidget {
  final int currentStep;
  const _PetStepBar({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Stack(alignment: Alignment.center, children: [
        Positioned.fill(
          child: Row(children: [
            const SizedBox(width: 28),
            Expanded(child: _StepLine(active: currentStep > 1)),
            const SizedBox(width: 56),
            Expanded(child: _StepLine(active: currentStep > 2)),
            const SizedBox(width: 56),
            Expanded(child: _StepLine(active: currentStep > 3)),
            const SizedBox(width: 56),
            Expanded(child: _StepLine(active: currentStep > 4)),
            const SizedBox(width: 28),
          ]),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (int i = 1; i <= 5; i++)
              _StepDot(step: i, current: currentStep),
          ],
        ),
      ]),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int step;
  final int current;
  const _StepDot({required this.step, required this.current});
  @override
  Widget build(BuildContext context) {
    final isActive = step <= current;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? AppColors.primary : const Color(0xFFFFF0F5),
        border: Border.all(
          color: isActive
              ? AppColors.primary
              : const Color(0xFFFFB3C1),
          width: isActive ? 0 : 2,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.45),
                    blurRadius: 18,
                    spreadRadius: 2)
              ]
            : [],
      ),
      child: Icon(Icons.pets,
          size: 22,
          color: isActive ? Colors.white : const Color(0xFFFFB3C1)),
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool active;
  const _StepLine({required this.active});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : const Color(0xFFFFCDD5),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
