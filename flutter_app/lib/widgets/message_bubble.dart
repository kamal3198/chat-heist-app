import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/message_model.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isSentByMe,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
  });

  final MessageModel message;
  final bool isSentByMe;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.14)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Align(
          alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isSentByMe
                  ? const Color(0xFFD9FDD3)
                  : colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.74,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: message.isImage
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(
                                message.text,
                                fit: BoxFit.cover,
                                width: 220,
                                height: 220,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 220,
                                  height: 120,
                                  alignment: Alignment.center,
                                  color: colorScheme.surfaceContainerHighest,
                                  child: const Icon(Icons.broken_image_outlined),
                                ),
                              ),
                            )
                          : Text(
                              message.text,
                              style: TextStyle(
                                fontSize: 15,
                                color: isSentByMe
                                    ? const Color(0xFF0F172A)
                                    : colorScheme.onSurface,
                              ),
                            ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat('h:mm a').format(message.sentAt.toLocal()),
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (isSentByMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            _statusIcon(message.deliveryStatus),
                            size: 16,
                            color: _statusColor(message.deliveryStatus, colorScheme),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _statusIcon(DeliveryStatus status) {
    return status == DeliveryStatus.sent ? Icons.check : Icons.done_all;
  }

  Color _statusColor(DeliveryStatus status, ColorScheme colorScheme) {
    return status == DeliveryStatus.seen
        ? const Color(0xFF34B7F1)
        : colorScheme.onSurfaceVariant;
  }
}
