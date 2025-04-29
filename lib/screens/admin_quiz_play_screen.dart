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
  StreamSubscription<DocumentSnapshot>? _quizSubscription;
  int _currentQuestionIndex = -1;
  bool started = false;
  bool ended = false;
  int questionDurationSeconds = 30;

  int _countdown = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    quizId = widget.quizData['id'];
    quizCode = widget.quizData['quiz_code'];
    questions = widget.quizData['questions'] ?? [];
    _currentQuestionIndex = -1;
    started = false;
    ended = false;

    _resetQuizState().then((_) => _listenForQuizChanges());
  }

  Future<void> _resetQuizState() async {
    final batch = FirebaseFirestore.instance.batch();

    // Reset the quiz document
    final quizRef =
        FirebaseFirestore.instance.collection('quizzes').doc(quizId);
    batch.update(quizRef, {
      'started': false,
      'ended': false,
      'currentQuestionIndex': -1,
    });

    // Reset answeredCurrentQuestion for all participants
    final participantsSnapshot = await FirebaseFirestore.instance
        .collection('participants')
        .where('quiz_code', isEqualTo: quizCode)
        .get();

    for (var doc in participantsSnapshot.docs) {
      batch.update(doc.reference, {'answeredCurrentQuestion': false});
    }

    // Commit all updates together
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
        if (data == null) return;

        final currentQuestionIndex = data['currentQuestionIndex'] ?? -1;

        // if (started && !_quizStarted) {
        //   _quizStarted = true;
        // }

        // _quizEnded = ended;

        if (_currentQuestionIndex != currentQuestionIndex) {
          // _currentQuestionIndex = currentQuestionIndex;
          _startCountdown();
        }

        setState(() {
          started = data['started'] ?? false;
          ended = data['ended'] ?? false;
          _currentQuestionIndex = currentQuestionIndex;
        });
      }
    });
  }

  void _startCountdown() {
    _countdown = questions[_currentQuestionIndex + 1]['duration'].toInt();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown <= 0) {
        timer.cancel();
        // if (!_hasAnswered) {
        //   _submitAnswer(null); // Submit no answer
        // }
      } else {
        setState(() {
          _countdown--;
        });
      }
    });
  }

  Future<void> _startQuiz() async {
    final batch = FirebaseFirestore.instance.batch();

    // Reset scores for all participants
    final participantsSnapshot = await FirebaseFirestore.instance
        .collection('participants')
        .where('quiz_code', isEqualTo: quizCode)
        .get();

    for (var doc in participantsSnapshot.docs) {
      batch.update(doc.reference, {'score': 0});
    }

    batch.update(FirebaseFirestore.instance.collection('quizzes').doc(quizId), {
      'started': true,
      'currentQuestionIndex': 0,
      'ended': false,
    });

    await batch.commit();
  }

  Future<void> _nextQuestion() async {
    if (_currentQuestionIndex + 1 < questions.length) {
      final batch = FirebaseFirestore.instance.batch();

      // Reset answeredCurrentQuestion for all participants
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

  Widget _buildWaitingRoom() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
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
    final question = questions[_currentQuestionIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Question ${_currentQuestionIndex + 1} of ${questions.length}',
          style: const TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 10),
        Text(
          question['question'] ?? 'No question text',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 10),
        Text('Time remaining: $_countdown seconds'),
        const SizedBox(height: 20),
        FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('participants')
              .where('quiz_code', isEqualTo: quizCode)
              .get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const CircularProgressIndicator();
            final participants = snapshot.data!.docs;

            final allAnswered = participants.any(
              (p) => ((p.data() as Map<String, dynamic>).containsKey(
                        'answeredCurrentQuestion',
                      ) ==
                      true &&
                  (p['answeredCurrentQuestion'] ?? false) == true),
            );

            final isTimeUp = _countdown == 0;

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
      appBar: AppBar(title: const Text("Quiz Admin Panel")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: !started
            ? _buildWaitingRoom()
            : ended
                ? const Center(
                    child:
                        Text('Quiz Ended 🎉', style: TextStyle(fontSize: 20)),
                  )
                : (_currentQuestionIndex >= 0 &&
                        _currentQuestionIndex < questions.length)
                    ? _buildQuestionUI()
                    : const Center(child: Text("Invalid Question")),
      ),
    );
  }
}
