import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Selector de color libre: plano saturación/brillo + barra de tono + hex.
/// Hecho a mano para no añadir dependencias (la app va offline y ligera).
/// Devuelve el color elegido, o null si se cancela.
Future<Color?> showFreeColorPicker(
  BuildContext context, {
  required String title,
  required Color initial,
  String? hint,
  Widget Function(BuildContext context, Color color)? preview,
}) {
  return showModalBottomSheet<Color>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _FreeColorPicker(
      title: title,
      initial: initial,
      hint: hint,
      preview: preview,
    ),
  );
}

/// Tonos del arcoíris: la barra de tono del selector y la muestra "libre".
const hueWheelStops = [
  Color(0xFFFF0000),
  Color(0xFFFFFF00),
  Color(0xFF00FF00),
  Color(0xFF00FFFF),
  Color(0xFF0000FF),
  Color(0xFFFF00FF),
  Color(0xFFFF0000),
];

class _FreeColorPicker extends StatefulWidget {
  final String title;
  final Color initial;
  final String? hint;
  final Widget Function(BuildContext context, Color color)? preview;

  const _FreeColorPicker({
    required this.title,
    required this.initial,
    this.hint,
    this.preview,
  });

  @override
  State<_FreeColorPicker> createState() => _FreeColorPickerState();
}

class _FreeColorPickerState extends State<_FreeColorPicker> {
  late HSVColor _hsv;
  late final TextEditingController _hexField;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initial);
    _hexField = TextEditingController(text: hexOf(widget.initial));
  }

  @override
  void dispose() {
    _hexField.dispose();
    super.dispose();
  }

  Color get _color => _hsv.toColor();

  /// Cambio venido de los controles: refleja el hex sin pelearse con el
  /// cursor (solo reescribe si de verdad cambió el valor).
  void _pick(HSVColor value) {
    setState(() => _hsv = value);
    final text = hexOf(value.toColor());
    if (_hexField.text.toUpperCase() != text) _hexField.text = text;
  }

  void _onHexTyped(String raw) {
    var digits = raw.replaceAll('#', '').trim();
    if (digits.length == 3) {
      digits = digits.split('').map((c) => '$c$c').join();
    }
    if (digits.length != 6) return;
    final rgb = int.tryParse(digits, radix: 16);
    if (rgb == null) return;
    setState(() => _hsv = HSVColor.fromColor(Color(0xFF000000 | rgb)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.inkSoft,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 16),
                _SvPlane(hsv: _hsv, height: 170, onChanged: _pick),
                const SizedBox(height: 16),
                _HueBar(hsv: _hsv, onChanged: _pick),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _color,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.divider),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextField(
                        controller: _hexField,
                        onChanged: _onHexTyped,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(7),
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[#0-9a-fA-F]'),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Hex',
                          hintText: '#8A5A2B',
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.preview != null) ...[
                  const SizedBox(height: 18),
                  widget.preview!(context, _color),
                ],
                if (widget.hint != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    widget.hint!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.inkSoft,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, _color),
                      child: const Text('Usar este color'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Plano de saturación (eje X) y brillo (eje Y) del tono actual.
class _SvPlane extends StatelessWidget {
  final HSVColor hsv;
  final double height;
  final ValueChanged<HSVColor> onChanged;
  const _SvPlane({
    required this.hsv,
    required this.height,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void handle(Offset pos) {
          onChanged(
            hsv
                .withSaturation((pos.dx / width).clamp(0.0, 1.0))
                .withValue((1 - pos.dy / height).clamp(0.0, 1.0)),
          );
        }

        return GestureDetector(
          onTapDown: (d) => handle(d.localPosition),
          onPanDown: (d) => handle(d.localPosition),
          onPanUpdate: (d) => handle(d.localPosition),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white,
                            HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: hsv.saturation * width - 11,
                    top: (1 - hsv.value) * height - 11,
                    child: _Knob(color: hsv.toColor()),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HueBar extends StatelessWidget {
  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;
  const _HueBar({required this.hsv, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const height = 26.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void handle(Offset pos) {
          final t = (pos.dx / width).clamp(0.0, 1.0);
          // 360 y 0 son el mismo tono; HSVColor exige hue < 360.
          onChanged(hsv.withHue((t * 360).clamp(0.0, 359.99)));
        }

        return GestureDetector(
          onTapDown: (d) => handle(d.localPosition),
          onPanDown: (d) => handle(d.localPosition),
          onPanUpdate: (d) => handle(d.localPosition),
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(height / 2),
                      gradient: const LinearGradient(colors: hueWheelStops),
                    ),
                  ),
                ),
                Positioned(
                  left: (hsv.hue / 360) * width - 11,
                  top: height / 2 - 11,
                  child: _Knob(
                    color: HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Knob extends StatelessWidget {
  final Color color;
  const _Knob({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

/// Muestra circular de color reutilizable. Con [color] nulo se pinta el
/// arcoíris: es la muestra que abre el selector libre.
class ColorDot extends StatelessWidget {
  final Color? color;
  final String? tooltip;
  final bool selected;
  final IconData? icon;
  final Color? iconColor;
  final double size;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ColorDot({
    super.key,
    this.color,
    this.tooltip,
    this.selected = false,
    this.icon,
    this.iconColor,
    this.size = 42,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final free = color == null;
    // El icono debe leerse sobre el propio color de la muestra.
    final onDot =
        iconColor ??
        (free
            ? Colors.white
            : (ThemeData.estimateBrightnessForColor(color!) == Brightness.dark
                  ? Colors.white
                  : AppPalette.lightInk));

    Widget dot = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        gradient: free ? const SweepGradient(colors: hueWheelStops) : null,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? colors.ink : colors.divider,
          width: selected ? 2.5 : 1,
        ),
      ),
      child: selected
          ? Icon(Icons.check, size: size * 0.42, color: onDot)
          : (icon == null ? null : Icon(icon, size: size * 0.46, color: onDot)),
    );

    dot = GestureDetector(onTap: onTap, onLongPress: onLongPress, child: dot);
    return tooltip == null ? dot : Tooltip(message: tooltip!, child: dot);
  }
}

/// Vista previa del resaltado: el mismo tinte y opacidad que usa el lector.
class HighlightPreview extends StatelessWidget {
  final Color color;

  const HighlightPreview({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = context.appColors;
    final tint = customHighlightFor(
      color,
      isDark,
    ).withValues(alpha: isDark ? 0.45 : 0.40);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.divider),
      ),
      child: Text(
        'Porque de tal manera amó Dios al mundo…',
        maxLines: 2,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontSize: 16,
          background: Paint()..color = tint,
        ),
      ),
    );
  }
}
