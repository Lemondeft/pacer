import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Blue primary CTA 315x50 r5. Subtle shadow per dump (no heavy drop).
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const PrimaryButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ElevatedButton(onPressed: onPressed, child: Text(label)),
    );
  }
}

/// White auth field 315x50 r5 with leading icon.
/// Inset shadow approximated with top inner darkening strip.
class AuthField extends StatelessWidget {
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  const AuthField({
    super.key,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.controller,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: PacerColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 8,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              style: PacerText.button,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: PacerText.hint,
                border: InputBorder.none,
                prefixIcon: Icon(icon, color: Colors.black54, size: 20),
                suffixIcon: obscure
                    ? const Icon(Icons.visibility_off_outlined, size: 20)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Run session card 329x166 r10, mint bg, shadow 0 4 4 25%.
/// Title case, distance 32 w700, pace pill bottom-right under distance.
class RunSessionCard extends StatelessWidget {
  final String title;
  final String date;
  final String time;
  final String pace;
  final String distance;
  final bool limePill;
  const RunSessionCard({
    super.key,
    this.title = 'Monday Morning Run',
    this.date = '16/7/2024',
    this.time = '15.00',
    this.pace = "5'00''",
    this.distance = '3,00 Km',
    this.limePill = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 329,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      decoration: BoxDecoration(
        color: PacerColors.runCardBg,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 4,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: PacerColors.lime,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.directions_run,
                  size: 20,
                  color: PacerColors.ink,
                ),
              ),
              const SizedBox(width: 8),
              Text(date, style: PacerText.cardDate),
            ],
          ),
          const SizedBox(height: 10),
          Text(title, style: PacerText.cardTitle),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(time, style: PacerText.cardTime),
                      const SizedBox(width: 16),
                      Text(pace, style: PacerText.cardPace),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('Time', style: PacerText.cardSub),
                      const SizedBox(width: 28),
                      Text('Pace', style: PacerText.cardSub),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(distance, style: PacerText.cardDistance),
                  const SizedBox(height: 4),
                  Container(
                    width: 100,
                    height: 8,
                    decoration: BoxDecoration(
                      color: (limePill ? PacerColors.lime : PacerColors.primary)
                          .withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Team tile — home 241x133 / clubs 329x133, r10.
/// Gradient + location pin + Fugaz name (no invented avatar).
class TeamCard extends StatelessWidget {
  final String name;
  final String location;
  final double width;
  const TeamCard({
    super.key,
    required this.name,
    required this.location,
    this.width = 241,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 133,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          colors: [Color(0xFF2B2B2B), PacerColors.streakBg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(name, style: PacerText.teamName),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on, size: 19, color: Colors.white),
              const SizedBox(width: 4),
              Expanded(child: Text(location, style: PacerText.teamLoc)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Section header row with "See all" (Outfit 500/20 + 15).
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  const SectionHeader({super.key, required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 20),
        ),
        TextButton(
          onPressed: onSeeAll,
          child: const Text(
            'See all',
            style: TextStyle(color: PacerColors.ink, fontSize: 15),
          ),
        ),
      ],
    );
  }
}

/// Outfit 800/32 page title.
class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) => Text(title, style: PacerText.pageTitle);
}

/// 48x48 back circle + optional Fugaz title.
class PageHeader extends StatelessWidget {
  final String? title;
  const PageHeader({super.key, this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: const BackButton(color: PacerColors.ink),
        ),
        if (title != null) ...[
          const SizedBox(width: 12),
          Text(title!, style: PacerText.fugazBrand),
        ],
      ],
    );
  }
}

/// Initials avatar replacing all photo avatars (copyright-free).
class InitialAvatar extends StatelessWidget {
  final String initials;
  final double size;
  const InitialAvatar(this.initials, {super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF2C2C2C),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(color: Colors.white, fontSize: size * 0.4),
      ),
    );
  }
}

/// Purple streak hero card (home).
class StreakCard extends StatelessWidget {
  final double width;
  final double height;
  const StreakCard({super.key, this.width = 329, this.height = 228});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PacerColors.streakBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'ACTIVE STREAK',
                style: PacerText.mono.copyWith(color: Colors.white),
              ),
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: PacerColors.neon,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '24',
                style: PacerText.giantNum(56)
                    .copyWith(color: PacerColors.streakNum),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'DAYS STREAK',
                  style: TextStyle(
                    color: PacerColors.streakLabel,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const Text(
            'Personal Record • Best since Nov 2024',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              7,
              (i) => Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: i < 5 ? PacerColors.neon : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: PacerColors.neon),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating dark blurred nav pill 377x80.7 r50 + central START circle.
class BottomNavPill extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onStart;
  const BottomNavPill({
    super.key,
    required this.index,
    required this.onTap,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    const icons = [
      Icons.home_outlined,
      Icons.route_outlined,
      Icons.groups_outlined,
      Icons.leaderboard_outlined,
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(50),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Container(
          width: 377,
          height: 80,
          decoration: BoxDecoration(
            color: PacerColors.bottomBar,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < 2; i++)
                IconButton(
                  onPressed: () => onTap(i),
                  icon: Icon(
                    icons[i],
                    color: index == i ? PacerColors.lime : Colors.white,
                  ),
                ),
              GestureDetector(
                onTap: onStart,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(
                    color: PacerColors.primary,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'START',
                    style: PacerText.cardTitle.copyWith(color: Colors.white),
                  ),
                ),
              ),
              for (var i = 2; i < 4; i++)
                IconButton(
                  onPressed: () => onTap(i),
                  icon: Icon(
                    icons[i],
                    color: index == i ? PacerColors.lime : Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 98x98 circular run action.
class CircleAction extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback? onTap;
  const CircleAction({
    super.key,
    required this.label,
    required this.bg,
    required this.fg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 98,
        height: 98,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(
            color: PacerColors.lime,
            width: bg == Colors.white ? 2 : 0,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: PacerText.cardTitle.copyWith(color: fg, fontSize: 20),
        ),
      ),
    );
  }
}

/// Lime action bar 329x48 r10.
class LimeActionBar extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const LimeActionBar(this.label, {super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 329,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: PacerColors.lime,
          foregroundColor: PacerColors.ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
    );
  }
}

/// Clubs search field 358 r12 #F8FAFC.
class SearchField extends StatelessWidget {
  final String hint;
  const SearchField({super.key, this.hint = 'Cari klub, kota, atau teman...'});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 358,
      child: TextField(
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: PacerColors.slate400, fontSize: 14),
          prefixIcon: const Icon(Icons.search, size: 14),
          filled: true,
          fillColor: PacerColors.slate50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: PacerColors.slate200),
          ),
        ),
      ),
    );
  }
}

/// Gradient grid replacing all map/photo fills.
class MapPlaceholder extends StatelessWidget {
  final double height;
  final String label;
  const MapPlaceholder({
    super.key,
    this.height = 180,
    this.label = 'Peta rute — placeholder bebas hak cipta',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: PacerColors.navy,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.route, color: PacerColors.lime, size: 40),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
