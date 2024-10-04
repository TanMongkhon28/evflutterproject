import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'search_station.dart'; 

class HistoryPage extends StatefulWidget {
  final Function(Map<String, dynamic>) onAddToFavorites;
  final Function(Map<String, dynamic>) onAddToHistory;

  HistoryPage({
    required this.onAddToFavorites,
    required this.onAddToHistory,
  });

  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final CollectionReference _historyCollection =
      FirebaseFirestore.instance.collection('users');

  Future<String?> _getUserId() async {
    User? user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown Date';
    try {
      DateTime dt = timestamp.toDate();
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    } catch (e) {
      return 'Unknown Date';
    }
  }

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
        return Icon(Icons.landscape, size: 24);
      case 'gas_station':
        return Icon(Icons.local_gas_station, size: 24);
      default:
        return Icon(Icons.place, size: 24);
    }
  }

  Future<void> _removeFromHistory(String userId, String historyId) async {
    try {
      await _historyCollection
          .doc(userId)
          .collection('history')
          .doc(historyId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed from history')),
      );
    } catch (e) {
      print('Error removing history: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove history')),
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
          'Travel History',
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

          return StreamBuilder<QuerySnapshot>(
            stream: _historyCollection
                .doc(userId)
                .collection('history')
                .orderBy('visited_at', descending: true)
                .snapshots(),
            builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text('No history found.'));
              }

              List<QueryDocumentSnapshot> historyPlaces = snapshot.data!.docs;

              return ListView.builder(
                itemCount: historyPlaces.length,
                itemBuilder: (context, index) {
                  final place =
                      historyPlaces[index].data() as Map<String, dynamic>;
                  final historyId = historyPlaces[index].id;

                  final lat = place['lat'] ?? 0.0;
                  final lng = place['lng'] ?? 0.0;

                  if (lat == 0.0 || lng == 0.0) {
                    return ListTile(
                      title: Text('Invalid location'),
                      subtitle: Text('Please check the place coordinates.'),
                    );
                  }

                  final address = place['address'] != null &&
                          place['address'].isNotEmpty
                      ? place['address']
                      : 'No address';

                  String placeType = place['type'] ?? 'unknown';
                  if (placeType == 'ev_station') {
                    placeType = 'EV Station';
                  }

                  final phone = place['phone'] ?? 'No phone available';

                  return InkWell(
                    onTap: () {
                      // นำทางไปยัง SearchPlacePage เมื่อคลิกที่รายการในประวัติ
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
                          Text(
                            _formatDateTime(place['visited_at']),
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
                                            phone,
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
                                              address,
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
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.redAccent),
                                  onPressed: () async {
                                    bool? confirmDelete = await showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text('Remove History'),
                                        content: Text(
                                            'Are you sure you want to remove "${place['name']}" from your history?'),
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
                                              style: TextStyle(color: Colors.red),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirmDelete != null && confirmDelete) {
                                      await _removeFromHistory(userId, historyId);
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
        },
      ),
    );
  }
}
