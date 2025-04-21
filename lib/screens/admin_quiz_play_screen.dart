import 'package:flutter/material.dart';

class AdminQuizPlayScreen extends StatelessWidget {
  final Map<String, dynamic> quizData;

  const AdminQuizPlayScreen({super.key, required this.quizData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Quiz in Progress"),
      ),
      body: Center(
        child: Text(
          'Admin is conducting quiz: ${quizData['title']}',
          style: const TextStyle(fontSize: 18),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
