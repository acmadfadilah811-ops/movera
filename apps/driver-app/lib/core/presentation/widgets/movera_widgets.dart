import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/movera_colors.dart';

TextStyle moveraText({double size = 14, FontWeight weight = FontWeight.w500, Color color = MoveraColors.text, double? height}) =>
    GoogleFonts.poppins(fontSize: size, fontWeight: weight, color: color, height: height);

class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(text.toUpperCase(),
                style: moveraText(size: 11, weight: FontWeight.w600, color: MoveraColors.textFaint).copyWith(letterSpacing: 1)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class MoveraCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool highlighted;

  const MoveraCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: MoveraColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlighted ? MoveraColors.accent.withValues(alpha: 0.35) : MoveraColors.border,
          width: highlighted ? 1.4 : 1,
        ),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: card);
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  const PrimaryButton({super.key, required this.label, this.onPressed, this.busy = false, this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: MoveraColors.accent,
          foregroundColor: MoveraColors.onAccent,
          disabledBackgroundColor: MoveraColors.accent.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.black))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
                  Text(label, style: moveraText(size: 16, weight: FontWeight.w700, color: MoveraColors.onAccent)),
                ],
              ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;

  const SecondaryButton({super.key, required this.label, this.onPressed, this.color = MoveraColors.text, this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
            Text(label, style: moveraText(size: 14, weight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const StatusChip(this.label, {super.key, this.color = MoveraColors.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: moveraText(size: 11, weight: FontWeight.w600, color: color)),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 48, color: MoveraColors.textFaint),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: moveraText(size: 16, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: moveraText(size: 13, color: MoveraColors.textMuted, height: 1.5)),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}

/// Bilah sisa kuota: bagian terpakai, dicadangkan, dan sisa.
class QuotaBar extends StatelessWidget {
  final int total;
  final int reserved;
  final int consumed;
  const QuotaBar({super.key, required this.total, required this.reserved, required this.consumed});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final Color c;
        if (i < consumed) {
          c = MoveraColors.textFaint;
        } else if (i < consumed + reserved) {
          c = MoveraColors.accent.withValues(alpha: 0.45);
        } else {
          c = MoveraColors.accent;
        }
        return Expanded(
          child: Container(
            height: 8,
            margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
          ),
        );
      }),
    );
  }
}

void showMoveraSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message, style: moveraText(size: 13, color: error ? Colors.white : Colors.black)),
      backgroundColor: error ? MoveraColors.danger : MoveraColors.accent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
}
