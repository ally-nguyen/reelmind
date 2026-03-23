import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/video_idea.dart';
import '../providers/auth_provider.dart';
import '../providers/ideas_provider.dart';
import 'idea_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    final uid = context.read<AuthProvider>().firebaseUser?.uid ?? 'preview-user';
    context.read<IdeasProvider>().listenToIdeas(uid);
  }

  @override
  void dispose() {
    context.read<IdeasProvider>().stopListening();
    super.dispose();
  }

  Future<void> _generateIdea() async {
    final auth = context.read<AuthProvider>();
    final ideas = context.read<IdeasProvider>();
    if (auth.profile == null) return;
    await ideas.generateAiIdea(auth.profile!);
  }

  Future<void> _newManualIdea() async {
    final uid = context.read<AuthProvider>().firebaseUser?.uid ?? 'preview-user';
    final titleCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Idea'),
        content: TextField(
          controller: titleCtrl,
          decoration: const InputDecoration(hintText: 'Idea title…'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create')),
        ],
      ),
    );
    if (confirmed == true && titleCtrl.text.isNotEmpty) {
      await context.read<IdeasProvider>().createManualIdea(uid, titleCtrl.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final ideas = context.watch<IdeasProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ReelMind'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: auth.signOut,
          ),
        ],
      ),
      body: ideas.ideas.isEmpty
          ? const Center(child: Text('No ideas yet — create one below!'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: ideas.ideas.length,
              itemBuilder: (ctx, i) {
                final idea = ideas.ideas[i];
                return _IdeaCard(idea: idea);
              },
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'ai',
            backgroundColor: Colors.grey,
            onPressed: ideas.generating ? null : _generateIdea,
            icon: ideas.generating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: const Text('Generate for me'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'manual',
            backgroundColor: Colors.grey,
            onPressed: _newManualIdea,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _IdeaCard extends StatelessWidget {
  final VideoIdea idea;
  const _IdeaCard({required this.idea});

  Color _statusColor(IdeaStatus s) => switch (s) {
        IdeaStatus.draft => Colors.grey,
        IdeaStatus.scripted => Colors.blue,
        IdeaStatus.filmed => Colors.orange,
        IdeaStatus.posted => Colors.green,
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => IdeaDetailScreen(idea: idea)),
        ),
        title: Text(idea.title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${idea.bullets.length} bullet(s)'),
        trailing: Chip(
          label: Text(idea.status.name,
              style: const TextStyle(fontSize: 12)),
          backgroundColor: _statusColor(idea.status).withOpacity(0.2),
          side: BorderSide(color: _statusColor(idea.status)),
        ),
        leading: idea.source == IdeaSource.aiGenerated
            ? const Icon(Icons.auto_awesome, size: 20)
            : const Icon(Icons.edit_note, size: 20),
      ),
    );
  }
}
