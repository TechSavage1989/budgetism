import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppAppearance {
  const AppAppearance({
    this.mode = ThemeMode.dark,
    this.accent = 0xC97367,
    this.compact = false,
    this.highContrast = false,
  });
  final ThemeMode mode;
  final int accent;
  final bool compact, highContrast;
  static const presets = <String, int>{
    'Coral': 0xC97367,
    'Ocean': 0x2878C8,
    'Forest': 0x22836A,
    'Amethyst': 0x8055B4,
    'Amber': 0xB77B16,
    'Slate': 0x52657B,
  };
  String get hex => accent.toRadixString(16).padLeft(6, '0').toUpperCase();
  AppAppearance copyWith({
    ThemeMode? mode,
    int? accent,
    bool? compact,
    bool? highContrast,
  }) => AppAppearance(
    mode: mode ?? this.mode,
    accent: accent ?? this.accent,
    compact: compact ?? this.compact,
    highContrast: highContrast ?? this.highContrast,
  );
  static int? parseAccent(String text) {
    final trimmed = text.trim();
    final value = trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
    return RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(value)
        ? int.parse(value, radix: 16)
        : null;
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'mode': mode.name,
    'accent': hex,
    'compact': compact,
    'highContrast': highContrast,
  };
  static AppAppearance read(
    SharedPreferences preferences, {
    String key = AppearancePreferences.key,
  }) {
    final legacy = AppAppearance(
      mode:
          preferences.get('appearance.theme') == 'light'
              ? ThemeMode.light
              : ThemeMode.dark,
    );
    try {
      final raw = preferences.get(key);
      if (raw is! String) return legacy;
      final value = jsonDecode(raw);
      if (value is! Map ||
          value['version'] != 1 ||
          value['compact'] is! bool ||
          value['highContrast'] is! bool ||
          value['accent'] is! String ||
          !ThemeMode.values.any((mode) => mode.name == value['mode'])) {
        return legacy;
      }
      final accent = parseAccent(value['accent'] as String);
      if (accent == null) return legacy;
      return AppAppearance(
        mode: ThemeMode.values.singleWhere(
          (mode) => mode.name == value['mode'],
        ),
        accent: accent,
        compact: value['compact'] as bool,
        highContrast: value['highContrast'] as bool,
      );
    } catch (_) {
      return legacy;
    }
  }

  ThemeData theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: Color(0xFF000000 | accent),
      brightness: brightness,
      contrastLevel: highContrast ? 1 : 0,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      cardTheme: CardThemeData(color: scheme.surfaceContainerLow, elevation: 0),
      listTileTheme: ListTileThemeData(dense: compact),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }
}

class AppearancePreferences {
  static const key = 'appearance.preferences.v1';
  Future<void> _writes = Future.value();
  Future<void> save(AppAppearance value, {String preferenceKey = key}) {
    final result = _writes.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(preferenceKey, jsonEncode(value.toJson()))) {
        throw StateError('Appearance not saved');
      }
    });
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}

class AppearanceDialog extends StatefulWidget {
  const AppearanceDialog({required this.initial, super.key});
  final AppAppearance initial;
  @override
  State<AppearanceDialog> createState() => _AppearanceDialogState();
}

class _AppearanceDialogState extends State<AppearanceDialog> {
  late AppAppearance _draft;
  late final TextEditingController _hex;
  bool _valid = true;
  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
    _hex = TextEditingController(text: _draft.hex);
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _preset(int seed) => setState(() {
    _draft = _draft.copyWith(accent: seed);
    _hex.text = _draft.hex;
    _valid = true;
  });
  @override
  Widget build(BuildContext context) {
    final brightness =
        _draft.mode == ThemeMode.system
            ? MediaQuery.platformBrightnessOf(context)
            : _draft.mode == ThemeMode.light
            ? Brightness.light
            : Brightness.dark;
    return Theme(
      data: _draft.theme(brightness),
      child: AlertDialog(
        title: const Text('Appearance and themes'),
        content: SizedBox(
          width: 530,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Preview your choices here. Apply saves appearance on this device.',
                ),
                const SizedBox(height: 16),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                      icon: Icon(Icons.settings_brightness_outlined),
                    ),
                  ],
                  selected: {_draft.mode},
                  onSelectionChanged:
                      (v) => setState(
                        () => _draft = _draft.copyWith(mode: v.single),
                      ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final preset in AppAppearance.presets.entries)
                      ChoiceChip(
                        label: Text(preset.key),
                        avatar: CircleAvatar(
                          backgroundColor: Color(0xFF000000 | preset.value),
                          radius: 8,
                        ),
                        selected: _draft.accent == preset.value,
                        onSelected: (_) => _preset(preset.value),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  key: const Key('appearance-accent'),
                  controller: _hex,
                  maxLength: 7,
                  decoration: InputDecoration(
                    labelText: 'Custom accent',
                    prefixText: '#',
                    helperText: 'Six hexadecimal digits, for example 2878C8',
                    errorText: _valid ? null : 'Enter a six-digit color.',
                  ),
                  onChanged: (text) {
                    final color = AppAppearance.parseAccent(text);
                    setState(() {
                      _valid = color != null;
                      if (color != null) {
                        _draft = _draft.copyWith(accent: color);
                      }
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Compact spacing'),
                  value: _draft.compact,
                  onChanged:
                      (v) =>
                          setState(() => _draft = _draft.copyWith(compact: v)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Higher contrast'),
                  value: _draft.highContrast,
                  onChanged:
                      (v) => setState(
                        () => _draft = _draft.copyWith(highContrast: v),
                      ),
                ),
                const Divider(),
                const Text('Preview'),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.account_balance_wallet_outlined),
                    title: const Text('Everyday account'),
                    subtitle: const Text('Recorded balance'),
                    trailing: const Text('\$1,240.00'),
                  ),
                ),
                Wrap(
                  spacing: 10,
                  children: [
                    FilledButton(
                      onPressed: () {},
                      child: const Text('Primary action'),
                    ),
                    OutlinedButton(
                      onPressed: () {},
                      child: const Text('Secondary action'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _draft = const AppAppearance();
                _hex.text = _draft.hex;
                _valid = true;
              });
            },
            child: const Text('Reset preview'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('appearance-apply'),
            onPressed: _valid ? () => Navigator.pop(context, _draft) : null,
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
