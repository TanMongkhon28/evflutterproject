// import 'package:flutter/material.dart';
// import 'dart:async';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';

// class SearchProvider with ChangeNotifier {
//   TextEditingController searchController = TextEditingController();
//   List<Map<String, dynamic>> suggestions = [];
//   bool isLoading = false;
//   Timer? _debounce;
//   final String _apiKey = 'AIzaSyB67ZhLCsWm7sC9pUluesjiCOT-Wwu67oU'; // ใส่ API Key ของคุณ

//   // ประวัติการค้นหา
//   List<String> searchHistory = [];

//   SearchProvider() {
//     _loadSearchHistory();
//   }

//   void onSearchChanged(String query) {
//     if (_debounce?.isActive ?? false) _debounce?.cancel();
//     _debounce = Timer(Duration(milliseconds: 500), () {
//       if (query.isNotEmpty) {
//         fetchPlaceSuggestions(query);
//       } else {
//         suggestions.clear();
//         notifyListeners();
//       }
//     });
//   }

//   Future<void> fetchPlaceSuggestions(String query) async {
//     isLoading = true;
//     notifyListeners();

//     try {
//       // เรียก API เพื่อดึงข้อมูล suggestions
//       final response = await http.get(Uri.parse(
//           'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&key=$_apiKey&components=country:th'));

//       if (response.statusCode == 200) {
//         final jsonResponse = json.decode(response.body);
//         final predictions = jsonResponse['predictions'] as List;

//         suggestions = predictions.map((prediction) {
//           return {
//             'description': prediction['description'],
//             'place_id': prediction['place_id'],
//           };
//         }).toList();
//       } else {
//         suggestions = [];
//       }
//     } catch (e) {
//       print('Error fetching suggestions: $e');
//       suggestions = [];
//     }

//     isLoading = false;
//     notifyListeners();
//   }

//   void clearSearch() {
//     searchController.clear();
//     suggestions.clear();
//     notifyListeners();
//   }

//   // ฟังก์ชันสำหรับจัดการประวัติการค้นหา
//   Future<void> _loadSearchHistory() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     searchHistory = prefs.getStringList('search_history') ?? [];
//     notifyListeners();
//   }

//   Future<void> saveSearchHistory(String query) async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     if (!searchHistory.contains(query)) {
//       searchHistory.add(query);
//       await prefs.setStringList('search_history', searchHistory);
//       notifyListeners();
//     }
//   }

//   Future<void> clearSearchHistory() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     searchHistory.clear();
//     await prefs.remove('search_history');
//     notifyListeners();
//   }

//   @override
//   void dispose() {
//     searchController.dispose();
//     _debounce?.cancel();
//     super.dispose();
//   }
// }
