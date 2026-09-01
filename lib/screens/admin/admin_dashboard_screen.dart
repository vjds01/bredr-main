import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/user_session_service.dart';
import '../../services/adoption_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/breedr_network_image.dart';
import '../auth/forgot_password_screen.dart';
import '../auth/get_started_screen.dart';

enum _AdminTab { dashboard, reports, returns, accounts, activity }

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _firestore = FirebaseFirestore.instance;
  _AdminTab _tab = _AdminTab.dashboard;
  String _reportTab = 'listing';
  String _reportFilter = 'all';
  String _returnFilter = 'all';
  String _userFilter = 'all';
  String _reportSearch = '';
  String _returnSearch = '';
  String _userSearch = '';
  bool _moderationGuideExpanded = true;

  Future<void> _logout() async {
    await UserSessionService.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const GetStartedScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = UserSessionService.instance.currentUser;
    final mediaQuery = MediaQuery.of(context);
    final currentScale = MediaQuery.textScalerOf(context).scale(1);
    return PopScope(
      canPop: false,
      child: MediaQuery(
        data: mediaQuery.copyWith(
          textScaler: TextScaler.linear(currentScale * 1.08),
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFFFFF7FA),
          body: SafeArea(
            child: Column(
              children: [
                _TopBar(
                  email: user?.email ?? 'breedrteam@gmail.com',
                  onNotifications: _showNotifications,
                  onProfile: _showAdminProfile,
                ),
                Expanded(child: _buildBody()),
                _AdminBottomNav(
                  selected: _tab,
                  onSelected: (tab) => setState(() => _tab = tab),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: switch (_tab) {
        _AdminTab.dashboard => _DashboardTab(
          key: const ValueKey('dashboard'),
          guideExpanded: _moderationGuideExpanded,
          onToggleGuide: () => setState(
            () => _moderationGuideExpanded = !_moderationGuideExpanded,
          ),
          onOpenReports: () => setState(() => _tab = _AdminTab.reports),
          onOpenReturns: () => setState(() => _tab = _AdminTab.returns),
          onOpenAccounts: () => setState(() => _tab = _AdminTab.accounts),
        ),
        _AdminTab.reports => _ReportsTab(
          key: const ValueKey('reports'),
          reportTab: _reportTab,
          filter: _reportFilter,
          search: _reportSearch,
          onReportTab: (value) => setState(() => _reportTab = value),
          onFilter: (value) => setState(() => _reportFilter = value),
          onSearch: (value) => setState(() => _reportSearch = value),
          onOpen: _openReportDetail,
        ),
        _AdminTab.returns => _ReturnsTab(
          key: const ValueKey('returns'),
          filter: _returnFilter,
          search: _returnSearch,
          onFilter: (value) => setState(() => _returnFilter = value),
          onSearch: (value) => setState(() => _returnSearch = value),
          onOpen: _openReturnDetail,
        ),
        _AdminTab.accounts => _AccountsTab(
          key: const ValueKey('accounts'),
          filter: _userFilter,
          search: _userSearch,
          onFilter: (value) => setState(() => _userFilter = value),
          onSearch: (value) => setState(() => _userSearch = value),
          onOpen: _openUserDetail,
        ),
        _AdminTab.activity => const _ActivityTab(key: ValueKey('activity')),
      },
    );
  }

  Future<void> _showNotifications() async {
    final items = await _loadAdminNotifications();
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => _AdminNotificationsSheet(items: items),
    );
  }

  Future<List<_AdminNotificationItem>> _loadAdminNotifications() async {
    final reports = await _firestore
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .get();
    final returns = await _firestore
        .collection('adoptionReturnRequests')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .get();
    final items = <_AdminNotificationItem>[];

    for (final doc in returns.docs) {
      final data = doc.data();
      final status = (data['adminStatus'] ?? data['status'] ?? 'pending')
          .toString()
          .toLowerCase();
      if (status != 'pending' && status != 'pendingadminreview') continue;
      final adopter = await _userDisplayName(
        data['adopterId']?.toString() ?? data['filedBy']?.toString() ?? '',
        fallback: 'An adopter',
      );
      final petName = data['petName']?.toString() ?? 'this pet';
      final reason = data['reason']?.toString() ?? 'Return request';
      items.add(
        _AdminNotificationItem(
          icon: Icons.assignment_return_outlined,
          category: 'Return request filed',
          title: '$adopter requested a return for $petName — $reason',
          createdAt: data['createdAt'],
          onOpen: () => _openReturnDetail(doc),
        ),
      );
    }

    for (final doc in reports.docs) {
      final data = doc.data();
      final status = (data['status'] ?? 'pending').toString().toLowerCase();
      if (status != 'pending') continue;
      final reporter = await _reporterName(data);
      final target = _targetTitle(data);
      final reason = data['reason']?.toString() ?? 'Report';
      items.add(
        _AdminNotificationItem(
          icon: _reportIcon(data),
          category: data['type'] == 'user'
              ? 'User profile reported'
              : 'Pet listing reported',
          title: '$reporter reported $target for $reason',
          createdAt: data['createdAt'],
          onOpen: () => _openReportDetail(doc),
        ),
      );
    }

    items.sort(
      (a, b) => _timestampMillis(
        b.createdAt,
      ).compareTo(_timestampMillis(a.createdAt)),
    );
    return items.take(20).toList();
  }

  Future<String> _userDisplayName(
    String userId, {
    required String fallback,
  }) async {
    if (userId.trim().isEmpty) return fallback;
    try {
      final snapshot = await _firestore.collection('users').doc(userId).get();
      final data = snapshot.data();
      if (data == null) return fallback;
      return _name(data);
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _showAdminProfile() async {
    final user = UserSessionService.instance.currentUser;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetHandle(),
            const SizedBox(height: 18),
            Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0xFFFFE1E8),
                  child: Icon(
                    Icons.admin_panel_settings,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Breedr Team',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        user?.email ?? 'breedrteam@gmail.com',
                        style: const TextStyle(color: Color(0xFF777777)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _AdminSettingTile(
              icon: Icons.person_outline,
              title: 'Admin Profile',
              subtitle: 'Breedr moderation account',
              onTap: () => _openFromAdminSheet(_showAdminProfileDetails),
            ),
            _AdminSettingTile(
              icon: Icons.notifications_outlined,
              title: 'Notification Preferences',
              subtitle: 'Report and return review alerts',
              onTap: () =>
                  _openFromAdminSheet(_showAdminNotificationPreferences),
            ),
            _AdminSettingTile(
              icon: Icons.lock_outline,
              title: 'Change Password',
              subtitle: 'Use the Breedr password reset flow',
              onTap: () => _openFromAdminSheet(_startAdminPasswordReset),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _confirmLogout,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(50),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }

  void _openFromAdminSheet(Future<void> Function() action) {
    Navigator.pop(context);
    Future<void>.delayed(const Duration(milliseconds: 180), () async {
      if (!mounted) return;
      await action();
    });
  }

  Future<void> _showAdminProfileDetails() async {
    final user = UserSessionService.instance.currentUser;
    final uid = user?.uid;
    final future = uid == null
        ? Future<DocumentSnapshot<Map<String, dynamic>>>.error(
            StateError('No signed-in admin account.'),
          )
        : _firestore.collection('users').doc(uid).get();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? const <String, dynamic>{};
          final name = _name({
            ...data,
            if ((data['fullName'] ?? '').toString().trim().isEmpty)
              'fullName': 'Breedr Team',
          });
          final email = user?.email ?? data['email']?.toString() ?? 'Not set';
          final role = data['role']?.toString().trim().isNotEmpty == true
              ? data['role'].toString()
              : 'admin';

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.62,
            minChildSize: 0.42,
            maxChildSize: 0.9,
            builder: (context, controller) => ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
              children: [
                const _SheetHandle(),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const _IconBubble(
                      icon: Icons.admin_panel_settings_outlined,
                      size: 54,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            email,
                            style: const TextStyle(
                              color: Color(0xFF8C7D88),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const LinearProgressIndicator(color: AppColors.primary),
                _DetailSection(
                  title: 'Admin Account',
                  children: [
                    _DetailRow(label: 'Display name', value: name),
                    _DetailRow(label: 'Email', value: email),
                    _DetailRow(label: 'Role', value: role),
                    _DetailRow(
                      label: 'Created',
                      value: _formatTimestamp(data['createdAt']),
                    ),
                    _DetailRow(
                      label: 'Updated',
                      value: _formatTimestamp(data['updatedAt']),
                    ),
                  ],
                ),
                const _AdminInfoPanel(
                  icon: Icons.verified_user_outlined,
                  title: 'Admin Access',
                  body:
                      'This account can review reports, return requests, and moderation history inside Breedr.',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAdminNotificationPreferences() async {
    final user = UserSessionService.instance.currentUser;
    final uid = user?.uid;
    if (uid == null) {
      _showGlobalSnack(context, 'Please sign in again to update preferences.');
      return;
    }

    final snapshot = await _firestore.collection('users').doc(uid).get();
    if (!mounted) return;
    final data = snapshot.data() ?? const <String, dynamic>{};
    final rawPreferences = data['adminNotificationPreferences'];
    final preferences = rawPreferences is Map
        ? Map<String, bool>.fromEntries(
            rawPreferences.entries.map(
              (entry) => MapEntry(entry.key.toString(), entry.value == true),
            ),
          )
        : <String, bool>{};

    bool valueFor(String key) => preferences[key] ?? true;

    Future<void> savePreference(String key, bool value) async {
      preferences[key] = value;
      await _firestore.collection('users').doc(uid).set({
        'adminNotificationPreferences': preferences,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> toggle(String key, bool value) async {
            setSheetState(() => preferences[key] = value);
            try {
              await savePreference(key, value);
            } on FirebaseException catch (_) {
              if (!context.mounted) return;
              setSheetState(() => preferences[key] = !value);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Unable to save this preference right now.'),
                ),
              );
            }
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _SheetHandle(),
                  const SizedBox(height: 18),
                  const _SheetTitle(
                    icon: Icons.notifications_outlined,
                    title: 'Notification Preferences',
                    badge: 'admin',
                  ),
                  const SizedBox(height: 14),
                  _AdminPreferenceSwitch(
                    title: 'Pet Listing Reports',
                    subtitle: 'New reports filed against adoption listings',
                    value: valueFor('listingReports'),
                    onChanged: (value) => toggle('listingReports', value),
                  ),
                  _AdminPreferenceSwitch(
                    title: 'User Profile Reports',
                    subtitle: 'New reports filed against Breedr users',
                    value: valueFor('profileReports'),
                    onChanged: (value) => toggle('profileReports', value),
                  ),
                  _AdminPreferenceSwitch(
                    title: 'Return Requests',
                    subtitle: 'Adoption return claims during protection',
                    value: valueFor('returnRequests'),
                    onChanged: (value) => toggle('returnRequests', value),
                  ),
                  _AdminPreferenceSwitch(
                    title: 'Admin Reminders',
                    subtitle: 'Pending review and moderation follow-ups',
                    value: valueFor('adminReminders'),
                    onChanged: (value) => toggle('adminReminders', value),
                  ),
                  const SizedBox(height: 8),
                  const _AdminInfoPanel(
                    icon: Icons.info_outline,
                    title: 'Saved to this admin account',
                    body:
                        'These settings are stored in Firestore and can be used by global push notifications once that module is added.',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _startAdminPasswordReset() async {
    final email = UserSessionService.instance.currentUser?.email;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(initialEmail: email),
      ),
    );
  }

  Future<void> _openReportDetail(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ReportDetailSheet(reportId: doc.id, data: doc.data()),
    );
  }

  Future<void> _openReturnDetail(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) =>
          _ReturnDetailSheet(returnRequestId: doc.id, data: doc.data()),
    );
  }

  Future<void> _openUserDetail(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _UserDetailSheet(userId: doc.id, data: doc.data()),
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to access admin.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (shouldLogout == true) {
      await _logout();
    }
  }
}

class _DashboardTab extends StatelessWidget {
  final bool guideExpanded;
  final VoidCallback onToggleGuide;
  final VoidCallback onOpenReports;
  final VoidCallback onOpenReturns;
  final VoidCallback onOpenAccounts;

  const _DashboardTab({
    super.key,
    required this.guideExpanded,
    required this.onToggleGuide,
    required this.onOpenReports,
    required this.onOpenReturns,
    required this.onOpenAccounts,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<_AdminCounts>(
      stream: _watchCounts(),
      builder: (context, snapshot) {
        final counts = snapshot.data ?? const _AdminCounts();
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          children: [
            const _PageIntro(
              title: 'Good day, Breedr Team',
              subtitle: "Here's what needs your attention today.",
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.05,
              children: [
                _StatCard(
                  icon: Icons.pets,
                  assetPath: 'assets/images/admin/pending_listing_report.png',
                  count: counts.pendingListingReports,
                  label: 'Pending listing reports',
                  color: const Color(0xFFFFDDE5),
                  onTap: onOpenReports,
                ),
                _StatCard(
                  icon: Icons.person_outline,
                  assetPath: 'assets/images/admin/pending_profile_reports.png',
                  count: counts.pendingUserReports,
                  label: 'Pending profile reports',
                  color: const Color(0xFFFFE6F2),
                  onTap: onOpenReports,
                ),
                _StatCard(
                  icon: Icons.assignment_return_outlined,
                  assetPath: 'assets/images/admin/pending_return_requests.png',
                  count: counts.pendingReturns,
                  label: 'Pending return requests',
                  color: const Color(0xFFFFEFD9),
                  onTap: onOpenReturns,
                ),
                _StatCard(
                  icon: Icons.manage_accounts_outlined,
                  assetPath: 'assets/images/admin/active_user_accounts.png',
                  count: counts.activeUsers,
                  label: 'Active user accounts',
                  color: const Color(0xFFEAF6EE),
                  onTap: onOpenAccounts,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _CollapsibleAdminInfoPanel(
              icon: Icons.lightbulb_outline,
              title: 'New to moderating? Read this first —',
              body:
                  "Every report or account action walks you through 4 guided steps: Review the evidence, Validate whether it's a real issue, pick a severity so the app can suggest the right action, then confirm before anything changes.",
              expanded: guideExpanded,
              onToggle: onToggleGuide,
            ),
            const SizedBox(height: 18),
            _DashboardPreview(
              title: 'Pending Reports',
              icon: Icons.flag_outlined,
              collection: 'reports',
              pendingField: 'status',
              pendingValue: 'pending',
              emptyText: 'No pending reports right now.',
              onViewAll: onOpenReports,
            ),
            const SizedBox(height: 14),
            _DashboardPreview(
              title: 'Pending Returns',
              icon: Icons.assignment_return_outlined,
              collection: 'adoptionReturnRequests',
              pendingField: 'adminStatus',
              pendingValue: 'pending',
              emptyText: 'No return requests waiting for review.',
              onViewAll: onOpenReturns,
            ),
          ],
        );
      },
    );
  }

  Stream<_AdminCounts> _watchCounts() {
    return FirebaseFirestore.instance.snapshotsInSync().asyncMap((_) async {
      final firestore = FirebaseFirestore.instance;
      final reports = await firestore.collection('reports').get();
      final returns = await firestore
          .collection('adoptionReturnRequests')
          .get();
      final users = await firestore.collection('users').get();
      final pendingReports = reports.docs
          .where((doc) => (doc.data()['status'] ?? 'pending') == 'pending')
          .toList();
      return _AdminCounts(
        pendingListingReports: pendingReports
            .where((doc) => (doc.data()['type'] ?? '') == 'listing')
            .length,
        pendingUserReports: pendingReports
            .where((doc) => (doc.data()['type'] ?? '') == 'user')
            .length,
        pendingReturns: returns.docs.where((doc) {
          final data = doc.data();
          return (data['adminStatus'] ?? data['status']) == 'pending' ||
              data['status'] == 'pendingAdminReview';
        }).length,
        activeUsers: users.docs.where((doc) {
          final data = doc.data();
          final role = data['role']?.toString().toLowerCase();
          final status =
              (data['moderationStatus'] ?? data['status'] ?? 'active')
                  .toString()
                  .toLowerCase();
          return role != 'admin' && (status == 'active' || status == 'warned');
        }).length,
      );
    });
  }
}

class _ReportsTab extends StatelessWidget {
  final String reportTab;
  final String filter;
  final String search;
  final ValueChanged<String> onReportTab;
  final ValueChanged<String> onFilter;
  final ValueChanged<String> onSearch;
  final ValueChanged<QueryDocumentSnapshot<Map<String, dynamic>>> onOpen;

  const _ReportsTab({
    super.key,
    required this.reportTab,
    required this.filter,
    required this.search,
    required this.onReportTab,
    required this.onFilter,
    required this.onSearch,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final docs =
            (snapshot.data?.docs ??
                    const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                .where((doc) => _matches(doc.data()))
                .toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          children: [
            const _PageIntro(
              title: 'Reports',
              subtitle: 'Review flagged listings & profiles.',
            ),
            const SizedBox(height: 14),
            _SearchBox(
              hint: 'Search by name, reason, or reporter',
              onChanged: onSearch,
            ),
            const SizedBox(height: 12),
            _SegmentRow(
              selected: reportTab,
              items: const [
                ('listing', Icons.pets, 'Listings'),
                ('user', Icons.person_outline, 'Profiles'),
              ],
              onSelected: onReportTab,
            ),
            const SizedBox(height: 12),
            _ChipRow(
              selected: filter,
              items: const [
                ('all', 'All'),
                ('pending', 'Pending'),
                ('resolved', 'Resolved'),
              ],
              onSelected: onFilter,
            ),
            const SizedBox(height: 16),
            if (snapshot.hasError)
              const _EmptyState(
                icon: Icons.cloud_off,
                title: 'Unable to load reports',
                message: 'Please check Firestore rules or your connection.',
              )
            else if (docs.isEmpty)
              const _EmptyState(
                icon: Icons.flag_outlined,
                title: 'No reports found',
                message: 'Reports matching this filter will appear here.',
              )
            else
              _GroupedAdminList(
                children: [
                  for (var index = 0; index < docs.length; index++)
                    _ReportCard(
                      doc: docs[index],
                      isLast: index == docs.length - 1,
                      onTap: onOpen,
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

  bool _matches(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString();
    if (type != reportTab) return false;
    final status = (data['status'] ?? 'pending').toString();
    if (filter != 'all' && status != filter) return false;
    if (search.trim().isEmpty) return true;
    final haystack = [
      data['reason'],
      data['detail'],
      (data['targetSnapshot'] as Map?)?['petName'],
      (data['targetSnapshot'] as Map?)?['displayName'],
      (data['targetSnapshot'] as Map?)?['ownerName'],
      (data['reporterSnapshot'] as Map?)?['fullName'],
      (data['reporterSnapshot'] as Map?)?['userName'],
      (data['reporterSnapshot'] as Map?)?['email'],
    ].join(' ').toLowerCase();
    return haystack.contains(search.trim().toLowerCase());
  }
}

class _ReturnsTab extends StatelessWidget {
  final String filter;
  final String search;
  final ValueChanged<String> onFilter;
  final ValueChanged<String> onSearch;
  final ValueChanged<QueryDocumentSnapshot<Map<String, dynamic>>> onOpen;

  const _ReturnsTab({
    super.key,
    required this.filter,
    required this.search,
    required this.onFilter,
    required this.onSearch,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('adoptionReturnRequests')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final docs =
            (snapshot.data?.docs ??
                    const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                .where((doc) => _matches(doc.data()))
                .toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          children: [
            const _PageIntro(
              title: 'Returns',
              subtitle: 'Requests awaiting a decision.',
            ),
            const SizedBox(height: 14),
            _SearchBox(
              hint: 'Search by pet, requester, or reason',
              onChanged: onSearch,
            ),
            const SizedBox(height: 12),
            _ChipRow(
              selected: filter,
              items: const [
                ('all', 'All'),
                ('pending', 'Pending'),
                ('approved', 'Approved'),
                ('denied', 'Denied'),
              ],
              onSelected: onFilter,
            ),
            const SizedBox(height: 16),
            if (snapshot.hasError)
              const _EmptyState(
                icon: Icons.cloud_off,
                title: 'Unable to load returns',
                message: 'Please check Firestore rules or your connection.',
              )
            else if (docs.isEmpty)
              const _EmptyState(
                icon: Icons.assignment_return_outlined,
                title: 'No return requests found',
                message:
                    'Return requests matching this filter will appear here.',
              )
            else
              _GroupedAdminList(
                children: [
                  for (var index = 0; index < docs.length; index++)
                    _ReturnCard(
                      doc: docs[index],
                      isLast: index == docs.length - 1,
                      onTap: onOpen,
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

  bool _matches(Map<String, dynamic> data) {
    final status = (data['adminStatus'] ?? data['status'] ?? 'pending')
        .toString()
        .replaceAll('pendingAdminReview', 'pending');
    if (filter != 'all' && status != filter) return false;
    if (search.trim().isEmpty) return true;
    final haystack = [
      data['petName'],
      data['reason'],
      data['description'],
      data['ownerName'],
      data['adopterName'],
    ].join(' ').toLowerCase();
    return haystack.contains(search.trim().toLowerCase());
  }
}

class _AccountsTab extends StatelessWidget {
  final String filter;
  final String search;
  final ValueChanged<String> onFilter;
  final ValueChanged<String> onSearch;
  final ValueChanged<QueryDocumentSnapshot<Map<String, dynamic>>> onOpen;

  const _AccountsTab({
    super.key,
    required this.filter,
    required this.search,
    required this.onFilter,
    required this.onSearch,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        final docs =
            (snapshot.data?.docs ??
                    const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                .where((doc) => _matches(doc.data()))
                .toList()
              ..sort((a, b) {
                final first = _name(a.data()).trim().toLowerCase();
                final second = _name(b.data()).trim().toLowerCase();
                final byName = first.compareTo(second);
                return byName != 0 ? byName : a.id.compareTo(b.id);
              });
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          children: [
            const _PageIntro(
              title: 'Accounts',
              subtitle: 'Review user standing and moderation history.',
            ),
            const SizedBox(height: 14),
            _SearchBox(hint: 'Search name or @handle', onChanged: onSearch),
            const SizedBox(height: 12),
            _ChipRow(
              selected: filter,
              items: const [
                ('all', 'All'),
                ('active', 'Active'),
                ('warned', 'Warned'),
                ('suspended', 'Suspended'),
                ('banned', 'Banned'),
              ],
              onSelected: onFilter,
            ),
            const SizedBox(height: 16),
            if (snapshot.hasError)
              const _EmptyState(
                icon: Icons.cloud_off,
                title: 'Unable to load accounts',
                message: 'Please check Firestore rules or your connection.',
              )
            else if (docs.isEmpty)
              const _EmptyState(
                icon: Icons.manage_accounts_outlined,
                title: 'No accounts found',
                message: 'Accounts matching this filter will appear here.',
              )
            else
              _GroupedAdminList(
                children: [
                  for (var index = 0; index < docs.length; index++)
                    _UserCard(
                      doc: docs[index],
                      isLast: index == docs.length - 1,
                      onTap: onOpen,
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

  bool _matches(Map<String, dynamic> data) {
    if ((data['role'] ?? '').toString().toLowerCase() == 'admin') {
      return false;
    }
    final status = _moderationStatus(data);
    if (filter == 'active' && status != 'active' && status != 'warned') {
      return false;
    }
    if (filter != 'all' && filter != 'active' && status != filter) return false;
    if (search.trim().isEmpty) return true;
    final haystack = [
      data['fullName'],
      data['userName'],
      data['username'],
      data['email'],
      data['locationName'],
    ].join(' ').toLowerCase();
    return haystack.contains(search.trim().toLowerCase());
  }
}

class _ActivityTab extends StatelessWidget {
  const _ActivityTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('adminActivity')
          .orderBy('createdAt', descending: true)
          .limit(80)
          .snapshots(),
      builder: (context, snapshot) {
        final docs =
            snapshot.data?.docs ??
            const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          children: [
            const _PageIntro(
              title: 'Activity Log',
              subtitle: 'Every action by the admin team.',
            ),
            const SizedBox(height: 16),
            if (snapshot.hasError)
              const _EmptyState(
                icon: Icons.cloud_off,
                title: 'Unable to load activity',
                message: 'Please check Firestore rules or your connection.',
              )
            else if (docs.isEmpty)
              const _EmptyState(
                icon: Icons.history,
                title: 'No admin activity yet',
                message: 'Moderation decisions will be recorded here.',
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFF2DDE3)),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Column(
                    children: docs
                        .map((doc) => _ActivityCard(data: doc.data()))
                        .toList(),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ReportDetailSheet extends StatefulWidget {
  final String reportId;
  final Map<String, dynamic> data;

  const _ReportDetailSheet({required this.reportId, required this.data});

  @override
  State<_ReportDetailSheet> createState() => _ReportDetailSheetState();
}

class _ReportDetailSheetState extends State<_ReportDetailSheet> {
  final _internalNote = TextEditingController();
  final _userNote = TextEditingController();
  int _step = 1;
  String _severity = 'minor';
  String _accountAction = 'Warned';
  String _listingAction = 'none';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final targetName = _targetTitle(widget.data);
    _internalNote.text =
        'Reviewed report evidence and account/listing context for $targetName.';
    _userNote.text =
        'The Breedr Team reviewed this report and took action according to our community guidelines.';
  }

  @override
  void dispose() {
    _internalNote.dispose();
    _userNote.dispose();
    super.dispose();
  }

  Future<void> _showProfilePreview() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReportedProfilePreviewSheet(data: widget.data),
    );
  }

  Future<void> _showListingPreview() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReportedListingPreviewSheet(data: widget.data),
    );
  }

  Future<void> _dismiss() async {
    await _resolve(
      status: 'resolved',
      adminAction: 'Dismissed',
      actionKey: 'Dismissed',
      severity: 'none',
      listingAction: 'none',
      defaultUserNote:
          'We reviewed this report and did not find enough evidence of a guideline violation.',
    );
  }

  Future<void> _confirmAction() async {
    if (_accountAction == 'Warned' && _listingAction != 'none') {
      setState(() => _listingAction = 'none');
    }
    await _resolve(
      status: 'resolved',
      adminAction: _actionLabel(_accountAction, _listingAction),
      actionKey: _accountAction,
      severity: _severity,
      listingAction: _listingAction,
      defaultUserNote: _userNote.text.trim(),
    );
  }

  Future<void> _resolve({
    required String status,
    required String adminAction,
    required String actionKey,
    required String severity,
    required String listingAction,
    required String defaultUserNote,
  }) async {
    final effectiveListingAction = actionKey == 'Warned'
        ? 'none'
        : listingAction;
    final userNote = defaultUserNote.trim();
    if (userNote.isEmpty) {
      _showSnack('Please add an explanation before confirming.');
      return;
    }
    final ok = await _confirm(
      context,
      title: '$adminAction?',
      message:
          'This will resolve the anonymous report and record the action in the admin activity log.',
      confirmText: 'Confirm',
    );
    if (!ok || !mounted) return;

    setState(() => _saving = true);
    final admin = UserSessionService.instance.currentUser;
    final data = widget.data;
    final target = Map<String, dynamic>.from(
      data['targetSnapshot'] as Map? ?? const {},
    );
    final type = data['type']?.toString() ?? '';
    final reportedUserId = data['reportedUserId']?.toString() ?? '';
    final targetId = data['targetId']?.toString() ?? '';
    final category =
        (data['reason'] ?? data['category'] ?? 'Account standing review')
            .toString()
            .trim();

    try {
      final batch = FirebaseFirestore.instance.batch();
      final reportRef = FirebaseFirestore.instance
          .collection('reports')
          .doc(widget.reportId);
      final activityRef = FirebaseFirestore.instance
          .collection('adminActivity')
          .doc();
      batch.update(reportRef, {
        'status': status,
        'adminAction': adminAction,
        'actionKey': actionKey,
        'severity': severity,
        'listingAction': effectiveListingAction,
        'internalNote': _internalNote.text.trim(),
        'userNote': userNote,
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': admin?.uid,
        'resolvedByEmail': admin?.email,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (reportedUserId.isNotEmpty && actionKey != 'Dismissed') {
        batch.set(
          FirebaseFirestore.instance.collection('users').doc(reportedUserId),
          {
            'moderationStatus': _statusForAction(actionKey),
            'lastModerationAction': adminAction,
            'lastModerationNote': userNote,
            'lastModerationUserNote': userNote,
            'lastModerationCategory': category,
            'lastModerationSeverity': severity,
            'lastModerationAt': FieldValue.serverTimestamp(),
            'moderationEndsAt': _moderationEndsAtForAction(actionKey),
            'suspensionEndsAt': _moderationEndsAtForAction(actionKey),
            'moderationHistory': FieldValue.arrayUnion([
              _moderationHistoryEntry(
                action: adminAction,
                actionKey: actionKey,
                severity: severity,
                category: category,
                userNote: userNote,
                endsAt: _moderationEndDateForAction(actionKey),
              ),
            ]),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        await _queueUserPetModerationUpdates(
          batch: batch,
          userId: reportedUserId,
          action: actionKey,
          adminId: admin?.uid,
          reason: userNote,
        );
      }
      if (_isListingReportType(type) && targetId.isNotEmpty) {
        final listingActionEndsAt = effectiveListingAction == 'hide'
            ? Timestamp.fromDate(DateTime.now().add(const Duration(days: 3)))
            : null;
        final listingUpdate = switch (effectiveListingAction) {
          'hide' => {
            'adminListingStatus': 'hidden',
            'adminHidden': true,
            'adminHiddenUntil': listingActionEndsAt,
            'adminHiddenAt': FieldValue.serverTimestamp(),
            'adminHiddenBy': admin?.uid,
            'adminHiddenReason': _internalNote.text.trim(),
            'adminSourceReportId': widget.reportId,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          'remove' => {
            'adminListingStatus': 'removed',
            'adminHidden': false,
            'adminHiddenUntil': FieldValue.delete(),
            'adminRemoved': true,
            'adminRemovedAt': FieldValue.serverTimestamp(),
            'adminRemovedBy': admin?.uid,
            'adminRemovedReason': _internalNote.text.trim(),
            'adminSourceReportId': widget.reportId,
            'isActive': false,
            'status': 'removed',
            'adoptionStatus': 'removed',
            'updatedAt': FieldValue.serverTimestamp(),
          },
          _ => <String, dynamic>{},
        };
        if (listingUpdate.isNotEmpty) {
          batch.set(
            FirebaseFirestore.instance.collection('pets').doc(targetId),
            listingUpdate,
            SetOptions(merge: true),
          );
        }
        if (effectiveListingAction != 'none') {
          batch.update(reportRef, {
            'listingActionEndsAt': listingActionEndsAt,
            'listingActionAppliedAt': FieldValue.serverTimestamp(),
          });
        }
      }
      batch.set(activityRef, {
        'type': 'report',
        'reportId': widget.reportId,
        'action': adminAction,
        'actionKey': actionKey,
        'severity': severity,
        'listingAction': effectiveListingAction,
        'status': status,
        'targetId': targetId,
        'targetName': _targetTitle(data),
        'targetType': type,
        'reportedUserId': reportedUserId,
        'reportedUserName': _reportedUserName(data),
        'reporterId': data['reporterId'],
        'reporterName': _reporterNameFromSnapshot(data),
        'reportReason': data['reason'],
        'reason': data['reason'],
        'adminId': admin?.uid,
        'adminEmail': admin?.email,
        'note': userNote,
        'internalNote': _internalNote.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'resolvedAt': FieldValue.serverTimestamp(),
        'targetSnapshot': target,
        'reporterSnapshot': data['reporterSnapshot'],
      });
      await batch.commit();
      if (!mounted) return;
      Navigator.pop(context);
      _showGlobalSnack(context, 'Report resolved and logged.');
    } on FirebaseException catch (error) {
      _showSnack(
        error.code == 'permission-denied'
            ? 'Admin permission is required for this action.'
            : 'Unable to resolve this report right now.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final status = (data['status'] ?? 'pending').toString();
    final resolved = status == 'resolved';
    final type = (data['type'] ?? '').toString();
    final evidence = _evidenceFiles(data);
    final title = resolved
        ? 'Review Report'
        : switch (_step) {
            2 => 'Validate Report',
            3 => 'Select Severity',
            4 => 'Confirm Action',
            _ => 'Review Report',
          };

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
        children: [
          const _SheetHandle(),
          const SizedBox(height: 16),
          _SheetTitle(
            icon: Icons.flag_outlined,
            title: title,
            badge: status,
            onClose: () => Navigator.pop(context),
          ),
          const SizedBox(height: 14),
          if (resolved)
            ..._buildResolvedReport(data, type, evidence)
          else
            ...switch (_step) {
              2 => _buildValidateStep(),
              3 => _buildReportSeverityStep(),
              4 => _buildReportConfirmStep(type),
              _ => _buildReportReviewStep(data, type, evidence),
            },
        ],
      ),
    );
  }

  List<Widget> _buildReportReviewStep(
    Map<String, dynamic> data,
    String type,
    List<Map<String, dynamic>> evidence,
  ) {
    return [
      const _WizardStepHeader(step: 1, total: 4, label: 'Review Report'),
      _TargetCard(data: data),
      const SizedBox(height: 14),
      _DetailSection(
        title: 'Report Details',
        children: [
          _DetailRow(
            label: 'Type',
            value: _isListingReportType(type) ? 'Pet Listing' : 'User Profile',
          ),
          _DetailRow(
            label: 'Category',
            value: data['reason']?.toString() ?? 'Not specified',
          ),
          _DetailRow(
            label: 'Filed',
            value: _formatTimestamp(data['createdAt']),
          ),
          _ReporterDetailRow(data: data),
          _DetailRow(
            label: 'Previous reports',
            value: (data['priorReports'] ?? data['previousReports'] ?? 0)
                .toString(),
          ),
        ],
      ),
      _TextPanel(
        title: "Reporter's Description",
        text: data['detail']?.toString().trim().isNotEmpty == true
            ? data['detail'].toString()
            : 'No additional detail provided.',
      ),
      _EvidencePanel(files: evidence),
      const _AdminInfoPanel(
        icon: Icons.lock_outline,
        title: 'Reporter Privacy',
        body:
            'The reporter’s identity is never shown to the reported user or listing owner.',
      ),
      const SizedBox(height: 6),
      if (_isListingReportType(type))
        _WizardFooter(
          primaryText: 'Review Listing',
          primaryIcon: Icons.pets,
          onPrimary: _showListingPreview,
          secondaryText: 'Continue to Validate',
          secondaryIcon: Icons.arrow_forward,
          onSecondary: () => setState(() => _step = 2),
        )
      else
        _WizardFooter(
          primaryText: 'Review Profile',
          primaryIcon: Icons.person_outline,
          onPrimary: _showProfilePreview,
          secondaryText: 'Continue to Validate',
          secondaryIcon: Icons.arrow_forward,
          onSecondary: () => setState(() => _step = 2),
        ),
    ];
  }

  List<Widget> _buildValidateStep() {
    return [
      const _WizardStepHeader(step: 2, total: 4, label: 'Validate Report'),
      _ChoiceCard(
        icon: Icons.cancel_outlined,
        title: 'Dismiss Report',
        body:
            'Choose this if, after reviewing, the report does not describe an actual violation.',
        onTap: _saving ? null : _dismiss,
      ),
      _ChoiceCard(
        icon: Icons.task_alt,
        title: 'Continue Review',
        body:
            'Choose this if the report is valid and needs a moderation decision.',
        highlighted: true,
        onTap: () => setState(() => _step = 3),
      ),
      const SizedBox(height: 8),
      _BackStepButton(onPressed: () => setState(() => _step = 1)),
    ];
  }

  List<Widget> _buildReportSeverityStep() {
    return [
      const _WizardStepHeader(step: 3, total: 4, label: 'Select Severity'),
      const Text(
        'Pick the category that best matches what you found. The app will suggest an action — you can still change it.',
        style: TextStyle(color: Color(0xFF777777), height: 1.35),
      ),
      const SizedBox(height: 12),
      for (final option in _severityOptions)
        _SeverityChoiceCard(
          option: option,
          selected: _severity == option.key,
          onTap: () => _pickSeverity(option),
        ),
      const SizedBox(height: 8),
      _WizardFooter(
        primaryText: 'Continue to Confirm',
        primaryIcon: Icons.arrow_forward,
        onPrimary: () => setState(() => _step = 4),
        secondaryText: 'Back',
        secondaryIcon: Icons.arrow_back,
        onSecondary: () => setState(() => _step = 2),
      ),
    ];
  }

  List<Widget> _buildReportConfirmStep(String type) {
    return [
      const _WizardStepHeader(step: 4, total: 4, label: 'Confirm Action'),
      _SeveritySummaryCard(option: _selectedSeverityOption),
      _DropdownField(
        label: 'Account Action',
        icon: Icons.gavel,
        value: _accountAction,
        items: const {
          'Warned': 'Send Warning',
          'Suspended7': 'Suspend Account (7 Days)',
          'Suspended30': 'Suspend Account (30 Days)',
          'Banned': 'Permanently Disable Account',
        },
        onChanged: (value) => setState(() {
          _accountAction = value;
          if (value == 'Warned') _listingAction = 'none';
        }),
      ),
      if (_accountAction == 'Warned')
        const _AdminInfoPanel(
          icon: Icons.info_outline,
          title: 'Formal warning only',
          body:
              'This records a formal warning only. The account stays active, no features are restricted, and no listings are hidden or removed.',
        ),
      if (_isListingReportType(type) && _accountAction != 'Warned')
        _DropdownField(
          label: 'Listing Action',
          icon: Icons.pets,
          value: _listingAction,
          items: const {
            'none': 'No listing action',
            'hide': 'Hide Listing (temporary)',
            'remove': 'Remove Listing (permanent)',
          },
          onChanged: (value) => setState(() => _listingAction = value),
        ),
      _TextArea(
        label: 'Internal Admin Note (admins only)',
        helperText: 'Ready-made summary — edit as needed.',
        icon: Icons.lock_outline,
        controller: _internalNote,
      ),
      _TextArea(
        label: 'Explanation to User (they will see this)',
        helperText: 'Ready-made explanation — edit as needed.',
        icon: Icons.chat_bubble_outline,
        controller: _userNote,
      ),
      if (_accountAction != 'Warned' || _listingAction != 'none')
        const _WarningBanner(
          text:
              'This is a high-impact action. Review the notes carefully before confirming.',
        ),
      _WizardFooter(
        primaryText: 'Review & Confirm',
        primaryIcon: Icons.check_circle_outline,
        onPrimary: _saving ? null : _confirmAction,
        secondaryText: 'Back',
        secondaryIcon: Icons.arrow_back,
        onSecondary: () => setState(() => _step = 3),
      ),
    ];
  }

  List<Widget> _buildResolvedReport(
    Map<String, dynamic> data,
    String type,
    List<Map<String, dynamic>> evidence,
  ) {
    final isListing = _isListingReportType(type);
    final action = data['adminAction']?.toString() ?? 'Resolved';
    final userNote = data['userNote']?.toString().trim();
    final internalNote = data['internalNote']?.toString().trim();
    return [
      const _ResolvedStepHeader(),
      _TargetCard(data: data),
      const SizedBox(height: 14),
      _DetailSection(
        title: 'Report Details',
        children: [
          _DetailRow(
            label: 'Category',
            value: data['reason']?.toString() ?? 'Not specified',
          ),
          _DetailRow(
            label: 'Filed',
            value: _formatTimestamp(data['createdAt']),
          ),
          _ReporterDetailRow(data: data),
          _DetailRow(
            label: 'Previous violations',
            value: (data['priorReports'] ?? data['previousReports'] ?? 0)
                .toString(),
          ),
        ],
      ),
      _TextPanel(
        title: "Reporter’s Description",
        text: data['detail']?.toString().trim().isNotEmpty == true
            ? data['detail'].toString()
            : 'No additional detail provided.',
      ),
      if (evidence.isNotEmpty) _EvidencePanel(files: evidence),
      _ResolvedAdminNotePanel(
        moderator: data['resolvedByEmail']?.toString() ?? 'Breedr Team',
        date: _formatTimestamp(data['resolvedAt']),
        note: internalNote?.isNotEmpty == true
            ? internalNote!
            : 'No additional notes recorded.',
      ),
      _ResolvedUserExplanationPanel(
        action: action,
        reason: userNote?.isNotEmpty == true
            ? userNote!
            : 'The Breedr Team reviewed this report and completed the moderation process.',
        effectiveDate: _formatTimestamp(data['resolvedAt']),
      ),
      const _AdminInfoPanel(
        icon: Icons.lock_outline,
        title: 'Reporter Privacy',
        body:
            'The reporter’s identity is never shown to the reported user or listing owner.',
      ),
      const SizedBox(height: 6),
      _WizardFooter(
        primaryText: isListing ? 'Review Listing' : 'Review Profile',
        primaryIcon: isListing ? Icons.pets : Icons.person_outline,
        onPrimary: isListing ? _showListingPreview : _showProfilePreview,
        secondaryText: 'Close',
        secondaryIcon: Icons.close,
        onSecondary: () => Navigator.pop(context),
      ),
    ];
  }

  void _pickSeverity(_SeverityOption option) {
    setState(() {
      _severity = option.key;
      _accountAction = option.action;
      _listingAction = option.listingAction;
    });
  }

  _SeverityOption get _selectedSeverityOption => _severityOptions.firstWhere(
    (option) => option.key == _severity,
    orElse: () => _severityOptions.first,
  );

  // Retained for the legacy moderation workflow.
  // ignore: unused_element
  Future<void> _showActionEditor() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                22,
                16,
                22,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SheetHandle(),
                    const SizedBox(height: 16),
                    const Text(
                      'Confirm Moderation Action',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _DropdownField(
                      label: 'Severity',
                      value: _severity,
                      items: const {
                        'minor': 'Minor - formal warning only',
                        'serious': 'Serious - temporary suspension',
                        'severe': 'Severe - ban or permanent removal',
                      },
                      onChanged: (value) {
                        setSheetState(() {
                          _severity = value;
                          _accountAction = switch (value) {
                            'serious' => 'Suspended7',
                            'severe' => 'Banned',
                            _ => 'Warned',
                          };
                          if (_accountAction == 'Warned') {
                            _listingAction = 'none';
                          }
                        });
                        setState(() {
                          _severity = value;
                          _accountAction = switch (value) {
                            'serious' => 'Suspended7',
                            'severe' => 'Banned',
                            _ => 'Warned',
                          };
                          if (_accountAction == 'Warned') {
                            _listingAction = 'none';
                          }
                        });
                      },
                    ),
                    _DropdownField(
                      label: 'Account Action',
                      value: _accountAction,
                      items: const {
                        'Warned': 'Send Warning',
                        'Suspended7': 'Suspend for 7 days',
                        'Suspended30': 'Suspend for 30 days',
                        'Banned': 'Ban account',
                      },
                      onChanged: (value) {
                        setSheetState(() {
                          _accountAction = value;
                          if (value == 'Warned') _listingAction = 'none';
                        });
                        setState(() {
                          _accountAction = value;
                          if (value == 'Warned') _listingAction = 'none';
                        });
                      },
                    ),
                    if ((widget.data['type'] ?? '') == 'listing' &&
                        _accountAction != 'Warned')
                      _DropdownField(
                        label: 'Listing Action',
                        value: _listingAction,
                        items: const {
                          'none': 'No listing action',
                          'hide': 'Hide listing temporarily',
                          'remove': 'Remove listing permanently',
                        },
                        onChanged: (value) {
                          setSheetState(() => _listingAction = value);
                          setState(() => _listingAction = value);
                        },
                      ),
                    _TextArea(
                      label: 'Internal Admin Note',
                      controller: _internalNote,
                    ),
                    _TextArea(
                      label: 'Explanation to User',
                      controller: _userNote,
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _saving
                          ? null
                          : () {
                              Navigator.pop(context);
                              _confirmAction();
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Review & Confirm'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSnack(String message) => _showGlobalSnack(context, message);
}

class _ReturnDetailSheet extends StatefulWidget {
  final String returnRequestId;
  final Map<String, dynamic> data;

  const _ReturnDetailSheet({required this.returnRequestId, required this.data});

  @override
  State<_ReturnDetailSheet> createState() => _ReturnDetailSheetState();
}

class _ReturnDetailSheetState extends State<_ReturnDetailSheet> {
  final _noteController = TextEditingController();
  int _step = 1;
  String _decision = 'approved';
  bool _saving = false;
  String? _ownerName;
  String? _adopterName;

  Map<String, dynamic> get _displayData {
    final data = Map<String, dynamic>.from(widget.data);
    data['ownerName'] =
        _ownerName ?? _returnOwnerName(data).replaceFirst('Owner: ', '');
    data['adopterName'] = _adopterName ?? _returnAdopterName(data);
    return data;
  }

  @override
  void initState() {
    super.initState();
    _noteController.text =
        'The Breedr Team reviewed the return request and available evidence.';
    _loadParticipantNames();
  }

  Future<void> _loadParticipantNames() async {
    final ownerId = widget.data['ownerId']?.toString().trim() ?? '';
    final adopterId =
        (widget.data['adopterId'] ?? widget.data['filedBy'])
            ?.toString()
            .trim() ??
        '';
    final ids = <String>{ownerId, adopterId}..remove('');
    if (ids.isEmpty) return;

    try {
      final snapshots = await Future.wait(
        ids.map(
          (id) => FirebaseFirestore.instance.collection('users').doc(id).get(),
        ),
      );
      final profiles = <String, Map<String, dynamic>>{
        for (final snapshot in snapshots)
          snapshot.id: snapshot.data() ?? const <String, dynamic>{},
      };
      if (!mounted) return;
      setState(() {
        _ownerName = _profileDisplayName(profiles[ownerId], fallback: 'Owner');
        _adopterName = _profileDisplayName(
          profiles[adopterId],
          fallback: 'Adopter',
        );
      });
    } catch (_) {
      // The generic labels remain visible if a linked profile cannot be read.
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _decide(String decision, {bool skipPrompt = false}) async {
    final approved = decision == 'approved';
    final note = _noteController.text.trim();
    if (note.isEmpty) {
      _showGlobalSnack(context, 'Please add an admin note first.');
      return;
    }
    final hasAdminAccess = await UserSessionService.instance
        .isCurrentUserAdmin();
    if (!mounted) return;
    if (!hasAdminAccess) {
      _showGlobalSnack(
        context,
        'This account is not configured as an admin. Check its role in Firestore.',
      );
      return;
    }
    if (!skipPrompt) {
      final ok = await _confirm(
        context,
        title: approved ? 'Approve Return?' : 'Deny Return?',
        message: approved
            ? 'This records that the return request is valid. The owners should coordinate the physical return outside the app.'
            : 'This records that the adoption continues and the return request was not accepted.',
        confirmText: approved ? 'Approve' : 'Deny',
      );
      if (!ok || !mounted) return;
    }
    setState(() => _saving = true);
    try {
      await AdoptionService.instance.processAdoptionReturnDecision(
        returnRequestId: widget.returnRequestId,
        approved: approved,
        adminNote: note,
      );
      if (!mounted) return;
      Navigator.pop(context);
      _showGlobalSnack(
        context,
        approved ? 'Return approved and logged.' : 'Return denied and logged.',
      );
    } on AdoptionServiceException catch (error) {
      _showGlobalSnack(context, error.message);
    } on FirebaseException catch (error) {
      debugPrint(
        'Unable to save return decision: ${error.code} ${error.message}',
      );
      _showGlobalSnack(
        context,
        error.code == 'permission-denied'
            ? 'Admin permission is required for this action.'
            : 'Unable to save this decision right now.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _displayData;
    final status = (data['adminStatus'] ?? data['status'] ?? 'pending')
        .toString()
        .replaceAll('pendingAdminReview', 'pending');
    final pending = status == 'pending';
    final evidence = _evidenceFiles(data);
    final title = pending
        ? switch (_step) {
            2 => 'Validate Return',
            3 => 'Select Decision',
            4 => 'Confirm Decision',
            _ => 'Return Request',
          }
        : 'Return Decision';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
        children: [
          const _SheetHandle(),
          const SizedBox(height: 16),
          _SheetTitle(
            icon: Icons.assignment_return_outlined,
            title: title,
            badge: status,
            onClose: () => Navigator.pop(context),
          ),
          const SizedBox(height: 14),
          if (!pending)
            ..._buildResolvedReturn(data, status, evidence)
          else
            ...switch (_step) {
              2 => _buildReturnValidateStep(),
              3 => _buildReturnDecisionStep(),
              4 => _buildReturnConfirmStep(),
              _ => _buildReturnReviewStep(data, evidence),
            },
        ],
      ),
    );
  }

  List<Widget> _buildReturnReviewStep(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> evidence,
  ) {
    final category = data['reason']?.toString() ?? 'Not specified';
    final filed = _formatTimestamp(data['createdAt']);
    final evidenceLabel = evidence.length == 1
        ? '1 file'
        : '${evidence.length} files';
    return [
      _PetReturnCard(data: data),
      _ProtectionWindowPanel(data: data),
      const SizedBox(height: 14),
      _SectionCard(
        title: 'Reason',
        icon: Icons.description_outlined,
        child: Column(
          children: [
            _DetailRow(label: 'Category', value: category),
            _DetailRow(label: 'Filed', value: filed),
            _DetailRow(label: 'Evidence attached', value: evidenceLabel),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _TextPanel(
        title: 'Description',
        text: data['description']?.toString().trim().isNotEmpty == true
            ? data['description'].toString()
            : 'No description.',
      ),
      _EvidencePanel(files: evidence),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: _saving ? null : () => _showReturnDecisionSheet(true),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF279D5C),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.check_circle_outline),
        label: const Text(
          'Approve Return',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _saving ? null : () => _showReturnDecisionSheet(false),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.cancel_outlined),
        label: const Text(
          'Deny Return',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    ];
  }

  Future<void> _showReturnDecisionSheet(bool approved) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReturnDecisionConfirmSheet(
        data: _displayData,
        approved: approved,
        noteController: _noteController,
      ),
    );
    if (confirmed == true && mounted) {
      await _decide(approved ? 'approved' : 'denied', skipPrompt: true);
    }
  }

  List<Widget> _buildReturnValidateStep() {
    return [
      const _WizardStepHeader(step: 2, total: 4, label: 'Validate Claim'),
      _ChoiceCard(
        icon: Icons.assignment_turned_in_outlined,
        title: 'Approve Return',
        body:
            'Choose this if the claim is valid and the pet should be returned to the original owner.',
        highlighted: _decision == 'approved',
        onTap: () => setState(() {
          _decision = 'approved';
          _step = 3;
        }),
      ),
      _ChoiceCard(
        icon: Icons.block,
        title: 'Deny Return',
        body:
            'Choose this if the evidence does not support a valid return request and the adoption should continue.',
        highlighted: _decision == 'denied',
        onTap: () => setState(() {
          _decision = 'denied';
          _step = 3;
        }),
      ),
      const SizedBox(height: 8),
      _BackStepButton(onPressed: () => setState(() => _step = 1)),
    ];
  }

  List<Widget> _buildReturnDecisionStep() {
    final approved = _decision == 'approved';
    return [
      const _WizardStepHeader(step: 3, total: 4, label: 'Select Decision'),
      _DecisionSummaryCard(
        icon: approved
            ? Icons.assignment_return_outlined
            : Icons.cancel_outlined,
        title: approved ? 'Approve Return' : 'Deny Return',
        body: approved
            ? 'The app will record the return as valid and notify both parties to coordinate the hand-back.'
            : 'The app will record the return as denied and keep the adoption process active or completed.',
        color: approved ? const Color(0xFF31A852) : AppColors.primary,
      ),
      _TextArea(
        label: 'Admin Decision Note',
        helperText: 'Admins only — explain how you reviewed this claim.',
        icon: Icons.lock_outline,
        controller: _noteController,
      ),
      const SizedBox(height: 6),
      _WizardFooter(
        primaryText: 'Continue to Confirm',
        primaryIcon: Icons.arrow_forward,
        onPrimary: () => setState(() => _step = 4),
        secondaryText: 'Back',
        secondaryIcon: Icons.arrow_back,
        onSecondary: () => setState(() => _step = 2),
      ),
    ];
  }

  List<Widget> _buildReturnConfirmStep() {
    final approved = _decision == 'approved';
    return [
      const _WizardStepHeader(step: 4, total: 4, label: 'Confirm Decision'),
      _DecisionSummaryCard(
        icon: approved
            ? Icons.assignment_return_outlined
            : Icons.cancel_outlined,
        title: approved ? 'Approve Return' : 'Deny Return',
        body: approved
            ? 'This records that the return request is valid. The owners should coordinate the physical return outside the app.'
            : 'This records that the adoption continues and the return request was not accepted.',
        color: approved ? const Color(0xFF31A852) : AppColors.primary,
      ),
      _TextArea(
        label: 'Admin Decision Note',
        helperText: 'Admins only — explain the decision for this return.',
        icon: Icons.lock_outline,
        controller: _noteController,
      ),
      if (approved)
        const _WarningBanner(
          text:
              'Approving does not physically return the pet. Both parties must arrange the hand-back themselves.',
        ),
      _WizardFooter(
        primaryText: 'Review & Confirm',
        primaryIcon: Icons.check_circle_outline,
        onPrimary: _saving ? null : () => _decide(_decision),
        secondaryText: 'Back',
        secondaryIcon: Icons.arrow_back,
        onSecondary: () => setState(() => _step = 3),
      ),
    ];
  }

  List<Widget> _buildResolvedReturn(
    Map<String, dynamic> data,
    String status,
    List<Map<String, dynamic>> evidence,
  ) {
    return [
      const _WizardStepHeader(step: 4, total: 4, label: 'Completed'),
      _PetReturnCard(data: data),
      _DetailSection(
        title: 'Final Decision',
        children: [
          _DetailRow(label: 'Status', value: status),
          _DetailRow(
            label: 'Resolved',
            value: _formatTimestamp(data['resolvedAt']),
          ),
          _DetailRow(label: 'Evidence', value: '${evidence.length} file(s)'),
        ],
      ),
      _EvidencePanel(files: evidence),
      _TextPanel(
        title: 'Final Admin Decision',
        text: data['adminNote']?.toString() ?? 'No admin note.',
      ),
      const SizedBox(height: 6),
      _WizardFooter(
        primaryText: 'Close',
        primaryIcon: Icons.close,
        onPrimary: () => Navigator.pop(context),
      ),
    ];
  }
}

class _UserDetailSheet extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> data;

  const _UserDetailSheet({required this.userId, required this.data});

  @override
  State<_UserDetailSheet> createState() => _UserDetailSheetState();
}

class _UserDetailSheetState extends State<_UserDetailSheet> {
  final _noteController = TextEditingController();
  final _userNoteController = TextEditingController();
  int _step = 1;
  String _severity = 'minor';
  String _action = 'Warned';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _noteController.text =
        'The Breedr Team reviewed your account activity and community standing.';
    _userNoteController.text =
        'The Breedr Team completed a review of your account activity and history.';
  }

  @override
  void dispose() {
    _noteController.dispose();
    _userNoteController.dispose();
    super.dispose();
  }

  Future<void> _applyAction(String action) async {
    final note = _noteController.text.trim();
    final userNote = _userNoteController.text.trim();
    if (note.isEmpty) {
      _showGlobalSnack(context, 'Please add a note before confirming.');
      return;
    }
    if (userNote.isEmpty) {
      _showGlobalSnack(context, 'Please add the explanation users will see.');
      return;
    }
    final label = _actionLabel(action, 'none');
    if (!mounted) return;
    final bool ok;
    if (_requiresRestrictionConfirmation(action)) {
      ok = await _showAccountRestrictionConfirmation(
        context: context,
        action: action,
        userName: _name(widget.data),
        userExplanation: userNote,
      );
    } else {
      ok = await _confirm(
        context,
        title: '$label?',
        message:
            'This will update the user moderation status and log the action.',
        confirmText: 'Confirm',
      );
    }
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    final admin = UserSessionService.instance.currentUser;
    final category =
        (widget.data['lastModerationCategory'] ??
                widget.data['reportCategory'] ??
                'Account standing review')
            .toString()
            .trim();
    final severity = _severityForAction(action);
    try {
      final batch = FirebaseFirestore.instance.batch();
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId);
      batch.set(userRef, {
        'moderationStatus': _statusForAction(action),
        'lastModerationAction': label,
        'lastModerationNote': note,
        'lastModerationUserNote': userNote,
        'lastModerationCategory': category,
        'lastModerationSeverity': severity,
        'lastModerationAt': FieldValue.serverTimestamp(),
        'moderationEndsAt': _moderationEndsAtForAction(action),
        'suspensionEndsAt': _moderationEndsAtForAction(action),
        'moderationHistory': FieldValue.arrayUnion([
          _moderationHistoryEntry(
            action: label,
            actionKey: action,
            severity: severity,
            category: category,
            userNote: userNote,
            endsAt: _moderationEndDateForAction(action),
          ),
        ]),
        if (action == 'Restored') 'lastModerationSeenAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _queueUserPetModerationUpdates(
        batch: batch,
        userId: widget.userId,
        action: action,
        adminId: admin?.uid,
        reason: userNote,
      );
      batch.set(FirebaseFirestore.instance.collection('adminActivity').doc(), {
        'type': 'account',
        'action': label,
        'targetId': widget.userId,
        'targetName': _name(widget.data),
        'adminId': admin?.uid,
        'adminEmail': admin?.email,
        'note': note,
        'userNote': userNote,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      if (!mounted) return;
      Navigator.pop(context);
      _showGlobalSnack(context, 'Account action logged.');
    } on FirebaseException catch (error) {
      _showGlobalSnack(
        context,
        error.code == 'permission-denied'
            ? 'Admin permission is required for this action.'
            : 'Unable to update this account right now.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final status = _moderationStatus(data);
    final title = switch (_step) {
      2 => 'Validate Account',
      3 => 'Select Severity',
      4 => 'Confirm Action',
      _ => 'Account Detail',
    };
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.48,
      maxChildSize: 0.96,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
        children: [
          const _SheetHandle(),
          const SizedBox(height: 16),
          _SheetTitle(
            icon: Icons.manage_accounts_outlined,
            title: title,
            badge: status,
            onClose: () => Navigator.pop(context),
          ),
          const SizedBox(height: 14),
          ...switch (_step) {
            2 => _buildAccountValidateStep(),
            3 => _buildAccountSeverityStep(),
            4 => _buildAccountConfirmStep(),
            _ => _buildAccountReviewStep(data, status),
          },
        ],
      ),
    );
  }

  List<Widget> _buildAccountReviewStep(
    Map<String, dynamic> data,
    String status,
  ) {
    return [
      const _WizardStepHeader(step: 1, total: 4, label: 'Review Account'),
      _UserHeader(userId: widget.userId, data: data),
      _DetailSection(
        title: 'Status',
        children: [
          _DetailRow(label: 'Current status', value: status),
          _DetailRow(
            label: 'Email',
            value: data['email']?.toString() ?? 'No email',
          ),
          _DetailRow(
            label: 'Location',
            value: data['locationName']?.toString() ?? 'Not set',
          ),
          _DetailRow(
            label: 'Joined',
            value: _formatTimestamp(data['createdAt']),
          ),
          _DetailRow(
            label: 'Reports received',
            value: (data['reportCount'] ?? data['reportsCount'] ?? 0)
                .toString(),
          ),
          _DetailRow(
            label: 'Reports filed',
            value: (data['reportsFiled'] ?? data['reportsFiledCount'] ?? 0)
                .toString(),
          ),
          _DetailRow(
            label: 'Active listings',
            value: (data['activeListings'] ?? data['activeListingCount'] ?? 0)
                .toString(),
          ),
        ],
      ),
      const _AdminInfoPanel(
        icon: Icons.flag_outlined,
        title: 'Previous Violations',
        body:
            'Review the account status and report history before choosing a moderation action.',
      ),
      if (_canRestoreAccount(status)) ...[
        const SizedBox(height: 8),
        _ChoiceCard(
          icon: Icons.lock_open_outlined,
          title: 'Lift Restriction',
          body:
              'Temporary testing action: restore this account to active and clear suspension or ban timers.',
          highlighted: true,
          onTap: _prepareRestoreAction,
        ),
      ],
      const SizedBox(height: 6),
      _WizardFooter(
        primaryText: 'Take Moderation Action',
        primaryIcon: Icons.gavel,
        onPrimary: () => setState(() => _step = 2),
        secondaryText: 'Close',
        secondaryIcon: Icons.close,
        onSecondary: () => Navigator.pop(context),
      ),
    ];
  }

  List<Widget> _buildAccountValidateStep() {
    return [
      const _WizardStepHeader(step: 2, total: 4, label: 'Validate Account'),
      _ChoiceCard(
        icon: Icons.check_circle_outline,
        title: 'No Action Needed',
        body:
            'Choose this if the account does not need a moderation restriction right now.',
        onTap: () {
          Navigator.pop(context);
          _showGlobalSnack(context, 'No account action was taken.');
        },
      ),
      _ChoiceCard(
        icon: Icons.gavel,
        title: 'Continue Review',
        body:
            'Choose this if the account needs a warning, suspension, or permanent restriction.',
        highlighted: true,
        onTap: () => setState(() => _step = 3),
      ),
      const SizedBox(height: 8),
      _BackStepButton(onPressed: () => setState(() => _step = 1)),
    ];
  }

  List<Widget> _buildAccountSeverityStep() {
    return [
      const _WizardStepHeader(step: 3, total: 4, label: 'Select Severity'),
      const Text(
        'Pick the account severity so Breedr can suggest the right moderation action.',
        style: TextStyle(color: Color(0xFF777777), height: 1.35),
      ),
      const SizedBox(height: 12),
      for (final option in _severityOptions)
        _SeverityChoiceCard(
          option: option,
          selected: _severity == option.key,
          onTap: () => _pickSeverity(option),
        ),
      const SizedBox(height: 8),
      _WizardFooter(
        primaryText: 'Continue to Confirm',
        primaryIcon: Icons.arrow_forward,
        onPrimary: () => setState(() => _step = 4),
        secondaryText: 'Back',
        secondaryIcon: Icons.arrow_back,
        onSecondary: () => setState(() => _step = 2),
      ),
    ];
  }

  List<Widget> _buildAccountConfirmStep() {
    return [
      const _WizardStepHeader(step: 4, total: 4, label: 'Confirm Action'),
      if (_action == 'Restored')
        const _AdminInfoPanel(
          icon: Icons.lock_open_outlined,
          title: 'Restore Account',
          body:
              'This will lift the current warning, suspension, or ban and let the user access Breedr again.',
        )
      else
        _SeveritySummaryCard(option: _selectedSeverityOption),
      _DropdownField(
        label: 'Account Action',
        icon: Icons.gavel,
        value: _action,
        items: const {
          'Restored': 'Lift Restriction / Restore Account',
          'Warned': 'Send Warning',
          'Suspended7': 'Suspend Account (7 Days)',
          'Suspended30': 'Suspend Account (30 Days)',
          'Banned': 'Permanently Disable Account',
        },
        onChanged: (value) => setState(() => _action = value),
      ),
      if (_action == 'Warned')
        const _AdminInfoPanel(
          icon: Icons.info_outline,
          title: 'Formal Warning Only',
          body:
              'The warning will be recorded, but the account remains active. No features are restricted and no listings are hidden or removed.',
        ),
      _TextArea(
        label: 'Internal Admin Note (admins only)',
        helperText: 'Ready-made summary — edit as needed.',
        icon: Icons.lock_outline,
        controller: _noteController,
      ),
      _TextArea(
        label: 'Explanation to User (they will see this)',
        helperText: 'Ready-made explanation — edit as needed.',
        icon: Icons.chat_bubble_outline,
        controller: _userNoteController,
      ),
      if (_action != 'Warned' && _action != 'Restored')
        const _WarningBanner(
          text:
              'This will restrict the user account. Confirm only after reviewing the account history.',
        ),
      _WizardFooter(
        primaryText: 'Review & Confirm',
        primaryIcon: Icons.check_circle_outline,
        onPrimary: _saving ? null : () => _applyAction(_action),
        secondaryText: 'Back',
        secondaryIcon: Icons.arrow_back,
        onSecondary: () => setState(() => _step = 3),
      ),
    ];
  }

  void _pickSeverity(_SeverityOption option) {
    setState(() {
      _severity = option.key;
      _action = option.action;
    });
  }

  void _prepareRestoreAction() {
    setState(() {
      _severity = 'minor';
      _action = 'Restored';
      _noteController.text =
          'The Breedr Team lifted this account restriction after review.';
      _userNoteController.text =
          'Your account restriction has been lifted. You can use Breedr again.';
      _step = 4;
    });
  }

  _SeverityOption get _selectedSeverityOption => _severityOptions.firstWhere(
    (option) => option.key == _severity,
    orElse: () => _severityOptions.first,
  );
}

class _TopBar extends StatelessWidget {
  final String email;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  const _TopBar({
    required this.email,
    required this.onNotifications,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2F7),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.pets, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Breedr Team',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                Text(
                  'Admin console',
                  style: TextStyle(color: Color(0xFF888888), fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onNotifications,
            icon: const Icon(Icons.notifications_outlined),
            color: AppColors.primary,
          ),
          GestureDetector(
            onTap: onProfile,
            child: const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFFFFDCE5),
              child: Icon(
                Icons.admin_panel_settings,
                color: AppColors.primary,
                size: 19,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminBottomNav extends StatelessWidget {
  final _AdminTab selected;
  final ValueChanged<_AdminTab> onSelected;

  const _AdminBottomNav({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          _NavItem(
            tab: _AdminTab.dashboard,
            selected: selected,
            icon: Icons.dashboard_outlined,
            label: 'Home',
            onSelected: onSelected,
          ),
          _NavItem(
            tab: _AdminTab.reports,
            selected: selected,
            icon: Icons.flag_outlined,
            label: 'Reports',
            onSelected: onSelected,
          ),
          _NavItem(
            tab: _AdminTab.returns,
            selected: selected,
            icon: Icons.assignment_return_outlined,
            label: 'Returns',
            onSelected: onSelected,
          ),
          _NavItem(
            tab: _AdminTab.accounts,
            selected: selected,
            icon: Icons.manage_accounts_outlined,
            label: 'Users',
            onSelected: onSelected,
          ),
          _NavItem(
            tab: _AdminTab.activity,
            selected: selected,
            icon: Icons.history,
            label: 'Activity',
            onSelected: onSelected,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final _AdminTab tab;
  final _AdminTab selected;
  final IconData icon;
  final String label;
  final ValueChanged<_AdminTab> onSelected;

  const _NavItem({
    required this.tab,
    required this.selected,
    required this.icon,
    required this.label,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final active = tab == selected;
    return Expanded(
      child: InkWell(
        onTap: () => onSelected(tab),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: active ? AppColors.primary : Colors.black54),
              Text(
                label,
                style: TextStyle(
                  color: active ? AppColors.primary : const Color(0xFF777777),
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool isLast;
  final ValueChanged<QueryDocumentSnapshot<Map<String, dynamic>>> onTap;

  const _ReportCard({
    required this.doc,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final evidenceCount = _evidenceFiles(data).length;
    return FutureBuilder<String>(
      future: _reporterName(data),
      builder: (context, snapshot) {
        final reporter = snapshot.data ?? _reporterNameFromSnapshot(data);
        return _AdminListRow(
          icon: _reportIcon(data),
          overline: _reportTypeLabel(data),
          title: '${_targetTitle(data)} — "${data['reason'] ?? 'Report'}"',
          subtitle: _reportSubtitle(data, reporter),
          badge: data['status']?.toString() ?? 'pending',
          meta: '${_reportTypeLabel(data)} • $evidenceCount evidence',
          trailingMeta: _relativeTimestamp(data['createdAt']),
          isLast: isLast,
          onTap: () => onTap(doc),
        );
      },
    );
  }
}

class _ReturnCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool isLast;
  final ValueChanged<QueryDocumentSnapshot<Map<String, dynamic>>> onTap;

  const _ReturnCard({
    required this.doc,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final evidenceCount = _evidenceFiles(data).length;
    return FutureBuilder<_ReturnParticipantNames>(
      future: _resolveReturnParticipantNames(data),
      builder: (context, snapshot) {
        final names = snapshot.data;
        final adopter = names?.adopter ?? _returnAdopterName(data);
        final owner =
            names?.owner ?? _returnOwnerName(data).replaceFirst('Owner: ', '');
        return _AdminListRow(
          icon: Icons.pets,
          overline: 'ADOPTION RETURN DISPUTE',
          title:
              '${data['petName']?.toString() ?? 'Adoption Return'} — "${data['reason'] ?? 'Return request'}"',
          subtitle: 'Adopter: $adopter • Owner: $owner',
          badge: (data['adminStatus'] ?? data['status'] ?? 'pending')
              .toString()
              .replaceAll('pendingAdminReview', 'pending'),
          meta: evidenceCount == 1
              ? '1 evidence file'
              : '$evidenceCount evidence files',
          trailingMeta: _relativeTimestamp(data['createdAt']),
          isLast: isLast,
          onTap: () => onTap(doc),
        );
      },
    );
  }
}

class _UserCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool isLast;
  final ValueChanged<QueryDocumentSnapshot<Map<String, dynamic>>> onTap;

  const _UserCard({
    required this.doc,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final reportCount = data['reportCount'] is num
        ? (data['reportCount'] as num).toInt()
        : data['reportsCount'] is num
        ? (data['reportsCount'] as num).toInt()
        : 0;
    return _AccountListRow(
      initials: _initials(_name(data)),
      title: _name(data),
      subtitle:
          '@${data['userName'] ?? data['username'] ?? 'user'} · ${_memberMonth(data)}',
      reportLabel: '$reportCount ${reportCount == 1 ? 'rpt' : 'rpts'}',
      badge: _moderationStatus(data),
      isLast: isLast,
      onTap: () => onTap(doc),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _ActivityCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final icon = _adminActivityIcon(data);
    final title =
        '${data['action']?.toString() ?? 'Admin action'} — ${data['targetName'] ?? 'Target'}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF2DDE3))),
        ),
        child: Row(
          children: [
            _IconBubble(icon: icon, size: 50),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF171022),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data['note']?.toString() ?? 'Admin action recorded.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF8E7F91),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _DatePill(label: _formatShortDate(data['createdAt'])),
          ],
        ),
      ),
    );
  }
}

class _AdminNotificationItem {
  final IconData icon;
  final String category;
  final String title;
  final dynamic createdAt;
  final Future<void> Function() onOpen;

  const _AdminNotificationItem({
    required this.icon,
    required this.category,
    required this.title,
    required this.createdAt,
    required this.onOpen,
  });
}

class _AdminNotificationsSheet extends StatelessWidget {
  final List<_AdminNotificationItem> items;

  const _AdminNotificationsSheet({required this.items});

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.9;
    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            const SizedBox(height: 12),
            const _SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 14, 18),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        color: Color(0xFF171022),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF2DDE3)),
            Expanded(
              child: items.isEmpty
                  ? const _EmptyState(
                      icon: Icons.notifications_none,
                      title: 'No admin notifications',
                      message:
                          'New reports and return requests will appear here.',
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFF2DDE3)),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            children: [
                              for (var index = 0; index < items.length; index++)
                                _AdminNotificationRow(
                                  item: items[index],
                                  isLast: index == items.length - 1,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF2DDE3))),
              ),
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: const Color(0xFF8E7F91),
                  side: const BorderSide(color: Color(0xFFF2DDE3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Close',
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

class _AdminNotificationRow extends StatelessWidget {
  final _AdminNotificationItem item;
  final bool isLast;

  const _AdminNotificationRow({required this.item, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        WidgetsBinding.instance.addPostFrameCallback((_) => item.onOpen());
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: Color(0xFFF2DDE3))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IconBubble(icon: item.icon, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.category,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF171022),
                      fontSize: 16,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _relativeTimestamp(item.createdAt),
                    style: const TextStyle(
                      color: Color(0xFF8E7F91),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF8E7F91)),
          ],
        ),
      ),
    );
  }
}

class _GroupedAdminList extends StatelessWidget {
  final List<Widget> children;

  const _GroupedAdminList({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF2DDE3)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(children: children),
      ),
    );
  }
}

class _AdminListRow extends StatelessWidget {
  final IconData icon;
  final String overline;
  final String title;
  final String subtitle;
  final String badge;
  final String meta;
  final String trailingMeta;
  final bool isLast;
  final VoidCallback onTap;

  const _AdminListRow({
    required this.icon,
    required this.overline,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.meta,
    required this.trailingMeta,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : const Border(bottom: BorderSide(color: Color(0xFFF2DDE3))),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBubble(icon: icon, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      overline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF9A8F96),
                        fontSize: 11,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF171022),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF8E7F91),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          trailingMeta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF8E7F91),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _Badge(label: badge),
                      ],
                    ),
                    if (meta.trim().isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF9A8F96),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountListRow extends StatelessWidget {
  final String initials;
  final String title;
  final String subtitle;
  final String reportLabel;
  final String badge;
  final bool isLast;
  final VoidCallback onTap;

  const _AccountListRow({
    required this.initials,
    required this.title,
    required this.subtitle,
    required this.reportLabel,
    required this.badge,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : const Border(bottom: BorderSide(color: Color(0xFFF2DDE3))),
          ),
          child: Row(
            children: [
              _InitialBubble(initials: initials),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF171022),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8E7F91),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _CountPill(label: reportLabel),
                  const SizedBox(height: 7),
                  _Badge(label: badge),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  final String label;

  const _DatePill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEF2),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.access_time, color: Color(0xFF8E7F91), size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8E7F91),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardPreview extends StatelessWidget {
  final String title;
  final IconData icon;
  final String collection;
  final String pendingField;
  final String pendingValue;
  final String emptyText;
  final VoidCallback onViewAll;

  const _DashboardPreview({
    required this.title,
    required this.icon,
    required this.collection,
    required this.pendingField,
    required this.pendingValue,
    required this.emptyText,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection(collection).snapshots(),
      builder: (context, snapshot) {
        final docs =
            (snapshot.data?.docs ??
                    const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                .where((doc) {
                  final value = doc.data()[pendingField];
                  return value == pendingValue ||
                      (pendingField == 'adminStatus' &&
                          doc.data()['status'] == 'pendingAdminReview');
                })
                .take(3)
                .toList();
        return _SectionCard(
          title: title,
          icon: icon,
          trailing: TextButton(
            onPressed: onViewAll,
            child: const Text('View all'),
          ),
          child: docs.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    emptyText,
                    style: const TextStyle(color: Color(0xFF777777)),
                  ),
                )
              : Column(
                  children: docs.map((doc) {
                    final data = doc.data();
                    if (collection == 'reports') {
                      return _DashboardReportPreviewRow(data: data);
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          _IconBubble(icon: icon, size: 34),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              data['petName']?.toString() ?? 'Return request',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          _Badge(
                            label:
                                data[pendingField]?.toString() ??
                                data['status']?.toString() ??
                                'pending',
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        );
      },
    );
  }
}

class _DashboardReportPreviewRow extends StatelessWidget {
  final Map<String, dynamic> data;

  const _DashboardReportPreviewRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _reporterName(data),
      builder: (context, snapshot) {
        final reporter = snapshot.data ?? _reporterNameFromSnapshot(data);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBubble(icon: _reportIcon(data), size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _reportTypeLabel(data),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF9A8F96),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_targetTitle(data)} - "${data['reason'] ?? 'Report'}"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Reported by $reporter',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF777777),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Badge(label: data['status']?.toString() ?? 'pending'),
            ],
          ),
        );
      },
    );
  }
}

class _EvidencePanel extends StatelessWidget {
  final List<Map<String, dynamic>> files;

  const _EvidencePanel({required this.files});

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return const _AdminInfoPanel(
        icon: Icons.attach_file,
        title: 'Evidence',
        body: 'No evidence files were attached.',
      );
    }
    return _SectionCard(
      title: 'Evidence',
      icon: Icons.attach_file,
      child: Column(
        children: files
            .map(
              (file) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => _openEvidence(context, file),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7FA),
                      border: Border.all(color: const Color(0xFFFFCAD5)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _evidenceIcon(file['fileType']?.toString()),
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                file['fileName']?.toString() ??
                                    file['url']?.toString() ??
                                    'Evidence file',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                '${file['fileType'] ?? 'file'} • ${_formatBytes(file['sizeBytes'])}',
                                style: const TextStyle(
                                  color: Color(0xFF777777),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.open_in_new, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _openEvidence(
    BuildContext context,
    Map<String, dynamic> file,
  ) async {
    final url = file['url']?.toString() ?? '';
    if (url.isEmpty) {
      _showGlobalSnack(context, 'This evidence file has no URL.');
      return;
    }
    final fileType = file['fileType']?.toString().trim().isNotEmpty == true
        ? file['fileType'].toString()
        : _guessFileType(url);
    if (fileType == 'image') {
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton.filled(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ),
                Flexible(
                  child: InteractiveViewer(
                    child: BreedrNetworkImage(
                      imageUrl: url,
                      width: double.infinity,
                      height: 430,
                      fit: BoxFit.contain,
                      backgroundColor: Colors.black,
                      fallback: const SizedBox(
                        height: 360,
                        child: Center(
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.white,
                            size: 42,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _copyEvidenceUrl(context, url),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                          ),
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy URL'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _launchEvidenceUrl(context, url),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Open'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_evidenceDialogTitle(fileType)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_evidenceIcon(fileType), color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    file['fileName']?.toString() ?? 'Evidence file',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              fileType == 'pdf'
                  ? 'Open this PDF in your browser or PDF viewer. If your emulator cannot open PDFs directly, copy the URL and test it in Chrome.'
                  : 'Open this video in your browser or video player. If playback does not start inside the emulator, copy the URL and open it in Chrome.',
              style: const TextStyle(color: Color(0xFF666666)),
            ),
            const SizedBox(height: 12),
            SelectableText(
              url,
              style: const TextStyle(fontSize: 12, color: Color(0xFF777777)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton.icon(
            onPressed: () => _copyEvidenceUrl(context, url),
            icon: const Icon(Icons.copy),
            label: const Text('Copy URL'),
          ),
          FilledButton.icon(
            onPressed: () => _launchEvidenceUrl(context, url),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyEvidenceUrl(BuildContext context, String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      _showGlobalSnack(context, 'Evidence URL copied.');
    }
  }

  Future<void> _launchEvidenceUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      _showGlobalSnack(context, 'This evidence URL is not valid.');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      _showGlobalSnack(
        context,
        'Unable to open this file. URL copied instead.',
      );
      await Clipboard.setData(ClipboardData(text: url));
    }
  }
}

class _TargetCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _TargetCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final target = Map<String, dynamic>.from(
      data['targetSnapshot'] as Map? ?? const {},
    );
    final isListing = _isListingReportType(data['type']?.toString() ?? '');
    final title = _targetTitle(data);
    final photo = isListing ? _petPhoto(target) : _profilePhoto(target);
    final handle = _firstText([
      target['userName'],
      target['username'],
      target['handle'],
      target['email'],
    ], fallback: '@breedr_user');
    final status = _moderationStatus(target);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEF3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCAD5)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            child: ClipOval(
              child: photo.isEmpty && !isListing
                  ? Center(
                      child: Text(
                        _initials(title),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    )
                  : BreedrNetworkImage(
                      imageUrl: photo,
                      width: 56,
                      height: 56,
                      fallback: Icon(
                        isListing ? Icons.pets : Icons.person_outline,
                        color: AppColors.primary,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                if (isListing)
                  Text(
                    '${target['species'] ?? 'Pet'} • ${target['breed'] ?? 'Breed not set'}',
                    style: const TextStyle(color: Color(0xFF777777)),
                  )
                else ...[
                  Text(
                    handle,
                    style: const TextStyle(color: Color(0xFF777777)),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE4F7EB),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                          color: Color(0xFF279D5C),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PetReturnCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _PetReturnCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final petSnapshot = data['petSnapshot'];
    final petData = petSnapshot is Map
        ? Map<String, dynamic>.from(petSnapshot)
        : <String, dynamic>{};
    final petName = _firstText([
      data['petName'],
      petData['name'],
      petData['petName'],
    ], fallback: 'Adopted pet');
    final photo = _firstText([
      data['petPhoto'],
      data['petProfilePhoto'],
      petData['petProfilePhoto'],
      petData['profilePhoto'],
    ], fallback: '');
    final owner = _returnOwnerName(data);
    final adopter = _returnAdopterName(data);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEF3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCAD5)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BreedrNetworkImage(
              imageUrl: photo,
              width: 64,
              height: 64,
              fallback: const ColoredBox(
                color: Colors.white,
                child: Center(
                  child: Icon(Icons.pets, color: AppColors.primary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  petName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 3),
                Text(owner, style: const TextStyle(color: Color(0xFF777777))),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 16,
                      color: Color(0xFF8E7F91),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Adopter: $adopter',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF8E7F91),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportedProfilePreviewSheet extends StatelessWidget {
  final Map<String, dynamic> data;

  const _ReportedProfilePreviewSheet({required this.data});

  Future<Map<String, dynamic>> _loadProfile() async {
    final snapshotTarget = Map<String, dynamic>.from(
      data['targetSnapshot'] as Map? ?? const {},
    );
    final userId = _firstText([
      data['reportedUserId'],
      data['targetId'],
      data['userId'],
      snapshotTarget['id'],
      snapshotTarget['userId'],
      snapshotTarget['uid'],
    ], fallback: '');
    if (userId.isEmpty) return snapshotTarget;

    var profile = snapshotTarget;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final liveData = snapshot.data();
      if (liveData != null) {
        profile = {...profile, ...liveData, 'id': snapshot.id};
      }
    } catch (_) {
      // Use the report snapshot when the live account cannot be loaded.
    }

    try {
      final pets = await FirebaseFirestore.instance
          .collection('pets')
          .where('ownerId', isEqualTo: userId)
          .get();
      final activeCount = pets.docs.where((doc) {
        final pet = doc.data();
        final status = pet['status']?.toString().toLowerCase() ?? '';
        final isActive = pet['isActive'] != false;
        final hidden =
            pet['adminHidden'] == true || pet['adminRemoved'] == true;
        final removed =
            status == 'removed' ||
            status == 'adopted' ||
            status == 'matched' ||
            status == 'inactive';
        return isActive && !hidden && !removed;
      }).length;
      return {...profile, 'activeListings': activeCount};
    } catch (_) {
      return profile;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadProfile(),
      builder: (context, snapshot) {
        final target =
            snapshot.data ??
            Map<String, dynamic>.from(
              data['targetSnapshot'] as Map? ?? const {},
            );
        return _buildContent(target, snapshot.connectionState);
      },
    );
  }

  Widget _buildContent(Map<String, dynamic> target, ConnectionState state) {
    final mergedReport = {
      ...data,
      'targetSnapshot': target,
      if (_firstText([data['reportedUserName']], fallback: '').isEmpty)
        'reportedUserName': _name(target),
    };
    final name = _targetTitle(mergedReport);
    final handleText = _firstText([
      target['userName'],
      target['username'],
      target['handle'],
      target['email'],
    ], fallback: 'breedr_user');
    final handle = handleText.startsWith('@') ? handleText : '@$handleText';
    final photo = _profilePhoto(target);
    final reports = (data['priorReports'] ?? data['previousReports'] ?? 1)
        .toString();
    final listings = _firstText([
      target['activeListings'],
      target['activeListingCount'],
      target['petsListed'],
      target['petsCount'],
      target['listedPetsCount'],
    ], fallback: '0');
    final homeType = _homeTypeText(target);
    final kids = _yesNo(
      target['childrenAtHome'] ??
          target['hasKids'] ??
          target['kidsAtHome'] ??
          _nestedMap(target, 'homeInformation')['kidsAtHome'],
    );
    final petsAtHome = _yesNo(
      target['otherPetsAtHome'] ??
          target['hasPets'] ??
          target['petsAtHome'] ??
          _nestedMap(target, 'homeInformation')['petsAtHome'],
    );
    final ownerRating = _ratingText(
      target['ownerRating'] ??
          target['breederRating'] ??
          target['petOwnerRating'] ??
          target['averageOwnerRating'],
    );
    final adopterRating = _ratingText(
      target['adopterRating'] ??
          target['adoptionRating'] ??
          target['averageAdopterRating'],
    );

    return _PreviewSheetScaffold(
      title: 'Profile Detail',
      icon: Icons.person_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state == ConnectionState.waiting)
            const LinearProgressIndicator(
              minHeight: 3,
              color: AppColors.primary,
              backgroundColor: Color(0xFFFFDCE5),
            ),
          if (state == ConnectionState.waiting) const SizedBox(height: 12),
          _PreviewIdentityCard(
            photoUrl: photo,
            fallbackText: _initials(name),
            title: name,
            subtitle: '$handle · joined ${_memberMonth(target)}',
          ),
          const SizedBox(height: 14),
          _PreviewStatGrid(
            children: [
              _PreviewMetricTile(label: 'HOME TYPE', value: homeType),
              _PreviewMetricTile(label: 'KIDS AT HOME', value: kids),
              _PreviewMetricTile(
                label: 'OWNER RATING',
                value: ownerRating,
                leading: ownerRating == '—'
                    ? null
                    : const Icon(
                        Icons.star,
                        size: 18,
                        color: Color(0xFFFFC72C),
                      ),
              ),
              _PreviewMetricTile(
                label: 'ADOPTER RATING',
                value: adopterRating,
                leading: adopterRating == '—'
                    ? null
                    : const Icon(
                        Icons.star,
                        size: 18,
                        color: Color(0xFFFFC72C),
                      ),
              ),
              _PreviewMetricTile(label: 'PETS AT HOME', value: petsAtHome),
            ],
          ),
          const SizedBox(height: 18),
          const _PreviewSectionTitle(
            icon: Icons.bar_chart,
            title: 'ACCOUNT ACTIVITY',
          ),
          _InlineValueRow(label: 'Reports received', value: reports),
          _InlineValueRow(label: 'Active listings', value: listings),
          const SizedBox(height: 18),
          const _PreviewSectionTitle(
            icon: Icons.flag_outlined,
            title: 'REPORT HISTORY',
          ),
          _InlineValueRow(
            label:
                '${_formatTimestamp(data['createdAt'])} · ${data['reason'] ?? 'Report'}',
            value: (data['status'] ?? 'Pending').toString(),
          ),
        ],
      ),
    );
  }
}

class _ReportedListingPreviewSheet extends StatelessWidget {
  final Map<String, dynamic> data;

  const _ReportedListingPreviewSheet({required this.data});

  Future<Map<String, Map<String, dynamic>>> _loadListing() async {
    final snapshotTarget = Map<String, dynamic>.from(
      data['targetSnapshot'] as Map? ?? const {},
    );
    final snapshotOwner = Map<String, dynamic>.from(
      data['ownerSnapshot'] as Map? ?? const {},
    );
    var target = snapshotTarget;
    var owner = snapshotOwner;

    final petId = _firstText([
      data['targetId'],
      data['petId'],
      data['listingId'],
      snapshotTarget['id'],
      snapshotTarget['petId'],
    ], fallback: '');
    if (petId.isNotEmpty) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('pets')
            .doc(petId)
            .get();
        final liveData = snapshot.data();
        if (liveData != null) {
          target = {...target, ...liveData, 'id': snapshot.id};
        }
      } catch (_) {
        // Old reports may point to deleted listings; keep the report snapshot.
      }
    }

    final ownerId = _firstText([
      target['ownerId'],
      target['userId'],
      target['postedById'],
      data['reportedUserId'],
      data['ownerId'],
      snapshotOwner['id'],
    ], fallback: '');
    if (ownerId.isNotEmpty) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(ownerId)
            .get();
        final liveData = snapshot.data();
        if (liveData != null) {
          owner = {...owner, ...liveData, 'id': snapshot.id};
        }
      } catch (_) {
        // Owner snapshot is enough for old report records.
      }

      try {
        final pets = await FirebaseFirestore.instance
            .collection('pets')
            .where('ownerId', isEqualTo: ownerId)
            .get();
        final activeCount = pets.docs.where((doc) {
          final pet = doc.data();
          final status = pet['status']?.toString().toLowerCase() ?? '';
          final isActive = pet['isActive'] != false;
          final hidden =
              pet['adminHidden'] == true || pet['adminRemoved'] == true;
          final removed =
              status == 'removed' ||
              status == 'adopted' ||
              status == 'matched' ||
              status == 'inactive';
          return isActive && !hidden && !removed;
        }).length;
        owner = {...owner, 'activeListings': activeCount};
      } catch (_) {
        // Counts are helpful but not required for the preview.
      }
    }

    return {'target': target, 'owner': owner};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, Map<String, dynamic>>>(
      future: _loadListing(),
      builder: (context, snapshot) {
        final target =
            snapshot.data?['target'] ??
            Map<String, dynamic>.from(
              data['targetSnapshot'] as Map? ?? const {},
            );
        final ownerSnapshot =
            snapshot.data?['owner'] ??
            Map<String, dynamic>.from(
              data['ownerSnapshot'] as Map? ?? const {},
            );
        return _buildContent(target, ownerSnapshot, snapshot.connectionState);
      },
    );
  }

  Widget _buildContent(
    Map<String, dynamic> target,
    Map<String, dynamic> ownerSnapshot,
    ConnectionState state,
  ) {
    final mergedReport = {
      ...data,
      'targetSnapshot': target,
      if (_firstText([data['targetName']], fallback: '').isEmpty)
        'targetName': _firstText([
          target['name'],
          target['petName'],
        ], fallback: ''),
    };
    final name = _targetTitle(mergedReport);
    final photo = _petPhoto(target);
    final price = _priceText(target);
    final description = _listingDescriptionText(target);
    final owner = _firstText([
      target['ownerName'],
      target['postedByName'],
      target['ownerEmail'],
      ownerSnapshot['fullName'],
      ownerSnapshot['displayName'],
      ownerSnapshot['userName'],
      data['reportedUserName'],
      data['reportedUserId'],
    ], fallback: 'Unknown owner');
    final ownerRating = _ratingText(
      target['ownerRating'] ??
          target['adoptionRating'] ??
          target['breederRating'] ??
          ownerSnapshot['ownerRating'] ??
          ownerSnapshot['adoptionRating'] ??
          ownerSnapshot['breederRating'],
    );
    final activeListings = _firstText([
      target['ownerActiveListings'],
      target['activeListings'],
      target['petsListed'],
      ownerSnapshot['activeListings'],
      ownerSnapshot['petsListed'],
    ], fallback: '—');

    return _PreviewSheetScaffold(
      title: 'Listing Detail',
      icon: Icons.pets,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state == ConnectionState.waiting)
            const LinearProgressIndicator(
              minHeight: 3,
              color: AppColors.primary,
              backgroundColor: Color(0xFFFFDCE5),
            ),
          if (state == ConnectionState.waiting) const SizedBox(height: 12),
          BreedrNetworkImage(
            imageUrl: photo,
            width: double.infinity,
            height: 190,
            borderRadius: BorderRadius.circular(14),
            fallback: const ColoredBox(
              color: Color(0xFFFFEEF3),
              child: Center(
                child: Icon(Icons.pets, color: AppColors.primary, size: 42),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: const TextStyle(
              color: Color(0xFF171022),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (price.isNotEmpty)
            Text(
              price,
              style: const TextStyle(
                color: Color(0xFF8E7F91),
                fontWeight: FontWeight.w800,
              ),
            ),
          const SizedBox(height: 18),
          _PreviewStatGrid(
            children: [
              _PreviewMetricTile(
                label: 'SPECIES',
                value: _firstText([target['species']], fallback: 'Not set'),
              ),
              _PreviewMetricTile(label: 'BREED', value: _petBreedText(target)),
              _PreviewMetricTile(label: 'AGE', value: _petAgeText(target)),
              _PreviewMetricTile(label: 'SIZE', value: _petSizeText(target)),
            ],
          ),
          const SizedBox(height: 18),
          const _PreviewSectionTitle(
            icon: Icons.description_outlined,
            title: 'LISTING DESCRIPTION',
          ),
          _PreviewTextBox(text: description),
          const SizedBox(height: 18),
          const _PreviewSectionTitle(
            icon: Icons.person_outline,
            title: 'POSTED BY',
          ),
          _InlineValueRow(label: 'Owner', value: owner),
          _InlineValueRow(label: 'Owner rating', value: ownerRating),
          _InlineValueRow(
            label: 'Other active listings',
            value: activeListings,
          ),
        ],
      ),
    );
  }
}

class _ReturnDecisionConfirmSheet extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool approved;
  final TextEditingController noteController;

  const _ReturnDecisionConfirmSheet({
    required this.data,
    required this.approved,
    required this.noteController,
  });

  @override
  Widget build(BuildContext context) {
    final petName = data['petName']?.toString() ?? 'This pet';
    final adopter = _returnAdopterName(data);
    final owner = _returnOwnerName(data).replaceFirst('Owner: ', '');
    final icon = approved ? Icons.check_circle_outline : Icons.cancel_outlined;
    final color = approved ? const Color(0xFF279D5C) : const Color(0xFF24182B);
    final title = approved ? 'Approve Return?' : 'Reject Return?';
    final bullets = approved
        ? [
            '$petName will be returned to $owner.',
            '$adopter will lose their adoption record for this pet.',
            '$adopter will receive a notification confirming the approved return.',
          ]
        : [
            'The adoption continues as-is — $petName stays with $adopter.',
            '$adopter will receive a notification with your reason for the rejection.',
          ];
    return _DecisionSheetFrame(
      icon: icon,
      iconColor: color,
      title: title,
      bullets: bullets,
      reversible: approved
          ? 'This finalizes the return and cannot be undone from here.'
          : 'You can still approve a future request if new evidence comes in.',
      noteController: noteController,
      confirmText: approved ? 'Approved' : 'Denied',
      confirmColor: color,
    );
  }
}

class _DecisionSheetFrame extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<String> bullets;
  final String reversible;
  final TextEditingController noteController;
  final String confirmText;
  final Color confirmColor;

  const _DecisionSheetFrame({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.bullets,
    required this.reversible,
    required this.noteController,
    required this.confirmText,
    required this.confirmColor,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(26, 28, 26, 22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: iconColor.withValues(alpha: 0.12),
              child: Icon(icon, color: iconColor, size: 30),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF171022),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            for (final bullet in bullets)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '•  $bullet',
                  style: const TextStyle(
                    color: Color(0xFF8E7F91),
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Reversible? ',
                    style: TextStyle(
                      color: Color(0xFF171022),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(text: reversible),
                ],
              ),
              style: const TextStyle(color: Color(0xFF8E7F91), height: 1.35),
            ),
            const SizedBox(height: 14),
            const Text(
              'This will be recorded in the moderation history.',
              style: TextStyle(color: Color(0xFF8E7F91)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Add a short note for the record (required)',
                filled: true,
                fillColor: const Color(0xFFFFF7FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFF2DDE3)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF8E7F91),
                      side: const BorderSide(color: Color(0xFFF2DDE3)),
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      confirmText,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewSheetScaffold extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _PreviewSheetScaffold({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
          children: [
            const _SheetHandle(),
            const SizedBox(height: 14),
            Row(
              children: [
                Material(
                  color: const Color(0xFFFFEEF3),
                  shape: const CircleBorder(),
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    color: const Color(0xFF171022),
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF171022),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Material(
                  color: const Color(0xFFFFEEF3),
                  shape: const CircleBorder(),
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    color: const Color(0xFF171022),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _PreviewIdentityCard extends StatelessWidget {
  final String photoUrl;
  final String fallbackText;
  final String title;
  final String subtitle;

  const _PreviewIdentityCard({
    required this.photoUrl,
    required this.fallbackText,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCAD5)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: const Color(0xFFFFDDE6),
            child: ClipOval(
              child: photoUrl.isEmpty
                  ? Text(
                      fallbackText,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    )
                  : BreedrNetworkImage(
                      imageUrl: photoUrl,
                      width: 64,
                      height: 64,
                      fallback: Text(
                        fallbackText,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF171022),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF8E7F91),
                    fontWeight: FontWeight.w600,
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

class _PreviewStatGrid extends StatelessWidget {
  final List<Widget> children;

  const _PreviewStatGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.45,
      children: children,
    );
  }
}

class _PreviewMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Widget? leading;

  const _PreviewMetricTile({
    required this.label,
    required this.value,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF9A8F96),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 4)],
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF171022),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _PreviewSectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF9A8F96), size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF9A8F96),
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineValueRow extends StatelessWidget {
  final String label;
  final String value;

  const _InlineValueRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF2DDE3))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF8E7F91),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF171022),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewTextBox extends StatelessWidget {
  final String text;

  const _PreviewTextBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text, style: const TextStyle(height: 1.35)),
    );
  }
}

class _ProtectionWindowPanel extends StatelessWidget {
  final Map<String, dynamic> data;

  const _ProtectionWindowPanel({required this.data});

  @override
  Widget build(BuildContext context) {
    const totalDays = 30;
    final startMillis = _timestampMillis(
      data['protectionStartedAt'] ??
          data['protectionStartAt'] ??
          data['handoverCompletedAt'] ??
          data['createdAt'],
    );
    final endMillis = _timestampMillis(
      data['protectionEndsAt'] ?? data['protectionEndAt'],
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    var currentDay = 2;
    if (startMillis > 0) {
      currentDay = ((now - startMillis) ~/ Duration.millisecondsPerDay) + 1;
    } else if (endMillis > 0) {
      final remainingDays = ((endMillis - now) / Duration.millisecondsPerDay)
          .ceil();
      currentDay = totalDays - remainingDays + 1;
    }
    currentDay = currentDay.clamp(1, totalDays).toInt();
    final progress = (currentDay / totalDays).clamp(0.03, 1.0).toDouble();

    return _SectionCard(
      title: '30-Day Protection Window',
      icon: Icons.hourglass_bottom_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              minHeight: 9,
              value: progress,
              backgroundColor: const Color(0xFFFFDDE6),
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Day $currentDay of $totalDays',
            style: const TextStyle(
              color: Color(0xFF8E7F91),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserHeader extends StatelessWidget {
  final String userId;
  final Map<String, dynamic> data;

  const _UserHeader({required this.userId, required this.data});

  @override
  Widget build(BuildContext context) {
    final photo = [
      data['profilePhotoUrl'],
      data['profilePhoto'],
      data['photoUrl'],
    ].whereType<String>().firstWhere((url) => url.isNotEmpty, orElse: () => '');
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEF3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCAD5)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: ClipOval(
              child: BreedrNetworkImage(
                imageUrl: photo,
                width: 60,
                height: 60,
                fallback: const Icon(Icons.person, color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name(data),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                Text(
                  '@${data['userName'] ?? data['username'] ?? userId.substring(0, userId.length < 7 ? userId.length : 7)}',
                  style: const TextStyle(color: Color(0xFF777777)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Retained for the legacy moderation workflow.
// ignore: unused_element
class _ActionButtonGrid extends StatelessWidget {
  final bool disabled;
  final ValueChanged<String> onAction;

  const _ActionButtonGrid({required this.disabled, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: disabled ? null : () => onAction('Warned'),
                child: const Text('Warn'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: disabled ? null : () => onAction('Suspended7'),
                child: const Text('Suspend 7d'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: disabled ? null : () => onAction('Suspended30'),
                child: const Text('Suspend 30d'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: disabled ? null : () => onAction('Banned'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('Ban'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

@immutable
class _SeverityOption {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final Color background;
  final String description;
  final String recommended;
  final String action;
  final String listingAction;

  const _SeverityOption({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
    required this.description,
    required this.recommended,
    required this.action,
    required this.listingAction,
  });
}

const _severityOptions = [
  _SeverityOption(
    key: 'minor',
    label: 'Minor Issue',
    icon: Icons.check_circle_outline,
    color: Color(0xFF45B649),
    background: Color(0xFFE8F8EA),
    description: 'First-time mistake or easily corrected.',
    recommended: 'Send Warning',
    action: 'Warned',
    listingAction: 'none',
  ),
  _SeverityOption(
    key: 'repeated',
    label: 'Repeated Issue',
    icon: Icons.replay,
    color: Color(0xFFFFA726),
    background: Color(0xFFFFF3DA),
    description: 'The same violation has happened again.',
    recommended: 'Suspend Account (7 Days)',
    action: 'Suspended7',
    listingAction: 'hide',
  ),
  _SeverityOption(
    key: 'serious',
    label: 'Serious Violation',
    icon: Icons.report_problem_outlined,
    color: Color(0xFFFF6B7D),
    background: Color(0xFFFFE6EC),
    description:
        'Serious misconduct such as harassment, scams, or misleading information.',
    recommended: 'Suspend Account (30 Days)',
    action: 'Suspended30',
    listingAction: 'remove',
  ),
  _SeverityOption(
    key: 'critical',
    label: 'Critical Violation',
    icon: Icons.block,
    color: AppColors.primary,
    background: Color(0xFFFFDCE5),
    description:
        'Animal abuse, illegal activity, fake documents, or repeated serious offenses.',
    recommended: 'Permanently Disable Account',
    action: 'Banned',
    listingAction: 'remove',
  ),
];

class _WizardStepHeader extends StatelessWidget {
  final int step;
  final int total;
  final String label;

  const _WizardStepHeader({
    required this.step,
    required this.total,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STEP $step OF $total • ${label.toUpperCase()}',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var index = 1; index <= total; index++) ...[
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 5,
                    decoration: BoxDecoration(
                      color: index <= step
                          ? AppColors.primary
                          : const Color(0xFFF2DDE3),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                if (index != total) const SizedBox(width: 6),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ResolvedStepHeader extends StatelessWidget {
  const _ResolvedStepHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'REVIEW COMPLETE',
            style: TextStyle(
              color: Color(0xFF279D5C),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var index = 0; index < 4; index++) ...[
                Expanded(
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                if (index != 3) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final bool highlighted;
  final VoidCallback? onTap;

  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.body,
    this.highlighted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: highlighted ? const Color(0xFFFFEEF3) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: highlighted
                    ? AppColors.primary
                    : const Color(0xFFFFCAD5),
                width: highlighted ? 1.4 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: const TextStyle(
                          color: Color(0xFF777777),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFFB9AAB2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SeverityChoiceCard extends StatelessWidget {
  final _SeverityOption option;
  final bool selected;
  final VoidCallback onTap;

  const _SeverityChoiceCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? option.background : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? option.color : const Color(0xFFFFCAD5),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(option.icon, color: option.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      option.label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle, color: option.color, size: 20),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                option.description,
                style: const TextStyle(color: Color(0xFF777777), height: 1.3),
              ),
              const SizedBox(height: 8),
              Text(
                'Recommended: ${option.recommended}',
                style: TextStyle(
                  color: option.color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeveritySummaryCard extends StatelessWidget {
  final _SeverityOption option;

  const _SeveritySummaryCard({required this.option});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: option.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: option.color.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            Icon(option.icon, color: option.color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    option.recommended,
                    style: const TextStyle(
                      color: Color(0xFF777777),
                      fontSize: 12,
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
}

class _DecisionSummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color color;

  const _DecisionSummaryCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    height: 1.32,
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

class _WarningBanner extends StatelessWidget {
  final String text;

  const _WarningBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1D9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFA726)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF6B4E00),
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WizardFooter extends StatelessWidget {
  final String primaryText;
  final IconData primaryIcon;
  final VoidCallback? onPrimary;
  final String? secondaryText;
  final IconData? secondaryIcon;
  final VoidCallback? onSecondary;

  const _WizardFooter({
    required this.primaryText,
    required this.primaryIcon,
    required this.onPrimary,
    this.secondaryText,
    this.secondaryIcon,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = secondaryText != null && onSecondary != null;
    return Column(
      children: [
        FilledButton.icon(
          onPressed: onPrimary,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: Icon(primaryIcon),
          label: Text(
            primaryText,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        if (secondary) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onSecondary,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              foregroundColor: const Color(0xFF7A6470),
              side: const BorderSide(color: Color(0xFFF2DDE3)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: Icon(secondaryIcon),
            label: Text(
              secondaryText!,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ],
    );
  }
}

class _BackStepButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _BackStepButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: const Color(0xFF7A6470),
        side: const BorderSide(color: Color(0xFFF2DDE3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const Icon(Icons.arrow_back),
      label: const Text('Back', style: TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFD0DA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _SectionCard(
        title: title,
        icon: Icons.description_outlined,
        child: Column(children: children),
      ),
    );
  }
}

class _TextPanel extends StatelessWidget {
  final String title;
  final String text;

  const _TextPanel({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _SectionCard(
        title: title,
        icon: Icons.chat_bubble_outline,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F5F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(text, style: const TextStyle(height: 1.35)),
        ),
      ),
    );
  }
}

class _ResolvedAdminNotePanel extends StatelessWidget {
  final String moderator;
  final String date;
  final String note;

  const _ResolvedAdminNotePanel({
    required this.moderator,
    required this.date,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _SectionCard(
        title: 'Internal Admin Note (admins only)',
        icon: Icons.lock_outline,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F5F6),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              _DetailRow(label: 'Moderator', value: moderator),
              _DetailRow(label: 'Date & time', value: date),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(note, style: const TextStyle(height: 1.35)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResolvedUserExplanationPanel extends StatelessWidget {
  final String action;
  final String reason;
  final String effectiveDate;

  const _ResolvedUserExplanationPanel({
    required this.action,
    required this.reason,
    required this.effectiveDate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _SectionCard(
        title: 'Explanation Sent to User',
        icon: Icons.chat_bubble_outline,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE4F7EB),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              _DetailRow(label: 'Action Taken', value: action),
              _DetailRow(label: 'Reason', value: reason),
              _DetailRow(label: 'Effective Date', value: effectiveDate),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminInfoPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _AdminInfoPanel({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE8EE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 12,
                    height: 1.35,
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

class _CollapsibleAdminInfoPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final bool expanded;
  final VoidCallback onToggle;

  const _CollapsibleAdminInfoPanel({
    required this.icon,
    required this.title,
    required this.body,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE8EE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCAD5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    TextButton(
                      onPressed: onToggle,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      child: Text(
                        expanded ? 'Hide' : 'Show',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                if (expanded) ...[
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF777777),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReporterDetailRow extends StatelessWidget {
  final Map<String, dynamic> data;

  const _ReporterDetailRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _reporterName(data),
      builder: (context, snapshot) {
        return _DetailRow(
          label: 'Reported by',
          value: snapshot.data ?? _reporterNameFromSnapshot(data),
        );
      },
    );
  }
}

class _TextArea extends StatelessWidget {
  final String label;
  final String? helperText;
  final IconData? icon;
  final TextEditingController controller;

  const _TextArea({
    required this.label,
    required this.controller,
    this.helperText,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label: label, icon: icon),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFFFF7FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFFFB5C1)),
              ),
            ),
          ),
          if (helperText != null) ...[
            const SizedBox(height: 7),
            Text(
              helperText!,
              style: const TextStyle(color: Color(0xFF8E7F91), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final IconData? icon;

  const _FieldLabel({required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: const Color(0xFF8E7F91), size: 18),
          const SizedBox(width: 7),
        ],
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8E7F91),
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final IconData? icon;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label: label, icon: icon),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: value,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFFFF7FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            items: items.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
          ),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchBox({required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search, color: Color(0xFF8E7F91)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 15,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: Color(0xFFF2DDE3), width: 1.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: Color(0xFFFFCAD5)),
        ),
      ),
    );
  }
}

class _SegmentRow extends StatelessWidget {
  final String selected;
  final List<(String, IconData, String)> items;
  final ValueChanged<String> onSelected;

  const _SegmentRow({
    required this.selected,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFFCAD5)),
      ),
      child: Row(
        children: items.map((item) {
          final active = item.$1 == selected;
          return Expanded(
            child: InkWell(
              onTap: () => onSelected(item.$1),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFFFFEDF2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: active ? AppColors.primary : Colors.transparent,
                    width: 1.3,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item.$2,
                      size: 15,
                      color: active
                          ? AppColors.primary
                          : const Color(0xFF777777),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      item.$3,
                      style: TextStyle(
                        color: active
                            ? AppColors.primary
                            : const Color(0xFF777777),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  final String selected;
  final List<(String, String)> items;
  final ValueChanged<String> onSelected;

  const _ChipRow({
    required this.selected,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 10),
            child: Icon(Icons.filter_list, color: Color(0xFF8E7F91), size: 18),
          ),
          ...items.map((item) {
            final active = selected == item.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () => onSelected(item.$1),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF171022)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: active
                          ? const Color(0xFF171022)
                          : const Color(0xFFF2DDE3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (active) ...[
                        const Icon(Icons.check, color: Colors.white, size: 15),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        item.$2,
                        style: TextStyle(
                          color: active
                              ? Colors.white
                              : const Color(0xFF8E7F91),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String assetPath;
  final int count;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.assetPath,
    required this.count,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFFC1CE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Image.asset(
                assetPath,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, _, _) => _IconBubble(icon: icon),
              ),
            ),
            const Spacer(),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF555555),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageIntro extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PageIntro({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF777777), height: 1.3),
        ),
      ],
    );
  }
}

class _SheetTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String badge;
  final VoidCallback? onClose;

  const _SheetTitle({
    required this.icon,
    required this.title,
    required this.badge,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ),
        _Badge(label: badge),
        if (onClose != null) ...[
          const SizedBox(width: 8),
          Material(
            color: const Color(0xFFFFEEF3),
            shape: const CircleBorder(),
            child: IconButton(
              onPressed: onClose,
              color: const Color(0xFF171022),
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD0DA)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 38),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF777777)),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;

  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    final normalized = label.toLowerCase();
    final color = normalized.contains('pending')
        ? const Color(0xFFFFA726)
        : normalized.contains('approved') ||
              normalized.contains('active') ||
              normalized.contains('resolved')
        ? const Color(0xFF45B649)
        : normalized.contains('denied') ||
              normalized.contains('banned') ||
              normalized.contains('remove')
        ? AppColors.primary
        : const Color(0xFF777777);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  final IconData icon;
  final double size;

  const _IconBubble({required this.icon, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFFFE4EB),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: AppColors.primary, size: size * 0.52),
    );
  }
}

class _InitialBubble extends StatelessWidget {
  final String initials;

  const _InitialBubble({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFFDDE5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  final String label;

  const _CountPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEF2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF6F6472),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 54,
        height: 5,
        decoration: BoxDecoration(
          color: const Color(0xFFD8D8D8),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

// Retained for legacy admin detail layouts.
// ignore: unused_element
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          _IconBubble(icon: icon, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF777777),
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

class _AdminSettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AdminSettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _IconBubble(icon: icon, size: 40),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _AdminPreferenceSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AdminPreferenceSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFD5DE)),
      ),
      child: SwitchListTile(
        value: value,
        activeThumbColor: Colors.white,
        activeTrackColor: AppColors.primary,
        inactiveThumbColor: Colors.white,
        inactiveTrackColor: const Color(0xFFD5CDD4),
        contentPadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF222222),
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF8C7D88),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

@immutable
class _AdminCounts {
  final int pendingListingReports;
  final int pendingUserReports;
  final int pendingReturns;
  final int activeUsers;

  const _AdminCounts({
    this.pendingListingReports = 0,
    this.pendingUserReports = 0,
    this.pendingReturns = 0,
    this.activeUsers = 0,
  });
}

List<Map<String, dynamic>> _evidenceFiles(Map<String, dynamic> data) {
  final files = data['evidenceFiles'];
  if (files is List) {
    return files
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
  final urls = data['evidenceUrls'];
  if (urls is List) {
    return urls
        .whereType<String>()
        .map(
          (url) => {
            'url': url,
            'fileName': url.split('/').last,
            'fileType': _guessFileType(url),
            'sizeBytes': null,
          },
        )
        .toList();
  }
  return const [];
}

String _guessFileType(String url) {
  final lower = url.toLowerCase();
  if (lower.endsWith('.pdf')) return 'pdf';
  if (lower.endsWith('.mp4') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.m4v')) {
    return 'video';
  }
  return 'image';
}

IconData _evidenceIcon(String? type) {
  return switch (type) {
    'image' => Icons.image_outlined,
    'video' => Icons.videocam_outlined,
    'pdf' => Icons.picture_as_pdf_outlined,
    _ => Icons.attach_file,
  };
}

String _evidenceDialogTitle(String fileType) {
  return switch (fileType) {
    'video' => 'Video Evidence',
    'pdf' => 'PDF Evidence',
    _ => 'Evidence File',
  };
}

String _targetTitle(Map<String, dynamic> data) {
  final target = Map<String, dynamic>.from(
    data['targetSnapshot'] as Map? ?? const {},
  );
  return [
    data['targetName'],
    data['petName'],
    target['petName'],
    target['name'],
    target['fullName'],
    target['displayName'],
    target['ownerName'],
    data['targetId'],
  ].whereType<String>().firstWhere(
    (value) => value.trim().isNotEmpty,
    orElse: () => 'Reported item',
  );
}

String _reportTypeLabel(Map<String, dynamic> data) {
  return _isListingReportType(data['type'])
      ? 'PET LISTING REPORT'
      : 'PROFILE REPORT';
}

IconData _reportIcon(Map<String, dynamic> data) {
  return _isListingReportType(data['type']) ? Icons.pets : Icons.person_outline;
}

IconData _adminActivityIcon(Map<String, dynamic> data) {
  final type = data['type']?.toString().toLowerCase() ?? '';
  if (type == 'return') return Icons.assignment_return_outlined;
  if (type == 'account') return Icons.manage_accounts_outlined;
  if (type == 'report') {
    final targetType = data['targetType'] ?? data['reportType'];
    if (_isListingReportType(targetType) || _looksLikePetTarget(data)) {
      return Icons.pets;
    }
    if (_isProfileReportType(targetType) || _looksLikeUserTarget(data)) {
      return Icons.person_outline;
    }
  }
  return Icons.flag_outlined;
}

bool _isListingReportType(dynamic value) {
  final type = value?.toString().toLowerCase().trim() ?? '';
  return type == 'listing' ||
      type == 'pet_listing' ||
      type == 'petlisting' ||
      type.contains('listing');
}

bool _isProfileReportType(dynamic value) {
  final type = value?.toString().toLowerCase().trim() ?? '';
  return type == 'user' ||
      type == 'profile' ||
      type == 'user_profile' ||
      type == 'userprofile' ||
      type.contains('profile');
}

bool _looksLikePetTarget(Map<String, dynamic> data) {
  final target = Map<String, dynamic>.from(
    data['targetSnapshot'] as Map? ?? const {},
  );
  return [
    target['petName'],
    target['species'],
    target['breed'],
    target['petProfilePhoto'],
  ].whereType<String>().any((value) => value.trim().isNotEmpty);
}

bool _looksLikeUserTarget(Map<String, dynamic> data) {
  final target = Map<String, dynamic>.from(
    data['targetSnapshot'] as Map? ?? const {},
  );
  return [
    target['fullName'],
    target['userName'],
    target['username'],
    target['email'],
    target['profilePhoto'],
  ].whereType<String>().any((value) => value.trim().isNotEmpty);
}

String _reportSubtitle(Map<String, dynamic> data, String reporter) {
  if (!_isListingReportType(data['type'])) {
    return 'Reported by $reporter';
  }
  final target = Map<String, dynamic>.from(
    data['targetSnapshot'] as Map? ?? const {},
  );
  final owner =
      [
        target['ownerName'],
        target['ownerEmail'],
        data['reportedUserId'],
      ].whereType<String>().firstWhere(
        (value) => value.trim().isNotEmpty,
        orElse: () => 'listing owner',
      );
  return 'Reported by $reporter • Listed by $owner';
}

String _reportedUserName(Map<String, dynamic> data) {
  final target = Map<String, dynamic>.from(
    data['targetSnapshot'] as Map? ?? const {},
  );
  return _firstText([
    data['reportedUserName'],
    target['ownerName'],
    target['postedByName'],
    target['fullName'],
    target['displayName'],
    target['userName'],
    target['username'],
    target['ownerEmail'],
    data['reportedUserId'],
  ], fallback: 'Reported user');
}

String _reporterNameFromSnapshot(Map<String, dynamic> data) {
  final reporter = Map<String, dynamic>.from(
    data['reporterSnapshot'] as Map? ?? const {},
  );
  return [
    reporter['fullName'],
    reporter['displayName'],
    reporter['userName'],
    reporter['username'],
    reporter['email'],
  ].whereType<String>().firstWhere(
    (value) => value.trim().isNotEmpty,
    orElse: () => 'Reporter unavailable',
  );
}

Future<String> _reporterName(Map<String, dynamic> data) async {
  final snapshottedName = _reporterNameFromSnapshot(data);
  if (snapshottedName != 'Reporter unavailable') return snapshottedName;
  final reporterId = data['reporterId']?.toString() ?? '';
  if (reporterId.trim().isEmpty) return snapshottedName;
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(reporterId)
        .get();
    final userData = snapshot.data();
    if (userData == null) return snapshottedName;
    return _name(userData);
  } catch (_) {
    return snapshottedName;
  }
}

Map<String, dynamic> _nestedMap(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

String _name(Map<String, dynamic> data) {
  return [
    data['fullName'],
    data['displayName'],
    data['name'],
    data['userName'],
    data['username'],
    data['email'],
  ].whereType<String>().firstWhere(
    (value) => value.trim().isNotEmpty,
    orElse: () => 'Breedr user',
  );
}

String _firstText(List<dynamic> values, {required String fallback}) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

String _profilePhoto(Map<String, dynamic> data) {
  return _firstText([
    data['profilePhotoUrl'],
    data['profilePhoto'],
    data['photoUrl'],
    data['avatarUrl'],
  ], fallback: '');
}

String _petPhoto(Map<String, dynamic> data) {
  final additional = data['additionalPhotos'];
  final morePhotos = data['morePhotos'];
  return _firstText([
    data['petProfilePhoto'],
    data['profilePhoto'],
    data['coverPhoto'],
    data['photoUrl'],
    if (additional is List && additional.isNotEmpty) additional.first,
    if (morePhotos is List && morePhotos.isNotEmpty) morePhotos.first,
  ], fallback: '');
}

String _petBreedText(Map<String, dynamic> data) {
  final mixed = data['breeds'];
  if (mixed is List) {
    final breeds = mixed
        .map((value) => value?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toList();
    if (breeds.isNotEmpty) return breeds.join(' / ');
  }
  final secondary = _firstText([
    data['secondaryBreed'],
    data['breed2'],
  ], fallback: '');
  final primary = _firstText([
    data['breed'],
    data['primaryBreed'],
  ], fallback: '');
  if (primary.isNotEmpty && secondary.isNotEmpty && primary != secondary) {
    return '$primary / $secondary';
  }
  return primary.isNotEmpty ? primary : 'Not set';
}

String _petAgeText(Map<String, dynamic> data) {
  final value = _firstText([
    data['age'],
    data['ageText'],
    data['petAge'],
    data['displayAge'],
  ], fallback: '');
  if (value.isNotEmpty) return value;

  final ageValue = data['ageValue'] ?? data['ageNumber'];
  final ageUnit = _firstText([
    data['ageUnit'],
    data['unit'],
  ], fallback: 'years old');
  if (ageValue != null && ageValue.toString().trim().isNotEmpty) {
    return '${ageValue.toString().trim()} $ageUnit';
  }
  return 'Not set';
}

String _petSizeText(Map<String, dynamic> data) {
  return _firstText([
    data['breedSize'],
    data['size'],
    data['petSize'],
    data['displaySize'],
  ], fallback: 'Not set');
}

String _listingDescriptionText(Map<String, dynamic> data) {
  final adoption = _nestedMap(data, 'adoptionDetails');
  return _firstText([
    data['about'],
    data['aboutPet'],
    data['bio'],
    data['description'],
    data['petBio'],
    data['petDescription'],
    adoption['description'],
    adoption['story'],
  ], fallback: 'No listing description provided.');
}

String _homeTypeText(Map<String, dynamic> data) {
  final homeInfo = _nestedMap(data, 'homeInformation');
  return _firstText([
    data['homeType'],
    data['typeOfHome'],
    data['housingType'],
    homeInfo['homeType'],
    homeInfo['typeOfHome'],
    homeInfo['housingType'],
  ], fallback: 'Not set');
}

String _priceText(Map<String, dynamic> data) {
  final adoption = _nestedMap(data, 'adoptionDetails');
  final type = _firstText([
    data['adoptionType'],
    adoption['adoptionType'],
    adoption['type'],
  ], fallback: '').toLowerCase();
  if (type == 'free') return 'Free';
  final value = data['price'] ?? data['adoptionPrice'] ?? adoption['price'];
  if (value == null) return '';
  final text = value.toString().trim();
  if (text.isEmpty || text == '0') return type == 'paid' ? 'Price not set' : '';
  if (text.startsWith('₱') || text.toLowerCase().startsWith('php')) return text;
  return '₱$text';
}

String _yesNo(dynamic value) {
  if (value == null) return '—';
  if (value is bool) return value ? 'YES' : 'NO';
  final text = value.toString().trim();
  if (text.isEmpty) return '—';
  return text;
}

String _ratingText(dynamic value) {
  if (value == null) return '—';
  if (value is num) return value <= 0 ? '—' : value.toStringAsFixed(1);
  final text = value.toString().trim();
  if (text.isEmpty || text == '0') return '—';
  final parsed = num.tryParse(text);
  if (parsed != null) return parsed <= 0 ? '—' : parsed.toStringAsFixed(1);
  return text;
}

String _profileDisplayName(
  Map<String, dynamic>? profile, {
  required String fallback,
}) {
  if (profile == null) return fallback;
  return _firstHumanName([
    profile['fullName'],
    profile['userName'],
    profile['username'],
    profile['displayName'],
  ], fallback: fallback);
}

class _ReturnParticipantNames {
  final String owner;
  final String adopter;

  const _ReturnParticipantNames({required this.owner, required this.adopter});
}

Future<_ReturnParticipantNames> _resolveReturnParticipantNames(
  Map<String, dynamic> data,
) async {
  final ownerId = data['ownerId']?.toString().trim() ?? '';
  final adopterId =
      (data['adopterId'] ?? data['filedBy'])?.toString().trim() ?? '';
  final ids = <String>{ownerId, adopterId}..remove('');
  if (ids.isEmpty) {
    return _ReturnParticipantNames(
      owner: _returnOwnerName(data).replaceFirst('Owner: ', ''),
      adopter: _returnAdopterName(data),
    );
  }

  try {
    final snapshots = await Future.wait(
      ids.map(
        (id) => FirebaseFirestore.instance.collection('users').doc(id).get(),
      ),
    );
    final profiles = <String, Map<String, dynamic>>{
      for (final snapshot in snapshots)
        snapshot.id: snapshot.data() ?? const <String, dynamic>{},
    };
    return _ReturnParticipantNames(
      owner: _profileDisplayName(profiles[ownerId], fallback: 'Owner'),
      adopter: _profileDisplayName(profiles[adopterId], fallback: 'Adopter'),
    );
  } catch (_) {
    return _ReturnParticipantNames(
      owner: _returnOwnerName(data).replaceFirst('Owner: ', ''),
      adopter: _returnAdopterName(data),
    );
  }
}

String _returnAdopterName(Map<String, dynamic> data) {
  final adopter = data['adopterSnapshot'];
  return _firstHumanName([
    data['adopterName'],
    if (adopter is Map) adopter['fullName'],
    if (adopter is Map) adopter['userName'],
    if (adopter is Map) adopter['username'],
    if (adopter is Map) adopter['displayName'],
    data['filedByName'],
  ], fallback: 'Adopter');
}

String _returnOwnerName(Map<String, dynamic> data) {
  final owner = data['ownerSnapshot'];
  return 'Owner: ${_firstHumanName([data['ownerName'], if (owner is Map) owner['fullName'], if (owner is Map) owner['userName'], if (owner is Map) owner['username'], if (owner is Map) owner['displayName']], fallback: 'Owner')}';
}

String _firstHumanName(List<dynamic> values, {required String fallback}) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty && !_looksLikeFirebaseUid(text)) return text;
  }
  return fallback;
}

bool _looksLikeFirebaseUid(String value) {
  return RegExp(r'^[A-Za-z0-9_-]{20,}$').hasMatch(value);
}

String _moderationStatus(Map<String, dynamic> data) {
  final value = (data['moderationStatus'] ?? data['status'] ?? 'active')
      .toString();
  if (value == 'published') return 'active';
  return value.toLowerCase();
}

String _formatTimestamp(dynamic value) {
  if (value is Timestamp) {
    final date = value.toDate();
    return '${date.month}/${date.day}/${date.year}';
  }
  if (value is DateTime) return '${value.month}/${value.day}/${value.year}';
  return value?.toString() ?? 'Not recorded';
}

String _memberMonth(Map<String, dynamic> data) {
  final value = data['createdAt'] ?? data['joinedAt'] ?? data['memberSince'];
  final date = switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    DateTime dateTime => dateTime,
    _ => null,
  };
  if (date == null) return 'Member';
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
  return '${months[date.month - 1]} ${date.year}';
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.trim().isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'U';
  if (parts.length == 1) {
    final value = parts.first;
    return value.substring(0, value.length >= 2 ? 2 : 1).toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

int _timestampMillis(dynamic value) {
  if (value is Timestamp) return value.millisecondsSinceEpoch;
  if (value is DateTime) return value.millisecondsSinceEpoch;
  return 0;
}

String _formatShortDate(dynamic value) {
  final date = switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    DateTime dateTime => dateTime,
    _ => null,
  };
  if (date == null) return 'Not recorded';
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

String _relativeTimestamp(dynamic value) {
  final date = switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    DateTime dateTime => dateTime,
    _ => null,
  };
  if (date == null) return 'Recently';
  final difference = DateTime.now().difference(date);
  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  return _formatShortDate(date);
}

String _formatBytes(dynamic value) {
  final bytes = value is num ? value.toDouble() : null;
  if (bytes == null || bytes <= 0) return 'size unknown';
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024).toStringAsFixed(1)} KB';
}

String _statusForAction(String action) {
  return switch (action) {
    'Restored' => 'active',
    'Warned' => 'warned',
    'Suspended7' || 'Suspended30' => 'suspended',
    'Banned' => 'banned',
    _ => 'active',
  };
}

Object _moderationEndsAtForAction(String action) {
  final now = DateTime.now();
  return switch (action) {
    'Suspended7' => Timestamp.fromDate(now.add(const Duration(days: 7))),
    'Suspended30' => Timestamp.fromDate(now.add(const Duration(days: 30))),
    _ => FieldValue.delete(),
  };
}

DateTime? _moderationEndDateForAction(String action) {
  final now = DateTime.now();
  return switch (action) {
    'Suspended7' => now.add(const Duration(days: 7)),
    'Suspended30' => now.add(const Duration(days: 30)),
    _ => null,
  };
}

String _severityForAction(String action) {
  return switch (action) {
    'Warned' => 'Minor Issue',
    'Suspended7' => 'Repeated Issue',
    'Suspended30' => 'Serious Violation',
    'Banned' => 'Critical Violation',
    _ => 'Account standing review',
  };
}

Map<String, dynamic> _moderationHistoryEntry({
  required String action,
  required String actionKey,
  required String severity,
  required String category,
  required String userNote,
  required DateTime? endsAt,
}) {
  return {
    'action': action,
    'actionKey': actionKey,
    'severity': severity,
    'category': category,
    'userNote': userNote,
    'createdAt': Timestamp.now(),
    if (endsAt != null) 'endsAt': Timestamp.fromDate(endsAt),
  };
}

Future<void> _queueUserPetModerationUpdates({
  required WriteBatch batch,
  required String userId,
  required String action,
  required String? adminId,
  required String reason,
}) async {
  if (userId.isEmpty || action == 'Dismissed') return;

  final snapshot = await FirebaseFirestore.instance
      .collection('pets')
      .where('ownerId', isEqualTo: userId)
      .get();
  final endDate = _moderationEndDateForAction(action);

  for (final pet in snapshot.docs) {
    final currentStatus = (pet.data()['moderationListingStatus'] ?? '')
        .toString()
        .toLowerCase();
    final sourceAction = (pet.data()['moderationSourceAction'] ?? '')
        .toString();

    if (action == 'Warned') {
      if (currentStatus != 'hidden' || sourceAction != 'Warned') continue;
      batch.set(pet.reference, {
        'moderationListingStatus': 'active',
        'moderationHiddenUntil': FieldValue.delete(),
        'moderationHiddenAt': FieldValue.delete(),
        'moderationHiddenBy': FieldValue.delete(),
        'moderationSourceAction': FieldValue.delete(),
        'moderationHiddenReason': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      continue;
    }

    if (action == 'Restored') {
      if (currentStatus != 'hidden') continue;
      batch.set(pet.reference, {
        'moderationListingStatus': 'active',
        'moderationHiddenUntil': FieldValue.delete(),
        'moderationSourceAction': FieldValue.delete(),
        'moderationHiddenReason': FieldValue.delete(),
        'moderationHiddenBy': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      continue;
    }

    final isPermanent = action == 'Banned';
    batch.set(pet.reference, {
      'moderationListingStatus': isPermanent ? 'removed' : 'hidden',
      'moderationHiddenUntil': isPermanent || endDate == null
          ? FieldValue.delete()
          : Timestamp.fromDate(endDate),
      'moderationHiddenAt': FieldValue.serverTimestamp(),
      'moderationHiddenBy': adminId,
      'moderationSourceAction': action,
      'moderationHiddenReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

String _actionLabel(String action, String listingAction) {
  final account = switch (action) {
    'Restored' => 'Lift Restriction',
    'Warned' => 'Send Warning',
    'Suspended7' => 'Suspend 7 Days',
    'Suspended30' => 'Suspend 30 Days',
    'Banned' => 'Ban Account',
    'Dismissed' => 'Dismissed',
    _ => action,
  };
  final listing = switch (listingAction) {
    'hide' => ' + Listing Hidden',
    'remove' => ' + Listing Removed',
    _ => '',
  };
  return '$account$listing';
}

bool _canRestoreAccount(String status) {
  final normalized = status.trim().toLowerCase();
  return normalized == 'warned' ||
      normalized == 'suspended' ||
      normalized == 'banned';
}

bool _requiresRestrictionConfirmation(String action) {
  return action == 'Suspended7' ||
      action == 'Suspended30' ||
      action == 'Banned';
}

Future<bool> _showAccountRestrictionConfirmation({
  required BuildContext context,
  required String action,
  required String userName,
  required String userExplanation,
}) async {
  final isBan = action == 'Banned';
  final days = action == 'Suspended7' ? 7 : 30;
  final title = isBan
      ? 'Permanently Disable Account?'
      : 'Suspend Account ($days Days)?';
  final icon = isBan ? Icons.block_rounded : Icons.pause_circle_outline;
  final accountVerb = isBan ? 'permanently lose access' : 'lose access';
  final listingCopy = isBan
      ? 'All active listings will be removed from public view.'
      : 'All active listings will be hidden from public view while the restriction is active.';
  final reversibility = isBan
      ? 'Not easily reversible. Only apply this after careful review.'
      : 'Reversible. An admin can reinstate the account early from the account profile.';

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.88,
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: _SheetHandle()),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFE1EA),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: AppColors.primary, size: 30),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF251D29),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                _RestrictionBullet(
                  '$userName will $accountVerb to Breedr${isBan ? '.' : ' for the next $days days.'}',
                ),
                const _RestrictionBullet(
                  'They will not be able to create listings, send messages, or submit adoption or breeding requests.',
                ),
                const _RestrictionBullet(
                  'They will receive the explanation shown below when they try to use the app.',
                ),
                _RestrictionBullet(listingCopy),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: Color(0xFF6F6574),
                      fontSize: 13,
                      height: 1.4,
                    ),
                    children: [
                      const TextSpan(
                        text: 'Reversible? ',
                        style: TextStyle(
                          color: Color(0xFF251D29),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(text: reversibility),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEEF2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'User will see:',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        userExplanation,
                        style: const TextStyle(
                          color: Color(0xFF6F6574),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'This will be recorded in the moderation history.',
                  style: TextStyle(color: Color(0xFF8B7C86), fontSize: 13),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6F6574),
                          side: const BorderSide(color: Color(0xFFFFCCD8)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Confirm'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return result ?? false;
}

class _RestrictionBullet extends StatelessWidget {
  final String text;

  const _RestrictionBullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5, right: 9),
            child: Icon(Icons.circle, size: 5, color: Color(0xFF8B7C86)),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF6F6574),
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _showGlobalSnack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmText,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return result ?? false;
}
