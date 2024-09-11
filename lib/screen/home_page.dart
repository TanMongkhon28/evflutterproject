import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'search_station.dart';
import 'favorite_page.dart';
import 'history_page.dart';
import 'profile_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> favoritePlaces = [];
  List<Map<String, dynamic>> travelHistory = [];

  @override
  void initState() {
    super.initState();
    _loadFavoritePlaces();
    _loadTravelHistory();
  }

  // ดึง userId จาก Firebase Authentication
  Future<String?> _getUserId() async {
    User? user = FirebaseAuth.instance.currentUser;
    return user?.uid; // คืนค่า userId ของผู้ใช้ปัจจุบัน หรือ null ถ้าไม่มีผู้ใช้ล็อกอิน
  }

  // ฟังก์ชันสำหรับโหลดรายการโปรดจาก Firestore
  Future<void> _loadFavoritePlaces() async {
    String? userId = await _getUserId();
    if (userId != null) {
      try {
        QuerySnapshot snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('favorites')
            .get();

        setState(() {
          favoritePlaces = snapshot.docs.map((doc) {
            return {
              'name': doc['name'],
              'address': doc['address'],
              'lat': doc['lat'],
              'lng': doc['lng'],
              'type': doc['type'],
              'added_at': doc['added_at'],
            };
          }).toList();
        });
      } catch (e) {
        print('Error loading favorite places: $e');
      }
    }
  }

  // ฟังก์ชันสำหรับโหลดประวัติการเดินทางจาก Firestore
  Future<void> _loadTravelHistory() async {
    String? userId = await _getUserId();
    if (userId != null) {
      try {
        QuerySnapshot snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('history')
            .get();

        setState(() {
          travelHistory = snapshot.docs.map((doc) {
            return {
              'name': doc['name'],
              'address': doc['address'],
              'lat': doc['lat'],
              'lng': doc['lng'],
              'type': doc['type'],
              'visited_at': doc['visited_at'],
            };
          }).toList();
        });
      } catch (e) {
        print('Error loading travel history: $e');
      }
    }
  }

 // ฟังก์ชันสำหรับเพิ่มรายการโปรดไปที่ Firestore
void _addToFavorites(Map<String, dynamic> place) async {
  String? userId = await _getUserId();

  if (userId != null) {
    try {
      // พิมพ์ค่าพิกัดเพื่อเช็คว่ามีค่าอะไร
      print('Lat: ${place['lat']}, Lng: ${place['lng']}');

      // ตรวจสอบว่า lat และ lng มีค่าเป็น null หรือไม่ หรือเป็น 0
      if (place['lat'] != null && place['lng'] != null && place['lat'] != 0 && place['lng'] != 0) {
        // ตรวจสอบว่ามี address หรือไม่ ถ้าไม่มีให้ตั้งค่าเป็น 'No address'
        final address = place['address'] != null && place['address'].isNotEmpty
            ? place['address']
            : 'No address'; // กำหนดค่าเริ่มต้นให้เป็น 'No address' ถ้าไม่มี

        // บันทึกข้อมูลลงใน Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('favorites')
            .add({
          'name': place['name'],
          'address': address, // ใช้ address ที่ตรวจสอบแล้ว
          'lat': place['lat'],
          'lng': place['lng'],
          'type': place['type'],
          'added_at': Timestamp.now(),
          'phone': place['phone'] ?? 'No phone available',
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added to favorites')),
        );
      } else {
        // แจ้งเตือนหากพิกัดไม่ถูกต้อง
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid lat/lng values')),
        );
      }
    } catch (e) {
      print('Error adding to favorites: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add to favorites')),
      );
    }
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('User not logged in')),
    );
  }
}


void _addToHistory(Map<String, dynamic> place) async {
  String? userId = await _getUserId();

  if (userId != null) {
    try {
      // พิมพ์ค่าพิกัดเพื่อเช็คว่ามีค่าอะไร
      print('Lat: ${place['lat']}, Lng: ${place['lng']}');

      // ตรวจสอบว่า lat และ lng มีค่าเป็น null หรือไม่ หรือเป็น 0
      if (place['lat'] != null && place['lng'] != null && place['lat'] != 0 && place['lng'] != 0) {
        // ตรวจสอบว่ามี address หรือไม่ ถ้าไม่มีให้ตั้งค่าเป็น 'No address'
        final address = place['address'] != null && place['address'].isNotEmpty
            ? place['address']
            : 'No address'; // กำหนดค่าเริ่มต้นให้เป็น 'No address' ถ้าไม่มี

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('history')
            .add({
          'name': place['name'] ?? 'Unknown Name',
          'address': address, 
          'lat': place['lat'],  // บันทึกค่าละติจูดที่มีอยู่
          'lng': place['lng'],  // บันทึกค่าลองจิจูดที่มีอยู่
          'type': place['type'] ?? 'Unknown Type',
          'visited_at': Timestamp.now(),
          'phone': place['phone'] ?? 'No phone available',
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added to history')),
        );
      } else {
        // แจ้งเตือนผู้ใช้หากพิกัดไม่มีค่า
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add to history: Invalid lat/lng')),
        );
      }
    } catch (e) {
      print('Error adding to history: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add to history')),
      );
    }
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('User not logged in')),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Section
          Container(
            color: Color.fromARGB(255, 250, 184, 1),
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Electric Vehicle Driving Plan',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 5),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                    children: <TextSpan>[
                      TextSpan(
                        text: 'Application',
                        style: TextStyle(
                          color: Color.fromARGB(255, 0, 94, 255),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Image Section
                  Container(
                    margin: EdgeInsets.all(20),
                    height: 250,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 5,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/images/ev2.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                  // Buttons Section
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // Search Station Button
                        _buildActionCard(
                          icon: Icons.search,
                          label: 'Search Station',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SearchPlacePage(
                                  onAddToFavorites: _addToFavorites,
                                  onAddToHistory: _addToHistory,
                                ),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: 16),

                        // Favorite Button
                        _buildActionCard(
                          icon: Icons.bookmark,
                          label: 'Favorite',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FavoritePage(
                                ),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: 16),

                        // Travel History Button
                        _buildActionCard(
                          icon: Icons.history,
                          label: 'Travel History',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => HistoryPage(
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

       // Bottom Navigation
      bottomNavigationBar: BottomAppBar(
        color: Color.fromARGB(255, 250, 184, 1),
        shape: CircularNotchedRectangle(),
        notchMargin: 6.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              IconButton(
                icon: Icon(Icons.person, color: Colors.white),
                onPressed: () {
                  // นำทางไปยังหน้าโปรไฟล์
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProfilePage()),
                  );
                },
              ),
              IconButton(
                icon: Icon(Icons.settings, color: Colors.white),
                onPressed: () {
                  // นำทางไปยังหน้าการตั้งค่า
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SettingsPage()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Card(
      color: Color(0xFF0D47A1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 4,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 25, horizontal: 20), // เพิ่ม Padding ให้ font ไม่ชนขอบ
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white),
              SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'OpenSans',
                  color: Color(0xFFFFC107),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
