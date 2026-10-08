import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:final_project/data/mock_data.dart';
import 'package:final_project/services/facility_repository.dart';

FacilityRepository installFakeCatalog() {
  var records = [
    for (var i = 0; i < mockFacilities.length; i++)
      {
        ...mockFacilities[i].toJson(),
        'id': 'place-$i',
        'version': 1,
        'sourceName': mockFacilities[i].name,
      },
  ];
  var nextId = records.length;
  final repository = FacilityRepository(
    pollInterval: null,
    client: MockClient((request) async {
      if (request.method != 'GET') {
        final id = request.url.pathSegments.last;
        if (request.method == 'DELETE') {
          records.removeWhere((item) => item['id'] == id);
        } else {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (request.method == 'POST') {
            records.add({
              ...body,
              'id': 'place-${nextId++}',
              'version': 1,
              'sourceName': null,
            });
          } else {
            final index = records.indexWhere((item) => item['id'] == id);
            records[index] = {
              ...body,
              'id': id,
              'version': (records[index]['version'] as int) + 1,
              'sourceName': records[index]['sourceName'],
            };
          }
        }
      }
      return http.Response.bytes(
        utf8.encode(jsonEncode({'facilities': records})),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
  FacilityRepository.instance = repository;
  return repository;
}
