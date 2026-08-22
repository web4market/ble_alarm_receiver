import 'package:flutter/material.dart';
import '../models/detector_model.dart';
import '../theme/app_theme.dart';

const _kFadeDuration   = Duration(seconds: 90);
const _kBorderAlarm    = Color(0xFFCC2222);
const _kBorderSelected = Color(0xFF4FC3F7);

class DetectorTile extends StatefulWidget {
  final DetectorModel detector;
  final int number;
  final bool alarmBorderActive;
  final DateTime? alarmStartTime;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onResetAlarm;

  const DetectorTile({
    super.key,
    required this.detector,
    required this.number,
    required this.alarmBorderActive,
    this.alarmStartTime,
    this.isSelected = false,
    this.onTap,
    this.onResetAlarm,
  });

  @override
  State<DetectorTile> createState() => _DetectorTileState();
}

class _DetectorTileState extends State<DetectorTile>
    with TickerProviderStateMixin {
  late final AnimationController _fade =
      AnimationController(vsync: this, duration: _kFadeDuration);

  @override
  void initState() {
    super.initState();
    _syncAlarm(null, widget.detector.status);
  }

  @override
  void didUpdateWidget(DetectorTile old) {
    super.didUpdateWidget(old);
    if (old.detector.status != widget.detector.status) {
      _syncAlarm(old.detector.status, widget.detector.status);
    }
  }

  void _syncAlarm(DetectorStatus? prev, DetectorStatus next) {
    if (next == DetectorStatus.alarm) {
      if (widget.alarmStartTime != null) {
        final elapsed =
            DateTime.now().difference(widget.alarmStartTime!).inMilliseconds;
        _fade.value =
            (elapsed / _kFadeDuration.inMilliseconds).clamp(0.0, 1.0);
      } else {
        _fade.value = 0;
      }
      if (_fade.value < 1.0) _fade.forward();
    } else if (prev == DetectorStatus.alarm) {
      _fade.stop();
      _fade.value = 0;
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  // ── Colors (theme-aware) ──────────────────────────────────────────────────

  Color _bg(AppColors c) {
    final d = widget.detector;
    if (!d.isActive || d.status == DetectorStatus.offline) return c.tileBgOff;
    if (!d.isArmed || d.status == DetectorStatus.off) return c.tileBgDisarmed;
    if (d.status == DetectorStatus.alarm) {
      return Color.lerp(c.tileBgAlarm, c.tileBgNormal, _fade.value)!;
    }
    if (d.status == DetectorStatus.lowBattery) return c.tileBgBattery;
    return c.tileBgNormal;
  }

  Color _border(AppColors c) {
    if (widget.isSelected) return _kBorderSelected;
    if (widget.alarmBorderActive) return _kBorderAlarm;
    final d = widget.detector;
    if (!d.isArmed || !d.isActive) return c.tileBorderDisarmed;
    return c.tileBorderNormal;
  }

  Color _numColor(AppColors c) {
    final d = widget.detector;
    if (!d.isArmed || !d.isActive) return c.tileTextDim;
    if (d.status == DetectorStatus.alarm) {
      return Color.lerp(const Color(0xFFFF6666), c.tileText, _fade.value)!;
    }
    return c.tileText;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return AnimatedBuilder(
      animation: _fade,
      builder: (ctx, _) => GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: _bg(c),
            border: Border.all(
              color: _border(c),
              width: widget.isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(children: [
            // Zone label — top left
            Positioned(
              top: 6, left: 8, right: 28,
              child: Text(
                'Зона ${widget.detector.zone}',
                style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w600,
                  color: c.tileText, letterSpacing: 0.4,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Reset button — top right
            if (widget.alarmBorderActive)
              Positioned(
                top: 3, right: 3,
                child: GestureDetector(
                  onTap: widget.onResetAlarm,
                  child: Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(
                      color: _kBorderAlarm.withOpacity(0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        size: 11, color: Color(0xFFFF8888)),
                  ),
                ),
              ),

            // Big number — center
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${widget.number}',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: _numColor(c),
                    height: 1,
                  ),
                ),
              ),
            ),

            // Type + ID — bottom left
            Positioned(
              bottom: 5, left: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${widget.detector.name} LoRa',
                    style: TextStyle(
                        fontSize: 8, color: c.tileTextDim, letterSpacing: 0.2),
                  ),
                  Text(
                    widget.detector.id,
                    style: TextStyle(
                      fontSize: 8, fontFamily: 'monospace',
                      color: c.tileTextDim,
                    ),
                  ),
                ],
              ),
            ),

            // Status icons — bottom right
            Positioned(
              bottom: 8, right: 7,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.detector.status == DetectorStatus.lowBattery
                        ? Icons.battery_alert
                        : Icons.battery_full_rounded,
                    size: 13,
                    color: widget.detector.status == DetectorStatus.lowBattery
                        ? const Color(0xFFFFAA00)
                        : c.tileTextDim,
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    widget.detector.status == DetectorStatus.tamper
                        ? Icons.lock_open_rounded
                        : Icons.lock_rounded,
                    size: 13,
                    color: widget.detector.status == DetectorStatus.tamper
                        ? const Color(0xFFAA44FF)
                        : c.tileTextDim,
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
