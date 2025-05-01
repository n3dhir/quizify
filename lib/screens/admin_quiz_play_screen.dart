import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminQuizPlayScreen extends StatefulWidget {
  final Map<String, dynamic> quizData;

  const AdminQuizPlayScreen({super.key, required this.quizData});

  @override
  State<AdminQuizPlayScreen> createState() => _AdminQuizPlayScreenState();
}

class _AdminQuizPlayScreenState extends State<AdminQuizPlayScreen> {
  late String quizId;
  late String quizCode;
  late List questions;
  StreamSubscription<DocumentSnapshot>? _quizSubscription;
  int _currentQuestionIndex = -1;
  bool started = false;
  bool ended = false;
  int _countdown = 30;
  Timer? _timer;
  int maxPossibleScore = 0;

  @override
  void initState() {
    super.initState();
    quizId = widget.quizData['id'];
    quizCode = widget.quizData['quiz_code'];
    questions = widget.quizData['questions'] ?? [];
    _currentQuestionIndex = -1;
    started = false;
    ended = false;

    // Calculate max possible score
    maxPossibleScore = questions.fold(
      0,
      (sum, question) => sum + (question['duration'] as int),
    );

    _resetQuizState().then((_) => _listenForQuizChanges());
  }

  Future<void> _resetQuizState() async {
    final batch = FirebaseFirestore.instance.batch();
    final quizRef = FirebaseFirestore.instance.collection('quizzes').doc(quizId);
    batch.update(quizRef, {
      'started': false,
      'ended': false,
      'currentQuestionIndex': -1,
    });

    final participantsSnapshot = await FirebaseFirestore.instance
        .collection('participants')
        .where('quiz_code', isEqualTo: quizCode)
        .get();

    for (var doc in participantsSnapshot.docs) {
      batch.update(doc.reference, {
        'answeredCurrentQuestion': false,
        'score': 0,
      });
    }

    await batch.commit();
  }

  void _listenForQuizChanges() {
    _quizSubscription = FirebaseFirestore.instance
        .collection('quizzes')
        .doc(quizId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        setState(() {
          started = data['started'] ?? false;
          ended = data['ended'] ?? false;
          if (_currentQuestionIndex != data['currentQuestionIndex']) {
            _currentQuestionIndex = data['currentQuestionIndex'] ?? -1;
            if (_currentQuestionIndex >= 0) {
              _startCountdown();
            }
          }
        });
      }
    });
  }

  void _startCountdown() {
    _countdown = questions[_currentQuestionIndex]['duration'].toInt();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown <= 0) {
          timer.cancel();
        } else {
          _countdown--;
        }
      });
    });
  }

  Future<void> _startQuiz() async {
    await FirebaseFirestore.instance.collection('quizzes').doc(quizId).update({
      'started': true,
      'currentQuestionIndex': 0,
      'ended': false,
    });
  }

  Future<void> _nextQuestion() async {
    if (_currentQuestionIndex + 1 < questions.length) {
      final batch = FirebaseFirestore.instance.batch();
      final participantsSnapshot = await FirebaseFirestore.instance
          .collection('participants')
          .where('quiz_code', isEqualTo: quizCode)
          .get();

      for (var doc in participantsSnapshot.docs) {
        batch.update(doc.reference, {'answeredCurrentQuestion': false});
      }

      batch.update(
        FirebaseFirestore.instance.collection('quizzes').doc(quizId),
        {'currentQuestionIndex': _currentQuestionIndex + 1},
      );

      await batch.commit();
    } else {
      _endQuiz();
    }
  }

  Future<void> _endQuiz() async {
    final batch = FirebaseFirestore.instance.batch();

    // Reset answeredCurrentQuestion for all participants
    final participantsSnapshot = await FirebaseFirestore.instance
        .collection('participants')
        .where('quiz_code', isEqualTo: quizCode)
        .get();

    for (var doc in participantsSnapshot.docs) {
      batch.update(doc.reference, {'answeredCurrentQuestion': false});
    }

    // Also update the quiz document in the SAME batch
    final quizRef =
        FirebaseFirestore.instance.collection('quizzes').doc(quizId);
    batch.update(quizRef, {'ended': true});

    // Now commit everything together
    await batch.commit();
  }

  Widget _buildParticipantCard(DocumentSnapshot participant) {
    final nickname = participant['nickname'] ?? 'Anonymous';
    final score = (participant['score'] ?? 0).toInt();
    final participantData = participant.data() as Map<String, dynamic>;
    final answeredCurrent = participantData.containsKey('answeredCurrentQuestion') 
        ? participantData['answeredCurrentQuestion'] == true 
        : false;
    final progress = maxPossibleScore > 0 ? score / maxPossibleScore : 0;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  nickname,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$score pts',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                answeredCurrent ? Colors.green : Theme.of(context).primaryColor,
              ),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            if (answeredCurrent)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Answered',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingRoom() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Participants",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('participants')
                .where('quiz_code', isEqualTo: quizCode)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final participants = snapshot.data!.docs;

              if (participants.isEmpty) {
                return const Center(
                  child: Text("No participants yet"),
                );
              }

              return ListView.builder(
                itemCount: participants.length,
                itemBuilder: (context, index) {
                  return _buildParticipantCard(participants[index]);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: ElevatedButton(
            onPressed: _startQuiz,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text(
              "Start Quiz",
              style: TextStyle(fontSize: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionUI() {
    final question = questions[_currentQuestionIndex];
    final isLastQuestion = _currentQuestionIndex == questions.length - 1;
    final imageUrl = question['imageUrl'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Question ${_currentQuestionIndex + 1}/${questions.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Chip(
                      label: Text(
                        '$_countdown s',
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: _countdown <= 10
                          ? Colors.red
                          : Theme.of(context).primaryColor,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  question['question'] ?? 'No question text',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 12),
                if (imageUrl != null && imageUrl.isNotEmpty)
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 200,
                      placeholder:
                          (context, url) => Container(
                            height: 200,
                            width: double.infinity,
                            alignment: Alignment.center,
                            child: const CircularProgressIndicator(),
                          ),
                      errorWidget:
                          (context, url, error) => Container(
                            height: 200,
                            width: double.infinity,
                            color: Colors.grey[300],
                            alignment: Alignment.center,
                            child: const Text('Failed to load image'),
                          ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "Participants",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('participants')
                .where('quiz_code', isEqualTo: quizCode)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final participants = snapshot.data!.docs;
              final allAnswered = participants.every(
                  (p) => (p['answeredCurrentQuestion'] ?? false) == true);
              final isTimeUp = _countdown == 0;

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: participants.length,
                      itemBuilder: (context, index) {
                        return _buildParticipantCard(participants[index]);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: _nextQuestion,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16),
                        ),
                        child: Text(
                          isLastQuestion ? 'Show Results' : 'Next Question',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton(
                        onPressed: _endQuiz,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16),
                        ),
                        child: const Text(
                          'End Quiz',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _quizSubscription?.cancel();
    _quizSubscription = null;
    FirebaseFirestore.instance.collection('quizzes').doc(quizId).update({
      'started': false,
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Quiz Admin Panel"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: !started
            ? _buildWaitingRoom()
            : ended
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.celebration,
                          size: 80,
                          color: Colors.amber,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Quiz Completed!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Back to Quiz Details'),
                        ),
                      ],
                    ),
                  )
                : (_currentQuestionIndex >= 0 &&
                        _currentQuestionIndex < questions.length)
                    ? _buildQuestionUI()
                    : const Center(child: Text("Preparing quiz...")),
      ),
    );
  }
}