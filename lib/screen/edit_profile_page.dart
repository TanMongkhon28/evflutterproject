import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditProfilePage extends StatefulWidget {
  final TextEditingController usernameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;

  EditProfilePage({
    required this.usernameController,
    required this.emailController,
    required this.phoneController,
  });

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Removed _loadUserData() since data is already loaded in ProfilePage
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      // If validation fails, do nothing
      return;
    }

    String username = widget.usernameController.text.trim();
    String email = widget.emailController.text.trim();
    String phone = widget.phoneController.text.trim();

    User? user = _auth.currentUser;

    if (user != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Start updating Firestore data
        await _firestore.collection('users').doc(user.uid).update({
          'username': username,
          'phone': phone,
        });

        // If email has changed, update it in Firebase Auth as well
        if (email != user.email) {
          await user.updateEmail(email);
          // Reload user to update user data
          await user.reload();
        }

        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile updated successfully')),
        );

        Navigator.pop(context, true); // Indicate that the update was successful
      } on FirebaseAuthException catch (e) {
        setState(() {
          _isLoading = false;
        });

        String errorMessage = 'Failed to update profile';

        if (e.code == 'requires-recent-login') {
          errorMessage =
              'Please log in again to update your account information';
        } else if (e.code == 'email-already-in-use') {
          errorMessage = 'This email is already in use. Please use another email';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      } catch (e) {
        setState(() {
          _isLoading = false;
        });

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
      appBar: AppBar(
        title: Text('Edit Profile'),
        backgroundColor: Color.fromARGB(255, 250, 184, 1),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey, // Assign key to the Form
                child: Column(
                  children: [
                    _buildTextField('Username', widget.usernameController,
                        validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your username';
                      }
                      return null;
                    }),
                    SizedBox(height: 20),
                    _buildTextField('Email', widget.emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      // Email format validation
                      if (!RegExp(
                              r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@"
                              r"[a-zA-Z0-9]+\.[a-zA-Z]+")
                          .hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    }),
                    SizedBox(height: 20),
                    _buildTextField('Phone', widget.phoneController,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your phone number';
                      }
                      // Phone number format validation (e.g., 10 digits)
                      if (!RegExp(r"^[0-9]{10}$").hasMatch(value)) {
                        return 'Please enter a valid phone number';
                      }
                      return null;
                    }),
                    SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: _updateProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0D47A1),
                        padding:
                            EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        'Save Changes',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {TextInputType keyboardType = TextInputType.text,
      String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: Colors.grey[200],
      ),
      validator: validator,
    );
  }
}
