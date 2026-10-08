import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/facility.dart';
import '../services/campus_chat_service.dart';
import '../widgets/app_header.dart';
import 'building_info_screen.dart';

class _ChatMessage {
  final String text;
  final bool isUser;
  final List<Facility> facilities;
  final Set<String> mapFacilityNames;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.facilities = const [],
    this.mapFacilityNames = const {},
  });
}

class ChatbotScreen extends StatefulWidget {
  final CampusChatService? service;
  final bool canReturnToMap;
  const ChatbotScreen({super.key, this.service, this.canReturnToMap = false});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  late final _service = widget.service ?? CampusChatService();
  final List<ChatTurn> _history = [];
  bool _sending = false;
  String? _error;
  String? _retryQuestion;

  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      text:
          'Hello! I\'m the ligHAU Assistant. I can help you navigate the campus. Try asking me about a building or facility!',
      isUser: false,
    ),
  ];

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;
    if (text.length > 2000) {
      setState(
        () => _error = 'Please keep your question under 2000 characters.',
      );
      return;
    }
    _request(text, addMessage: true);
  }

  Future<void> _request(String text, {bool addMessage = false}) async {
    if (_sending) return;
    setState(() {
      if (addMessage) {
        _messages.add(_ChatMessage(text: text, isUser: true));
        _inputController.clear();
      }
      _sending = true;
      _error = null;
      _retryQuestion = null;
    });
    _scrollToEnd();
    try {
      final reply = await _service.send(text, _history);
      if (!mounted) return;
      setState(() {
        _history.addAll([
          ChatTurn('user', text),
          ChatTurn('model', reply.answer),
        ]);
        _messages.add(
          _ChatMessage(
            text: reply.answer,
            isUser: false,
            facilities: reply.facilities,
            mapFacilityNames: reply.mapFacilityNames,
          ),
        );
      });
    } on CampusChatException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _retryQuestion = text;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToEnd();
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    if (widget.service == null) _service.close();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const AppHeader(title: 'Campus assistant'),
      body: PageBody(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'A little help finding your way.',
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          'Ask about a building or campus facility.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _buildBubble(msg, theme);
                },
              ),
            ),
            if (_sending)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text('Finding an answer…'),
                  ],
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    if (_retryQuestion != null)
                      TextButton(
                        onPressed: _sending
                            ? null
                            : () => _request(_retryQuestion!),
                        child: const Text('Try again'),
                      ),
                  ],
                ),
              ),
            // Input area
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.pathway)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        enabled: !_sending,
                        controller: _inputController,
                        decoration: const InputDecoration(
                          hintText: 'Ask about a building or facility...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Send question',
                      onPressed: _sending ? null : _sendMessage,
                      icon: const Icon(Icons.send, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(_ChatMessage msg, ThemeData theme) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width < 760
              ? MediaQuery.of(context).size.width * 0.8
              : 560,
        ),
        child: Column(
          crossAxisAlignment: msg.isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: msg.isUser ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
                  bottomRight: Radius.circular(msg.isUser ? 4 : 16),
                ),
                border: msg.isUser
                    ? null
                    : Border.all(color: AppColors.pathway),
              ),
              child: Text(
                msg.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: msg.isUser ? AppColors.onPrimary : AppColors.onSurface,
                ),
              ),
            ),
            if (msg.facilities.isNotEmpty && !msg.isUser) ...[
              const SizedBox(height: AppSpacing.xs),
              for (final facility in msg.facilities)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(facility.name, style: theme.textTheme.labelMedium),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    BuildingInfoScreen(facility: facility),
                              ),
                            ),
                            icon: const Icon(Icons.info_outline, size: 16),
                            label: const Text('Open Details'),
                          ),
                          if (widget.canReturnToMap &&
                              msg.mapFacilityNames.contains(facility.name))
                            OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context, facility),
                              icon: const Icon(Icons.map_outlined, size: 16),
                              label: const Text('Show on Map'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
