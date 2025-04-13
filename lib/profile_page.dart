import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:virtual_assistant/edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback toggleTheme;

  const ProfilePage({Key? key, required this.toggleTheme}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? fullName;
  String? phone;
  String? email;
  String? profilePicUrl;
  bool isLoading = true;

  // ✅ Helper to convert Google Drive link to direct image URL
  String? getDirectDriveImageUrl(String? driveLink) {
    if (driveLink == null || driveLink.isEmpty) return null;

    final regExp = RegExp(r'd/([a-zA-Z0-9_-]+)');
    final match = regExp.firstMatch(driveLink);
    if (match != null && match.groupCount > 0) {
      final fileId = match.group(1);
      return 'https://drive.google.com/uc?export=view&id=$fileId';
    }

    return driveLink; // fallback to original URL
  }

  Future<void> fetchUserData() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) return;

    try {
      email = currentUser.email;
      profilePicUrl = currentUser.photoURL;

      final docSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (mounted && data != null) {
          String? firestorePic = data['profilePic'];

          setState(() {
            fullName = data['fullName'] ?? 'N/A';
            phone = data['phone'] ?? 'N/A';

            // ✅ Convert if it's a Google Drive link
            if ((profilePicUrl == null || profilePicUrl!.isEmpty) &&
                (firestorePic != null && firestorePic.isNotEmpty)) {
              profilePicUrl = getDirectDriveImageUrl(firestorePic);
            } else if (profilePicUrl != null &&
                profilePicUrl!.contains("drive.google.com")) {
              profilePicUrl = getDirectDriveImageUrl(profilePicUrl);
            }
          });
        }
      } else {
        debugPrint("User document does not exist.");
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Widget buildDetail(String label, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label: ",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: textColor,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 16, color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor =
        Theme.of(context).brightness == Brightness.light
            ? Colors.black
            : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile Page"),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: widget.toggleTheme,
          ),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🔧 Profile Picture and Name (centered)
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundImage:
                                profilePicUrl != null &&
                                        profilePicUrl!.isNotEmpty
                                    ? NetworkImage(profilePicUrl!)
                                    : const AssetImage(
                                          "assets/images/default.jpg",
                                        )
                                        as ImageProvider,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            fullName ?? 'No name',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 🔧 Edit Profile button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Personal Details",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const EditProfilePage(),
                              ),
                            );

                            if (result == true) {
                              // Re-fetch user data after editing
                              fetchUserData();
                            }
                          },
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text("Edit Profile"),
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    buildDetail("Name", fullName ?? 'N/A', textColor),
                    buildDetail("Email", email ?? 'N/A', textColor),
                    buildDetail("Phone", phone ?? 'N/A', textColor),
                  ],
                ),
              ),
    );
  }
}
