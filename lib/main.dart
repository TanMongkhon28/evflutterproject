import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'screen/login_form.dart';
import 'package:evflutterproject/screen/register_form.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EV Project',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const LoginPage(),
      routes: {
        '/loginForm': (context) => LoginFormPage(),
        '/RegisterForm': (context) => const RegisterForm(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  void _navigateToLoginForm() {
    Navigator.pushNamed(context, '/loginForm');
  }

  void _navigateToRegisterForm() {
    Navigator.pushNamed(context, '/RegisterForm');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade900,
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                children: <TextSpan>[
                  TextSpan(text: 'Electric Vehicle\n'),
                  TextSpan(text: 'Driving Plan\n'),
                  TextSpan(
                    text: 'Application',
                    style: TextStyle(color: Colors.orange),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 50),
            ConstrainedBox(
              constraints:
                  const BoxConstraints.tightFor(width: 250, height: 50),
              child: ElevatedButton(
                onPressed: _navigateToLoginForm,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Login', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints:
                  const BoxConstraints.tightFor(width: 250, height: 50),
              child: OutlinedButton(
                onPressed: _navigateToRegisterForm,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Register', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
