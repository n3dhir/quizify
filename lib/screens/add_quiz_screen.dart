import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:quizify/services/quizz_service.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class AddQuizScreen extends StatefulWidget {
  const AddQuizScreen({super.key});

  @override
  State<AddQuizScreen> createState() => _AddQuizScreenState();
}

class _AddQuizScreenState extends State<AddQuizScreen> {
  Timer? _debounce;
  bool _isLoading = false;
  final TextEditingController _quizTitleController = TextEditingController();
  final PageController _pageController = PageController();
  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> _questions = [];

  @override
  void initState() {
    super.initState();
    _quizTitleController.text = "Untitled Quiz";
    _addNewQuestion();
  }

  void _addNewQuestion() {
    setState(() {
      _questions.add({
        'question': TextEditingController(),
        'options': [TextEditingController(), TextEditingController()],
        'correctAnswerIndex': 0,
        'duration': 30,
        'image': null,
      });

      Future.delayed(Duration(milliseconds: 200), () {
        _pageController.animateToPage(
          _questions.length - 1,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    });
  }

  bool _isQuestionValid(Map<String, dynamic> question) {
    if (question['question'].text.trim().isEmpty) return false;
    for (var option in question['options']) {
      if (option.text.trim().isEmpty) return false;
    }
    return true;
  }

  Future<void> _removeQuestion(int index) async {
    if (_questions.length <= 1) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text("Delete Question"),
            content: Text("Are you sure you want to delete this question?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text("Delete", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      setState(() {
        _questions.removeAt(index);
        if (index >= _questions.length) {
          _pageController.jumpToPage(_questions.length - 1);
        }
      });
    }
  }

  Future<void> _pickImage(int index) async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _questions[index]['image'] = bytes;
        });
      } else {
        setState(() {
          _questions[index]['image'] = File(pickedFile.path);
        });
      }
    }
  }

  @override
  void dispose() {
    for (var q in _questions) {
      q['question']?.dispose();
      for (var opt in q['options']) {
        opt.dispose();
      }
    }
    _pageController.dispose();
    super.dispose();
  }

  Future<String> generateUniqueQuizCode() async {
    const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rand = Random();
    String quizCode = '';

    for (int i = 0; i < 6; i++) {
      quizCode += characters[rand.nextInt(characters.length)];
    }

    final quizRef = FirebaseFirestore.instance.collection('quizzes');
    final querySnapshot =
        await quizRef.where('quiz_code', isEqualTo: quizCode).get();

    if (querySnapshot.docs.isNotEmpty) {
      return generateUniqueQuizCode();
    }

    return quizCode;
  }

  Future<void> _createQuiz() async {
    if (_quizTitleController.text.trim().isEmpty ||
        _questions.isEmpty ||
        !_questions.every((q) => _isQuestionValid(q))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Please ensure all questions are complete.",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final quizRef = firestore.collection('quizzes').doc();
      final quizId = quizRef.id;

      List<Map<String, dynamic>> questionList = [];

      for (int i = 0; i < _questions.length; i++) {
        var q = _questions[i];
        String? imageUrl;

        if (q['image'] != null) {
          imageUrl = await uploadImageToBytescale(q['image'], quizId, i);
        }

        questionList.add({
          'question': q['question'].text,
          'imageUrl': imageUrl,
          'options': q['options'].map((c) => c.text).toList(),
          'correctAnswerIndex': q['correctAnswerIndex'],
          'duration': q['duration'],
        });
      }

      String quizCode = await generateUniqueQuizCode();

      await quizRef.set({
        'title': _quizTitleController.text,
        'createdAt': FieldValue.serverTimestamp(),
        'questions': questionList,
        'quiz_code': quizCode,
        'creator_id': FirebaseAuth.instance.currentUser?.uid,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Quiz created successfully!"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      context.go("/app/creator/home");
    } catch (e) {
      print("Error creating quiz: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to create quiz. Please try again."),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildQuestionCard(Map<String, dynamic> q, int index) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Question ${index + 1} of ${_questions.length}",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                IconButton(
                  onPressed:
                      _questions.length > 1
                          ? () => _removeQuestion(index)
                          : null,
                  icon: Icon(Icons.delete_outline_rounded),
                  color: Colors.red[400],
                  tooltip: 'Delete question',
                ),
              ],
            ),
            SizedBox(height: 16),

            // Image Upload Section
            _buildImageUploadSection(q, index),
            SizedBox(height: 24),

            // Question Input
            _buildQuestionInput(q),
            SizedBox(height: 24),

            // Options Section
            _buildOptionsSection(q),
            SizedBox(height: 16),

            // Add Option Button
            _buildAddOptionButton(q),
            SizedBox(height: 24),

            // Duration Slider
            _buildDurationSlider(q),
          ],
        ),
      ),
    );
  }

  Widget _buildImageUploadSection(Map<String, dynamic> q, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Question Image (Optional)",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 8),
        if (q['image'] == null)
          InkWell(
            onTap: () => _pickImage(index),
            borderRadius: BorderRadius.circular(12),
            child: DottedBorder(
              borderType: BorderType.RRect,
              radius: Radius.circular(12),
              dashPattern: [8, 4],
              color: Colors.blue.withOpacity(0.7),
              strokeWidth: 2,
              child: Container(
                width: double.infinity,
                height: 150,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 40,
                      color: Colors.blue,
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Click to upload an image",
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Supports JPG, PNG",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child:
                    kIsWeb
                        ? Image.memory(
                          q['image'],
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                        : Image.file(
                          q['image'],
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
              ),
              Positioned(
                bottom: 10,
                right: 10,
                child: Row(
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'edit_$index',
                      onPressed: () => _pickImage(index),
                      backgroundColor: Colors.white,
                      child: Icon(Icons.edit, color: Colors.blue, size: 18),
                    ),
                    SizedBox(width: 8),
                    FloatingActionButton.small(
                      heroTag: 'delete_$index',
                      onPressed: () {
                        setState(() {
                          q['image'] = null;
                        });
                      },
                      backgroundColor: Colors.white,
                      child: Icon(Icons.delete, color: Colors.red, size: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildQuestionInput(Map<String, dynamic> q) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Question Text",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 8),
        TextField(
          controller: q['question'],
          decoration: InputDecoration(
            hintText: 'Enter your question here...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          maxLines: 2,
          onChanged: (value) {
            if (_debounce?.isActive ?? false) _debounce?.cancel();
            _debounce = Timer(Duration(milliseconds: 300), () {
              setState(() {});
            });
          },
        ),
      ],
    );
  }

  Widget _buildOptionsSection(Map<String, dynamic> q) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Answer Options",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 8),
        ...List.generate(q['options'].length, (i) {
          return Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: _buildOptionTile(q, i),
              )
              .animate(delay: (i * 50).ms)
              .fadeIn()
              .slideY(begin: 0.1, end: 0, curve: Curves.easeOut);
        }),
      ],
    );
  }

  Widget _buildOptionTile(Map<String, dynamic> q, int index) {
    return Container(
      decoration: BoxDecoration(
        color:
            q['correctAnswerIndex'] == index
                ? Colors.green.withOpacity(0.1)
                : Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color:
              q['correctAnswerIndex'] == index
                  ? Colors.green.withOpacity(0.3)
                  : Colors.grey[200]!,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Radio(
              value: index,
              groupValue: q['correctAnswerIndex'],
              onChanged: (value) {
                setState(() {
                  q['correctAnswerIndex'] = value;
                });
              },
              activeColor: Colors.green,
            ),
            Expanded(
              child: TextField(
                controller: q['options'][index],
                decoration: InputDecoration(
                  hintText: 'Option ${index + 1}',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 16),
                ),
                onChanged: (value) {
                  if (_debounce?.isActive ?? false) _debounce?.cancel();
                  _debounce = Timer(Duration(milliseconds: 300), () {
                    setState(() {});
                  });
                },
              ),
            ),
            if (q['options'].length > 2)
              IconButton(
                icon: Icon(Icons.remove_circle_outline, color: Colors.red[400]),
                onPressed: () {
                  setState(() {
                    q['options'].removeAt(index);
                    if (q['correctAnswerIndex'] >= q['options'].length) {
                      q['correctAnswerIndex'] = q['options'].length - 1;
                    }
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddOptionButton(Map<String, dynamic> q) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          setState(() {
            q['options'].add(TextEditingController());
          });
        },
        icon: Icon(Icons.add, size: 20),
        label: Text("Add Another Option"),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.blue,
          backgroundColor: Colors.blue[50],
          padding: EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.blue.withOpacity(0.2)),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildDurationSlider(Map<String, dynamic> q) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Time Limit",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "${q['duration']} seconds",
                style: TextStyle(
                  color: Colors.blue[800],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 6,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: Colors.blue,
            inactiveTrackColor: Colors.blue[100],
            thumbColor: Colors.blue,
            overlayColor: Colors.blue.withOpacity(0.2),
          ),
          child: Slider(
            value: q['duration'].toDouble(),
            min: 10,
            max: 60,
            divisions: 10,
            label: q['duration'].toString(),
            onChanged: (double value) {
              setState(() {
                q['duration'] = value.toInt();
              });
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            if (_questions.any((q) => q['question'].text.isNotEmpty)) {
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: Text("Unsaved Changes"),
                      content: Text(
                        "You have unsaved changes. Are you sure you want to leave?",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            context.go('/app/creator/home');
                          },
                          child: Text(
                            "Leave",
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
              );
            } else {
              context.go('/app/creator/home');
            }
          },
        ),
        title: SizedBox(
          height: 40,
          child: TextField(
            controller: _quizTitleController,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Enter Quiz Title',
              hintStyle: TextStyle(color: Colors.grey),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        actions: [
          if (_questions.isNotEmpty &&
              _questions.every((q) => _isQuestionValid(q)))
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _createQuiz,
                icon:
                    _isLoading
                        ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : Icon(Icons.check, size: 20),
                label: Text("Publish Quiz"),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_questions.length > 1)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SmoothPageIndicator(
                controller: _pageController,
                count: _questions.length,
                effect: ExpandingDotsEffect(
                  dotHeight: 8,
                  dotWidth: 8,
                  activeDotColor: Colors.blue,
                  dotColor: Colors.grey[300]!,
                  spacing: 6,
                ),
                onDotClicked: (index) {
                  _pageController.animateToPage(
                    index,
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              ),
            ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _questions.length,
              itemBuilder: (context, index) {
                return SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: 100),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height - 200,
                    ),
                    child:
                        isDesktop
                            ? Center(
                              child: Container(
                                constraints: BoxConstraints(maxWidth: 800),
                                child: _buildQuestionCard(
                                  _questions[index],
                                  index,
                                ),
                              ),
                            )
                            : _buildQuestionCard(_questions[index], index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton:
          _questions.isNotEmpty && _isQuestionValid(_questions.last)
              ? FloatingActionButton.extended(
                onPressed: _addNewQuestion,
                icon: Icon(Icons.add),
                label: Text("Add Question"),
                backgroundColor: Colors.blue,
                elevation: 4,
              )
              : null,
    );
  }
}
