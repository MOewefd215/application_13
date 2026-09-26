import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import '../theme/app_theme.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import '../models/chat_models.dart';
import '../services/upload_service.dart';

/// Chat list screen — real conversations from Firestore.
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('แชท')),
      body: uid == null
          ? const EmptyState(
              icon: Icons.lock_outline, message: 'กรุณาเข้าสู่ระบบก่อน')
          : StreamBuilder<List<ChatRoomModel>>(
              stream: ChatService().roomsForUser(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rooms = snapshot.data ?? const [];
                if (rooms.isEmpty) {
                  return const EmptyState(
                    icon: Icons.chat_bubble_outline,
                    message: 'ยังไม่มีบทสนทนา',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rooms.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.border,
                          child: Icon(Icons.person,
                              color: AppColors.textSecondary),
                        ),
                        title: Text(room.jobTitle ?? 'บทสนทนา'),
                        subtitle: Text(
                          room.lastMessage ?? 'ยังไม่มีข้อความ',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ConversationScreen(
                              roomId: room.id,
                              otherUserId: room.otherParticipant(uid),
                              title: room.jobTitle ?? 'บทสนทนา',
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

/// A single conversation — real-time messages via ChatService.
class ConversationScreen extends StatefulWidget {
  /// All optional so this screen still opens standalone (UI gallery).
  /// Pass real values when navigating from a chat room or job detail.
  final String? roomId;
  final String? otherUserId;
  final String title;

  const ConversationScreen({
    super.key,
    this.roomId,
    this.otherUserId,
    this.title = 'ชื่อผู้สนทนา',
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _chatService = ChatService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _uploadingImage = false;
  bool _isRecording = false;
  bool _uploadingVoice = false;
  Duration _recordingElapsed = Duration.zero;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final Stopwatch _recordingClock = Stopwatch();
  Timer? _recordingTimer;

  @override
  void dispose() {
    _recordingTimer?.cancel();
    unawaited(_audioRecorder.dispose());
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null || widget.roomId == null) return;
    final text = _messageController.text;
    if (text.trim().isEmpty) return;
    _messageController.clear();
    await _chatService.sendMessage(
        roomId: widget.roomId!, senderId: uid, text: text);
  }

  Future<void> _pickAndSendImage() async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null || widget.roomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Open a conversation before attaching an image.')),
      );
      return;
    }
    setState(() => _uploadingImage = true);
    try {
      final imageUrl = await UploadService().pickAndUploadImage();
      if (imageUrl == null || !mounted) return;
      await _chatService.sendImageMessage(
        roomId: widget.roomId!,
        senderId: uid,
        imageUrl: imageUrl,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image upload failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _toggleVoiceRecording() async {
    if (_isRecording) {
      await _stopAndSendVoice();
      return;
    }
    if (_uploadingVoice) return;
    final uid = AuthService().currentUser?.uid;
    if (uid == null || widget.roomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Open a conversation before recording.')),
      );
      return;
    }
    try {
      if (!await _audioRecorder.hasPermission()) {
        throw StateError('Microphone permission was denied.');
      }
      final path = Directory.systemTemp.path +
          Platform.pathSeparator +
          'chat_voice_' +
          DateTime.now().microsecondsSinceEpoch.toString() +
          '.m4a';
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      _recordingClock
        ..reset()
        ..start();
      setState(() {
        _recordingElapsed = Duration.zero;
        _isRecording = true;
      });
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _recordingElapsed = _recordingClock.elapsed);
        }
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not start recording: ' + error.toString())),
        );
      }
    }
  }

  Future<void> _stopAndSendVoice() async {
    _recordingTimer?.cancel();
    _recordingClock.stop();
    final duration = _recordingClock.elapsed;
    if (mounted) setState(() => _isRecording = false);
    String? path;
    try {
      path = await _audioRecorder.stop();
      if (path == null) throw StateError('No audio recording was created.');
      if (duration.inMilliseconds < 500) {
        throw StateError('Record for at least half a second before sending.');
      }
      if (mounted) setState(() => _uploadingVoice = true);
      final uid = AuthService().currentUser?.uid;
      if (uid == null || widget.roomId == null) {
        throw StateError('The conversation is no longer available.');
      }
      final audioUrl = await UploadService().uploadAudioFile(File(path));
      await _chatService.sendAudioMessage(
        roomId: widget.roomId!,
        senderId: uid,
        audioUrl: audioUrl,
        durationMs: duration.inMilliseconds,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Could not send voice message: ' + error.toString())),
        );
      }
    } finally {
      if (path != null) {
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
      _recordingClock.reset();
      if (mounted) {
        setState(() {
          _uploadingVoice = false;
          _recordingElapsed = Duration.zero;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService().currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.border,
              child:
                  Icon(Icons.person, color: AppColors.textSecondary, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.title,
                  style: const TextStyle(fontSize: 15),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: widget.roomId == null
                ? const EmptyState(
                    icon: Icons.forum_outlined,
                    message: 'เริ่มต้นบทสนทนาของคุณ',
                  )
                : StreamBuilder<List<ChatMessageModel>>(
                    stream: _chatService.messagesInRoom(widget.roomId!),
                    builder: (context, snapshot) {
                      final messages = snapshot.data ?? const [];
                      if (messages.isEmpty) {
                        return const EmptyState(
                          icon: Icons.forum_outlined,
                          message: 'เริ่มต้นบทสนทนาของคุณ',
                        );
                      }
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_scrollController.hasClients) {
                          _scrollController.jumpTo(
                              _scrollController.position.maxScrollExtent);
                        }
                      });
                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isMe = msg.senderId == myUid;
                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.7),
                              decoration: BoxDecoration(
                                color: isMe ? AppColors.navy : AppColors.card,
                                borderRadius: BorderRadius.circular(16),
                                border: isMe
                                    ? null
                                    : Border.all(color: AppColors.border),
                              ),
                              child: msg.audioUrl != null
                                  ? _VoiceMessageBubble(
                                      audioUrl: msg.audioUrl!,
                                      durationMs: msg.audioDurationMs ?? 0,
                                      isMe: isMe,
                                    )
                                  : msg.imageUrl != null
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.network(
                                            msg.imageUrl!,
                                            width: 220,
                                            height: 220,
                                            fit: BoxFit.cover,
                                            loadingBuilder:
                                                (context, child, progress) {
                                              if (progress == null)
                                                return child;
                                              return const SizedBox(
                                                width: 220,
                                                height: 220,
                                                child: Center(
                                                    child:
                                                        CircularProgressIndicator()),
                                              );
                                            },
                                          ),
                                        )
                                      : Text(
                                          msg.text,
                                          style: TextStyle(
                                              color: isMe
                                                  ? Colors.white
                                                  : AppColors.textPrimary),
                                        ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          if (_isRecording)
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.fiber_manual_record,
                      color: Colors.red, size: 14),
                  const SizedBox(width: 8),
                  Text('Recording ' +
                      _formatAudioDuration(_recordingElapsed.inMilliseconds)),
                  const Spacer(),
                  const Text('Tap stop to send'),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  icon: _uploadingImage
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.add_circle_outline),
                  onPressed: _uploadingImage ? null : _pickAndSendImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration:
                        const InputDecoration(hintText: 'พิมพ์ข้อความ...'),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                IconButton(
                  tooltip: _isRecording
                      ? 'Stop and send voice message'
                      : 'Record voice message',
                  onPressed: _uploadingVoice ? null : _toggleVoiceRecording,
                  icon: _uploadingVoice
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _isRecording
                              ? Icons.stop_circle_outlined
                              : Icons.mic_none,
                          color: _isRecording ? Colors.red : null,
                        ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppColors.navy,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: _send,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceMessageBubble extends StatefulWidget {
  const _VoiceMessageBubble({
    required this.audioUrl,
    required this.durationMs,
    required this.isMe,
  });

  final String audioUrl;
  final int durationMs;
  final bool isMe;

  @override
  State<_VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<_VoiceMessageBubble> {
  late final AudioPlayer _player;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_busy) return;
    if (_player.playing) {
      await _player.pause();
      return;
    }
    setState(() => _busy = true);
    try {
      if (_player.processingState == ProcessingState.idle) {
        await _player.setUrl(widget.audioUrl);
      }
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      unawaited(_player.play());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Could not play voice message: ' + error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final foreground = widget.isMe ? Colors.white : AppColors.textPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StreamBuilder<PlayerState>(
          stream: _player.playerStateStream,
          initialData: _player.playerState,
          builder: (context, snapshot) {
            final state = snapshot.data ?? _player.playerState;
            final icon = _busy
                ? null
                : state.playing
                    ? Icons.pause
                    : state.processingState == ProcessingState.completed
                        ? Icons.replay
                        : Icons.play_arrow;
            return IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: _togglePlayback,
              icon: icon == null
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(icon, color: foreground),
            );
          },
        ),
        const SizedBox(width: 4),
        Text(
          _formatAudioDuration(widget.durationMs),
          style: TextStyle(color: foreground),
        ),
      ],
    );
  }
}

String _formatAudioDuration(int milliseconds) {
  final seconds = (milliseconds / 1000).floor();
  final minutesPart = (seconds ~/ 60).toString().padLeft(2, '0');
  final secondsPart = (seconds % 60).toString().padLeft(2, '0');
  return minutesPart + ':' + secondsPart;
}
