import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/models/ai_chat_model.dart';
import '../data/services/ai_chat_service.dart';
import '../data/services/api_exception.dart';
import 'package_management_screen.dart';
import '../l10n/app_localizations.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final AiChatService _aiChatService = AiChatService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<AiSessionModel> _sessions = [];
  AiSessionModel? _currentSession;
  List<AiMessageModel> _messages = [];

  bool _isLoadingMessages = false;
  bool _isGenerating = false;
  StreamSubscription<Map<String, dynamic>>? _streamSubscription;
  Timer? _pollTimer;

  final List<String> _suggestedPrompts = [
    '🍲 Gợi ý món ăn ngon từ nguyên liệu trong tủ lạnh',
    '🥗 Lên thực đơn ăn uống lành mạnh & tiết kiệm 3 ngày',
    '🥩 Mẹo bảo quản thịt cá tươi ngon trong ngăn đá',
    '🛒 Tạo danh sách nguyên liệu cần mua cho tuần tới',
  ];

  @override
  void initState() {
    super.initState();
    _loadSessionsAndSelectLatest();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _pollTimer?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Helper methods
  // ------------------------------------------------------------------

  String _getSessionDisplayTitle(AiSessionModel session) {
    if (session.title != null && session.title!.trim().isNotEmpty) {
      return session.title!;
    }
    if (_currentSession?.id == session.id && _messages.isNotEmpty) {
      final firstUserMsg = _messages.firstWhere(
        (m) => m.role == 'user',
        orElse: () => AiMessageModel(id: '', role: '', content: '', createdAt: ''),
      );
      if (firstUserMsg.content.isNotEmpty) {
        final text = firstUserMsg.content.trim();
        return text.length > 28 ? '${text.substring(0, 28)}...' : text;
      }
    }
    return 'Trò chuyện ${session.id.length >= 6 ? session.id.substring(0, 6) : session.id}';
  }

  // ------------------------------------------------------------------
  // Data Loading & API Calls
  // ------------------------------------------------------------------

  Future<void> _loadSessionsAndSelectLatest() async {
    try {
      final list = await _aiChatService.getSessions(page: 1, limit: 20);
      if (!mounted) return;

      setState(() {
        _sessions = list;
      });

      if (list.isNotEmpty) {
        _selectSession(list.first);
      } else {
        _createNewSession();
      }
    } catch (e) {
      debugPrint('[AiChatScreen] Error loading sessions: $e');
    }
  }

  Future<void> _createNewSession() async {
    _streamSubscription?.cancel();
    _pollTimer?.cancel();
    setState(() {
      _isLoadingMessages = true;
      _isGenerating = false;
    });

    try {
      final newSession = await _aiChatService.createSession();
      if (!mounted) return;

      setState(() {
        _sessions.insert(0, newSession);
        _currentSession = newSession;
        _messages = [];
        _isLoadingMessages = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMessages = false);
      _showSnackBar('Lỗi khi tạo phiên chat mới: $e', isError: true);
    }
  }

  Future<void> _selectSession(AiSessionModel session) async {
    if (_currentSession?.id == session.id && _messages.isNotEmpty) return;

    _streamSubscription?.cancel();
    _pollTimer?.cancel();
    setState(() {
      _currentSession = session;
      _isLoadingMessages = true;
      _isGenerating = false;
      _messages = [];
    });

    try {
      final detail = await _aiChatService.getSessionDetail(session.id);
      if (!mounted) return;

      setState(() {
        _messages = detail.messages;
        _isLoadingMessages = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMessages = false);
    }
  }

  Future<void> _deleteCurrentSession() async {
    if (_currentSession == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF19271E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: Text(
            'Xóa phiên trò chuyện?',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Bạn có chắc chắn muốn xóa phiên chat này không? Tất cả tin nhắn trong phiên chat sẽ bị đóng.',
            style: GoogleFonts.plusJakartaSans(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Hủy',
                style: GoogleFonts.plusJakartaSans(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Xóa',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    final targetId = _currentSession!.id;
    try {
      await _aiChatService.deleteSession(targetId);
      if (!mounted) return;

      setState(() {
        _sessions.removeWhere((s) => s.id == targetId);
      });

      if (_sessions.isNotEmpty) {
        _selectSession(_sessions.first);
      } else {
        _createNewSession();
      }
      _showSnackBar('Đã xóa phiên trò chuyện thành công');
    } catch (e) {
      _showSnackBar('Lỗi khi xóa phiên trò chuyện: $e', isError: true);
    }
  }

  // ------------------------------------------------------------------
  // Messaging & Async AI Result Polling
  // ------------------------------------------------------------------

  Future<void> _sendMessage([String? customText]) async {
    final text = (customText ?? _inputController.text).trim();
    if (text.isEmpty || _isGenerating) return;

    if (_currentSession == null) {
      await _createNewSession();
      if (_currentSession == null) return;
    }

    _inputController.clear();

    final userMsg = AiMessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      content: text,
      createdAt: DateTime.now().toIso8601String(),
    );

    final assistantMsg = AiMessageModel(
      id: '${DateTime.now().millisecondsSinceEpoch}_ai',
      role: 'assistant',
      content: '',
      createdAt: DateTime.now().toIso8601String(),
      isStreaming: true,
    );

    setState(() {
      _messages.add(userMsg);
      _messages.add(assistantMsg);
      _isGenerating = true;
    });

    _scrollToBottom();

    final sessionId = _currentSession!.id;

    try {
      // 1. Subscribe to SSE stream FIRST so we catch real-time tokens from the start
      _streamSubscription?.cancel();
      _streamSubscription = _aiChatService.streamSession(sessionId).listen(
        (eventMap) {
          if (!mounted) return;
          final eventType = eventMap['event'] as String?;
          final data = eventMap['data'];

          if (eventType == 'chunk' && data != null) {
            setState(() {
              assistantMsg.content += data.toString();
            });
            _scrollToBottom();
          } else if (eventType == 'done') {
            setState(() {
              assistantMsg.isStreaming = false;
              _isGenerating = false;
            });
            _scrollToBottom();
            _streamSubscription?.cancel();
            _pollTimer?.cancel();
          } else if (eventType == 'error') {
            debugPrint('[AiChatScreen] SSE stream error event: $data');
            setState(() {
              final errMsg = data?.toString().trim();
              assistantMsg.content = (errMsg != null && errMsg.isNotEmpty)
                  ? errMsg
                  : 'Có lỗi xảy ra trong quá trình xử lý của AI.';
              assistantMsg.isStreaming = false;
              _isGenerating = false;
            });
            _streamSubscription?.cancel();
            _pollTimer?.cancel();
          }
        },
        onError: (err) {
          debugPrint('[AiChatScreen] SSE stream onError: $err');
        },
      );

      // 2. Send message to backend (POST /ai-chat/sessions/:id/messages)
      await _aiChatService.sendMessage(sessionId, text);

      // 3. Fallback DB polling every 2s in case stream drops
      _pollTimer?.cancel();
      int attempts = 0;
      const maxAttempts = 25; // Poll up to 50 seconds max

      _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
        attempts++;
        if (!mounted || !_isGenerating) {
          timer.cancel();
          return;
        }

        try {
          final detail = await _aiChatService.getSessionDetail(sessionId);
          if (!mounted) {
            timer.cancel();
            return;
          }

          if (detail.messages.isNotEmpty) {
            final lastMsg = detail.messages.last;
            if (lastMsg.role == 'assistant' && lastMsg.content.trim().isNotEmpty) {
              setState(() {
                if (assistantMsg.content.length < lastMsg.content.length) {
                  assistantMsg.content = lastMsg.content;
                }
                assistantMsg.isStreaming = false;
                _isGenerating = false;
              });
              _scrollToBottom();
              timer.cancel();
              _streamSubscription?.cancel();
              return;
            }
          }
        } catch (e) {
          debugPrint('[AiChatScreen] Poll DB detail error: $e');
        }

        if (attempts >= maxAttempts) {
          timer.cancel();
          if (mounted && assistantMsg.isStreaming) {
            setState(() {
              if (assistantMsg.content.trim().isEmpty) {
                assistantMsg.content = 'Hệ thống AI đã xử lý xong. Hãy vuốt nhẹ để cập nhật tin nhắn!';
              }
              assistantMsg.isStreaming = false;
              _isGenerating = false;
            });
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      _pollTimer?.cancel();
      _streamSubscription?.cancel();

      String cleanMsg = e is ApiException
          ? e.message
          : e.toString().replaceAll('ApiException: ', '').replaceAll('Exception: ', '');

      setState(() {
        if (assistantMsg.content.trim().isEmpty) {
          _messages.remove(assistantMsg);
        } else {
          assistantMsg.isStreaming = false;
        }
        _isGenerating = false;
      });
      _showSnackBar(cleanMsg, isError: true);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    final isLimitError = message.contains('dùng hết') || message.contains('lượt AI');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isLimitError
                  ? Icons.stars_rounded
                  : (isError ? Icons.info_outline_rounded : Icons.check_circle_rounded),
              color: const Color(0xFFFFD54F),
              size: 20,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF006428),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        margin: EdgeInsets.all(16.w),
        action: isLimitError
            ? SnackBarAction(
                label: 'Nâng cấp',
                textColor: const Color(0xFFFFD54F),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PackageManagementScreen(),
                    ),
                  );
                },
              )
            : null,
      ),
    );
  }

  // ------------------------------------------------------------------
  // UI Building Methods
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final isEn = loc?.locale.languageCode == 'en';

    return SafeArea(
      child: Column(
        children: [
          // 1. Header Bar
          _buildHeader(isDark, isEn),

          // 2. Main Chat Content Body
          Expanded(
            child: _isLoadingMessages
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF008435)),
                  )
                : _messages.isEmpty
                    ? _buildWelcomeState(isDark)
                    : _buildMessagesList(isDark),
          ),

          // 3. Input Bar (Seamless Transparent Green Theme)
          _buildInputBar(isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark, bool isEn) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.transparent, // Seamless green background!
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF2E4D36).withValues(alpha: 0.5) : const Color(0xFFC8E6C9).withValues(alpha: 0.6),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          // Mascot Avatar Badge
          Container(
            width: 44,
            height: 44,
            padding: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF81C784), Color(0xFF008435)],
              ),
            ),
            child: CircleAvatar(
              backgroundColor: isDark ? const Color(0xFF19271E) : Colors.white,
              child: Padding(
                padding: EdgeInsets.all(2.0.w),
                child: Image.asset(
                  'assets/images/cute_mascot.png',
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, error, stackTrace) => const Icon(
                    Icons.smart_toy_rounded,
                    color: Color(0xFF008435),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),

          // Title & Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    children: [
                      TextSpan(
                        text: 'Đầu bếp ',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF19221C),
                        ),
                      ),
                      const TextSpan(
                        text: 'AI',
                        style: TextStyle(
                          color: Color(0xFF008435),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _currentSession != null
                      ? _getSessionDisplayTitle(_currentSession!)
                      : 'Tư vấn món ăn & tủ lạnh',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.sp,
                    color: isDark ? Colors.grey[400] : const Color(0xFF55775A),
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons: Session List & New Session & Delete
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Color(0xFF008435)),
            tooltip: 'Danh sách phiên chat',
            onPressed: () => _showSessionsBottomSheet(isDark),
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_rounded, color: Color(0xFF008435)),
            tooltip: 'Tạo trò chuyện mới',
            onPressed: _createNewSession,
          ),
          if (_currentSession != null)
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: Colors.red[400]),
              tooltip: 'Xóa phiên chat này',
              onPressed: _deleteCurrentSession,
            ),
        ],
      ),
    );
  }

  Widget _buildWelcomeState(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      child: Column(
        children: [
          SizedBox(height: 12.h),
          // Giant Mascot Card
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF008435).withValues(alpha: 0.12),
            ),
            padding: EdgeInsets.all(16.w),
            child: Image.asset(
              'assets/images/cute_mascot.png',
              fit: BoxFit.contain,
              errorBuilder: (ctx, error, stackTrace) => const Icon(
                Icons.smart_toy_rounded,
                size: 50,
                color: Color(0xFF008435),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'Xin chào! Tớ là Đầu Bếp AI Friggy 🧑‍🍳',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF19221C),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Hỏi tớ bất kỳ món ăn nào, gợi ý thực đơn tuần hoặc cách tận dụng thực phẩm còn trong tủ lạnh nhé!',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5.sp,
              color: isDark ? Colors.grey[400] : const Color(0xFF4A684F),
              height: 1.4,
            ),
          ),
          SizedBox(height: 28.h),

          // Suggested Prompt Chips Header
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Gợi ý câu hỏi phổ biến:',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF008435),
              ),
            ),
          ),
          SizedBox(height: 12.h),

          // Chips List
          ..._suggestedPrompts.map(
            (prompt) => Container(
              width: double.infinity,
              margin: EdgeInsets.only(bottom: 10.h),
              child: InkWell(
                onTap: () => _sendMessage(prompt),
                borderRadius: BorderRadius.circular(16.r),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF19271E) : Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2E4D36) : const Color(0xFF81C784),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          prompt,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF19221C),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: Color(0xFF008435),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(bool isDark) {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      physics: const BouncingScrollPhysics(),
      itemCount: _messages.length,
      itemBuilder: (ctx, index) {
        final msg = _messages[index];
        final isUser = msg.role == 'user';
        return _buildMessageItem(msg, isUser, isDark);
      },
    );
  }

  Widget _buildMessageItem(AiMessageModel msg, bool isUser, bool isDark) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF008435).withValues(alpha: 0.15),
              child: Padding(
                padding: EdgeInsets.all(2.0.w),
                child: Image.asset(
                  'assets/images/cute_mascot.png',
                  fit: BoxFit.contain,
                  errorBuilder: (c, error, stackTrace) => const Icon(
                    Icons.smart_toy_rounded,
                    size: 18,
                    color: Color(0xFF008435),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8.w),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                gradient: isUser
                    ? LinearGradient(
                        colors: [Color(0xFF008435), Color(0xFF0F5A24)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isUser
                    ? null
                    : (isDark ? const Color(0xFF19271E) : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18.r),
                  topRight: Radius.circular(18.r),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: isUser
                    ? null
                    : Border.all(
                        color: isDark ? const Color(0xFF2E4D36) : const Color(0xFF81C784),
                        width: 1,
                      ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.content.isEmpty && msg.isStreaming
                        ? 'AI Friggy đang suy nghĩ...'
                        : msg.content,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.sp,
                      height: 1.45,
                      color: isUser
                          ? Colors.white
                          : (isDark ? Colors.white : const Color(0xFF19221C)),
                    ),
                  ),
                  if (msg.isStreaming) ...[
                    SizedBox(height: 6.h),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF008435),
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          'Đang trả lời...',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.sp,
                            fontStyle: FontStyle.italic,
                            color: const Color(0xFF008435),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) SizedBox(width: 8.w),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.transparent,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF19271E) : Colors.white,
                borderRadius: BorderRadius.circular(24.r),
                border: Border.all(
                  color: isDark ? const Color(0xFF2E4D36) : const Color(0xFF81C784),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _inputController,
                onSubmitted: (_) => _sendMessage(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.sp,
                  color: isDark ? Colors.white : const Color(0xFF19221C),
                ),
                decoration: InputDecoration(
                  hintText: 'Hỏi Đầu Bếp AI Friggy...',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5.sp,
                    color: isDark ? Colors.grey[500] : const Color(0xFF7A9E7F),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 10.w),

          // Send Button
          InkWell(
            onTap: _isGenerating ? null : () => _sendMessage(),
            borderRadius: BorderRadius.circular(24.r),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _isGenerating
                    ? LinearGradient(colors: [Colors.grey[400]!, Colors.grey[600]!])
                    : LinearGradient(
                        colors: [Color(0xFF81C784), Color(0xFF008435)],
                      ),
                boxShadow: [
                  if (!_isGenerating)
                    BoxShadow(
                      color: const Color(0xFF008435).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                ],
              ),
              child: Icon(
                _isGenerating ? Icons.hourglass_top_rounded : Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSessionsBottomSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF142419) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          height: 380,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 14.h),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Lịch sử trò chuyện',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF19221C),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _createNewSession();
                    },
                    icon: const Icon(Icons.add, size: 18, color: Color(0xFF008435)),
                    label: Text(
                      'Tạo mới',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF008435),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),

              Expanded(
                child: _sessions.isEmpty
                    ? Center(
                        child: Text(
                          'Chưa có phiên trò chuyện nào',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.grey[500],
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _sessions.length,
                        itemBuilder: (c, idx) {
                          final session = _sessions[idx];
                          final isSelected = _currentSession?.id == session.id;

                          return Container(
                            margin: EdgeInsets.only(bottom: 8.h),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF008435).withValues(alpha: 0.12)
                                  : (isDark ? const Color(0xFF19271E) : const Color(0xFFF5F5F5)),
                              borderRadius: BorderRadius.circular(14.r),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF008435)
                                    : Colors.transparent,
                                width: 1.2,
                              ),
                            ),
                            child: ListTile(
                              leading: Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: isSelected
                                    ? const Color(0xFF008435)
                                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
                              ),
                              title: Text(
                                _getSessionDisplayTitle(session),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF19221C),
                                ),
                              ),
                              subtitle: Text(
                                '${session.messageCount} tin nhắn',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.sp,
                                  color: Colors.grey[500],
                                ),
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.red[400],
                                  size: 20,
                                ),
                                onPressed: () async {
                                  Navigator.of(ctx).pop();
                                  _selectSession(session);
                                  await _deleteCurrentSession();
                                },
                              ),
                              onTap: () {
                                Navigator.of(ctx).pop();
                                _selectSession(session);
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
