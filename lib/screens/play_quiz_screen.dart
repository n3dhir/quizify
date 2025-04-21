import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyJoined();
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
        _joining = false;
      });
    } else {
      setState(() {
        _joining = false;
      });
    }
  }

  Future<void> _joinQuiz() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final nickname = _nicknameController.text.trim();

    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a nickname")),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('participants').doc(uid).set({
      'uid': uid,
      'quiz_code': widget.quizCode,
      'joined_at': FieldValue.serverTimestamp(),
      'nickname': nickname,
    });

    setState(() {
      _submitted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_joining) {
      return Scaffold(
        appBar: AppBar(title: Text('Joining Quiz...')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Quiz Lobby')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _submitted
            ? Center(
                child: Text(
                  'Waiting for quiz to start...',
                  // style: Theme.of(context).textTheme.headline6,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter your nickname to join the quiz:',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nicknameController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Nickname',
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _joinQuiz,
                    child: Text('Join Quiz'),
                  ),
                ],
              ),
      ),
    );
  }
}
