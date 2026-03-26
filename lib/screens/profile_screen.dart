import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/instagram_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final InstagramService _instagram = InstagramService();
  bool _connecting = false;
  bool _syncing = false;
  String? _error;

  Future<void> _connectInstagram() async {
    final auth = context.read<AuthProvider>();
    final uid = auth.firebaseUser?.uid;
    if (uid == null) return;

    setState(() { _connecting = true; _error = null; });
    try {
      await _instagram.connectInstagram(uid);
      // Auto-sync feed immediately after connecting
      await _instagram.syncFeed(uid);
      await auth.refreshProfile();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _syncFeed() async {
    final auth = context.read<AuthProvider>();
    final uid = auth.firebaseUser?.uid;
    if (uid == null) return;

    setState(() { _syncing = true; _error = null; });
    try {
      await _instagram.syncFeed(uid);
      await auth.refreshProfile();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final connected = profile?.instagramConnected ?? false;
    final taste = profile?.tasteProfile;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── User info ──────────────────────────────────────────────────────
          _SectionCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                  child: Text(
                    (profile?.displayName ?? profile?.email ?? '?')[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6C63FF),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (profile?.displayName != null)
                        Text(profile!.displayName!,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w600)),
                      if (profile?.email != null)
                        Text(profile!.email!,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Instagram connection ───────────────────────────────────────────
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.camera_alt_outlined, size: 22),
                    const SizedBox(width: 10),
                    const Text('Instagram',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (connected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle,
                                size: 13, color: Colors.green),
                            SizedBox(width: 4),
                            Text('Connected',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.green)),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                if (!connected) ...[
                  const Text(
                    'Connect your Instagram to let Claude generate ideas that match your content style and audience.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _connecting ? null : _connectInstagram,
                      icon: _connecting
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.link, size: 18),
                      label: Text(_connecting ? 'Connecting…' : 'Connect Instagram'),
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF)),
                    ),
                  ),
                ] else ...[
                  // Taste profile stats
                  if (taste != null && taste.totalPostsAnalyzed > 0) ...[
                    _StatRow(
                        label: 'Posts analyzed',
                        value: '${taste.totalPostsAnalyzed}'),
                    _StatRow(
                        label: 'Videos (Reels)',
                        value: '${taste.videoCount}'),
                    if (taste.videoTopics.isNotEmpty)
                      _StatRow(
                          label: 'Your video themes',
                          value: taste.videoTopics.take(3).join(', ')),
                    if (taste.likedHashtags.isNotEmpty)
                      _StatRow(
                          label: 'You engage with',
                          value: taste.likedHashtags.take(3).join(', ')),
                    if (taste.lastSynced != null)
                      _StatRow(
                          label: 'Last synced',
                          value: _formatDate(taste.lastSynced!)),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _syncing ? null : _syncFeed,
                      icon: _syncing
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.sync, size: 18),
                      label: Text(_syncing ? 'Syncing…' : 'Sync Feed'),
                    ),
                  ),
                ],

                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!,
                      style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
