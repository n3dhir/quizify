import 'dart:async';
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
  int currentQuestionIndex = -1;
  bool started = false;
  bool ended = false;
  Timestamp? questionStartTime;
  int questionDurationSeconds = 30;

  Timer? _timer;
  int timeRemaining = 30;

  @override
  void initState() {
    super.initState();
    quizId = widget.quizData['id'];
    quizCode = widget.quizData['quiz_code'];
    questions = widget.quizData['questions'] ?? [];
    currentQuestionIndex = -1;
    started = false;
    ended = false;

    _resetQuizState(); // reset when screen is loaded
    _listenForQuizChanges(); // listen for real-time updates
    _startTimerLoop();
  }

  Future<void> _resetQuizState() async {
    await FirebaseFirestore.instance.collection('quizzes').doc(quizId).update({
      'started': false,
      'ended': false,
      'currentQuestionIndex': -1,
    });
  }

  void _listenForQuizChanges() {
    FirebaseFirestore.instance
        .collection('quizzes')
        .doc(quizId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data()!;
            setState(() {
              started = data['started'] ?? false;
              ended = data['ended'] ?? false;
              currentQuestionIndex = data['currentQuestionIndex'] ?? -1;
              questionStartTime = data['questionStartTime'];
            });
          }
        });
  }

  void _startTimerLoop() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (questionStartTime != null) {
        final start = questionStartTime!.toDate();
        final end = start.add(Duration(seconds: questionDurationSeconds));
        final now = DateTime.now();
        final remaining = end.difference(now).inSeconds;

        setState(() {
          timeRemaining = remaining.clamp(0, questionDurationSeconds);
        });
      }
    });
  }

  Future<void> _startQuiz() async {
    final batch = FirebaseFirestore.instance.batch();

    // Reset scores for all participants
    final participantsSnapshot =
      await FirebaseFirestore.instance
        .collection('participants')
        .where('quiz_code', isEqualTo: quizCode)
        .get();

    for (var doc in participantsSnapshot.docs) {
      batch.update(doc.reference, {'score': 0});
    }

    batch.update(
      FirebaseFirestore.instance.collection('quizzes').doc(quizId),
      {
      'started': true,
      'currentQuestionIndex': 0,
      'questionStartTime': FieldValue.serverTimestamp(),
      'ended': false,
      },
    );

    await batch.commit();
  }

  Future<void> _nextQuestion() async {
    if (currentQuestionIndex + 1 < questions.length) {
      final batch = FirebaseFirestore.instance.batch();

      // Reset answeredCurrentQuestion for all participants
      final participantsSnapshot =
          await FirebaseFirestore.instance
              .collection('participants')
              .where('quiz_code', isEqualTo: quizCode)
              .get();

      for (var doc in participantsSnapshot.docs) {
        batch.update(doc.reference, {'answeredCurrentQuestion': false});
      }

      batch.update(
        FirebaseFirestore.instance.collection('quizzes').doc(quizId),
        {
          'currentQuestionIndex': currentQuestionIndex + 1,
          'questionStartTime': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();
    } else {
      _endQuiz();
    }
  }

  Future<void> _endQuiz() async {
    await FirebaseFirestore.instance.collection('quizzes').doc(quizId).update({
      'ended': true,
    });
  }

  Widget _buildWaitingRoom() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('participants')
              .where('quiz_code', isEqualTo: quizCode)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final participants = snapshot.data!.docs;

        // print(participants);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Waiting for participants...",
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 10),
            ...participants
                .map((doc) => Text(doc['nickname'] ?? 'Unnamed'))
                .toList(),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _startQuiz,
              child: const Text("Start Quiz"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuestionUI() {
    final question = questions[currentQuestionIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Question ${currentQuestionIndex + 1} of ${questions.length}',
          style: const TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 10),
        Text(
          question['question'] ?? 'No question text',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 10),
        Text('Time remaining: $timeRemaining seconds'),
        const SizedBox(height: 20),
        FutureBuilder<QuerySnapshot>(
          future:
              FirebaseFirestore.instance
                  .collection('participants')
                  .where('quiz_code', isEqualTo: quizCode)
                  .get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const CircularProgressIndicator();
            final participants = snapshot.data!.docs;


            final allAnswered = participants.every(
              (p) => ((p.data() as Map<String, dynamic>).containsKey('answeredCurrentQuestion') == true && (p['answeredCurrentQuestion'] ?? false) == true),
            );

            final isTimeUp = timeRemaining == 0;

            if (allAnswered || isTimeUp) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Scores so far:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...participants.map(
                    (p) => Text(
                      "${p['nickname'] ?? 'Unnamed'}: ${p['score'] ?? 0} pts",
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _nextQuestion,
                    child: const Text("Next Question"),
                  ),
                  OutlinedButton(
                    onPressed: _endQuiz,
                    child: const Text('End Quiz'),
                  ),
                ],
              );
            }

            return const Text("Waiting for responses...");
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    FirebaseFirestore.instance.collection('quizzes').doc(quizId).update({
      'started': false,
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Quiz Admin Panel")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            !started
                ? _buildWaitingRoom()
                : ended
                ? const Center(
                  child: Text('Quiz Ended 🎉', style: TextStyle(fontSize: 20)),
                )
                : (currentQuestionIndex >= 0 &&
                    currentQuestionIndex < questions.length)
                ? _buildQuestionUI()
                : const Center(child: Text("Invalid Question")),
      ),
    );
  }
}
