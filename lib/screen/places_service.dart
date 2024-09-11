import 'dart:convert';
import 'package:http/http.dart' as http;

class PlacesService {
  final String apiKey;

  PlacesService(this.apiKey);

  Future<List<dynamic>> getNearbyEVStations(double lat, double lng) async {
    final String url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=$lat,$lng'
        '&radius=5000'
        '&type=car_charging_station'
        '&key=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
       
        if (json.containsKey('results')) {
          return json['results'];
        } else {
          throw Exception('No results found in the response');
        }
      } else {
        throw Exception('Failed to load EV stations. Status code: ${response.statusCode}');
      }
    } catch (e) {
     
      throw Exception('An error occurred: $e');
    }
  }
}
