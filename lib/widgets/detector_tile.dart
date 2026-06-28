import 'package:flutter/material.dart';
import '../models/detector_model.dart';

const _kFadeDuration = Duration(seconds: 90);

// ── Palette ─────────────────────────────────────────────────────────────────
const _kBgNormal   = Color(0xFF0A2010);
const _kBgAlarm    = Color(0xFF2A0808);
const _kBgDisarmed = Color(0xFF181818);
const _kBgOff      = Color(0xFF111111);
const _kBgBattery  = Color(0xFF2A1A06);
const _kBorderNormal   = Color(0xFF2A6A2A);
const _kBorderAlarm    = Color(0xFFCC2222);
const _kBorderDisarmed = Color(0xFF383838);
const _kBorderSelected = Color(0xFF4FC3F7);
const _kTextPrimary    = Color(0xFFD0DDD8);
const _kTextDim        = Color(0xFF5A7060);
// ────────────────────────────────────────────────────────────────────────────

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
        final elapsed = DateTime.now()
            .difference(widget.alarmStartTime!)
            .inMilliseconds;
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

  // ── Colors ────────────────────────────────────────────────────────────────

  Color get _bg {
    final d = widget.detector;
    if (!d.isActive || d.status == DetectorStatus.offline) return _kBgOff;
    if (!d.isArmed || d.status == DetectorStatus.off) return _kBgDisarmed;
    if (d.status == DetectorStatus.alarm) {
      return Color.lerp(_kBgAlarm, _kBgNormal, _fade.value)!;
    }
    if (d.status == DetectorStatus.lowBattery) return _kBgBattery;
    return _kBgNormal;
  }

  Color get _border {
    if (widget.isSelected) return _kBorderSelected;
    if (widget.alarmBorderActive) return _kBorderAlarm;
    final d = widget.detector;
    if (!d.isArmed || !d.isActive) return _kBorderDisarmed;
    return _kBorderNormal;
  }

  Color get _numColor {
    final d = widget.detector;
    if (!d.isArmed || !d.isActive) return _kTextDim;
    if (d.status == DetectorStatus.alarm) {
      return Color.lerp(const Color(0xFFFF6666), _kTextPrimary, _fade.value)!;
    }
    return _kTextPrimary;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fade,
      builder: (ctx, _) => GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: _bg,
            border: Border.all(
              color: _border,
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
                style: const TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w600,
                  color: _kTextPrimary, letterSpacing: 0.4,
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
                    color: _numColor,
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
                    style: const TextStyle(
                        fontSize: 8, color: _kTextDim, letterSpacing: 0.2),
                  ),
                  Text(
                    widget.detector.id,
                    style: const TextStyle(
                      fontSize: 8, fontFamily: 'monospace', color: _kTextDim,
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
                        : _kTextDim,
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    widget.detector.status == DetectorStatus.tamper
                        ? Icons.lock_open_rounded
                        : Icons.lock_rounded,
                    size: 13,
                    color: widget.detector.status == DetectorStatus.tamper
                        ? const Color(0xFFAA44FF)
                        : _kTextDim,
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
