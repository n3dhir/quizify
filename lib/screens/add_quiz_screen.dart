import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

  void _removeQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
    });
  }

  Future<void> _pickImage(int index) async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes(); // <-- Uint8List
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

  Future<void> _createQuiz() async {
  if (_quizTitleController.text.trim().isEmpty || _questions.isEmpty || !_questions.every((q) => _isQuestionValid(q))) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Please ensure your quiz is valid.",
          style: TextStyle(color: Theme.of(context).colorScheme.onError),
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
    return;
  }

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
      });
    }

    await quizRef.set({
      'title': _quizTitleController.text, // add more metadata if needed
      'createdAt': FieldValue.serverTimestamp(),
      'questions': questionList,
      'creator_id': FirebaseAuth.instance.currentUser?.uid
    });

    Navigator.pop(context);

  } catch (e) {
    print("Error creating quiz: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Failed to create quiz."),
        backgroundColor: Colors.red,
      ),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  title: SizedBox(
    height: 40,
    child: TextField(
      controller: _quizTitleController,
      style: TextStyle(
        fontSize: 20,
        // color: Colors.white,
        color: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.bold,
      ),
      // cursorColor: Colors.white,
      // textAlign: TextAlign.center,
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: 'Enter Quiz Title',
        hintStyle: TextStyle(color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.5)),
        contentPadding: EdgeInsets.zero,
      ),
    ),
  ),
  // centerTitle: true,
  // backgroundColor: Colors.deepPurple,
),

      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _questions.length,
              itemBuilder: (context, index) {
                final q = _questions[index];
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Question ${index + 1} / ${_questions.length}",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  onPressed:
                                      _questions.length > 1
                                          ? () => _removeQuestion(index)
                                          : null,
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                begin: 0.0,
                                end: (index + 1) / _questions.length,
                              ),
                              duration: Duration(
                                milliseconds: 500,
                              ), // <-- adjust for smoother/slower
                              curve:
                                  Curves
                                      .easeInOut, // <-- makes it look smoother
                              builder: (context, value, child) {
                                return LinearProgressIndicator(
                                  value: value,
                                  backgroundColor: Colors.grey.shade300,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.deepPurple,
                                  ),
                                  minHeight: 6,
                                );
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        q['image'] == null
                            ? InkWell(
                              onTap: () => _pickImage(index),
                              child: DottedBorder(
                                borderType: BorderType.RRect,
                                radius: Radius.circular(12),
                                dashPattern: [8, 4],
                                color: Colors.deepPurple,
                                strokeWidth: 2,
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.image,
                                        size: 32,
                                        color: Colors.deepPurple,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        "Upload Image",
                                        style: TextStyle(
                                          color: Colors.deepPurple,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                            : Stack(
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
                                // Edit Button
                                // EDIT BUTTON
                                Positioned(
                                  top: 8,
                                  right: 48,
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurple.shade50
                                            .withOpacity(0.9),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.deepPurple
                                                .withOpacity(0.2),
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Tooltip(
                                        message: "Change Image",
                                        child: IconButton(
                                          icon: Icon(
                                            Icons.edit_outlined,
                                            color: Colors.deepPurple,
                                            size: 18,
                                          ),
                                          onPressed: () => _pickImage(index),
                                          splashRadius: 18,
                                          padding: EdgeInsets.zero,
                                          constraints: BoxConstraints(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // DELETE BUTTON
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurple.shade50
                                            .withOpacity(0.9),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.deepPurple
                                                .withOpacity(0.2),
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Tooltip(
                                        message: "Delete Image",
                                        child: IconButton(
                                          icon: Icon(
                                            Icons.delete_outline,
                                            color: Colors.deepPurple,
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              q['image'] = null;
                                            });
                                          },
                                          splashRadius: 18,
                                          padding: EdgeInsets.zero,
                                          constraints: BoxConstraints(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        SizedBox(height: 16),
                        TextField(
                          controller: q['question'],
                          decoration: InputDecoration(
                            labelText: 'Enter question',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            if (_debounce?.isActive ?? false)
                              _debounce?.cancel();
                            _debounce = Timer(Duration(milliseconds: 300), () {
                              setState(() {
                                // Trigger re-evaluation of the validity after a delay
                              });
                            });
                          },
                        ),
                        SizedBox(height: 16),
                        for (int i = 0; i < q['options'].length; i++)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: TextField(
                              controller: q['options'][i],
                              decoration: InputDecoration(
                                labelText: 'Option ${i + 1}',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                if (_debounce?.isActive ?? false)
                                  _debounce?.cancel();
                                _debounce = Timer(
                                  Duration(milliseconds: 300),
                                  () {
                                    setState(() {
                                      // Trigger re-evaluation of the validity after a delay
                                    });
                                  },
                                );
                              },
                            ),
                            leading: Radio(
                              value: i,
                              groupValue: q['correctAnswerIndex'],
                              onChanged: (value) {
                                setState(() {
                                  q['correctAnswerIndex'] = value;
                                });
                              },
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.deepPurple,
                              ),
                              onPressed:
                                  q['options'].length > 2
                                      ? () {
                                        setState(() {
                                          // Remove the option at the selected index
                                          q['options'].removeAt(i);
                                        });
                                      }
                                      : null,
                            ),
                          ),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              q['options'].add(TextEditingController());
                            });
                          },
                          icon: Icon(Icons.add),
                          label: Text("Add Option"),
                          style: ElevatedButton.styleFrom(
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                            backgroundColor:
                                Colors.deepPurple, // Purplish background color
                            // padding: EdgeInsets.all(16),
                            padding: EdgeInsets.fromLTRB(8, 16, 16, 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                8,
                              ), // Roundish border
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: SmoothPageIndicator(
              controller: _pageController,
              count: _questions.length,
              effect: WormEffect(
                dotHeight: 10,
                dotWidth: 10,
                activeDotColor: Colors.deepPurple,
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

          SizedBox(height: 16),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              onPressed:
                  _questions.isNotEmpty && _isQuestionValid(_questions.last)
                      ? _addNewQuestion
                      : null,
              backgroundColor:
                  _questions.isNotEmpty && _isQuestionValid(_questions.last)
                      ? Colors.deepPurple
                      : Colors.grey,
              child: Icon(Icons.add),
            ),
            SizedBox(width: 12),
            FloatingActionButton(
              onPressed:
                  _questions.isNotEmpty &&
                          _questions.every((q) => _isQuestionValid(q))
                      ? _createQuiz
                      : null,
              backgroundColor:
                  _questions.isNotEmpty &&
                          _questions.every((q) => _isQuestionValid(q))
                      ? Colors.deepPurple
                      : Colors.grey,
              child: Icon(Icons.check),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
