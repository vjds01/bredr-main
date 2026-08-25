import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/moderation_service.dart';
import '../../services/user_session_service.dart';
import '../../theme/app_colors.dart';
import 'get_started_screen.dart';

class ModerationGateScreen extends StatefulWidget {
  final ModerationState state;

  const ModerationGateScreen({super.key, required this.state});

  @override
  State<ModerationGateScreen> createState() => _ModerationGateScreenState();
}

class _ModerationGateScreenState extends State<ModerationGateScreen> {
  Future<void> _logout(BuildContext context) async {
    await UserSessionService.instance.signOut();
    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const GetStartedScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final icon = state.isBanned
        ? Icons.block_rounded
        : Icons.lock_clock_rounded;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF4F8),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: const Color(0xFFFFCCD8)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        blurRadius: 28,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 82,
                        height: 82,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFFE1EA),
                        ),
                        child: Icon(icon, size: 42, color: AppColors.primary),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        state.title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF251D29),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        state.body,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.urbanist(
                          fontSize: 16,
                          height: 1.45,
                          color: const Color(0xFF6F6574),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 22),
                      _StatusRow(label: 'Status', value: state.badge),
                      if (state.action.isNotEmpty)
                        _StatusRow(label: 'Action', value: state.action),
                      if (state.actionAt != null)
                        _StatusRow(
                          label: 'Reviewed',
                          value: _formatDate(state.actionAt!),
                        ),
                      if (state.suspensionEndsAt != null)
                        _StatusRow(
                          label: 'Suspension ends',
                          value: _formatDate(state.suspensionEndsAt!),
                        ),
                      const SizedBox(height: 18),
                      _GuidanceCard(guidance: state.guidance),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AccountStatusScreen(state: state),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    'View Account Status',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () => _logout(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    'Log out',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
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

class AccountStatusScreen extends StatelessWidget {
  final ModerationState state;

  const AccountStatusScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final icon = state.isBanned
        ? Icons.block_rounded
        : Icons.lock_clock_rounded;
    final action = state.action.isNotEmpty
        ? state.action
        : state.isPermanent
            ? 'Permanent account disable'
            : 'Temporary suspension';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF4F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
        ),
        title: Text(
          'Account Status',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF251D29),
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFFFCCD8)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFE1EA),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: AppColors.primary, size: 38),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      state.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF251D29),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      state.body,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.urbanist(
                        fontSize: 15,
                        height: 1.4,
                        color: const Color(0xFF6F6574),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _StatusRow(label: 'Status', value: state.badge),
                    _StatusRow(label: 'Action', value: action),
                    if (state.actionAt != null)
                      _StatusRow(
                        label: 'Reviewed',
                        value: _formatDate(state.actionAt!),
                      ),
                    if (state.suspensionEndsAt != null)
                      _StatusRow(
                        label: 'Suspension ends',
                        value: _formatDate(state.suspensionEndsAt!),
                      ),
                    const SizedBox(height: 16),
                    _GuidanceCard(guidance: state.guidance),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  'I Understand',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
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

class _GuidanceCard extends StatelessWidget {
  final ModerationGuidance guidance;

  const _GuidanceCard({required this.guidance});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1C9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            guidance.title,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF6F5317),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            guidance.body,
            style: GoogleFonts.urbanist(
              color: const Color(0xFF6F6574),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatusRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.urbanist(
                color: const Color(0xFF8B7C86),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.urbanist(
                color: const Color(0xFF251D29),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
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
