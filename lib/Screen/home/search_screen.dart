// lib/Screen/home/search_screen.dart (COMPLETE UPDATED VERSION)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tapmate/Screen/home/download_progress_screen.dart';
import 'package:tapmate/Screen/home/other_user_profile_screen.dart';
import 'package:tapmate/Screen/home/storage_selection_dialog.dart';
import 'package:tapmate/Screen/services/search_service.dart';
import '../../auth_provider.dart';
import '../../theme_provider.dart';
import 'package:tapmate/Screen/constants/app_colors.dart';

class SearchDiscoverScreen extends StatefulWidget {
  const SearchDiscoverScreen({super.key});

  @override
  State<SearchDiscoverScreen> createState() => _SearchDiscoverScreenState();
}

class _SearchDiscoverScreenState extends State<SearchDiscoverScreen> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final SearchService _searchService = SearchService();

  String _selectedPlatform = "All";
  bool _isSearching = false;
  bool _showResults = false;
  String _activeTab = 'all'; // 'all', 'users', 'videos'

  final List<String> platforms = ["All", "YouTube", "TikTok", "Instagram", "Facebook", "Twitter"];

  // Data lists
  List<Map<String, dynamic>> _searchResults = [];
  List<String> _searchHistory = [];
  List<Map<String, dynamic>> _trendingPosts = [];
  List<Map<String, dynamic>> _categories = [];
  List<String> _trendingSearches = [];

  @override
  bool get wantKeepAlive => true; // Keep state when switching tabs

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isSearching = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Load search history for logged-in users
      if (!authProvider.isGuest) {
        _searchHistory = await _searchService.getSearchHistory();
      }

      // Load trending posts
      _trendingPosts = await _searchService.getTrendingPosts();

      // Load categories
      _categories = await _searchService.getCategories();

      // Load trending searches
      _trendingSearches = await _searchService.getTrendingSearches();

    } catch (e) {
      print('Error loading initial data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _showResults = true;
      _searchResults.clear();
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Save to search history (only for logged-in users)
      if (!authProvider.isGuest) {
        await _searchService.saveSearchHistory(query);
        // Refresh search history
        _searchHistory = await _searchService.getSearchHistory();
      }

      List<Map<String, dynamic>> allResults = [];

      // Search based on active tab
      if (_activeTab == 'all' || _activeTab == 'users') {
        final users = await _searchService.searchUsers(query);
        allResults.addAll(users);
      }

      if (_activeTab == 'all' || _activeTab == 'videos') {
        final posts = await _searchService.searchPosts(
            query,
            platform: _selectedPlatform != 'All' ? _selectedPlatform : null
        );
        allResults.addAll(posts);
      }

      // Sort results: users first, then posts
      allResults.sort((a, b) {
        if (a['type'] == 'user' && b['type'] != 'user') return -1;
        if (a['type'] != 'user' && b['type'] == 'user') return 1;
        return 0;
      });

      setState(() {
        _searchResults = allResults;
      });

    } catch (e) {
      print('Search error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Search failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _showResults = false;
      _searchResults.clear();
      _activeTab = 'all';
    });
  }

  void _clearSearchHistory() async {
    try {
      await _searchService.clearSearchHistory();
      setState(() {
        _searchHistory.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Search history cleared'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error clearing history: $e');
    }
  }

  void _deleteSearchItem(String query) async {
    try {
      await _searchService.deleteSearchItem(query);
      setState(() {
        _searchHistory.remove(query);
      });
    } catch (e) {
      print('Error deleting search item: $e');
    }
  }

  void _downloadContent(Map<String, dynamic> content) {
    showDialog(
      context: context,
      builder: (context) => StorageSelectionDialog(
        platformName: content['platform'] ?? 'Unknown',
        contentId: content['id'],
        contentTitle: content['title'] ?? content['caption'] ?? 'Unknown',
        onDeviceStorageSelected: (path, format, quality) {
          Navigator.pop(context);
          _startDownload(content, path, format, quality, true);
        },
        onAppStorageSelected: (format, quality) {
          Navigator.pop(context);
          _startDownload(content, null, format, quality, false);
        },
      ),
    );
  }

  void _startDownload(Map<String, dynamic> content, String? path, String format, String quality, bool isDeviceStorage) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DownloadProgressScreen(
          platformName: content['platform'] ?? 'Unknown',
          contentTitle: '${content['title'] ?? content['caption']} ($format - $quality)',
          storagePath: path,
          isDeviceStorage: isDeviceStorage,
          fromPlatformScreen: false,
          sourcePlatform: 'search',
        ),
      ),
    );
  }

  void _viewUserProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OtherUserProfileScreen(
          userId: userId,
          userName: '', // Will be loaded from Firestore
          userAvatar: '👤',
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive, BuildContext context, bool isGuest, bool isDarkMode) {
    final isLocked = isGuest && (label == 'Message' || label == 'Profile');

    return GestureDetector(
      onTap: isLocked
          ? () => _showLockedFeatureDialog(label)
          : () {
        if (label == 'Home') {
          Navigator.pushReplacementNamed(context, '/home');
        } else if (label == 'Discover') {
          Navigator.pushReplacementNamed(context, '/search');
        } else if (label == 'Feed') {
          Navigator.pushReplacementNamed(context, '/feed');
        } else if (label == 'Message') {
          Navigator.pushReplacementNamed(context, '/chat');
        } else if (label == 'Profile') {
          Navigator.pushReplacementNamed(context, '/profile');
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            children: [
              Icon(
                icon,
                color: isActive ? AppColors.primary : (isDarkMode ? Colors.grey[600] : Colors.grey),
                size: 24,
              ),
              if (isLocked)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: isDarkMode ? AppColors.textMain : AppColors.lightSurface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock,
                      size: 10,
                      color: Colors.orange,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? AppColors.primary : (isDarkMode ? Colors.grey[600] : Colors.grey),
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isGuest = authProvider.isGuest;
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : AppColors.lightSurface,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.accent, AppColors.secondary, AppColors.primary],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/home',
                                (route) => false,
                          );
                        },
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: AppColors.lightSurface,
                          size: 22,
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            _showResults ? "Search Results" : "Search & Discover",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: AppColors.lightSurface,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          if (_searchController.text.isNotEmpty) {
                            _performSearch(_searchController.text);
                          }
                        },
                        icon: const Icon(
                          Icons.search,
                          color: AppColors.lightSurface,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Search Tabs (only when showing results)
            if (_showResults)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    _buildSearchTab('All', 'all'),
                    const SizedBox(width: 10),
                    _buildSearchTab('Users', 'users'),
                    const SizedBox(width: 10),
                    _buildSearchTab('Videos', 'videos'),
                  ],
                ),
              ),

            // Platform Filter
            if (!_showResults || _activeTab != 'users')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                height: 60,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: platforms.map((platform) {
                    bool isSelected = _selectedPlatform == platform;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        label: Text(platform),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedPlatform = platform;
                          });
                          if (_searchController.text.isNotEmpty) {
                            _performSearch(_searchController.text);
                          }
                        },
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.lightSurface : (isDarkMode ? AppColors.lightSurface : AppColors.accent),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        backgroundColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[100],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? Colors.transparent : Colors.grey.withOpacity(0.3),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            // Body Content
            Expanded(
              child: _showResults
                  ? _buildSearchResults(isGuest, isDarkMode)
                  : _buildDiscoverySection(isGuest, isDarkMode),
            ),

            // Bottom Navigation
            SafeArea(
              top: false,
              child: Container(
                height: 70,
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF1E1E1E) : AppColors.lightSurface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(Icons.home_rounded, 'Home', false, context, isGuest, isDarkMode),
                    _buildNavItem(Icons.explore_rounded, 'Discover', true, context, isGuest, isDarkMode),
                    _buildNavItem(Icons.feed_rounded, 'Feed', false, context, isGuest, isDarkMode),
                    _buildNavItem(Icons.message_rounded, 'Message', false, context, isGuest, isDarkMode),
                    _buildNavItem(Icons.person_rounded, 'Profile', false, context, isGuest, isDarkMode),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchTab(String label, String value) {
    bool isActive = _activeTab == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeTab = value;
          });
          if (_searchController.text.isNotEmpty) {
            _performSearch(_searchController.text);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? AppColors.primary : Colors.grey,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(bool isGuest, bool isDarkMode) {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF2C2C2C) : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(isDarkMode ? 0.3 : 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Search users, videos...",
                      hintStyle: TextStyle(
                        color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                      ),
                      border: InputBorder.none,
                    ),
                    style: TextStyle(
                      color: isDarkMode ? AppColors.lightSurface : AppColors.textMain,
                    ),
                    onSubmitted: (value) => _performSearch(value),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.clear, size: 20, color: AppColors.primary),
                    onPressed: _clearSearch,
                  ),
              ],
            ),
          ),
        ),

        // Results Count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _searchController.text.isNotEmpty
                    ? '${_searchResults.length} results found'
                    : '',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              if (_selectedPlatform != "All" && _activeTab != 'users')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _selectedPlatform,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Results List
        Expanded(
          child: _isSearching
              ? Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _searchResults.isEmpty
              ? _buildEmptyState(isDarkMode)
              : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final item = _searchResults[index];
              if (item['type'] == 'user') {
                return _buildUserResultCard(item, isGuest, isDarkMode);
              } else {
                return _buildVideoResultCard(item, isGuest, isDarkMode, index);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDiscoverySection(bool isGuest, bool isDarkMode) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF2C2C2C) : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(isDarkMode ? 0.3 : 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: "Search users, videos...",
                        hintStyle: TextStyle(
                          color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                        ),
                        border: InputBorder.none,
                      ),
                      style: TextStyle(
                        color: isDarkMode ? AppColors.lightSurface : AppColors.textMain,
                      ),
                      onSubmitted: (value) => _performSearch(value),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.clear, size: 20, color: AppColors.primary),
                      onPressed: _clearSearch,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Recent Searches (for logged-in users)
            if (!isGuest && _searchHistory.isNotEmpty) ...[
              _buildRecentSearchesSection(isDarkMode),
              const SizedBox(height: 20),
            ],

            // Trending Videos
            _buildTrendingSection(isGuest, isDarkMode),
            const SizedBox(height: 20),

            // Trending Searches
            _buildTrendingSearchesSection(isDarkMode),
            const SizedBox(height: 20),

            // Browse Categories
            _buildCategoriesSection(isDarkMode),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: isDarkMode ? Colors.grey[600] : Colors.grey[300],
          ),
          const SizedBox(height: 20),
          Text(
            'No results found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? AppColors.lightSurface : AppColors.accent,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Try a different search term',
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingSection(bool isGuest, bool isDarkMode) {
    if (_trendingPosts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2C) : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(isDarkMode ? 0.3 : 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                "Trending Videos",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode ? AppColors.lightSurface : AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 280,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _trendingPosts.length,
              itemBuilder: (context, index) {
                return _buildTrendingVideoCard(_trendingPosts[index], isGuest, isDarkMode);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSearchesSection(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2C) : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(isDarkMode ? 0.3 : 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Recent Searches",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? AppColors.lightSurface : AppColors.accent,
                ),
              ),
              if (_searchHistory.isNotEmpty)
                GestureDetector(
                  onTap: _clearSearchHistory,
                  child: Text(
                    "Clear",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ..._searchHistory.take(5).map((search) => _buildRecentSearchItem(search, isDarkMode)),
        ],
      ),
    );
  }

  Widget _buildRecentSearchItem(String search, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(isDarkMode ? 0.2 : 0.1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _searchController.text = search;
                });
                _performSearch(search);
              },
              child: Row(
                children: [
                  Icon(Icons.history, size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      search,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? AppColors.lightSurface : AppColors.accent,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _deleteSearchItem(search),
            child: Icon(Icons.close, size: 18, color: isDarkMode ? Colors.grey[400] : Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingSearchesSection(bool isDarkMode) {
    if (_trendingSearches.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2C) : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(isDarkMode ? 0.3 : 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                "Trending Searches",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode ? AppColors.lightSurface : AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _trendingSearches.map((trend) {
              return _buildTrendingChip(trend, isDarkMode);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection(bool isDarkMode) {
    if (_categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2C) : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(isDarkMode ? 0.3 : 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Browse Categories",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDarkMode ? AppColors.lightSurface : AppColors.accent,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _categories.map((category) {
                return _CategoryCard(
                  category['icon'] ?? Icons.category,
                  category['name'] ?? 'Category',
                  category['count'] ?? '0',
                  isDarkMode,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserResultCard(Map<String, dynamic> user, bool isGuest, bool isDarkMode) {
    return GestureDetector(
      onTap: () => _viewUserProfile(user['id']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2C2C2C) : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(isDarkMode ? 0.3 : 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: AppColors.accent.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            // Profile Picture
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.primary.withOpacity(0.2),
              backgroundImage: user['profilePic'] != null && user['profilePic'].toString().isNotEmpty
                  ? NetworkImage(user['profilePic'])
                  : null,
              child: user['profilePic'] == null || user['profilePic'].toString().isEmpty
                  ? Text(
                user['name']?.toString().substring(0, 1).toUpperCase() ?? '?',
                style: const TextStyle(fontSize: 24, color: AppColors.primary),
              )
                  : null,
            ),
            const SizedBox(width: 16),

            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['name'] ?? 'Unknown',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? AppColors.lightSurface : AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${user['username'] ?? 'username'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.primary,
                    ),
                  ),
                  if (user['bio'] != null && user['bio'].toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      user['bio'],
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Follow/Message buttons could be added here
            if (user['isPrivate'] == true)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.lock, size: 16, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoResultCard(Map<String, dynamic> video, bool isGuest, bool isDarkMode, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2C) : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(isDarkMode ? 0.3 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppColors.accent.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          Stack(
            children: [
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.3),
                      AppColors.primary.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Image.network(
                  video['thumbnailUrl'] ?? video['thumbnail_url'] ?? 'https://picsum.photos/400/400',
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.videocam, size: 40, color: AppColors.primary),
                          const SizedBox(height: 10),
                          Text(
                            'Video Preview',
                            style: TextStyle(color: AppColors.primary),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (video['duration'] != null)
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.textMain.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      video['duration'],
                      style: const TextStyle(
                        color: AppColors.lightSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getPlatformColor(video['platform'] ?? 'YouTube'),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    video['platform'] ?? 'Unknown',
                    style: const TextStyle(
                      color: AppColors.lightSurface,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Video Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video['caption'] ?? video['title'] ?? 'Untitled',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? AppColors.lightSurface : AppColors.accent,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _viewUserProfile(video['userId']),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.primary.withOpacity(0.2),
                        backgroundImage: video['user_profile_pic'] != null && video['user_profile_pic'].toString().isNotEmpty
                            ? NetworkImage(video['user_profile_pic'])
                            : null,
                        child: video['user_profile_pic'] == null || video['user_profile_pic'].toString().isEmpty
                            ? Text(
                          video['user_name']?.toString().substring(0, 1).toUpperCase() ?? '?',
                          style: const TextStyle(fontSize: 12, color: AppColors.primary),
                        )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        video['user_name'] ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.favorite, size: 14, color: Colors.red),
                    const SizedBox(width: 4),
                    Text(
                      video['likes']?.toString() ?? '0',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.comment, size: 14, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      video['comments']?.toString() ?? '0',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Download Button
                if (video['canDownload'] == true && !isGuest)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _downloadContent(video),
                      icon: const Icon(Icons.download_rounded, size: 20),
                      label: const Text(
                        "Download",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.lightSurface,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingVideoCard(Map<String, dynamic> video, bool isGuest, bool isDarkMode) {
    return GestureDetector(
      onTap: () {
        // Navigate to video detail
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 15),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2C2C2C) : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(isDarkMode ? 0.3 : 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: AppColors.accent.withOpacity(0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.3),
                    AppColors.primary.withOpacity(0.1),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Image.network(
                video['thumbnailUrl'] ?? video['thumbnail_url'] ?? 'https://picsum.photos/300/200',
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Icon(Icons.videocam, size: 40, color: AppColors.primary),
                  );
                },
              ),
            ),

            // Video Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video['caption'] ?? video['title'] ?? 'Untitled',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? AppColors.lightSurface : AppColors.accent,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '@${video['user_name'] ?? 'Unknown'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.favorite, size: 12, color: Colors.red),
                          const SizedBox(width: 2),
                          Text(
                            video['likes']?.toString() ?? '0',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "Trending",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.orange[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingChip(String trend, bool isDarkMode) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _searchController.text = trend;
        });
        _performSearch(trend);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.primary, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(isDarkMode ? 0.2 : 0.1),
              blurRadius: 3,
            ),
          ],
        ),
        child: Text(
          trend,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 13,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  void _showGuestDownloadDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign In Required'),
        content: const Text('Please sign in to download videos. Guest users can only browse content.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text(
              'Sign In',
              style: TextStyle(color: AppColors.lightSurface),
            ),
          ),
        ],
      ),
    );
  }

  void _showLockedFeatureDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$feature Locked'),
        content: Text('Sign up to access $feature and all premium features.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Sign Up', style: TextStyle(color: AppColors.lightSurface)),
          ),
        ],
      ),
    );
  }

  Color _getPlatformColor(String platform) {
    switch (platform.toLowerCase()) {
      case 'youtube':
        return const Color(0xFFFF0000);
      case 'tiktok':
        return const Color(0xFF000000);
      case 'instagram':
        return const Color(0xFFE4405F);
      case 'facebook':
        return const Color(0xFF1877F2);
      case 'twitter':
        return const Color(0xFF1DA1F2);
      default:
        return AppColors.primary;
    }
  }
}

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String count;
  final bool isDarkMode;

  const _CategoryCard(this.icon, this.title, this.count, this.isDarkMode);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(isDarkMode ? 0.3 : 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 28,
            color: AppColors.primary,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? AppColors.lightSurface : AppColors.accent,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            "$count videos",
            style: TextStyle(
              fontSize: 11,
              color: AppColors.primary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}