import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/create_profile_provider.dart';

class CreateLeadProfileScreen extends ConsumerStatefulWidget {
  final String userName;

  const CreateLeadProfileScreen({super.key, this.userName = 'Usuário'});

  @override
  ConsumerState<CreateLeadProfileScreen> createState() =>
      _CreateLeadProfileScreenState();
}

class _CreateLeadProfileScreenState
    extends ConsumerState<CreateLeadProfileScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createProfileProvider(widget.userName));
    final notifier = ref.read(createProfileProvider(widget.userName).notifier);

    // Auto-scroll on new messages
    ref.listen(createProfileProvider(widget.userName), (previous, next) {
      if (previous?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Perfil de Lead'),
        leading: state.isCompleted
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: state.messages.length + (state.isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == state.messages.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Digitando...',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    );
                  }

                  final message = state.messages[index];
                  final isUser = message.sender == MessageSender.user;

                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUser
                            ? Colors.blue.shade100
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      child: Text(message.text),
                    ),
                  );
                },
              ),
            ),
            if (state.isCompleted)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text("Voltar para Listagem"))),
              )
            else
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled: !state.isTyping && !state.isCompleted,
                        decoration: InputDecoration(
                          hintText: 'Digite sua resposta...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty) {
                            notifier.addUserMessage(value);
                            _controller.clear();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: state.isTyping || state.isCompleted
                          ? null
                          : () {
                              final text = _controller.text;
                              if (text.trim().isNotEmpty) {
                                notifier.addUserMessage(text);
                                _controller.clear();
                              }
                            },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
