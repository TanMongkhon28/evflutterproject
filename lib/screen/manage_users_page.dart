import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageUsersPage extends StatefulWidget {
  @override
  _ManageUsersPageState createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _users = [];
  List<DocumentSnapshot> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterUsers);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('users').get();
      setState(() {
        _users = snapshot.docs;
        _filteredUsers = _users;
      });
    } catch (e) {
      print('Error fetching users: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch users')),
      );
    }
  }

  void _filterUsers() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _users.where((user) {
        Map<String, dynamic> data = user.data() as Map<String, dynamic>;
        return (data['username']?.toString().toLowerCase().contains(query) ?? false) ||
               (data['email']?.toString().toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  void _showUserDetails(DocumentSnapshot user) {
    Map<String, dynamic> userData = user.data() as Map<String, dynamic>;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(userData['username'] ?? 'No name'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                if (userData['profileImageUrl'] != null && userData['profileImageUrl'].isNotEmpty)
                  CircleAvatar(
                    backgroundImage: NetworkImage(userData['profileImageUrl']),
                    radius: 40,
                  )
                else
                  CircleAvatar(
                    child: Icon(Icons.person, size: 40),
                    radius: 40,
                  ),
                SizedBox(height: 10),
                ListTile(
                  leading: Icon(Icons.email, color: Colors.lightBlueAccent),
                  title: Text(userData['email'] ?? 'No email'),
                ),
                if (userData['phone'] != null)
                  ListTile(
                    leading: Icon(Icons.phone, color: Colors.lightBlueAccent),
                    title: Text(userData['phone']),
                  ),
                // เพิ่มฟิลด์อื่นๆ ที่ต้องการแสดง เช่น status, created_at ฯลฯ
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: TextStyle(color: Colors.lightBlueAccent)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _banUser(DocumentSnapshot user) async {
    try {
      await _firestore.collection('users').doc(user.id).update({'banned': true});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User banned successfully')),
      );
      _fetchUsers(); // รีเฟรชข้อมูล
    } catch (e) {
      print('Error banning user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to ban user')),
      );
    }
  }

  Future<void> _unbanUser(DocumentSnapshot user) async {
    try {
      await _firestore.collection('users').doc(user.id).update({'banned': false});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User unbanned successfully')),
      );
      _fetchUsers(); // รีเฟรชข้อมูล
    } catch (e) {
      print('Error unbanning user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to unban user')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Users'),
        backgroundColor: const Color.fromARGB(255, 3, 33, 153),
      ),
      body: Column(
        children: [
          // แถบค้นหา
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Users',
                prefixIcon: Icon(Icons.search, color: Colors.lightBlueAccent),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
            ),
          ),
          // รายการผู้ใช้งาน
          Expanded(
            child: _filteredUsers.isEmpty
                ? Center(child: Text('No users found'))
                : ListView.builder(
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      final userData = user.data() as Map<String, dynamic>?;
                      bool isBanned = userData?['banned'] ?? false;

                      return Card(
                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 4,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: (userData?['profileImageUrl'] != null && userData!['profileImageUrl'].isNotEmpty)
                                ? NetworkImage(userData['profileImageUrl'])
                                : null,
                            child: (userData?['profileImageUrl'] == null || userData!['profileImageUrl'].isEmpty)
                                ? Icon(Icons.person, color: Colors.white)
                                : null,
                            backgroundColor: Colors.lightBlueAccent,
                          ),
                          title: Text(userData?['username'] ?? 'No name'),
                          subtitle: Text(userData?['email'] ?? 'No email'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.info, color: Colors.green),
                                onPressed: () => _showUserDetails(user),
                                tooltip: 'View Details',
                              ),
                              IconButton(
                                icon: Icon(
                                  isBanned ? Icons.check_circle : Icons.cancel,
                                  color: isBanned ? Colors.green : Colors.red,
                                ),
                                onPressed: () {
                                  if (isBanned) {
                                    _unbanUser(user);
                                  } else {
                                    _banUser(user);
                                  }
                                },
                                tooltip: isBanned ? 'Unban User' : 'Ban User',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
