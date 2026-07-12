import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/debug_log_service.dart';

/// A floating LOG chip pinned to the bottom-right of every screen.
///
/// Wrapped once at MaterialApp.builder so it is visible above every
/// route in the app — home, onboarding, wake alarm, punishment,
/// paywall, all of it.
///
/// Kept intentionally minimal after a previous variant tried to nest
/// a `Positioned` inside a `LayoutBuilder` inside a `Stack` — which
/// is illegal (Positioned must be a direct child of a Stack) and made
/// the app throw render-tree errors on every frame, blocking taps.
/// No draggability, no state mutation during build, one `Positioned`
/// child at a fixed offset.
class DebugLogOverlay extends StatelessWidget {
  final Widget child;
  const DebugLogOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      fit: StackFit.expand,
      children: [
        // The whole app — filling the Stack. StackFit.expand + no
        // Positioned means it grows to the parent's size.
        child,
        // Bottom-right, above the bottom nav bar height. Wrapped in
        // Positioned only — no LayoutBuilder — so hit testing stays
        // strictly local to the chip's own rect.
        Positioned(
          right: 12,
          bottom: 100,
          child: _LogFab(onTap: () => _openLog(context)),
        ),
      ],
    );
  }

  static void _openLog(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const _LogViewer(),
      ),
    );
  }
}

class _LogFab extends StatelessWidget {
  final VoidCallback onTap;
  const _LogFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkResponse(
        onTap: onTap,
        radius: 30,
        containedInkWell: true,
        highlightShape: BoxShape.circle,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text(
            'LOG',
            style: TextStyle(
              color: Colors.black,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _LogViewer extends StatefulWidget {
  const _LogViewer();

  @override
  State<_LogViewer> createState() => _LogViewerState();
}

class _LogViewerState extends State<_LogViewer> {
  final ScrollController _controller = ScrollController();
  final _filter = TextEditingController();
  bool _autoScroll = true;
  String _filterText = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    DebugLogService().lines.addListener(_maybeAutoScroll);
  }

  @override
  void dispose() {
    DebugLogService().lines.removeListener(_maybeAutoScroll);
    _controller.dispose();
    _filter.dispose();
    super.dispose();
  }

  void _maybeAutoScroll() {
    if (!_autoScroll) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (!_controller.hasClients) return;
    _controller.jumpTo(_controller.position.maxScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050505),
        elevation: 0,
        title: const Text(
          'DEBUG LOG',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: _autoScroll ? 'Auto-scroll on' : 'Auto-scroll off',
            icon: Icon(
              _autoScroll ? Icons.arrow_downward : Icons.stop_circle,
              color: _autoScroll ? const Color(0xFF10B981) : Colors.white54,
            ),
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy, color: Colors.white70),
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: DebugLogService().snapshot()),
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Log copied')),
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.delete_outline, color: Colors.white70),
            onPressed: () {
              DebugLogService().clear();
              setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: TextField(
              controller: _filter,
              onChanged: (v) => setState(() => _filterText = v.toLowerCase()),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0B0B0B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                hintText: 'Filter…',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.4), size: 20),
              ),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<List<String>>(
              valueListenable: DebugLogService().lines,
              builder: (context, lines, _) {
                final visible = _filterText.isEmpty
                    ? lines
                    : lines.where((l) => l.toLowerCase().contains(_filterText)).toList();
                if (visible.isEmpty) {
                  return Center(
                    child: Text(
                      lines.isEmpty ? 'No log lines yet.' : 'No lines match filter.',
                      style: TextStyle(color: Colors.white.withOpacity(0.4)),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _controller,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  itemCount: visible.length,
                  itemBuilder: (context, i) {
                    final l = visible[i];
                    final color = _colorFor(l);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: SelectableText(
                        l,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontFamily: 'Menlo',
                          height: 1.3,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _colorFor(String l) {
    final lower = l.toLowerCase();
    if (lower.contains('❌') || lower.contains('failed') || lower.contains('error')) {
      return const Color(0xFFFF6B6B);
    }
    if (lower.contains('⚠️') || lower.contains('warning')) {
      return const Color(0xFFF59E0B);
    }
    if (lower.contains('✅') || lower.contains('🔔') || lower.contains('🛎')) {
      return const Color(0xFF10B981);
    }
    return Colors.white.withOpacity(0.85);
  }
}
