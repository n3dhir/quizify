import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:quizify/providers/auth_provider.dart' as quizify_auth;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:share_plus/share_plus.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  bool _checkingOnboarding = true;
  late TabController _tabController;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _publicSearchQuery = '';

  // For handling cloning public quizzes
  bool _isCloning = false;
  String? _cloningQuizId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkOnboardingStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkOnboardingStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

    final hasSeenOnboarding = userDoc.data()?['has_seen_onboarding'] ?? false;

    if (!hasSeenOnboarding) {
      if (mounted) context.go('/app/creator/onboarding');
    } else {
      setState(() {
        _checkingOnboarding = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingOnboarding) {
      // prevent flashing home screen
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    final authProvider = Provider.of<quizify_auth.AuthProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                floating: true,
                pinned: true,
                snap: false,
                expandedHeight: 80.0,
                backgroundColor: colorScheme.surface,
                elevation: 0,
                title:
                    !_isSearching
                        ? Text(
                          'My Quizzes',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                        : null,
                actions: [
                  IconButton(
                    icon: Icon(
                      _isSearching ? Icons.close : Icons.search,
                      color: colorScheme.onSurface,
                    ),
                    onPressed: () {
                      setState(() {
                        _isSearching = !_isSearching;
                        if (!_isSearching) {
                          _searchController.clear();
                          _searchQuery = '';
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                ],
                flexibleSpace:
                    _isSearching
                        ? FlexibleSpaceBar(
                          titlePadding: EdgeInsets.only(
                            left: 16,
                            right: 72,
                            bottom: 16,
                          ),
                          title: Animate(
                            effects: [FadeEffect(duration: 300.ms)],
                            child: TextField(
                              controller: _searchController,
                              autofocus: true,
                              decoration: InputDecoration(
                                hintText: 'Search quizzes...',
                                hintStyle: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurface.withOpacity(0.6),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 8.0,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: colorScheme.surfaceVariant
                                    .withOpacity(0.5),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: colorScheme.primary,
                                ),
                              ),
                              style: textTheme.bodySmall,
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                });
                              },
                            ),
                          ),
                        )
                        : null,
              ),
              SliverPersistentHeader(
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    controller: _tabController,
                    labelColor: colorScheme.primary,
                    unselectedLabelColor: colorScheme.onSurface.withOpacity(
                      0.6,
                    ),
                    indicatorColor: colorScheme.primary,
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: [
                      Tab(text: 'My Quizzes'),
                      Tab(text: 'Public Quizzes'),
                    ],
                  ),
                ),
                pinned: true,
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildQuizzesList(context, colorScheme, textTheme, isMobile),
              _buildPublicQuizzesList(
                context,
                colorScheme,
                textTheme,
                isMobile,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.go('/app/creator/add');
        },
        label: const Text('Create Quiz'),
        icon: const Icon(Icons.add),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ).animate().slide(
        duration: 400.ms,
        begin: const Offset(0, 1),
        end: const Offset(0, 0),
      ),
    );
  }

  Widget _buildPublicQuizzesList(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isMobile,
  ) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      return Center(child: Text('Please log in to view public quizzes'));
    }

    return StreamBuilder<QuerySnapshot>(
      // final quizzes = snapshot.data!.docs.where((doc) => doc['creator_id'] != currentUserId);
      stream:
          FirebaseFirestore.instance
              .collection('quizzes')
              .where('isPublic', isEqualTo: true)
              // .where('creator_id', isNotEqualTo: currentUserId) // Only show other people's quizzes
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                const SizedBox(height: 16),
                Text('Something went wrong', style: textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'We couldn\'t load public quizzes',
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingShimmer(isMobile);
        }
        final quizzes =
            snapshot.data!.docs
                .where((doc) => doc['creator_id'] != currentUserId)
                .toList() ??
            [];

        // final quizzes = snapshot.data?.docs ?? [];

        if (quizzes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.public_off,
                  size: 70,
                  color: colorScheme.primary.withOpacity(0.5),
                ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                const SizedBox(height: 24),
                Text(
                  'No public quizzes available',
                  style: textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Check back later or create your own quiz',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: MasonryGridView.count(
            crossAxisCount: isMobile ? 2 : 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            itemCount: quizzes.length,
            itemBuilder: (context, index) {
              final quizDoc = quizzes[index];
              final quiz = quizDoc.data() as Map<String, dynamic>;
              final questions = quiz['questions'] as List<dynamic>? ?? [];

              // Try to find the first image in any question
              String? imageUrl;
              for (final question in questions) {
                if (question is Map<String, dynamic> &&
                    question['imageUrl'] != null &&
                    question['imageUrl'].toString().isNotEmpty) {
                  imageUrl = question['imageUrl'].toString();
                  break;
                }
              }

              imageUrl ??=
                  'https://via.placeholder.com/400x200.png?text=Public+Quiz';
              final creatorId = quiz['creator_id'] as String?;
              final aspectRatio = 0.8 + (index % 3) * 0.1;

              return AnimatedOpacity(
                    duration: Duration(milliseconds: 500),
                    opacity:
                        _isCloning && _cloningQuizId == quizDoc.id ? 0.7 : 1.0,
                    child: Card(
                      elevation: 2,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: InkWell(
                        onTap: () {
                          // View public quiz details
                          context.go("/app/creator/view/${quizDoc.id}");
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AspectRatio(
                              aspectRatio: aspectRatio,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    placeholder:
                                        (context, url) => Shimmer.fromColors(
                                          baseColor: colorScheme.surfaceVariant,
                                          highlightColor: colorScheme.surface,
                                          child: Container(
                                            color: colorScheme.surfaceVariant,
                                          ),
                                        ),
                                    errorWidget:
                                        (context, url, error) => Container(
                                          color: colorScheme.surfaceVariant,
                                          child: Icon(
                                            Icons.quiz,
                                            size: 50,
                                            color: colorScheme.onSurfaceVariant
                                                .withOpacity(0.5),
                                          ),
                                        ),
                                  ),
                                  // Gradient overlay
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    height: 60,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withOpacity(0.7),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Stats overlay
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.tertiaryContainer
                                            .withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.question_mark,
                                            size: 16,
                                            color:
                                                colorScheme.onTertiaryContainer,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${questions.length}',
                                            style: TextStyle(
                                              color:
                                                  colorScheme
                                                      .onTertiaryContainer,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    quiz['title'] ?? 'Untitled Quiz',
                                    style: textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  StreamBuilder<DocumentSnapshot>(
                                    stream:
                                        FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(creatorId)
                                            .snapshots(),
                                    builder: (context, userSnapshot) {
                                      // final username = userSnapshot.hasData && userSnapshot.data!.exists
                                      //     ? userSnapshot.data!.get('username') ?? 'Unknown User'
                                      //     : 'Unknown User';
                                      return Row(
                                        // children: [
                                        //   Icon(
                                        //     Icons.person,
                                        //     size: 14,
                                        //     color: colorScheme.onSurfaceVariant,
                                        //   ),
                                        //   SizedBox(width: 4),
                                        //   Expanded(
                                        //     child: Text(
                                        //         '',
                                        //       style: textTheme.bodySmall
                                        //           ?.copyWith(
                                        //             color:
                                        //                 colorScheme
                                        //                     .onSurfaceVariant,
                                        //           ),
                                        //       maxLines: 1,
                                        //       overflow: TextOverflow.ellipsis,
                                        //     ),
                                        //   ),
                                        // ],
                                      
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed:
                                          _isCloning
                                              ? null
                                              : () => _cloneQuiz(
                                                context,
                                                quizDoc.id,
                                                quiz,
                                              ),
                                      icon:
                                          _isCloning &&
                                                  _cloningQuizId == quizDoc.id
                                              ? SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color:
                                                          colorScheme.onPrimary,
                                                    ),
                                              )
                                              : Icon(Icons.file_copy, size: 16),
                                      label: Text(
                                        _isCloning &&
                                                _cloningQuizId == quizDoc.id
                                            ? 'Cloning...'
                                            : 'Clone Quiz',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: colorScheme.primary,
                                        foregroundColor: colorScheme.onPrimary,
                                        padding: EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        textStyle: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .animate(delay: (50 * index).ms)
                  .fadeIn(duration: 300.ms)
                  .moveY(
                    begin: 20,
                    end: 0,
                    duration: 300.ms,
                    curve: Curves.easeOutQuad,
                  );
            },
          ),
        );
      },
    );
  }

  Future<void> _cloneQuiz(
    BuildContext context,
    String quizId,
    Map<String, dynamic> quiz,
  ) async {
    try {
      setState(() {
        _isCloning = true;
        _cloningQuizId = quizId;
      });

      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      final clonedQuiz = Map<String, dynamic>.from(quiz);

      // Update quiz metadata
      clonedQuiz['creator_id'] = currentUserId;
      clonedQuiz['title'] = '${clonedQuiz['title']} (Clone)';
      clonedQuiz['isPublic'] = false;
      clonedQuiz['createdAt'] = Timestamp.now();

      // Add to the user's quizzes
      final docRef = await FirebaseFirestore.instance
          .collection('quizzes')
          .add(clonedQuiz);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Quiz cloned successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Switch to My Quizzes tab
      _tabController.animateTo(0);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clone quiz: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCloning = false;
          _cloningQuizId = null;
        });
      }
    }
  }

  Widget _buildQuizzesList(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isMobile,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('quizzes')
              .where(
                'creator_id',
                isEqualTo: FirebaseAuth.instance.currentUser?.uid,
              )
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                const SizedBox(height: 16),
                Text('Something went wrong', style: textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'We couldn\'t load your quizzes',
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingShimmer(isMobile);
        }

        final quizzes = snapshot.data?.docs ?? [];

        // Filter quizzes if search is active
        final filteredQuizzes =
            _searchQuery.isEmpty
                ? quizzes
                : quizzes.where((quiz) {
                  final data = quiz.data() as Map<String, dynamic>;
                  final title = (data['title'] ?? '').toString().toLowerCase();
                  return title.contains(_searchQuery.toLowerCase());
                }).toList();

        if (filteredQuizzes.isEmpty) {
          return _buildEmptyState(colorScheme, textTheme);
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: RefreshIndicator(
            onRefresh: () async {
              // Refresh logic (if needed)
              await Future.delayed(const Duration(milliseconds: 1500));
            },
            color: colorScheme.primary,
            child: MasonryGridView.count(
              crossAxisCount: isMobile ? 2 : 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              itemCount: filteredQuizzes.length,
              itemBuilder: (context, index) {
                final quizDoc = filteredQuizzes[index];
                final quiz = quizDoc.data() as Map<String, dynamic>;
                final questions = quiz['questions'] as List<dynamic>? ?? [];

                // Try to find the first image in any question
                String? imageUrl;
                for (final question in questions) {
                  if (question is Map<String, dynamic> &&
                      question['imageUrl'] != null &&
                      question['imageUrl'].toString().isNotEmpty) {
                    imageUrl = question['imageUrl'].toString();
                    break;
                  }
                }

                // Fallback image if no question has an image
                imageUrl ??=
                    'https://via.placeholder.com/400x200.png?text=Quiz+Image';

                // Randomize card height a bit to make the grid more interesting
                final aspectRatio = 0.8 + (index % 3) * 0.1;

                return AnimatedOpacity(
                      duration: Duration(milliseconds: 500),
                      opacity: 1.0,
                      child: _buildQuizCard(
                        context,
                        colorScheme,
                        textTheme,
                        quizDoc.id,
                        quiz,
                        imageUrl,
                        questions.length,
                        aspectRatio,
                      ),
                    )
                    .animate(delay: (50 * index).ms)
                    .fadeIn(duration: 300.ms)
                    .moveY(
                      begin: 20,
                      end: 0,
                      duration: 300.ms,
                      curve: Curves.easeOutQuad,
                    );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuizCard(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    String quizId,
    Map<String, dynamic> quiz,
    String imageUrl,
    int questionCount,
    double aspectRatio,
  ) {
    final creationDate = (quiz['createdAt'] as Timestamp?)?.toDate();
    final formattedDate =
        creationDate != null
            ? '${creationDate.day}/${creationDate.month}/${creationDate.year}'
            : 'Unknown date';

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          context.go("/app/creator/details/$quizId");
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: aspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'quiz-image-$quizId',
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder:
                          (context, url) => Shimmer.fromColors(
                            baseColor: colorScheme.surfaceVariant,
                            highlightColor: colorScheme.surface,
                            child: Container(color: colorScheme.surfaceVariant),
                          ),
                      errorWidget:
                          (context, url, error) => Container(
                            color: colorScheme.surfaceVariant,
                            child: Icon(
                              Icons.quiz,
                              size: 50,
                              color: colorScheme.onSurfaceVariant.withOpacity(
                                0.5,
                              ),
                            ),
                          ),
                    ),
                  ),
                  // Gradient overlay at the bottom for better text visibility
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 60,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Stats overlay
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.question_mark,
                            size: 16,
                            color: colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$questionCount',
                            style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quiz['title'] ?? 'Untitled Quiz',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(width: 4),
                      Text(
                        formattedDate,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildChip(
                        quiz['isPublic'] == true ? 'Public' : 'Private',
                        quiz['isPublic'] == true
                            ? Colors.blue
                            : colorScheme.secondary,
                        quiz['isPublic'] == true
                            ? Colors.blue
                            : colorScheme.onSecondary,
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            // Show quiz options or quick actions
                            _showQuizOptions(context, quizId, quiz);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(
                              Icons.more_vert,
                              size: 20,
                              color: colorScheme.onSurfaceVariant,
                            ),
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

  Widget _buildChip(String label, Color backgroundColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: backgroundColor.withOpacity(0.5), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: backgroundColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showQuizOptions(
    BuildContext context,
    String quizId,
    Map<String, dynamic> quiz,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.edit, color: colorScheme.primary),
                title: Text('Edit Quiz'),
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to edit page
                  context.go('/app/creator/edit/$quizId');
                },
              ),
              ListTile(
                leading: Icon(Icons.share, color: colorScheme.primary),
                title: Text('Share Quiz'),

                onTap: () async {
                  // get the share sheet’s position (optional; improves tablet/UI placement)
                  final box = context.findRenderObject() as RenderBox?;
                  await SharePlus.instance.share(
                    ShareParams(
                      text:
                          'Join my quiz on Quizify!\nQuiz Code: code\nhttps://quizify.app/play?code=code',
                      subject: 'Quizify Quiz Invite',
                      sharePositionOrigin:
                          box!.localToGlobal(Offset.zero) & box!.size,
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  quiz['isPublic'] == true
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: colorScheme.primary,
                ),
                title: Text(
                  quiz['isPublic'] == true ? 'Make Private' : 'Make Public',
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Update visibility
                  FirebaseFirestore.instance
                      .collection('quizzes')
                      .doc(quizId)
                      .update({'isPublic': !(quiz['isPublic'] ?? false)});
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: colorScheme.error),
                title: Text(
                  'Delete Quiz',
                  style: TextStyle(color: colorScheme.error),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteQuiz(context, quizId);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteQuiz(BuildContext context, String quizId) {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Delete Quiz?'),
            content: Text(
              'This action cannot be undone. All questions and responses will be permanently deleted.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: colorScheme.primary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  // Delete the quiz
                  FirebaseFirestore.instance
                      .collection('quizzes')
                      .doc(quizId)
                      .delete();
                },
                child: Text('Delete'),
              ),
            ],
          ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty ? Icons.search_off : Icons.quiz,
            size: 70,
            color: colorScheme.primary.withOpacity(0.5),
          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isNotEmpty
                ? 'No matching quizzes found'
                : 'No quizzes created yet',
            style: textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Create your first quiz by tapping the button below',
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (_searchQuery.isEmpty)
            ElevatedButton.icon(
              onPressed: () {
                context.go('/app/creator/add');
              },
              icon: Icon(Icons.add),
              label: Text('Create Quiz'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                textStyle: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingShimmer(bool isMobile) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: MasonryGridView.count(
          crossAxisCount: isMobile ? 2 : 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          itemCount: 6,
          itemBuilder: (context, index) {
            return Container(
              height: 220 + (index % 3) * 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
