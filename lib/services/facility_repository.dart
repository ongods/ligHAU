import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/backend_config.dart';
import '../data/mock_data.dart';
import '../models/facility.dart';
import 'admin_access.dart';

class FacilitySaveException implements Exception {
  final String message;
  const FacilitySaveException(this.message);
  @override
  String toString() => message;
}

enum CatalogSyncStatus { loading, current, stale, unavailable }

class FacilityRepository extends ValueNotifier<List<Facility>>
    with WidgetsBindingObserver {
  static FacilityRepository instance = FacilityRepository();
  final http.Client _client;
  final Uri endpoint;
  Future<void>? _pending;
  final Duration? pollInterval;
  Timer? _pollTimer;
  bool _disposed = false;
  bool _observing = false;
  int _writeVersion = 0;
  String? _lastCatalog;
  CatalogSyncStatus syncStatus = CatalogSyncStatus.loading;
  DateTime? lastSuccessfulRefresh;
  bool get isRefreshing => _pending != null;
  bool loaded = false;
  FacilityRepository({
    http.Client? client,
    Uri? endpoint,
    this.pollInterval = const Duration(seconds: 10),
  }) : _client = client ?? http.Client(),
       endpoint = endpoint ?? backendEndpoint('/api/facilities'),
       super(List.of(mockFacilities));

  @override
  void addListener(VoidCallback listener) {
    final first = !hasListeners;
    super.addListener(listener);
    if (first) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
      _startPolling();
      scheduleMicrotask(() {
        if (!_disposed && hasListeners) unawaited(refresh());
      });
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _pollTimer?.cancel();
      _pollTimer = null;
      if (_observing) WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
  }

  void _startPolling() {
    if (pollInterval == null || _pollTimer != null) return;
    _pollTimer = Timer.periodic(pollInterval!, (_) => unawaited(refresh()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && hasListeners) {
      _startPolling();
      unawaited(refresh());
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Facility? current(Facility facility) {
    for (final item in value) {
      if (facility.id != null
          ? item.id == facility.id
          : item.mapName == facility.mapName) {
        return item;
      }
    }
    return null;
  }

  void _accept(http.Response response) {
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final next = (data['facilities'] as List).map((raw) {
      final item = raw as Map<String, dynamic>;
      final sourceName = item['sourceName'] as String?;
      final original = mockFacilities.where(
        (f) => f.name == (sourceName ?? item['name']),
      );
      return Facility(
        id: item['id'] as String,
        version: (item['version'] as int?) ?? 0,
        sourceName: sourceName,
        latitude: (item['latitude'] as num?)?.toDouble(),
        longitude: (item['longitude'] as num?)?.toDouble(),
        name: item['name'] as String,
        category: item['category'] as String,
        location: item['location'] as String,
        description: item['description'] as String,
        hours: item['hours'] as String,
        floors: item['floors'] as int?,
        icon: original.isEmpty ? Icons.apartment : original.first.icon,
        facilities: (item['facilities'] as List).cast<String>(),
      );
    }).toList();
    final encoded = jsonEncode(data['facilities']);
    final statusChanged = syncStatus != CatalogSyncStatus.current;
    loaded = true;
    syncStatus = CatalogSyncStatus.current;
    lastSuccessfulRefresh = DateTime.now();
    if (encoded != _lastCatalog) {
      _lastCatalog = encoded;
      value = next;
    } else if (statusChanged) {
      notifyListeners();
    }
  }

  Future<void> refresh() =>
      _pending ??= _load().whenComplete(() => _pending = null);
  Future<void> _load() async {
    final version = _writeVersion;
    try {
      final response = await _client
          .get(endpoint)
          .timeout(const Duration(seconds: 10));
      if (_disposed || version != _writeVersion) return;
      if (response.statusCode != 200) {
        throw const FacilitySaveException('Catalog unavailable.');
      }
      _accept(response);
    } catch (_) {
      if (_disposed || version != _writeVersion) return;
      final status = loaded
          ? CatalogSyncStatus.stale
          : CatalogSyncStatus.unavailable;
      if (syncStatus != status) {
        syncStatus = status;
        notifyListeners();
      }
    }
  }

  Future<void> save(Facility facility, {Facility? previous}) async {
    if (!loaded) await refresh();
    final original = previous == null ? null : current(previous);
    if (previous != null && original?.id == null) {
      throw const FacilitySaveException(
        'Cannot load the saved catalog. Check that the chat backend is running.',
      );
    }
    await _write(original == null ? 'POST' : 'PUT', original?.id, {
      ...facility.toJson(),
      'version': previous?.id == null
          ? original?.version ?? 0
          : previous!.version,
    });
  }

  Future<void> delete(Facility facility) async {
    if (!loaded) await refresh();
    final id = current(facility)?.id;
    if (id == null) {
      throw const FacilitySaveException(
        'Cannot load the saved catalog. Check that the chat backend is running.',
      );
    }
    await _write('DELETE', id, {
      'version': facility.id == null
          ? current(facility)!.version
          : facility.version,
    });
  }

  Future<void> _write(
    String method,
    String? id,
    Map<String, dynamic>? body,
  ) async {
    final auth = AdminAccess.authorizationHeader;
    if (auth == null) {
      throw const FacilitySaveException(
        'Sign in as admin before saving changes.',
      );
    }
    try {
      final url = endpoint.resolve(
        '/api/admin/facilities${id == null ? '' : '/$id'}',
      );
      final headers = {
        'Authorization': auth,
        'Content-Type': 'application/json; charset=utf-8',
        if (method == 'DELETE') 'If-Match': '"${body!['version']}"',
      };
      final pending = switch (method) {
        'POST' => _client.post(url, headers: headers, body: jsonEncode(body)),
        'PUT' => _client.put(url, headers: headers, body: jsonEncode(body)),
        _ => _client.delete(url, headers: headers),
      };
      final response = await pending.timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        if (response.statusCode == 412 || response.statusCode == 428) {
          await refresh();
        }
        throw FacilitySaveException(switch (response.statusCode) {
          401 => 'Admin access was denied. Sign in again.',
          409 => 'A place with this name already exists.',
          412 || 428 =>
            'This place changed since you opened it. Reopen the editor and review your changes.',
          404 =>
            'Catalog saving is unavailable. Restart the chat backend and retry.',
          _ => 'Could not save changes. Please retry.',
        });
      }
      if (_disposed) return;
      _writeVersion++;
      _accept(response);
    } on FacilitySaveException {
      rethrow;
    } catch (_) {
      throw const FacilitySaveException(
        'Cannot save changes. Check that the chat backend is running, then retry.',
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    _client.close();
    super.dispose();
  }
}
