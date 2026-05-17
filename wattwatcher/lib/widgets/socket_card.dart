import 'package:flutter/material.dart';
import '../models/socket_data.dart';
import '../theme.dart';

class SocketCard extends StatelessWidget {
  final SocketData socket;
  final VoidCallback onToggle;
  final VoidCallback onReset;
  final VoidCallback onLabelEdit;

  const SocketCard({
    super.key,
    required this.socket,
    required this.onToggle,
    required this.onReset,
    required this.onLabelEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isOverload = socket.isOverload;
    final isOn = socket.isOn && !isOverload;

    Color borderColor = AppTheme.border;
    Color bgColor = AppTheme.bg;
    if (isOverload) {
      borderColor = AppTheme.redBorder;
      bgColor = AppTheme.redDim;
    } else if (isOn) {
      borderColor = AppTheme.green;
      bgColor = AppTheme.green;
    }

    return GestureDetector(
      onLongPress: onLabelEdit,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Socket ${socket.socketId}',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isOverload)
                  _OverloadBadge()
                else
                  Switch(
                    value: isOn,
                    onChanged: (_) => onToggle(),
                    activeColor: AppTheme.textPrimary,
                    activeTrackColor: AppTheme.bg,
                    inactiveThumbColor: AppTheme.bg,
                    inactiveTrackColor: AppTheme.textMuted,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${socket.watts.toStringAsFixed(0)} W',
              style: TextStyle(
                color: isOverload
                    ? AppTheme.red
                    : isOn
                        ? AppTheme.textPrimary
                        : AppTheme.textMuted,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    isOverload
                        ? '${socket.amps.toStringAsFixed(2)}A · Tripped'
                        : socket.watts == 0
                            ? 'Empty'
                            : '${socket.amps.toStringAsFixed(2)}A · ${socket.deviceLabel}',
                    style: TextStyle(
                      color: isOverload ? Color(0xFFA05050) : AppTheme.textMuted,
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isOverload)
                  GestureDetector(
                    onTap: onReset,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.redBorder),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Reset',
                        style: TextStyle(
                          color: AppTheme.red,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
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

class _OverloadBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.redDim,
        border: Border.all(color: AppTheme.redBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppTheme.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Overload',
            style: TextStyle(
              color: AppTheme.red,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
