import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:quizify/providers/auth_provider.dart' as quizify_auth;
// import 'package:quizify/providers/theme_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _checkingOnboarding = true;
  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final hasSeenOnboarding = userDoc.data()?['has_seen_onboarding'] ?? false;

    if (!hasSeenOnboarding) {
      context.go('/app/creator/onboarding');
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final authProvider = Provider.of<quizify_auth.AuthProvider>(context);
    // final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: Text('My Quizzes')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('quizzes')
            .where(
              'creator_id',
              isEqualTo: FirebaseAuth.instance.currentUser?.uid,
            )
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final quizzes = snapshot.data?.docs ?? [];

          if (quizzes.isEmpty) {
            return Center(child: Text('No quizzes created yet'));
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: GridView.builder(
              itemCount: quizzes.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.9,
              ),
              itemBuilder: (context, index) {
                final quiz = quizzes[index].data() as Map<String, dynamic>;
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
                // ? TODO: Use a default image URL
                imageUrl ??=
                    'https://via.placeholder.com/400x200.png?text=Quiz+Image';

                return Card(
                  elevation: 4,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () {
                      context.go(
                        "/app/creator/details/${quizzes[index].id}",
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                Center(child: CircularProgressIndicator()),
                            errorWidget: (context, url, error) =>
                                Icon(Icons.broken_image_outlined, size: 50),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                quiz['title'] ?? 'Untitled Quiz',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Questions: ${questions.length}',
                                style: const TextStyle(color: Colors.grey),
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.go('/app/creator/add');
        },
        label: Text('Add Quiz'),
        icon: Icon(Icons.add),
      ),
    );
  }
}
