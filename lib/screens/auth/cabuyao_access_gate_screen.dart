import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/cabuyao_access_service.dart';
import '../../services/user_session_service.dart';
import '../../theme/app_colors.dart';
import 'get_started_screen.dart';

class CabuyaoAccessGate extends StatefulWidget {
  const CabuyaoAccessGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<CabuyaoAccessGate> createState() => _CabuyaoAccessGateState();
}

class _CabuyaoAccessGateState extends State<CabuyaoAccessGate>
    with WidgetsBindingObserver {
  CabuyaoAccessResult? _result;
  bool _checking = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_checking && !_isAdmin) {
      _checkAccess(requestPermission: false);
    }
  }

  Future<void> _checkAccess({bool requestPermission = true}) async {
    if (mounted) setState(() => _checking = true);

    var isAdmin = false;
    try {
      isAdmin = await UserSessionService.instance.isCurrentUserAdmin();
    } catch (error) {
      // A profile lookup should never prevent a regular user from completing
      // the local service-area check during a temporary Firestore failure.
      debugPrint('Unable to check admin role for location gate: $error');
    }
    final result = isAdmin
        ? const CabuyaoAccessResult(CabuyaoAccessStatus.allowed)
        : await CabuyaoAccessService.instance.checkAccess(
            requestPermission: requestPermission,
          );

    if (!mounted) return;
    setState(() {
      _isAdmin = isAdmin;
      _result = result;
      _checking = false;
    });
  }

  Future<void> _openSettings() async {
    await Geolocator.openAppSettings();
    await _checkAccess(requestPermission: false);
  }

  Future<void> _openLocationSettings() async {
    await Geolocator.openLocationSettings();
    await _checkAccess(requestPermission: false);
  }

  Future<void> _signOut() async {
    await UserSessionService.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const GetStartedScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_result?.isAllowed == true) return widget.child;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: _AccessRequiredCard(
                status: _result?.status ??
                    CabuyaoAccessStatus.locationUnavailable,
                onPrimaryPressed: () {
                  if (_result?.status ==
                      CabuyaoAccessStatus.serviceDisabled) {
                    _openLocationSettings();
                  } else if (_result?.status ==
                      CabuyaoAccessStatus.permissionDeniedForever) {
                    _openSettings();
                  } else {
                    _checkAccess();
                  }
                },
                onSignOut: _signOut,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccessRequiredCard extends StatelessWidget {
  const _AccessRequiredCard({
    required this.status,
    required this.onPrimaryPressed,
    required this.onSignOut,
  });

  final CabuyaoAccessStatus status;
  final VoidCallback onPrimaryPressed;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final content = _contentFor(status);

    return Container(
      width: 380,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Icon(content.icon, color: AppColors.primary, size: 34),
          ),
          const SizedBox(height: 18),
          Text(
            content.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            content.message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textGrey,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onPrimaryPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                content.primaryAction,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onSignOut,
            child: const Text(
              'Log out',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _AccessContent _contentFor(CabuyaoAccessStatus status) {
    switch (status) {
      case CabuyaoAccessStatus.serviceDisabled:
        return const _AccessContent(
          icon: Icons.location_off_outlined,
          title: 'Turn on location',
          message:
              'Breedr uses your location to keep the community within Cabuyao. Turn on Location Services, then try again.',
          primaryAction: 'Open Location Settings',
        );
      case CabuyaoAccessStatus.permissionDenied:
        return const _AccessContent(
          icon: Icons.location_on_outlined,
          title: 'Allow location access',
          message:
              'Location access is needed to confirm that you are within Cabuyao, Laguna.',
          primaryAction: 'Allow location',
        );
      case CabuyaoAccessStatus.permissionDeniedForever:
        return const _AccessContent(
          icon: Icons.settings_outlined,
          title: 'Allow location in Settings',
          message:
              'Location permission was turned off for Breedr. Enable it in your device settings to continue.',
          primaryAction: 'Open Settings',
        );
      case CabuyaoAccessStatus.outsideServiceArea:
        return const _AccessContent(
          icon: Icons.location_city_outlined,
          title: 'Breedr is available in Cabuyao only',
          message:
              'Your current location is outside the Cabuyao service area. You can try again after returning to Cabuyao.',
          primaryAction: 'Check location again',
        );
      case CabuyaoAccessStatus.locationUnavailable:
        return const _AccessContent(
          icon: Icons.my_location_outlined,
          title: 'We could not get your location',
          message:
              'Check your internet and location signal, then try again. Breedr needs a current location to verify the service area.',
          primaryAction: 'Try again',
        );
      case CabuyaoAccessStatus.allowed:
        return const _AccessContent(
          icon: Icons.location_on_outlined,
          title: '',
          message: '',
          primaryAction: '',
        );
    }
  }
}

class _AccessContent {
  const _AccessContent({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String primaryAction;
}
