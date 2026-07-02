import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../design/tokens.dart';
import '../models/contract.dart';
import '../services/contract_service.dart';
import '../services/analytics_service.dart';

class NewContractScreen extends StatefulWidget {
  const NewContractScreen({super.key});

  @override
  State<NewContractScreen> createState() => _NewContractScreenState();
}

class _NewContractScreenState extends State<NewContractScreen> {
  ContractTemplate? _selected;
  bool _custom = false;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _emojiController = TextEditingController(text: '🎯');
  int _customDays = 30;
  ContractType _customType = ContractType.build;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreenView('new_contract');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _emojiController.dispose();
    super.dispose();
  }

  Future<void> _sign() async {
    if (_saving) return;
    String title;
    String emoji;
    int? targetDays;
    ContractType type;

    if (_custom) {
      title = _titleController.text.trim();
      emoji = _emojiController.text.trim();
      if (title.isEmpty) return;
      if (emoji.isEmpty) emoji = '🎯';
      targetDays = _customDays > 0 ? _customDays : null;
      type = _customType;
    } else if (_selected != null) {
      title = _selected!.title;
      emoji = _selected!.emoji;
      targetDays = _selected!.targetDays;
      type = _selected!.type;
    } else {
      return;
    }

    setState(() => _saving = true);
    final contract = await ContractService.create(
      title: title,
      emoji: emoji,
      targetDays: targetDays,
      type: type,
    );
    if (!mounted) return;
    Navigator.of(context).pop(contract);
  }

  @override
  Widget build(BuildContext context) {
    final canSign = _custom
        ? _titleController.text.trim().isNotEmpty
        : _selected != null;

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onClose: () => Navigator.of(context).pop()),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Hero(custom: _custom),
                    const SizedBox(height: 28),
                    if (!_custom) ...[
                      _Divider(label: 'PRESETS'),
                      const SizedBox(height: 16),
                      ..._buildPresetTiles(),
                      const SizedBox(height: 24),
                      _CustomToggle(
                        onTap: () => setState(() {
                          _custom = true;
                          _selected = null;
                        }),
                      ),
                    ] else ...[
                      _Divider(label: 'CUSTOM CONTRACT'),
                      const SizedBox(height: 20),
                      _CustomForm(
                        titleController: _titleController,
                        emojiController: _emojiController,
                        days: _customDays,
                        type: _customType,
                        onDaysChanged: (v) => setState(() => _customDays = v),
                        onTypeChanged: (v) => setState(() => _customType = v),
                        onTitleChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => setState(() => _custom = false),
                        child: Text(
                          '← BACK TO PRESETS',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
            _SignButton(enabled: canSign && !_saving, saving: _saving, onTap: _sign),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPresetTiles() {
    return List.generate(ContractTemplate.presets.length, (i) {
      final p = ContractTemplate.presets[i];
      final selected = _selected == p;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _PresetTile(
          template: p,
          selected: selected,
          onTap: () => setState(() => _selected = p),
        ).animate(delay: (i * 40).ms).fadeIn(duration: 220.ms).slideX(begin: 0.03, end: 0),
      );
    });
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onClose;
  const _TopBar({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'DRAFT',
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close, color: Colors.white.withOpacity(0.4), size: 22),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final bool custom;
  const _Hero({required this.custom});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 22,
              decoration: BoxDecoration(
                color: AppColors.emerald,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              custom ? 'YOUR CONTRACT' : 'PICK A CONTRACT',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                height: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(left: 18),
          child: Text(
            'Signing means it is your word.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  final String label;
  const _Divider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withOpacity(0.06),
          ),
        ),
      ],
    );
  }
}

class _PresetTile extends StatelessWidget {
  final ContractTemplate template;
  final bool selected;
  final VoidCallback onTap;
  const _PresetTile({required this.template, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.emerald.withOpacity(0.1) : const Color(0xFF0B0B0B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.emerald.withOpacity(0.5)
                : Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Text(template.emoji, style: const TextStyle(fontSize: 26, height: 1)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    template.title.toUpperCase(),
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white.withOpacity(0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _typeLabel(template.type),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (selected ? AppColors.emerald : Colors.white).withOpacity(selected ? 0.15 : 0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                template.targetDays != null ? '${template.targetDays} D' : 'STREAK',
                style: TextStyle(
                  color: selected ? AppColors.emerald : Colors.white.withOpacity(0.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(ContractType t) {
    switch (t) {
      case ContractType.quit:
        return 'ABSTAIN';
      case ContractType.build:
        return 'BUILD';
      case ContractType.streak:
        return 'STREAK';
    }
  }
}

class _CustomToggle extends StatelessWidget {
  final VoidCallback onTap;
  const _CustomToggle({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.emerald.withOpacity(0.15),
              AppColors.emerald.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.emerald.withOpacity(0.35), width: 1),
        ),
        child: const Center(
          child: Text(
            '+  BUILD MY OWN',
            style: TextStyle(
              color: AppColors.emerald,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomForm extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController emojiController;
  final int days;
  final ContractType type;
  final ValueChanged<int> onDaysChanged;
  final ValueChanged<ContractType> onTypeChanged;
  final ValueChanged<String> onTitleChanged;

  const _CustomForm({
    required this.titleController,
    required this.emojiController,
    required this.days,
    required this.type,
    required this.onDaysChanged,
    required this.onTypeChanged,
    required this.onTitleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel('TITLE'),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF0B0B0B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
              ),
              alignment: Alignment.center,
              child: TextField(
                controller: emojiController,
                textAlign: TextAlign.center,
                maxLength: 2,
                style: const TextStyle(fontSize: 26, height: 1),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0B0B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
                ),
                alignment: Alignment.centerLeft,
                child: TextField(
                  controller: titleController,
                  onChanged: onTitleChanged,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'e.g. Quit Porn',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.2),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _FieldLabel('TYPE'),
        const SizedBox(height: 8),
        _TypeSelector(current: type, onChanged: onTypeChanged),
        const SizedBox(height: 22),
        _FieldLabel('DURATION'),
        const SizedBox(height: 8),
        _DurationSelector(current: days, onChanged: onDaysChanged),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withOpacity(0.45),
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 3,
      ),
    );
  }
}

class _TypeSelector extends StatelessWidget {
  final ContractType current;
  final ValueChanged<ContractType> onChanged;
  const _TypeSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: ContractType.values.map((t) {
        final selected = t == current;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: t == ContractType.values.last ? 0 : 8),
            child: GestureDetector(
              onTap: () => onChanged(t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: selected ? AppColors.emerald.withOpacity(0.15) : const Color(0xFF0B0B0B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? AppColors.emerald.withOpacity(0.5)
                        : Colors.white.withOpacity(0.05),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _label(t),
                  style: TextStyle(
                    color: selected ? AppColors.emerald : Colors.white.withOpacity(0.55),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _label(ContractType t) {
    switch (t) {
      case ContractType.quit:
        return 'ABSTAIN';
      case ContractType.build:
        return 'BUILD';
      case ContractType.streak:
        return 'STREAK';
    }
  }
}

class _DurationSelector extends StatelessWidget {
  final int current;
  final ValueChanged<int> onChanged;
  const _DurationSelector({required this.current, required this.onChanged});

  static const List<int> options = [7, 30, 60, 75, 90, 120];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((n) {
        final selected = n == current;
        return GestureDetector(
          onTap: () => onChanged(n),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? AppColors.emerald.withOpacity(0.15) : const Color(0xFF0B0B0B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? AppColors.emerald.withOpacity(0.5)
                    : Colors.white.withOpacity(0.05),
                width: 1,
              ),
            ),
            child: Text(
              '$n DAYS',
              style: TextStyle(
                color: selected ? AppColors.emerald : Colors.white.withOpacity(0.55),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                letterSpacing: 0.8,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SignButton extends StatelessWidget {
  final bool enabled;
  final bool saving;
  final VoidCallback onTap;
  const _SignButton({required this.enabled, required this.saving, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: enabled ? AppColors.emeraldGradient : null,
            color: enabled ? null : const Color(0xFF0B0B0B),
            borderRadius: BorderRadius.circular(14),
            border: enabled
                ? null
                : Border.all(color: Colors.white.withOpacity(0.05), width: 1),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.emerald.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : Text(
                  'SIGN CONTRACT',
                  style: TextStyle(
                    color: enabled ? Colors.black : Colors.white.withOpacity(0.3),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
        ),
      ),
    );
  }
}
