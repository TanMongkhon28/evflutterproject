import 'package:flutter/foundation.dart';

class PlaceModel with ChangeNotifier {
  String placeId = '';
  double lat = 0.0;
  double lng = 0.0;
  String name = '';
  String address = '';
  String phone = '';
  String placeType = '';
  Map<String, dynamic> additionalDetails = {}; // เก็บข้อมูลเพิ่มเติมจาก Firestore

  void setPlace({
    required String id,
    required double latitude,
    required double longitude,
    required String placeName,
    required String placeAddress,
    required String placePhone,
    required String type,
    required Map<String, dynamic> details,
  }) {
    placeId = id;
    lat = latitude;
    lng = longitude;
    name = placeName;
    address = placeAddress;
    phone = placePhone;
    placeType = type;
    additionalDetails = details;
    notifyListeners();
  }
}
