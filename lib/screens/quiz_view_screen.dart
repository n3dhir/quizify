import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:quizify/services/quizz_service.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';

class QuizViewScreen extends StatefulWidget {
  final String quizId;

  const QuizViewScreen({super.key, required this.quizId});

  @override
  State<QuizViewScreen> createState() => _QuizViewScreenState();
}

class _QuizViewScreenState extends State<QuizViewScreen> {
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _hasChanges = false;

  final TextEditingController _quizTitleController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  Timer? _debounce;

  List<Map<String, dynamic>> _questions = [];
  Map<String, dynamic>? _originalQuizData;
  List<Widget> _questionWidgets = [];
  String _quizCode = '';

  @override
  void initState() {
    super.initState();
    _loadQuizData();
  }

  Future<void> _loadQuizData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final quizDoc =
          await FirebaseFirestore.instance
              .collection('quizzes')
              .doc(widget.quizId)
              .get();

      if (!quizDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Quiz not found')));
          context.go('/app/creator/home');
          return;
        }
      }

      final quizData = quizDoc.data() as Map<String, dynamic>;
      _originalQuizData = Map<String, dynamic>.from(quizData);
      _quizTitleController.text = quizData['title'] ?? 'Untitled Quiz';
      _quizCode = quizData['quiz_code'] ?? 'Unknown Code';

      // Initialize the questions from Firestore
      List<Map<String, dynamic>> loadedQuestions = [];

      for (var question in quizData['questions']) {
        final questionMap = Map<String, dynamic>.from(question);
        final questionController = TextEditingController(
          text: questionMap['question'],
        );

        List<TextEditingController> optionControllers = [];
        for (var option in questionMap['options']) {
          optionControllers.add(TextEditingController(text: option));
        }

        loadedQuestions.add({
          'question': questionController,
          'options': optionControllers,
          'correctAnswerIndex': questionMap['correctAnswerIndex'],
          'duration': questionMap['duration'],
          'imageUrl': questionMap['imageUrl'],
          'image': null,
        });
      }

      if (mounted) {
        setState(() {
          _questions = loadedQuestions;
          _isLoading = false;
          _buildQuestionWidgets();
        });
      }
    } catch (e) {
      print('Error loading quiz: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load quiz')));
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _buildQuestionWidgets() {
    _questionWidgets = [];
    for (int i = 0; i < _questions.length; i++) {
      _questionWidgets.add(_buildQuestionCard(_questions[i], i));
    }
  }

  Future<void> _pickImage(int index) async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _questions[index]['image'] = bytes;
          _questions[index]['imageUrl'] = null; // Clear the old URL
          _hasChanges = true;
          _buildQuestionWidgets();
        });
      } else {
        setState(() {
          _questions[index]['image'] = File(pickedFile.path);
          _questions[index]['imageUrl'] = null; // Clear the old URL
          _hasChanges = true;
          _buildQuestionWidgets();
        });
      }
    }
  }

  Future<void> _saveQuizChanges() async {
    if (!_hasChanges) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final quizRef = firestore.collection('quizzes').doc(widget.quizId);

      List<Map<String, dynamic>> questionList = [];

      for (int i = 0; i < _questions.length; i++) {
        var q = _questions[i];
        String? imageUrl = q['imageUrl'];

        if (q['image'] != null) {
          imageUrl = await uploadImageToBytescale(q['image'], widget.quizId, i);
        }

        questionList.add({
          'question': q['question'].text,
          'imageUrl': imageUrl,
          'options': q['options'].map((c) => c.text).toList(),
          'correctAnswerIndex': q['correctAnswerIndex'],
          'duration': q['duration'],
        });
      }

      await quizRef.update({
        'title': _quizTitleController.text,
        'questions': questionList,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Quiz updated successfully!"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      setState(() {
        _hasChanges = false;
        _isEditing = false;
      });

      // Reload quiz data to refresh the view
      _loadQuizData();
    } catch (e) {
      print("Error updating quiz: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to update quiz. Please try again."),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _confirmDeleteQuiz() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text("Delete Quiz"),
            content: Text(
              "Are you sure you want to delete this quiz? This action cannot be undone.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text("Cancel"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _deleteQuiz();
                },
                child: Text("Delete", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteQuiz() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('quizzes')
          .doc(widget.quizId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Quiz deleted successfully"),
          backgroundColor: Colors.green,
        ),
      );

      context.go('/app/creator/home');
    } catch (e) {
      print("Error deleting quiz: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to delete quiz"),
          backgroundColor: Colors.red,
        ),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildQuestionCard(Map<String, dynamic> q, int index) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  "Question ${index + 1}",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                if (_isEditing)
                  IconButton(
                    onPressed:
                        _questions.length > 1
                            ? () {
                              setState(() {
                                _questions.removeAt(index);
                                _hasChanges = true;
                                _buildQuestionWidgets();
                              });
                            }
                            : null,
                    icon: Icon(Icons.delete_outline_rounded),
                    color: Colors.red[400],
                    tooltip: 'Delete question',
                  ),
              ],
            ),
            SizedBox(height: 16),

            // Image Section
            if (q['imageUrl'] != null || q['image'] != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child:
                        q['image'] != null
                            ? kIsWeb
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
                                )
                            : q['imageUrl'] != null
                            ? Image.network(
                              q['imageUrl'],
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  height: 200,
                                  width: double.infinity,
                                  color: Colors.grey[200],
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value:
                                          progress.expectedTotalBytes != null
                                              ? progress.cumulativeBytesLoaded /
                                                  progress.expectedTotalBytes!
                                              : null,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 200,
                                  width: double.infinity,
                                  color: Colors.grey[200],
                                  child: Center(
                                    child: Icon(
                                      Icons.error_outline,
                                      color: Colors.red,
                                      size: 40,
                                    ),
                                  ),
                                );
                              },
                            )
                            : SizedBox(),
                  ),
                  if (_isEditing)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _pickImage(index),
                            icon: Icon(Icons.edit_outlined, size: 18),
                            label: Text("Change Image"),
                          ),
                          SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                q['imageUrl'] = null;
                                q['image'] = null;
                                _hasChanges = true;
                                _buildQuestionWidgets();
                              });
                            },
                            icon: Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.red,
                            ),
                            label: Text(
                              "Remove",
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 16),
                ],
              )
            else if (_isEditing)
              InkWell(
                onTap: () => _pickImage(index),
                child: Container(
                  width: double.infinity,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        color: Colors.blue,
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Add an image",
                        style: TextStyle(color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              ),

            SizedBox(height: 16),

            // Question Text
            Text(
              "Question",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            _isEditing
                ? TextField(
                  controller: q['question'],
                  decoration: InputDecoration(
                    hintText: 'Enter your question here...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: EdgeInsets.all(12),
                  ),
                  maxLines: 2,
                  onChanged: (value) {
                    _hasChanges = true;
                  },
                )
                : Text(q['question'].text, style: TextStyle(fontSize: 16)),
            SizedBox(height: 20),

            // Options
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
                    child:
                        _isEditing
                            ? _buildEditOptionTile(q, i)
                            : _buildViewOptionTile(q, i),
                  )
                  .animate(delay: (i * 50).ms)
                  .fadeIn()
                  .slideY(begin: 0.1, end: 0, curve: Curves.easeOut);
            }),

            if (_isEditing)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    q['options'].add(TextEditingController());
                    _hasChanges = true;
                    _buildQuestionWidgets();
                  });
                },
                icon: Icon(Icons.add_circle_outline),
                label: Text("Add Option"),
              ),

            SizedBox(height: 12),

            // Duration
            Row(
              children: [
                Icon(Icons.timer_outlined, color: Colors.grey[600], size: 18),
                SizedBox(width: 8),
                Text("Time Limit: ", style: TextStyle(color: Colors.grey[600])),
                Text(
                  "${q['duration']} seconds",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),

            if (_isEditing)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
                    activeTrackColor: Colors.blue,
                  ),
                  child: Slider(
                    value: q['duration'].toDouble(),
                    min: 10,
                    max: 60,
                    divisions: 10,
                    label: q['duration'].toString(),
                    onChanged: (value) {
                      setState(() {
                        q['duration'] = value.toInt();
                        _hasChanges = true;
                      });
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditOptionTile(Map<String, dynamic> q, int index) {
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
                  : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Radio(
            value: index,
            groupValue: q['correctAnswerIndex'],
            onChanged: (value) {
              setState(() {
                q['correctAnswerIndex'] = value;
                _hasChanges = true;
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
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) {
                _hasChanges = true;
              },
            ),
          ),
          if (q['options'].length > 2)
            IconButton(
              icon: Icon(Icons.remove_circle_outline, color: Colors.red[400]),
              onPressed: () {
                setState(() {
                  q['options'].removeAt(index);
                  if (q['correctAnswerIndex'] >= index) {
                    q['correctAnswerIndex'] = max(
                      0,
                      q['correctAnswerIndex'] - 1,
                    );
                  }
                  _hasChanges = true;
                  _buildQuestionWidgets();
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildViewOptionTile(Map<String, dynamic> q, int index) {
    final isCorrect = q['correctAnswerIndex'] == index;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: isCorrect ? Colors.green.withOpacity(0.1) : Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCorrect ? Colors.green : Colors.grey[300]!,
          width: isCorrect ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          isCorrect
              ? Icon(Icons.check_circle, color: Colors.green, size: 20)
              : Icon(Icons.circle_outlined, color: Colors.grey[400], size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              q['options'][index].text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isCorrect ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleEditMode() {
    if (_isEditing && _hasChanges) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text("Save Changes"),
              content: Text(
                "Would you like to save your changes before exiting edit mode?",
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _isEditing = false;
                      _loadQuizData(); // Reload original data
                    });
                  },
                  child: Text("Discard"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _saveQuizChanges().then((_) {
                      setState(() {
                        _isEditing = false;
                      });
                    });
                  },
                  child: Text("Save"),
                ),
              ],
            ),
      );
    } else {
      setState(() {
        _isEditing = !_isEditing;
      });
    }
  }

  void _addNewQuestion() {
    setState(() {
      _questions.add({
        'question': TextEditingController(),
        'options': [TextEditingController(), TextEditingController()],
        'correctAnswerIndex': 0,
        'duration': 30,
        'imageUrl': null,
        'image': null,
      });
      _hasChanges = true;
      _buildQuestionWidgets();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;

    return WillPopScope(
      onWillPop: () async {
        if (_isEditing && _hasChanges) {
          final result = await showDialog<bool>(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: Text("Unsaved Changes"),
                  content: Text(
                    "You have unsaved changes. Would you like to save them before leaving?",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text("Discard"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text("Save"),
                    ),
                  ],
                ),
          );

          if (result == true) {
            await _saveQuizChanges();
          }
        }
        context.go('/app/creator/home');
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title:
              _isEditing
                  ? TextField(
                    controller: _quizTitleController,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Quiz Title',
                    ),
                    onChanged: (_) {
                      _hasChanges = true;
                    },
                  )
                  : Text(_quizTitleController.text),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              if (_isEditing && _hasChanges) {
                showDialog(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: Text("Unsaved Changes"),
                        content: Text(
                          "You have unsaved changes. Would you like to save them before leaving?",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              context.go('/app/creator/home');
                            },
                            child: Text("Discard"),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _saveQuizChanges().then((_) {
                                context.go('/app/creator/home');
                              });
                            },
                            child: Text("Save"),
                          ),
                        ],
                      ),
                );
              } else {
                context.go('/app/creator/home');
              }
            },
          ),
          actions: [
            if (!_isLoading && !_isEditing)
              IconButton(
                icon: Icon(Icons.delete_outline),
                onPressed: _confirmDeleteQuiz,
                tooltip: 'Delete Quiz',
              ),
            if (!_isLoading)
              _isEditing
                  ? _isSaving
                      ? Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                      : TextButton.icon(
                        onPressed: _hasChanges ? _saveQuizChanges : null,
                        icon: Icon(Icons.save),
                        label: Text("Save"),
                      )
                  : TextButton.icon(
                    onPressed: _toggleEditMode,
                    icon: Icon(Icons.edit),
                    label: Text("Edit"),
                  ),
          ],
        ),
        body:
            _isLoading
                ? Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: 80),
                  child: Column(
                    children: [
                      // Questions
                      Center(
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: isDesktop ? 800 : double.infinity,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _questionWidgets,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        floatingActionButton:
            _isEditing
                ? FloatingActionButton.extended(
                  onPressed: _addNewQuestion,
                  icon: Icon(Icons.add),
                  label: Text("Add Question"),
                  backgroundColor: Colors.blue,
                )
                : null,
      ),
    );
  }
}
