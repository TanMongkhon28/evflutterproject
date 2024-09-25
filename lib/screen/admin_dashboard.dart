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
        title: Row(
          children: [
            Icon(Icons.admin_panel_settings, size: 28),
            SizedBox(width: 10),
            Text(
              'Manage Places',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ],
        ),
        backgroundColor: const Color.fromARGB(255, 3, 33, 153), // เปลี่ยนสีธีม
        actions: [
          // ลบปุ่มเพิ่มสถานที่ออกจาก AppBar
          PopupMenuButton<int>(
            icon: Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 1) {
                _showPendingRequests();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 1,
                child: ListTile(
                  leading: Icon(Icons.pending_actions, color: Colors.lightBlueAccent),
                  title: Text('Manage Requests'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Dropdown สำหรับเลือกประเภทสถานที่
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                            color: Colors.lightBlueAccent, // เปลี่ยนสีไอคอน
                          ),
                          SizedBox(width: 10),
                          Text(
                            category['label']!,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black, // สีข้อความ
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
                    border: InputBorder.none,
                  ),
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: Colors.lightBlueAccent, // เปลี่ยนสีลูกศร
                  ),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 4,
                      margin:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(16.0),
                        leading: Icon(
                          _selectedCategory == 'ev_stations'
                              ? Icons.ev_station
                              : Icons.place,
                          color: Colors.lightBlueAccent, // เปลี่ยนสีไอคอน
                          size: 40,
                        ),
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
                              placeData?['address'] ?? 'No address available',
                              style: TextStyle(fontSize: 16),
                            ),
                            SizedBox(height: 4),
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
                        onTap: () {
                          _showPlaceDetails(place);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddStationDialog,
        child: Icon(Icons.add),
        backgroundColor: Colors.lightBlueAccent,
        tooltip: 'Add New Station',
      ),
    );
  }

  void _showPlaceDetails(DocumentSnapshot place) {
    final placeData = place.data() as Map<String, dynamic>?;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(placeData?['name'] ?? 'No name available'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.location_on, color: Colors.lightBlueAccent),
                  title: Text(placeData?['address'] ?? 'No address available'),
                ),
                if (placeData?.containsKey('phone') ?? false)
                  ListTile(
                    leading: Icon(Icons.phone, color: Colors.green),
                    title: Text(placeData?['phone']),
                  ),
                if (placeData?.containsKey('charging_type') ?? false)
                  ListTile(
                    leading: Icon(Icons.ev_station, color: Colors.orange),
                    title: Text('Charging Type: ${placeData?['charging_type']}'),
                  ),
                if (placeData?.containsKey('kw') ?? false)
                  ListTile(
                    leading: Icon(Icons.bolt, color: Colors.yellow),
                    title: Text('Power: ${placeData?['kw']} kW'),
                  ),
                // เพิ่มการแสดง lat/lng
                ListTile(
                  leading: Icon(Icons.map, color: Colors.lightBlueAccent),
                  title: Text(
                    'Latitude: ${placeData?['lat'] ?? 'N/A'}, Longitude: ${placeData?['lng'] ?? 'N/A'}',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  Text('Close', style: TextStyle(color: Colors.lightBlueAccent)),
            ),
          ],
        );
      },
    );
  }

  // เมธอดสำหรับแสดงคำขอที่รอดำเนินการ
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
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              SizedBox(height: 15),
              Text(
                'Pending Requests',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.lightBlueAccent,
                ),
              ),
              SizedBox(height: 15),
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
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
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
                    ...snapshot.data![0].docs, // จาก 'station_requests'
                    ...snapshot.data![1].docs, // จาก 'place_requests'
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
                          request.data() as Map<String, dynamic>?;

                      final String name =
                          requestData?['name'] ?? 'No name';
                      final String address =
                          requestData?['address'] ?? 'No address';
                      final String phone =
                          requestData?['phone'] ?? 'No phone';
                      final String chargingType =
                          requestData?['charging_type'] ?? 'N/A';
                      final String openHours =
                          requestData?['open_hours'] ?? 'N/A';
                      final double lat = requestData?['lat']?.toDouble() ?? 0.0;
                      final double lng = requestData?['lng']?.toDouble() ?? 0.0;

                      return Card(
                        elevation: 5,
                        margin: EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.lightBlueAccent,
                                ),
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.location_on,
                                      color: Colors.grey),
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
                              if (chargingType != 'N/A')
                                Row(
                                  children: [
                                    Icon(Icons.ev_station,
                                        color: Colors.grey),
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
                                  Icon(Icons.access_time,
                                      color: Colors.grey),
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
                                mainAxisAlignment:
                                    MainAxisAlignment.end,
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
                                    icon: Icon(Icons.cancel,
                                        color: Colors.red),
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

  // เมธอดสำหรับอนุมัติคำขอ
  Future<void> _approveRequest(DocumentSnapshot request) async {
    try {
      Map<String, dynamic>? requestData =
          request.data() as Map<String, dynamic>?;

      String collection = request.reference.parent.id;

      String targetCollection =
          (collection == 'station_requests') ? 'ev_stations' : 'places';

      await FirebaseFirestore.instance.collection(targetCollection).add({
        'name': requestData?['name'] ?? '',
        'address': requestData?['address'] ?? '',
        'lat': requestData?['lat'] ?? 0.0,
        'lng': requestData?['lng'] ?? 0.0,
        'phone': requestData?['phone'] ?? '',
        'open_hours': requestData?['open_hours'] ?? '',
        if (collection == 'station_requests')
          'charging_type': requestData?['charging_type'] ?? '',
        'kw': requestData?['kw'] ?? 0,
      });

      await FirebaseFirestore.instance
          .collection(collection)
          .doc(request.id)
          .delete();

      _removeRequestFromUI(request);

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

  // เมธอดสำหรับปฏิเสธคำขอ
  Future<void> _rejectRequest(DocumentSnapshot request) async {
    try {
      String collection = request.reference.parent.id;

      await FirebaseFirestore.instance
          .collection(collection)
          .doc(request.id)
          .delete();

      _removeRequestFromUI(request);

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

  // เมธอดสำหรับลบคำขอจาก UI
  void _removeRequestFromUI(DocumentSnapshot request) {
    setState(() {
      allRequests.removeWhere((element) => element.id == request.id);
    });
  }

  // เมธอดสำหรับแสดง Dialog เพิ่มสถานีใหม่
  void _showAddStationDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController addressController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController latController = TextEditingController();
    final TextEditingController lngController = TextEditingController();
    final TextEditingController kwController = TextEditingController();

    String selectedChargingType = 'Type 1';
    final List<String> chargingTypes = [
      'Type 1',
      'Type 2',
      'CSS',
      'CHAdeMO',
      'GB/T',
      'Tesla',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16.0),
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Add New EV Station',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.lightBlueAccent,
                      ),
                    ),
                    SizedBox(height: 20),
                    _buildTextField(
                        nameController, 'Name', Icons.drive_file_rename_outline),
                    SizedBox(height: 10),
                    _buildTextField(addressController, 'Address',
                        Icons.location_on),
                    SizedBox(height: 10),
                    _buildTextField(phoneController, 'Phone', Icons.phone),
                    SizedBox(height: 10),
                    _buildTextField(
                        latController, 'Latitude', Icons.my_location),
                    SizedBox(height: 10),
                    _buildTextField(
                        lngController, 'Longitude', Icons.my_location),
                    SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedChargingType,
                      items: chargingTypes.map((String type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(
                            type,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedChargingType = value!;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Charging Type',
                        prefixIcon: Icon(Icons.ev_station, color: Colors.lightBlueAccent),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    _buildTextField(kwController, 'Power (kW)', Icons.bolt),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text('Cancel',
                              style: TextStyle(color: Colors.redAccent)),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () async {
                            if (nameController.text.isEmpty ||
                                addressController.text.isEmpty ||
                                latController.text.isEmpty ||
                                lngController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Please fill out all required fields')),
                              );
                              return;
                            }

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

                            int? kwValue = int.tryParse(kwController.text);
                            if (kwValue == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text('Please enter a valid kW value')),
                              );
                              return;
                            }

                            await FirebaseFirestore.instance
                                .collection('ev_stations')
                                .add({
                              'name': nameController.text,
                              'address': addressController.text,
                              'phone': phoneController.text,
                              'lat': lat,
                              'lng': lng,
                              'charging_type': selectedChargingType,
                              'kw': kwValue,
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content:
                                      Text('Successfully saved EV Station!')),
                            );

                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.lightBlueAccent, // เปลี่ยนสีปุ่ม
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            padding: EdgeInsets.symmetric(
                                vertical: 12, horizontal: 24),
                          ),
                          child: Text('Save'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  // เมธอดสำหรับแสดง Dialog แก้ไขสถานี
  void _showEditStationDialog(DocumentSnapshot station) {
    final placeData = station.data() as Map<String, dynamic>?;

    final TextEditingController nameController =
        TextEditingController(text: placeData?['name']);
    final TextEditingController addressController =
        TextEditingController(text: placeData?['address']);
    final TextEditingController phoneController =
        TextEditingController(text: placeData?['phone']);
    final TextEditingController latController =
        TextEditingController(text: placeData?['lat'].toString());
    final TextEditingController lngController =
        TextEditingController(text: placeData?['lng'].toString());
    final TextEditingController kwController = TextEditingController(
        text: placeData?['kw'].toString());

    String selectedChargingType = placeData?['charging_type'] ?? 'Type 1';

    final List<String> chargingTypes = [
      'Type 1',
      'Type 2',
      'CSS',
      'CHAdeMO',
      'GB/T',
      'Tesla',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16.0),
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Edit EV Station',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.lightBlueAccent,
                      ),
                    ),
                    SizedBox(height: 20),
                    _buildTextField(
                        nameController, 'Name', Icons.drive_file_rename_outline),
                    SizedBox(height: 10),
                    _buildTextField(
                        addressController, 'Address', Icons.location_on),
                    SizedBox(height: 10),
                    _buildTextField(phoneController, 'Phone', Icons.phone),
                    SizedBox(height: 10),
                    _buildTextField(
                        latController, 'Latitude', Icons.my_location),
                    SizedBox(height: 10),
                    _buildTextField(
                        lngController, 'Longitude', Icons.my_location),
                    SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedChargingType,
                      items: chargingTypes.map((String type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(
                            type,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedChargingType = value!;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Charging Type',
                        prefixIcon: Icon(Icons.ev_station, color: Colors.lightBlueAccent),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    _buildTextField(kwController, 'Power (kW)', Icons.bolt),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text('Cancel',
                              style: TextStyle(color: Colors.redAccent)),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () async {
                            if (nameController.text.isEmpty ||
                                addressController.text.isEmpty ||
                                latController.text.isEmpty ||
                                lngController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text('Please fill out all required fields')),
                              );
                              return;
                            }

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

                            int? kwValue = int.tryParse(kwController.text);
                            if (kwValue == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text('Please enter a valid kW value')),
                              );
                              return;
                            }

                            await FirebaseFirestore.instance
                                .collection('ev_stations')
                                .doc(station.id)
                                .update({
                              'name': nameController.text,
                              'address': addressController.text,
                              'phone': phoneController.text,
                              'lat': lat,
                              'lng': lng,
                              'charging_type': selectedChargingType,
                              'kw': kwValue,
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content:
                                      Text('Successfully updated EV Station!')),
                            );

                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.lightBlueAccent, // เปลี่ยนสีปุ่ม
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            padding:
                                EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                          ),
                          child: Text('Save'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  // เมธอดสำหรับลบสถานี
  void _deleteStation(String id) async {
    await _firestore.collection(_selectedCategory).doc(id).delete();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Successfully deleted!')),
    );
  }

  // เมธอดสำหรับสร้าง TextField
  Widget _buildTextField(
      TextEditingController controller, String labelText, IconData icon) {
    return TextFormField(
      controller: controller,
      keyboardType: (labelText == 'Latitude' ||
              labelText == 'Longitude' ||
              labelText == 'Power (kW)')
          ? TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon, color: Colors.lightBlueAccent),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
      ),
    );
  }
}
