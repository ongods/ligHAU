import 'dart:async';
import 'dart:math' show Point;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:url_launcher/url_launcher.dart';

import '../data/campus_map_data.dart';
import '../data/campus_map_features.dart';
import '../data/campus_map_style.dart';
import '../models/facility.dart';
import '../theme/app_theme.dart';

class CampusVectorMap extends StatefulWidget {
  final List<Facility> facilities;
  final Map<String, CampusMapLocation> locations;
  final Facility? selected;
  final ValueChanged<Facility> onSelected;
  final VoidCallback onClear;
  const CampusVectorMap({
    super.key,
    required this.facilities,
    required this.locations,
    required this.selected,
    required this.onSelected,
    required this.onClear,
  });

  @override
  State<CampusVectorMap> createState() => CampusVectorMapState();
}

class CampusVectorMapState extends State<CampusVectorMap> {
  static const _campus = ml.LatLng(15.1325, 120.5901);
  static const _source = 'hau-facilities';
  late Future<String> _style = loadCampusMapStyle();
  ml.MapLibreMapController? _controller;
  ml.LatLng? _pendingFocus;
  bool _ready = false;
  bool _failed = false;
  int _generation = 0;
  Timer? _loadTimer;
  Future<void> _updates = Future.value();

  void focus(CampusMapLocation location) {
    final center = location.center;
    _pendingFocus = ml.LatLng(center.latitude, center.longitude);
    if (_ready) _move(_pendingFocus!, 19);
  }

  Future<void> _move(ml.LatLng target, double zoom) async {
    try {
      await _controller?.animateCamera(
        ml.CameraUpdate.newLatLngZoom(target, zoom),
      );
    } catch (_) {
      // A responsive layout change may dispose the platform view during an animation.
    }
  }

  void _zoom(double delta) {
    final camera = _controller?.cameraPosition;
    if (camera != null) {
      _move(camera.target, (camera.zoom + delta).clamp(15.0, 20.0));
    }
  }

  void _created(ml.MapLibreMapController controller) {
    _controller = controller;
    controller.onFeatureTapped.add(_featureTapped);
    final generation = _generation;
    _loadTimer?.cancel();
    _loadTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && !_ready && generation == _generation) {
        setState(() => _failed = true);
      }
    });
  }

  void _featureTapped(
    Point<double> point,
    ml.LatLng position,
    String id,
    String layer,
    ml.Annotation? annotation,
  ) {
    if (!layer.startsWith('hau-')) return;
    for (final facility in widget.facilities) {
      if (widget.locations[facility.name]?.osmWayId.toString() == id) {
        widget.onSelected(facility);
        return;
      }
    }
  }

  Future<void> _styleLoaded() async {
    final controller = _controller;
    final generation = _generation;
    if (controller == null) return;
    try {
      final icons = <int, Facility>{
        for (final f in widget.facilities) f.icon.codePoint: f,
      };
      for (final facility in icons.values) {
        for (final selected in [false, true]) {
          final bytes = await _iconImage(facility.icon, selected);
          if (!mounted || generation != _generation) return;
          await controller.addImage(
            campusIconId(facility, selected: selected),
            bytes,
          );
        }
      }
      await controller.addGeoJsonSource(_source, _features);
      await controller.addSymbolLayer(
        _source,
        'hau-icons',
        const ml.SymbolLayerProperties(
          iconImage: ['get', 'icon'],
          iconSize: .42,
          iconPadding: 4,
          iconAllowOverlap: false,
          iconIgnorePlacement: false,
        ),
        filter: [
          '==',
          ['get', 'selected'],
          false,
        ],
      );
      await controller.addSymbolLayer(
        _source,
        'hau-labels',
        const ml.SymbolLayerProperties(
          textField: ['get', 'label'],
          textFont: ['Roboto Regular', 'Noto Sans Regular'],
          textSize: 11,
          textColor: '#645C52',
          textHaloColor: '#F8F7F3',
          textHaloWidth: 2,
          textAnchor: 'top',
          textOffset: [0, 1.9],
          textMaxWidth: 10,
          textAllowOverlap: false,
        ),
        minzoom: 18.2,
        filter: [
          '==',
          ['get', 'selected'],
          false,
        ],
      );
      await controller.addSymbolLayer(
        _source,
        'hau-selected',
        const ml.SymbolLayerProperties(
          iconImage: ['get', 'icon'],
          iconSize: .5,
          iconAllowOverlap: true,
          textField: ['get', 'label'],
          textFont: ['Roboto Medium', 'Noto Sans Regular'],
          textSize: 12,
          textColor: '#780F25',
          textHaloColor: '#F8F7F3',
          textHaloWidth: 2,
          textAnchor: 'top',
          textOffset: [0, 2.1],
          textMaxWidth: 10,
          textOptional: true,
        ),
        filter: [
          '==',
          ['get', 'selected'],
          true,
        ],
      );
      if (!mounted || generation != _generation) return;
      _loadTimer?.cancel();
      setState(() {
        _ready = true;
        _failed = false;
      });
      _queueFeatures();
      if (_pendingFocus != null) _move(_pendingFocus!, 19);
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    }
  }

  Map<String, dynamic> get _features => campusFacilityFeatures(
    widget.facilities,
    widget.locations,
    widget.selected,
  );

  void _queueFeatures() {
    if (!_ready) return;
    final generation = _generation;
    _updates = _updates
        .then((_) async {
          if (!mounted || !_ready || generation != _generation) return;
          await _controller?.setGeoJsonSource(_source, _features);
        })
        .catchError((Object _) {
          if (mounted && generation == _generation) {
            setState(() => _failed = true);
          }
        });
  }

  @override
  void didUpdateWidget(CampusVectorMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _queueFeatures();
  }

  void _retry() {
    _loadTimer?.cancel();
    _controller?.onFeatureTapped.remove(_featureTapped);
    setState(() {
      _generation++;
      _controller = null;
      _ready = false;
      _failed = false;
      _style = loadCampusMapStyle();
    });
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    _controller?.onFeatureTapped.remove(_featureTapped);
    // MapLibreMap owns and disposes its controller.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: ColoredBox(
      color: AppColors.background,
      child: Stack(
        children: [
          FutureBuilder<String>(
            future: _style,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                final error = snapshot.error;
                return _unavailable(
                  message: error is MapStyleException ? error.message : null,
                );
              }
              if (!snapshot.hasData) return _loading();
              return Stack(
                fit: StackFit.expand,
                children: [
                  ml.MapLibreMap(
                    key: ValueKey(_generation),
                    styleString: snapshot.data!,
                    initialCameraPosition: const ml.CameraPosition(
                      target: _campus,
                      zoom: 17.5,
                    ),
                    minMaxZoomPreference: const ml.MinMaxZoomPreference(15, 20),
                    trackCameraPosition: true,
                    compassEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                    attributionButtonPosition: null,
                    annotationOrder: const [],
                    onMapCreated: _created,
                    onStyleLoadedCallback: _styleLoaded,
                    onMapClick: (_, _) => widget.onClear(),
                  ),
                  if (!_ready && !_failed) IgnorePointer(child: _loading()),
                ],
              );
            },
          ),
          if (_failed) Positioned.fill(child: _unavailable()),
          Positioned(
            top: 16,
            left: 16,
            right: 76,
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.pathway),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Holy Angel University',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.pathway),
              ),
              child: Column(
                children: [
                  IconButton(
                    tooltip: 'Zoom in',
                    onPressed: _ready ? () => _zoom(1) : null,
                    icon: const Icon(Icons.add_rounded, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Zoom out',
                    onPressed: _ready ? () => _zoom(-1) : null,
                    icon: const Icon(Icons.remove_rounded, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Recenter campus',
                    onPressed: _ready
                        ? () {
                            _pendingFocus = null;
                            _move(_campus, 17.5);
                          }
                        : null,
                    icon: const Icon(
                      Icons.center_focus_strong_rounded,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(bottom: 0, left: 0, right: 0, child: _attribution()),
        ],
      ),
    ),
  );

  Widget _loading() =>
      const Center(child: CircularProgressIndicator(strokeWidth: 2));
  Widget _unavailable({String? message}) => ColoredBox(
    color: AppColors.background,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 36, color: AppColors.border),
            const SizedBox(height: 12),
            Text(
              'The map couldn’t load.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              message ?? 'You can still browse campus places below.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _retry, child: const Text('Try again')),
          ],
        ),
      ),
    ),
  );

  Widget _attribution() => Material(
    color: AppColors.surface.withValues(alpha: .94),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: [
          InkWell(
            onTap: () => launchUrl(Uri.parse('https://www.maptiler.com/')),
            child: SvgPicture.asset(
              'assets/branding/maptiler-logo.svg',
              width: 75,
              height: 24,
              semanticsLabel: 'MapTiler',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                _credit('© MapTiler', 'https://www.maptiler.com/copyright/'),
                _credit(
                  '© OpenStreetMap contributors',
                  'https://www.openstreetmap.org/copyright',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _credit(String text, String url) => InkWell(
    onTap: () => launchUrl(Uri.parse(url)),
    child: Text(
      text,
      style: const TextStyle(fontSize: 9, color: AppColors.border, height: 1.5),
    ),
  );
}

Future<Uint8List> _iconImage(IconData icon, bool selected) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final shape = RRect.fromRectAndRadius(
    const Rect.fromLTWH(8, 8, 80, 80),
    const Radius.circular(24),
  );
  canvas.drawShadow(
    Path()..addRRect(shape),
    Colors.black.withValues(alpha: .18),
    4,
    false,
  );
  canvas.drawRRect(
    shape,
    Paint()..color = selected ? AppColors.primary : AppColors.surface,
  );
  canvas.drawRRect(
    shape,
    Paint()
      ..color = selected
          ? AppColors.secondary
          : AppColors.primary.withValues(alpha: .2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 4 : 2,
  );
  final painter = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        fontSize: 40,
        color: selected ? Colors.white : AppColors.primary,
      ),
    ),
  )..layout();
  painter.paint(
    canvas,
    Offset((96 - painter.width) / 2, (96 - painter.height) / 2),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(96, 96);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
}
