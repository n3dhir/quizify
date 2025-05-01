import 'dart:math';
import 'dart:io';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:quizify/services/quizz_service.dart';
import 'package:share_plus/share_plus.dart';

class QuizEditScreen extends StatefulWidget {
  final String quizId;

  const QuizEditScreen({super.key, required this.quizId});

  @override
  State<QuizEditScreen> createState() => _QuizEditScreenState();
}

class _QuizEditScreenState extends State<QuizEditScreen> {
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _hasChanges = false;

  final TextEditingController _quizTitleController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _questions = [];
  String _quizCode = '';

  @override
  void initState() {
    super.initState();
    _loadQuizData();
  }

  Future<void> _loadQuizData() async {
    setState(() => _isLoading = true);
    try {
      final quizDoc =
          await FirebaseFirestore.instance
              .collection('quizzes')
              .doc(widget.quizId)
              .get();
      if (!quizDoc.exists && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Quiz not found')));
        context.go('/app/creator/home');
        return;
      }
      final data = quizDoc.data()!;
      _quizTitleController.text = data['title'] ?? '';
      _quizCode = data['quiz_code'] ?? '';

      final loaded = <Map<String, dynamic>>[];
      for (var q in data['questions']) {
        final qm = Map<String, dynamic>.from(q);
        final questionCtrl = TextEditingController(text: qm['question']);
        final optionsCtrls = <TextEditingController>[];
        for (var o in qm['options']) {
          optionsCtrls.add(TextEditingController(text: o));
        }
        loaded.add({
          'question': questionCtrl,
          'options': optionsCtrls,
          'correctAnswerIndex': qm['correctAnswerIndex'] as int,
          'duration': qm['duration'] as int,
          'imageUrl': qm['imageUrl'] as String?,
          'image': null,
        });
      }
      if (mounted)
        setState(() {
          _questions = loaded;
          _isLoading = false;
          _hasChanges = false;
        });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load quiz')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage(int index) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() async {
      _questions[index]['image'] =
          kIsWeb ? await picked.readAsBytes() : File(picked.path);
      _questions[index]['imageUrl'] = null;
      _hasChanges = true;
    });
  }

  Future<void> _saveQuizChanges() async {
    if (!_hasChanges) return;
    setState(() => _isSaving = true);
    try {
      final ref = FirebaseFirestore.instance
          .collection('quizzes')
          .doc(widget.quizId);
      final updatedQuestions = <Map<String, dynamic>>[];
      for (int i = 0; i < _questions.length; i++) {
        final q = _questions[i];
        String? imageUrl = q['imageUrl'];
        if (q['image'] != null) {
          imageUrl = await uploadImageToBytescale(q['image'], widget.quizId, i);
        }
        updatedQuestions.add({
          'question': q['question'].text,
          'options': q['options'].map((c) => c.text).toList(),
          'correctAnswerIndex': q['correctAnswerIndex'],
          'duration': q['duration'],
          'imageUrl': imageUrl,
        });
      }
      await ref.update({
        'title': _quizTitleController.text,
        'questions': updatedQuestions,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Quiz updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _isEditing = false;
        _hasChanges = false;
      });
      _loadQuizData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update quiz.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteQuiz() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('quizzes')
          .doc(widget.quizId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Quiz deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
      context.go('/app/creator/home');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete quiz'),
          backgroundColor: Colors.red,
        ),
      );
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleEditMode() {
    if (_isEditing && _hasChanges) {
      showDialog(
        context: context,
        builder:
            (c) => AlertDialog(
              title: Text('Save Changes'),
              content: Text(
                'Would you like to save your changes before exiting edit mode?',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(c).pop();
                    setState(() {
                      _isEditing = false;
                      _loadQuizData();
                    });
                  },
                  child: Text('Discard'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(c).pop();
                    _saveQuizChanges();
                  },
                  child: Text('Save'),
                ),
              ],
            ),
      );
    } else {
      setState(() => _isEditing = !_isEditing);
    }
  }

  void _addQuestion() {
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;
    return WillPopScope(
      onWillPop: () async {
        if (_isEditing && _hasChanges) {
          final save = await showDialog<bool>(
            context: context,
            builder:
                (c) => AlertDialog(
                  title: Text('Unsaved Changes'),
                  content: Text(
                    'You have unsaved changes. Would you like to save them before leaving?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(c).pop(false),
                      child: Text('Discard'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(c).pop(true),
                      child: Text('Save'),
                    ),
                  ],
                ),
          );
          if (save == true) await _saveQuizChanges();
        }
        context.go('/app/creator/home');
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              if (_isEditing && _hasChanges) {
                _toggleEditMode();
              } else {
                context.go('/app/creator/home');
              }
            },
          ),
          title:
              _isEditing
                  ? TextField(
                    controller: _quizTitleController,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Quiz Title',
                    ),
                    onChanged: (_) => _hasChanges = true,
                  )
                  : Text(_quizTitleController.text),
          actions: [
            if (!_isLoading)
              _isEditing
                  ? (_isSaving
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
                        label: Text('Save'),
                      ))
                  : TextButton.icon(
                    onPressed: _toggleEditMode,
                    icon: Icon(Icons.edit),
                    label: Text('Edit'),
                  ),
            if (!_isLoading && !_isEditing)
              IconButton(
                icon: Icon(Icons.delete_outline),
                onPressed: _deleteQuiz,
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
                      if (!_isEditing) _buildShareSection(),
                      Center(
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: isDesktop ? 800 : double.infinity,
                          ),
                          child: Column(
                            children: List.generate(
                              _questions.length,
                              (i) => _buildQuestionCard(_questions[i], i),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        floatingActionButton:
            _isEditing
                ? FloatingActionButton.extended(
                  onPressed: _addQuestion,
                  icon: Icon(Icons.add),
                  label: Text('Add Question'),
                  backgroundColor: Colors.blue,
                )
                : null,
      ),
    );
  }

  Widget _buildShareSection() {
    return Card(
      margin: EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share Quiz',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.qr_code, color: Colors.blue),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quiz Code',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      Text(
                        _quizCode,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Quiz code copied to clipboard')),
                    );
                  },
                  icon: Icon(Icons.copy),
                  label: Text('Copy'),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      // get the share sheet’s position (optional; improves tablet/UI placement)
                      final box = context.findRenderObject() as RenderBox?;
                      await SharePlus.instance.share(
                        ShareParams(
                          text:
                              'Join my quiz on Quizify!\nQuiz Code: $_quizCode\nhttps://quizify.app/play?code=$_quizCode',
                          subject: 'Quizify Quiz Invite',
                          sharePositionOrigin:
                              box!.localToGlobal(Offset.zero) & box!.size,
                        ),
                      );
                    },
                    icon: Icon(Icons.share),
                    label: Text('Share Quiz'),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        () => ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Starting quiz...')),
                        ),
                    icon: Icon(Icons.play_arrow),
                    label: Text('Start Quiz'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> q, int index) {
    final isEditing = _isEditing;
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
                  'Question ${index + 1}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                if (isEditing)
                  IconButton(
                    onPressed:
                        _questions.length > 1
                            ? () => setState(() {
                              _questions.removeAt(index);
                              _hasChanges = true;
                            })
                            : null,
                    icon: Icon(Icons.delete_outline_rounded),
                    color: Colors.red[400],
                    tooltip: 'Delete question',
                  ),
              ],
            ),
            SizedBox(height: 16),
            if (q['imageUrl'] != null || q['image'] != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child:
                        q['image'] != null
                            ? (kIsWeb
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
                                ))
                            : Image.network(
                              q['imageUrl']!,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              loadingBuilder: (c, child, progress) {
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
                              errorBuilder:
                                  (c, e, s) => Container(
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
                                  ),
                            ),
                  ),
                  if (isEditing)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _pickImage(index),
                            icon: Icon(Icons.edit_outlined, size: 18),
                            label: Text('Change Image'),
                          ),
                          SizedBox(width: 8),
                          TextButton.icon(
                            onPressed:
                                () => setState(() {
                                  q['imageUrl'] = null;
                                  q['image'] = null;
                                  _hasChanges = true;
                                }),
                            icon: Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.red,
                            ),
                            label: Text(
                              'Remove',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 16),
                ],
              )
            else if (isEditing)
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
                        'Add an image',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              ),
            SizedBox(height: 16),
            Text(
              'Question',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            isEditing
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
                  onChanged: (_) => _hasChanges = true,
                )
                : Text(q['question'].text, style: TextStyle(fontSize: 16)),
            SizedBox(height: 20),
            Text(
              'Answer Options',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            ...List.generate(q['options'].length, (optIdx) {
              return Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child:
                        isEditing
                            ? _buildEditOptionTile(q, optIdx)
                            : _buildViewOptionTile(q, optIdx),
                  )
                  .animate(delay: (optIdx * 50).ms)
                  .fadeIn()
                  .slideY(begin: 0.1, end: 0, curve: Curves.easeOut);
            }),
            if (isEditing)
              TextButton.icon(
                onPressed:
                    () => setState(() {
                      q['options'].add(TextEditingController());
                      _hasChanges = true;
                    }),
                icon: Icon(Icons.add_circle_outline),
                label: Text('Add Option'),
              ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.timer_outlined, color: Colors.grey[600], size: 18),
                SizedBox(width: 8),
                Text('Time Limit: ', style: TextStyle(color: Colors.grey[600])),
                Text(
                  '${q['duration']} seconds',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (isEditing)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
                    activeTrackColor: Colors.blue,
                  ),
                  child: Slider(
                    value: (q['duration'] as int).toDouble(),
                    min: 10,
                    max: 60,
                    divisions: 10,
                    label: q['duration'].toString(),
                    onChanged:
                        (val) => setState(() {
                          q['duration'] = val.toInt();
                          _hasChanges = true;
                        }),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditOptionTile(Map<String, dynamic> q, int idx) {
    return Container(
      decoration: BoxDecoration(
        color:
            q['correctAnswerIndex'] == idx
                ? Colors.green.withOpacity(0.1)
                : Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color:
              q['correctAnswerIndex'] == idx
                  ? Colors.green.withOpacity(0.3)
                  : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Radio<int>(
            value: idx,
            groupValue: q['correctAnswerIndex'] as int,
            onChanged:
                (val) => setState(() {
                  q['correctAnswerIndex'] = val!;
                  _hasChanges = true;
                }),
            activeColor: Colors.green,
          ),
          Expanded(
            child: TextField(
              controller: q['options'][idx] as TextEditingController,
              decoration: InputDecoration(
                hintText: 'Option ${idx + 1}',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (_) => _hasChanges = true,
            ),
          ),
          if ((q['options'] as List).length > 2)
            IconButton(
              icon: Icon(Icons.remove_circle_outline, color: Colors.red[400]),
              onPressed:
                  () => setState(() {
                    q['options'].removeAt(idx);
                    if (q['correctAnswerIndex'] >= idx) {
                      q['correctAnswerIndex'] = max(
                        0,
                        q['correctAnswerIndex'] - 1,
                      );
                    }
                    _hasChanges = true;
                  }),
            ),
        ],
      ),
    );
  }

  Widget _buildViewOptionTile(Map<String, dynamic> q, int idx) {
    final isCorrect = q['correctAnswerIndex'] == idx;
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
              q['options'][idx].text,
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
}
