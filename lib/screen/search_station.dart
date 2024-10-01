import 'dart:io';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gms;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchPlacePage extends StatefulWidget {
  final Function(Map<String, dynamic>) onAddToFavorites;
  final Function(Map<String, dynamic>) onAddToHistory;
  final CollectionReference evStationsCollection =
      FirebaseFirestore.instance.collection('ev_stations');

  SearchPlacePage(
      {required this.onAddToFavorites, required this.onAddToHistory});

  @override
  _SearchPlacePageState createState() => _SearchPlacePageState();
}

class _SearchPlacePageState extends State<SearchPlacePage> {
  final Completer<gms.GoogleMapController> _controllerCompleter = Completer();
  gms.LatLng? _currentPosition;
  BitmapDescriptor? _restaurantIcon;
  BitmapDescriptor? _cafeIcon;
  BitmapDescriptor? _storeIcon;
  BitmapDescriptor? _touristAttractionIcon;
  BitmapDescriptor? _gasStationIcon;
  BitmapDescriptor? _evStationIcon;
  final String _apiKey = 'AIzaSyB67ZhLCsWm7sC9pUluesjiCOT-Wwu67oU';
  List<Map<String, dynamic>> _places = [];
  TextEditingController _searchController = TextEditingController();
  bool _isLoadingLocation = true;
  bool _isNavigating = false;
  Timer? _debounce;
  String? _distanceText;
  String? _durationText;
  List<String> _searchHistory = [];
  List<Map<String, dynamic>> _originalPlaces = [];
  String? _selectedFilter = 'all';
  String? _tempSelectedFilter;
  String? selectedPlace;
  File? _selectedImage;
  List<Map<String, dynamic>> _suggestions = [];
  gms.LatLng? _destination;
  final suggestions = ValueNotifier<List<Map<String, dynamic>>>([]);
  final ValueNotifier<List<Map<String, dynamic>>> suggestionsNotifier =
      ValueNotifier([]);

  Set<gms.Polyline> _polylines = {};
  gms.PolylineId polylineId = gms.PolylineId('route');

  @override
  void initState() {
    super.initState();
    _setCustomIcons();
    _checkPermissions().then((_) {
      _getCurrentLocation();
      _startTrackingUserPosition();
    }).catchError((e) {
      print('Error checking permissions: $e');
    });
    _loadPlacesFromFirestore();

    _loadSearchHistory();
  }

  // โหลดประวัติการค้นหาจาก SharedPreferences
  Future<void> _loadSearchHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _searchHistory = prefs.getStringList('search_history') ?? [];
    });
  }

  // บันทึกประวัติการค้นหาใน SharedPreferences
  Future<void> _saveSearchHistory(String query) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      if (!_searchHistory.contains(query)) {
        _searchHistory.add(query);
      }
    });
    await prefs.setStringList('search_history', _searchHistory);
  }

  void _clearSearchHistory(String historyItem) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _searchHistory.removeWhere((item) => item == historyItem);
      prefs.setStringList('search_history', _searchHistory);
    });
  }

  void _resetSearchResults() {
    setState(() {
      _places = List.from(_originalPlaces); // โหลดข้อมูลทั้งหมดกลับ
    });
  }

  // ฟังก์ชันค้นหา
  void _onSearchChanged(String query) {
    setState(() {
      _places = _originalPlaces.where((place) {
        final matchType =
            _selectedFilter == 'all' || place['type'] == _selectedFilter;
        final matchQuery = place['name']
            .toString()
            .toLowerCase()
            .contains(query.toLowerCase());
        return matchType && matchQuery;
      }).toList();
    });
  }

  // ฟังก์ชันล้างคำค้นหา
  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _resetSearchResults();
    });
  }

  Future<void> _moveCameraToPlace(double lat, double lng) async {
    final gms.GoogleMapController controller =
        await _controllerCompleter.future;
    gms.LatLng position = gms.LatLng(lat, lng);
    print("Moving camera to position: $lat, $lng");
    controller
        .animateCamera(CameraUpdate.newLatLngZoom(position, 18.0)); // ซูมเข้า
  }

// // ดึง userId จาก Firebase Authentication
//   Future<String?> _getUserId() async {
//     User? user = FirebaseAuth.instance.currentUser;
//     return user
//         ?.uid; // คืนค่า userId ของผู้ใช้ปัจจุบัน หรือ null ถ้าไม่มีผู้ใช้ล็อกอิน
//   }

  void _applyFilter(String? filterType) {
    setState(() {
      if (filterType == null || filterType == 'all') {
        // แสดงผลทั้งหมด
        _places = List.from(_originalPlaces);
      } else if (filterType == 'ev_station') {
        // กรองตามประเภทที่เป็นสถานี EV จากทั้ง Firestore และ Google API
        _places = _originalPlaces.where((place) {
          // ตรวจสอบว่าประเภทของสถานที่เป็น 'ev_station' หรือ 'electric_vehicle_charging_station'
          return place['type'] == 'ev_station' ||
              place['type'] == 'electric_vehicle_charging_station';
        }).toList();
      } else {
        // กรองตามประเภทอื่น ๆ
        _places = _originalPlaces.where((place) {
          return place['type'] == filterType;
        }).toList();
      }
    });
  }

  void _sortPlacesByDistance() {
    if (_currentPosition != null) {
      setState(() {
        _places.sort((a, b) {
          double distanceA = _calculateDistance(_currentPosition!.latitude,
              _currentPosition!.longitude, a['lat'], a['lng']);
          double distanceB = _calculateDistance(_currentPosition!.latitude,
              _currentPosition!.longitude, b['lat'], b['lng']);
          return distanceA.compareTo(distanceB);
        });
      });
    }
  }

  Future<void> _searchAllPlaces(String query) async {
    try {
      // ดึงข้อมูลสถานที่จาก Google API
      await _fetchPlaces();

      // ดึงข้อมูลสถานที่จาก Firestore
      await _loadPlacesFromFirestore();

      // ทำการค้นหาในรายการทั้งหมดตามคำค้นหาที่ให้มา
      setState(() {
        _places = _originalPlaces.where((place) {
          final matchQuery = place['name']
              .toString()
              .toLowerCase()
              .contains(query.toLowerCase());
          return matchQuery;
        }).toList();
      });
    } catch (e) {
      print('Error searching all places: $e');
    }
  }

  double _calculateDistance(
      double lat1, double lng1, double lat2, double lng2) {
    const p = 0.017453292519943295;
    const c = cos;
    final a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lng2 - lng1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 12742 เป็นค่าเส้นรอบวงโลก (กิโลเมตร)
  }

  Future<String> _getDistance(double destLat, double destLng) async {
    if (_currentPosition == null) return 'Unknown distance';

    final String origin =
        '${_currentPosition!.latitude},${_currentPosition!.longitude}';
    final String destination = '$destLat,$destLng';

    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&key=$_apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final route = jsonResponse['routes'][0];
        final leg = route['legs'][0];
        final distance =
            leg['distance']['text']; // ระยะทางในรูปแบบข้อความ เช่น '5.2 km'
        final duration =
            leg['duration']['text']; // เวลาที่ใช้เดินทาง เช่น '15 mins'

        setState(() {
          _distanceText = distance;
          _durationText = duration;
        });

        return distance;
      } else {
        throw Exception('Failed to fetch distance');
      }
    } catch (e) {
      print('Error fetching distance: $e');
      return 'Unknown distance';
    }
  }

  Timer? _debounceTimer;

  void _startTrackingUserPosition() {
    Geolocator.getPositionStream().listen((Position position) {
      setState(() {
        _currentPosition = gms.LatLng(position.latitude, position.longitude);
        _debounceUpdateDistance(); // อัปเดตระยะทางแบบ real-time
        _updatePolyline(); // อัปเดต Polyline บนแผนที่
      });
    });
  }

  void _updatePolyline() async {
    if (_currentPosition != null && _destination != null) {
      _fetchRouteAndNavigate(
          _destination!); // อัปเดตเส้นทางใหม่เมื่อผู้ใช้เคลื่อนที่
    }
  }

  void _debounceUpdateDistance() {
    // ยกเลิกการนับเวลาถ้ามี debounce ที่ยังทำงานอยู่
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();

    // เริ่ม debounce 5 วินาที ก่อนอัปเดตระยะทาง
    _debounceTimer = Timer(const Duration(seconds: 5), () {
      if (_destination != null && _currentPosition != null) {
        _updateDistanceToDestination();
      }
    });
  }

  void _updateDistanceToDestination() async {
    if (_destination != null && _currentPosition != null) {
      final distance =
          await _getDistance(_destination!.latitude, _destination!.longitude);
      setState(() {
        _distanceText = distance;
      });
    }
  }

  Future<void> onSuggestionSelected(Map<String, dynamic> suggestion) async {
    try {
      String placeId = suggestion['place_id'];
      String description = suggestion['description'] ?? 'Unknown';

      // Fetch details of the selected place from Google API or Firestore
      Map<String, dynamic> placeDetails;
      if (suggestion['source'] == 'google') {
        placeDetails = await fetchPlaceDetails(placeId);
      } else if (suggestion['source'] == 'firestore') {
        // หากเป็นจาก Firestore ให้ใช้ข้อมูลที่มีอยู่
        placeDetails = {
          'name': suggestion['description'],
          'address': suggestion['address'],
          'lat': suggestion['lat'],
          'lng': suggestion['lng'],
          'type': suggestion['type'] ?? 'unknown',
        };
      } else {
        placeDetails = {};
      }

      // ตรวจสอบว่ามีข้อมูล lat และ lng
      if (placeDetails.isNotEmpty &&
          placeDetails.containsKey('lat') &&
          placeDetails.containsKey('lng')) {
        double lat = placeDetails['lat'];
        double lng = placeDetails['lng'];

        // Move the camera to the selected place
        await _moveCameraToPlace(lat, lng);
        print("Moved camera to place: $lat, $lng");

        // Show place details immediately after moving the camera
        final gms.LatLng placeLatLng = gms.LatLng(lat, lng);
        _showPlaceDetails(placeId, placeLatLng, placeDetails);

        // Save the search to history
        await _saveSearchHistory(description);
        print("Saved search history for: $description");
      } else {
        print("Place details not found or invalid.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Place details not found or invalid.')),
        );
      }
    } catch (e) {
      print("Error selecting suggestion: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting suggestion: $e')),
      );
    }
  }

  void _handleSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isNotEmpty) {
        await _fetchPlaceSuggestions(query);
      } else {
        setState(() {
          _suggestions.clear();
          _resetSearchResults();
        });
      }
    });
  }

// ค้นหาข้อมูลใน Firestore ตาม query ที่ระบุ
  List<Map<String, dynamic>> _searchInFirestore(String query) {
    return _originalPlaces.where((place) {
      final matchQuery =
          place['name'].toString().toLowerCase().contains(query.toLowerCase());
      return matchQuery;
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> _searchCache = {};

  Future<void> _fetchPlaceSuggestions(String query) async {
    print("Fetching place suggestions for query: $query");
    if (_searchCache.containsKey(query)) {
      suggestionsNotifier.value = _searchCache[query]!;
      print("Loaded suggestions from cache");
      return;
    }

    if (_currentPosition == null) {
      print("Current position is null");
      return;
    }

    try {
      // โหลดข้อมูลจาก Firestore
      await _loadPlacesFromFirestore();
      print("Loaded places from Firestore");

      // แปลงข้อมูลจาก Firestore ให้มีฟิลด์ที่สอดคล้องกับ Google Places API
      List<Map<String, dynamic>> firestoreSuggestions = _places.where((place) {
        final name = place['name']?.toString().toLowerCase() ?? '';
        return name.contains(query.toLowerCase());
      }).map((place) {
        return {
          'name': place['name'] ?? 'No name available',
          'place_id': place['place_id'] ?? '', // ใช้ place_id จาก Firestore
          'source': 'firestore', // ระบุแหล่งที่มา
          'lat': place['lat'],
          'lng': place['lng'],
          'type': place['type'] ?? 'unknown',
          'address': place['address'] ?? 'No address available',
        };
      }).toList();

      print(
          "Fetched ${firestoreSuggestions.length} suggestions from Firestore");

      // ดึงข้อมูลจาก Google Places API
      final googleApiUrl =
          'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&key=$_apiKey&components=country:th';
      final googleResponse = await http.get(Uri.parse(googleApiUrl));
      List<Map<String, dynamic>> googleSuggestions = [];

      if (googleResponse.statusCode == 200) {
        final jsonResponse = json.decode(googleResponse.body);
        final predictions = jsonResponse['predictions'] as List;

        googleSuggestions = predictions.map((prediction) {
          return {
            'description': prediction['description'],
            'place_id': prediction['place_id'],
            'source': 'google',
          };
        }).toList();

        print(
            "Fetched ${predictions.length} suggestions from Google Places API");
      } else {
        print(
            "Google Places API error: ${googleResponse.statusCode} - ${googleResponse.body}");
      }

      // รวมผลลัพธ์จาก Firestore และ Google Places API
      List<Map<String, dynamic>> fetchedSuggestions = [
        ...firestoreSuggestions,
        ...googleSuggestions,
      ];

      // คำนวณระยะทางสำหรับแต่ละ Suggestion
      List<Map<String, dynamic>> processedSuggestions = [];
      for (var suggestion in fetchedSuggestions) {
        if (suggestion.containsKey('lat') && suggestion.containsKey('lng')) {
          String distance =
              await _getDistance(suggestion['lat'], suggestion['lng']);
          suggestion['distance'] = distance;
          processedSuggestions.add(suggestion);
        } else if (suggestion['source'] == 'google') {
          final placeDetails = await fetchPlaceDetails(suggestion['place_id']);
          if (placeDetails.containsKey('lat') &&
              placeDetails.containsKey('lng')) {
            String distance =
                await _getDistance(placeDetails['lat'], placeDetails['lng']);
            suggestion['lat'] = placeDetails['lat'];
            suggestion['lng'] = placeDetails['lng'];
            suggestion['distance'] = distance;
            // เพิ่มฟิลด์อื่น ๆ ที่จำเป็นจาก Google Places API
            suggestion['address'] =
                placeDetails['address'] ?? 'No address available';
            suggestion['type'] = placeDetails['type'] ?? 'unknown';
            processedSuggestions.add(suggestion);
          }
        }
      }

      print("Setting suggestions and caching them");
      _searchCache[query] = processedSuggestions; // แคชผลลัพธ์
      suggestionsNotifier.value = processedSuggestions;
    } catch (e) {
      print('Error fetching suggestions: $e');
      suggestionsNotifier.value = [];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching suggestions: $e')),
      );
    }
  }

  void _showFilterDialog() {
    _tempSelectedFilter = _selectedFilter; // กำหนดค่าเริ่มต้นจากตัวแปรเดิม
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // ใช้ StatefulBuilder เพื่ออัปเดตสถานะภายใน dialog
            return AlertDialog(
              title: Text('Filter by Type'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFilterOption(setState, 'Show All', 'all.png', 'all'),
                    _buildFilterOption(
                      setState,
                      'EV Station',
                      'ev_station.png',
                      'ev_station',
                    ),
                    _buildFilterOption(setState, 'Gas Station',
                        'gas_station.png', 'gas_station'),
                    _buildFilterOption(setState, 'Cafe', 'cafe.png', 'cafe'),
                    _buildFilterOption(
                        setState, 'Restaurant', 'restaurant.png', 'restaurant'),
                    _buildFilterOption(setState, 'Store', 'store.png', 'store'),
                    _buildFilterOption(setState, 'Tourist Attraction',
                        'tourist_attraction.png', 'tourist_attraction'),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _selectedFilter =
                        _tempSelectedFilter; // อัปเดตตัวเลือกจริงเมื่อกด Apply
                    _applyFilter(_selectedFilter); // ใช้ฟังก์ชันกรองข้อมูล
                  },
                  child: Text('Apply'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context)
                        .pop(); // ยกเลิกการเปลี่ยนแปลงเมื่อกด Cancel
                  },
                  child: Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFilterOption(
      StateSetter setState, String title, String iconName, String filterType) {
    return CheckboxListTile(
      value: _tempSelectedFilter == filterType, // ตรวจสอบการเลือกชั่วคราว
      onChanged: (bool? value) {
        setState(() {
          // อัปเดตสถานะทันทีที่คลิก
          if (value == true) {
            _tempSelectedFilter = filterType; // อัปเดตค่าชั่วคราวเมื่อเลือก
          } else {
            _tempSelectedFilter = 'all'; // หากยกเลิก ให้กลับไปเลือกทั้งหมด
          }
        });
      },
      title: Row(
        children: [
          if (iconName != 'all')
            Image.asset('assets/icons/$iconName', width: 24, height: 24),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadPlacesFromFirestore() async {
    try {
      // ดึงข้อมูลจาก ev_stations
      QuerySnapshot evStationsSnapshot =
          await FirebaseFirestore.instance.collection('ev_stations').get();
      List<Map<String, dynamic>> evStations =
          evStationsSnapshot.docs.map((doc) {
        return {
          'place_id': doc.id,
          'name': doc['name'],
          'address': doc['address'],
          'lat': doc['lat'],
          'lng': doc['lng'],
          'type': 'ev_station',
          'charging_type': doc['charging_type'],
          'kw': doc['kw'],
          'open_hours': doc['open_hours'],
          'phone': doc['phone'],
          'image_url': doc['image_url'] ?? '',
          'source': 'firestore',
        };
      }).toList();

      // ดึงข้อมูลจาก places
      QuerySnapshot placesSnapshot =
          await FirebaseFirestore.instance.collection('places').get();
      List<Map<String, dynamic>> places = placesSnapshot.docs.map((doc) {
        return {
          'place_id': doc.id,
          'name': doc['name'],
          'address': doc['address'],
          'lat': doc['lat'],
          'lng': doc['lng'],
          'type': doc['type'],
          'open_hours': doc['open_hours'],
          'phone': doc['phone'],
          'image_url': doc['image_url'] ?? '',
          'source': 'firestore',
        };
      }).toList();

      // รวมข้อมูลทั้งหมด
      setState(() {
        _places.addAll(evStations);
        _places.addAll(places);
        _originalPlaces = List.from(_places);
      });

      print(
          "Loaded ${evStations.length} EV stations and ${places.length} places from Firestore");
    } catch (e) {
      print('Error loading places: $e');
    }
  }

  void _setCustomIcons() async {
    _restaurantIcon = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(size: Size(100, 100)),
      'assets/icons/restaurant.png',
    );
    _cafeIcon = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(size: Size(100, 100)),
      'assets/icons/cafe.png',
    );
    _storeIcon = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(size: Size(100, 100)),
      'assets/icons/store.png',
    );
    _touristAttractionIcon = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(size: Size(100, 100)),
      'assets/icons/tourist_attraction.png',
    );
    _gasStationIcon = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(size: Size(100, 100)),
      'assets/icons/gas_station.png',
    );
    _evStationIcon = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(size: Size(100, 100)),
      'assets/icons/ev_station.png',
    );
  }

  Future<void> _checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      throw Exception('Location permissions are denied');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = gms.LatLng(position.latitude, position.longitude);
        print(
            'Current position: $_currentPosition'); // พิมพ์ตำแหน่งปัจจุบันเพื่อเช็ค
        _isLoadingLocation = false;
      });
      if (_currentPosition != null) {
        final controller = await _controllerCompleter.future;
        controller.animateCamera(
          CameraUpdate.newLatLngZoom(_currentPosition!, 14.0),
        );
      }
      _fetchPlaces();
      _loadPlacesFromFirestore();
    } catch (e) {
      print('Error getting current location: $e');
    }
  }

  Future<Map<String, dynamic>> _fetchEVChargingStationDetails(
      String placeId) async {
    final url =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$_apiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final result = jsonResponse['result'];

        if (result == null) {
          throw Exception('Invalid data format from Google API');
        }

        String chargingType = 'EV Charging Station';

        // คุณสามารถปรับปรุงการกำหนดค่า chargingType ตามข้อมูลที่ได้มา
        if (result['types'] != null &&
            (result['types'] as List).contains('charging_station')) {
          chargingType = 'CHAdeMO'; // ตัวอย่างการกำหนดค่า
        }

        final weekdayText = result['opening_hours']?['weekday_text'] ?? [];
        if (weekdayText is! List) {
          throw Exception('weekday_text is not a list');
        }

        List<String> photoReferences = [];
        if (result['photos'] != null) {
          for (var photo in result['photos']) {
            if (photo['photo_reference'] != null) {
              photoReferences.add(photo['photo_reference']);
            }
          }
        }

        return {
          'name': result['name'] ?? 'No name available',
          'address': result['formatted_address'] ?? 'No address available',
          'phone': result['formatted_phone_number'] ?? 'No phone available',
          'international_phone': result['international_phone_number'] ??
              'No international phone available',
          'opening_hours': weekdayText,
          'photos': result['photos'] ?? [],
          'lat': result['geometry']['location']['lat'],
          'lng': result['geometry']['location']['lng'],
          'rating': result['rating'] ?? 0.0,
          'reviews': result['reviews'] ?? [],
          'charging_type': chargingType,
          'place_id': result['place_id'] ?? '',
          'photo_references': photoReferences,
        };
      } else {
        print('Failed to fetch place details: ${response.statusCode}');
        return {};
      }
    } catch (e) {
      print('Error fetching place details: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> fetchPlaceDetails(String placeId) async {
    final url =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$_apiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final result = jsonResponse['result'];

        if (result == null) {
          print('Result is null.');
          return {}; // คืนค่า Map ว่างหาก result เป็น null
        }
        List<String> photoReferences = [];
        if (result['photos'] != null) {
          for (var photo in result['photos']) {
            if (photo['photo_reference'] != null) {
              photoReferences.add(photo['photo_reference']);
            }
          }
        }

        return {
          'name': result['name'] ?? 'No name available',
          'address': result['formatted_address'] ?? 'No address available',
          'phone': result['formatted_phone_number'] ?? 'No phone available',
          'opening_hours':
              result['opening_hours']?['weekday_text'] ?? 'No hours available',
          'reviews': result['reviews'] ?? [],
          'lat': result['geometry']['location']['lat'],
          'lng': result['geometry']['location']['lng'],
          'type': result['types'] != null ? result['types'].first : 'unknown',
          'photo_references': photoReferences,
        };
      } else {
        print('Failed to fetch place details: ${response.statusCode}');
        return {};
      }
    } catch (e) {
      print('Error fetching place details: $e');
      return {};
    }
  }

  Future<void> _fetchEVChargingStations(String location, String radius) async {
    final url =
        'https://maps.googleapis.com/maps/api/place/textsearch/json?query=ev_charging_station&location=$location&radius=$radius&key=$_apiKey';

    List<Map<String, dynamic>> evChargingStations = [];

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final results = jsonResponse['results'] as List<dynamic>;

        if (results.isNotEmpty) {
          for (var result in results) {
            double lat = result['geometry']['location']['lat'] ?? 0.0;
            double lng = result['geometry']['location']['lng'] ?? 0.0;

            if (lat != 0.0 && lng != 0.0) {
              Map<String, dynamic> placeDetails =
                  await _fetchEVChargingStationDetails(
                      result['place_id'] ?? '');

              String placeName = result['name'] ?? 'Unknown';
              if (placeName.toLowerCase().contains('charging') ||
                  placeName.toLowerCase().contains('ev')) {
                evChargingStations.add({
                  'name': result['name'] ?? 'Unknown',
                  'address':
                      result['formatted_address'] ?? 'No address available',
                  'lat': lat,
                  'lng': lng,
                  'place_id': result['place_id'] ?? '',
                  'type': 'electric_vehicle_charging_station',
                  'phone': placeDetails['phone'],
                  'opening_hours': placeDetails['opening_hours'],
                  'reviews': placeDetails['reviews'],
                  'source': 'google',
                });
              }
            }
          }
        }
      } else {
        print(
            'Failed to fetch EV charging stations with status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching EV charging stations: $e');
    }

    setState(() {
      _places.addAll(evChargingStations);
    });
  }

  String getPhotoUrl(String photoReference, int maxWidth) {
    return 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=$maxWidth&photoreference=$photoReference&key=$_apiKey';
  }

  Future<void> _fetchPlaces() async {
    if (_currentPosition == null) return;

    final location =
        '${_currentPosition!.latitude},${_currentPosition!.longitude}';
    final radius = '5000';

    List<String> types = [
      'restaurant',
      'cafe',
      'store',
      'tourist_attraction',
      'gas_station',
    ];
    List<Map<String, dynamic>> allPlaces = [];

    // เรียกฟังก์ชันเพื่อดึง EV Charging Stations
    await _fetchEVChargingStations(location, radius);

    for (String type in types) {
      final url =
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$location&radius=$radius&type=$type&key=$_apiKey';

      try {
        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final jsonResponse = json.decode(response.body);
          final results = jsonResponse['results'] as List<dynamic>;

          if (results.isEmpty) {
            print('No $type found in the area.');
          } else {
            for (var result in results) {
              String address = result['formatted_address'] ??
                  result['vicinity'] ??
                  'No address available';

              double lat = result['geometry']['location']['lat'] ?? 0.0;
              double lng = result['geometry']['location']['lng'] ?? 0.0;

              if (lat != 0.0 && lng != 0.0) {
                Map<String, dynamic> placeDetails =
                    await fetchPlaceDetails(result['place_id'] ?? '');

                allPlaces.add({
                  'name': result['name'] ?? 'Unknown',
                  'address': address,
                  'lat': lat,
                  'lng': lng,
                  'place_id': result['place_id'] ?? '',
                  'type': type,
                  'phone': placeDetails['phone'],
                  'opening_hours': placeDetails['opening_hours'],
                  'reviews': placeDetails['reviews'],
                  'photo_references': placeDetails['photo_references'] ?? [],
                  'source': 'google',
                });
              } else {
                print('Invalid coordinates for place: ${result['name']}');
              }
            }
          }
        } else {
          print(
              'Failed to load places with status code: ${response.statusCode}');
        }
      } catch (e) {
        print('Error fetching places: $e');
      }
    }

    setState(() {
      _places.addAll(allPlaces);
      _originalPlaces = List.from(_places);
      _sortPlacesByDistance();
    });
  }

  void _onMapCreated(gms.GoogleMapController controller) {
    if (!_controllerCompleter.isCompleted) {
      // เพิ่มการตรวจสอบเพื่อป้องกันการเรียก complete ซ้ำ
      _controllerCompleter.complete(controller);
    }
    if (!_isLoadingLocation && _currentPosition != null) {
      controller
          .moveCamera(CameraUpdate.newLatLngZoom(_currentPosition!, 14.0));
    }
  }

  BitmapDescriptor? _getIconForType(String type) {
    switch (type) {
      case 'restaurant':
        return _restaurantIcon;
      case 'cafe':
        return _cafeIcon;
      case 'store':
        return _storeIcon;
      case 'tourist_attraction':
        return _touristAttractionIcon;
      case 'gas_station':
        return _gasStationIcon;
      case 'ev_station':
      case 'electric_vehicle_charging_station':
        return _evStationIcon;
      default:
        return BitmapDescriptor.defaultMarker;
    }
  }

  void _showPlaceDetails(String placeId, gms.LatLng placeLatLng,
      Map<String, dynamic> place) async {
    TextEditingController _reviewController = TextEditingController();
    int _rating = 5;
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    String username =
        FirebaseAuth.instance.currentUser?.displayName ?? 'Anonymous';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) {
            return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // แสดงรูปภาพตามแหล่งที่มา
                      if (place['source'] == 'google' &&
                          place.containsKey('photo_references') &&
                          (place['photo_references'] as List).isNotEmpty)
                        CarouselSlider(
                          options: CarouselOptions(
                            height: 200.0,
                            enableInfiniteScroll: false,
                            enlargeCenterPage: true,
                          ),
                          items: (place['photo_references'] as List)
                              .map((photoRef) {
                            String imageUrl = getPhotoUrl(photoRef, 400);
                            print('Google Image URL: $imageUrl');
                            return Builder(
                              builder: (BuildContext context) {
                                return CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  imageBuilder: (context, imageProvider) =>
                                      Container(
                                    width: MediaQuery.of(context).size.width,
                                    margin:
                                        EdgeInsets.symmetric(horizontal: 5.0),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12.0),
                                      image: DecorationImage(
                                        image: imageProvider,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  placeholder: (context, url) => Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  errorWidget: (context, url, error) {
                                    print('Error loading Google image: $error');
                                    return Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.error, color: Colors.red),
                                        SizedBox(height: 8),
                                        Text(
                                          'Failed to load image',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            );
                          }).toList(),
                        )
                      else if (place['source'] == 'firestore' &&
                          place.containsKey('image_url') &&
                          place['image_url'].isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: place['image_url'],
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) =>
                              Icon(Icons.error, color: Colors.red),
                        ),
                      if (place['source'] == 'firestore' &&
                          (!place.containsKey('image_url') ||
                              place['image_url'].isEmpty))
                        SizedBox.shrink(), // ไม่แสดงอะไรถ้าไม่มีรูป
                      SizedBox(height: 12),
                      // ชื่อสถานที่
                      Row(
                        children: [
                          Icon(Icons.place, color: Colors.blueAccent, size: 24),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              place['name'] ?? 'No name available',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),

                      // ที่อยู่
                      if (place['address'] != null)
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                color: Colors.redAccent, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                place['address'],
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      SizedBox(height: 8),

                      // หมายเลขโทรศัพท์
                      if (place['phone'] != null &&
                          place['phone'].toString().isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.phone, color: Colors.green, size: 20),
                            SizedBox(width: 8),
                            Text(
                              place['phone'],
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      if (place['phone'] != null &&
                          place['phone'].toString().isNotEmpty)
                        SizedBox(height: 8),

                      // เวลาทำการ
                      if (place['opening_hours'] != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.access_time,
                                    color: Colors.orange, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Opening Hours',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            if (place['opening_hours'] is List)
                              ...List.generate(
                                (place['opening_hours'] as List).length,
                                (index) => Text(
                                  place['opening_hours'][index],
                                  style: TextStyle(fontSize: 14),
                                ),
                              )
                            else if (place['opening_hours'] is String)
                              Text(
                                place['opening_hours'],
                                style: TextStyle(fontSize: 14),
                              ),
                          ],
                        ),
                      if (place['opening_hours'] != null) SizedBox(height: 8),

                      Divider(thickness: 1.0),
                      SizedBox(height: 8),

                      // รีวิว
                      FutureBuilder(
                        future: _fetchCombinedReviews(placeId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          }

                          if (snapshot.hasData) {
                            List<Map<String, dynamic>> reviews =
                                snapshot.data as List<Map<String, dynamic>>;

                            if (reviews.isEmpty) {
                              return Text("No reviews yet.");
                            } else {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Reviews:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  ...reviews.map((review) {
                                    return Card(
                                      margin: EdgeInsets.symmetric(vertical: 4),
                                      child: Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  backgroundImage: (review[
                                                                  'profile_photo_url'] !=
                                                              null &&
                                                          review['profile_photo_url']
                                                              .isNotEmpty)
                                                      ? NetworkImage(review[
                                                          'profile_photo_url'])
                                                      : (review['profileImageUrl'] !=
                                                                  null &&
                                                              review['profileImageUrl']
                                                                  .isNotEmpty
                                                          ? NetworkImage(review[
                                                              'profileImageUrl'])
                                                          : null),
                                                  radius: 14,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  review['username'] ??
                                                      'Unknown user',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 4),
                                            Row(
                                              children:
                                                  List.generate(5, (index) {
                                                return Icon(
                                                  index <
                                                          (review['rating'] ??
                                                              0)
                                                      ? Icons.star
                                                      : Icons.star_border,
                                                  color: Colors.amber,
                                                  size: 16,
                                                );
                                              }),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              review['review'] ??
                                                  'No review text available',
                                              style: TextStyle(fontSize: 14),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ],
                              );
                            }
                          } else if (snapshot.hasError) {
                            return Text("Error: ${snapshot.error}");
                          } else {
                            return CircularProgressIndicator();
                          }
                        },
                      ),
                      Divider(thickness: 1.0),
                      SizedBox(height: 8),

                      // ระบบการให้คะแนน (Rating stars)
                      Text(
                        'Rate this place:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blueAccent,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: List.generate(5, (index) {
                          return IconButton(
                            icon: Icon(
                              index < _rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 24,
                            ),
                            onPressed: () {
                              setState(() {
                                _rating = index + 1;
                              });
                            },
                          );
                        }),
                      ),
                      SizedBox(height: 8),

                      // ฟอร์มรีวิว
                      TextField(
                        controller: _reviewController,
                        decoration: InputDecoration(
                          labelText: 'Write your review',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(fontSize: 14),
                      ),
                      SizedBox(height: 12),

                      // ปุ่ม Submit รีวิว
                      OutlinedButton(
                        onPressed: () async {
                          await _submitReview(
                            placeId: place['place_id'],
                            type: place['type'] ?? 'ev_station',
                            reviewText: _reviewController.text,
                            rating: _rating,
                            userId: userId,
                            username: username,
                          );
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Submit',
                          style:
                              TextStyle(color: Colors.blueAccent, fontSize: 16),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.blueAccent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                      SizedBox(height: 12),

                      // ปุ่ม Favorite และ Go
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              widget.onAddToFavorites(place);
                              Navigator.pop(context);
                            },
                            icon: Icon(Icons.favorite_border,
                                color: Colors.blueAccent),
                            label: Text(
                              'Favorite',
                              style: TextStyle(color: Colors.blueAccent),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.blueAccent),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              padding: EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 20),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              widget.onAddToHistory({
                                'name': place['name'] ?? 'Unknown',
                                'address': place['address'] ?? 'Unknown',
                                'phone': place['phone'] ?? 'Unknown',
                                'lat': placeLatLng.latitude,
                                'lng': placeLatLng.longitude,
                                'type': place['type'] ?? 'Unknown',
                                'date': DateTime.now().toString(),
                                'time': DateTime.now().toString().split(' ')[1],
                              });
                              Navigator.pop(context);
                              _fetchRouteAndNavigate(placeLatLng);
                            },
                            icon: Icon(Icons.directions,
                                color: Colors.blueAccent),
                            label: Text(
                              'Go',
                              style: TextStyle(color: Colors.blueAccent),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.blueAccent),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              padding: EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 20),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ));
          },
        );
      },
    );
  }

  Future<String> fetchUsernameFromFirestore(String userId) async {
    DocumentSnapshot userSnapshot =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (userSnapshot.exists) {
      return userSnapshot.get('username'); // ดึงฟิลด์ username จาก Firestore
    } else {
      return 'Anonymous'; // ถ้าไม่มีข้อมูล
    }
  }

  Future<void> _submitReview({
    required String username,
    required String placeId,
    required String type, // ev_station หรือ place
    required String reviewText,
    required int rating,
    required String? userId,
  }) async {
    String username = 'Anonymous';
    String? profilePhotoUrl;

    if (userId != null) {
      try {
        username = await fetchUsernameFromFirestore(userId);
        // ดึง URL รูปโปรไฟล์จาก Firestore ถ้ามี
        DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        if (userSnapshot.exists && userSnapshot.data() != null) {
          profilePhotoUrl = userSnapshot.get('profile_photo_url') ?? '';
        }
      } catch (e) {
        print('Error fetching user details: $e');
        // ค่า username จะเป็น 'Anonymous' และ profilePhotoUrl จะเป็น null หรือ ''
      }
    }

    if (userId != null) {
      try {
        await FirebaseFirestore.instance.collection('places_reviews').add({
          'place_id': placeId,
          'type': type.isNotEmpty ? type : 'unknown',
          'review':
              reviewText.isNotEmpty ? reviewText : 'No review text provided',
          'rating': rating >= 0 && rating <= 5 ? rating : 0,
          'user_id': userId,
          'username': username.isNotEmpty ? username : 'Anonymous',
          'created_at': FieldValue.serverTimestamp(),
          'profile_photo_url': profilePhotoUrl ?? '',
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Review submitted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit review')),
        );
        print('Error submitting review: $e');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please log in to submit a review')),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCombinedReviews(
      String placeId) async {
    List<Map<String, dynamic>> combinedReviews = [];

    // 1. Fetch reviews from Google Places API
    final googleReviews = await _fetchGoogleReviews(placeId);

    // 2. Fetch reviews from Firestore
    final firestoreReviews = await _fetchReviewsFromFirestore(placeId);

    // Combine both reviews into one list
    combinedReviews.addAll(googleReviews);
    combinedReviews.addAll(firestoreReviews);

    return combinedReviews;
  }

  Future<List<Map<String, dynamic>>> _fetchGoogleReviews(String placeId) async {
    try {
      final url =
          'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=AIzaSyB67ZhLCsWm7sC9pUluesjiCOT-Wwu67oU';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        // ตรวจสอบว่ามีฟิลด์ 'result' และ 'reviews' หรือไม่
        if (jsonResponse['result'] != null &&
            jsonResponse['result']['reviews'] != null) {
          final reviews = jsonResponse['result']['reviews'];

          if (reviews.isNotEmpty) {
            return reviews.map<Map<String, dynamic>>((review) {
              return {
                'username': review['author_name'],
                'review': review['text'],
                'rating': review['rating'],
                'created_at':
                    DateTime.fromMillisecondsSinceEpoch(review['time'] * 1000),
                'profile_photo_url': review['profile_photo_url'] ?? '',
              };
            }).toList();
          } else {
            return [];
          }
        } else {
          print("No reviews field found in the Google API response");
          return [];
        }
      } else {
        print("Failed to fetch Google reviews: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Error fetching Google reviews: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchReviewsFromFirestore(
      String placeId) async {
    try {
      QuerySnapshot reviewSnapshot = await FirebaseFirestore.instance
          .collection('places_reviews')
          .where('place_id', isEqualTo: placeId)
          .orderBy('created_at', descending: true)
          .get();

      List<Map<String, dynamic>> reviews = [];

      for (var doc in reviewSnapshot.docs) {
        String username = doc['username'] ?? 'Anonymous';
        String? userId = doc['user_id'];
        String? profileImageUrl;

        if (userId != null) {
          DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
          if (userSnapshot.exists) {
            profileImageUrl = userSnapshot.get('profileImageUrl');
          }
        }

        reviews.add({
          'username': username,
          'review': doc['review'],
          'rating': doc['rating'],
          'created_at': (doc['created_at'] as Timestamp).toDate(),
          'profileImageUrl': profileImageUrl,
        });
      }

      return reviews;
    } catch (e) {
      print("Error fetching reviews from Firestore: $e");
      return [];
    }
  }

  void _fetchRouteAndNavigate(gms.LatLng destination) async {
    if (_currentPosition == null) return;

    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${_currentPosition!.latitude},${_currentPosition!.longitude}&destination=${destination.latitude},${destination.longitude}&key=$_apiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final route = jsonResponse['routes'][0];
        final polylinePoints = route['overview_polyline']['points'];
        final legs = route['legs'][0];
        final distance = legs['distance']['text'];
        final duration = legs['duration']['text'];

        // ลบ polyline เก่าก่อนสร้างใหม่
        _clearRoute();
        _createPolylinesFromEncodedString(polylinePoints);

        setState(() {
          _distanceText = distance;
          _durationText = duration;
          _isNavigating = true;
        });
      } else {
        throw Exception('Failed to fetch directions');
      }
    } catch (e) {
      print('Error fetching directions: $e');
    }
  }

  void _createPolylinesFromEncodedString(String encodedPolyline) {
    final List<gms.LatLng> polylineCoordinates =
        _decodePolyline(encodedPolyline);

    setState(() {
      _polylines.clear(); // ล้าง polyline เก่าก่อน
      _polylines.add(
        gms.Polyline(
          polylineId: polylineId,
          width: 5,
          color: Colors.blue,
          points: polylineCoordinates,
        ),
      );
    });
  }

  List<gms.LatLng> _decodePolyline(String encoded) {
    List<gms.LatLng> polylineCoordinates = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      polylineCoordinates.add(gms.LatLng(
        (lat / 1E5).toDouble(),
        (lng / 1E5).toDouble(),
      ));
    }
    return polylineCoordinates;
  }

  Future<void> _goToCurrentLocation() async {
    if (_currentPosition == null) return;

    final controller = await _controllerCompleter.future;
    controller.animateCamera(
      CameraUpdate.newLatLngZoom(_currentPosition!, 14.0),
    );
  }

  Future<void> _addPlaceRequestToFirestore(
    String type,
    String name,
    String address,
    gms.LatLng location,
    String phone,
    String openHours,
    String chargingType,
    double kw,
    String imageUrl,
  ) async {
    try {
      // ตรวจสอบประเภทของสถานที่ แล้วกำหนดคอลเล็กชันที่เหมาะสม
      String collectionName =
          type == 'ev_station' ? 'station_requests' : 'place_requests';

      // อ้างอิงถึงเอกสาร metadata สำหรับการติดตาม lastRequestId
      DocumentReference metadataRef = FirebaseFirestore.instance
          .collection('metadata')
          .doc(type == 'ev_station'
              ? 'station_request_metadata'
              : 'place_request_metadata');

      // ดึงเอกสาร metadata เพื่อรับค่า lastRequestId
      DocumentSnapshot metadataSnapshot = await metadataRef.get();

      // กำหนดค่า lastRequestId จาก metadata หรือใช้ค่า 0 ถ้าไม่มีข้อมูล
      int lastRequestId =
          metadataSnapshot.exists && metadataSnapshot.data() != null
              ? metadataSnapshot['lastRequestId']
              : 0;

      // สร้าง request ID ใหม่ โดยเพิ่มจาก lastRequestId
      String newRequestId = 'request_id${lastRequestId + 1}';

      // ข้อมูลที่จะบันทึกในคำขอ
      Map<String, dynamic> data = {
        'name': name.isNotEmpty ? name : 'No name provided',
        'address': address.isNotEmpty ? address : 'No address provided',
        'lat': location.latitude,
        'lng': location.longitude,
        'phone': phone.isNotEmpty ? phone : 'No phone provided',
        'open_hours':
            openHours.isNotEmpty ? openHours : 'No open hours provided',
        'type': type.isNotEmpty ? type : 'unknown',
        'status': 'pending', // สถานะเริ่มต้นเป็น pending รอการอนุมัติ
        'requested_at': Timestamp.now(),
        'image_url': imageUrl.isNotEmpty ? imageUrl : '',
      };

      // กรณีเป็นสถานี EV ให้บันทึกข้อมูลเฉพาะเพิ่มเติม
      if (type == 'ev_station') {
        data['charging_type'] =
            chargingType.isNotEmpty ? chargingType : 'Unknown';
        data['kw'] = kw > 0.0 ? kw : 0.0;
      }

      // บันทึกคำขอลงในคอลเล็กชันที่เหมาะสม
      await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(newRequestId)
          .set(
              data,
              SetOptions(
                  merge: true)); // ใช้ merge เพื่อไม่เขียนทับข้อมูลที่มีอยู่

      // อัปเดตเอกสาร metadata ด้วยการเพิ่มค่า lastRequestId
      await metadataRef.set({
        'lastRequestId': lastRequestId + 1,
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to send request: $e');
    }
  }

  void _showEVStationDetails(
      Map<String, dynamic> place, gms.LatLng placeLatLng) {
    TextEditingController _reviewController = TextEditingController();
    int _rating = 5;
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    String username =
        FirebaseAuth.instance.currentUser?.displayName ?? 'Anonymous';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) {
            return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // แสดงรูปภาพตามแหล่งที่มา
                      if (place['source'] == 'google' &&
                          place.containsKey('photo_references') &&
                          (place['photo_references'] as List).isNotEmpty)
                        CarouselSlider(
                          options: CarouselOptions(
                            height: 200.0,
                            enableInfiniteScroll: false,
                            enlargeCenterPage: true,
                          ),
                          items: (place['photo_references'] as List)
                              .map((photoRef) {
                            String imageUrl = getPhotoUrl(photoRef, 400);
                            print('Google Image URL: $imageUrl');
                            return Builder(
                              builder: (BuildContext context) {
                                return CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  imageBuilder: (context, imageProvider) =>
                                      Container(
                                    width: MediaQuery.of(context).size.width,
                                    margin:
                                        EdgeInsets.symmetric(horizontal: 5.0),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12.0),
                                      image: DecorationImage(
                                        image: imageProvider,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  placeholder: (context, url) => Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  errorWidget: (context, url, error) {
                                    print('Error loading Google image: $error');
                                    return Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.error, color: Colors.red),
                                        SizedBox(height: 8),
                                        Text(
                                          'Failed to load image',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            );
                          }).toList(),
                        )
                      else if (place['source'] == 'firestore' &&
                          place.containsKey('image_url') &&
                          place['image_url'].isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: place['image_url'],
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) =>
                              Icon(Icons.error, color: Colors.red),
                        ),
                      if (place['source'] == 'firestore' &&
                          (!place.containsKey('image_url') ||
                              place['image_url'].isEmpty))
                        SizedBox.shrink(), // ไม่แสดงอะไรถ้าไม่มีรูป
                      SizedBox(height: 12),
                      // ชื่อสถานี EV
                      Row(
                        children: [
                          Icon(Icons.ev_station,
                              color: Colors.blueAccent, size: 24),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              place['name'] ?? 'No name available',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),

                      // ที่อยู่
                      if (place['address'] != null)
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                color: Colors.redAccent, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                place['address'],
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      SizedBox(height: 8),

                      // หมายเลขโทรศัพท์
                      if (place['phone'] != null &&
                          place['phone'].toString().isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.phone, color: Colors.green, size: 20),
                            SizedBox(width: 8),
                            Text(
                              place['phone'],
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      if (place['phone'] != null &&
                          place['phone'].toString().isNotEmpty)
                        SizedBox(height: 8),

                      // เวลาทำการ
                      if (place['open_hours'] != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.access_time,
                                    color: Colors.orange, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Opening Hours',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            if (place['open_hours'] is List)
                              ...List.generate(
                                (place['open_hours'] as List).length,
                                (index) => Text(
                                  place['open_hours'][index],
                                  style: TextStyle(fontSize: 14),
                                ),
                              )
                            else if (place['open_hours'] is String)
                              Text(
                                place['open_hours'],
                                style: TextStyle(fontSize: 14),
                              ),
                          ],
                        ),
                      if (place['open_hours'] != null) SizedBox(height: 8),

                      // ประเภทการชาร์จ
                      if (place['charging_type'] != null)
                        Row(
                          children: [
                            Icon(Icons.electrical_services,
                                color: Colors.deepPurpleAccent, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Charging Type: ${place['charging_type']}',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      if (place['charging_type'] != null) SizedBox(height: 8),

                      // กำลังไฟฟ้า (kW)
                      if (place['kw'] != null)
                        Row(
                          children: [
                            Icon(Icons.bolt,
                                color: Colors.yellow[700], size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Power: ${place['kw']} kW',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      if (place['kw'] != null) SizedBox(height: 8),

                      Divider(thickness: 1.0),
                      SizedBox(height: 8),

                      // รีวิว
                      FutureBuilder(
                        future: _fetchCombinedReviews(place['place_id']),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          }

                          if (snapshot.hasData) {
                            List<Map<String, dynamic>> reviews =
                                snapshot.data as List<Map<String, dynamic>>;

                            if (reviews.isEmpty) {
                              return Text("No reviews yet.");
                            } else {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Reviews:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  ...reviews.map((review) {
                                    return Card(
                                      margin: EdgeInsets.symmetric(vertical: 4),
                                      child: Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  backgroundImage: (review[
                                                                  'profile_photo_url'] !=
                                                              null &&
                                                          review['profile_photo_url']
                                                              .isNotEmpty)
                                                      ? NetworkImage(review[
                                                          'profile_photo_url'])
                                                      : (review['profileImageUrl'] !=
                                                                  null &&
                                                              review['profileImageUrl']
                                                                  .isNotEmpty
                                                          ? NetworkImage(review[
                                                              'profileImageUrl'])
                                                          : null),
                                                  radius: 14,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  review['username'] ??
                                                      'Unknown user',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 4),
                                            Row(
                                              children:
                                                  List.generate(5, (index) {
                                                return Icon(
                                                  index <
                                                          (review['rating'] ??
                                                              0)
                                                      ? Icons.star
                                                      : Icons.star_border,
                                                  color: Colors.amber,
                                                  size: 16,
                                                );
                                              }),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              review['review'] ??
                                                  'No review text available',
                                              style: TextStyle(fontSize: 14),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ],
                              );
                            }
                          } else if (snapshot.hasError) {
                            return Text("Error: ${snapshot.error}");
                          } else {
                            return CircularProgressIndicator();
                          }
                        },
                      ),
                      Divider(thickness: 1.0),
                      SizedBox(height: 8),

                      // ระบบการให้คะแนน (Rating stars)
                      Text(
                        'Rate this station:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blueAccent,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: List.generate(5, (index) {
                          return IconButton(
                            icon: Icon(
                              index < _rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 24,
                            ),
                            onPressed: () {
                              setState(() {
                                _rating = index + 1;
                              });
                            },
                          );
                        }),
                      ),
                      SizedBox(height: 8),

                      // ฟอร์มรีวิว
                      TextField(
                        controller: _reviewController,
                        decoration: InputDecoration(
                          labelText: 'Write your review',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                        ),
                        maxLines: 1,
                        style: TextStyle(fontSize: 14),
                      ),
                      SizedBox(height: 12),

                      // ปุ่ม Submit รีวิว
                      OutlinedButton(
                        onPressed: () async {
                          await _submitReview(
                            placeId: place['place_id'],
                            type: place['type'] ?? 'ev_station',
                            reviewText: _reviewController.text,
                            rating: _rating,
                            userId: userId,
                            username: username,
                          );
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Submit',
                          style:
                              TextStyle(color: Colors.blueAccent, fontSize: 16),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.blueAccent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                      SizedBox(height: 12),

                      // ปุ่ม Favorite และ Go
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              widget.onAddToFavorites(place);
                              Navigator.pop(context);
                            },
                            icon: Icon(Icons.favorite_border,
                                color: Colors.blueAccent),
                            label: Text(
                              'Favorite',
                              style: TextStyle(color: Colors.blueAccent),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.blueAccent),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              padding: EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 20),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              widget.onAddToHistory({
                                'name': place['name'] ?? 'Unknown',
                                'address': place['address'] ?? 'Unknown',
                                'phone': place['phone'] ?? 'Unknown',
                                'lat': placeLatLng.latitude,
                                'lng': placeLatLng.longitude,
                                'type': place['type'] ?? 'Unknown',
                                'date': DateTime.now().toString(),
                                'time': DateTime.now().toString().split(' ')[1],
                              });
                              Navigator.pop(context);
                              _fetchRouteAndNavigate(placeLatLng);
                            },
                            icon: Icon(Icons.directions,
                                color: Colors.blueAccent),
                            label: Text(
                              'Go',
                              style: TextStyle(color: Colors.blueAccent),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.blueAccent),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              padding: EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 20),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ));
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _calculateAndSortPlacesByDistance(
      List<Map<String, dynamic>> suggestions) async {
    List<Map<String, dynamic>> suggestionsWithDistance = [];

    for (var suggestion in suggestions) {
      final placeId = suggestion['place_id'];
      final placeDetails = await fetchPlaceDetails(placeId);
      final lat = placeDetails['lat'];
      final lng = placeDetails['lng'];

      if (lat != null && lng != null) {
        // คำนวณระยะทาง
        String distanceStr = await _getDistance(lat, lng);
        double distance;
        try {
          distance = double.parse(distanceStr.split(' ')[0]);
        } catch (e) {
          distance =
              double.infinity; // กำหนดค่าระยะทางสูงสุดหากไม่สามารถคำนวณได้
        }
        suggestionsWithDistance.add({
          ...suggestion,
          'lat': lat,
          'lng': lng,
          'distance': distanceStr,
          'distanceValue':
              distance, // เก็บค่าระยะทางในรูปแบบตัวเลขเพื่อใช้ในการเรียง
        });
      }
    }

    // เรียงลำดับตามระยะทางจากน้อยไปมาก
    suggestionsWithDistance.sort((a, b) =>
        (a['distanceValue'] as double).compareTo(b['distanceValue'] as double));

    return suggestionsWithDistance;
  }

  void _clearRoute() {
    setState(() {
      _polylines.clear();
      _isNavigating = false;
      _distanceText = null;
      _durationText = null;
    });
  }

  void _showSearchScreen(BuildContext context) async {
    final selectedPlace = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text("Search"),
            automaticallyImplyLeading: false, // ไม่แสดงปุ่มย้อนกลับ
          ),
          body: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  autofocus: true,
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search Places...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    prefixIcon: Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _suggestions.clear();
                        });
                        Navigator.pop(context); // ปิดหน้าค้นหา
                      },
                    ),
                  ),
                  onChanged: _handleSearchChanged,
                ),
              ),
              Expanded(
                child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                  valueListenable: suggestionsNotifier,
                  builder: (context, suggestions, child) {
                    return FutureBuilder<List<Map<String, dynamic>>>(
                      future: _calculateAndSortPlacesByDistance(suggestions),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(
                              child: Text('Error: ${snapshot.error}'));
                        }
                        if (snapshot.hasData) {
                          List<Map<String, dynamic>> sortedSuggestions =
                              snapshot.data!;
                          return ListView.builder(
                            itemCount: _searchHistory.length +
                                sortedSuggestions.length,
                            itemBuilder: (context, index) {
                              if (index < _searchHistory.length) {
                                String historyItem = _searchHistory[index];
                                return Column(
                                  children: [
                                    ListTile(
                                      title: Text(historyItem),
                                      onTap: () {
                                        _searchAllPlaces(historyItem);
                                      },
                                      trailing: IconButton(
                                        icon: Icon(Icons.delete),
                                        onPressed: () {
                                          _clearSearchHistory(historyItem);
                                        },
                                      ),
                                    ),
                                    Divider(),
                                  ],
                                );
                              } else {
                                var suggestion = sortedSuggestions[
                                    index - _searchHistory.length];
                                return ListTile(
                                  title: Text(
                                      suggestion['description'] ?? 'Unknown'),
                                  subtitle: Text(
                                      'Distance: ${suggestion['distance'] ?? 'Calculating...'}'),
                                  onTap: () {
                                    // ส่งข้อมูลสถานที่ที่ถูกเลือกกลับมายังหน้าหลัก
                                    Navigator.pop(context, suggestion);
                                  },
                                );
                              }
                            },
                          );
                        }
                        return Center(child: Text('No suggestions'));
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selectedPlace != null) {
      await onSuggestionSelected(selectedPlace);
    }
  }

  void _showAddPlaceDialog() {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController();
    final openHoursController = TextEditingController();

    String selectedType = 'ev_station';
    String selectedChargingType = 'Type 1';
    final List<String> placeTypes = [
      'ev_station',
      'restaurant',
      'cafe',
      'store',
      'gas_station'
    ];

    final List<String> chargingTypes = [
      'Type 1',
      'Type 2',
      'CSS',
      'CHAdeMO',
      'GB/T',
      'Tesla',
    ];

    final TextEditingController kwController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> _pickImage() async {
              final picker = ImagePicker();
              final pickedFile =
                  await picker.pickImage(source: ImageSource.gallery);
              if (pickedFile != null) {
                setState(() {
                  _selectedImage = File(pickedFile.path);
                });
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              title: Text(
                'Add New Place',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      items: placeTypes.map((String type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(
                            type.replaceAll('_', ' ').toUpperCase(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedType = value!;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Place Type',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: addressController,
                      decoration: InputDecoration(
                        labelText: 'Address',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: openHoursController,
                      decoration: InputDecoration(
                        labelText: 'Open Hours',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    if (selectedType == 'ev_station') ...[
                      DropdownButtonFormField<String>(
                        value: selectedChargingType,
                        items: chargingTypes.map((String type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Text(
                              type,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedChargingType = value!;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Charging Type',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: kwController,
                        decoration: InputDecoration(
                          labelText: 'kW',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 12),
                    ],
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: Icon(Icons.image),
                      label: Text('Upload Image (Optional)'),
                    ),
                    SizedBox(height: 8),
                    if (_selectedImage != null)
                      Image.file(
                        _selectedImage!,
                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty ||
                        addressController.text.isEmpty ||
                        phoneController.text.isEmpty ||
                        openHoursController.text.isEmpty ||
                        (selectedType == 'ev_station' &&
                            (selectedChargingType.isEmpty ||
                                kwController.text.isEmpty))) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Please fill all required fields')),
                      );
                      return;
                    }

                    String imageUrl = '';
                    if (_selectedImage != null) {
                      // อัปโหลดรูปภาพไปยัง Firebase Storage
                      String fileName =
                          '${DateTime.now().millisecondsSinceEpoch}.jpg';
                      Reference storageRef = FirebaseStorage.instance
                          .ref()
                          .child('place_images')
                          .child(fileName);

                      UploadTask uploadTask =
                          storageRef.putFile(_selectedImage!);
                      TaskSnapshot snapshot =
                          await uploadTask.whenComplete(() => null);
                      imageUrl = await snapshot.ref.getDownloadURL();
                    }

                    final newStationLatLng = gms.LatLng(
                      _currentPosition?.latitude ?? 0.0,
                      _currentPosition?.longitude ?? 0.0,
                    );

                    await _addPlaceRequestToFirestore(
                      selectedType,
                      nameController.text,
                      addressController.text,
                      newStationLatLng,
                      phoneController.text,
                      openHoursController.text,
                      selectedType == 'ev_station' ? selectedChargingType : '',
                      selectedType == 'ev_station'
                          ? double.tryParse(kwController.text) ?? 0.0
                          : 0.0,
                      imageUrl,
                    );

                    Navigator.pop(context); // ปิด Dialog หลังจากส่งคำขอ

                    setState(() {
                      _selectedImage = null;
                    });

                    // แสดงข้อความแจ้งเตือน
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Request sent to Admin for approval'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  ),
                  child: Text(
                    'Save',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentPosition == null
          ? Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                gms.GoogleMap(
                  mapType: gms.MapType.normal,
                  myLocationButtonEnabled: false,
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: gms.CameraPosition(
                    target: _currentPosition!,
                    zoom: 14.0,
                  ),
                  markers: _places.map((place) {
                    final lat = place['lat'] ?? 0.0;
                    final lng = place['lng'] ?? 0.0;
                    final placeLatLng = gms.LatLng(lat, lng);
                    final icon = _getIconForType(place['type'] ?? '');

                    return gms.Marker(
                      markerId: gms.MarkerId(
                          place['place_id']?.toString() ?? 'unknown'),
                      position: placeLatLng,
                      infoWindow: gms.InfoWindow(
                        title: place['name'] ?? 'No name available',
                        snippet: place['address'] ?? 'No address available',
                        onTap: () {
                          if (place['type'] == 'ev_station' ||
                              place['type'] ==
                                  'electric_vehicle_charging_station') {
                            _showEVStationDetails(place, placeLatLng);
                          } else {
                            _showPlaceDetails(place['place_id'].toString(),
                                placeLatLng, place);
                          }
                        },
                      ),
                      icon: icon ?? BitmapDescriptor.defaultMarker,
                    );
                  }).toSet(),
                  polylines: _polylines,
                  zoomControlsEnabled: false,
                  myLocationEnabled: true,
                ),
                Positioned(
                  top: 80,
                  left: 16,
                  child: FloatingActionButton(
                    onPressed: () => _showSearchScreen(context),
                    heroTag: 'search', // heroTag สำหรับปุ่มค้นหา
                    backgroundColor: Colors.white,
                    shape: CircleBorder(),
                    child: Icon(
                      Icons.search,
                      color: Colors.black, // ปรับสีไอคอน
                      size: 26, // ขนาดไอคอน
                    ),
                  ),
                ),
                Positioned(
                  bottom: 100,
                  right: 16,
                  child: FloatingActionButton(
                    onPressed: _showAddPlaceDialog,
                    heroTag: 'add', // heroTag สำหรับปุ่มเพิ่มสถานที่
                    backgroundColor: Colors.white,
                    shape: CircleBorder(),
                    child: Icon(
                      Icons.add,
                      color: Colors.black,
                      size: 26,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 160,
                  right: 16,
                  child: FloatingActionButton(
                    onPressed: _getCurrentLocation,
                    heroTag:
                        'currentLocation', // heroTag สำหรับปุ่มตำแหน่งปัจจุบัน
                    backgroundColor: Colors.white,
                    shape: CircleBorder(), // ใช้รูปร่างวงกลม
                    child: Icon(
                      Icons.my_location,
                      color: Colors.blueAccent,
                      size: 26,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 100,
                  left: 16,
                  child: FloatingActionButton(
                    onPressed: _showFilterDialog,
                    heroTag: 'filter', // heroTag สำหรับปุ่มกรองข้อมูล
                    backgroundColor: Colors.white,
                    shape: CircleBorder(),
                    child: Icon(
                      Icons.filter_list,
                      color: Colors.black,
                      size: 26,
                    ),
                  ),
                ),
                if (_isNavigating)
                  Positioned(
                    top: 70,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8.0,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Navigating...',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              Icon(
                                Icons.navigation,
                                color: Colors.blue,
                                size: 24,
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          if (_distanceText != null)
                            Text(
                              'Distance: $_distanceText',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black54,
                              ),
                            ),
                          if (_durationText != null)
                            Text(
                              'Duration: $_durationText',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black54,
                              ),
                            ),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _clearRoute,
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.redAccent,
                              padding: EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.cancel, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Cancel Navigation'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
