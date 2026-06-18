// ==========================================================
// widgets/ai_chat_widget.dart
// PHASE-17 — FILE 4 OF 4
// PURPOSE: RAW TEXT CAPTURE AND FORWARD ONLY
// ==========================================================
//
// INPUT:
//   chatHistory → List<String>  (read-only display)
//
// OUTPUT:
//   AiPrompt → { type:"AI_PROMPT", payload:STRING,
//                target:"AI_ENGINE", timestamp:INTEGER }
//   → EditorController.sendAI(prompt)
//
// ALLOWED STATE:
//   inputBuffer: String   (ONLY this, nothing else)
//
// FORBIDDEN: AI processing, command generation,
//            engine access, decision making
// ==========================================================

import 'package:flutter/material.dart';
import '../controllers/editor_controller.dart';

// ---------------------------------------------------------------------------
// AI PROMPT — the only output format this widget produces
// ---------------------------------------------------------------------------

@immutable
class AiPrompt {
  const AiPrompt({required this.payload, required this.timestamp});

  final String type      = 'AI_PROMPT';
  final String target    = 'AI_ENGINE';
  final String payload;
  final int    timestamp;

  Map<String, dynamic> toMap() => {
        'type':      type,
        'payload':   payload,
        'target':    target,
        'timestamp': timestamp,
      };
}

// ---------------------------------------------------------------------------
// WIDGET
// ---------------------------------------------------------------------------

class AiChatWidget extends StatefulWidget {
  const AiChatWidget({
    super.key,
    required this.chatHistory,
    required this.editorController,
  });

  final List<String>    chatHistory;     // read-only messages from EditorController
  final EditorController editorController;

  @override
  State<AiChatWidget> createState() => _AiChatWidgetState();
}

class _AiChatWidgetState extends State<AiChatWidget> {
  // ALLOWED STATE — ONLY inputBuffer
  String _inputBuffer = '';

  final TextEditingController _textCtrl    = TextEditingController();
  final ScrollController      _scrollCtrl  = ScrollController();
  final FocusNode             _focusNode   = FocusNode();

  @override
  void didUpdateWidget(AiChatWidget old) {
    super.didUpdateWidget(old);
    if (old.chatHistory.length != widget.chatHistory.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  // Raw text pipe — no processing, no logic
  void _submitPrompt() {
    final String raw = _inputBuffer.trim();
    if (raw.isEmpty) return;

    widget.editorController.sendAI(
      AiPrompt(
        payload:   raw,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    _textCtrl.clear();
    setState(() => _inputBuffer = '');
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D0D0F),
      child: Column(
        children: [

          // ── Top bar ────────────────────────────────────────────────────
          const _AiTopBar(),

          // ── Suggestion chips (shown only when history is empty) ────────
          if (widget.chatHistory.isEmpty)
            const _SuggestionRow(),

          // ── Message thread ─────────────────────────────────────────────
          Expanded(
            child: widget.chatHistory.isEmpty
                ? const _WelcomeState()
                : ListView.builder(
                    controller:  _scrollCtrl,
                    padding:     const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    itemCount:   widget.chatHistory.length,
                    itemBuilder: (context, i) => _ChatBubble(
                      text:   widget.chatHistory[i],
                      isUser: i.isEven,  // even = user, odd = AI response
                    ),
                  ),
          ),

          // ── Divider ───────────────────────────────────────────────────
          const Divider(height: 1, thickness: 1, color: Color(0xFF1E1E22)),

          // ── Input bar ─────────────────────────────────────────────────
          _ChatInputBar(
            textCtrl:  _textCtrl,
            focusNode: _focusNode,
            onChanged: (v) => setState(() => _inputBuffer = v),
            onSubmit:  _submitPrompt,
            canSend:   _inputBuffer.trim().isNotEmpty,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TOP BAR
// ---------------------------------------------------------------------------

class _AiTopBar extends StatelessWidget {
  const _AiTopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height:  44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF131315),
        border: Border(bottom: BorderSide(color: Color(0xFF1E1E22))),
      ),
      child: Row(
        children: [
          // AI status indicator
          Container(
            width: 7, height: 7,
            decoration: const BoxDecoration(
              color:  Color(0xFF30D158),
              shape:  BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Z-AI',
            style: TextStyle(
              color:       Color(0xFFE5E5EA),
              fontSize:    13,
              fontWeight:  FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding:    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color:        const Color(0xFF6C63FF).withOpacity(0.18),
              borderRadius: BorderRadius.circular(4),
              border:       Border.all(
                color: const Color(0xFF6C63FF).withOpacity(0.3),
                width: 0.5,
              ),
            ),
            child: const Text(
              'TEXT PIPE',
              style: TextStyle(
                color:       Color(0xFF6C63FF),
                fontSize:    8,
                fontWeight:  FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const Spacer(),
          const Icon(Icons.psychology_outlined, size: 16, color: Color(0xFF3A3A3C)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// WELCOME STATE — shown when chatHistory is empty
// ---------------------------------------------------------------------------

class _WelcomeState extends StatelessWidget {
  const _WelcomeState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated AI logo ring
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF6C63FF).withOpacity(0.4),
                width: 1.5,
              ),
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF6C63FF).withOpacity(0.12),
                  Colors.transparent,
                ],
              ),
            ),
            child: const Icon(
              Icons.auto_awesome,
              size:  24,
              color: Color(0xFF6C63FF),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'What do you want to create?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color:      Color(0xFFAEAEB2),
              fontSize:   14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Describe your design and Z-AI will\ngenerate it on the canvas.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color:    Color(0xFF48484A),
              fontSize: 11,
              height:   1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SUGGESTION CHIPS — display only, pre-fill inputBuffer
// ---------------------------------------------------------------------------

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow();

  static const List<String> _suggestions = [
    'Create a banner',
    'Add bold headline',
    'Dark gradient bg',
    'Minimal logo card',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding:         const EdgeInsets.symmetric(horizontal: 12),
        itemCount:       _suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) => Center(
          child: Container(
            padding:    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color:        const Color(0xFF1E1E22),
              borderRadius: BorderRadius.circular(16),
              border:       Border.all(color: const Color(0xFF2C2C2E)),
            ),
            child: Text(
              _suggestions[i],
              style: const TextStyle(
                color:    Color(0xFF636366),
                fontSize: 11,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CHAT BUBBLE — read-only display of one message
// ---------------------------------------------------------------------------

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.text, required this.isUser});

  final String text;
  final bool   isUser;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: isUser ? _UserBubble(text: text) : _AiBubble(text: text),
    );
  }
}

// ── User bubble — right-aligned, purple tint ──────────────────────────────

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const SizedBox(width: 48),
        Flexible(
          child: Container(
            padding:    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF5A52E0)],
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft:     Radius.circular(16),
                topRight:    Radius.circular(16),
                bottomLeft:  Radius.circular(16),
                bottomRight: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color:  const Color(0xFF6C63FF).withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              text,
              style: const TextStyle(
                color:    Color(0xFFFFFFFF),
                fontSize: 13,
                height:   1.45,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // User avatar
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            color:        const Color(0xFF6C63FF).withOpacity(0.2),
            shape:        BoxShape.circle,
            border:       Border.all(
              color: const Color(0xFF6C63FF).withOpacity(0.4),
              width: 1,
            ),
          ),
          child: const Icon(Icons.person_outline, size: 14, color: Color(0xFF6C63FF)),
        ),
      ],
    );
  }
}

// ── AI bubble — left-aligned, dark card ───────────────────────────────────

class _AiBubble extends StatelessWidget {
  const _AiBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI avatar
        Container(
          width: 26, height: 26,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color:  const Color(0xFF1E1E22),
            shape:  BoxShape.circle,
            border: Border.all(color: const Color(0xFF2C2C2E)),
          ),
          child: const Icon(Icons.auto_awesome, size: 13, color: Color(0xFF6C63FF)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // "Z-AI" label above bubble
              const Padding(
                padding: EdgeInsets.only(left: 2, bottom: 4),
                child: Text(
                  'Z-AI',
                  style: TextStyle(
                    color:       Color(0xFF636366),
                    fontSize:    9,
                    fontWeight:  FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                padding:    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color:  Color(0xFF1E1E22),
                  borderRadius: BorderRadius.only(
                    topLeft:     Radius.circular(4),
                    topRight:    Radius.circular(16),
                    bottomLeft:  Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Text(
                  text,
                  style: const TextStyle(
                    color:    Color(0xFFD1D1D6),
                    fontSize: 13,
                    height:   1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// INPUT BAR — captures raw text only, no processing
// ---------------------------------------------------------------------------

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.textCtrl,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmit,
    required this.canSend,
  });

  final TextEditingController textCtrl;
  final FocusNode             focusNode;
  final void Function(String) onChanged;
  final VoidCallback          onSubmit;
  final bool                  canSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [

            // Text field
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 40, maxHeight: 130),
                decoration: BoxDecoration(
                  color:        const Color(0xFF1E1E22),
                  borderRadius: BorderRadius.circular(14),
                  border:       Border.all(
                    color: canSend
                        ? const Color(0xFF6C63FF).withOpacity(0.5)
                        : const Color(0xFF2C2C2E),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller:      textCtrl,
                  focusNode:       focusNode,
                  onChanged:       onChanged,
                  onSubmitted:     (_) => onSubmit(),
                  maxLines:        null,
                  minLines:        1,
                  textInputAction: TextInputAction.send,
                  style: const TextStyle(
                    color:    Color(0xFFE5E5EA),
                    fontSize: 13,
                    height:   1.4,
                  ),
                  decoration: const InputDecoration(
                    hintText:       'Describe your design…',
                    hintStyle:      TextStyle(color: Color(0xFF3A3A3C), fontSize: 13),
                    border:         InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    isDense:        true,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Send button
            GestureDetector(
              onTap: canSend ? onSubmit : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 40, height: 40,
                decoration: BoxDecoration(
                  gradient: canSend
                      ? const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF5A52E0)],
                          begin:  Alignment.topLeft,
                          end:    Alignment.bottomRight,
                        )
                      : null,
                  color:        canSend ? null : const Color(0xFF1E1E22),
                  borderRadius: BorderRadius.circular(12),
                  border: canSend
                      ? null
                      : Border.all(color: const Color(0xFF2C2C2E)),
                ),
                child: Icon(
                  Icons.arrow_upward_rounded,
                  size:  18,
                  color: canSend ? Colors.white : const Color(0xFF3A3A3C),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================
// END OF FILE — widgets/ai_chat_widget.dart
// ==========================================================
