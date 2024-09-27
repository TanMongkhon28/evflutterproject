import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? userName;
  String? userEmail;
  String? userPhone;
  String? profileImageUrl;
  File? _image;

  final picker = ImagePicker();
  TextEditingController _usernameController = TextEditingController();
  TextEditingController _emailController = TextEditingController();
  TextEditingController _phoneController = TextEditingController();

  late Future<void> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadUserProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<String?> _getUserId() async {
    User? user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  Future<void> _loadUserProfile() async {
    String? userId = await _getUserId();
    if (userId != null) {
      try {
        DocumentReference userDocRef =
            FirebaseFirestore.instance.collection('users').doc(userId);
        DocumentSnapshot userSnapshot = await userDocRef.get();

        if (!userSnapshot.exists) {
          // Create a new document if not found
          await userDocRef.set({
            'username': '',
            'email': FirebaseAuth.instance.currentUser?.email ?? '',
            'phone': '',
            'profileImageUrl': '',
          });
          userSnapshot = await userDocRef.get();
        }

        var userData = userSnapshot.data() as Map<String, dynamic>?;

        setState(() {
          userName = userData?['username'] ?? '';
          userEmail = userData?['email'] ?? '';
          userPhone = userData?['phone'] ?? '';
          profileImageUrl = userData?['profileImageUrl'] ?? '';

          _usernameController.text = userName!;
          _emailController.text = userEmail!;
          _phoneController.text = userPhone!;
        });
      } catch (e) {
        print('Error loading user profile: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile data')),
        );
        // Optionally, you can rethrow the error to let FutureBuilder handle it
        // throw e;
      }
    } else {
      // Handle the case where the user is not logged in
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User not logged in')),
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
        });
        await _uploadProfileImage();
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image')),
      );
    }
  }

  Future<void> _uploadProfileImage() async {
    String? userId = await _getUserId();
    if (userId != null && _image != null) {
      try {
        Reference storageReference =
            FirebaseStorage.instance.ref().child('profile_images/$userId.jpg');
        UploadTask uploadTask = storageReference.putFile(_image!);

        await uploadTask;
        String downloadUrl = await storageReference.getDownloadURL();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .set({'profileImageUrl': downloadUrl}, SetOptions(merge: true));

        setState(() {
          profileImageUrl = downloadUrl;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile picture updated successfully')),
        );
      } catch (e) {
        print('Error uploading profile picture: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload profile picture')),
        );
      }
    }
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _profileFuture = _loadUserProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color(0xFFFFC107),
        title: Text(
          'Profile',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: FutureBuilder<void>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Show CircularProgressIndicator while loading
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            // Show error message if there's an error
            return Center(
              child: Text(
                'Error loading profile data',
                style: TextStyle(color: Colors.red),
              ),
            );
          } else {
            // Show profile data when loading is complete
            return RefreshIndicator(
              onRefresh: _refreshProfile,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min, // Ensures Column takes minimum space
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 70,
                            backgroundImage: profileImageUrl != null &&
                                    profileImageUrl!.isNotEmpty
                                ? CachedNetworkImageProvider(profileImageUrl!)
                                : AssetImage('assets/images/default_avatar.png')
                                    as ImageProvider,
                            backgroundColor: Colors.grey.shade300,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: CircleAvatar(
                                backgroundColor: Colors.blue,
                                radius: 20,
                                child: Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24), // Fixed spacing instead of Spacer
                      Text(
                        userName ?? 'No Name',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Row(
                          children: [
                            Icon(Icons.email, color: Colors.black54),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                userEmail ?? 'No Email',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Row(
                          children: [
                            Icon(Icons.phone, color: Colors.black54),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                userPhone ?? 'No Phone',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24), // Replace Spacer with SizedBox
                      ElevatedButton.icon(
                        onPressed: () async {
                          final updated = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditProfilePage(
                                usernameController: _usernameController,
                                emailController: _emailController,
                                phoneController: _phoneController,
                              ),
                            ),
                          );

                          if (updated == true) {
                            await _refreshProfile();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Profile updated successfully')),
                            );
                          }
                        },
                        icon: Icon(Icons.edit, color: Colors.white),
                        label: Text('Edit Profile'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding:
                              EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                          elevation: 4,
                          shadowColor: Colors.black.withOpacity(0.3),
                        ),
                      ),
                      SizedBox(height: 20), // Additional spacing if needed
                    ],
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
