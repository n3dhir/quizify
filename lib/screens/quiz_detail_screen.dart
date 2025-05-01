import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:quizify/screens/admin_quiz_play_screen.dart';

class QuizDetailScreen extends StatefulWidget {
  final String quiz_id;

  const QuizDetailScreen({super.key, required this.quiz_id});

  @override
  _QuizDetailScreenState createState() => _QuizDetailScreenState();
}

class _QuizDetailScreenState extends State<QuizDetailScreen> {
  Map<String, dynamic>? loadedQuizData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
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
    // Responsive breakpoints
    final Size screenSize = MediaQuery.of(context).size;
    final bool isPhone = screenSize.width < 600;
    final bool isTablet = screenSize.width >= 600 && screenSize.width < 900;
    final bool isDesktop = screenSize.width >= 900;

    // Loading state
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Quiz Preview'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.deepPurple),
              SizedBox(height: 16),
              Text('Loading quiz details...', 
                style: TextStyle(fontSize: 16, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    // Error state
    if (loadedQuizData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Quiz Not Found'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/app/creator/home'),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              const Text(
                'Quiz data not found.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go('/app/creator/home'),
                child: const Text('Return to Home'),
              ),
            ],
          ),
        ),
      );
    }

    // Quiz data
    final quizData = loadedQuizData!;
    final int questionCount = quizData['questions'].length;
    final int estimatedMinutes = questionCount * 1; // Assuming ~1 min per question
    final String quizCode = quizData['quiz_code'];

    // Start the quiz function
    void startQuiz() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AdminQuizPlayScreen(
              quizData: {'id': widget.quiz_id, ...quizData}),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Preview'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/app/creator/home'),
        ),
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.edit),
          //   tooltip: 'Edit Quiz',
          //   onPressed: () {
          //     ScaffoldMessenger.of(context).showSnackBar(
          //       const SnackBar(content: Text('Edit feature not implemented yet')),
          //     );
          //   },
          // ),
          // const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Top header section
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(isPhone ? 20 : 32),
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quiz Title
                  Text(
                    quizData['title'],
                    style: TextStyle(
                      fontSize: isDesktop ? 32 : 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Quiz Stats
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildInfoChip(
                        Icons.format_list_numbered,
                        '$questionCount Questions', 
                        isDesktop,
                      ),
                      _buildInfoChip(
                        Icons.access_time,
                        'Est. $estimatedMinutes min', 
                        isDesktop,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Join Card
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isPhone ? 16 : 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'JOIN CODE',
                          style: TextStyle(
                            fontSize: isDesktop ? 18 : 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                        SizedBox(height: isPhone ? 8 : 12),
                        
                        GestureDetector(
                          onTap: () {
                          Clipboard.setData(ClipboardData(text: quizCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                            content: Text('Quiz code copied to clipboard!'),
                            ),
                          );
                          },
                          child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                            quizCode,
                            style: TextStyle(
                              fontSize: isDesktop ? 72 : 56,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                              color: Colors.deepPurple,
                            ),
                            ),
                          ),
                          ),
                        ),
                        SizedBox(height: isPhone ? 8 : 16),
                        const Text(
                          'Participants can join at quizify.app',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Main content area
          SliverPadding(
            padding: EdgeInsets.all(isPhone ? 16 : 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Build content based on screen size
                isDesktop
                    ? _buildDesktopContent(quizData, questionCount)
                    : isTablet
                        ? _buildTabletContent(quizData, questionCount)
                        : _buildPhoneContent(quizData, questionCount),
                
                const SizedBox(height: 24),
                
                // Start button
                ElevatedButton.icon(
                  onPressed: startQuiz,
                  icon: const Icon(Icons.play_arrow_rounded, size: 24),
                  label: const Text('START PRESENTING'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.deepPurple,
                    padding: EdgeInsets.symmetric(
                      vertical: isPhone ? 16 : 20,
                    ),
                    textStyle: TextStyle(
                      fontSize: isPhone ? 16 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // Different layouts for different screen sizes
  Widget _buildDesktopContent(Map<String, dynamic> quizData, int questionCount) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoCard(quizData),
              const SizedBox(height: 24),
              _buildQuestionsCard(questionCount),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _buildTipsCard(),
        ),
      ],
    );
  }

  Widget _buildTabletContent(Map<String, dynamic> quizData, int questionCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildInfoCard(quizData),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildQuestionsCard(questionCount),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildTipsCard(),
      ],
    );
  }

  Widget _buildPhoneContent(Map<String, dynamic> quizData, int questionCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoCard(quizData),
        const SizedBox(height: 24),
        _buildQuestionsCard(questionCount),
        const SizedBox(height: 24),
        _buildTipsCard(),
      ],
    );
  }

  // Common widget builder methods
  Widget _buildInfoCard(Map<String, dynamic> quizData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Quiz Information'),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInfoItem(
                  'Created',
                  formatDate(quizData['createdAt']),
                  Icons.calendar_today,
                  Colors.blue,
                ),
                if (quizData['description'] != null) ...[
                  const Divider(height: 24),
                  _buildInfoItem(
                    'Description',
                    quizData['description'] ?? 'No description provided',
                    Icons.info_outline,
                    Colors.teal,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionsCard(int questionCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Questions Overview'),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.question_mark,
                      color: Colors.deepPurple,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$questionCount Questions',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'The answers will be shown during presentation',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTipsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Presentation Tips'),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildTipItem(
                  'Display this screen for participants to see the join code',
                  Icons.groups,
                ),
                const Divider(height: 24),
                _buildTipItem(
                  'Give participants enough time to answer each question',
                  Icons.timer,
                ),
                const Divider(height: 24),
                _buildTipItem(
                  'Encourage discussion after revealing answers',
                  Icons.chat_bubble_outline,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Helper widgets
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, bool isLarge) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isLarge ? 20 : 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: isLarge ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTipItem(String tip, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.deepPurple,
          size: 20,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            tip,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}