import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';

/// Reusable frosted glass AppBar with thin bottom border and system status bar compatibility
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool automaticallyImplyLeading;
  final Widget? leading;
  final double? titleSpacing;
  final bool centerTitle;

  const GlassAppBar({
    super.key,
    this.title,
    this.actions,
    this.bottom,
    this.automaticallyImplyLeading = true,
    this.leading,
    this.titleSpacing,
    this.centerTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: AppBar(
          backgroundColor: isDark
              ? AppColors.bgDark.withValues(alpha: 0.65)
              : AppColors.bgLight.withValues(alpha: 0.7),
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: automaticallyImplyLeading,
          leading: leading,
          title: title,
          actions: actions,
          titleSpacing: titleSpacing,
          centerTitle: centerTitle,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          ),
          bottom: bottom != null
              ? _PreferredSizeWidgetWithBorder(
                  bottom: bottom!,
                  isDark: isDark,
                )
              : PreferredSize(
                  preferredSize: const Size.fromHeight(0.5),
                  child: Container(
                    height: 0.5,
                    color: isDark
                        ? AppColors.glassBorderDark
                        : AppColors.glassBorderLight,
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0.0),
      );
}

class _PreferredSizeWidgetWithBorder extends StatelessWidget
    implements PreferredSizeWidget {
  final PreferredSizeWidget bottom;
  final bool isDark;

  const _PreferredSizeWidgetWithBorder({
    required this.bottom,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        bottom,
        Container(
          height: 0.5,
          color: isDark
              ? AppColors.glassBorderDark
              : AppColors.glassBorderLight,
        ),
      ],
    );
  }

  @override
  Size get preferredSize => bottom.preferredSize;
}
