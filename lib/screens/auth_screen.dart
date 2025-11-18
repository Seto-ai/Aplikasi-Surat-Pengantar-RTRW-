import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  String emailOrPhone = '', password = '';
  bool isLogin = true;
  bool _obscurePassword = true;

  Future<void> _submit() async {
    try {
      if (isLogin) {
        await _auth.signInWithEmailAndPassword(email: emailOrPhone, password: password);
        final userDoc = await _firestore.collection('users').doc(_auth.currentUser!.uid).get();
        if (userDoc.exists) {
          final role = userDoc['role'];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('role', role);
          context.go('/dashboard/$role');
        } else {
          context.go('/biodata');
        }
      } else {
        final userCredential = await _auth.createUserWithEmailAndPassword(email: emailOrPhone, password: password);
        await userCredential.user!.sendEmailVerification();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verifikasi email dikirim!')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  void initState() {
    super.initState();
    _checkPersist();
  }

  Future<void> _checkPersist() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role');
    if (role != null && _auth.currentUser != null) {
      context.go('/dashboard/$role');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isLogin ? 'Login' : 'Register')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              decoration: InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              onChanged: (val) => emailOrPhone = val,
            ),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              obscureText: _obscurePassword,
              onChanged: (val) => password = val,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16)),
              onPressed: _submit,
              child: Text(isLogin ? 'Login' : 'Register'),
            ),
            SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => isLogin = !isLogin),
              child: Text(isLogin ? 'Belum punya akun?' : 'Sudah punya akun?'),
            ),
          ],
        ),
      ),
    );
  }
}