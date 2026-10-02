import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final bool isPayment;

  const StatusBadge({
    super.key,
    required this.status,
    this.isPayment = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    final s = status.toLowerCase();

    if (isPayment) {
      switch (s) {
        case 'paid':
          bg = const Color(0xFF10B981).withOpacity(0.15);
          fg = const Color(0xFF34D399);
          label = 'পরিশোধিত (Paid)';
          break;
        case 'refunded':
          bg = const Color(0xFF8B5CF6).withOpacity(0.15);
          fg = const Color(0xFFA78BFA);
          label = 'রিফান্ডেড';
          break;
        case 'failed':
          bg = const Color(0xFFEF4444).withOpacity(0.15);
          fg = const Color(0xFFF87171);
          label = 'ব্যর্থ (Failed)';
          break;
        default:
          bg = const Color(0xFFF59E0B).withOpacity(0.15);
          fg = const Color(0xFFFBBF24);
          label = 'বকেয়া (COD/Pending)';
      }
    } else {
      switch (s) {
        case 'pending':
          bg = const Color(0xFFF59E0B).withOpacity(0.15);
          fg = const Color(0xFFFBBF24);
          label = 'পেন্ডিং';
          break;
        case 'processing':
          bg = const Color(0xFF3B82F6).withOpacity(0.15);
          fg = const Color(0xFF60A5FA);
          label = 'প্রসেসিং';
          break;
        case 'shipped':
        case 'in_transit':
          bg = const Color(0xFF06B6D4).withOpacity(0.15);
          fg = const Color(0xFF22D3EE);
          label = 'কুরিয়ারে চলমান';
          break;
        case 'delivered':
        case 'completed':
          bg = const Color(0xFF10B981).withOpacity(0.15);
          fg = const Color(0xFF34D399);
          label = 'ডেলিভার্ড';
          break;
        case 'cancelled':
          bg = const Color(0xFFEF4444).withOpacity(0.15);
          fg = const Color(0xFFF87171);
          label = 'বাতিল';
          break;
        case 'recovered':
          bg = const Color(0xFF10B981).withOpacity(0.15);
          fg = const Color(0xFF34D399);
          label = 'রিকভার্ড';
          break;
        case 'contacted':
          bg = const Color(0xFF3B82F6).withOpacity(0.15);
          fg = const Color(0xFF60A5FA);
          label = 'যোগাযোগকৃত';
          break;
        case 'lost':
          bg = const Color(0xFF64748B).withOpacity(0.15);
          fg = const Color(0xFF94A3B8);
          label = 'বাতিল লিড';
          break;
        default:
          bg = const Color(0xFF64748B).withOpacity(0.15);
          fg = const Color(0xFFCBD5E1);
          label = status;
      }
    }

    final isPending = s == 'pending';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPending) ...[
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: fg,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: fg.withOpacity(0.8),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
