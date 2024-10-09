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

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown Date';
    try {
      DateTime dt = timestamp.toDate();
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    } catch (e) {
      return 'Unknown Date';
    }
  }

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
        return Icons.landscape;
      case 'gas_station':
        return Icons.local_gas_station;
      default:
        return Icons.place;
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
        const SnackBar(content: Text('Removed from history')),
      );
    } catch (e) {
      print('Error removing history: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to remove history')),
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
            'Travel History',
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
          'Travel History',
          style: TextStyle(color: Colors.yellow, fontSize: 24),
        ),
        backgroundColor: const Color(0xFF2D5C88),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _historyCollection
            .doc(userId)
            .collection('history')
            .orderBy('visited_at', descending: true)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No history found.'));
          }

          List<QueryDocumentSnapshot> historyPlaces = snapshot.data!.docs;

          return ListView.separated(
            itemCount: historyPlaces.length,
            separatorBuilder: (context, index) =>
                const Divider(color: Colors.black54, thickness: 1),
            itemBuilder: (context, index) {
              final place =
                  historyPlaces[index].data() as Map<String, dynamic>;
              final historyId = historyPlaces[index].id;

              final lat = place['lat'] ?? 0.0;
              final lng = place['lng'] ?? 0.0;

              if (lat == 0.0 || lng == 0.0) {
                return const ListTile(
                  title: Text('Invalid location'),
                  subtitle: Text('Please check the place coordinates.'),
                );
              }

              final address = place['address']?.isNotEmpty == true
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
                                        style: const TextStyle(fontSize: 16),
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
                                  title: const Text('Remove History'),
                                  content: Text(
                                      'Are you sure you want to remove "${place['name']}" from your history?'),
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
                                await _removeFromHistory(userId, historyId);
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
