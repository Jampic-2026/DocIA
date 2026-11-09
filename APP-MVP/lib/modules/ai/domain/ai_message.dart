class AiMessage {
  const AiMessage({
    required this.text,
    required this.isUser,
    required this.time,
  });

  final String text;
  final bool isUser;
  final DateTime time;
}
