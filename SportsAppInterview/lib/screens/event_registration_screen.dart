import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import '../points_notifier.dart';
import '../services/auth_service.dart';

class EventRegistrationScreen extends StatefulWidget {
  const EventRegistrationScreen({super.key});

  @override
  State<EventRegistrationScreen> createState() => _EventRegistrationScreenState();
}

class _EventRegistrationScreenState extends State<EventRegistrationScreen> {
  List<Map<String, dynamic>> eventForms = [
    {
      'title': 'Inter-Hall Basketball Tournament',
      'url': 'https://docs.google.com/forms/d/e/1FAIpQLSdQhhpa8o0lNGVWPClgNQyXfEfHBvAMEbiVynfW0w2-fEt_6Q/viewform?usp=sharing',
      'completed': false
    },
    {
      'title': 'Annual Sports Meet Registration',
      'url': 'https://docs.google.com/forms/d/e/1FAIpQLSdQhhpa8o0lNGVWPClgNQyXfEfHBvAMEbiVynfW0w2-fEt_6Q/viewform?usp=sharing',
      'completed': false
    },
    {
      'title': 'Swimming Competition Entry',
      'url': 'https://docs.google.com/forms/d/e/1FAIpQLSdQhhpa8o0lNGVWPClgNQyXfEfHBvAMEbiVynfW0w2-fEt_6Q/viewform?usp=sharing',
      'completed': false
    },
    {
      'title': 'Cricket League Tryouts',
      'url': 'https://docs.google.com/forms/d/e/1FAIpQLSdQhhpa8o0lNGVWPClgNQyXfEfHBvAMEbiVynfW0w2-fEt_6Q/viewform?usp=sharing',
      'completed': false
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadCompletedForms();
  }

  Future<void> _loadCompletedForms() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('user_email'); // Ensure user is identified uniquely
    final completedFormsList = prefs.getStringList('completedForms_$userEmail') ?? [];

    setState(() {
      for (var i = 0; i < eventForms.length; i++) {
        eventForms[i]['completed'] = completedFormsList.contains(eventForms[i]['title']);
      }
    });
  }

  // Updated: Call backend endpoint to mark the form as completed
  Future<void> _markFormAsCompleted(int index) async {
    if (eventForms[index]['completed']) return;

    final authService = AuthService();
    final result = await authService.markFormCompleted(eventForms[index]['title']);
    if (result['success']) {
      // Update local storage and provider only if backend call was successful
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('user_email');
      List<String> completedForms = prefs.getStringList('completedForms_$userEmail') ?? [];
      if (!completedForms.contains(eventForms[index]['title'])) {
        completedForms.add(eventForms[index]['title']);
        await prefs.setStringList('completedForms_$userEmail', completedForms);
      }

      // Optionally, update the provider to refresh points and forms count from the backend
      Provider.of<PointsNotifier>(context, listen: false).refreshDataFromServer();

      setState(() {
        eventForms[index]['completed'] = true;
      });

      Fluttertoast.showToast(
        msg: "Congratulations! You earned 20 points!",
        backgroundColor: Colors.green,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
    } else {
      Fluttertoast.showToast(
        msg: result['message'] ?? "Failed to update form completion.",
        backgroundColor: Colors.red,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPoints = Provider.of<PointsNotifier>(context).points;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Event Registration',
          style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: Colors.blue[100], borderRadius: BorderRadius.circular(20)),
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.stars, color: Colors.amber),
                const SizedBox(width: 4),
                Text('$currentPoints pts',
                    style: GoogleFonts.roboto(
                        fontWeight: FontWeight.bold, color: Colors.blue[800])),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Column(
              children: [
                Text('Institute Sports Events',
                    style: GoogleFonts.roboto(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800])),
                const SizedBox(height: 8),
                Text('Register for upcoming events and earn 20 points!',
                    style: GoogleFonts.roboto(
                        fontSize: 16, color: Colors.blue[600]),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: eventForms.length,
              itemBuilder: (context, index) {
                final event = eventForms[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    title: Text(event['title'],
                        style: GoogleFonts.roboto(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: event['completed']
                          ? Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 16),
                          const SizedBox(width: 4),
                          Text('Completed - Points awarded',
                              style: GoogleFonts.roboto(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500)),
                        ],
                      )
                          : Row(
                        children: [
                          const Icon(Icons.add_circle_outline,
                              color: Colors.blue, size: 16),
                          const SizedBox(width: 4),
                          Text('Complete to earn +20 points',
                              style: GoogleFonts.roboto(
                                  color: Colors.blue[700])),
                        ],
                      ),
                    ),
                    trailing: event['completed']
                        ? const Icon(Icons.visibility, color: Colors.blue)
                        : const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      if (!event['completed']) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GoogleFormView(
                              title: event['title'],
                              url: event['url'],
                              onFormComplete: () => _markFormAsCompleted(index),
                              isAlreadyCompleted: event['completed'],
                            ),
                          ),
                        );
                      } else {
                        Fluttertoast.showToast(
                          msg: "You have already completed this form!",
                          backgroundColor: Colors.orange,
                          textColor: Colors.white,
                          toastLength: Toast.LENGTH_SHORT,
                        );
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class GoogleFormView extends StatefulWidget {
  final String title;
  final String url;
  final VoidCallback onFormComplete;
  final bool isAlreadyCompleted;

  const GoogleFormView({
    super.key,
    required this.title,
    required this.url,
    required this.onFormComplete,
    this.isAlreadyCompleted = false,
  });

  @override
  State<GoogleFormView> createState() => _GoogleFormViewState();
}

class _GoogleFormViewState extends State<GoogleFormView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _formSubmitted = false;

  final String _checkSubmitJS = '''
    var formSubmitStatus = false;
    function checkIfFormSubmitted() {
      var thankYouText = document.querySelector('.freebirdFormviewerViewResponseConfirmationMessage');
      var confirmationPage = document.querySelector('.freebirdFormviewerViewResponseConfirmationContainer');
      if (thankYouText || confirmationPage) {
        formSubmitStatus = true;
        return "submitted";
      }
      return "in_progress";
    }
    checkIfFormSubmitted();
  ''';

  @override
  void initState() {
    super.initState();
    _formSubmitted = widget.isAlreadyCompleted;
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            _evaluateForm();
            setState(() {
              _isLoading = false;
            });
          },
          onPageStarted: (String url) {
            if (url.contains('formResponse') && !_formSubmitted) {
              _handleFormSubmission();
            }
          },
          onUrlChange: (UrlChange change) {
            if (change.url?.contains('formResponse') == true && !_formSubmitted) {
              _handleFormSubmission();
            }
          },
        ),
      )
      ..addJavaScriptChannel(
        'FormSubmitChannel',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'submitted' && !_formSubmitted) {
            _handleFormSubmission();
          }
        },
      )
      ..loadRequest(Uri.parse(widget.url));

    Future.delayed(const Duration(seconds: 2), _checkFormStatus);
  }

  void _checkFormStatus() {
    if (!_formSubmitted && mounted) {
      _evaluateForm();
      Future.delayed(const Duration(seconds: 3), _checkFormStatus);
    }
  }

  Future<void> _evaluateForm() async {
    await _controller.runJavaScript(_checkSubmitJS);
  }

  void _handleFormSubmission() {
    if (_formSubmitted) return;
    setState(() {
      _formSubmitted = true;
    });
    widget.onFormComplete();
    _showSuccessDialog();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title,
            style: GoogleFonts.roboto(
                fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              color: Colors.amber[50],
              child: widget.isAlreadyCompleted
                  ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle,
                      color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                      'You\'ve already earned points for this form!',
                      style: GoogleFonts.roboto(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800])),
                ],
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.stars, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text('Complete this form to earn 20 points!',
                      style: GoogleFonts.roboto(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800])),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 30),
              const SizedBox(width: 10),
              Text("Success!",
                  style: GoogleFonts.roboto(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Your registration has been submitted successfully!",
                  style: GoogleFonts.roboto(fontSize: 16)),
              const SizedBox(height: 10),
              Text("You've earned 20 points for this activity.",
                  style: GoogleFonts.roboto(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue)),
            ],
          ),
          actions: [
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
                Future.delayed(const Duration(milliseconds: 500), () {
                  Navigator.of(context).pop(); // Return to event list.
                });
              },
            ),
          ],
        );
      },
    );
  }
}
