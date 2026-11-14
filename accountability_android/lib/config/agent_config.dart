class AgentConfig {
  final String? telegramBotToken;  // bot made with @BotFather; must be an admin of the channel
  final String? telegramChatId;    // "@channelname" (public) or "-100…" (private channel)
  final String? nextDnsDohUrl;
  final String? nextDnsApiKey;   // optional: enables phone-side porn-attempt reports via the log API
  AgentConfig({this.telegramBotToken, this.telegramChatId, this.nextDnsDohUrl, this.nextDnsApiKey});

  factory AgentConfig.fromJson(Map j) => AgentConfig(
        telegramBotToken: j['telegramBotToken'],
        telegramChatId: j['telegramChatId'],
        nextDnsDohUrl: j['nextDnsDohUrl'],
        nextDnsApiKey: j['nextDnsApiKey'],
      );

  // The profile id is the last path segment of the DoH URL (…/nextdns.io/<profileId>).
  String? get nextDnsProfileId {
    if (nextDnsDohUrl == null) return null;
    final segs = Uri.parse(nextDnsDohUrl!).pathSegments.where((s) => s.isNotEmpty).toList();
    return segs.isEmpty ? null : segs.last;
  }

  Map<String, dynamic> toJson() => {
        if (telegramBotToken != null) 'telegramBotToken': telegramBotToken,
        if (telegramChatId != null) 'telegramChatId': telegramChatId,
        if (nextDnsDohUrl != null) 'nextDnsDohUrl': nextDnsDohUrl,
        if (nextDnsApiKey != null) 'nextDnsApiKey': nextDnsApiKey,
      };

  List<String> get validationErrors {
    final e = <String>[];
    if (telegramBotToken == null || telegramBotToken!.isEmpty) e.add('telegramBotToken is required');
    if (telegramChatId == null || telegramChatId!.isEmpty) e.add('telegramChatId is required');
    if (nextDnsDohUrl == null || !nextDnsDohUrl!.startsWith('https://')) e.add('nextDnsDohUrl must be https');
    return e;
  }

  bool get isValid => validationErrors.isEmpty;
}
