import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FavoritePage extends StatelessWidget {
  final CollectionReference _favoritesCollection =
      FirebaseFirestore.instance.collection('users');

  Future<String?> _getUserId() async {
    User? user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  // ฟังก์ชันสำหรับจัดรูปแบบวันที่และเวลา (ไม่แสดงวินาที)
  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown Date';
    try {
      DateTime dt = timestamp.toDate(); // แปลงจาก Timestamp เป็น DateTime
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    } catch (e) {
      return 'Unknown Date';
    }
  }

  // ฟังก์ชันเพื่อเลือกไอคอนตามประเภทของสถานที่
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
      case 'gas_station':
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
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Bookmarks',
          style: TextStyle(color: Colors.yellow, fontSize: 24),
        ),
        backgroundColor: Color(0xFF2D5C88),
      ),
      body: FutureBuilder<String?>(
        future: _getUserId(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return Center(child: Text('User not logged in.'));
          }

          String userId = snapshot.data!;

          // ใช้ StreamBuilder เพื่อดึงข้อมูลจาก Firestore และอัปเดต UI
          return StreamBuilder<QuerySnapshot>(
            stream: _favoritesCollection
                .doc(userId)
                .collection('favorites') // คอลเลกชันที่คุณต้องการดึงข้อมูล
                .snapshots(),
            builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text('No bookmarks found.'));
              }

              List<QueryDocumentSnapshot> favoritePlaces = snapshot.data!.docs;

              return ListView.builder(
                itemCount: favoritePlaces.length,
                itemBuilder: (context, index) {
                  final place =
                      favoritePlaces[index].data() as Map<String, dynamic>;

                  // ตรวจสอบค่าพิกัดก่อนแสดงผล
                  final lat = place['lat'] ?? 0.0;
                  final lng = place['lng'] ?? 0.0;

                  if (lat == 0.0 || lng == 0.0) {
                    return ListTile(
                      title: Text('Invalid location'),
                      subtitle: Text('Please check the place coordinates.'),
                    );
                  }

                  // ตรวจสอบและแสดงที่อยู่ ถ้าไม่มี ให้แสดง "No address"
                  final address = place['address'] != null &&
                          place['address'].isNotEmpty
                      ? place['address']
                      : 'No address'; // ถ้าไม่มีข้อมูลที่อยู่ จะใช้ข้อความนี้แทน

                  // ตรวจสอบประเภทของสถานที่และเก็บข้อมูลตามประเภทที่เหมาะสม
                  String placeType = place['type'] ?? 'unknown';
                  if (placeType == 'ev_station') {
                    placeType =
                        'EV Station'; // ถ้าเป็น EV Station แสดงเป็น 'EV Station'
                  }

                  // ตรวจสอบหมายเลขโทรศัพท์
                  final phone = place['phone'] ??
                      'No phone available'; // ถ้าไม่มี phone ให้แสดงข้อความนี้แทน

                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // แสดงวันที่เพิ่มเข้ารายการโปรด
                        Text(
                          _formatDateTime(place[
                              'added_at']), // ใช้ 'added_at' และแปลง Timestamp
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Divider(color: Colors.black54, thickness: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ใช้ไอคอนที่แสดงตามประเภท
                              _getIconForType(place['type'] ?? 'unknown'),
                              SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      place['name'] ?? 'Unknown Name',
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
                                          phone, // ใช้ฟิลด์ phone ที่เราเพิ่มใน Firestore
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
                                            address, // ใช้ตัวแปร address ที่ตรวจสอบแล้ว
                                            style: TextStyle(fontSize: 16),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.access_time, size: 16),
                                        SizedBox(width: 4),
                                        Text(
                                          place['opening_hours'] != null
                                              ? (place['opening_hours']
                                                      ['open_now']
                                                  ? 'Open now'
                                                  : 'Closed')
                                              : 'N/A',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: place['opening_hours'] !=
                                                        null &&
                                                    place['opening_hours']
                                                        ['open_now']
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    if (place['type'] != null)
                                      Row(
                                        children: [
                                          Icon(Icons.category, size: 16),
                                          SizedBox(width: 4),
                                          // แสดงประเภทสถานที่ที่ถูกต้อง
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
