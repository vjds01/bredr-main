import 'package:flutter/material.dart';

import '../../models/pet_listing_data.dart';
import '../../services/pet_registration_draft_service.dart';
import '../../theme/app_colors.dart';
import 'adoption_interview_screen.dart';

class SellingPetInformationScreen extends StatefulWidget {
  const SellingPetInformationScreen({
    super.key,
    required this.petData,
    this.onConfirmed,
  });

  final PetListingData petData;
  final Future<void> Function(PetListingData data)? onConfirmed;

  @override
  State<SellingPetInformationScreen> createState() =>
      _SellingPetInformationScreenState();
}

class _SellingPetInformationScreenState
    extends State<SellingPetInformationScreen> {
  bool _confirmed = false;
  bool _continuing = false;

  @override
  void initState() {
    super.initState();
    _confirmed = widget.petData.hasValidSaleAcknowledgement;
  }

  Future<void> _continue() async {
    if (!_confirmed || _continuing) return;
    setState(() => _continuing = true);

    final updatedData = widget.petData.copyWith(
      saleRequirementsAcknowledged: true,
      saleRequirementsAcknowledgedAt: DateTime.now().toUtc(),
    );

    try {
      final callback = widget.onConfirmed;
      if (callback != null) {
        await callback(updatedData);
      } else {
        await PetRegistrationDraftService.instance.saveDraft(updatedData);
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdoptionInterviewScreen(petData: updatedData),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'We could not save your confirmation. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _continuing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        tooltip: 'Back',
                        onPressed: _continuing
                            ? null
                            : () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const _IntroductionCard(),
                    const SizedBox(height: 16),
                    const _RequirementsCard(),
                    const SizedBox(height: 18),
                    _ConfirmationTile(
                      value: _confirmed,
                      enabled: !_continuing,
                      onChanged: (value) => setState(() => _confirmed = value),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  key: const Key('selling-requirements-continue'),
                  onPressed: _confirmed && !_continuing ? _continue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: const Color(0xFFFFBCC7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: _continuing
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroductionCard extends StatelessWidget {
  const _IntroductionCard();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SquareIcon(icon: Icons.campaign_outlined),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Before you sell your pet, make sure you have everything you need!',
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF20232A),
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'To keep the Breedr community safe and trusted, review the documents and permits that may apply before listing your pet for sale.',
                  style: TextStyle(color: Color(0xFF6E6870), height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.pets, color: AppColors.primary, size: 38),
        ],
      ),
    );
  }
}

class _RequirementsCard extends StatelessWidget {
  const _RequirementsCard();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      bordered: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionHeading(
            icon: Icons.person_outline,
            title: 'Pet Owner / Seller Requirements',
            subtitle: 'Documents must be complete, valid, and up to date.',
          ),
          SizedBox(height: 14),
          _RequirementRow(
            icon: Icons.badge_outlined,
            title: 'Valid Government ID',
            detail: 'For identity verification and record purposes.',
          ),
          _RequirementRow(
            icon: Icons.description_outlined,
            title: "Mayor's / Business Permit",
            detail:
                'When required for a business or pet breeding/selling facility, obtain this from the local BPLO.',
          ),
          _RequirementRow(
            icon: Icons.medical_information_outlined,
            title: 'Veterinary Health Certificate',
            detail:
                'Issued by a licensed veterinarian and showing that the pet is healthy and fit for sale.',
          ),
          _RequirementRow(
            icon: Icons.folder_copy_outlined,
            title: 'Proof of Ownership / Facility Documents',
            detail:
                'Ownership papers, facility photos, or other documents required by BAI or the local veterinary office.',
          ),
          Divider(height: 28),
          _SectionHeading(
            icon: Icons.verified_user_outlined,
            title: 'Required Permit / Registration',
            subtitle:
                'Requirements depend on the seller, facility, location, and type of activity.',
          ),
          SizedBox(height: 14),
          _RequirementRow(
            icon: Icons.assignment_turned_in_outlined,
            title: 'BAI Certificate of Registration / License to Operate',
            detail:
                'When applicable to kennels, catteries, pet shops, or live-animal selling/trading facilities.',
          ),
          SizedBox(height: 4),
          _InformationNote(),
        ],
      ),
    );
  }
}

class _ConfirmationTile extends StatelessWidget {
  const _ConfirmationTile({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Confirm selling requirements',
      checked: value,
      child: InkWell(
        key: const Key('selling-requirements-confirmation'),
        onTap: enabled ? () => onChanged(!value) : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: value ? AppColors.primary : const Color(0xFFFFC7D1),
              width: value ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: value,
                onChanged: enabled
                    ? (checked) => onChanged(checked ?? false)
                    : null,
                activeColor: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'I confirm that I have read and understood the requirements and permits that may apply when selling or offering a pet on Breedr. I understand that this confirmation does not verify my documents.',
                    style: TextStyle(
                      color: Color(0xFF505660),
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
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

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F7),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(Icons.check_circle, color: AppColors.primary, size: 21),
          ),
          const SizedBox(width: 10),
          Icon(icon, color: const Color(0xFF26313A), size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF20232A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: const TextStyle(
                    color: Color(0xFF716B73),
                    height: 1.35,
                    fontSize: 12,
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

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SquareIcon(icon: icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF20232A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF716B73), height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SquareIcon extends StatelessWidget {
  const _SquareIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: Colors.white, size: 27),
    );
  }
}

class _InformationNote extends StatelessWidget {
  const _InformationNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE8ED),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info, color: AppColors.primary, size: 20),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Breedr does not determine which permits apply to you. Confirm current requirements with the BAI, Cabuyao City, or your local veterinary office before listing.',
              style: TextStyle(
                color: Color(0xFF6B6067),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, this.bordered = false});

  final Widget child;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: bordered ? AppColors.primary : const Color(0xFFFFDDE5),
        ),
      ),
      child: child,
    );
  }
}
