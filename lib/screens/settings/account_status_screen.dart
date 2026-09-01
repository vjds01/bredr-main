import 'package:flutter/material.dart';

import '../../services/moderation_service.dart';
import '../../theme/app_colors.dart';

class AccountStatusDetailsScreen extends StatelessWidget {
  final ModerationState state;

  const AccountStatusDetailsScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7F9),
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 2,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              color: AppColors.primary,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: const Text(
          'Account Status',
          style: TextStyle(
            color: Color(0xFF281F2B),
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusTabs(state: state),
            const SizedBox(height: 18),
            _StatusHero(state: state),
            const SizedBox(height: 18),
            if (state.isWarning) ..._warningContent(state),
            if (state.isSuspended) ..._suspendedContent(state),
            if (state.isBanned) ..._disabledContent(state),
            if (!state.isWarning && !state.isBlocked) ..._activeContent(),
          ],
        ),
      ),
    );
  }

  List<Widget> _warningContent(ModerationState state) => [
    _SectionLabel('REPORT CATEGORY'),
    _TextCard(
      title: _category(state),
      titleColor: AppColors.primary,
      body: _categoryDescription(state.category),
    ),
    _SectionLabel("ADMIN'S EXPLANATION"),
    _TextCard(body: state.body),
    _SectionLabel(state.guidance.title.toUpperCase()),
    _TextCard(body: state.guidance.body),
    const _SectionLabel('WHAT HAPPENS NEXT'),
    const _TextCard(
      body:
          'No features are restricted right now. Your account and listings remain active. If another report against your account is verified, stronger action may be taken.',
    ),
  ];

  List<Widget> _suspendedContent(ModerationState state) => [
    const _SectionLabel('SUSPENSION DETAILS'),
    _DetailsCard(
      rows: [
        ('Report category', _category(state)),
        ('Date issued', _formatDate(state.actionAt)),
        ('Access restored', _formatDate(state.suspensionEndsAt)),
      ],
    ),
    const _SectionLabel("ADMIN'S EXPLANATION"),
    _TextCard(body: state.body),
    const _SectionLabel('UNAVAILABLE WHILE SUSPENDED'),
    const _RestrictionCard(
      items: [
        'Creating or editing pet listings',
        'Sending or receiving messages',
        'Submitting adoption or breeding requests',
      ],
    ),
  ];

  List<Widget> _disabledContent(ModerationState state) => [
    const _SectionLabel('DISABLED DETAILS'),
    _DetailsCard(
      rows: [
        ('Report category', _category(state)),
        ('Date of enforcement', _formatDate(state.actionAt)),
      ],
    ),
    const _SectionLabel('FINAL ADMIN EXPLANATION'),
    _TextCard(body: state.body),
    const _SectionLabel('THINK THIS WAS A MISTAKE?'),
    const _TextCard(
      body:
          'You can appeal this decision by contacting breedrteam@gmail.com with your account details. Our team will review appeals within 5–7 business days.',
    ),
  ];

  List<Widget> _activeContent() => const [
    _SectionLabel('ACCOUNT STANDING'),
    _TextCard(
      body:
          'Your account is in good standing. There are no active warnings, suspensions, or restrictions.',
    ),
  ];
}

class _StatusTabs extends StatelessWidget {
  final ModerationState state;
  const _StatusTabs({required this.state});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _StatusChip(
          label: 'Warning',
          color: const Color(0xFFE6B83D),
          selected: state.isWarning,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _StatusChip(
          label: 'Suspended',
          color: const Color(0xFFFF7A54),
          selected: state.isSuspended,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _StatusChip(
          label: 'Disabled',
          color: const Color(0xFFE63E60),
          selected: state.isBanned,
        ),
      ),
    ],
  );
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  const _StatusChip({
    required this.label,
    required this.color,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 36,
    decoration: BoxDecoration(
      color: selected ? const Color(0xFF271D2B) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE9DDE1)),
    ),
    alignment: Alignment.center,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF8C8390),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _StatusHero extends StatelessWidget {
  final ModerationState state;
  const _StatusHero({required this.state});

  @override
  Widget build(BuildContext context) {
    final warning = state.isWarning;
    final suspended = state.isSuspended;
    final blocked = state.isBlocked;
    final title = warning
        ? 'You have a warning'
        : suspended
        ? 'Account Suspended'
        : state.isBanned
        ? 'Account Disabled'
        : 'Account in good standing';
    final subtitle = warning
        ? 'Issued ${_formatDate(state.actionAt)} by the Breedr Team'
        : suspended
        ? _suspensionSummary(state)
        : state.isBanned
        ? 'Permanently removed from Breedr'
        : 'No active account actions';
    final icon = warning
        ? Icons.warning_amber_rounded
        : suspended
        ? Icons.pause_rounded
        : state.isBanned
        ? Icons.block
        : Icons.verified_outlined;
    final accent = warning
        ? const Color(0xFFFFB238)
        : blocked
        ? AppColors.primary
        : const Color(0xFF279B6A);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 25),
      decoration: BoxDecoration(
        color: warning
            ? const Color(0xFFFFF0D3)
            : blocked
            ? const Color(0xFFFFDDE4)
            : const Color(0xFFE1F5EC),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 30),
          ),
          const SizedBox(height: 13),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF2B2230),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF918794),
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 9),
    child: Text(
      text,
      style: const TextStyle(
        color: Color(0xFF918796),
        fontSize: 11,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _TextCard extends StatelessWidget {
  final String? title;
  final String body;
  final Color? titleColor;
  const _TextCard({this.title, required this.body, this.titleColor});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 18),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF8FA),
      borderRadius: BorderRadius.circular(17),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title!,
            style: TextStyle(
              color: titleColor ?? const Color(0xFF2B2230),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (body.isNotEmpty) const SizedBox(height: 5),
        ],
        if (body.isNotEmpty)
          Text(
            body,
            style: const TextStyle(
              color: Color(0xFF706675),
              fontSize: 13,
              height: 1.5,
            ),
          ),
      ],
    ),
  );
}

class _DetailsCard extends StatelessWidget {
  final List<(String, String)> rows;
  const _DetailsCard({required this.rows});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 18),
    padding: const EdgeInsets.symmetric(horizontal: 15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: const Color(0xFFEADDE1)),
    ),
    child: Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    rows[i].$1,
                    style: const TextStyle(
                      color: Color(0xFF988E9C),
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    rows[i].$2,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Color(0xFF312733),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (i != rows.length - 1)
            const Divider(height: 1, color: Color(0xFFF0E2E6)),
        ],
      ],
    ),
  );
}

class _RestrictionCard extends StatelessWidget {
  final List<String> items;
  const _RestrictionCard({required this.items});
  @override
  Widget build(BuildContext context) => Column(
    children: items
        .map(
          (item) => Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEADDE1)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.flag_outlined,
                  color: AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      color: Color(0xFF817786),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList(),
  );
}

String _category(ModerationState state) => state.category.trim().isEmpty
    ? 'Account standing review'
    : state.category.trim();

String _categoryDescription(String category) {
  final key = category.toLowerCase();
  if (key.contains('scam') || key.contains('fraud')) {
    return 'Requests for money or personal information may be unsafe or inappropriate.';
  }
  if (key.contains('harassment') || key.contains('abusive')) {
    return 'Communication must remain respectful and safe for everyone.';
  }
  if (key.contains('animal abuse') || key.contains('neglect')) {
    return 'Animal welfare concerns require immediate correction.';
  }
  if (key.contains('misleading') || key.contains('fake')) {
    return 'Profiles and listings must contain accurate, verifiable information.';
  }
  return 'The Breedr Team reviewed activity associated with this account.';
}

String _formatDate(DateTime? value) {
  if (value == null) return 'Not available';
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
  final local = value.toLocal();
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}

String _suspensionSummary(ModerationState state) {
  final end = state.suspensionEndsAt;
  if (end == null) return 'Temporary account restriction';
  final remaining = end.difference(DateTime.now()).inDays + 1;
  return remaining > 0
      ? '$remaining day${remaining == 1 ? '' : 's'} remaining'
      : 'Access is being restored';
}
