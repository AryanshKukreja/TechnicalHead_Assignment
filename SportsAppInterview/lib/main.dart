import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// 1. Import your PointsNotifier from a single file.
import 'points_notifier.dart';

// 2. Import all screens. Avoid re-importing PointsNotifier from any screen.
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/upload_achievements_screen.dart';
import 'screens/redeem_rewards_screen.dart';
import 'screens/event_registration_screen.dart' hide PointsNotifier;

// 3. Import the auth service
import 'services/auth_service.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Create AuthService instance
  final authService = AuthService();

  // Get initial points from SharedPreferences if the user is signed in
  int initialPoints = 0;
  if (await authService.isSignedIn()) {
    initialPoints = await authService.getUserPoints();
  }

  runApp(
    MultiProvider(
      providers: [
        // Provide AuthService throughout the app
        Provider<AuthService>(
          create: (_) => authService,
        ),
        // Provide PointsNotifier globally
        ChangeNotifierProvider<PointsNotifier>(
          create: (_) => PointsNotifier(initialPoints: initialPoints),
        ),
        // Use FutureProvider to asynchronously fetch initial points
        FutureProvider<int>(
          create: (_) async {
            return initialPoints; // Provide initial points fetched from the AuthService
          },
          initialData: 0, // Default value until the future resolves
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sports Engagement App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.blue,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
      home: AuthWrapper(), // No need for const here
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/home': (context) => const HomeScreen(),
        '/log_activity': (context) => const UploadAchievementsScreen(),
        '/earn_points': (context) => const UploadAchievementsScreen(),
        '/redeem_rewards': (context) => const RedeemRewardsScreen(),
        '/event_registration': (context) => const EventRegistrationScreen(),
      },
    );
  }
}

// AuthWrapper checks if user is already logged in and syncs points
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Get AuthService from provider
    final authService = Provider.of<AuthService>(context, listen: false);
    final isSignedIn = await authService.isSignedIn();

    // If user is signed in, sync points with the server
    if (isSignedIn) {
      // Get the PointsNotifier instance
      final pointsNotifier = Provider.of<PointsNotifier>(context, listen: false);

      // Fetch updated user profile to ensure points are in sync
      final profileResult = await authService.fetchUserProfile();
      if (profileResult['success']) {
        // Update points in the PointsNotifier
        final serverPoints = await authService.getUserPoints();
        pointsNotifier.setPoints(serverPoints);
      }
    }

    setState(() {
      _isLoggedIn = isSignedIn;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_isLoggedIn) {
      return const HomeScreen();
    } else {
      return const LoginScreen();
    }
  }
}
