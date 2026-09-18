import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// SWeShare Interactive Card: Crisp white surface, soft ice-blue border,
/// subtle blue-tinted shadow, and smooth hover/press scale animation.
class EmpiranCard extends StatefulWidget {
  const EmpiranCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
    this.borderColor,
    this.borderRadius,
    this.elevation = 0,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final BorderRadius? borderRadius;
  final double elevation;
  final Gradient? gradient;

  @override
  State<EmpiranCard> createState() => _EmpiranCardState();
}

class _EmpiranCardState extends State<EmpiranCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final r = widget.borderRadius ?? BorderRadius.circular(AppRadii.large);

    final cardContent = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      margin: widget.margin,
      transform: widget.onTap != null
          ? Matrix4.diagonal3Values(
              _isPressed ? 0.985 : (_isHovered ? 1.012 : 1.0),
              _isPressed ? 0.985 : (_isHovered ? 1.012 : 1.0),
              1.0,
            )
          : Matrix4.identity(),
      decoration: BoxDecoration(
        color: widget.gradient == null
            ? (widget.color ??
                (isDark
                    ? AppColors.darkSurfaceContainer
                    : AppColors.lightSurface))
            : null,
        gradient: widget.gradient,
        borderRadius: r,
        border: Border.all(
          color: _isHovered && widget.onTap != null
              ? AppColors.primary.withValues(alpha: 0.6)
              : (widget.borderColor ??
                  (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
          width: 1.2,
        ),
        boxShadow: [
          if (_isHovered && widget.onTap != null)
            BoxShadow(
              color: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12),
              blurRadius: 20,
              offset: const Offset(0, 6),
            )
          else if (widget.elevation > 0)
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : const Color(0x0E007F73),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          else
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.15)
                  : const Color(0x06007F73),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: r,
        child: InkWell(
          borderRadius: r,
          splashColor: AppColors.primary.withValues(alpha: 0.08),
          highlightColor: AppColors.primary.withValues(alpha: 0.04),
          onTap: widget.onTap,
          onTapDown: widget.onTap != null
              ? (_) => setState(() => _isPressed = true)
              : null,
          onTapUp: widget.onTap != null
              ? (_) => setState(() => _isPressed = false)
              : null,
          onTapCancel: widget.onTap != null
              ? () => setState(() => _isPressed = false)
              : null,
          child: Padding(
            padding: widget.padding ?? const EdgeInsets.all(AppSpacing.x5),
            child: widget.child,
          ),
        ),
      ),
    );

    if (widget.onTap == null) return cardContent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: cardContent,
    );
  }
}

/// SWeShare Action Button: Vibrant royal blue, smooth rounded squircle,
/// optional right arrow or icon, press micro-animation and loading spinner.
class EmpiranButton extends StatefulWidget {
  const EmpiranButton({
    super.key,
    required this.label,
    this.icon,
    this.trailingIcon,
    this.onPressed,
    this.isLoading = false,
    this.isFullWidth = false,
    this.variant = EmpiranButtonVariant.primary,
    this.height = 48,
    this.borderRadius,
  });

  final String label;
  final IconData? icon;
  final IconData? trailingIcon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;
  final EmpiranButtonVariant variant;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<EmpiranButton> createState() => _EmpiranButtonState();
}

class _EmpiranButtonState extends State<EmpiranButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color bg;
    Color fg;
    BorderSide side = BorderSide.none;
    List<BoxShadow> shadows = [];

    switch (widget.variant) {
      case EmpiranButtonVariant.primary:
        bg = AppColors.primary;
        fg = Colors.white;
        shadows = [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ];
        break;
      case EmpiranButtonVariant.secondary:
        bg = isDark
            ? AppColors.darkSurfaceContainerHighest
            : AppColors.primarySubtle;
        fg = AppColors.primary;
        side = BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorderStrong);
        break;
      case EmpiranButtonVariant.outlined:
        bg = Colors.transparent;
        fg = AppColors.primary;
        side = const BorderSide(color: AppColors.primary, width: 1.5);
        break;
      case EmpiranButtonVariant.danger:
        bg = AppColors.error;
        fg = Colors.white;
        shadows = [
          BoxShadow(
            color: AppColors.error.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ];
        break;
      case EmpiranButtonVariant.ghost:
        bg = Colors.transparent;
        fg = AppColors.primary;
        break;
    }

    final effectiveRadius =
        widget.borderRadius ?? BorderRadius.circular(AppRadii.medium);

    final childWidget = widget.isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          )
        : Row(
            mainAxisSize:
                widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18, color: fg),
                const SizedBox(width: AppSpacing.x2),
              ],
              Text(
                widget.label,
                style: AppTypography.button.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              if (widget.trailingIcon != null) ...[
                const SizedBox(width: AppSpacing.x2),
                Icon(widget.trailingIcon, size: 18, color: fg),
              ],
            ],
          );

    return AnimatedScale(
      scale: _isPressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: Container(
        height: widget.height,
        width: widget.isFullWidth ? double.infinity : null,
        decoration: BoxDecoration(
          borderRadius: effectiveRadius,
          boxShadow:
              widget.onPressed != null && !widget.isLoading ? shadows : null,
        ),
        child: Material(
          color: widget.onPressed == null ? bg.withValues(alpha: 0.5) : bg,
          shape: RoundedRectangleBorder(
            borderRadius: effectiveRadius,
            side: side,
          ),
          child: InkWell(
            borderRadius: effectiveRadius,
            onTapDown: widget.onPressed != null
                ? (_) => setState(() => _isPressed = true)
                : null,
            onTapUp: widget.onPressed != null
                ? (_) => setState(() => _isPressed = false)
                : null,
            onTapCancel: widget.onPressed != null
                ? () => setState(() => _isPressed = false)
                : null,
            onTap: widget.isLoading ? null : widget.onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x5),
              child: Center(child: childWidget),
            ),
          ),
        ),
      ),
    );
  }
}

enum EmpiranButtonVariant { primary, secondary, outlined, danger, ghost }

/// SWeShare Form Input Field: Clean, rounded borders with focus highlights
/// and support for split prefixes like phone country codes (+91).
class EmpiranTextField extends StatelessWidget {
  const EmpiranTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.prefixWidget,
    this.suffixIcon,
    this.isRequired = false,
    this.isNumber = false,
    this.isDecimal = false,
    this.obscureText = false,
    this.maxLines = 1,
    this.onChanged,
    this.validator,
    this.enabled = true,
    this.initialValue,
    this.helperText,
    this.focusNode,
  });

  final TextEditingController? controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? prefixWidget;
  final Widget? suffixIcon;
  final bool isRequired;
  final bool isNumber;
  final bool isDecimal;
  final bool obscureText;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final String? initialValue;
  final String? helperText;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isRequired)
                  const Text(
                    ' *',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          initialValue: initialValue,
          obscureText: obscureText,
          enabled: enabled,
          maxLines: maxLines,
          keyboardType: isNumber
              ? TextInputType.numberWithOptions(
                  decimal: isDecimal, signed: false)
              : TextInputType.text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color:
                isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            helperText: helperText,
            prefixIcon: prefixWidget ??
                (prefixIcon != null ? Icon(prefixIcon, size: 20) : null),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: isDark
                ? AppColors.darkSurfaceContainer
                : AppColors.lightSurface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.medium),
              borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.medium),
              borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.medium),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.8),
            ),
          ),
          onChanged: onChanged,
          validator: validator,
        ),
      ],
    );
  }
}

/// SWeShare Step Progress Stepper (1)-(2)-(3)
class SWeShareStepIndicator extends StatelessWidget {
  const SWeShareStepIndicator({
    super.key,
    required this.currentStep,
    this.totalSteps = 3,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalSteps * 2 - 1, (index) {
        if (index.isOdd) {
          final stepBefore = index ~/ 2 + 1;
          final isCompleted = currentStep > stepBefore;
          return Container(
            width: 32,
            height: 2,
            color: isCompleted ? AppColors.primary : const Color(0xFFDCE6F5),
          );
        }

        final step = index ~/ 2 + 1;
        final isActive = currentStep == step;
        final isPassed = currentStep > step;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (isActive || isPassed)
                ? AppColors.primary
                : const Color(0xFFF1F5F9),
            border: Border.all(
              color: (isActive || isPassed)
                  ? AppColors.primary
                  : const Color(0xFFCBD5E1),
              width: 1.5,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Center(
            child: isPassed
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    '$step',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: (isActive || isPassed)
                          ? Colors.white
                          : const Color(0xFF64748B),
                    ),
                  ),
          ),
        );
      }),
    );
  }
}

/// SWeShare Search bar with icon, debounce, and clean white floating design.
class EmpiranSearchBar extends StatefulWidget {
  const EmpiranSearchBar({
    super.key,
    required this.hint,
    required this.onChanged,
    this.initialValue = '',
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final String initialValue;

  @override
  State<EmpiranSearchBar> createState() => _EmpiranSearchBarState();
}

class _EmpiranSearchBarState extends State<EmpiranSearchBar> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainer : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08007F73),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        onChanged: (v) {
          setState(() {});
          widget.onChanged(v);
        },
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          hintText: widget.hint,
          prefixIcon: Icon(
            Icons.search,
            size: 22,
            color: isDark ? AppColors.darkTextMuted : AppColors.primary,
          ),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _controller.clear();
                    setState(() {});
                    widget.onChanged('');
                  },
                )
              : null,
        ),
      ),
    );
  }
}

/// SWeShare Semantic Status Chip
class EmpiranStatusChip extends StatelessWidget {
  const EmpiranStatusChip({
    super.key,
    required this.label,
    this.icon,
    this.type = EmpiranStatusType.neutral,
    this.small = false,
  });

  final String label;
  final IconData? icon;
  final EmpiranStatusType type;
  final bool small;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color border;

    switch (type) {
      case EmpiranStatusType.success:
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF047857);
        border = const Color(0xFFA7F3D0);
        break;
      case EmpiranStatusType.warning:
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFFB45309);
        border = const Color(0xFFFDE68A);
        break;
      case EmpiranStatusType.error:
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFB91C1C);
        border = const Color(0xFFFECACA);
        break;
      case EmpiranStatusType.info:
        bg = AppColors.primarySubtle;
        fg = AppColors.primary;
        border = const Color(0xFFBAE6FD);
        break;
      case EmpiranStatusType.neutral:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        border = const Color(0xFFCBD5E1);
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 12,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: small ? 12 : 14, color: fg),
            SizedBox(width: small ? 4 : 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: small ? 11 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

enum EmpiranStatusType { success, warning, error, info, neutral }

/// SWeShare Modern Stat Card: Crisp white card with soft blue icon container,
/// bold typography, and trend chip.
class EmpiranStatCard extends StatelessWidget {
  const EmpiranStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor = AppColors.primary,
    this.badgeText,
    this.badgeType = EmpiranStatusType.info,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final String? badgeText;
  final EmpiranStatusType badgeType;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return EmpiranCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceContainerHighest
                      : AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorderStrong,
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              if (badgeText != null)
                Flexible(
                  child: EmpiranStatusChip(
                      label: badgeText!, type: badgeType, small: true),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTypography.number.copyWith(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// SWeShare Feature Card: Module launcher with vibrant icon & arrow.
class EmpiranFeatureCard extends StatelessWidget {
  const EmpiranFeatureCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.accentColor = AppColors.primary,
    this.statBadge,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final String? statBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return EmpiranCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceContainerHighest
                      : AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                ),
                child: Icon(icon, color: accentColor, size: 26),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceContainer
                      : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (statBadge != null) ...[
            const SizedBox(height: AppSpacing.x2),
            Text(
              statBadge!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// SWeShare Real-time Sync Indicator
class EmpiranSyncIndicator extends StatelessWidget {
  const EmpiranSyncIndicator({
    super.key,
    required this.isOnline,
    required this.isSyncing,
    this.pendingCount = 0,
    this.onTap,
  });

  final bool isOnline;
  final bool isSyncing;
  final int pendingCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? AppColors.primary : AppColors.offline;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSyncing)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )
            else
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            const SizedBox(width: 6),
            Text(
              isSyncing
                  ? 'Syncing…'
                  : isOnline
                      ? (pendingCount > 0 ? '$pendingCount pending' : 'Online')
                      : 'Offline',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// SWeShare Empty State Container
class EmpiranEmptyState extends StatelessWidget {
  const EmpiranEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String description;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceContainerHighest
                    : AppColors.primarySubtle,
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    width: 1.5),
              ),
              child: Icon(
                icon,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            Text(
              title,
              style: AppTypography.titleLarge.copyWith(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                description,
                style: AppTypography.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.x6),
              EmpiranButton(
                label: actionLabel!,
                icon: Icons.add,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// SWeShare Error State Container
class EmpiranErrorState extends StatelessWidget {
  const EmpiranErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.isOffline = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOffline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
              size: 48,
              color: isOffline ? AppColors.offline : AppColors.error,
            ),
            const SizedBox(height: AppSpacing.x3),
            Text(
              isOffline ? 'You\'re offline' : 'Unable to complete request',
              style: AppTypography.titleLarge
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              isOffline
                  ? 'Displaying locally saved data. Connect to the internet to sync.'
                  : message,
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.x4),
              EmpiranButton(
                label: 'Retry',
                icon: Icons.refresh,
                variant: EmpiranButtonVariant.secondary,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// High-Performance Animated Shimmer for SWeShare skeleton loading
class EmpiranShimmer extends StatefulWidget {
  const EmpiranShimmer({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  });

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  @override
  State<EmpiranShimmer> createState() => _EmpiranShimmerState();
}

class _EmpiranShimmerState extends State<EmpiranShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        isDark ? const Color(0xFF18223B) : const Color(0xFFE8F2FD);
    final highlightColor =
        isDark ? const Color(0xFF26375E) : const Color(0xFFFFFFFF);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius:
                widget.borderRadius ?? BorderRadius.circular(AppRadii.medium),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: [
                (_ctrl.value - 0.3).clamp(0.0, 1.0),
                _ctrl.value,
                (_ctrl.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Reusable Shimmer Loading Skeletons
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return EmpiranShimmer(
      width: width,
      height: height,
      borderRadius: borderRadius ?? BorderRadius.circular(6),
    );
  }
}

class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key, this.height = 96});
  final double height;

  @override
  Widget build(BuildContext context) {
    return EmpiranCard(
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              children: [
                const EmpiranShimmer(width: 40, height: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerBox(width: 120, height: 14),
                      SizedBox(height: 6),
                      ShimmerBox(width: 80, height: 12),
                    ],
                  ),
                ),
              ],
            ),
            const ShimmerBox(width: double.infinity, height: 12),
          ],
        ),
      ),
    );
  }
}

class ShimmerStatsGrid extends StatelessWidget {
  const ShimmerStatsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.4,
      crossAxisSpacing: AppSpacing.x4,
      mainAxisSpacing: AppSpacing.x4,
      children: List.generate(4, (_) => const ShimmerCard(height: 100)),
    );
  }
}

/// SWeShare Section Header with title, subtitle, and action
class EmpiranSectionHeader extends StatelessWidget {
  const EmpiranSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Responsive Page Header & Shell Frame
class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  final String title, subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 650;
        final hPadding = isCompact ? 14.0 : 20.0;
        final vPadding = isCompact ? 12.0 : 18.0;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: vPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isCompact) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
                if (action != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: action!,
                    ),
                  ),
                ],
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (action != null) ...[
                      const SizedBox(width: 12),
                      action!,
                    ],
                  ],
                ),
              ],
              SizedBox(height: isCompact ? 12 : 18),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}
