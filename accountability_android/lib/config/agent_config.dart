class SmtpConfig {
  final String host; final int port; final String username;
  final String appPassword; final String fromAddress;
  SmtpConfig(this.host, this.port, this.username, this.appPassword, this.fromAddress);
  factory SmtpConfig.fromJson(Map j) =>
      SmtpConfig(j['host'], j['port'], j['username'], j['appPassword'], j['fromAddress']);
  Map<String, dynamic> toJson() =>
      {'host': host, 'port': port, 'username': username, 'appPassword': appPassword, 'fromAddress': fromAddress};
}

class AgentConfig {
  final String? witnessEmail;
  final String? nextDnsDohUrl;
  final String? nextDnsApiKey;   // optional: enables phone-side porn-attempt emails via the log API
  final SmtpConfig? smtp;
  AgentConfig({this.witnessEmail, this.nextDnsDohUrl, this.nextDnsApiKey, this.smtp});

  factory AgentConfig.fromJson(Map j) => AgentConfig(
        witnessEmail: j['witnessEmail'],
        nextDnsDohUrl: j['nextDnsDohUrl'],
        nextDnsApiKey: j['nextDnsApiKey'],
        smtp: j['smtp'] != null ? SmtpConfig.fromJson(j['smtp']) : null,
      );

  // The profile id is the last path segment of the DoH URL (…/nextdns.io/<profileId>).
  String? get nextDnsProfileId {
    if (nextDnsDohUrl == null) return null;
    final segs = Uri.parse(nextDnsDohUrl!).pathSegments.where((s) => s.isNotEmpty).toList();
    return segs.isEmpty ? null : segs.last;
  }

  Map<String, dynamic> toJson() => {
        if (witnessEmail != null) 'witnessEmail': witnessEmail,
        if (nextDnsDohUrl != null) 'nextDnsDohUrl': nextDnsDohUrl,
        if (nextDnsApiKey != null) 'nextDnsApiKey': nextDnsApiKey,
        if (smtp != null) 'smtp': smtp!.toJson(),
      };

  List<String> get validationErrors {
    final e = <String>[];
    if (witnessEmail == null || witnessEmail!.isEmpty) e.add('witnessEmail is required');
    if (nextDnsDohUrl == null || !nextDnsDohUrl!.startsWith('https://')) e.add('nextDnsDohUrl must be https');
    if (smtp == null) e.add('smtp is required');
    return e;
  }

  bool get isValid => validationErrors.isEmpty;
}
