import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/video_idea.dart';
import '../providers/auth_provider.dart';
import '../providers/ideas_provider.dart';
import 'idea_detail_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _currentUid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = Provider.of<AuthProvider>(context).firebaseUser?.uid;
    if (uid != null && uid != _currentUid) {
      _currentUid = uid;
      context.read<IdeasProvider>().listenToIdeas(uid);
    }
  }

  @override
  void dispose() {
    context.read<IdeasProvider>().stopListening();
    super.dispose();
  }

  Future<void> _generateIdea() async {
    final auth = context.read<AuthProvider>();
    final ideas = context.read<IdeasProvider>();
    final uid = auth.firebaseUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not signed in — please sign out and back in')),
      );
      return;
    }

    final drafts = ideas.byStatus(IdeaStatus.draft);

    if (drafts.isEmpty) {
      // No drafts — go straight to full AI generation
      if (auth.profile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile still loading — try again')),
        );
        return;
      }
      await ideas.generateAiIdea(auth.profile!);
      if (mounted && ideas.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generation failed: ${ideas.error}')),
        );
      }
      return;
    }

    if (!mounted) return;

    // Show picker: generate new idea OR pick a draft to generate bullets for
    final choice = await showModalBottomSheet<_GenerateChoice>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _GenerateBottomSheet(drafts: drafts),
    );

    if (choice == null || !mounted) return;

    if (choice.idea == null) {
      // "Generate a brand-new idea" selected
      if (auth.profile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile still loading — try again')),
        );
        return;
      }
      await ideas.generateAiIdea(auth.profile!);
      if (mounted && ideas.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generation failed: ${ideas.error}')),
        );
      }
    } else {
      // Ask the user what they want to talk about before generating
      if (!mounted) return;
      final userInput = await showDialog<String>(
        context: context,
        builder: (ctx) => _BulletInputDialog(title: choice.idea!.title),
      );
      if (userInput == null || !mounted) return; // user cancelled

      await ideas.generateBulletsForIdea(uid, choice.idea!, userInput: userInput);
      if (mounted && ideas.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generation failed: ${ideas.error}')),
        );
      } else if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => IdeaDetailScreen(idea: choice.idea!),
          ),
        );
      }
    }
  }

  Future<void> _newManualIdea() async {
    final uid = context.read<AuthProvider>().firebaseUser?.uid ?? 'preview-user';
    final ideas = context.read<IdeasProvider>();
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
      await ideas.createManualIdea(uid, titleCtrl.text);
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
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: auth.signOut,
          ),
        ],
      ),
      body: ideas.error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error: ${ideas.error}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ideas.ideas.isEmpty
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

class _BulletInputDialog extends StatefulWidget {
  final String title;
  const _BulletInputDialog({required this.title});

  @override
  State<_BulletInputDialog> createState() => _BulletInputDialogState();
}

class _BulletInputDialogState extends State<_BulletInputDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('What do you want to talk about?'),
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

class _GenerateChoice {
  final VideoIdea? idea; // null = generate brand-new
  const _GenerateChoice({this.idea});
}

class _GenerateBottomSheet extends StatelessWidget {
  final List<VideoIdea> drafts;
  const _GenerateBottomSheet({required this.drafts});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Generate with AI',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pick a draft to write bullet points for, or let AI create a whole new idea.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                child: Icon(Icons.auto_awesome),
              ),
              title: const Text('Generate a brand-new idea'),
              subtitle: const Text('AI picks the topic and bullet points'),
              onTap: () => Navigator.pop(context, const _GenerateChoice()),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Or generate bullet points for a draft:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: drafts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (ctx, i) {
                  final idea = drafts[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.edit_note),
                    title: Text(idea.title),
                    subtitle: idea.bullets.isEmpty
                        ? const Text('No bullets yet')
                        : Text('${idea.bullets.length} bullet(s)'),
                    onTap: () =>
                        Navigator.pop(context, _GenerateChoice(idea: idea)),
                  );
                },
              ),
            ),
          ],
        ),
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
          backgroundColor: _statusColor(idea.status).withValues(alpha: 0.2),
          side: BorderSide(color: _statusColor(idea.status)),
        ),
        leading: idea.source == IdeaSource.aiGenerated
            ? const Icon(Icons.auto_awesome, size: 20)
            : const Icon(Icons.edit_note, size: 20),
      ),
    );
  }
}
