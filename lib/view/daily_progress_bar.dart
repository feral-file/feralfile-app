import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class ProgressBar extends StatefulWidget {
  const ProgressBar({required this.progress, super.key});

  final double progress;

  @override
  State<ProgressBar> createState() => ProgressBarState();
}

class ProgressBarState extends State<ProgressBar> {
  late double _progress;

  @override
  void initState() {
    super.initState();
    _progress = widget.progress;
  }

  @override
  void didUpdateWidget(ProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    setState(() {
      _progress = widget.progress;
    });
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 1,
        child: LinearProgressIndicator(
          value: _progress,
          backgroundColor: AppColor.greyMedium,
          valueColor: const AlwaysStoppedAnimation<Color>(AppColor.white),
        ),
      );
}

class DailyProgressBar extends StatelessWidget {
  const DailyProgressBar({
    required this.remainingDuration,
    required this.totalDuration,
    super.key,
  });

  final Duration remainingDuration;
  final Duration totalDuration;

  @override
  Widget build(BuildContext context) {
    return _progressBar(
      context,
      remainingDuration,
      totalDuration,
    );
  }

  Widget _progressBar(
    BuildContext context,
    Duration remainingDuration,
    Duration totalDuration,
  ) {
    final progress = 1 - remainingDuration.inSeconds / totalDuration.inSeconds;
    return Row(
      children: [
        Expanded(
          child: ProgressBar(
            progress: progress,
          ),
        ),
        const SizedBox(width: 32),
        Text(
          _nextDailyDurationText(remainingDuration),
          style: Theme.of(context).textTheme.ppMori400Grey12,
        ),
      ],
    );
  }

  String _nextDailyDurationText(Duration remainingDuration) {
    final hours = remainingDuration.inHours;
    if (hours > 0) {
      return 'next_daily'.tr(
        namedArgs: {
          'duration': '${hours}hr',
        },
      );
    } else {
      final minutes = remainingDuration.inMinutes;
      if (minutes <= 1) {
        return 'next_daily'.tr(
          namedArgs: {
            'duration': 'in a minute',
          },
        );
      } else {
        return 'next_daily'.tr(
          namedArgs: {
            'duration': '$minutes mins',
          },
        );
      }
    }
  }
}
