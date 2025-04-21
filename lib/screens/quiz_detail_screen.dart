import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:quizify/screens/admin_quiz_play_screen.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class QuizDetailScreen extends StatefulWidget {
  final String quiz_id;

  const QuizDetailScreen({super.key, required this.quiz_id});

  @override
  _QuizDetailScreenState createState() => _QuizDetailScreenState();
}

class _QuizDetailScreenState extends State<QuizDetailScreen> {
  late PageController _pageController;

  Map<String, dynamic>? loadedQuizData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    fetchQuizData(widget.quiz_id).then((data) {
      setState(() {
        loadedQuizData = data;
        isLoading = false;
      });
    }).catchError((error) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading quiz: $error')),
      );
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> fetchQuizData(String quizId) async {
    final quizDoc = await FirebaseFirestore.instance
        .collection('quizzes')
        .doc(quizId)
        .get();

    if (!quizDoc.exists) {
      throw Exception('Quiz not found');
    }

    return quizDoc.data()!;
  }

  String formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('d MMMM yyyy \u00e0 HH:mm:ss')
          .format(timestamp.toDate());
    } else if (timestamp is DateTime) {
      return DateFormat('d MMMM yyyy \u00e0 HH:mm:ss').format(timestamp);
    } else {
      return 'Invalid date';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (loadedQuizData == null) {
      return const Scaffold(
        body: Center(
          child: Text('Quiz data not found.'),
        ),
      );
    }

    final quizData = loadedQuizData!;

    return Scaffold(
      appBar: AppBar(
        title: Text(quizData['title']),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go('/app/creator/home');
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AdminQuizPlayScreen(quizData: {
                          'id': widget.quiz_id,
                          ...quizData
                          }),
                  ),
                );
              },
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Start Quiz',
                style: TextStyle(
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quiz Title: ${quizData['title']}',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Quiz Code: ${quizData['quiz_code']}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Created At: ${formatDate(quizData['createdAt'])}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: quizData['questions'].length,
                    itemBuilder: (context, index) {
                      final question = quizData['questions'][index];
                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (question['imageUrl'] != null)
                                CachedNetworkImage(
                                  imageUrl: question['imageUrl'],
                                  placeholder: (context, url) =>
                                      const CircularProgressIndicator(),
                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.error),
                                ),
                              const SizedBox(height: 8),
                              Text(
                                'Q${index + 1}: ${question['question']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children:
                                    question['options'].map<Widget>((option) {
                                  return Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Text(option),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Correct Answer: ${question['options'][question['correctAnswerIndex']]}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: SmoothPageIndicator(
                          controller: _pageController,
                          count: quizData['questions'].length,
                          effect: const WormEffect(
                            dotHeight: 10,
                            dotWidth: 10,
                            activeDotColor: Colors.deepPurple,
                          ),
                          onDotClicked: (index) {
                            _pageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
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
    );
  }
}
