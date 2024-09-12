import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboardPage extends StatefulWidget {
  @override
  _AdminDashboardPageState createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedCategory = 'ev_stations';
  List<DocumentSnapshot> allRequests = []; 

  final List<Map<String, String>> _placeCategories = [
    {'label': 'EV Stations', 'value': 'ev_stations'},
    {'label': 'General Places', 'value': 'places'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Manage Places',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.blueAccent,
        actions: [
          PopupMenuButton<int>(
            icon: Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 1) {
                _showPendingRequests(); // ฟังก์ชันแสดงคำขอ
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 1,
                child: ListTile(
                  leading:
                      Icon(Icons.pending_actions, color: Colors.blueAccent),
                  title: Text('Manage Requests'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<String>(
              value: _selectedCategory,
              items: _placeCategories.map((category) {
                return DropdownMenuItem<String>(
                  value: category['value'],
                  child: Row(
                    children: [
                      Icon(
                        category['value'] == 'ev_stations'
                            ? Icons.ev_station
                            : Icons.place,
                        color: Colors.blueAccent,
                      ),
                      SizedBox(width: 10),
                      Text(
                        category['label']!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                });
              },
              decoration: InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(vertical: 15, horizontal: 15),
                fillColor: Colors.white,
                filled: true,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30), // ปรับมุมให้โค้ง
                  borderSide: BorderSide(color: Colors.blueAccent, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30), // ปรับมุมให้โค้ง
                  borderSide: BorderSide(color: Colors.blueAccent, width: 2),
                ),
              ),
              icon: Icon(
                Icons.arrow_drop_down,
                color: Colors.blueAccent,
              ),
              dropdownColor: Colors.white, // สีของ dropdown menu
              borderRadius:
                  BorderRadius.circular(15), // ปรับมุม dropdown ให้โค้ง
            ),
          ),
          Expanded(
            child: FutureBuilder<QuerySnapshot>(
              future: _firestore.collection(_selectedCategory).get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                final places = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: places.length,
                  itemBuilder: (context, index) {
                    final place = places[index];
                    final placeData = place.data() as Map<String, dynamic>?;
                    return Card(
                      elevation: 4,
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(16.0),
                        title: Text(
                          placeData?['name'] ?? 'No name available',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Address: ${placeData?['address'] ?? 'No address available'}'),
                            if (placeData?.containsKey('charging_type') ??
                                false)
                              Text(
                                  'Charging Type: ${placeData!['charging_type']}'),
                            Text(
                                'Phone: ${placeData?['phone'] ?? 'No phone available'}'),
                            Text(
                                'Latitude: ${placeData?['lat'] ?? 'No latitude'}'),
                            Text(
                                'Longitude: ${placeData?['lng'] ?? 'No longitude'}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                _showEditStationDialog(place);
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                _deleteStation(place.id);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

void _showPendingRequests() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
    ),
    builder: (BuildContext context) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Text(
                'Pending Requests',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
            ),
            SizedBox(height: 10),
            FutureBuilder<List<QuerySnapshot>>(
              future: Future.wait([
                FirebaseFirestore.instance
                    .collection('station_requests')
                    .where('status', isEqualTo: 'pending')
                    .get(),
                FirebaseFirestore.instance
                    .collection('place_requests')
                    .where('status', isEqualTo: 'pending')
                    .get(),
              ]),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data == null) {
                  return Center(
                    child: Text(
                      'No pending requests.',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  );
                }

                // รวมข้อมูลจากทั้งสอง collection
                final allRequests = [
                  ...snapshot.data![0].docs, // ข้อมูลจาก 'station_requests'
                  ...snapshot.data![1].docs, // ข้อมูลจาก 'place_requests'
                ];

                if (allRequests.isEmpty) {
                  return Center(
                    child: Text(
                      'No pending requests.',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: allRequests.length,
                  itemBuilder: (context, index) {
                    var request = allRequests[index];
                    var requestData =
                        request.data() as Map<String, dynamic>;

                    // ตรวจสอบว่ามีข้อมูลใดบ้างที่ต้องแสดงผล
                    final String name = requestData['name'] ?? 'No name';
                    final String address = requestData['address'] ?? 'No address';
                    final String phone = requestData['phone'] ?? 'No phone';
                    final String chargingType = requestData['charging_type'] ?? 'N/A';
                    final String openHours = requestData['open_hours'] ?? 'N/A';
                    final double lat = requestData['lat'] ?? 0.0;
                    final double lng = requestData['lng'] ?? 0.0;

                    return Card(
                      elevation: 5,
                      margin: EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                              ),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.location_on, color: Colors.grey),
                                SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    'Address: $address',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.phone, color: Colors.grey),
                                SizedBox(width: 5),
                                Text(
                                  'Phone: $phone',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.bolt, color: Colors.grey),
                                SizedBox(width: 5),
                                Text(
                                  'Charging Type: $chargingType',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.access_time, color: Colors.grey),
                                SizedBox(width: 5),
                                Text(
                                  'Open Hours: $openHours',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.map, color: Colors.grey),
                                SizedBox(width: 5),
                                Text(
                                  'Coordinates: ($lat, $lng)',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.check_circle,
                                      color: Colors.green),
                                  onPressed: () async {
                                    await _approveRequest(request);
                                    Navigator.pop(context);
                                  },
                                ),
                                SizedBox(width: 10),
                                IconButton(
                                  icon: Icon(Icons.cancel, color: Colors.red),
                                  onPressed: () async {
                                    await _rejectRequest(request);
                                    Navigator.pop(context);
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
          ],
        ),
      );
    },
  );
}



Future<void> _approveRequest(DocumentSnapshot request) async {
  try {
    // ดึงข้อมูลคำขอจากเอกสาร
    Map<String, dynamic>? requestData = request.data() as Map<String, dynamic>?;

    // ตรวจสอบว่าเอกสารนี้มาจากคอลเล็กชันไหน (station_requests หรือ place_requests)
    String collection = request.reference.parent.id;

    // ตั้งค่าชื่อคอลเล็กชันที่จะบันทึก เช่น ev_stations หรือ places
    String targetCollection =
        (collection == 'station_requests') ? 'ev_stations' : 'places';

    // สร้างเอกสารใหม่ในคอลเล็กชันที่ต้องการบันทึก
    await FirebaseFirestore.instance.collection(targetCollection).add({
      'name': requestData?['name'] ?? '',
      'address': requestData?['address'] ?? '',
      'lat': requestData?['lat'] ?? 0.0,
      'lng': requestData?['lng'] ?? 0.0,
      'phone': requestData?['phone'] ?? '',
      'open_hours': requestData?['open_hours'] ?? '',
      if (collection == 'station_requests')
        'charging_type': requestData?['charging_type'] ?? '',
    });

    // ลบคำขอจากคอลเล็กชัน requests
    await FirebaseFirestore.instance
        .collection(collection)
        .doc(request.id)
        .delete();

    _removeRequestFromUI(request);  // ลบคำขอจาก UI

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Request Approved and station added!'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    print('Error approving request: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to approve request.'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

Future<void> _rejectRequest(DocumentSnapshot request) async {
  try {
    // ตรวจสอบว่าเอกสารนี้มาจากคอลเล็กชันไหน
    String collection = request.reference.parent.id;

    // ลบเอกสารคำขอ
    await FirebaseFirestore.instance
        .collection(collection)
        .doc(request.id)
        .delete();

    _removeRequestFromUI(request);  // ลบคำขอจาก UI

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Request Rejected and deleted.'),
        backgroundColor: Colors.red,
      ),
    );
  } catch (e) {
    print('Error rejecting request: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to reject request.'),
        backgroundColor: Colors.red,
      ),
    );
  }
}


void _removeRequestFromUI(DocumentSnapshot request) {
  setState(() {
    // ลบคำขอออกจากรายการ allRequests
    allRequests.removeWhere((element) => element.id == request.id);
  });
}


  void _showAddStationDialog() {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();
    final chargingTypeController = TextEditingController();

    // Add dropdown for place types
    String selectedPlaceType = 'restaurant'; // Default place type
    final List<Map<String, String>> placeTypes = [
      {'label': 'Restaurant', 'value': 'restaurant'},
      {'label': 'Cafe', 'value': 'cafe'},
      {'label': 'Store', 'value': 'store'},
      {'label': 'Tourist Attraction', 'value': 'tourist_attraction'},
      {'label': 'Gas Station', 'value': 'gas_station'}
    ];

    showDialog(
      context: context,
      builder: (context) {
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
                // Dropdown for General Places types
                if (_selectedCategory == 'places')
                  DropdownButtonFormField<String>(
                    value: selectedPlaceType,
                    items: placeTypes.map((type) {
                      return DropdownMenuItem<String>(
                        value: type['value'],
                        child: Text(type['label']!),
                      );
                    }).toList(),
                    onChanged: (value) {
                      selectedPlaceType = value!;
                    },
                    decoration: InputDecoration(
                      labelText: 'Place Type',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                  ),
                SizedBox(height: 10),
                _buildTextField(nameController, 'Name'),
                SizedBox(height: 10),
                _buildTextField(addressController, 'Address'),
                SizedBox(height: 10),
                _buildTextField(phoneController, 'Phone'),
                SizedBox(height: 10),
                _buildTextField(latController, 'Latitude'),
                SizedBox(height: 10),
                _buildTextField(lngController, 'Longitude'),
                SizedBox(height: 10),
                if (_selectedCategory == 'ev_stations')
                  _buildTextField(chargingTypeController, 'Charging Type'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel', style: TextStyle(color: Colors.redAccent)),
            ),
            ElevatedButton(
              onPressed: () async {
                // Validate required fields
                if (nameController.text.isEmpty ||
                    addressController.text.isEmpty ||
                    latController.text.isEmpty ||
                    lngController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Please fill out all required fields')),
                  );
                  return;
                }

                // Convert lat/lng to double
                double? lat = double.tryParse(latController.text);
                double? lng = double.tryParse(lngController.text);

                if (lat == null || lng == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Please enter valid Latitude and Longitude values')),
                  );
                  return;
                }

                // Fetch metadata to generate new ID
                String metadataDocId = (_selectedCategory == 'ev_stations')
                    ? 'station_metadata'
                    : 'place_metadata';
                String collectionName = (_selectedCategory == 'ev_stations')
                    ? 'ev_stations'
                    : 'places';

                DocumentSnapshot metadataDoc = await _firestore
                    .collection('metadata')
                    .doc(metadataDocId)
                    .get();

                // Check if metadata exists, if not create new one
                int lastId = 1; // default to 1 if no metadata exists
                if (metadataDoc.exists && metadataDoc.data() != null) {
                  lastId = metadataDoc.get((_selectedCategory == 'ev_stations')
                      ? 'lastStationId'
                      : 'lastPlaceId');
                }

                // Generate new document ID
                String newId = (_selectedCategory == 'ev_stations')
                    ? 'station_id${lastId + 1}'
                    : 'place_id${lastId + 1}';

                // Save new place/station to Firestore
                await _firestore.collection(collectionName).doc(newId).set({
                  'name': nameController.text,
                  'address': addressController.text,
                  'phone': phoneController.text,
                  'lat': lat,
                  'lng': lng,
                  if (_selectedCategory == 'ev_stations')
                    'charging_type': chargingTypeController.text,
                  if (_selectedCategory == 'places') 'type': selectedPlaceType,
                });

                // Update metadata
                await _firestore.collection('metadata').doc(metadataDocId).set(
                    {
                      (_selectedCategory == 'ev_stations')
                          ? 'lastStationId'
                          : 'lastPlaceId': lastId + 1,
                    },
                    SetOptions(
                        merge:
                            true)); // Use merge to update only the required field

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Successfully saved!')),
                );

                Navigator.pop(context); // Close the dialog after saving
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              ),
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showEditStationDialog(DocumentSnapshot station) {
    final placeData = station.data() as Map<String, dynamic>?;
    final nameController = TextEditingController(text: placeData?['name']);
    final addressController =
        TextEditingController(text: placeData?['address']);
    final phoneController = TextEditingController(text: placeData?['phone']);
    final latController =
        TextEditingController(text: placeData?['lat'].toString());
    final lngController =
        TextEditingController(text: placeData?['lng'].toString());
    final chargingTypeController = TextEditingController(
      text: placeData?.containsKey('charging_type') ?? false
          ? placeData!['charging_type']
          : '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          title: Text(
            'Edit Place',
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
                _buildTextField(nameController, 'Name'),
                SizedBox(height: 10),
                _buildTextField(addressController, 'Address'),
                SizedBox(height: 10),
                _buildTextField(phoneController, 'Phone'),
                SizedBox(height: 10),
                _buildTextField(latController, 'Latitude'),
                SizedBox(height: 10),
                _buildTextField(lngController, 'Longitude'),
                SizedBox(height: 10),
                if (_selectedCategory == 'ev_stations')
                  _buildTextField(chargingTypeController, 'Charging Type'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel', style: TextStyle(color: Colors.redAccent)),
            ),
            ElevatedButton(
              onPressed: () async {
                await _firestore
                    .collection(_selectedCategory)
                    .doc(station.id)
                    .update({
                  'name': nameController.text,
                  'address': addressController.text,
                  'phone': phoneController.text,
                  'lat': double.parse(latController.text),
                  'lng': double.parse(lngController.text),
                  if (_selectedCategory == 'ev_stations')
                    'charging_type': chargingTypeController.text,
                });

                // แสดงข้อความแจ้งเตือนเมื่อบันทึกสำเร็จ
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Successfully saved!')),
                );

                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              ),
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // Delete station
  void _deleteStation(String id) async {
    await _firestore.collection(_selectedCategory).doc(id).delete();

    // แสดงข้อความแจ้งเตือนเมื่อการลบสำเร็จ
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Successfully deleted!')),
    );
  }

  // Build TextField widget for reuse
  Widget _buildTextField(TextEditingController controller, String labelText) {
    return TextField(
      controller: controller,
      keyboardType: (labelText == 'Latitude' || labelText == 'Longitude')
          ? TextInputType.number
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
      ),
    );
  }
}
