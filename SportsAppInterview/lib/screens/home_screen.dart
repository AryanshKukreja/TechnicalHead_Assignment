import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'upload_achievements_screen.dart';
import 'redeem_rewards_screen.dart';
import 'package:provider/provider.dart';
import '../points_notifier.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final AuthService _authService = AuthService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Refresh points from server when screen loads
    _refreshUserData();
  }

  // Refresh user data from server
  Future<void> _refreshUserData() async {
    setState(() {
      _isLoading = true;
    });

    // Get the points notifier
    final pointsNotifier = Provider.of<PointsNotifier>(context, listen: false);

    // Refresh points from server
    await pointsNotifier.refreshDataFromServer();

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // List of widget content for each tab
    final List<Widget> _pageContents = [
      _buildHomeContent(),
      const UploadAchievementsScreen(),
      RedeemRewardsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sports Engagement App',
          style: GoogleFonts.lobster(fontSize: 24, color: Colors.white),
        ),
        backgroundColor: Colors.blueAccent,
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshUserData,
            tooltip: 'Refresh Points',
          ),
          // Logout button on the app bar
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await _authService.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshUserData,
        child: _pageContents[_selectedIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.image),
            label: 'Upload',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.card_giftcard),
            label: 'Rewards',
          ),
        ],
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
      ),
    );
  }

  // Build Home tab content
  Widget _buildHomeContent() {
    // Dynamically fetch current points from our PointsNotifier
    final pointsNotifier = Provider.of<PointsNotifier>(context);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome message and current points display
            Text(
              'Welcome to Sports Engagement App!',
              style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars, color: Colors.amber, size: 30),
                  const SizedBox(width: 10),
                  pointsNotifier.isLoading
                      ? const CircularProgressIndicator()
                      : Text(
                    'Current Points: ${pointsNotifier.points}',
                    style: GoogleFonts.roboto(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'Ways to earn points:',
              style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildActivityCard(
              title: 'Upload Achievements',
              description: 'Share your sports achievements to earn points',
              points: '+100 points',
              icon: Icons.upload_file,
              onTap: () => setState(() => _selectedIndex = 1),
            ),
            _buildActivityCard(
              title: 'Register for Events',
              description: 'Fill out registration forms for institute sports events',
              points: '+20 points',
              icon: Icons.event_available,
              onTap: () {
                Navigator.pushNamed(context, '/event_registration');
              },
            ),
            const SizedBox(height: 30),
            // Display the logged-in user's email using AuthService
            FutureBuilder<String?>(
              future: _authService.getUserEmail(),
              builder: (context, snapshot) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.person, color: Colors.green[800]),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Logged In',
                                style: GoogleFonts.roboto(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                snapshot.data ?? 'Loading...',
                                style: GoogleFonts.roboto(
                                    fontSize: 14, color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Helper: Build an activity card widget
  Widget _buildActivityCard({
    required String title,
    required String description,
    required String points,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.blue[800]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      description,
                      style: GoogleFonts.roboto(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  points,
                  style: GoogleFonts.roboto(fontWeight: FontWeight.bold, color: Colors.green[800]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}