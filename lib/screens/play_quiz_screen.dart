import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PlayQuizScreen extends StatefulWidget {
  final String quizCode;

  const PlayQuizScreen({super.key, required this.quizCode});

  @override
  State<PlayQuizScreen> createState() => _PlayQuizScreenState();
}

class _PlayQuizScreenState extends State<PlayQuizScreen>
    with SingleTickerProviderStateMixin {
  // Add these new variables for animation
  late AnimationController _countdownController;
  late Animation<double> _progressAnimation;

  final TextEditingController _nicknameController = TextEditingController();
  bool _joining = true;
  bool _submitted = false;
  bool _quizStarted = false;
  bool _quizEnded = false;
  int _currentQuestionIndex = -1;
  List<dynamic> _questions = [];
  String _quiz_title = "";
  String? _selectedAnswer;
  StreamSubscription<DocumentSnapshot>? _quizListener;
  int _countdown = 30;
  Timer? _timer;
  bool _hasAnswered = false;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _countdownController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Initialize progress animation
    _progressAnimation = Tween<double>(begin: 1.0, end: 1.0).animate(
      CurvedAnimation(parent: _countdownController, curve: Curves.easeInOut),
    );

    _checkIfAlreadyJoined();
  }

  @override
  void dispose() {
    _countdownController.dispose();
    _timer?.cancel();
    _quizListener?.cancel();
    _quizListener = null;
    _removeParticipant();
    super.dispose();
  }

  Future<void> _checkIfAlreadyJoined() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc =
        await FirebaseFirestore.instance
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
      ).showSnackBar(const SnackBar(content: Text("Please enter a nickname")));
      return;
    }

    await FirebaseFirestore.instance.collection('participants').doc(uid).set({
      'uid': uid,
      'quiz_code': widget.quizCode,
      'joined_at': FieldValue.serverTimestamp(),
      'answeredCurrentQuestion': false, // Initialize here
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
              _quiz_title = data['title'] ?? "";
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
    final duration = _questions[_currentQuestionIndex + 1]['duration'].toInt();
    _countdown = duration;

    // Update the progress animation
    _updateProgressAnimation(_countdown / duration);

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown <= 0) {
        timer.cancel();
        if (!_hasAnswered) {
          _submitAnswer(null);
        }
      } else {
        setState(() {
          _countdown--;
          _updateProgressAnimation(_countdown / duration);
        });
      }
    });
  }

  void _updateProgressAnimation(double newValue) {
    _progressAnimation = Tween<double>(
      begin: _progressAnimation.value,
      end: newValue,
    ).animate(
      CurvedAnimation(parent: _countdownController, curve: Curves.easeInOut),
    );
    _countdownController.forward(from: 0);
  }

  Future<void> _submitAnswer(String? answer) async {
    if (_hasAnswered) return;

    // Cancel the timer when an answer is submitted
    _timer?.cancel();

    _hasAnswered = true;
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final question = _questions[_currentQuestionIndex];
    final correct =
        question['options'].indexOf(answer) == question['correctAnswerIndex'];

    final participantRef = FirebaseFirestore.instance
        .collection('participants')
        .doc(uid);

    final batch = FirebaseFirestore.instance.batch();

    if (correct) {
      int scoreIncrement = _countdown;
      batch.update(participantRef, {
        'score': FieldValue.increment(scoreIncrement),
      });
    }

    batch.update(participantRef, {'answeredCurrentQuestion': true});

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

  // Helper methods for option styling
  Color _getOptionBackgroundColor({
    required bool isSelected,
    required bool isCorrectSelection,
    required bool isWrongSelection,
    required bool timeIsUp,
  }) {
    if (timeIsUp) return Colors.grey[100]!;
    if (isCorrectSelection) return Colors.green[50]!;
    if (isWrongSelection) return Colors.red[50]!;
    if (isSelected) return Theme.of(context).primaryColor.withOpacity(0.1);
    return Colors.white;
  }

  Color _getOptionBorderColor({
    required bool isSelected,
    required bool isCorrectSelection,
    required bool isWrongSelection,
  }) {
    if (isCorrectSelection) return Colors.green;
    if (isWrongSelection) return Colors.red;
    if (isSelected) return Theme.of(context).primaryColor;
    return Colors.grey[300]!;
  }

  Color _getOptionTextColor({
    required bool isSelected,
    required bool isCorrectSelection,
    required bool isWrongSelection,
  }) {
    if (isCorrectSelection) return Colors.green[800]!;
    if (isWrongSelection) return Colors.red[800]!;
    if (isSelected) return Theme.of(context).primaryColor;
    return Colors.grey[800]!;
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
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Lottie.asset(
                'assets/animations/join.json',
                width: 150,
                height: 150,
              ),
              const SizedBox(height: 20),
              const Text(
                'Enter your nickname',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nicknameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Nickname',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _joinQuiz,
                icon: const Icon(Icons.login),
                label: const Text('Join Quiz'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_quizStarted) {
      return Scaffold(
        appBar: AppBar(title: Text(_quiz_title.toString())),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Lottie.asset('/animations/waiting.json', width: 200, height: 200),
              const SizedBox(height: 20),
              const Text(
                'Waiting for quiz to start...',
                style: TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    if (_quizEnded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz Ended')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Lottie.asset(
                '/animations/celebration.json',
                width: 200,
                height: 200,
              ),
              const SizedBox(height: 20),
              const Text('Quiz Ended 🎉', style: TextStyle(fontSize: 20)),
            ],
          ),
        ),
      );
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
            // Inside the Scaffold where the countdown was displayed:
            AnimatedBuilder(
              animation:
                  _countdownController, // You'll need to create an AnimationController
              builder: (context, child) {
                return LinearProgressIndicator(
                  value: _progressAnimation.value,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _countdown <= 10
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                  ),
                  minHeight: 8,
                );
              },
            ),
            const SizedBox(height: 16),
            ...options.map((option) {
              final isSelected = option == _selectedAnswer;
              final correctAnswer =
                  question['options'][question['correctAnswerIndex']];
              final isCorrectSelection =
                  _hasAnswered && isSelected && option == correctAnswer;
              final isWrongSelection =
                  _hasAnswered && isSelected && option != correctAnswer;
              final _timeIsUp = _countdown <= 0;

              // Enhanced styling with animations
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Animate(
                  effects: [
                    FadeEffect(duration: 300.ms),
                    SlideEffect(begin: const Offset(0.2, 0)),
                  ],
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap:
                          _hasAnswered || _timeIsUp
                              ? null
                              : () => _submitAnswer(option),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: _getOptionBackgroundColor(
                            isSelected: isSelected,
                            isCorrectSelection: isCorrectSelection,
                            isWrongSelection: isWrongSelection,
                            timeIsUp: _timeIsUp,
                          ),
                          border: Border.all(
                            color: _getOptionBorderColor(
                              isSelected: isSelected,
                              isCorrectSelection: isCorrectSelection,
                              isWrongSelection: isWrongSelection,
                            ),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                option,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                  color: _getOptionTextColor(
                                    isSelected: isSelected,
                                    isCorrectSelection: isCorrectSelection,
                                    isWrongSelection: isWrongSelection,
                                  ),
                                ),
                              ),
                            ),
                            if (!_hasAnswered && isSelected)
                              Icon(
                                Icons.radio_button_checked,
                                color: Theme.of(context).primaryColor,
                              ),
                            if (!_hasAnswered && !isSelected)
                              const Icon(
                                Icons.radio_button_off,
                                color: Colors.grey,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
          
        ),
      ),
    );
  }
}
