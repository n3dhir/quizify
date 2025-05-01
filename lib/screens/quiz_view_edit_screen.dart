import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:quizify/services/quizz_service.dart';
import 'package:shimmer/shimmer.dart';

class QuizViewEditScreen extends StatefulWidget {
  final String quizId;

  const QuizViewEditScreen({super.key, required this.quizId});

  @override
  State<QuizViewEditScreen> createState() => _QuizViewEditScreenState();
}

class _QuizViewEditScreenState extends State<QuizViewEditScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();
  bool _isEditing = false;
  bool _isLoading = false;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  String? _imageUrl;
  File? _newImage;
  List<Map<String, dynamic>> _questions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _loadQuizData();
  }

  Future<void> _loadQuizData() async {
    setState(() => _isLoading = true);
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('quizzes')
              .doc(widget.quizId)
              .get();

      if (doc.exists) {
        final data = doc.data()!;
        _titleController.text = data['title'] ?? '';
        _descriptionController.text = data['description'] ?? '';
        _imageUrl = data['imageUrl'];
        _questions = List<Map<String, dynamic>>.from(data['questions'] ?? []);
      }
    } catch (e) {
      print("Error loading quiz: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load quiz data'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _newImage = File(pickedFile.path);
        _imageUrl = null;
      });
    }
  }

  Future<void> _updateQuiz() async {
    setState(() => _isLoading = true);
    try {
      String? updatedImageUrl = _imageUrl;
      if (_newImage != null) {
        updatedImageUrl = await uploadImageToBytescale(
          _newImage!,
          widget.quizId,
          0,
        );
      }

      await FirebaseFirestore.instance
          .collection('quizzes')
          .doc(widget.quizId)
          .update({
            'title': _titleController.text,
            'description': _descriptionController.text,
            'imageUrl': updatedImageUrl,
            'questions': _questions,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Quiz updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() => _isEditing = false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update quiz: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildImageSection() {
    return GestureDetector(
      onTap: _isEditing ? _pickImage : null,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.grey[200],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child:
              _newImage != null
                  ? Image.file(_newImage!, fit: BoxFit.cover)
                  : (_imageUrl != null
                      ? CachedNetworkImage(
                        imageUrl: _imageUrl!,
                        fit: BoxFit.cover,
                        placeholder:
                            (context, url) => Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Container(color: Colors.white),
                            ),
                        errorWidget:
                            (context, url, error) =>
                                Icon(Icons.error, color: Colors.red),
                      )
                      : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt,
                              size: 50,
                              color: Colors.grey[500],
                            ),
                            if (_isEditing)
                              Text(
                                'Tap to add image',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                          ],
                        ),
                      )),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildQuestionList() {
    return ListView.separated(
      padding: EdgeInsets.all(16),
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: _questions.length,
      separatorBuilder: (_, __) => Divider(height: 32),
      itemBuilder: (context, index) {
        final question = _questions[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Question ${index + 1}",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 12),
            Text(
              question['question'] ?? '',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
            SizedBox(height: 16),
            ...List.generate(
              question['options'].length,
              (i) => ListTile(
                leading: Icon(
                  question['correctAnswerIndex'] == i
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  color:
                      question['correctAnswerIndex'] == i
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                ),
                title: Text(question['options'][i]),
              ),
            ),
          ],
        ).animate(delay: (100 * index).ms).slideX();
      },
    );
  }

  Widget _buildEditableQuestion(int index, Map<String, dynamic> question) {
    final questionController = TextEditingController(
      text: question['question'],
    );
    final optionControllers = List<TextEditingController>.from(
      question['options'].map((opt) => TextEditingController(text: opt)),
    );

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: questionController,
                    decoration: InputDecoration(
                      labelText: 'Question ${index + 1}',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => _questions[index]['question'] = value,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () => _removeQuestion(index),
                ),
              ],
            ),
            SizedBox(height: 16),
            ...List.generate(
              optionControllers.length,
              (i) => Row(
                children: [
                  Radio(
                    value: i,
                    groupValue: question['correctAnswerIndex'],
                    onChanged:
                        (value) => setState(() {
                          _questions[index]['correctAnswerIndex'] = value;
                        }),
                  ),
                  Expanded(
                    child: TextField(
                      controller: optionControllers[i],
                      decoration: InputDecoration(
                        labelText: 'Option ${i + 1}',
                        border: OutlineInputBorder(),
                      ),
                      onChanged:
                          (value) => _questions[index]['options'][i] = value,
                    ),
                  ),
                  if (optionControllers.length > 2)
                    IconButton(
                      icon: Icon(Icons.remove),
                      onPressed: () => _removeOption(index, i),
                    ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _addOption(index),
              child: Text('Add Option'),
            ),
          ],
        ),
      ),
    );
  }

  void _addOption(int questionIndex) {
    setState(() {
      _questions[questionIndex]['options'].add('');
    });
  }

  void _removeOption(int questionIndex, int optionIndex) {
    setState(() {
      _questions[questionIndex]['options'].removeAt(optionIndex);
      if (_questions[questionIndex]['correctAnswerIndex'] >= optionIndex) {
        _questions[questionIndex]['correctAnswerIndex'] =
            _questions[questionIndex]['correctAnswerIndex'] - 1;
      }
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
    });
  }

  void _addNewQuestion() {
    setState(() {
      _questions.add({
        'question': '',
        'options': ['', ''],
        'correctAnswerIndex': 0,
        'duration': 30,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Quiz' : 'Quiz Details',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: Icon(Icons.edit, color: colorScheme.onSurface),
              onPressed: () => setState(() => _isEditing = true),
            ),
          if (_isEditing)
            IconButton(
              icon:
                  _isLoading
                      ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: colorScheme.onPrimary,
                          strokeWidth: 3,
                        ),
                      )
                      : Icon(Icons.save, color: colorScheme.onSurface),
              onPressed: _isLoading ? null : _updateQuiz,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurface.withOpacity(0.6),
          indicatorColor: colorScheme.primary,
          tabs: [Tab(text: 'Overview'), Tab(text: 'Questions')],
        ),
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : TabBarView(
                controller: _tabController,
                children: [
                  // Overview Tab
                  SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child:
                        isDesktop
                            ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 2, child: _buildImageSection()),
                                SizedBox(width: 20),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      TextField(
                                        controller: _titleController,
                                        enabled: _isEditing,
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.headlineSmall,
                                        decoration: InputDecoration(
                                          border:
                                              _isEditing
                                                  ? OutlineInputBorder()
                                                  : InputBorder.none,
                                          hintText: 'Quiz Title',
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      TextField(
                                        controller: _descriptionController,
                                        enabled: _isEditing,
                                        maxLines: 3,
                                        style: TextStyle(fontSize: 16),
                                        decoration: InputDecoration(
                                          border:
                                              _isEditing
                                                  ? OutlineInputBorder()
                                                  : InputBorder.none,
                                          hintText: 'Quiz Description',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                            : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildImageSection(),
                                SizedBox(height: 20),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      TextField(
                                        controller: _titleController,
                                        enabled: _isEditing,
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.titleLarge,
                                        decoration: InputDecoration(
                                          border:
                                              _isEditing
                                                  ? OutlineInputBorder()
                                                  : InputBorder.none,
                                          hintText: 'Quiz Title',
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      TextField(
                                        controller: _descriptionController,
                                        enabled: _isEditing,
                                        maxLines: 3,
                                        style: TextStyle(fontSize: 16),
                                        decoration: InputDecoration(
                                          border:
                                              _isEditing
                                                  ? OutlineInputBorder()
                                                  : InputBorder.none,
                                          hintText: 'Quiz Description',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                  ),

                  // Questions Tab
                  _isEditing
                      ? SingleChildScrollView(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            ..._questions.asMap().entries.map(
                              (entry) => _buildEditableQuestion(
                                entry.key,
                                entry.value,
                              ),
                            ),
                            ElevatedButton(
                              onPressed: _addNewQuestion,
                              child: Text('Add New Question'),
                            ),
                          ],
                        ),
                      )
                      : _buildQuestionList(),
                ],
              ),
    );
  }
}
