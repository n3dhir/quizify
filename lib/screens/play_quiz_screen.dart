import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class PlayQuizScreen extends StatefulWidget {
  final String quizCode;

  const PlayQuizScreen({super.key, required this.quizCode});

  @override
  State<PlayQuizScreen> createState() => _PlayQuizScreenState();
}

class _PlayQuizScreenState extends State<PlayQuizScreen> {
  final TextEditingController _nicknameController = TextEditingController();
  bool _joining = true;
  bool _submitted = false;
  bool _quizStarted = false;
  bool _quizEnded = false;
  int _currentQuestionIndex = -1;
  List<dynamic> _questions = [];
  String? _selectedAnswer;
  StreamSubscription<DocumentSnapshot>? _quizListener;
  int _countdown = 30;
  Timer? _timer;
  bool _hasAnswered = false;

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyJoined();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _quizListener?.cancel();
    _quizListener = null;

    // Remove the participant from Firestore when the screen is disposed
    _removeParticipant();

    super.dispose();
  }

  Future<void> _checkIfAlreadyJoined() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final doc = await FirebaseFirestore.instance
        .collection('participants')
        .doc(uid)
        .get();

    if (doc.exists) {
      setState(() {
        _submitted = true;
      });
      _listenToQuiz();
    }

    setState(() {
      _joining = false;
    });
  }

  Future<void> _joinQuiz() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final nickname = _nicknameController.text.trim();

    if (nickname.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Please enter a nickname")));
      return;
    }

    await FirebaseFirestore.instance.collection('participants').doc(uid).set({
      'uid': uid,
      'quiz_code': widget.quizCode,
      'joined_at': FieldValue.serverTimestamp(),
      'nickname': nickname,
      'score': 0,
    });

    setState(() {
      _submitted = true;
    });

    _listenToQuiz();
  }

  void _listenToQuiz() {
    final quizRef = FirebaseFirestore.instance
        .collection('quizzes')
        .where('quiz_code', isEqualTo: widget.quizCode)
        .limit(1);

    quizRef.get().then((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final quizDoc = snapshot.docs.first;
        final quizId = quizDoc.id;

        _quizListener = FirebaseFirestore.instance
            .collection('quizzes')
            .doc(quizId)
            .snapshots()
            .listen((docSnapshot) {
          final data = docSnapshot.data();
          if (data == null) return;

          final started = data['started'] ?? false;
          final ended = data['ended'] ?? false;
          final currentQuestionIndex = data['currentQuestionIndex'] ?? -1;
          final questions = data['questions'] ?? [];

          if (started && !_quizStarted) {
            _quizStarted = true;
          }

          if (!started) {
            _currentQuestionIndex = -1;
          }

          _quizEnded = ended;

          if (_currentQuestionIndex != currentQuestionIndex) {
            _selectedAnswer = null;
            _hasAnswered = false;
            _startCountdown();
          }

          setState(() {
            _quizStarted = started;
            _currentQuestionIndex = currentQuestionIndex;
            _questions = questions;
          });
        });
      }
    });
  }

  void _startCountdown() {
    _countdown = _questions[_currentQuestionIndex + 1]['duration'].toInt();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown <= 0) {
        timer.cancel();
        if (!_hasAnswered) {
          _submitAnswer(null); // Submit no answer
        }
      } else {
        setState(() {
          _countdown--;
        });
      }
    });
  }

  Future<void> _submitAnswer(String? answer) async {
    if (_hasAnswered) return;

    _hasAnswered = true;
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final question = _questions[_currentQuestionIndex];
    final correct =
        question['options'].indexOf(answer) == question['correctAnswerIndex'];

    final participantRef =
        FirebaseFirestore.instance.collection('participants').doc(uid);

    // Start a batch to ensure both updates happen together
    final batch = FirebaseFirestore.instance.batch();

    if (correct) {
      int scoreIncrement =
          _countdown; // Use the remaining countdown time as a score multiplier
      batch.update(
          participantRef, {'score': FieldValue.increment(scoreIncrement)});
    }

    // Update answeredCurrentQuestion to true regardless of correctness
    batch.update(participantRef, {'answeredCurrentQuestion': true});

    // Commit the batch
    await batch.commit();

    setState(() {
      _selectedAnswer = answer;
    });
  }

  Future<void> _removeParticipant() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    try {
      await FirebaseFirestore.instance
          .collection('participants')
          .doc(uid)
          .delete();
    } catch (e) {
      print("Error removing participant: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_joining) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_submitted) {
      return Scaffold(
        appBar: AppBar(title: const Text('Join Quiz')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text('Enter your nickname to join the quiz:'),
              const SizedBox(height: 12),
              TextField(
                controller: _nicknameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Nickname',
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _joinQuiz,
                child: const Text('Join Quiz'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_quizStarted) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz Lobby')),
        body: const Center(child: Text('Waiting for quiz to start...')),
      );
    }

    if (_quizEnded) {
      return Scaffold(
          appBar: AppBar(title: const Text('Quiz Lobby')),
          body: const Center(
            child: Text('Quiz Ended 🎉', style: TextStyle(fontSize: 20)),
          ));
    }

    if (_currentQuestionIndex == -1 ||
        _currentQuestionIndex >= _questions.length) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz')),
        body: const Center(child: Text('Waiting for next question...')),
      );
    }

    final question = _questions[_currentQuestionIndex];
    final options = List<String>.from(question['options'] ?? []);
    final imageUrl = question['imageUrl'] as String?;

    return Scaffold(
      appBar: AppBar(title: Text('Question ${_currentQuestionIndex + 1}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question['question'] ?? 'No question',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (imageUrl != null && imageUrl.isNotEmpty)
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 200,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 200,
                          width: double.infinity,
                          alignment: Alignment.center,
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          width: double.infinity,
                          color: Colors.grey[300],
                          alignment: Alignment.center,
                          child: const Text('Failed to load image'),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            Text(
              'Time left: $_countdown seconds',
              style: const TextStyle(fontSize: 16, color: Colors.red),
            ),
            const SizedBox(height: 16),
            ...options.map((option) {
              final isSelected = option == _selectedAnswer;
              return ListTile(
                title: Text(option),
                tileColor: isSelected ? Colors.blue[100] : null,
                onTap: () => _submitAnswer(option),
              );
            }),
          ],
        ),
      ),
    );
  }
}
