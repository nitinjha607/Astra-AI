import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignUpPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  const SignUpPage({super.key, required this.toggleTheme});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _profilePicController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _error;
  bool _obscurePassword = true;

  Future<void> _signup() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // ignore: unused_local_variable
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await user.updateDisplayName(_fullNameController.text.trim());
        if (_profilePicController.text.trim().isNotEmpty) {
          await user.updatePhotoURL(_profilePicController.text.trim());
        }

        await user.reload();

        print("🔁 Trying to save data to Firestore...");
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
              'uid': user.uid,
              'fullName': _fullNameController.text.trim(),
              'email': _emailController.text.trim(),
              'phone': _phoneController.text.trim(),
              'profilePic': _profilePicController.text.trim(),
              'createdAt': FieldValue.serverTimestamp(),
            })
            .then((_) {
              print("✅ Firestore write successful");
            })
            .catchError((error) {
              print("❌ Firestore write error: $error");
              setState(() => _error = "Firestore Error: $error");
            });
      } else {
        print("❌ User is null after signup.");
        setState(() => _error = "User not found after signup.");
      }

      if (_error == null) {
        Navigator.pop(context); // Go back to login if successful
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
      print("❌ Firebase Auth Exception: ${e.code} - ${e.message}");
    } catch (e) {
      setState(() => _error = "Something went wrong: $e");
      print("❌ General Exception: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sign Up"),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: widget.toggleTheme,
            tooltip: 'Toggle Theme',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _fullNameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ElevatedButton(
              onPressed: _isLoading ? null : _signup,
              child:
                  _isLoading
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text("Sign Up"),
            ),
          ],
        ),
      ),
    );
  }
}
