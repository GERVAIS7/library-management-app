import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/auth_service.dart';
import '../services/ad_service.dart';
import 'book_list_screen.dart';
import 'my_loans_screen.dart';
import 'authors_screen.dart';
import 'book_form_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;
  final _authService = AuthService();
  final _adService = AdService();

  BannerAd? _bannerAd;
  bool _bannerFailed = false;

  // Tabs are built dynamically in build() so BookListScreen can receive
  // a callback to switch tabs after a successful borrow.

  @override
  void initState() {
    super.initState();
    // Ads only run on Android/iOS. Skip entirely on web so we can still
    // test Auth/Firestore/Storage flows in Chrome during development.
    if (!kIsWeb) {
      _loadBanner();
      _adService.loadInterstitial(); // preload for later (e.g. after borrowing)
    }
  }

  void _loadBanner() {
    _bannerAd = _adService.createBannerAd(
      onFailed: () {
        // Ad failed — hide it gracefully, app keeps working.
        if (mounted) setState(() => _bannerFailed = true);
      },
    );
    // BannerAd.load() triggers async load; give the widget a rebuild once ready.
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _adService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['Library', 'My Loans', 'Authors'];

    final tabs = [
      BookListScreen(onBorrowedNavigateToLoans: () => setState(() => _currentTab = 1)),
      const MyLoansScreen(),
      const AuthorsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentTab]),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: 'My Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => _authService.signOut(),
          ),
        ],
      ),
      body: tabs[_currentTab],
      floatingActionButton: _currentTab == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BookFormScreen()),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Banner ad pinned above the nav bar. Never rendered on web,
          // and collapses to zero height if it failed to load on device.
          if (!kIsWeb && !_bannerFailed && _bannerAd != null)
            SizedBox(
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
          NavigationBar(
            selectedIndex: _currentTab,
            onDestinationSelected: (i) => setState(() => _currentTab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.menu_book), label: 'Library'),
              NavigationDestination(icon: Icon(Icons.bookmark), label: 'My Loans'),
              NavigationDestination(icon: Icon(Icons.person), label: 'Authors'),
            ],
          ),
        ],
      ),
    );
  }
}
