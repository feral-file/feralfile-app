import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/au_icons.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';

class ColorPickerManager {
  static const _maxHistoryColors = 5;
  static final List<Color> _historyColors = [];

  static void addHistoryColor(Color color) {
    _historyColors.remove(color);
    if (_historyColors.length >= _maxHistoryColors) {
      _historyColors.removeAt(0);
    }
    _historyColors.add(color);
  }

  static List<Color> get getHistoryColors {
    return _historyColors.reversed.toList();
  }
}

class ColorPickerView extends StatefulWidget {
  const ColorPickerView(
      {required this.onColorChanged, required this.initialColor, super.key});

  final Color initialColor;

  final void Function(Color) onColorChanged;

  @override
  _ColorPickerViewState createState() => _ColorPickerViewState();
}

class _ColorPickerViewState extends State<ColorPickerView> {
  late Color _selectedColor;

  List<Color> _historyColors = ColorPickerManager.getHistoryColors;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
  }

  @override
  void dispose() {
    ColorPickerManager.addHistoryColor(_selectedColor);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ColorPickerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selectedColor = widget.initialColor;
    _historyColors = ColorPickerManager.getHistoryColors;
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardVisibilityBuilder(builder: (context, isKeyboardVisible) {
      return Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Background Color',
                      style: Theme.of(context).textTheme.ppMori400White14),
                ),
                const SizedBox(width: 8.0),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                  child: const Icon(
                    AuIcon.close,
                    color: AppColor.white,
                    size: 22,
                  ),
                )
              ],
            ),
            addDivider(height: 40, color: AppColor.primaryBlack),
            FFColorPicker(
              pickerColor: _selectedColor,
              displayThumbColor: true,
              colorHistory: _historyColors,
              onColorChanged: (color) {
                if (!mounted) {
                  return;
                }
                setState(() {
                  _selectedColor = color;
                });
                widget.onColorChanged(color);
              },
            ),
          ],
        ),
      );
    });
  }
}

/// The default layout of Color Picker.
class FFColorPicker extends StatefulWidget {
  const FFColorPicker({
    required this.pickerColor,
    required this.onColorChanged,
    super.key,
    this.pickerHsvColor,
    this.displayThumbColor = false,
    this.colorPickerWidth = 300.0,
    this.pickerAreaHeightPercent = 1.0,
    this.pickerAreaBorderRadius = const BorderRadius.all(Radius.zero),
    this.hexInputBar = false,
    this.colorHistory,
  });

  final Color pickerColor;
  final ValueChanged<Color> onColorChanged;
  final HSVColor? pickerHsvColor;
  final bool displayThumbColor;
  final double colorPickerWidth;
  final double pickerAreaHeightPercent;
  final BorderRadius pickerAreaBorderRadius;
  final bool hexInputBar;
  final List<Color>? colorHistory;

  @override
  State<FFColorPicker> createState() => _FFColorPickerState();
}

class _FFColorPickerState extends State<FFColorPicker> {
  HSVColor currentHsvColor = const HSVColor.fromAHSV(0.0, 0.0, 0.0, 0.0);

  late final List<TextEditingController> colorControllers;

  @override
  void initState() {
    currentHsvColor = (widget.pickerHsvColor != null)
        ? widget.pickerHsvColor as HSVColor
        : HSVColor.fromColor(widget.pickerColor);

    final rgbColor = currentHsvColor.toColor();

    final redController = TextEditingController(text: rgbColor.red.toString());
    final greenController =
        TextEditingController(text: rgbColor.green.toString());
    final blueController =
        TextEditingController(text: rgbColor.blue.toString());

    colorControllers = [redController, greenController, blueController];

    final keyboardController = KeyboardVisibilityController();
    keyboardController.onChange.listen((visible) {
      if (!visible) {
        keyboardControllerListener();
      }
    });

    super.initState();
  }

  @override
  void didUpdateWidget(FFColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    currentHsvColor = (widget.pickerHsvColor != null)
        ? widget.pickerHsvColor as HSVColor
        : HSVColor.fromColor(widget.pickerColor);
    // onColorChanging(currentHsvColor);
  }

  @override
  void dispose() {
    super.dispose();
    colorControllers.forEach((controller) {
      controller.dispose();
    });
  }

  void keyboardControllerListener() {
    final red = int.tryParse(colorControllers[0].text) ?? 0;
    final green = int.tryParse(colorControllers[1].text) ?? 0;
    final blue = int.tryParse(colorControllers[2].text) ?? 0;
    final color = Color.fromARGB(255, red, green, blue);
    onColorChanging(HSVColor.fromColor(color));
  }

  void onColorChanging(HSVColor color) {
    if (mounted) {
      setState(() => currentHsvColor = color);
    }
    final rgbColor = currentHsvColor.toColor();
    colorControllers[0].text = rgbColor.red.toString();
    colorControllers[1].text = rgbColor.green.toString();
    colorControllers[2].text = rgbColor.blue.toString();
    widget.onColorChanged(rgbColor);
  }

  Widget colorPicker() {
    return ClipRRect(
      borderRadius: widget.pickerAreaBorderRadius,
      child: Padding(
        padding: const EdgeInsets.all(0),
        child: AspectRatio(
          aspectRatio: 1.0,
          child: FFColorPickerArea(
            currentHsvColor,
            onColorChanging,
          ),
        ),
      ),
    );
  }

  Widget _colorInfo(BuildContext context, Color color) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: 79.25 / 42,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColor.white,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Text(
                  'RGB',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.ppMori400Black12,
                ),
              ),
            ),
          ),
        ),
        for (int i = 0; i < 3; i++) ...[
          const SizedBox(width: 12),
          Expanded(
            child: AspectRatio(
              aspectRatio: 79.25 / 42,
              child: TextField(
                controller: colorControllers[i],
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: AppColor.white,
                  contentPadding: EdgeInsets.symmetric(horizontal: 5),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColor.white),
                    borderRadius: BorderRadius.all(Radius.circular(5)),
                  ),
                ),
                showCursor: true,
                cursorColor: AppColor.primaryBlack,
                style: theme.textTheme.ppMori400Black12,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                onChanged: (value) {},
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _recentColor(BuildContext context, List<Color> colors) {
    if (colors.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        Expanded(
          child: Text('Recent Colors',
              style: Theme.of(context).textTheme.ppMori400White12),
        ),
        const SizedBox(width: 8.0),
        ...colors.map((color) {
          return GestureDetector(
            onTap: () => onColorChanging(HSVColor.fromColor(color)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: ColorIndicator(HSVColor.fromColor(color),
                  width: 30, height: 30),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _selectButton(BuildContext context) {
    return PrimaryAsyncButton(
      onTap: () {
        Navigator.of(context).pop(currentHsvColor.toColor());
      },
      text: 'Set Background Color',
      color: Colors.transparent,
      borderColor: AppColor.white,
      textColor: AppColor.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        colorPicker(),
        const SizedBox(height: 12.0),
        _colorInfo(context, currentHsvColor.toColor()),
        const SizedBox(height: 24.0),
        if (widget.colorHistory?.isNotEmpty == true) ...[
          _recentColor(context, widget.colorHistory ?? []),
          const SizedBox(height: 24.0),
        ],
        _selectButton(context),
        const SizedBox(height: 20.0),
      ],
    );
  }
}

class FFColorPickerArea extends StatelessWidget {
  const FFColorPickerArea(
    this.hsvColor,
    this.onColorChanged, {
    super.key,
  });

  final HSVColor hsvColor;
  final ValueChanged<HSVColor> onColorChanged;

  void _handleColorRectChange(double horizontal, double vertical) {
    onColorChanged(hslToHsv(
      hsvToHsl(hsvColor)
          .withHue(horizontal * 360)
          .withLightness(vertical)
          .withSaturation(1.0),
    ));
  }

  void _handleGesture(
      Offset position, BuildContext context, double height, double width) {
    RenderBox? getBox = context.findRenderObject() as RenderBox?;
    if (getBox == null) return;

    Offset localOffset = getBox.globalToLocal(position);
    double horizontal = localOffset.dx.clamp(0.0, width);
    double vertical = localOffset.dy.clamp(0.0, height);
    _handleColorRectChange(horizontal / width, 1 - vertical / height);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        double width = constraints.maxWidth;
        double height = constraints.maxHeight;

        return RawGestureDetector(
          gestures: {
            _AlwaysWinPanGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                    _AlwaysWinPanGestureRecognizer>(
              () => _AlwaysWinPanGestureRecognizer(),
              (_AlwaysWinPanGestureRecognizer instance) {
                instance
                  ..onDown = ((details) => _handleGesture(
                      details.globalPosition, context, height, width))
                  ..onUpdate = ((details) => _handleGesture(
                      details.globalPosition, context, height, width));
              },
            ),
          },
          child: Builder(
            builder: (BuildContext _) {
              return CustomPaint(
                  painter: FFHSLWithSaturationColorPainter(hsvToHsl(hsvColor)));
            },
          ),
        );
      },
    );
  }
}

class _AlwaysWinPanGestureRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }

  @override
  String get debugDescription => 'alwaysWin';
}

/// Painter for HL mixture.
class FFHSLWithSaturationColorPainter extends CustomPainter {
  const FFHSLWithSaturationColorPainter(this.hslColor, {this.pointerColor});

  final HSLColor hslColor;
  final Color? pointerColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    const saturation = 1.0;
    final List<Color> colors = [
      const HSLColor.fromAHSL(1.0, 0.0, saturation, 0.5).toColor(),
      const HSLColor.fromAHSL(1.0, 60.0, saturation, 0.5).toColor(),
      const HSLColor.fromAHSL(1.0, 120.0, saturation, 0.5).toColor(),
      const HSLColor.fromAHSL(1.0, 180.0, saturation, 0.5).toColor(),
      const HSLColor.fromAHSL(1.0, 240.0, saturation, 0.5).toColor(),
      const HSLColor.fromAHSL(1.0, 300.0, saturation, 0.5).toColor(),
      const HSLColor.fromAHSL(1.0, 360.0, saturation, 0.5).toColor(),
    ];
    final Gradient gradientH = LinearGradient(colors: colors);
    const Gradient gradientV = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: [0.0, 0.5, 0.5, 1],
      colors: [
        Colors.white,
        Color(0x00ffffff),
        Colors.transparent,
        Colors.black,
      ],
    );
    canvas.drawRect(rect, Paint()..shader = gradientH.createShader(rect));
    canvas.drawRect(rect, Paint()..shader = gradientV.createShader(rect));

    final circleOffset = Offset(size.width * hslColor.hue / 360,
        size.height * (1 - hslColor.lightness));
    canvas.drawCircle(
      circleOffset,
      size.height * 0.04,
      Paint()
        ..color = pointerColor ??
            (useWhiteForeground(hslColor.toColor())
                ? Colors.white
                : Colors.black)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
