import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // สำหรับจัดรูปแบบวันที่และเวลา
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';

class HistoryPage extends StatelessWidget {
  final CollectionReference _historyCollection =
      FirebaseFirestore.instance.collection('users');

  Future<String> getAddressFromLatLng(double lat, double lng) async {
    try {
      print("Fetching address for lat: $lat, lng: $lng");
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) {
        return "Address not found";
      }

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String street = place.street ?? "Unknown Street";
        String locality = place.locality ?? "Unknown Locality";
        String country = place.country ?? "Unknown Country";
        String address = "$street, $locality, $country";
        print("Address: $address");
        return address;
      } else {
        print("No address found");
        return "No address";
      }
    } catch (e) {
      print("Error getting address: $e");
      return "Error retrieving address";
    }
  }

  void saveHistoryData(double lat, double lng,
      {String? name, String? type, String? phone}) async {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      print('No user is currently logged in.');
      return;
    }

    String userId = currentUser.uid;

    if (lat == 0.0 || lng == 0.0) {
      print('Invalid coordinates: lat = $lat, lng = $lng');
      return;
    }

    String address = await getAddressFromLatLng(lat, lng);

    if (address == "No address" || address == "Error retrieving address") {
      print('Invalid address: $address');
      return;
    }

    // บันทึกข้อมูลลง Firestore
    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('history')
        .add({
      'lat': lat,
      'lng': lng,
      'address': address,
      'visited_at': DateTime.now(),
      if (name != null) 'name': name, // เพิ่ม field name ถ้ามี
      if (type != null) 'type': type, // เพิ่ม field type ถ้ามี
      if (phone != null) 'phone': phone, // เพิ่ม field phone ถ้ามี
    }).then((value) {
      print('History data saved successfully.');
    }).catchError((error) {
      print('Failed to save history: $error');
    });
  }

  // ฟังก์ชันจัดรูปแบบวันที่และเวลา (ไม่แสดงวินาที)
  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown Date';
    try {
      DateTime dt = timestamp.toDate(); // แปลง Timestamp เป็น DateTime
      return DateFormat('yyyy-MM-dd HH:mm')
          .format(dt); // ปรับรูปแบบไม่แสดงวินาที
    } catch (e) {
      return 'Unknown Date';
    }
  }

  // ฟังก์ชันเลือกไอคอนตามประเภทของสถานที่
  Icon _getIconForType(String type) {
    switch (type) {
      case 'restaurant':
        return Icon(Icons.restaurant, size: 24);
      case 'ev_station':
        return Icon(Icons.ev_station, size: 24);
      case 'store':
        return Icon(Icons.store, size: 24);
      case 'cafe':
        return Icon(Icons.local_cafe, size: 24);
      case 'tourist_attraction':
        return Icon(Icons.camera_alt, size: 24);
      default:
        return Icon(Icons.place, size: 24);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // กลับไปหน้าก่อนหน้า
          },
        ),
        title: Text(
          'Travel History',
          style: TextStyle(color: Colors.yellow, fontSize: 24),
        ),
        backgroundColor: Color(0xFF2D5C88),
      ),
      body: FutureBuilder<User?>(
        future: FirebaseAuth.instance.authStateChanges().first,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return Center(
                child: Text('Error loading user data or no user logged in'));
          }

          String userId = snapshot.data!.uid;

          return StreamBuilder<QuerySnapshot>(
            stream: _historyCollection
                .doc(userId)
                .collection('history')
                .snapshots(),
            builder: (context, AsyncSnapshot<QuerySnapshot> historySnapshot) {
              if (historySnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (historySnapshot.hasError || !historySnapshot.hasData) {
                return Center(child: Text('Error loading history'));
              }

              final historyDocs = historySnapshot.data!.docs;

              if (historyDocs.isEmpty) {
                return Center(child: Text('No travel history found'));
              }

              return ListView.builder(
                itemCount: historyDocs.length,
                itemBuilder: (context, index) {
                  final historyItem =
                      historyDocs[index].data() as Map<String, dynamic>;
                  final lat = historyItem['lat'] ?? 0.0;
                  final lng = historyItem['lng'] ?? 0.0;

                  if (lat == 0.0 || lng == 0.0) {
                    return ListTile(
                      title: Text('Invalid location'),
                      subtitle: Text('Please check the place coordinates.'),
                    );
                  }

                  String placeType = historyItem['type'] ?? 'unknown';
                  if (placeType == 'ev_station') {
                    placeType = 'EV Station';
                  }

                  // ตรวจสอบหมายเลขโทรศัพท์ หากไม่มีให้แสดง 'N/A'
                  final phone = historyItem['phone'] ?? 'N/A';

                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDateTime(historyItem['visited_at']),
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Divider(
                            color: Colors.black54,
                            thickness: 1,
                            indent: 16,
                            endIndent: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _getIconForType(historyItem['type'] ?? 'unknown'),
                              SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      historyItem['name'] ?? 'Unknown Name',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.phone, size: 16),
                                        SizedBox(width: 4),
                                        Text(
                                          phone, // ใช้ตัวแปร phone ที่ตรวจสอบแล้ว
                                          style: TextStyle(fontSize: 16),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.location_on, size: 16),
                                        SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            historyItem['address'] ??
                                                'No address',
                                            style: TextStyle(fontSize: 16),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    if (historyItem['opening_hours'] != null)
                                      Row(
                                        children: [
                                          Icon(Icons.access_time, size: 16),
                                          SizedBox(width: 4),
                                          Text(
                                            historyItem['opening_hours']
                                                ? 'Open now'
                                                : 'Closed',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color:
                                                  historyItem['opening_hours']
                                                      ? Colors.green
                                                      : Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    SizedBox(height: 4),
                                    if (historyItem['type'] != null)
                                      Row(
                                        children: [
                                          Icon(Icons.category, size: 16),
                                          SizedBox(width: 4),
                                          Text(
                                            placeType,
                                            style: TextStyle(fontSize: 16),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(color: Colors.black54, thickness: 1),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
