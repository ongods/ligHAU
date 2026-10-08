import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/facility.dart';

String formatCampusTime(TimeOfDay time) {
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${time.period == DayPeriod.am ? 'AM' : 'PM'}';
}

String formatOperatingHours(TimeOfDay opening, TimeOfDay closing) {
  final overnight =
      closing.hour * 60 + closing.minute < opening.hour * 60 + opening.minute;
  return '${formatCampusTime(opening)} – ${formatCampusTime(closing)}${overnight ? ' (next day)' : ''}';
}

({TimeOfDay opening, TimeOfDay closing})? parseOperatingHours(String hours) {
  final matches = RegExp(
    r'(\d{1,2}):(\d{2})\s*(AM|PM)',
    caseSensitive: false,
  ).allMatches(hours).toList();
  if (matches.length != 2) return null;
  final times = <TimeOfDay>[];
  for (final match in matches) {
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour < 1 || hour > 12 || minute > 59) return null;
    times.add(
      TimeOfDay(
        hour: hour % 12 + (match.group(3)!.toUpperCase() == 'PM' ? 12 : 0),
        minute: minute,
      ),
    );
  }
  return (opening: times[0], closing: times[1]);
}

class BuildingEditorDialog extends StatefulWidget {
  final Facility? facility;
  final bool Function(String name) isNameAvailable;
  const BuildingEditorDialog({
    super.key,
    this.facility,
    required this.isNameAvailable,
  });

  @override
  State<BuildingEditorDialog> createState() => _BuildingEditorDialogState();
}

class _BuildingEditorDialogState extends State<BuildingEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.facility?.name ?? '');
  late final _location = TextEditingController(
    text: widget.facility?.location ?? '',
  );
  late final _description = TextEditingController(
    text: widget.facility?.description ?? '',
  );
  late final _facilities = TextEditingController(
    text: widget.facility?.facilities.join('\n') ?? '',
  );
  late final _floors = TextEditingController(
    text: widget.facility?.floors?.toString() ?? '',
  );
  late final _latitude = TextEditingController(
    text: widget.facility?.latitude?.toString() ?? '',
  );
  late final _longitude = TextEditingController(
    text: widget.facility?.longitude?.toString() ?? '',
  );
  final _openingText = TextEditingController();
  final _closingText = TextEditingController();
  late String _category = widget.facility?.category ?? 'Buildings';
  TimeOfDay? _opening;
  TimeOfDay? _closing;

  @override
  void initState() {
    super.initState();
    final hours = parseOperatingHours(
      widget.facility?.hours ?? '7:00 AM – 8:00 PM',
    );
    _opening = hours?.opening;
    _closing = hours?.closing;
    _syncTimeFields();
  }

  void _syncTimeFields() {
    _openingText.text = _opening == null ? '' : formatCampusTime(_opening!);
    _closingText.text = _closing == null ? '' : formatCampusTime(_closing!);
  }

  Future<void> _pickTime(bool opening) async {
    final time = await showTimePicker(
      context: context,
      initialTime:
          (opening ? _opening : _closing) ??
          const TimeOfDay(hour: 7, minute: 0),
      initialEntryMode: TimePickerEntryMode.input,
      helpText: opening ? 'Opening time' : 'Closing time',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (!mounted || time == null) return;
    setState(() {
      if (opening) {
        _opening = time;
      } else {
        _closing = time;
      }
      _syncTimeFields();
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final facilities = <String>[];
    final seen = <String>{};
    for (final line in _facilities.text.split('\n')) {
      final value = line.trim();
      if (value.isNotEmpty && seen.add(value.toLowerCase())) {
        facilities.add(value);
      }
    }
    Navigator.pop(
      context,
      Facility(
        id: widget.facility?.id,
        version: widget.facility?.version ?? 0,
        sourceName: widget.facility?.sourceName,
        latitude: double.tryParse(_latitude.text.trim()),
        longitude: double.tryParse(_longitude.text.trim()),
        name: _name.text.trim(),
        category: _category,
        location: _location.text.trim(),
        description: _description.text.trim(),
        facilities: facilities,
        hours: formatOperatingHours(_opening!, _closing!),
        floors: _floors.text.trim().isEmpty
            ? null
            : int.parse(_floors.text.trim()),
        icon: widget.facility?.icon ?? Icons.apartment,
      ),
    );
  }

  String? _validateCoordinate(String? text, {required bool latitude}) {
    final raw = text?.trim() ?? '';
    final other = latitude ? _longitude.text.trim() : _latitude.text.trim();
    if (raw.isEmpty) return other.isEmpty ? null : 'Enter both coordinates.';
    final value = double.tryParse(raw);
    final limit = latitude ? 90 : 180;
    if (value == null || !value.isFinite || value.abs() > limit) {
      return 'Enter a number from -$limit to $limit.';
    }
    return null;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _location,
      _description,
      _facilities,
      _floors,
      _latitude,
      _longitude,
      _openingText,
      _closingText,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    title: Text(widget.facility == null ? 'Add Building' : 'Edit Building'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const ValueKey('building-name'),
                controller: _name,
                decoration: const InputDecoration(labelText: 'Building name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a building name.';
                  }
                  if (!widget.isNameAvailable(value.trim())) {
                    return 'A building with this name already exists.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: {'Buildings', 'Offices', _category}
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('building-location'),
                controller: _location,
                decoration: const InputDecoration(labelText: 'Location'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter the location.'
                    : null,
              ),
              const SizedBox(height: 16),
              Text('Map pin', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(
                'Enter the building coordinates in decimal degrees to place its pin. '
                'Leave both blank to use its original map location, if available.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('building-latitude'),
                controller: _latitude,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Latitude',
                  hintText: '15.1325',
                ),
                validator: (value) =>
                    _validateCoordinate(value, latitude: true),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('building-longitude'),
                controller: _longitude,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Longitude',
                  hintText: '120.5901',
                ),
                validator: (value) =>
                    _validateCoordinate(value, latitude: false),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('building-description'),
                controller: _description,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'About this place',
                  alignLabelWithHint: true,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Describe this place.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('building-facilities'),
                controller: _facilities,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: "What you'll find here",
                  alignLabelWithHint: true,
                  helperText: 'One office, service, or amenity per line.',
                  helperMaxLines: 2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Operating hours',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('building-opening-time'),
                      controller: _openingText,
                      readOnly: true,
                      onTap: () => _pickTime(true),
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Opening time',
                      ),
                      validator: (_) =>
                          _opening == null ? 'Choose a time.' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('building-closing-time'),
                      controller: _closingText,
                      readOnly: true,
                      onTap: () => _pickTime(false),
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Closing time',
                      ),
                      validator: (_) => _closing == null
                          ? 'Choose a time.'
                          : _closing == _opening
                          ? 'Choose a different time.'
                          : null,
                    ),
                  ),
                ],
              ),
              if (_opening != null &&
                  _closing != null &&
                  _closing!.hour * 60 + _closing!.minute <
                      _opening!.hour * 60 + _opening!.minute)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Closes the next day.'),
                ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('building-floors'),
                controller: _floors,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Number of floors (optional)',
                  helperText: 'Leave blank if not verified.',
                ),
                validator: (value) =>
                    value != null &&
                        value.isNotEmpty &&
                        (int.tryParse(value) ?? 0) < 1
                    ? 'Enter a positive number.'
                    : null,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _save,
        child: Text(widget.facility == null ? 'Add' : 'Save'),
      ),
    ],
  );
}
