import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ฟังก์ชันสำหรับเปลี่ยนรหัสผ่าน
  Future<void> _changePassword() async {
    String currentPassword = _currentPasswordController.text.trim();
    String newPassword = _newPasswordController.text.trim();
    String confirmPassword = _confirmPasswordController.text.trim();

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("New password and confirm password don't match")),
      );
      return;
    }

    try {
      // รับ current user
      User? user = _auth.currentUser;

      if (user != null) {
        // ทำการเข้าสู่ระบบใหม่ด้วยรหัสผ่านปัจจุบันเพื่อความปลอดภัย
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        );

        // Reauthenticate ผู้ใช้
        await user.reauthenticateWithCredential(credential);

        // เปลี่ยนรหัสผ่าน
        await user.updatePassword(newPassword);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password updated successfully')),
        );
      }
    } catch (error) {
      print('Error updating password: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update password')),
      );
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        backgroundColor: Color.fromARGB(255, 250, 184, 1),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 20),

            // แสดงฟอร์มกรอกรหัสผ่าน
            _buildPasswordField('Password', _currentPasswordController, obscureText: true),
            SizedBox(height: 20),
            _buildPasswordField('New Password', _newPasswordController, obscureText: true),
            SizedBox(height: 20),
            _buildPasswordField('Confirm Password', _confirmPasswordController, obscureText: true),

            SizedBox(height: 40),

            // ปุ่ม Confirm สำหรับบันทึกรหัสผ่านใหม่
            ElevatedButton(
              onPressed: _changePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0D47A1),
                padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                'Confirm',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget สำหรับสร้างฟิลด์กรอกรหัสผ่าน
  Widget _buildPasswordField(String label, TextEditingController controller, {bool obscureText = false}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: Colors.grey[200],
      ),
    );
  }
}
