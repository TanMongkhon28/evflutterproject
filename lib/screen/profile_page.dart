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

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
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
          // สร้างเอกสารใหม่ถ้าไม่พบ
          await userDocRef.set({
            'username': '',
            'email': FirebaseAuth.instance.currentUser?.email ?? '',
            'phone': '',
            'profileImageUrl': '',
          });
          userSnapshot = await userDocRef.get();
        }

        setState(() {
          var userData = userSnapshot.data() as Map<String, dynamic>?;
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
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
        _uploadProfileImage();
      }
    });
  }

  Future<void> _uploadProfileImage() async {
    String? userId = await _getUserId();
    if (userId != null && _image != null) {
      try {
        Reference storageReference =
            FirebaseStorage.instance.ref().child('profile_images/$userId.jpg');
        UploadTask uploadTask = storageReference.putFile(_image!);

        await uploadTask.whenComplete(() => null);
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

  Future<void> _updateUserProfile() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'username': _usernameController.text,
          'email': _emailController.text,
          'phone': _phoneController.text,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile updated successfully')),
        );
      } catch (e) {
        print('Error updating profile: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile')),
        );
      }
    }
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
      body: userName == null
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
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
                  SizedBox(height: 24),
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
                  Spacer(),
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
                        await _loadUserProfile();
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
                ],
              ),
            ),
    );
  }
}
