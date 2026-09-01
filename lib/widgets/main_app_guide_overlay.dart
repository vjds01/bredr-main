import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum GuideCardPlacement { top, center, bottom }

enum GuidePreviewType {
  breedingWelcome,
  breedingCard,
  breedingLike,
  breedingPass,
  breedingSwipe,
  breedingFilter,
  breedingMatch,
  adoptionBrowse,
  adoptionRequest,
  adoptionListings,
  chat,
  notifications,
  profile,
  ready,
}

class MainAppGuideStep {
  final int tabIndex;
  final String title;
  final String body;
  final GuideCardPlacement placement;
  final GuidePreviewType previewType;
  final String assetPath;

  const MainAppGuideStep({
    required this.tabIndex,
    required this.title,
    required this.body,
    required this.previewType,
    required this.assetPath,
    this.placement = GuideCardPlacement.center,
  });
}

class MainAppGuideOverlay extends StatelessWidget {
  static const double _guideImageAspectRatio = 430 / 932;

  final List<MainAppGuideStep> steps;
  final int currentIndex;
  final VoidCallback onSkip;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const MainAppGuideOverlay({
    super.key,
    required this.steps,
    required this.currentIndex,
    required this.onSkip,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final step = steps[currentIndex];
    final isFirst = currentIndex == 0;

    return Positioned.fill(
      child: Material(
        color: const Color(0xFFFFF7FA),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final fittedSize = _fittedGuideSize(
              Size(constraints.maxWidth, constraints.maxHeight),
            );
            final left = (constraints.maxWidth - fittedSize.width) / 2;
            final top = (constraints.maxHeight - fittedSize.height) / 2;

            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: left,
                  top: top,
                  width: fittedSize.width,
                  height: fittedSize.height,
                  child: Image.asset(
                    step.assetPath,
                    key: ValueKey(step.assetPath),
                    fit: BoxFit.fill,
                    cacheWidth: fittedSize.width.ceil(),
                    cacheHeight: fittedSize.height.ceil(),
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.low,
                    errorBuilder: (context, error, stackTrace) {
                      return const ColoredBox(
                        color: Color(0xFFFFF7FA),
                        child: Center(
                          child: Text(
                            'Unable to load guide image.',
                            style: TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  left: left,
                  top: top,
                  width: fittedSize.width,
                  height: fittedSize.height,
                  child: _GuideImageTapZones(
                    currentIndex: currentIndex,
                    isFirst: isFirst,
                    onSkip: onSkip,
                    onBack: onBack,
                    onNext: onNext,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Size _fittedGuideSize(Size bounds) {
    final widthFromHeight = bounds.height * _guideImageAspectRatio;
    if (widthFromHeight <= bounds.width) {
      return Size(widthFromHeight, bounds.height);
    }

    return Size(bounds.width, bounds.width / _guideImageAspectRatio);
  }
}

class _GuideImageTapZones extends StatelessWidget {
  final int currentIndex;
  final bool isFirst;
  final VoidCallback onSkip;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _GuideImageTapZones({
    required this.currentIndex,
    required this.isFirst,
    required this.onSkip,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final centerY = _buttonCenterY(currentIndex);

    return LayoutBuilder(
      builder: (context, constraints) {
        final buttonHeight = constraints.maxHeight * 0.105;
        final top = constraints.maxHeight * centerY - buttonHeight / 2;

        return Stack(
          children: [
            Positioned(
              left: constraints.maxWidth * 0.07,
              top: top,
              width: constraints.maxWidth * 0.30,
              height: buttonHeight,
              child: _TapZone(onTap: onSkip),
            ),
            Positioned(
              left: constraints.maxWidth * 0.35,
              top: top,
              width: constraints.maxWidth * 0.30,
              height: buttonHeight,
              child: _TapZone(onTap: isFirst ? null : onBack),
            ),
            Positioned(
              left: constraints.maxWidth * 0.63,
              top: top,
              width: constraints.maxWidth * 0.30,
              height: buttonHeight,
              child: _TapZone(onTap: onNext),
            ),
          ],
        );
      },
    );
  }

  double _buttonCenterY(int index) {
    return switch (index) {
      0 => 0.346,
      1 => 0.536,
      2 => 0.734,
      3 => 0.734,
      4 => 0.304,
      5 => 0.260,
      6 => 0.884,
      7 => 0.282,
      8 => 0.282,
      9 => 0.282,
      10 => 0.323,
      11 => 0.292,
      12 => 0.850,
      13 => 0.383,
      _ => 0.85,
    };
  }
}

class _TapZone extends StatelessWidget {
  final VoidCallback? onTap;

  const _TapZone({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: const SizedBox.expand(),
    );
  }
}

// Retained so older guide configurations can still be restored safely.
// ignore: unused_element
class _LegacyGuideCardPreview extends StatelessWidget {
  final MainAppGuideStep step;
  final int currentIndex;
  final int total;
  final VoidCallback onSkip;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _LegacyGuideCardPreview({
    required this.step,
    required this.currentIndex,
    required this.total,
    required this.onSkip,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isFirst = currentIndex == 0;
    final isLast = currentIndex == total - 1;
    return Material(
      color: Colors.white.withValues(alpha: 0.62),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 42,
                ),
                child: Align(
                  alignment: _alignmentFor(step.placement),
                  child: _GuideCard(
                    stepNumber: currentIndex + 1,
                    totalSteps: total,
                    title: step.title,
                    body: step.body,
                    previewType: step.previewType,
                    isFirst: isFirst,
                    isLast: isLast,
                    onSkip: onSkip,
                    onBack: onBack,
                    onNext: onNext,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Alignment _alignmentFor(GuideCardPlacement placement) {
    return switch (placement) {
      GuideCardPlacement.top => Alignment.topCenter,
      GuideCardPlacement.center => Alignment.center,
      GuideCardPlacement.bottom => Alignment.bottomCenter,
    };
  }
}

class _GuideCard extends StatelessWidget {
  final int stepNumber;
  final int totalSteps;
  final String title;
  final String body;
  final GuidePreviewType previewType;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onSkip;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _GuideCard({
    required this.stepNumber,
    required this.totalSteps,
    required this.title,
    required this.body,
    required this.previewType,
    required this.isFirst,
    required this.isLast,
    required this.onSkip,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 480),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GuidePreview(type: previewType),
          const SizedBox(height: 14),
          Text(
            'Step $stepNumber of $totalSteps',
            style: const TextStyle(
              color: Color(0xFF222222),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: Color(0xFF202020),
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _GuideButton(
                  label: 'Skip',
                  outlined: true,
                  onPressed: onSkip,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GuideButton(
                  label: 'Back',
                  outlined: true,
                  onPressed: isFirst ? null : onBack,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GuideButton(
                  label: isLast ? 'Done' : 'Next',
                  onPressed: onNext,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GuideButton extends StatelessWidget {
  final String label;
  final bool outlined;
  final VoidCallback? onPressed;

  const _GuideButton({
    required this.label,
    this.outlined = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(
            color: onPressed == null
                ? const Color(0xFFBBBBBB)
                : AppColors.primary,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class _GuidePreview extends StatelessWidget {
  final GuidePreviewType type;

  const _GuidePreview({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 230,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD4DE)),
      ),
      clipBehavior: Clip.antiAlias,
      child: switch (type) {
        GuidePreviewType.breedingWelcome => const _BreedingGuidePreview(
          focus: _BreedingFocus.card,
        ),
        GuidePreviewType.breedingCard => const _BreedingGuidePreview(
          focus: _BreedingFocus.details,
        ),
        GuidePreviewType.breedingLike => const _BreedingGuidePreview(
          focus: _BreedingFocus.like,
        ),
        GuidePreviewType.breedingPass => const _BreedingGuidePreview(
          focus: _BreedingFocus.pass,
        ),
        GuidePreviewType.breedingSwipe => const _BreedingGuidePreview(
          focus: _BreedingFocus.card,
        ),
        GuidePreviewType.breedingFilter => const _BreedingGuidePreview(
          focus: _BreedingFocus.filter,
        ),
        GuidePreviewType.breedingMatch => const _MatchGuidePreview(),
        GuidePreviewType.adoptionBrowse => const _AdoptionGuidePreview(
          selected: 'Browse',
        ),
        GuidePreviewType.adoptionRequest => const _AdoptionGuidePreview(
          selected: 'My Request',
        ),
        GuidePreviewType.adoptionListings => const _AdoptionGuidePreview(
          selected: 'My Listings',
        ),
        GuidePreviewType.chat => const _ChatGuidePreview(),
        GuidePreviewType.notifications => const _NotificationsGuidePreview(),
        GuidePreviewType.profile => const _ProfileGuidePreview(),
        GuidePreviewType.ready => const _ReadyGuidePreview(),
      },
    );
  }
}

enum _BreedingFocus { card, details, like, pass, filter }

class _BreedingGuidePreview extends StatelessWidget {
  final _BreedingFocus focus;

  const _BreedingGuidePreview({required this.focus});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF6FA), Color(0xFFFFE5EC)],
              ),
            ),
          ),
        ),
        Positioned(
          left: 14,
          top: 12,
          child: Row(
            children: [
              const Text(
                'Swiping as:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 8),
              _TinyPetPill(name: 'Cooper', selected: true),
              const SizedBox(width: 5),
              _TinyPetCircle(label: 'L'),
            ],
          ),
        ),
        Positioned(
          right: 14,
          top: 14,
          child: _FocusWrap(
            active: focus == _BreedingFocus.filter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Filter',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 28,
          right: 28,
          top: 70,
          bottom: 64,
          child: _FocusWrap(
            active: focus == _BreedingFocus.card,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFB98955),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF55433A), width: 1.5),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 20,
                    top: 12,
                    right: 20,
                    child: Row(
                      children: List.generate(
                        5,
                        (_) => Expanded(
                          child: Container(
                            height: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 20,
                    top: 36,
                    child: Icon(Icons.pets, color: Colors.white70, size: 44),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 13,
                    child: _FocusWrap(
                      active: focus == _BreedingFocus.details,
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Cooper',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 5),
                              Icon(
                                Icons.verified,
                                color: Color(0xFF2FA7FF),
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Text(
                                '2 years old',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 3),
                          Text(
                            'American Shih Tzu  |  Medium',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 54,
          bottom: 14,
          child: _ActionCircle(
            icon: Icons.close,
            label: 'Pass',
            active: focus == _BreedingFocus.pass,
            filled: false,
          ),
        ),
        Positioned(
          right: 54,
          bottom: 14,
          child: _ActionCircle(
            icon: Icons.favorite,
            label: 'Like',
            active: focus == _BreedingFocus.like,
            filled: true,
          ),
        ),
      ],
    );
  }
}

class _MatchGuidePreview extends StatelessWidget {
  const _MatchGuidePreview();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _FocusWrap(
        active: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TinyPetCircle(label: 'C', size: 40),
              const SizedBox(width: 6),
              const Icon(Icons.favorite, color: Colors.white, size: 24),
              const SizedBox(width: 6),
              _TinyPetCircle(label: 'P', size: 40),
              const SizedBox(width: 10),
              const Text(
                'Say Hello',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
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

class _AdoptionGuidePreview extends StatelessWidget {
  final String selected;

  const _AdoptionGuidePreview({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Adoption',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Row(
            children: ['Browse', 'My Request', 'My Listings']
                .map(
                  (tab) => Expanded(
                    child: _FocusWrap(
                      active: tab == selected,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: tab == selected
                              ? const Color(0xFFFFE0E8)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          tab,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: tab == selected
                                ? AppColors.primary
                                : const Color(0xFF777777),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                _AdoptionPetRow(name: 'Mochi', price: 'P7,000'),
                SizedBox(height: 8),
                _AdoptionPetRow(name: 'Buddy', price: 'P10,000'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatGuidePreview extends StatelessWidget {
  const _ChatGuidePreview();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chat',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Which pet?',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _FocusWrap(
            active: true,
            child: const _ChatPetRow(name: 'Luna', purpose: 'Adoption'),
          ),
        ],
      ),
    );
  }
}

class _NotificationsGuidePreview extends StatelessWidget {
  const _NotificationsGuidePreview();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notifications',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          _FocusWrap(
            active: true,
            child: const Column(
              children: [
                _NotificationMockRow(
                  title: 'Peanut liked Max',
                  chip: 'Breeding',
                ),
                SizedBox(height: 8),
                _NotificationMockRow(
                  title: 'Mia approved your request',
                  chip: 'Adoption',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileGuidePreview extends StatelessWidget {
  const _ProfileGuidePreview();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 64,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2B2B2B), Color(0xFFFFDDE8)],
            ),
          ),
        ),
        Positioned(
          left: 16,
          top: 45,
          child: _TinyPetCircle(label: 'J', size: 52),
        ),
        Positioned(
          left: 20,
          right: 20,
          top: 104,
          child: _FocusWrap(
            active: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Jane Doe',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Home information, photos, and reviews',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        const Positioned(
          right: 18,
          top: 14,
          child: Icon(Icons.settings, color: AppColors.primary),
        ),
      ],
    );
  }
}

class _ReadyGuidePreview extends StatelessWidget {
  const _ReadyGuidePreview();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: AppColors.primary, size: 58),
          SizedBox(height: 10),
          Text(
            'You are ready',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusWrap extends StatelessWidget {
  final bool active;
  final Widget child;

  const _FocusWrap({required this.active, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: EdgeInsets.all(active ? 4 : 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: active
            ? Border.all(color: AppColors.primary, width: 2.5)
            : null,
        boxShadow: active
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.22),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

class _ActionCircle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool filled;

  const _ActionCircle({
    required this.icon,
    required this.label,
    required this.active,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    return _FocusWrap(
      active: active,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: filled ? AppColors.primary : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: Icon(
              icon,
              color: filled ? Colors.white : AppColors.primary,
              size: 25,
            ),
          ),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontSize: 9)),
        ],
      ),
    );
  }
}

class _TinyPetPill extends StatelessWidget {
  final String name;
  final bool selected;

  const _TinyPetPill({required this.name, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 4, 10, 4),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFFFC9D7) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _TinyPetCircle(label: 'C', size: 28),
          const SizedBox(width: 5),
          Text(
            name,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _TinyPetCircle extends StatelessWidget {
  final String label;
  final double size;

  const _TinyPetCircle({required this.label, this.size = 30});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFFFD7E1),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: size * 0.38,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _AdoptionPetRow extends StatelessWidget {
  final String name;
  final String price;

  const _AdoptionPetRow({required this.name, required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          const _TinyPetCircle(label: 'M', size: 42),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  'Persian Cat  |  1 year',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Text(
            price,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatPetRow extends StatelessWidget {
  final String name;
  final String purpose;

  const _ChatPetRow({required this.name, required this.purpose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const _TinyPetCircle(label: 'L', size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  purpose,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Color(0xFF2FA7FF),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                '5',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationMockRow extends StatelessWidget {
  final String title;
  final String chip;

  const _NotificationMockRow({required this.title, required this.chip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE4EB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFB5C3)),
      ),
      child: Row(
        children: [
          const _TinyPetCircle(label: 'P', size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: Text(
                    chip,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
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
}
