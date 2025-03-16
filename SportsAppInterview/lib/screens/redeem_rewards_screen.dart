import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../points_notifier.dart';
import '../services/auth_service.dart';

class RedeemRewardsScreen extends StatefulWidget {
  const RedeemRewardsScreen({super.key});

  @override
  State<RedeemRewardsScreen> createState() => _RedeemRewardsScreenState();
}

class _RedeemRewardsScreenState extends State<RedeemRewardsScreen> with SingleTickerProviderStateMixin {
  final List<Map<String, dynamic>> rewards = [
    {
      'name': 'Sports T-shirt',
      'icon': Icons.checkroom,
      'color': Colors.blue,
      'description': 'High-quality sports t-shirt with team logo',
      'points': 500,
    },
    {
      'name': 'Event Ticket',
      'icon': Icons.confirmation_number,
      'color': Colors.green,
      'description': 'Premium ticket to the upcoming championship game',
      'points': 20,
    },
    {
      'name': 'Personalized Trophy',
      'icon': Icons.emoji_events,
      'color': Colors.amber,
      'description': 'Custom engraved trophy with your name',
      'points': 1000,
    },
  ];

  final AuthService _authService = AuthService();
  late TabController _tabController;
  List<Map<String, dynamic>> _redemptionRequests = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchRedemptionRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchRedemptionRequests() async {
    setState(() {
      _isLoading = true;
    });

    final response = await _authService.fetchRedemptionRequests();

    if (response['success']) {
      setState(() {
        _redemptionRequests = List<Map<String, dynamic>>.from(response['data']['requests']);
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message']),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentPoints = Provider.of<PointsNotifier>(context).points;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Redeem Rewards',
          style: GoogleFonts.lobster(
            fontSize: 26,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.lightGreenAccent,
          unselectedLabelColor: Colors.lightGreenAccent,
          tabs: const [
            Tab(
              icon: Icon(Icons.redeem),
              text: 'Available Rewards',
            ),
            Tab(
              icon: Icon(Icons.history),
              text: 'Redemption History',
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blueAccent, Colors.blue.shade50],
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildAvailableRewardsTab(currentPoints),
            _buildRedemptionHistoryTab(),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton(
        onPressed: _fetchRedemptionRequests,
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.refresh),
      )
          : null,
    );
  }

  Widget _buildAvailableRewardsTab(int currentPoints) {
    return Column(
      children: [
        // Points display at the top
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.stars_rounded,
                color: Colors.amber,
                size: 40,
              ),
              const SizedBox(width: 12),
              Text(
                'Your Points: $currentPoints',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
        ),
        // Rewards list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rewards.length,
            itemBuilder: (context, index) {
              final reward = rewards[index];
              final int rewardPoints = reward['points'] as int;
              final bool hasEnoughPoints = currentPoints >= rewardPoints;
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
                margin: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: reward['color'].withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: reward['color'].withOpacity(0.1),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Icon(
                          reward['icon'],
                          size: 60,
                          color: reward['color'],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reward['name'],
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: hasEnoughPoints
                                    ? reward['color'].withOpacity(0.2)
                                    : Colors.grey.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.stars_rounded,
                                    size: 16,
                                    color: hasEnoughPoints
                                        ? reward['color']
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$rewardPoints points',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: hasEnoughPoints
                                          ? reward['color']
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              reward['description'],
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                backgroundColor: hasEnoughPoints
                                    ? reward['color']
                                    : Colors.grey.shade400,
                                foregroundColor: Colors.white,
                                elevation: hasEnoughPoints ? 3 : 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                minimumSize: const Size(double.infinity, 48),
                              ),
                              onPressed: hasEnoughPoints
                                  ? () => _showRewardRequestDialog(context, reward, rewardPoints)
                                  : () => _showInsufficientPointsDialog(context, reward, rewardPoints),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(hasEnoughPoints ? Icons.redeem : Icons.lock),
                                  const SizedBox(width: 8),
                                  Text(
                                    hasEnoughPoints ? 'Redeem Now' : 'Not Enough Points',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
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
        ),
      ],
    );
  }

  Widget _buildRedemptionHistoryTab() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: Colors.white,
          backgroundColor: Colors.blueAccent.withOpacity(0.3),
        ),
      );
    }

    if (_redemptionRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.history_toggle_off,
              size: 80,
              color: Colors.white70,
            ),
            const SizedBox(height: 16),
            Text(
              'No redemption history yet',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Redeem rewards to see your history here',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _tabController.animateTo(0);
              },
              icon: const Icon(Icons.redeem),
              label: Text(
                'Browse Rewards',
                style: GoogleFonts.poppins(),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                backgroundColor: Colors.white,
                foregroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _redemptionRequests.length,
      itemBuilder: (context, index) {
        final request = _redemptionRequests[index];
        final String status = request['status'];

        // Safely parse the date with error handling
        DateTime? requestDate;
        try {
          requestDate = DateTime.parse(request['request_date']);
        } catch (e) {
          requestDate = null; // Fallback if date parsing fails
        }
        final String formattedDate = requestDate != null
            ? '${requestDate.day}/${requestDate.month}/${requestDate.year}'
            : 'Invalid Date Format'; // Use fallback date format

        Color statusColor;
        IconData statusIcon;
        String statusText;

        switch (status.toLowerCase()) {
          case 'pending':
            statusColor = Colors.orange;
            statusIcon = Icons.pending;
            statusText = 'Pending Approval';
            break;
          case 'approved':
            statusColor = Colors.green;
            statusIcon = Icons.check_circle;
            statusText = 'Approved';
            break;
          case 'rejected':
            statusColor = Colors.red;
            statusIcon = Icons.cancel;
            statusText = 'Rejected';
            break;
          default:
            statusColor = Colors.grey;
            statusIcon = Icons.info;
            statusText = 'Unknown';
            break;
        }

        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          margin: const EdgeInsets.symmetric(vertical: 12),
          child: ListTile(
            leading: Icon(statusIcon, color: statusColor, size: 40),
            title: Text(
              request['reward_name'] ?? 'Reward',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Requested on $formattedDate\n$statusText',
              style: GoogleFonts.poppins(
                fontSize: 14,
              ),
            ),
          ),
        );
      },
    );
  }

  void _showRewardRequestDialog(BuildContext context, Map<String, dynamic> reward, int rewardPoints) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(reward['icon'], color: reward['color'], size: 16),
            const SizedBox(width: 1),
            Text(
              'Request Redemption',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Do you want to request the ${reward['name']}?',
              style: GoogleFonts.poppins(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '$rewardPoints points will be deducted after admin approval.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: reward['color'],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () async {
              final response = await _authService.requestRewardRedemption(
                  reward['name'], rewardPoints);
              Navigator.of(context).pop();
              if (response['success'] == true) {
                _showSuccessSnackbar(context, reward);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      response['message'] ?? 'Reward request failed. Please try again later.',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text(
              'Confirm',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        actionsPadding: const EdgeInsets.all(16),
      ),
    );
  }

  void _showInsufficientPointsDialog(BuildContext context, Map<String, dynamic> reward, int rewardPoints) {
    final pointsNotifier = Provider.of<PointsNotifier>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            Text(
              'Insufficient Points',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You need $rewardPoints points to redeem ${reward['name']}.',
              style: GoogleFonts.poppins(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Current balance: ${pointsNotifier.points} points',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You need ${rewardPoints - pointsNotifier.points} more points.',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              'Close',
              style: GoogleFonts.poppins(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              if (context.mounted) {
                Navigator.of(context).pop(0); // Return value 0 to indicate home tab
              }
            },
            child: Text(
              'Earn More Points',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        actionsPadding: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackbar(BuildContext context, Map<String, dynamic> reward) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${reward['name']} redemption request submitted!'),
                  Text(
                    'Await admin approval for points deduction.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: reward['color'],
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(12),
      ),
    );
  }
}
