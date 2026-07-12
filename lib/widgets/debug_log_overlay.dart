import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/debug_log_service.dart';

/// A tiny draggable floating button that opens a full-screen log view.
///
/// Wraps the entire app via HabitDrillApp.builder so it's visible on
/// every screen — home, onboarding, wake alarm, punishment, all of it.
/// Persistence-of-symptom is the whole point: the user reported crashes
/// happening across screens and had no way to see what led up to them.
///
/// Tap → opens ScrollView of every captured line.
/// Long-press → drag to reposition. Position survives navigation.
class DebugLogOverlay extends StatefulWidget {
  final Widget child;
  const DebugLogOverlay({super.key, required this.child});

  @override
  State<DebugLogOverlay> createState() => _DebugLogOverlayState();
}

class _DebugLogOverlayState extends State<DebugLogOverlay> {
  Offset _pos = const Offset(-1, -1); // sentinel — recompute after first layout

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          widget.child,
          LayoutBuilder(
            builder: (context, constraints) {
              if (_pos.dx < 0 || _pos.dy < 0) {
                _pos = Offset(
                  constraints.maxWidth - 60,
                  constraints.maxHeight - 240,
                );
              }
              return Positioned(
                left: _pos.dx,
                top: _pos.dy,
                child: _FabButton(
                  onTap: () => _openLog(context),
                  onDrag: (delta) {
                    setState(() {
                      _pos = Offset(
                        (_pos.dx + delta.dx).clamp(0, constraints.maxWidth - 44),
                        (_pos.dy + delta.dy).clamp(24, constraints.maxHeight - 44),
                      );
                    });
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _openLog(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const _LogViewer(),
      ),
    );
  }
}

class _FabButton extends StatelessWidget {
  final VoidCallback onTap;
  final ValueChanged<Offset> onDrag;
  const _FabButton({required this.onTap, required this.onDrag});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: onTap,
        onPanUpdate: (d) => onDrag(d.delta),
        behavior: HitTestBehavior.opaque,
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
