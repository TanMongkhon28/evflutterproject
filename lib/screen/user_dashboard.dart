import 'package:flutter/material.dart';

class UserDashboardPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Dashboard'),
      ),
      body: Center(
        child: Text('Welcome, User!'),
      ),
    );
  }
}
