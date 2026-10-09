import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'app_strings.dart';

/// The ONE app logo: rounded gradient tile + PACER wordmark (Fugaz One).
/// Used on Loading, GetStarted, and the Home header at different sizes.
class PacerLogo extends StatelessWidget {
  final double width;
  final double fontSize;
  const PacerLogo({super.key, this.width = 198, this.fontSize = 40});

  @override
  Widget build(BuildContext context) {
    final height = width * 108 / 198;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [PacerColors.primary, PacerColors.lime],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(
        'PACER',
        style: PacerText.fugazBrand.copyWith(
          fontSize: fontSize,
          color: Colors.white,
        ),
      ),
    );
  }
}

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
      height: 166,
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
      child: Stack(
        children: [
          const Positioned(
            left: 20,
            top: 23,
            child: Icon(Icons.directions_run, size: 34, color: PacerColors.ink),
          ),
          Positioned(
            left: 62,
            top: 32,
            child: Text(date, style: PacerText.cardDate),
          ),
          Positioned(
            left: 20,
            top: 73,
            child: Text(title, style: PacerText.cardTitle),
          ),
          Positioned(
            left: 20,
            top: 98,
            child: Text(time, style: PacerText.cardTime),
          ),
          Positioned(
            left: 73,
            top: 98,
            child: Text(pace, style: PacerText.cardPace),
          ),
          Positioned(
            left: 22,
            top: 123,
            child: Text(S.time, style: PacerText.cardSub),
          ),
          Positioned(
            left: 76,
            top: 123,
            child: Text(S.pace, style: PacerText.cardSub),
          ),
          Positioned(
            left: 182,
            top: 65,
            child: Text(distance, style: PacerText.cardDistance),
          ),
          Positioned(
            left: 169,
            top: 102,
            child: Container(
              width: 156,
              height: 12.5,
              decoration: BoxDecoration(
                color: (limePill ? PacerColors.lime : PacerColors.primary)
                    .withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
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
      padding: const EdgeInsets.all(16),
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
              const SizedBox(width: 8),
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
          child: Text(
            S.seeAll,
            style: const TextStyle(color: PacerColors.ink, fontSize: 15),
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

/// Purple streak hero card 321x228 r12 (HOME audit).
class StreakCard extends StatelessWidget {
  final double width;
  final double height;
  const StreakCard({super.key, this.width = 321, this.height = 228});

  @override
  Widget build(BuildContext context) {
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: PacerColors.streakBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: 144,
              height: 144,
              decoration: BoxDecoration(
                color: const Color(0x1ADFE900),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 8,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                color: const Color(0x1A10FFA0),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Positioned(
            left: 96,
            top: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0x99343538),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: PacerColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    S.activeStreak,
                    style: PacerText.mono.copyWith(color: PacerColors.primary),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            top: 50,
            child: SizedBox(
              width: 281,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '24',
                                  style: PacerText.giantNum(56)
                                      .copyWith(color: PacerColors.streakNum),
                                ),
                                const SizedBox(width: 4),
                                Padding(
                                  padding: EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    S.daysStreak,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: PacerColors.streakLabel,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.local_fire_department,
                                    size: 11,
                                    color: Color(0xFFDFE900),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    S.personalRecord,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF090A09),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 55,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xCC292A2D),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Icon(
                          Icons.local_fire_department,
                          size: 36,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: List.generate(7, (i) {
                      final last = i == 6;
                      return Expanded(
                        child: Column(
                          children: [
                            Text(
                              dayLabels[i],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: last
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: last
                                    ? PacerColors.neon
                                    : const Color(0xFF090A09),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: PacerColors.neon,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0x5910FFA0),
                                    blurRadius: last ? 14 : 12,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.check,
                                size: 12,
                                color: Color(0xFF007144),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
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
      Icons.emoji_events_outlined,
      Icons.leaderboard_outlined,
      Icons.groups_outlined,
      Icons.local_fire_department_outlined,
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(50),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Container(
          width: 377,
          height: 80.7,
          decoration: BoxDecoration(
            color: PacerColors.bottomBar,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < 2; i++)
                SizedBox(
                  width: 50,
                  height: 49,
                  child: IconButton(
                    onPressed: () => onTap(i),
                    icon: Icon(
                      icons[i],
                      size: 30,
                      color: index == i ? PacerColors.lime : Colors.white,
                    ),
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
                  // Fugaz One 20 "START" is ~75px wide — scale to the circle
                  // instead of wrapping on narrow screens.
                  padding: const EdgeInsets.all(8),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'START',
                      style: PacerText.fugazBrand.copyWith(
                        fontSize: 20,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
              for (var i = 2; i < 4; i++)
                SizedBox(
                  width: 50,
                  height: 49,
                  child: IconButton(
                    onPressed: () => onTap(i),
                    icon: Icon(
                      icons[i],
                      size: 30,
                      color: index == i ? PacerColors.lime : Colors.white,
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

/// 98x98 circular run action (tracker audit).
class CircleAction extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final double labelSize;
  final VoidCallback? onTap;
  const CircleAction({
    super.key,
    required this.label,
    required this.bg,
    required this.fg,
    this.labelSize = 20,
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
          textAlign: TextAlign.center,
          style: PacerText.fugazBrand.copyWith(color: fg, fontSize: labelSize),
        ),
      ),
    );
  }
}

/// 98x98 circular mini-map button (tracker slot 1).
class MapCircleButton extends StatelessWidget {
  final VoidCallback? onTap;
  const MapCircleButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 98,
        height: 98,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFFE2E8F0), Color(0xFFF8FAFC)],
          ),
          border: Border.fromBorderSide(BorderSide.none),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.map_outlined, size: 36, color: PacerColors.ink),
      ),
    );
  }
}

/// Tracker stat column: bottom-aligned avatar + value + label.
class TrackerStatColumn extends StatelessWidget {
  final double avatarSize;
  final String initials;
  final String value;
  final String label;
  const TrackerStatColumn({
    super.key,
    required this.avatarSize,
    required this.initials,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InitialAvatar(initials, size: avatarSize),
        const SizedBox(height: 6),
        Text(value, style: PacerText.statValue),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w300,
            fontSize: 15,
            color: Color(0x99000000),
          ),
        ),
      ],
    );
  }
}

/// GPS pill 91x43 r30 #E5F0C5.
class GpsPill extends StatelessWidget {
  const GpsPill({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 91,
      height: 43,
      decoration: BoxDecoration(
        color: PacerColors.gpsPill,
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi, size: 20, color: Colors.black),
          SizedBox(width: 6),
          Text('GPS', style: TextStyle(fontSize: 16, color: Colors.black)),
        ],
      ),
    );
  }
}

/// Centers content in a phone-width column on wide screens (iPad/desktop).
/// Mobile-first Figma widths stay exact on phones; tablets get a centered
/// column instead of stretched or overflowing rows.
class PhoneColumn extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const PhoneColumn({super.key, required this.child, this.maxWidth = 430});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Lime summary card 329x92 r30 (finish screen).
class SummaryLimeCard extends StatelessWidget {
  final String distance;
  final String duration;
  final String pace;
  const SummaryLimeCard({
    super.key,
    this.distance = '0,00 Km',
    this.duration = '00.00',
    this.pace = "0'00''",
  });

  Widget _col(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: PacerText.statValue),
        const SizedBox(height: 14),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w300,
            fontSize: 15,
            color: Color(0x99000000),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 329,
      height: 92,
      padding: const EdgeInsets.fromLTRB(30, 18, 30, 0),
      decoration: BoxDecoration(
        color: PacerColors.lime,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _col(distance, 'Distance'),
          Container(
            width: 1,
            height: 30,
            margin: const EdgeInsets.only(left: 19, top: 13),
            color: const Color(0x40000000),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 15),
            child: _col(duration, 'Duration'),
          ),
          Container(
            width: 1,
            height: 30,
            margin: const EdgeInsets.only(left: 15, top: 13),
            color: const Color(0x40000000),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 15),
            child: _col(pace, 'Avg Pace'),
          ),
        ],
      ),
    );
  }
}

/// Metric card 329x75 r30 #FDFDFD (finish screen).
class MetricCard extends StatelessWidget {
  final String title;
  final String sub;
  final String? value;
  final String? unit;
  const MetricCard({
    super.key,
    required this.title,
    required this.sub,
    this.value,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 329,
      height: 75,
      padding: const EdgeInsets.fromLTRB(30, 16, 30, 0),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFD),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, color: PacerColors.ink),
                ),
                const SizedBox(height: 7),
                Text(
                  sub,
                  style: const TextStyle(
                    fontWeight: FontWeight.w300,
                    fontSize: 12,
                    color: Color(0x99000000),
                  ),
                ),
              ],
            ),
          ),
          if (value != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value!, style: PacerText.statValue),
                Text(
                  unit ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w300,
                    fontSize: 12,
                    color: Color(0x99000000),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Session-goal chip h32 r8 (setup screen).
class GoalChip extends StatelessWidget {
  final String label;
  final bool selected;
  const GoalChip({super.key, required this.label, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 23),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? Colors.black : const Color(0xFFC4C7C8),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : const Color(0xFF181C22),
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
