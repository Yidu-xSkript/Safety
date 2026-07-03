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
  final SmtpConfig? smtp;
  AgentConfig({this.witnessEmail, this.nextDnsDohUrl, this.smtp});

  factory AgentConfig.fromJson(Map j) => AgentConfig(
        witnessEmail: j['witnessEmail'],
        nextDnsDohUrl: j['nextDnsDohUrl'],
        smtp: j['smtp'] != null ? SmtpConfig.fromJson(j['smtp']) : null,
      );

  Map<String, dynamic> toJson() => {
        if (witnessEmail != null) 'witnessEmail': witnessEmail,
        if (nextDnsDohUrl != null) 'nextDnsDohUrl': nextDnsDohUrl,
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
