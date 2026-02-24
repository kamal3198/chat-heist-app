import 'message_provider.dart';

class ChatProvider extends MessageProvider {
  ChatProvider({
    super.chatService,
    super.messageService,
    super.socketService,
  });
}
