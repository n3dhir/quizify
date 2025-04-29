import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:introduction_screen/introduction_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  Future<void> _completeOnboarding(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .set({'has_seen_onboarding': true}, SetOptions(merge: true));

    context.go('/app/creator/home');
  }

  @override
  Widget build(BuildContext context) {
    return IntroductionScreen(
      pages: [
        PageViewModel(
          title: "Welcome",
          body: "Create and manage quizzes effortlessly.",
          image: Center(child: Icon(Icons.quiz, size: 120)),
        ),
        PageViewModel(
          title: "Invite Friends",
          body: "Share a link or code and play together.",
          image: Center(child: Icon(Icons.people, size: 120)),
        ),
        PageViewModel(
          title: "Track Results",
          body: "Get real-time scoreboards and rankings.",
          image: Center(child: Icon(Icons.leaderboard, size: 120)),
        ),
      ],
      onDone: () => _completeOnboarding(context),
      onSkip: () => _completeOnboarding(context),
      showSkipButton: true,
      skip: const Text("Skip"),
      next: const Icon(Icons.arrow_forward),
      done: const Text("Done", style: TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
