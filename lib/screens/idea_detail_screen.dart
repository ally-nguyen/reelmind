import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/video_idea.dart';
import '../providers/ideas_provider.dart';
import '../providers/auth_provider.dart';
import '../services/idea_generator_service.dart';

class IdeaDetailScreen extends StatefulWidget {
  final VideoIdea idea;
  const IdeaDetailScreen({super.key, required this.idea});

  @override
  State<IdeaDetailScreen> createState() => _IdeaDetailScreenState();
}

class _IdeaDetailScreenState extends State<IdeaDetailScreen> {
  late TextEditingController _titleCtrl;
  late TextEditingController _bodyCtrl;
  Timer? _saveTimer;
  bool _saved = true;
  bool _generating = false;
  String? _lastUserInput;
  final IdeaGeneratorService _generator = IdeaGeneratorService();

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.idea.title);
    _bodyCtrl = TextEditingController(
      text: widget.idea.bullets.join('\n'),
    );
    _titleCtrl.addListener(_onChanged);
    _bodyCtrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (_saved) setState(() => _saved = false);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), _save);
  }

  Future<void> _save() async {
    widget.idea.title = _titleCtrl.text.trim();
    widget.idea.bullets = _bodyCtrl.text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    await context.read<IdeasProvider>().saveIdea(widget.idea);
    if (mounted) setState(() => _saved = true);
  }

  Future<void> _generateBullets() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a title first')),
      );
      return;
    }

    // Ask what they want to talk about, pre-filling last input if available
    final userInput = await showDialog<String>(
      context: context,
      builder: (ctx) => _BulletInputDialog(title: title, initialInput: _lastUserInput),
    );
    if (userInput == null || !mounted) return; // cancelled

    setState(() => _lastUserInput = userInput);

    final uid = context.read<AuthProvider>().firebaseUser?.uid ?? 'preview-user';
    setState(() => _generating = true);
    try {
      final bullets = await _generator.generateBullets(uid, title, userInput: userInput);
      _bodyCtrl.text = bullets.join('\n');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generation failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _delete() async {
    final uid = context.read<AuthProvider>().firebaseUser?.uid ?? 'preview-user';
    final ideasProvider = context.read<IdeasProvider>();
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete idea?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ideasProvider.deleteIdea(uid, widget.idea.id);
      if (mounted) navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () {
            _saveTimer?.cancel();
            final nav = Navigator.of(context);
            _save().then((_) {
              if (mounted) nav.pop();
            });
          },
        ),
        actions: [
          if (_generating)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip: 'Generate bullets with AI',
              onPressed: _generateBullets,
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text(
                _saved ? 'Saved' : 'Saving…',
                style: TextStyle(
                  fontSize: 13,
                  color: _saved ? Colors.grey : Colors.orange,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _delete,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              decoration: const InputDecoration(
                hintText: 'Title',
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _bodyCtrl,
                maxLines: null,
                expands: true,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: Colors.black87,
                ),
                decoration: const InputDecoration(
                  hintText: '• Start writing your bullet points…\n• One per line',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulletInputDialog extends StatefulWidget {
  final String title;
  final String? initialInput;
  const _BulletInputDialog({required this.title, this.initialInput});

  @override
  State<_BulletInputDialog> createState() => _BulletInputDialogState();
}

class _BulletInputDialogState extends State<_BulletInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialInput ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialInput != null ? 'Regenerate talking points' : 'What do you want to talk about?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'e.g. my morning routine, why I switched careers, top 3 tips...',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Generate'),
        ),
      ],
    );
  }
}
