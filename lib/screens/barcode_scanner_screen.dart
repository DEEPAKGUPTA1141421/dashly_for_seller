import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../utils/app_colors.dart';
import '../utils/haptic_utils.dart';

/// Continuous barcode scanner — the seller can scan several items in a row
/// (a shelf of products) without the camera closing after each one, then
/// tap Done. Returns the accumulated list of distinct barcode strings; the
/// caller resolves each one against the seller's catalog and falls back to
/// "Add as Custom Item" for anything that doesn't match.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  static Future<List<String>?> show(BuildContext context) {
    return Navigator.of(context).push<List<String>>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
  }

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final List<String> _scanned = [];
  DateTime _lastDetection = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    // Debounce — the stream fires repeatedly while a code stays in frame.
    final now = DateTime.now();
    if (now.difference(_lastDetection) < const Duration(milliseconds: 600)) return;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null || value.isEmpty || _scanned.contains(value)) continue;
      _lastDetection = now;
      HapticUtils.light();
      setState(() => _scanned.add(value));
      break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // No AppBar — the camera platform view can render above it on some
      // devices, hiding the close button. Overlaying the button directly
      // inside the camera Stack guarantees it always paints on top.
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(controller: _controller, onDetect: _onDetect),
                Center(
                  child: Container(
                    width: 240, height: 160,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _OverlayButton(
                          icon: Icons.close_rounded,
                          tooltip: 'Cancel',
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const Text('Scan Items',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                        _OverlayButton(
                          icon: Icons.flash_on_rounded,
                          tooltip: 'Toggle flash',
                          onTap: () => _controller.toggleTorch(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Detected (${_scanned.length})',
                      style: const TextStyle(color: AppColors.grey, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _scanned.isEmpty
                        ? const Center(child: Text('Point the camera at a barcode', style: TextStyle(color: AppColors.greyDark, fontSize: 13)))
                        : ListView.builder(
                            itemCount: _scanned.length,
                            itemBuilder: (_, i) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(_scanned[i], style: const TextStyle(color: AppColors.white, fontSize: 13))),
                                  GestureDetector(
                                    onTap: () => setState(() => _scanned.removeAt(i)),
                                    child: const Icon(Icons.close_rounded, color: AppColors.grey, size: 16),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _scanned.isEmpty ? null : () => Navigator.of(context).pop(_scanned),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Done${_scanned.isNotEmpty ? ' (${_scanned.length})' : ''}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
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

class _OverlayButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _OverlayButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withOpacity(0.45),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}
