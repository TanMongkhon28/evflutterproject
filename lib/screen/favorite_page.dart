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
  String? _userId;
  final double _iconSize = 24.0;

  @override
  void initState() {
    super.initState();
    _getUserId();
  }

  void _getUserId() async {
    User? user = FirebaseAuth.instance.currentUser;
    setState(() {
      _userId = user?.uid;
    });
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

  // ฟังก์ชันเพื่อเลือก IconData ตามประเภทของสถานที่
  IconData _getIconForType(String type) {
    switch (type) {
      case 'restaurant':
        return Icons.restaurant;
      case 'ev_station':
        return Icons.ev_station;
      case 'store':
        return Icons.store;
      case 'cafe':
        return Icons.local_cafe;
      case 'tourist_attraction':
        return Icons.landscape; // เปลี่ยนจาก camera_alt เป็น landscape
      case 'gas_station':
        return Icons.local_gas_station; // เปลี่ยนจาก camera_alt เป็น local_gas_station
      default:
        return Icons.place;
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
    if (_userId == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: const Text(
            'Favorite',
            style: TextStyle(color: Colors.yellow, fontSize: 24),
          ),
          backgroundColor: const Color(0xFF2D5C88),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    String userId = _userId!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Favorite',
          style: TextStyle(color: Colors.yellow, fontSize: 24),
        ),
        backgroundColor: const Color(0xFF2D5C88),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _favoritesCollection
            .doc(userId)
            .collection('favorites') // คอลเลกชันที่คุณต้องการดึงข้อมูล
            .orderBy('added_at', descending: true) // เรียงลำดับตามวันที่เพิ่มล่าสุด
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No bookmarks found.'));
          }

          List<QueryDocumentSnapshot> favoritePlaces = snapshot.data!.docs;

          return ListView.separated(
            itemCount: favoritePlaces.length,
            separatorBuilder: (context, index) =>
                const Divider(color: Colors.black54, thickness: 1),
            itemBuilder: (context, index) {
              final place = favoritePlaces[index].data() as Map<String, dynamic>;
              final favoriteId = favoritePlaces[index].id;

              // ตรวจสอบค่าพิกัดก่อนแสดงผล
              final lat = place['lat'] ?? 0.0;
              final lng = place['lng'] ?? 0.0;

              if (lat == 0.0 || lng == 0.0) {
                return const ListTile(
                  title: Text('Invalid location'),
                  subtitle: Text('Please check the place coordinates.'),
                );
              }

              // ตรวจสอบและแสดงที่อยู่ ถ้าไม่มี ให้แสดง "No address"
              final address = place['address']?.isNotEmpty == true
                  ? place['address']
                  : 'No address';

              // ตรวจสอบประเภทของสถานที่และเก็บข้อมูลตามประเภทที่เหมาะสม
              String placeType = place['type'] ?? 'unknown';
              if (placeType == 'ev_station') {
                placeType = 'EV Station';
              }

              // ตรวจสอบหมายเลขโทรศัพท์
              final phone = place['phone'] ?? 'No phone available';

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
                        _formatDateTime(place['added_at']),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          
                          Icon(_getIconForType(place['type'] ?? 'unknown'),
                              size: _iconSize),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  place['name'] ?? 'Unknown Name',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.phone, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      phone,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.location_on, size: 16),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        address,
                                        style:
                                            const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                        _getIconForType(
                                            place['type'] ?? 'unknown'),
                                        size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      placeType,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                         
                          IconButton(
                            icon: const Icon(Icons.delete,
                                color: Colors.redAccent),
                            onPressed: () async {
                              
                              bool? confirmDelete = await showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Remove Favorite'),
                                  content: Text(
                                      'Are you sure you want to remove "${place['name']}" from your favorites?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: const Text(
                                        'Remove',
                                        style: TextStyle(color: Colors.red),
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
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
