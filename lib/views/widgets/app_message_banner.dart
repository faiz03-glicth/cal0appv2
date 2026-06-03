import 'package:flutter/material.dart';
import 'package:cal0appv2/views/theme/app_theme.dart';

enum MessageType { error, success, warning }

class AppMessageBanner extends StatelessWidget {
  final String message;
  final MessageType type;

  const AppMessageBanner({
    super.key,
    required this.message,
    this.type = MessageType.error,
  });

  const AppMessageBanner.error({super.key, required this.message})
    : type = MessageType.error;

  const AppMessageBanner.success({super.key, required this.message})
    : type = MessageType.success;

  const AppMessageBanner.warning({super.key, required this.message})
    : type = MessageType.warning;

  Color _color(C0Colors c) {
    switch (type) {
      case MessageType.error:
        return c.warning;
      case MessageType.success:
        return c.success;
      case MessageType.warning:
        return C0Theme.accentOrange;
    }
  }

  IconData _icon() {
    switch (type) {
      case MessageType.error:
        return Icons.error_outline;
      case MessageType.success:
        return Icons.check_circle;
      case MessageType.warning:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = C0Theme.of(context);
    final color = _color(c);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(_icon(), color: color, size: AppSizes.smallIconSize),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.caption.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
