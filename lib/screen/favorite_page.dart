import 'package:evflutterproject/screen/search_station.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FavoritePage extends StatefulWidget {
  final Function(Map<String, dynamic>) onAddToFavorites;
  final Function(Map<String, dynamic>) onAddToHistory;
  final double? lat;
  final double? lng;

  FavoritePage({
    required this.onAddToFavorites,
    required this.onAddToHistory,
    this.lat,
    this.lng,
  });

  @override
  _FavoritePageState createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
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
        return Icon(Icons.landscape, size: 24); // เปลี่ยนจาก camera_alt เป็น landscape
      case 'gas_station':
        return Icon(Icons.local_gas_station, size: 24); // เปลี่ยนจาก camera_alt เป็น local_gas_station
      default:
        return Icon(Icons.place, size: 24);
    }
  }

  // ฟังก์ชันลบสถานที่จาก Favorites
  Future<void> _removeFromFavorites(String userId, String favoriteId) async {
    try {
      await _favoritesCollection
          .doc(userId)
          .collection('favorites')
          .doc(favoriteId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed from favorites')),
      );
    } catch (e) {
      print('Error removing favorite: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove favorite')),
      );
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
                .orderBy('added_at', descending: true) // เรียงลำดับตามวันที่เพิ่มล่าสุด
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
                  final favoriteId = favoritePlaces[index].id;

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
                  final phone =
                      place['phone'] ?? 'No phone available'; // ถ้าไม่มี phone ให้แสดงข้อความนี้แทน

                  return InkWell(
                    onTap: () {
                      // เมื่อคลิก จะนำทางไปยัง SearchPlacePage พร้อมกับส่งข้อมูลสถานที่
                      if (place['lat'] != null &&
                          place['lng'] != null &&
                          place['name'] != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SearchPlacePage(
                              lat: place['lat'],
                              lng: place['lng'],
                              name: place['name'],
                              onAddToFavorites: widget.onAddToFavorites,
                              onAddToHistory: widget.onAddToHistory,
                            ),
                          ),
                        );
                      } else {
                        print('Invalid place data');
                      }
                    },
                    child: Padding(
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
                                // เพิ่มปุ่มลบที่นี่
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.redAccent),
                                  onPressed: () async {
                                    // ยืนยันการลบก่อนลบ
                                    bool? confirmDelete = await showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text('Remove Favorite'),
                                        content: Text(
                                            'Are you sure you want to remove "${place['name']}" from your favorites?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(false),
                                            child: Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
                                            child: Text(
                                              'Remove',
                                              style:
                                                  TextStyle(color: Colors.red),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirmDelete != null && confirmDelete) {
                                      await _removeFromFavorites(userId, favoriteId);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            
          );
        }
      )
    );
      }
}
