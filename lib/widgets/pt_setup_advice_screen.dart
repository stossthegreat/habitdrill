import 'package:flutter/material.dart';
import '../design/tokens.dart';

class PTSetupAdviceDialog extends StatelessWidget {
  const PTSetupAdviceDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.emerald.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // IMPORTANT header
            Text(
              'IMPORTANT',
              style: TextStyle(
                color: AppColors.emerald,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.emerald,
              ),
            ),
            const SizedBox(height: 24),

            // Advice items
            _adviceRow(Icons.phone_android, 'Place phone below hip\nheight to floor level'),
            const SizedBox(height: 16),
            _adviceRow(Icons.straighten, 'Stand 6-8 feet\naway from your phone'),
            const SizedBox(height: 16),
            _adviceRow(Icons.accessibility_new, 'Your whole body must\nbe visible — head to feet'),
            const SizedBox(height: 16),
            _adviceRow(Icons.light_mode, 'Works best with\ngood lighting'),
            const SizedBox(height: 16),

            // Camera direction
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.emerald.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.emerald.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.videocam, color: AppColors.emerald, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'FRONT — face the camera\nSIDE — place camera to your side',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Direction shown before each exercise',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Settings note
            Text(
              'Next screen: adjust skeleton, PT advice & more',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 20),

            // GOT IT button
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.emerald,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'GOT IT',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _adviceRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.emerald, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
