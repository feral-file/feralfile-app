import 'dart:async';

import 'package:autonomy_flutter/model/canvas_cast_request_reply.dart';
import 'package:autonomy_flutter/model/ff_artwork.dart';
import 'package:autonomy_flutter/nft_rendering/nft_loading_widget.dart';
import 'package:autonomy_flutter/screen/bloc/artist_artwork_display_settings/artist_artwork_display_setting_bloc.dart';
import 'package:autonomy_flutter/screen/device_setting/device_config.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/au_icons.dart';
import 'package:autonomy_flutter/util/exhibition_ext.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/range_input_formatter.dart';
import 'package:autonomy_flutter/util/series_ext.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/color_picker.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_svg/svg.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';

class ArtistDisplaySettingWidget extends StatefulWidget {
  const ArtistDisplaySettingWidget({
    required this.artwork,
    required this.artistDisplaySetting,
    required this.onSettingChanged,
    super.key,
  });

  final ArtistDisplaySetting? artistDisplaySetting;
  final void Function(ArtistDisplaySetting)? onSettingChanged;
  final Artwork? artwork;

  @override
  _ArtistDisplaySettingWidgetState createState() =>
      _ArtistDisplaySettingWidgetState();
}

class _ArtistDisplaySettingWidgetState
    extends State<ArtistDisplaySettingWidget> {
  late ArtistArtworkDisplaySettingBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = ArtistArtworkDisplaySettingBloc(
      tokenId: widget.artwork?.indexerTokenId ?? '',
    );
    _bloc.add(
      InitArtistArtworkDisplaySettingEvent(
        artistDisplaySetting: widget.artistDisplaySetting,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ArtistArtworkDisplaySettingBloc,
        ArtistArtworkDisplaySettingState>(
      bloc: _bloc,
      builder: (context, state) {
        return KeyboardVisibilityBuilder(
          builder: (context, isKeyboardVisible) {
            final shouldShowMargin = state.artistDisplaySetting?.artFraming ==
                ArtFraming.fitToScreen;
            final shouldShowBackgroundColour =
                state.artistDisplaySetting?.artFraming ==
                    ArtFraming.fitToScreen;
            final shouldShowPlayback = widget.artwork?.series?.isVideo ?? false;
            final shouldShowInteractable =
                widget.artwork?.series?.isGenerative ?? false;
            return Padding(
              padding: MediaQuery.of(context).viewInsets,
              child: Stack(
                children: [
                  CustomScrollView(
                    shrinkWrap: true,
                    slivers: [
                      SliverToBoxAdapter(
                        child: _header(context),
                      ),
                      const SliverToBoxAdapter(
                        child: Divider(
                          height: 16,
                          color: AppColor.primaryBlack,
                          thickness: 2,
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 16),
                      ),
                      SliverToBoxAdapter(
                        child: _artFramingSetting(
                          context,
                          value: state.artistDisplaySetting?.artFraming,
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 16),
                      ),
                      if (shouldShowBackgroundColour) ...[
                        SliverToBoxAdapter(
                          child: _backgroundColourSetting(
                            context,
                            value: state.artistDisplaySetting?.backgroundColour,
                          ),
                        ),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 16),
                        ),
                      ],
                      if (shouldShowMargin) ...[
                        SliverToBoxAdapter(
                          child: _marginSetting(
                            context,
                            value: state.artistDisplaySetting?.margin,
                          ),
                        ),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 16),
                        ),
                      ],
                      if (shouldShowPlayback) ...[
                        SliverToBoxAdapter(
                          child: _playbackSetting(
                            context,
                            isAutoPlay: state.artistDisplaySetting?.autoPlay,
                            isLoop: state.artistDisplaySetting?.loop,
                          ),
                        ),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 16),
                        ),
                      ],
                      if (shouldShowInteractable) ...[
                        SliverToBoxAdapter(
                          child: _interactableSetting(
                            context,
                            value: state.artistDisplaySetting?.interactable,
                          ),
                        ),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 16),
                        ),
                      ],
                      SliverToBoxAdapter(
                        child: _viewerOverrideSetting(
                          context,
                          value: state.artistDisplaySetting?.overridable,
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 100),
                      ),
                    ],
                  ),
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: _saveButton(context),
                  ),
                  if (state.artistDisplaySetting == null)
                    Positioned.fill(
                      child: Center(
                        child: LoadingWidget(
                          backgroundColor:
                              AppColor.primaryBlack.withOpacity(0.9),
                        ),
                      ),
                    )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _saveButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: PrimaryAsyncButton(
        color: Colors.transparent,
        text: 'Save',
        textColor: AppColor.white,
        borderColor: AppColor.white,
        onTap: () async {
          final completer = Completer<void>();
          _bloc.add(
            SaveArtistArtworkDisplaySettingEvent(
              seriesId: widget.artwork?.seriesID,
              onSuccess: () {
                completer.complete();
              },
              onError: (error) {
                log.info('Error saving display setting: $error');
                completer.complete();
              },
            ),
          );
          await completer.future;
        },
      ),
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Artist Display Setting',
              style: theme.textTheme.ppMori700White14,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            Navigator.of(context).pop();
          },
          child: Icon(
            AuIcon.close,
            color: AppColor.white,
            size: 24,
          ),
        ),
      ],
    );
  }

  Widget _artFramingSetting(BuildContext context, {ArtFraming? value}) {
    final selectedIndex = value == ArtFraming.fitToScreen ? 1 : 0;
    return ArtistSettingItemWidget(
      settingName: 'Fitment',
      items: [
        DeviceConfigItem(
          title: 'Fill',
          icon: SvgPicture.asset(
            'assets/images/Rec_landscape.svg',
            colorFilter: const ColorFilter.mode(
              AppColor.primaryBlack,
              BlendMode.srcIn,
            ),
          ),
          onSelected: () {
            _bloc.add(UpdateArtFramingEvent(ArtFraming.cropToFill));
          },
        ),
        DeviceConfigItem(
          title: 'Fit',
          icon: SvgPicture.asset(
            'assets/images/fitment.svg',
          ),
          onSelected: () {
            _bloc.add(UpdateArtFramingEvent(ArtFraming.fitToScreen));
          },
        ),
      ],
      selectedIndex: selectedIndex,
    );
  }

  Widget _backgroundColourSetting(BuildContext context, {Color? value}) {
    return ColorSettingWidget(
      initialColor: value ?? AppColor.primaryBlack,
      onColorChanged: (color, isSelected) {
        _bloc.add(UpdateBackgroundColourEvent(color, isSelected));
      },
    );
  }

  Widget _viewerOverrideSetting(BuildContext context, {bool? value}) {
    final selectedIndex = value == true ? 0 : 1;
    final theme = Theme.of(context);
    return ArtistSettingItemWidget(
      settingName: 'Viewer Override',
      shouldShowSelectedLabel: false,
      items: [
        DeviceConfigItem(
          title: 'Yes',
          icon: Text('Yes', style: theme.textTheme.ppMori400Black12),
          onSelected: () {
            _bloc.add(UpdateOverridableEvent(true));
          },
        ),
        DeviceConfigItem(
          title: 'No',
          icon: Text('No', style: theme.textTheme.ppMori400Black12),
          onSelected: () {
            _bloc.add(UpdateOverridableEvent(false));
          },
        ),
      ],
      selectedIndex: selectedIndex,
    );
  }

  Widget _playbackSetting(
    BuildContext context, {
    bool? isAutoPlay,
    bool? isLoop,
  }) {
    final selectedItems = <int>[];
    if (isAutoPlay == true) {
      selectedItems.add(0);
    }
    if (isLoop == true) {
      selectedItems.add(1);
    }
    final theme = Theme.of(context);
    return ArtistMultiSettingItemWidget(
      settingName: 'Playback',
      items: [
        DeviceConfigItem(
          title: 'Autoplay',
          icon: Text('Autoplay', style: theme.textTheme.ppMori400Black12),
          onSelected: () {
            _bloc.add(UpdateAutoPlayEvent(true));
          },
          onUnselected: () {
            _bloc.add(UpdateAutoPlayEvent(false));
          },
        ),
        DeviceConfigItem(
          title: 'Loop',
          icon: Text('Loop', style: theme.textTheme.ppMori400Black12),
          onSelected: () {
            _bloc.add(UpdateLoopEvent(true));
          },
          onUnselected: () {
            _bloc.add(UpdateLoopEvent(false));
          },
        ),
      ],
      selectedItems: selectedItems,
    );
  }

  Widget _interactableSetting(BuildContext context, {bool? value}) {
    final theme = Theme.of(context);
    final selectedIndex = value == true ? 0 : 1;
    return ArtistSettingItemWidget(
      settingName: 'Interactable',
      shouldShowSelectedLabel: false,
      items: [
        DeviceConfigItem(
          title: 'Enabled',
          icon: Text('Enabled', style: theme.textTheme.ppMori400Black12),
          onSelected: () {
            _bloc.add(UpdateInteractableEvent(true));
          },
        ),
        DeviceConfigItem(
          title: 'Disabled',
          icon: Text('Disabled', style: theme.textTheme.ppMori400Black12),
          onSelected: () {
            _bloc.add(UpdateInteractableEvent(false));
          },
        ),
      ],
      selectedIndex: selectedIndex,
    );
  }

  Widget _marginSetting(BuildContext context, {EdgeInsets? value}) {
    return MarginSettingWidget(
      initialMargin: value ?? EdgeInsets.zero,
      onMarginChanged: (margin) {
        _bloc.add(UpdateMarginEvent(margin));
      },
    );
  }
}

class ArtistSettingItemWidget extends StatefulWidget {
  const ArtistSettingItemWidget(
      {required this.items,
      required this.selectedIndex,
      required this.settingName,
      super.key,
      this.shouldShowSelectedLabel = true});

  final List<DeviceConfigItem> items;
  final int selectedIndex;
  final String settingName;
  final bool shouldShowSelectedLabel;

  @override
  _ArtistSettingItemWidgetState createState() =>
      _ArtistSettingItemWidgetState();
}

class _ArtistSettingItemWidgetState extends State<ArtistSettingItemWidget> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex;
  }

  @override
  void didUpdateWidget(covariant ArtistSettingItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selectedIndex = widget.selectedIndex;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedItem = widget.items[_selectedIndex];

    return Column(
      children: [
        Row(
          children: [
            Text(widget.settingName, style: theme.textTheme.ppMori400White12),
            const SizedBox(width: 8),
            if (widget.shouldShowSelectedLabel)
              Text(selectedItem.title, style: theme.textTheme.ppMori400Grey12),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 15,
            crossAxisSpacing: 15,
            childAspectRatio: 168.5 / 42,
          ),
          itemCount: widget.items.length,
          padding: EdgeInsets.zero,
          itemBuilder: (context, index) {
            final item = widget.items[index];
            final isSelected = _selectedIndex == index;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedIndex = index;
                });
                item.onSelected?.call();
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: isSelected ? AppColor.white : AppColor.disabledColor,
                ),
                child: Center(
                  child: isSelected
                      ? item.icon
                      : (item.iconOnUnselected ?? item.icon),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class ArtistMultiSettingItemWidget extends StatefulWidget {
  const ArtistMultiSettingItemWidget({
    required this.items,
    required this.selectedItems,
    required this.settingName,
    super.key,
  });

  final List<DeviceConfigItem> items;
  final List<int> selectedItems;
  final String settingName;

  @override
  State<ArtistMultiSettingItemWidget> createState() =>
      _ArtistMultiSettingItemWidgetState();
}

class _ArtistMultiSettingItemWidgetState
    extends State<ArtistMultiSettingItemWidget> {
  late List<bool> _isSelected;

  @override
  void initState() {
    super.initState();
    _isSelected = List.generate(
      widget.items.length,
      (index) => widget.selectedItems.contains(index),
    );
  }

  @override
  void didUpdateWidget(covariant ArtistMultiSettingItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _isSelected = List.generate(
      widget.items.length,
      (index) => widget.selectedItems.contains(index),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          children: [
            Text(widget.settingName, style: theme.textTheme.ppMori400White12),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 15,
            crossAxisSpacing: 15,
            childAspectRatio: 168.5 / 42,
          ),
          itemCount: widget.items.length,
          padding: EdgeInsets.zero,
          itemBuilder: (context, index) {
            final item = widget.items[index];
            final isSelected = _isSelected[index];
            return GestureDetector(
              onTap: () {
                setState(() {
                  _isSelected[index] = !isSelected;
                });
                if (_isSelected[index]) {
                  item.onSelected?.call();
                } else {
                  item.onUnselected?.call();
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: isSelected ? AppColor.white : AppColor.disabledColor,
                ),
                child: Center(
                  child: isSelected
                      ? item.icon
                      : (item.iconOnUnselected ?? item.icon),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class ColorSettingWidget extends StatefulWidget {
  const ColorSettingWidget({
    required this.onColorChanged,
    required this.initialColor,
    super.key,
  });

  final Color initialColor;

  final void Function(Color color, bool isSelected) onColorChanged;

  @override
  _ColorSettingWidgetState createState() => _ColorSettingWidgetState();
}

class _ColorSettingWidgetState extends State<ColorSettingWidget> {
  late Color _selectedColor;
  late InputTextFieldController _controller;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
    _controller = InputTextFieldController();
    _controller.text = _selectedColor.toHex();
  }

  @override
  void didUpdateWidget(covariant ColorSettingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selectedColor = widget.initialColor;
    _controller.text = _selectedColor.toHex();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Background Color',
                style: Theme.of(context).textTheme.ppMori400White12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final currentColor = _selectedColor;
                  final color = await UIHelper.showCustomDialog<Color>(
                    context: context,
                    child: ColorPickerView(
                      initialColor: _selectedColor,
                      onColorChanged: (color) {
                        widget.onColorChanged(color, true);
                      },
                    ),
                  );
                  final newColor = color ?? currentColor;
                  if (newColor != _selectedColor) {
                    setState(() {
                      _selectedColor = newColor;
                      _controller.text = newColor.toHex();
                    });
                    widget.onColorChanged(newColor, true);
                  }

                  log.info('Color: $newColor');
                },
                child: AspectRatio(
                  aspectRatio: 168.5 / 42,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: _selectedColor,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: _colorTextField(context, _selectedColor)),
          ],
        ),
      ],
    );
  }

  Widget _colorTextField(BuildContext context, Color color) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColor.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      textAlign: TextAlign.center,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^#?[0-9A-Fa-f]{0,6}$')),
        // Allows # at start + max 6 hex chars
        // LengthLimitingTextInputFormatter(7),
        // Ensures # + 6 characters max
      ],
      style: Theme.of(context).textTheme.ppMori400Black12,
      onSubmitted: (value) {
        try {
          final color = ColorExt.fromHex(value);
          setState(() {
            _selectedColor = color;
          });
          widget.onColorChanged(color, true);
        } catch (e) {
          log.info('Invalid color format: $value');
          // Handle invalid color format
        }
      },
    );
  }
}

extension ColorExt on Color {
  // Convert a color to a hex string without the alpha value
  // example: Colors.white.toHex() => '#FFFFFF'

  String toHex() {
    return '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  // Convert a hex string to a color
  // example: Color.fromHex('#FFFFFF') => Colors.white
  static Color fromHex(String hex) {
    final hexWithoutHash = hex.replaceFirst('#', '');
    final formattedHex = hexWithoutHash.padRight(6, '0');
    return Color(int.parse(formattedHex.padLeft(8, 'F'), radix: 16));
  }
}

enum MarginType { left, top, right, bottom }

class MarginSettingWidget extends StatefulWidget {
  const MarginSettingWidget({
    required this.onMarginChanged,
    required this.initialMargin,
    super.key,
  });

  final EdgeInsets initialMargin;

  final void Function(EdgeInsets margin) onMarginChanged;

  @override
  _MarginSettingWidgetState createState() => _MarginSettingWidgetState();
}

class _MarginSettingWidgetState extends State<MarginSettingWidget> {
  late EdgeInsets _selectedMargin;

  late final List<InputTextFieldController> marginControllers;
  late final List<FocusNode> marginFocusNodes;

  @override
  void initState() {
    super.initState();
    _selectedMargin = widget.initialMargin;
    marginControllers = List.generate(4, (index) => InputTextFieldController());
    marginControllers[MarginType.left.index].text =
        '${_selectedMargin.left.toInt()}%';
    marginControllers[MarginType.top.index].text =
        '${_selectedMargin.top.toInt()}%';
    marginControllers[MarginType.right.index].text =
        '${_selectedMargin.right.toInt()}%';
    marginControllers[MarginType.bottom.index].text =
        '${_selectedMargin.bottom.toInt()}%';

    marginFocusNodes = List.generate(4, (index) => FocusNode());
    marginFocusNodes.mapIndexed((index, element) {
      element.addListener(() {
        if (!element.hasFocus) {
          final value = marginControllers[index].text;
          final marginValue = double.tryParse(value) ?? 0;
          if (index == MarginType.left.index ||
              index == MarginType.right.index) {
            final newMargin = EdgeInsets.only(
              left: marginValue,
              right: marginValue,
            );
            _onMarginChanged(newMargin);
          } else {
            final newMargin = EdgeInsets.only(
              top: marginValue,
              bottom: marginValue,
            );
            _onMarginChanged(newMargin);
          }
        }
      });
    }).toList();
  }

  final icons = [
    SvgPicture.asset(
      'assets/images/margin_left.svg',
      colorFilter:
          const ColorFilter.mode(AppColor.primaryBlack, BlendMode.srcIn),
    ),
    SvgPicture.asset(
      'assets/images/margin_top.svg',
      colorFilter:
          const ColorFilter.mode(AppColor.primaryBlack, BlendMode.srcIn),
    ),
    SvgPicture.asset(
      'assets/images/margin_right.svg',
      colorFilter:
          const ColorFilter.mode(AppColor.primaryBlack, BlendMode.srcIn),
    ),
    SvgPicture.asset(
      'assets/images/margin_bottom.svg',
      colorFilter:
          const ColorFilter.mode(AppColor.primaryBlack, BlendMode.srcIn),
    ),
  ];

  @override
  void dispose() {
    for (var controller in marginControllers) {
      controller.dispose();
    }
    for (var focusNode in marginFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Margin',
                style: Theme.of(context).textTheme.ppMori400White12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 79.25 / 42,
          ),
          itemCount: 4,
          itemBuilder: (BuildContext context, int index) {
            final icon = icons[index];
            return GestureDetector(
              onTap: () {},
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AppColor.white,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 4, child: icon),
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: marginControllers[index],
                        focusNode: marginFocusNodes[index],
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColor.white,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          RangeTextInputFormatter(min: 0, max: 100),
                        ],
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.ppMori400Black12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        _slider(context),
      ],
    );
  }

  double getMarginValue() {
    if (_selectedMargin.top != 0) {
      return _selectedMargin.top * (-1);
    }
    return _selectedMargin.left;
  }

  void setMarginValue(double value) {
    var margin = _selectedMargin;
    if (value > 0) {
      final le = value.abs();
      margin = EdgeInsets.only(left: le, right: le);
    } else {
      final le = value.abs();
      margin = EdgeInsets.only(top: le, bottom: le);
    }
    _onMarginChanged(margin);
  }

  void _onMarginChanged(EdgeInsets value) {
    setState(() {
      _selectedMargin = value;
    });
    marginControllers[MarginType.left.index].text =
        '${_selectedMargin.left.toInt()}%';
    marginControllers[MarginType.top.index].text =
        '${_selectedMargin.top.toInt()}%';
    marginControllers[MarginType.right.index].text =
        '${_selectedMargin.right.toInt()}%';
    marginControllers[MarginType.bottom.index].text =
        '${_selectedMargin.bottom.toInt()}%';
    widget.onMarginChanged(_selectedMargin);
  }

  Widget _slider(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AppColor.white,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
      child: FFHorizontalSlider(
        value: getMarginValue(),
        min: -50,
        max: 50,
        interval: 50,
        onChanged: (value) {
          setMarginValue(value);
        },
      ),
    );
  }
}

class FFHorizontalSlider extends StatefulWidget {
  const FFHorizontalSlider({
    required this.min,
    required this.max,
    required this.value,
    required this.interval,
    required this.onChanged,
    super.key,
  });

  final double min;
  final double max;
  final double value;
  final double interval;
  final void Function(double) onChanged;

  @override
  _FFHorizontalSliderState createState() => _FFHorizontalSliderState();
}

class _FFHorizontalSliderState extends State<FFHorizontalSlider> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  void didUpdateWidget(covariant FFHorizontalSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    _value = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return SfSliderTheme(
      data: const SfSliderThemeData(
        activeTrackHeight: 2,
        inactiveTrackHeight: 2,
        tickSize: Size(2, 24),
        tickOffset: Offset(0, -12),
        activeTickColor: AppColor.primaryBlack,
        inactiveTickColor: AppColor.primaryBlack,
        overlayColor: Colors.green,
        overlayRadius: 0,
      ),
      child: SfSlider(
        value: _value,
        min: widget.min,
        max: widget.max,
        interval: widget.interval,
        // showTicks: true,
        activeColor: AppColor.primaryBlack,
        inactiveColor: AppColor.primaryBlack,
        showDividers: true,
        // tickShape: const CustomSfTickShape(),
        stepSize: 1,
        showTicks: true,
        onChanged: (v) {
          final value = v as double;
          setState(() {
            _value = value;
          });
          widget.onChanged(value);
        },
      ),
    );
  }
}
