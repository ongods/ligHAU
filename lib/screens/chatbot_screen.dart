import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/facility.dart';
import '../services/campus_chat_service.dart';
import '../widgets/app_header.dart';
import '../widgets/panel_frame.dart';
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
  final _latestReplyKey = GlobalKey();
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
        _scrollToEnd(showReply: true);
      }
    }
  }

  void _scrollToEnd({bool showReply = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final replyContext = _latestReplyKey.currentContext;
      if (showReply && replyContext != null) {
        Scrollable.ensureVisible(
          replyContext,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
        return;
      }
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
      body: SafeArea(
        top: false,
        child: PageBody(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: PanelFrame(
              key: const ValueKey('chat-panel'),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
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
                  const Divider(color: AppColors.panelBorder),
                  Expanded(
                    child: ColoredBox(
                      color: AppColors.background,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          return _buildBubble(
                            msg,
                            theme,
                            isLatestReply:
                                index == _messages.length - 1 && !msg.isUser,
                          );
                        },
                      ),
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
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                        border: Border.fromBorderSide(
                          BorderSide(color: AppColors.panelBorder),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                enabled: !_sending,
                                controller: _inputController,
                                minLines: 1,
                                maxLines: 4,
                                textInputAction: TextInputAction.send,
                                decoration: const InputDecoration(
                                  hintText:
                                      'Ask about a building or facility...',
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                  ),
                                ),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                            IconButton.filled(
                              tooltip: 'Send question',
                              onPressed: _sending ? null : _sendMessage,
                              icon: const Icon(Icons.send),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(
    _ChatMessage msg,
    ThemeData theme, {
    required bool isLatestReply,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          key: isLatestReply ? _latestReplyKey : null,
          margin: const EdgeInsets.only(bottom: AppSpacing.lg),
          constraints: BoxConstraints(
            maxWidth: msg.isUser
                ? constraints.maxWidth * 0.85
                : constraints.maxWidth.clamp(0.0, 620.0),
          ),
          child: Column(
            crossAxisAlignment: msg.isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!msg.isUser) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome_outlined,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ligHAU Assistant',
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
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
                    : Border.all(color: AppColors.panelBorder),
                ),
                child: SelectableText(
                  msg.text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: msg.isUser
                        ? AppColors.onPrimary
                        : AppColors.onSurface,
                  ),
                ),
              ),
              if (msg.facilities.isNotEmpty && !msg.isUser) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  msg.facilities.length == 1
                      ? 'Matched location'
                      : '${msg.facilities.length} matching locations',
                  style: theme.textTheme.titleMedium,
                ),
                if (msg.facilities.length > 1)
                  Text(
                    'Compare the locations below to find the one you need.',
                    style: theme.textTheme.bodySmall,
                  ),
                for (final (index, facility) in msg.facilities.indexed)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: _FacilityMatchCard(
                      facility: facility,
                      number: msg.facilities.length > 1 ? index + 1 : null,
                      onDetails: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              BuildingInfoScreen(facility: facility),
                        ),
                      ),
                      onMap:
                          widget.canReturnToMap &&
                              msg.mapFacilityNames.contains(facility.name)
                          ? () => Navigator.pop(context, facility)
                          : null,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FacilityMatchCard extends StatelessWidget {
  final Facility facility;
  final int? number;
  final VoidCallback onDetails;
  final VoidCallback? onMap;

  const _FacilityMatchCard({
    required this.facility,
    required this.number,
    required this.onDetails,
    required this.onMap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(facility.icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        if (number != null) 'Match $number',
                        facility.category,
                      ].where((text) => text.isNotEmpty).join(' · '),
                      style: theme.textTheme.labelSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(facility.name, style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
            ],
          ),
          if (facility.location.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.place_outlined,
                  size: 16,
                  color: AppColors.border,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    facility.location,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          if (facility.description.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(facility.description, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onDetails,
                icon: const Icon(Icons.info_outline, size: 16),
                label: const Text('Open Details'),
              ),
              if (onMap != null)
                FilledButton.icon(
                  onPressed: onMap,
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: const Text('Show on Map'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
