import 'dart:async';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:confetti/confetti.dart';

class AdminQuizPlayScreen extends StatefulWidget {
  final Map<String, dynamic> quizData;

  const AdminQuizPlayScreen({super.key, required this.quizData});

  @override
  State<AdminQuizPlayScreen> createState() => _AdminQuizPlayScreenState();
}

class _AdminQuizPlayScreenState extends State<AdminQuizPlayScreen>
    with TickerProviderStateMixin {
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

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<Color> _avatarColors = [
    Colors.blue[300]!,
    Colors.teal[300]!,
    Colors.amber[300]!,
    Colors.purple[300]!,
    Colors.orange[300]!,
    Colors.pink[300]!,
    Colors.indigo[300]!,
    Colors.lime[300]!,
  ];
  final List<IconData> _avatarIcons = [
    Icons.person,
    Icons.emoji_people,
    Icons.face,
    Icons.sports,
    Icons.emoji_emotions,
    Icons.school,
    Icons.psychology,
    Icons.pets,
  ];

  late ConfettiController _confettiController;
  bool _showStartCountdown = false;
  int _startCountdownValue = 5;
  Timer? _startCountdownTimer;

  @override
  void initState() {
    super.initState();
    quizId = widget.quizData['id'];
    quizCode = widget.quizData['quiz_code'];
    questions = widget.quizData['questions'] ?? [];
    _currentQuestionIndex = -1;
    started = false;
    ended = false;

    maxPossibleScore = questions.fold(
      0,
      (sum, question) => sum + (question['duration'] as int),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    _resetQuizState().then((_) => _listenForQuizChanges());
  }

  List<DocumentSnapshot> _sortedParticipants(
    List<DocumentSnapshot> participants,
  ) {
    participants.sort((a, b) => (b['score'] ?? 0).compareTo(a['score'] ?? 0));
    return participants;
  }

  Widget _buildWinnerPodium(List<DocumentSnapshot> participants) {
    final winners = participants.take(3).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (winners.length >= 2)
            _PodiumStep(
              participant: winners[1],
              position: 2,
              height: 100,
              color: Colors.blueGrey[300]!,
            ),
          if (winners.isNotEmpty)
            _PodiumStep(
              participant: winners[0],
              position: 1,
              height: 150,
              color: Colors.amber[300]!,
            ),
          if (winners.length >= 3)
            _PodiumStep(
              participant: winners[2],
              position: 3,
              height: 80,
              color: Colors.brown[300]!,
            ),
        ],
      ),
    );
  }

  Widget _buildWinnerBadge(int position) {
    final colors = {1: Colors.amber, 2: Colors.blueGrey, 3: Colors.brown};

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colors[position]?[300],
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Center(
        child: Text(
          '$position${_getPositionSuffix(position)}',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  String _getPositionSuffix(int position) {
    switch (position) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  @override
  void dispose() {
    _quizSubscription?.cancel();
    _timer?.cancel();
    _startCountdownTimer?.cancel();
    _pulseController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _resetQuizState() async {
    final batch = FirebaseFirestore.instance.batch();
    final quizRef = FirebaseFirestore.instance
        .collection('quizzes')
        .doc(quizId);
    batch.update(quizRef, {
      'started': false,
      'ended': false,
      'currentQuestionIndex': -1,
    });

    final participantsSnapshot =
        await FirebaseFirestore.instance
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

  void _startQuizWithCountdown() {
    setState(() {
      _showStartCountdown = true;
      _startCountdownValue = 5;
    });

    _startCountdownTimer?.cancel();
    _startCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_startCountdownValue <= 1) {
          timer.cancel();
          _showStartCountdown = false;
          _startQuiz();
        } else {
          _startCountdownValue--;
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
        {'currentQuestionIndex': _currentQuestionIndex + 1},
      );

      await batch.commit();
    } else {
      _endQuiz();
    }
  }

  Future<void> _endQuiz() async {
    final batch = FirebaseFirestore.instance.batch();
    _confettiController.play();

    final participantsSnapshot =
        await FirebaseFirestore.instance
            .collection('participants')
            .where('quiz_code', isEqualTo: quizCode)
            .get();

    for (var doc in participantsSnapshot.docs) {
      batch.update(doc.reference, {'answeredCurrentQuestion': false});
    }

    final quizRef = FirebaseFirestore.instance
        .collection('quizzes')
        .doc(quizId);
    batch.update(quizRef, {'ended': true});

    await batch.commit();
  }

  Widget _buildParticipantAvatar(String nickname, bool answeredCurrent) {
    final hashCode = nickname.hashCode;
    final colorIndex = hashCode % _avatarColors.length;
    final iconIndex = (hashCode ~/ 10) % _avatarIcons.length;

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: _avatarColors[colorIndex],
          child: Icon(_avatarIcons[iconIndex], color: Colors.white, size: 28),
        ),
        if (answeredCurrent)
          Container(
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 16),
          ),
      ],
    );
  }

  Widget _buildParticipantCard(
    DocumentSnapshot participant, {
    bool grid = false,
    int? position,
  }) {
    final nickname = participant['nickname'] ?? 'Anonymous';
    final score = (participant['score'] ?? 0).toInt();
    final participantData = participant.data() as Map<String, dynamic>;
    final answeredCurrent =
        (participantData['answeredCurrentQuestion'] ?? false) as bool;
    final progress = maxPossibleScore > 0 ? score / maxPossibleScore : 0;

    final isWinner = position != null && position <= 3;
    final medalColors = {1: Colors.amber, 2: Colors.blueGrey, 3: Colors.brown};

    final card = Card(
      elevation: isWinner ? 6 : 3,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: answeredCurrent ? Colors.green.shade300 : Colors.transparent,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.topCenter,
              children: [
                _buildParticipantAvatar(nickname, answeredCurrent),
                if (position != null)
                  Positioned(top: -10, child: _buildWinnerBadge(position)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              nickname,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isWinner ? medalColors[position] : Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              '$score pts',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                answeredCurrent ? Colors.green : Theme.of(context).primaryColor,
              ),
              minHeight: 6,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );

    return ended && position != null
        ? AnimationConfiguration.staggeredGrid(
          position: position,
          duration: const Duration(milliseconds: 500),
          columnCount: 1,
          child: ScaleAnimation(
            curve: Curves.elasticOut,
            child: FadeInAnimation(child: card),
          ),
        )
        : card;
  }

  Widget _buildEndScreen(List<DocumentSnapshot> participants) {
    final sorted = _sortedParticipants(participants);

    return Column(
      children: [
        Text(
          'Quiz Results',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        _buildWinnerPodium(sorted),
        Expanded(
          child: AnimationLimiter(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: sorted.length,
              itemBuilder: (context, index) {
                return AnimationConfiguration.staggeredList(
                  position: index,
                  duration: const Duration(milliseconds: 375),
                  child: SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(
                      child: _buildParticipantCard(
                        sorted[index],
                        position: index + 1,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (!started || ended)
            StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('participants')
                      .where('quiz_code', isEqualTo: quizCode)
                      .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final participants = snapshot.data!.docs;
                return ended
                    ? _buildEndScreen(participants)
                    : _buildWaitingRoom();
              },
            ),
          if (started && !ended) _buildQuestionUI(),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingRoom() {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.quiz, size: 28, color: Colors.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.quizData['title'] ?? 'Quiz Session',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${questions.length} questions · ${widget.quizData['description'] ?? 'Get ready for fun!'}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            color: Colors.blue[50],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.code, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Quiz Code: $quizCode',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        StreamBuilder<QuerySnapshot>(
                          stream:
                              FirebaseFirestore.instance
                                  .collection('participants')
                                  .where('quiz_code', isEqualTo: quizCode)
                                  .orderBy('score', descending: true)
                                  .snapshots(),
                          builder: (context, snapshot) {
                            int participantCount =
                                snapshot.hasData
                                    ? snapshot.data!.docs.length
                                    : 0;
                            return Card(
                              color: Colors.purple[50],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.people,
                                      color: Colors.purple,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Participants: $participantCount',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.purple,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Participants",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream:
                        FirebaseFirestore.instance
                            .collection('participants')
                            .where('quiz_code', isEqualTo: quizCode)
                            .snapshots(),
                    builder: (context, snapshot) {
                      int participantCount =
                          snapshot.hasData ? snapshot.data!.docs.length : 0;
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child:
                            participantCount > 0
                                ? ElevatedButton.icon(
                                  key: const ValueKey('startButton'),
                                  onPressed: _startQuizWithCountdown,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple[50],
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text(
                                    "Start Quiz",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                                : const SizedBox.shrink(),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('participants')
                        .where('quiz_code', isEqualTo: quizCode)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final participants = snapshot.data!.docs;

                  if (participants.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Waiting for participants...",
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          const SizedBox(height: 24),
                          ScaleTransition(
                            scale: _pulseAnimation,
                            child: Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.qr_code,
                                      size: 60,
                                      color: Colors.blue,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      "Join with code: $quizCode",
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth > 600) {
                        return AnimationLimiter(
                          child: GridView.builder(
                            padding: const EdgeInsets.all(8),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount:
                                      constraints.maxWidth > 1200
                                          ? 5
                                          : constraints.maxWidth > 900
                                          ? 4
                                          : 3,
                                  childAspectRatio: 0.85,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                            itemCount: participants.length,
                            itemBuilder: (context, index) {
                              return AnimationConfiguration.staggeredGrid(
                                position: index,
                                duration: const Duration(milliseconds: 375),
                                columnCount:
                                    constraints.maxWidth > 1200
                                        ? 5
                                        : constraints.maxWidth > 900
                                        ? 4
                                        : 3,
                                child: ScaleAnimation(
                                  child: FadeInAnimation(
                                    child: _buildParticipantCard(
                                      participants[index],
                                      grid: true,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      } else {
                        return AnimationLimiter(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: participants.length,
                            itemBuilder: (context, index) {
                              return AnimationConfiguration.staggeredList(
                                position: index,
                                duration: const Duration(milliseconds: 375),
                                child: SlideAnimation(
                                  verticalOffset: 50.0,
                                  child: FadeInAnimation(
                                    child: _buildParticipantCard(
                                      participants[index],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
        if (_showStartCountdown)
          Container(
            color: Colors.black54,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Quiz Starting in",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "$_startCountdownValue",
                    style: TextStyle(
                      fontSize: 60,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
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
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Question ${_currentQuestionIndex + 1}/${questions.length}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color:
                            _countdown <= 10
                                ? Colors.red[50]
                                : Colors.green[50],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _countdown <= 10 ? Colors.red : Colors.green,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer,
                            size: 20,
                            color: _countdown <= 10 ? Colors.red : Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$_countdown s',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color:
                                  _countdown <= 10 ? Colors.red : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  question['question'] ?? 'No question text',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                if (imageUrl != null && imageUrl.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 250,
                        placeholder:
                            (context, url) => Container(
                              height: 250,
                              width: double.infinity,
                              color: Colors.grey[200],
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(),
                            ),
                        errorWidget:
                            (context, url, error) => Container(
                              height: 250,
                              width: double.infinity,
                              color: Colors.grey[300],
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.error,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Failed to load image',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Participants",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('participants')
                        .where('quiz_code', isEqualTo: quizCode)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();

                  final participants = snapshot.data!.docs;
                  final answeredCount =
                      participants
                          .where(
                            (p) =>
                                (p['answeredCurrentQuestion'] ?? false) == true,
                          )
                          .length;

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "Answers: $answeredCount/${participants.length}",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple[700],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('participants')
                    .where('quiz_code', isEqualTo: quizCode)
                    .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final participants = snapshot.data!.docs;
              final allAnswered = participants.every(
                (p) => (p['answeredCurrentQuestion'] ?? false) == true,
              );
              final isTimeUp = _countdown == 0;

              return Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 600) {
                          return AnimationLimiter(
                            child: GridView.builder(
                              padding: const EdgeInsets.all(8),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount:
                                        constraints.maxWidth > 1200
                                            ? 5
                                            : constraints.maxWidth > 900
                                            ? 4
                                            : 3,
                                    childAspectRatio: 0.85,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                              itemCount: participants.length,
                              itemBuilder: (context, index) {
                                return AnimationConfiguration.staggeredGrid(
                                  position: index,
                                  duration: const Duration(milliseconds: 375),
                                  columnCount:
                                      constraints.maxWidth > 1200
                                          ? 5
                                          : constraints.maxWidth > 900
                                          ? 4
                                          : 3,
                                  child: ScaleAnimation(
                                    child: FadeInAnimation(
                                      child: _buildParticipantCard(
                                        participants[index],
                                        grid: true,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        } else {
                          return AnimationLimiter(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: participants.length,
                              itemBuilder: (context, index) {
                                return AnimationConfiguration.staggeredList(
                                  position: index,
                                  duration: const Duration(milliseconds: 375),
                                  child: SlideAnimation(
                                    verticalOffset: 50.0,
                                    child: FadeInAnimation(
                                      child: _buildParticipantCard(
                                        participants[index],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  if ((allAnswered || isTimeUp) && !ended)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton.icon(
                        onPressed: _nextQuestion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isLastQuestion ? Colors.purple : Colors.blue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(
                          isLastQuestion ? Icons.flag : Icons.navigate_next,
                        ),
                        label: Text(
                          isLastQuestion ? "Finish Quiz" : "Next Question",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PodiumStep extends StatelessWidget {
  final DocumentSnapshot participant;
  final int position;
  final double height;
  final Color color;

  const _PodiumStep({
    required this.participant,
    required this.position,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final nickname = participant['nickname'] ?? 'Anonymous';
    final score = (participant['score'] ?? 0).toInt();

    return AnimationConfiguration.staggeredList(
      position: position,
      duration: const Duration(milliseconds: 500),
      child: SlideAnimation(
        verticalOffset: 50,
        child: FadeInAnimation(
          child: Container(
            width: 120,
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '$position${_getPositionSuffix(position)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  nickname,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$score pts',
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getPositionSuffix(int position) {
    switch (position) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
}
