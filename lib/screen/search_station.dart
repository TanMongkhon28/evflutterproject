import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gms;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final String _apiKey = 'AIzaSyCrOHVlCBGDkDoO88AD_E_m3C1vPXB02OI';
  List<Map<String, dynamic>> _places = [];
  TextEditingController _searchController = TextEditingController();
  bool _isLoadingLocation = true;
  bool _isNavigating = false;
  String? _distanceText;
  String? _durationText;
  List<String> _searchHistory = [];
  List<Map<String, dynamic>> _originalPlaces = [];
  String? _selectedFilter = 'all';
  String? _tempSelectedFilter;

  Set<gms.Polyline> _polylines = {};
  gms.PolylineId polylineId = gms.PolylineId('route');

  @override
  void initState() {
    super.initState();
    _setCustomIcons();
    _checkPermissions().then((_) {
      _getCurrentLocation();
    }).catchError((e) {
      print('Error checking permissions: $e');
    });

    // โหลดประวัติการค้นหาเมื่อเริ่มต้น
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

  // ลบประวัติการค้นหาทั้งหมด
  void _clearSearchHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('search_history');
    setState(() {
      _searchHistory.clear();
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
    controller.animateCamera(CameraUpdate.newLatLngZoom(position, 14.0));
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
      } else {
        // กรองตามประเภทที่เลือก
        _places = _originalPlaces.where((place) {
          return place['type'].toString().toLowerCase() == filterType;
        }).toList();
      }
    });
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
                        setState, 'EV Station', 'ev_station.png', 'ev_station'),
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
    setState(() {
      _places.clear();
    });

    try {
      // ดึงข้อมูลจาก ev_stations
      QuerySnapshot evStationsSnapshot =
          await FirebaseFirestore.instance.collection('ev_stations').get();
      setState(() {
        _places.addAll(evStationsSnapshot.docs.map((doc) {
          return {
            'place_id': doc.id,
            'name': doc['name'],
            'address': doc['address'],
            'lat': doc['lat'],
            'lng': doc['lng'],
            'type': 'ev_station',
            'charging_type': doc['charging_type'],
            'open_hours': doc['open_hours'],
            'phone': doc['phone'],
          };
        }).toList());
      });

      // ดึงข้อมูลจาก places
      QuerySnapshot placesSnapshot =
          await FirebaseFirestore.instance.collection('places').get();
      setState(() {
        _places.addAll(placesSnapshot.docs.map((doc) {
          return {
            'place_id': doc.id,
            'name': doc['name'],
            'address': doc['address'],
            'lat': doc['lat'],
            'lng': doc['lng'],
            'type': doc['type'],
            'open_hours': doc['open_hours'],
            'phone': doc['phone'],
          };
        }).toList());
      });
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

  Future<Map<String, dynamic>> _fetchEVChargingStationDetails(String placeId) async {
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

      final weekdayText = result['opening_hours']?['weekday_text'] ?? [];
      if (weekdayText is! List) {
        throw Exception('weekday_text is not a list');
      }

      return {
        'name': result['name'] ?? 'No name available',
        'address': result['formatted_address'] ?? 'No address available',
        'phone': result['formatted_phone_number'] ?? 'No phone available',
        'international_phone':
            result['international_phone_number'] ?? 'No international phone available',
        'opening_hours': weekdayText,
        'photos': result['photos'] ?? [],
        'lat': result['geometry']['location']['lat'],
        'lng': result['geometry']['location']['lng'],
        'rating': result['rating'] ?? 0.0,
        'reviews': result['reviews'] ?? [],
        'charging_type': chargingType,
        'place_id': result['place_id'] ?? '',
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

                         // ตรวจสอบประเภทจากชื่อแทน types
            String placeName = result['name'] ?? 'Unknown';
            if (placeName.toLowerCase().contains('charging') || placeName.toLowerCase().contains('ev')) {
              evChargingStations.add({
                'name': result['name'] ?? 'Unknown',
                'address': result['formatted_address'] ?? 'No address available',
                'lat': lat,
                'lng': lng,
                'place_id': result['place_id'] ?? '',
                'type': 'electric_vehicle_charging_station',  // กำหนด type ให้ตรงกับ EV Station
                'phone': placeDetails['phone'],
                'opening_hours': placeDetails['opening_hours'],
                'charging_type': placeDetails['charging_type'],
                'reviews': placeDetails['reviews'],
              });
            }
          }
        }
      }
    } else {
      print('Failed to fetch EV charging stations with status code: ${response.statusCode}');
    }
  } catch (e) {
    print('Error fetching EV charging stations: $e');
  }

  setState(() {
    _places.addAll(evChargingStations);
  });
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
                  'charging_type': result['charging_type'] ?? 'Unknown',
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

  Future<void> _showPlaceDetails(String placeId, gms.LatLng placeLatLng,
      Map<String, dynamic> place) async {
    late Map<String, dynamic> placeDetails;

    // ตรวจสอบประเภทของ place เพื่อใช้ในการดึงข้อมูล
    if (place['type'] != null) {
      if (place['type'] == 'ev_station' ||
          place['type'] ==
              'electric_vehicle_charging_station' || // เพิ่ม ev_charging_station
          place['type'] == 'cafe' ||
          place['type'] == 'restaurant' ||
          place['type'] == 'gas_station' ||
          place['type'] == 'tourist_attraction'||
          place['type'] == 'store') {
        placeDetails = place;
      } else {
        throw Exception('Place type not supported');
      }
    } else {
      placeDetails = await fetchPlaceDetails(placeId);
    }

    if (placeDetails.isNotEmpty && _currentPosition != null) {
      TextEditingController _reviewController = TextEditingController();
      int _rating = 5; // ค่าเริ่มต้นสำหรับการให้คะแนน
      String? userId = FirebaseAuth.instance.currentUser?.uid;
      String username =
          FirebaseAuth.instance.currentUser?.displayName ?? 'Anonymous';

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10.0,
                      spreadRadius: 5.0,
                      offset: Offset(0.0, 0.75),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ชื่อสถานที่
                        Row(
                          children: [
                            Icon(Icons.place, color: Colors.blueAccent),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                placeDetails['name'] ?? 'No name available',
                                style: TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        // ที่อยู่
                        Text(
                          placeDetails['address'] ?? 'No address available',
                          style:
                              TextStyle(color: Colors.grey[700], fontSize: 16),
                        ),
                        SizedBox(height: 16),
                        // เบอร์โทรศัพท์
                        if (placeDetails['phone'] != null)
                          Row(
                            children: [
                              Icon(Icons.phone, color: Colors.green),
                              SizedBox(width: 8),
                              Text(
                                placeDetails['phone'] ?? 'No phone available',
                                style: TextStyle(
                                    color: Colors.green[700], fontSize: 16),
                              ),
                            ],
                          ),
                        SizedBox(height: 16),
                        // เวลาทำการ
                        if (placeDetails['opening_hours'] != null &&
                            (placeDetails['opening_hours'] as List)
                                .isNotEmpty) ...[
                          Text('Opening Hours:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 18)),
                          SizedBox(height: 8),
                          for (String hour
                              in (placeDetails['opening_hours'] as List))
                            Text(hour,
                                style: TextStyle(
                                    fontSize: 16, color: Colors.black)),
                          SizedBox(height: 16),
                        ],
                        // ประเภทการชาร์จ (สำหรับ ev_station, ev_charging_station)
                        if (placeDetails['type'] == 'ev_station' ||
                            placeDetails['type'] ==
                                'electric_vehicle_charging_station')
                          if (placeDetails['charging_type'] != null) ...[
                            Text('Charging Type:',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18)),
                            SizedBox(height: 8),
                            Text(
                              placeDetails['charging_type'] ?? 'Not available',
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        Divider(),
                        SizedBox(height: 8),
                        // รีวิวที่รวมมาจาก Firestore และ Google API
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
                                  children: reviews.map((review) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          review['username'] ?? 'Unknown user',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                        ),
                                        Text(review['review'] ??
                                            'No review text available'),
                                        Row(
                                          children: List.generate(5, (index) {
                                            return Icon(
                                              index < (review['rating'] ?? 0)
                                                  ? Icons.star
                                                  : Icons.star_border,
                                              color: Colors.amber,
                                            );
                                          }),
                                        ),
                                        SizedBox(height: 16),
                                      ],
                                    );
                                  }).toList(),
                                );
                              }
                            } else {
                              return Text("Failed to load reviews.");
                            }
                          },
                        ),
                        Divider(),
                        SizedBox(height: 8),
                        // ฟอร์มรีวิว
                        TextField(
                          controller: _reviewController,
                          decoration: InputDecoration(
                            labelText: 'Write your review',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: 12),
                        // ระบบการให้คะแนน
                        Text('Rating:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18)),
                        SizedBox(height: 8),
                        Row(
                          children: List.generate(5, (index) {
                            return IconButton(
                              icon: Icon(
                                index < _rating
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                              ),
                              onPressed: () {
                                setModalState(() {
                                  _rating = index + 1;
                                });
                              },
                            );
                          }),
                        ),
                        SizedBox(height: 12),
                        // ปุ่ม Submit รีวิว
                        ElevatedButton(
                          onPressed: () async {
                            await _submitReview(
                              placeId: placeId,
                              type: placeDetails['type'] ?? 'unknown',
                              reviewText: _reviewController.text,
                              rating: _rating,
                              userId: userId,
                              username: username,
                            );
                            Navigator.pop(context);
                          },
                          child: Text('Submit Review'),
                        ),
                        Divider(),
                        SizedBox(height: 16),
                        // ปุ่ม Favorite และ Go
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                widget.onAddToFavorites(placeDetails);
                                Navigator.pop(context);
                              },
                              icon: Icon(Icons.favorite_border),
                              label: Text('Favorite'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.pinkAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20.0),
                                ),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                widget.onAddToHistory({
                                  'name': placeDetails['name'] ?? 'Unknown',
                                  'address':
                                      placeDetails['address'] ?? 'Unknown',
                                  'phone': placeDetails['phone'] ?? 'Unknown',
                                  'lat': placeDetails['lat'],
                                  'lng': placeDetails['lng'],
                                  'type': placeDetails['type'] ?? 'Unknown',
                                  'date': DateTime.now().toString(),
                                  'time':
                                      DateTime.now().toString().split(' ')[1],
                                });

                                Navigator.pop(context);
                                _fetchRouteAndNavigate(placeLatLng);
                              },
                              icon: Icon(Icons.directions),
                              label: Text('Go'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20.0),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    }
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
    required String placeId,
    required String type, // ev_station หรือ place
    required String reviewText,
    required int rating,
    required String? userId,
    required String username,
  }) async {
    String username;
    if (userId != null) {
      username = await fetchUsernameFromFirestore(userId);
    } else {
      username = 'Anonymous';
    }

    if (userId != null) {
      try {
        await FirebaseFirestore.instance.collection('places_reviews').add({
          'place_id': placeId,
          'type': type,
          'review': reviewText,
          'rating': rating,
          'user_id': userId,
          'username': username, // ใช้ชื่อผู้ใช้จาก Firebase
          'created_at': FieldValue.serverTimestamp(), // เวลาในการสร้างรีวิว
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
          'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=AIzaSyCrOHVlCBGDkDoO88AD_E_m3C1vPXB02OI';
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
                'created_at': DateTime.fromMillisecondsSinceEpoch(
                    review['time'] *
                        1000), // เวลาใน Google API เป็น UNIX timestamp
              };
            }).toList();
          } else {
            return []; // ไม่มีรีวิว
          }
        } else {
          print("No reviews field found in the Google API response");
          return []; // ไม่มีฟิลด์ reviews ใน response
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

      List<Map<String, dynamic>> reviews = reviewSnapshot.docs.map((doc) {
        return {
          'username': doc['username'],
          'review': doc['review'],
          'rating': doc['rating'],
          'created_at': (doc['created_at'] as Timestamp).toDate(),
        };
      }).toList();

      return reviews;
    } catch (e) {
      print("Error fetching reviews from Firestore: $e");
      return [];
    }
  }

  Future<void> _fetchRouteAndNavigate(gms.LatLng destination) async {
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
      _polylines.clear();
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
  ) async {
    String collectionName =
        type == 'ev_station' ? 'station_requests' : 'place_requests';

    // ดึง metadata เพื่อดูค่า lastRequestId
    DocumentSnapshot metadataSnapshot = await FirebaseFirestore.instance
        .collection('metadata')
        .doc(type == 'ev_station'
            ? 'station_request_metadata'
            : 'place_request_metadata')
        .get();

    // กำหนดค่า lastRequestId ถ้า metadata มีอยู่แล้วให้ใช้ lastRequestId ถ้าไม่ให้เริ่มที่ 0
    int lastRequestId =
        metadataSnapshot.exists && metadataSnapshot.data() != null
            ? metadataSnapshot['lastRequestId']
            : 0;

    // สร้าง document id ใหม่โดยเพิ่มค่า lastRequestId
    String newRequestId = 'request_id${lastRequestId + 1}';

    // ส่งคำขอไปยัง Firestore ใน collection ที่เหมาะสม (place_requests หรือ station_requests)
    await FirebaseFirestore.instance
        .collection(collectionName)
        .doc(newRequestId)
        .set({
      'name': name,
      'address': address,
      'lat': location.latitude,
      'lng': location.longitude,
      'phone': phone,
      'open_hours': openHours,
      if (type == 'ev_station') 'charging_type': chargingType,
      'type': type,
      'status': 'pending', // สถานะเริ่มต้นของคำขอคือ pending
      'requested_at': Timestamp.now(),
    });

    // อัปเดตค่า lastRequestId ใน metadata
    await FirebaseFirestore.instance
        .collection('metadata')
        .doc(type == 'ev_station'
            ? 'station_request_metadata'
            : 'place_request_metadata')
        .update({
      'lastRequestId': lastRequestId + 1,
    });

    // แสดง SnackBar เมื่อคำขอถูกส่งไปยัง Admin
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Request sent to Admin for approval')),
    );
  }
void _showEVStationDetails(Map<String, dynamic> place, gms.LatLng placeLatLng) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10.0,
              spreadRadius: 5.0,
              offset: Offset(0.0, 0.75),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ชื่อสถานี EV
                Row(
                  children: [
                    Icon(Icons.ev_station, color: Colors.blueAccent),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        place.containsKey('name') ? place['name'] : 'No name available',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),

                // ที่อยู่
                Text(
                  place.containsKey('formatted_address') 
                      ? place['formatted_address'] 
                      : (place.containsKey('address') ? place['address'] : 'No address available'),
                  style: TextStyle(color: Colors.grey[700]),
                ),
                SizedBox(height: 8),

                // หมายเลขโทรศัพท์
                if ((place.containsKey('formatted_phone_number') &&
                        place['formatted_phone_number'].toString().isNotEmpty) ||
                    (place.containsKey('phone') && place['phone'].toString().isNotEmpty))
                  Text('Phone: ${place['formatted_phone_number'] ?? place['phone']}'),
                SizedBox(height: 8),

                // เวลาทำการ (จาก current_opening_hours ถ้ามี)
                if (place.containsKey('current_opening_hours') &&
                    place['current_opening_hours'] is Map &&
                    place['current_opening_hours']['weekday_text'] != null &&
                    place['current_opening_hours']['weekday_text'] is List)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Opening Hours:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ...List.generate(
                        (place['current_opening_hours']['weekday_text'] as List).length,
                        (index) => Text(place['current_opening_hours']['weekday_text'][index]),
                      ),
                    ],
                  ),
                SizedBox(height: 8),

                // รูปภาพ
                if (place.containsKey('photos') &&
                    place['photos'] is List &&
                    (place['photos'] as List).isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Divider(),
                      Text('Photos:', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(
                            (place['photos'] as List).length,
                            (index) {
                              var photo = place['photos'][index];
                              if (photo != null && photo is Map && photo.containsKey('photo_reference')) {
                                return Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Image.network(
                                    'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=${photo['photo_reference']}&key=YOUR_API_KEY',
                                    width: 200,
                                    height: 150,
                                    fit: BoxFit.cover,
                                  ),
                                );
                              }
                              return Container(); // ถ้าไม่มีข้อมูลรูปภาพก็แสดงค่าว่าง
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                SizedBox(height: 8),

                // รีวิว
                if (place.containsKey('reviews') &&
                    place['reviews'] is List &&
                    (place['reviews'] as List).isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Divider(),
                      Text('Reviews:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ...List.generate(
                        (place['reviews'] as List).length,
                        (index) {
                          var review = place['reviews'][index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundImage: NetworkImage(review['profile_photo_url']),
                                      radius: 16,
                                    ),
                                    SizedBox(width: 8),
                                    Text(review['author_name']),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Text('Rating: ${review['rating']}'),
                                Text(review['text'].isNotEmpty
                                    ? review['text']
                                    : 'No review text available'),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                Divider(),

                // ปุ่ม Favorite และ Go
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        if (place.containsKey('name') || place.containsKey('formatted_address')) {
                          widget.onAddToFavorites(place);
                        }
                        Navigator.pop(context);
                      },
                      icon: Icon(Icons.favorite_border),
                      label: Text('Favorite'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        widget.onAddToHistory({
                          'name': place.containsKey('name') ? place['name'] : 'Unknown',
                          'address': place.containsKey('formatted_address')
                              ? place['formatted_address']
                              : (place.containsKey('address') ? place['address'] : 'Unknown'),
                          'phone': place.containsKey('formatted_phone_number')
                              ? place['formatted_phone_number']
                              : (place.containsKey('phone') ? place['phone'] : 'Unknown'),
                          'lat': placeLatLng.latitude,
                          'lng': placeLatLng.longitude,
                          'type': place.containsKey('types') ? place['types'] : 'Unknown',
                          'date': DateTime.now().toString(),
                          'time': DateTime.now().toString().split(' ')[1],
                        });

                        Navigator.pop(context);
                        _fetchRouteAndNavigate(placeLatLng);
                      },
                      icon: Icon(Icons.directions),
                      label: Text('Go'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}




  void _clearRoute() {
    setState(() {
      _polylines.clear();
      _isNavigating = false;
      _distanceText = null;
      _durationText = null;
    });
  }

  void _showAddPlaceDialog() {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController();
    final openHoursController = TextEditingController();
    final chargingTypeController = TextEditingController();

    String selectedType = 'ev_station';
    final List<String> placeTypes = [
      'ev_station',
      'restaurant',
      'cafe',
      'store',
      'gas_station'
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
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
                    if (selectedType == 'ev_station')
                      TextField(
                        controller: chargingTypeController,
                        decoration: InputDecoration(
                          labelText: 'Charging Type',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
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
                    // สร้าง LatLng สำหรับตำแหน่งใหม่
                    final newStationLatLng = gms.LatLng(
                      _currentPosition?.latitude ?? 0.0,
                      _currentPosition?.longitude ?? 0.0,
                    );

                    // เรียกใช้ฟังก์ชันเพื่อส่งคำขอไปยัง Firestore
                    await _addPlaceRequestToFirestore(
                      selectedType,
                      nameController.text,
                      addressController.text,
                      newStationLatLng,
                      phoneController.text,
                      openHoursController.text,
                      chargingTypeController.text,
                    );

                    // ปิด dialog และแสดงข้อความ SnackBar เมื่อคำขอถูกส่งแล้ว
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Request sent to Admin for approval')),
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
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: _currentPosition == null
          ? Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                gms.GoogleMap(
                  mapType: gms.MapType.normal,
                  myLocationButtonEnabled: true,
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
                          if (place['type'] ==
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
                // Search Bar UI
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8.0,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search Places...',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30.0),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: Icon(Icons.search),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.clear),
                                      onPressed: () {
                                        _clearSearch();
                                      },
                                    )
                                  : null,
                            ),
                            onChanged: (query) {
                              _onSearchChanged(query);
                            },
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      // Search Button
                      GestureDetector(
                        onTap: () {
                          // Trigger search functionality
                          if (_searchController.text.isNotEmpty) {
                            _onSearchChanged(_searchController.text);
                            _moveCameraToPlace(
                              _places.first[
                                  'lat'], // Move camera to the first result
                              _places.first['lng'],
                            );
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(30.0),
                          ),
                          child: Icon(Icons.search, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                // Add Place Button (moved to bottom-right corner)
                Positioned(
                  bottom: 100,
                  right: 16,
                  child: FloatingActionButton(
                    onPressed: _showAddPlaceDialog,
                    child: Icon(Icons.add),
                  ),
                ),
                Positioned(
                  top: 80,
                  right: 16,
                  child: FloatingActionButton(
                    onPressed: _showFilterDialog,
                    child: Icon(Icons.filter_list),
                  ),
                ),

                // My Location Button
                Positioned(
                  bottom: 160,
                  right: 16,
                  child: FloatingActionButton(
                    onPressed: _goToCurrentLocation,
                    child: Icon(Icons.my_location),
                  ),
                ),
                // Navigation Information Overlay
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
