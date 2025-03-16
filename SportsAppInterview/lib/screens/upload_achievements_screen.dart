import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../points_notifier.dart'; // Ensure this file defines your PointsNotifier
import '../services/auth_service.dart'; // Import the updated AuthService

class UploadAchievementsScreen extends StatefulWidget {
  const UploadAchievementsScreen({super.key});

  @override
  _UploadAchievementsScreenState createState() => _UploadAchievementsScreenState();
}

class _UploadAchievementsScreenState extends State<UploadAchievementsScreen> {
  File? _image;
  bool _isUploading = false;
  final TextEditingController _achievementTitleController = TextEditingController();
  final TextEditingController _achievementDescriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _achievementTitleController.dispose();
    _achievementDescriptionController.dispose();
    super.dispose();
  }

  // Select image from gallery or camera
  Future pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 80, // Compress image for faster uploads
    );

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  // Show image source selection dialog
  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Select Image Source",
                  style: GoogleFonts.roboto(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildImageSourceOption(
                      icon: Icons.photo_library,
                      title: "Gallery",
                      onTap: () {
                        Navigator.pop(context);
                        pickImage(ImageSource.gallery);
                      },
                    ),
                    _buildImageSourceOption(
                      icon: Icons.camera_alt,
                      title: "Camera",
                      onTap: () {
                        Navigator.pop(context);
                        pickImage(ImageSource.camera);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: Colors.blue.shade800),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.roboto(fontSize: 16),
          ),
        ],
      ),
    );
  }

  // Upload achievement image via backend and update points via Provider
  Future<void> saveAchievementLocally() async {
    if (_image == null) {
      Fluttertoast.showToast(msg: "Please select an image first");
      return;
    }

    if (!_formKey.currentState!.validate()) {
      Fluttertoast.showToast(msg: "Please fill all required fields");
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // Upload the image to the backend via the AuthService API
      final authService = AuthService();
      final response = await authService.uploadAchievementImage(_image!.path);

      if (response['success'] == true) {
        // Retrieve the S3 URL returned by the backend
        final String imageUrl = response['data']['url'];

        // Create achievement object with backend image URL
        final achievement = {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'title': _achievementTitleController.text,
          'description': _achievementDescriptionController.text,
          'imageUrl': imageUrl,
          'createdAt': DateTime.now().toIso8601String(),
          'points': 5, // Default points for an achievement
        };

        // Save achievement to SharedPreferences (for offline support or future use)
        final prefs = await SharedPreferences.getInstance();
        List<String> achievementsJson = prefs.getStringList('achievements') ?? [];
        achievementsJson.add(jsonEncode(achievement));
        await prefs.setStringList('achievements', achievementsJson);

        // Update points via Provider (adding 100 points for this activity)
        Provider.of<PointsNotifier>(context, listen: false).addPoints(100);

        // Show success dialog with updated messaging
        _showSuccessDialog();

        // Reset form fields
        setState(() {
          _image = null;
          _achievementTitleController.clear();
          _achievementDescriptionController.clear();
        });
      } else {
        Fluttertoast.showToast(msg: response['message'] ?? "Achievement upload failed");
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error uploading achievement: ${e.toString()}",
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.red,
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 30),
              const SizedBox(width: 10),
              Text("Success!", style: GoogleFonts.roboto(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Your achievement has been uploaded successfully!",
                style: GoogleFonts.roboto(fontSize: 16),
              ),
              const SizedBox(height: 10),
              Text(
                "You've earned 100 points for this activity.",
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Your achievement image is now stored securely in the cloud.",
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "Share Your Achievement",
                    style: GoogleFonts.lobster(
                      fontSize: 28,
                      color: Colors.blueAccent,
                    ),
                  ),
                  Text(
                    "Upload an image of your sports achievement to earn points!",
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Image preview or placeholder
                  GestureDetector(
                    onTap: _showImageSourceDialog,
                    child: Container(
                      width: double.infinity,
                      height: 250,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.grey[300]!,
                          width: 2,
                        ),
                      ),
                      child: _image == null
                          ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate,
                            size: 80,
                            color: Colors.blue[300],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Tap to add an image",
                            style: GoogleFonts.roboto(
                              fontSize: 16,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      )
                          : ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          _image!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                    ),
                  ),
                  if (_image != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _showImageSourceDialog,
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text("Change Image"),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  // Achievement title
                  TextFormField(
                    controller: _achievementTitleController,
                    decoration: InputDecoration(
                      labelText: "Achievement Title",
                      hintText: "E.g., Marathon Completion, Tournament Win",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.emoji_events),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Please enter a title";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  // Achievement description
                  TextFormField(
                    controller: _achievementDescriptionController,
                    decoration: InputDecoration(
                      labelText: "Description",
                      hintText: "Tell us about your achievement...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.description),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Please enter a description";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 30),
                  // Upload button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                      ),
                      onPressed: _isUploading ? null : saveAchievementLocally,
                      child: _isUploading
                          ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "Uploading...",
                            style: GoogleFonts.roboto(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                          : Text(
                        "Submit Achievement",
                        style: GoogleFonts.roboto(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      "Your achievement image is uploaded to the cloud for secure storage.",
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
