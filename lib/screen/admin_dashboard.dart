import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'manage_users_page.dart'; // เพิ่มการนำเข้าหน้า ManageUsersPage

class AdminDashboardPage extends StatefulWidget {
  @override
  _AdminDashboardPageState createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // เปลี่ยนจาก _selectedCategory เป็น selectedType
  String selectedType = 'ev_station';
  String selectedChargingType = 'Type 1';

  // ปรับรายการประเภทสถานที่
  final List<String> placeTypes = [
    'ev_station',
    'restaurant',
    'cafe',
    'store',
    'gas_station'
  ];

  final List<String> chargingTypes = [
    'Type 1',
    'Type 2',
    'CSS',
    'CHAdeMO',
    'GB/T',
    'Tesla',
  ];

  List<DocumentSnapshot> allRequests = [];

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
        backgroundColor: const Color.fromARGB(255, 3, 33, 153),
        actions: [
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
                  leading: Icon(Icons.pending_actions,
                      color: Colors.lightBlueAccent),
                  title: Text('Manage Requests'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
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
                      value: selectedType,
                      items: placeTypes.map((type) {
                        IconData icon;
                        switch (type) {
                          case 'ev_station':
                            icon = Icons.ev_station;
                            break;
                          case 'restaurant':
                            icon = Icons.restaurant;
                            break;
                          case 'cafe':
                            icon = Icons.local_cafe;
                            break;
                          case 'store':
                            icon = Icons.store;
                            break;
                          case 'gas_station':
                            icon = Icons.local_gas_station;
                            break;
                          default:
                            icon = Icons.place;
                        }
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Row(
                            children: [
                              Icon(icon, color: Colors.lightBlueAccent),
                              SizedBox(width: 10),
                              Text(
                                _getTypeLabel(type),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedType = value!;
                        });
                      },
                      decoration: InputDecoration(
                        border: InputBorder.none,
                      ),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: Colors.lightBlueAccent,
                      ),
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<QuerySnapshot>(
                  future: _firestore
                      .collection(selectedType == 'ev_station'
                          ? 'ev_stations'
                          : 'places')
                      .where('type', isEqualTo: selectedType)
                      .get(),
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
                            leading: selectedType == 'ev_station'
                                ? Icon(
                                    Icons.ev_station,
                                    color: Colors.lightBlueAccent,
                                    size: 40,
                                  )
                                : Icon(
                                    Icons.place,
                                    color: Colors.lightBlueAccent,
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
                                if (placeData?['image_url'] != null &&
                                    placeData!['image_url'].isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8.0),
                                    child: Image.network(
                                      placeData['image_url'],
                                      height: 100,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                Text(
                                  placeData?['address'] ??
                                      'No address available',
                                  style: TextStyle(fontSize: 16),
                                ),
                                SizedBox(height: 4),
                                if (selectedType == 'ev_station') ...[
                                  Text(
                                    'Charging Type: ${placeData?['charging_type'] ?? 'N/A'}',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  Text(
                                    'Power: ${placeData?['kw'] ?? 'N/A'} kW',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ],
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () {
                                    _showEditPlaceDialog(place);
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    _deletePlace(place.id);
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
          Positioned(
            bottom: 80,
            right: 16,
            child: FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ManageUsersPage()),
                );
              },
              heroTag: 'manageUsers',
              backgroundColor: Colors.white,
              shape: CircleBorder(),
              child: Icon(
                Icons.person,
                color: Colors.blueAccent,
                size: 26,
              ),
              tooltip: 'Manage Users',
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPlaceDialog,
        heroTag: 'addPlace',
        child: Icon(Icons.add),
        backgroundColor: Colors.lightBlueAccent,
        tooltip: 'Add New Place',
      ),
    );
  }

  // ฟังก์ชันสำหรับแปลง type เป็น label ที่อ่านง่าย
  String _getTypeLabel(String type) {
    switch (type) {
      case 'ev_station':
        return 'EV Station';
      case 'restaurant':
        return 'Restaurant';
      case 'cafe':
        return 'Cafe';
      case 'store':
        return 'Store';
      case 'gas_station':
        return 'Gas Station';
      default:
        return 'Unknown';
    }
  }

  void _showPlaceDetails(DocumentSnapshot place) {
    final placeData = place.data() as Map<String, dynamic>?;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(placeData?['name'] ?? 'No name available'),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth:
                    MediaQuery.of(context).size.width * 0.8, // จำกัดความกว้าง
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (placeData?['image_url'] != null &&
                      placeData!['image_url'].isNotEmpty)
                    SizedBox(
                      height: 200,
                      width: MediaQuery.of(context).size.width *
                          0.7, // จำกัดความกว้าง
                      child: Image.network(
                        placeData['image_url'],
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    CircleAvatar(
                      child: Icon(Icons.person, size: 40),
                      radius: 40,
                    ),
                  SizedBox(height: 10),
                  ListTile(
                    leading:
                        Icon(Icons.location_on, color: Colors.lightBlueAccent),
                    title:
                        Text(placeData?['address'] ?? 'No address available'),
                  ),
                  if (placeData?.containsKey('phone') ?? false)
                    ListTile(
                      leading: Icon(Icons.phone, color: Colors.green),
                      title: Text(placeData?['phone']),
                    ),
                  if (placeData?['type'] == 'ev_station') ...[
                    ListTile(
                      leading: Icon(Icons.ev_station, color: Colors.orange),
                      title:
                          Text('Charging Type: ${placeData?['charging_type']}'),
                    ),
                    ListTile(
                      leading: Icon(Icons.bolt, color: Colors.yellow),
                      title: Text('Power: ${placeData?['kw']} kW'),
                    ),
                  ],
                  // แสดง lat/lng
                  ListTile(
                    leading: Icon(Icons.map, color: Colors.lightBlueAccent),
                    title: Text(
                      'Latitude: ${placeData?['lat'] ?? 'N/A'}, Longitude: ${placeData?['lng'] ?? 'N/A'}',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close',
                  style: TextStyle(color: Colors.lightBlueAccent)),
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
                      var requestData = request.data() as Map<String, dynamic>?;

                      final String name = requestData?['name'] ?? 'No name';
                      final String address =
                          requestData?['address'] ?? 'No address';
                      final String phone = requestData?['phone'] ?? 'No phone';
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
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                              if (chargingType != 'N/A')
                                Row(
                                  children: [
                                    Icon(Icons.ev_station, color: Colors.grey),
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
      Map<String, dynamic>? requestData =
          request.data() as Map<String, dynamic>?;

      String collection = request.reference.parent.id;
      String type = requestData?['type']?.toString() ?? 'unknown';

      // กำหนดคอลเล็กชันเป้าหมายโดยใช้ทั้งคอลเล็กชันต้นทางและประเภทของสถานที่
      String targetCollection;
      if (collection == 'station_requests' && type == 'ev_station') {
        targetCollection = 'ev_stations';
      } else if (collection == 'place_requests' && type != 'ev_station') {
        targetCollection = 'places';
      } else {
        // หากข้อมูลไม่ตรงกัน ให้แสดงข้อผิดพลาด
        throw Exception('Mismatch between request collection and place type.');
      }

      // ฟิลด์ข้อมูลพื้นฐาน
      Map<String, dynamic> dataToAdd = {
        'name': requestData?['name']?.toString() ?? 'No name provided',
        'address': requestData?['address']?.toString() ?? 'No address provided',
        'lat': requestData?['lat']?.toDouble() ?? 0.0,
        'lng': requestData?['lng']?.toDouble() ?? 0.0,
        'phone': requestData?['phone']?.toString() ?? 'No phone provided',
        'open_hours':
            requestData?['open_hours']?.toString() ?? 'No open hours provided',
        'image_url': requestData?['image_url']?.toString() ?? '',
        'type': type,
        'status': 'active',
        'created_at': FieldValue.serverTimestamp(),
      };

      // เพิ่มฟิลด์เพิ่มเติมสำหรับ EV Station
      if (type == 'ev_station') {
        dataToAdd['type'] = 'ev_station';
        dataToAdd['charging_type'] =
            requestData?['charging_type']?.toString() ?? 'Unknown';
        dataToAdd['kw'] = requestData?['kw']?.toDouble() ?? 0.0;
      }

      // บันทึกข้อมูลไปยังคอลเล็กชันที่ถูกต้อง
      await FirebaseFirestore.instance
          .collection(targetCollection)
          .add(dataToAdd);

      // ลบคำขอที่ได้รับการอนุมัติแล้ว
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(request.id)
          .delete();

      _removeRequestFromUI(request);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Request Approved and ${type == 'ev_station' ? 'EV Station' : 'Place'} added!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error approving request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve request: $e'),
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

  void _showAddPlaceDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController addressController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController latController = TextEditingController();
    final TextEditingController lngController = TextEditingController();
    final TextEditingController kwController = TextEditingController();

    String tempSelectedType = selectedType;
    String tempSelectedChargingType = 'Type 1';
    File? _selectedImage;

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
                Future<void> _pickImage() async {
                  final picker = ImagePicker();
                  final pickedFile =
                      await picker.pickImage(source: ImageSource.gallery);
                  if (pickedFile != null) {
                    setState(() {
                      _selectedImage = File(pickedFile.path);
                    });
                  }
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Add New Place',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.lightBlueAccent,
                      ),
                    ),
                    SizedBox(height: 20),
                    GestureDetector(
                      onTap: _pickImage,
                      child: _selectedImage != null
                          ? Image.file(
                              _selectedImage!,
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              height: 150,
                              width: double.infinity,
                              color: Colors.grey[300],
                              child: Icon(
                                Icons.camera_alt,
                                color: Colors.grey[700],
                                size: 50,
                              ),
                            ),
                    ),
                    SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _pickImage,
                      icon: Icon(Icons.image, color: Colors.lightBlueAccent),
                      label: Text(
                        'Select Image',
                        style: TextStyle(color: Colors.lightBlueAccent),
                      ),
                    ),
                    SizedBox(height: 10),
                    _buildTextField(nameController, 'Name',
                        Icons.drive_file_rename_outline),
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
                      value: tempSelectedType,
                      items: placeTypes.map((String type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(
                            _getTypeLabel(type),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          tempSelectedType = value!;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Type',
                        prefixIcon:
                            Icon(Icons.category, color: Colors.lightBlueAccent),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    if (tempSelectedType == 'ev_station') ...[
                      DropdownButtonFormField<String>(
                        value: tempSelectedChargingType,
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
                            tempSelectedChargingType = value!;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Charging Type',
                          prefixIcon: Icon(Icons.ev_station,
                              color: Colors.lightBlueAccent),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      _buildTextField(kwController, 'Power (kW)', Icons.bolt),
                      SizedBox(height: 10),
                    ],
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
                                lngController.text.isEmpty ||
                                (tempSelectedType == 'ev_station' &&
                                    kwController.text.isEmpty)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Please fill out all required fields')),
                              );
                              return;
                            }

                            double? lat = double.tryParse(latController.text);
                            double? lng = double.tryParse(lngController.text);
                            double? kwValue = tempSelectedType == 'ev_station'
                                ? double.tryParse(kwController.text)
                                : null;

                            if (lat == null || lng == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Please enter valid Latitude and Longitude values')),
                              );
                              return;
                            }

                            if (tempSelectedType == 'ev_station' &&
                                kwValue == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text('Please enter a valid kW value')),
                              );
                              return;
                            }

                            String imageUrl = '';
                            if (_selectedImage != null) {
                              String fileName =
                                  '${DateTime.now().millisecondsSinceEpoch}.jpg';
                              Reference storageRef = FirebaseStorage.instance
                                  .ref()
                                  .child('place_images')
                                  .child(fileName);
                              UploadTask uploadTask =
                                  storageRef.putFile(_selectedImage!);
                              TaskSnapshot snapshot = await uploadTask;
                              imageUrl = await snapshot.ref.getDownloadURL();
                            }

                            // เลือกคอลเล็กชันตามประเภท
                            String collectionName =
                                tempSelectedType == 'ev_station'
                                    ? 'ev_stations'
                                    : 'places';

                            Map<String, dynamic> dataToAdd = {
                              'name': nameController.text.isNotEmpty
                                  ? nameController.text
                                  : 'No name provided',
                              'address': addressController.text.isNotEmpty
                                  ? addressController.text
                                  : 'No address provided',
                              'phone': phoneController.text.isNotEmpty
                                  ? phoneController.text
                                  : 'No phone provided',
                              'lat': lat,
                              'lng': lng,
                              'type': tempSelectedType,
                              'open_hours': 'No open hours provided',
                              'image_url': imageUrl,
                              'status': 'active',
                              'created_at': FieldValue.serverTimestamp(),
                            };

                            if (tempSelectedType == 'ev_station') {
                              dataToAdd['charging_type'] =
                                  tempSelectedChargingType;
                              dataToAdd['kw'] = kwValue ?? 0.0;
                            }

                            await FirebaseFirestore.instance
                                .collection(collectionName)
                                .add(dataToAdd);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Successfully saved ${_getTypeLabel(tempSelectedType)}!')),
                            );

                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.lightBlueAccent,
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

// เมธอดสำหรับแสดง Dialog แก้ไขสถานที่
  void _showEditPlaceDialog(DocumentSnapshot place) {
    final placeData = place.data() as Map<String, dynamic>?;

    final TextEditingController nameController =
        TextEditingController(text: placeData?['name']?.toString() ?? '');
    final TextEditingController addressController =
        TextEditingController(text: placeData?['address']?.toString() ?? '');
    final TextEditingController phoneController =
        TextEditingController(text: placeData?['phone']?.toString() ?? '');
    final TextEditingController latController =
        TextEditingController(text: placeData?['lat']?.toString() ?? '');
    final TextEditingController lngController =
        TextEditingController(text: placeData?['lng']?.toString() ?? '');
    final TextEditingController kwController =
        TextEditingController(text: placeData?['kw']?.toString() ?? '');

    String tempSelectedType = placeData?['type']?.toString() ?? 'ev_station';
    String tempSelectedChargingType =
        placeData?['charging_type']?.toString() ?? 'Type 1';
    File? _selectedImage; // ตัวแปรเก็บไฟล์ภาพที่เลือก

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
                Future<void> _pickImage() async {
                  final picker = ImagePicker();
                  final pickedFile =
                      await picker.pickImage(source: ImageSource.gallery);
                  if (pickedFile != null) {
                    setState(() {
                      _selectedImage = File(pickedFile.path);
                    });
                  }
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Edit Place',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.lightBlueAccent,
                      ),
                    ),
                    SizedBox(height: 20),
                    // แสดงภาพที่มีอยู่ หรือภาพที่เลือกใหม่
                    GestureDetector(
                      onTap: _pickImage,
                      child: _selectedImage != null
                          ? Image.file(
                              _selectedImage!,
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : (placeData?['image_url'] != null &&
                                  placeData!['image_url'].isNotEmpty
                              ? Image.network(
                                  placeData['image_url'],
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  height: 150,
                                  width: double.infinity,
                                  color: Colors.grey[300],
                                  child: Icon(
                                    Icons.camera_alt,
                                    color: Colors.grey[700],
                                    size: 50,
                                  ),
                                )),
                    ),
                    SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _pickImage,
                      icon: Icon(Icons.image, color: Colors.lightBlueAccent),
                      label: Text(
                        'Select Image',
                        style: TextStyle(color: Colors.lightBlueAccent),
                      ),
                    ),
                    SizedBox(height: 10),
                    _buildTextField(nameController, 'Name',
                        Icons.drive_file_rename_outline),
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
                      value: tempSelectedType,
                      items: placeTypes.map((String type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(
                            _getTypeLabel(type),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          tempSelectedType = value!;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Type',
                        prefixIcon:
                            Icon(Icons.category, color: Colors.lightBlueAccent),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    // แสดง Charging Type และ Power เฉพาะเมื่อเลือกเป็น EV Station
                    if (tempSelectedType == 'ev_station') ...[
                      DropdownButtonFormField<String>(
                        value: tempSelectedChargingType,
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
                            tempSelectedChargingType = value!;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Charging Type',
                          prefixIcon: Icon(Icons.ev_station,
                              color: Colors.lightBlueAccent),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      _buildTextField(kwController, 'Power (kW)', Icons.bolt),
                      SizedBox(height: 10),
                    ],
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
                            // ตรวจสอบฟิลด์ที่จำเป็น
                            if (nameController.text.isEmpty ||
                                addressController.text.isEmpty ||
                                latController.text.isEmpty ||
                                lngController.text.isEmpty ||
                                (tempSelectedType == 'ev_station' &&
                                    kwController.text.isEmpty)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Please fill out all required fields')),
                              );
                              return;
                            }

                            double? lat = double.tryParse(latController.text);
                            double? lng = double.tryParse(lngController.text);
                            double? kwValue = tempSelectedType == 'ev_station'
                                ? double.tryParse(kwController.text)
                                : null;

                            if (lat == null || lng == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Please enter valid Latitude and Longitude values')),
                              );
                              return;
                            }

                            if (tempSelectedType == 'ev_station' &&
                                kwValue == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text('Please enter a valid kW value')),
                              );
                              return;
                            }

                            String imageUrl = placeData?['image_url'] ?? '';
                            if (_selectedImage != null) {
                              // อัปโหลดภาพใหม่ไปยัง Firebase Storage
                              String fileName =
                                  '${DateTime.now().millisecondsSinceEpoch}.jpg';
                              Reference storageRef = FirebaseStorage.instance
                                  .ref()
                                  .child('place_images')
                                  .child(fileName);
                              UploadTask uploadTask =
                                  storageRef.putFile(_selectedImage!);
                              TaskSnapshot snapshot = await uploadTask;
                              imageUrl = await snapshot.ref.getDownloadURL();
                            }

                            // กำหนดฟิลด์ที่อาจขาดหายไปด้วยค่าเริ่มต้น
                            Map<String, dynamic> dataToUpdate = {
                              'name': nameController.text.isNotEmpty
                                  ? nameController.text
                                  : 'No name provided',
                              'address': addressController.text.isNotEmpty
                                  ? addressController.text
                                  : 'No address provided',
                              'phone': phoneController.text.isNotEmpty
                                  ? phoneController.text
                                  : 'No phone provided',
                              'lat': lat,
                              'lng': lng,
                              'type': tempSelectedType,
                              'open_hours':
                                  placeData?['open_hours']?.toString() ??
                                      'No open hours provided',
                              'image_url': imageUrl, // อัปเดต URL ของภาพ
                              'status': 'active', // หรือสถานะอื่นที่เหมาะสม
                            };

                            // ถ้าเป็น EV Station เพิ่มฟิลด์เพิ่มเติม
                            if (tempSelectedType == 'ev_station') {
                              dataToUpdate['charging_type'] =
                                  tempSelectedChargingType;
                              dataToUpdate['kw'] = kwValue ?? 0.0;
                            } else {
                              // ลบฟิลด์ที่ไม่จำเป็นสำหรับประเภทอื่น ๆ
                              dataToUpdate.remove('charging_type');
                              dataToUpdate.remove('kw');
                            }

                            await FirebaseFirestore.instance
                                .collection('places')
                                .doc(place.id)
                                .update(dataToUpdate);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Successfully updated ${_getTypeLabel(tempSelectedType)}!')),
                            );

                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.lightBlueAccent, // เปลี่ยนสีปุ่ม
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

  // เมธอดสำหรับลบสถานที่
  void _deletePlace(String id) async {
    await _firestore.collection('places').doc(id).delete();

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
