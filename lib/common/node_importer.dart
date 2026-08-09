import 'dart:convert';

class NodeImportResult {
  final String label;
  final String content;
  final int count;

  const NodeImportResult({
    required this.label,
    required this.content,
    required this.count,
  });
}

class NodeImporter {
  static const _defaultTestUrl = 'https://www.gstatic.com/generate_204';

  static final _linkRegExp = RegExp(
    r'(?:vmess|vless|trojan|ss|hysteria2|hy2|tuic)://[^\s]+',
    caseSensitive: false,
  );

  static bool hasImportableNodes(String value) {
    return _extractLinks(value).isNotEmpty;
  }

  static NodeImportResult fromText(String value, {String? label}) {
    final proxies = <Map<String, Object?>>[];
    final names = <String>{};

    for (final link in _extractLinks(value)) {
      final proxy = _parseLink(link);
      if (proxy == null) continue;
      final name = _uniqueName((proxy['name'] as String?) ?? 'Proxy', names);
      proxies.add({...proxy, 'name': name});
    }

    if (proxies.isEmpty) {
      throw '没有找到支持的节点链接';
    }

    final realLabel = label?.trim().isNotEmpty == true
        ? label!.trim()
        : proxies.length == 1
            ? proxies.first['name'] as String
            : '导入节点 (${proxies.length})';

    return NodeImportResult(
      label: realLabel,
      content: _encodeConfig(proxies),
      count: proxies.length,
    );
  }

  static String blankProfileContent() {
    return _encodeConfig(const []);
  }

  static List<String> _extractLinks(String value) {
    final values = <String>[value.trim()];
    final decoded = _tryDecodeBase64Subscription(value.trim());
    if (decoded != null) {
      values.add(decoded);
    }

    final links = <String>[];
    final seen = <String>{};
    for (final item in values) {
      for (final match in _linkRegExp.allMatches(item)) {
        final link = match.group(0)?.trim();
        if (link == null || link.isEmpty || seen.contains(link)) continue;
        seen.add(link);
        links.add(link);
      }
    }
    return links;
  }

  static String? _tryDecodeBase64Subscription(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), '');
    if (normalized.isEmpty || normalized.contains('://')) return null;
    try {
      final bytes = base64.decode(_normalizeBase64(normalized));
      final decoded = utf8.decode(bytes, allowMalformed: true).trim();
      return decoded.contains('://') ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static Map<String, Object?>? _parseLink(String link) {
    final scheme = link.substring(0, link.indexOf('://')).toLowerCase();
    return switch (scheme) {
      'vmess' => _parseVmess(link),
      'vless' => _parseVless(link),
      'trojan' => _parseTrojan(link),
      'ss' => _parseShadowsocks(link),
      'hysteria2' || 'hy2' => _parseHysteria2(link),
      'tuic' => _parseTuic(link),
      _ => null,
    };
  }

  static Map<String, Object?>? _parseVmess(String link) {
    try {
      final payload = link.substring('vmess://'.length);
      final jsonText = utf8.decode(
        base64.decode(_normalizeBase64(payload)),
        allowMalformed: true,
      );
      final data = json.decode(jsonText) as Map<String, dynamic>;
      final network = (data['net'] ?? 'tcp').toString();
      final tls = (data['tls'] ?? '').toString().isNotEmpty;
      final proxy = <String, Object?>{
        'name': _firstNotEmpty([data['ps'], data['add'], 'VMess']),
        'type': 'vmess',
        'server': data['add']?.toString() ?? '',
        'port': _parseInt(data['port']) ?? 443,
        'uuid': data['id']?.toString() ?? '',
        'alterId': _parseInt(data['aid']) ?? 0,
        'cipher': _firstNotEmpty([data['scy'], 'auto']),
        'udp': true,
        'tls': tls,
        'network': network,
      };

      final sni = _firstNotEmpty([data['sni'], data['host']]);
      if (tls && sni.isNotEmpty) proxy['servername'] = sni;
      final alpn = _splitCsv(data['alpn']);
      if (alpn.isNotEmpty) proxy['alpn'] = alpn;
      final fp = data['fp']?.toString();
      if (fp != null && fp.isNotEmpty) proxy['client-fingerprint'] = fp;

      if (network == 'ws') {
        proxy['ws-opts'] = {
          'path': _firstNotEmpty([data['path'], '/']),
          if ((data['host']?.toString() ?? '').isNotEmpty)
            'headers': {'Host': data['host'].toString()},
        };
      } else if (network == 'grpc') {
        proxy['grpc-opts'] = {
          'grpc-service-name': data['path']?.toString() ?? '',
        };
      }
      return _hasServer(proxy) ? proxy : null;
    } catch (_) {
      return null;
    }
  }

  static Map<String, Object?>? _parseVless(String link) {
    final uri = _parseProxyUri(link);
    if (uri == null) return null;
    final query = uri.queryParameters;
    final network = query['type'] ?? query['network'] ?? 'tcp';
    final tls = (query['security'] ?? '').toLowerCase();
    final proxy = <String, Object?>{
      'name': _uriName(uri, 'VLESS'),
      'type': 'vless',
      'server': uri.host,
      'port': uri.hasPort ? uri.port : 443,
      'uuid': _decode(uri.userInfo),
      'udp': true,
      'tls': tls == 'tls' || tls == 'reality',
      'network': network,
    };
    _copyIfNotEmpty(proxy, 'servername', query['sni'] ?? query['servername']);
    _copyIfNotEmpty(proxy, 'flow', query['flow']);
    _copyIfNotEmpty(proxy, 'client-fingerprint', query['fp']);
    _copyBool(proxy, 'skip-cert-verify', query['allowInsecure']);
    _applyTransportOptions(proxy, network, query);
    return _hasServer(proxy) ? proxy : null;
  }

  static Map<String, Object?>? _parseTrojan(String link) {
    final uri = _parseProxyUri(link);
    if (uri == null) return null;
    final query = uri.queryParameters;
    final network = query['type'] ?? query['network'] ?? 'tcp';
    final proxy = <String, Object?>{
      'name': _uriName(uri, 'Trojan'),
      'type': 'trojan',
      'server': uri.host,
      'port': uri.hasPort ? uri.port : 443,
      'password': _decode(uri.userInfo),
      'udp': true,
      'sni': query['sni'] ?? query['peer'] ?? query['servername'] ?? uri.host,
      'network': network,
    };
    _copyBool(proxy, 'skip-cert-verify', query['allowInsecure']);
    _applyTransportOptions(proxy, network, query);
    return _hasServer(proxy) ? proxy : null;
  }

  static Map<String, Object?>? _parseShadowsocks(String link) {
    try {
      final body = link.substring('ss://'.length);
      final hashIndex = body.indexOf('#');
      final rawServer = hashIndex == -1 ? body : body.substring(0, hashIndex);
      final name = hashIndex == -1
          ? 'Shadowsocks'
          : _decode(body.substring(hashIndex + 1));
      final pluginSplit = rawServer.split('?').first;

      String userInfo;
      String hostPort;
      if (pluginSplit.contains('@')) {
        final pieces = pluginSplit.split('@');
        userInfo = pieces.first;
        hostPort = pieces.sublist(1).join('@');
        if (!userInfo.contains(':')) {
          userInfo = utf8.decode(
            base64.decode(_normalizeBase64(userInfo)),
            allowMalformed: true,
          );
        } else {
          userInfo = _decode(userInfo);
        }
      } else {
        final decoded = utf8.decode(
          base64.decode(_normalizeBase64(pluginSplit)),
          allowMalformed: true,
        );
        final atIndex = decoded.lastIndexOf('@');
        if (atIndex == -1) return null;
        userInfo = decoded.substring(0, atIndex);
        hostPort = decoded.substring(atIndex + 1);
      }

      final methodPassword = userInfo.split(':');
      if (methodPassword.length < 2) return null;
      final portIndex = hostPort.lastIndexOf(':');
      if (portIndex == -1) return null;
      final proxy = <String, Object?>{
        'name': name.isEmpty ? 'Shadowsocks' : name,
        'type': 'ss',
        'server': hostPort.substring(0, portIndex),
        'port': int.tryParse(hostPort.substring(portIndex + 1)) ?? 8388,
        'cipher': methodPassword.first,
        'password': methodPassword.sublist(1).join(':'),
        'udp': true,
      };
      return _hasServer(proxy) ? proxy : null;
    } catch (_) {
      return null;
    }
  }

  static Map<String, Object?>? _parseHysteria2(String link) {
    final uri = _parseProxyUri(link);
    if (uri == null) return null;
    final query = uri.queryParameters;
    final proxy = <String, Object?>{
      'name': _uriName(uri, 'Hysteria2'),
      'type': 'hysteria2',
      'server': uri.host,
      'port': uri.hasPort ? uri.port : 443,
      'password': _decode(uri.userInfo),
    };
    _copyIfNotEmpty(proxy, 'sni', query['sni']);
    _copyBool(proxy, 'skip-cert-verify', query['insecure']);
    _copyIfNotEmpty(proxy, 'obfs', query['obfs']);
    _copyIfNotEmpty(
      proxy,
      'obfs-password',
      query['obfs-password'] ?? query['obfsPassword'],
    );
    return _hasServer(proxy) ? proxy : null;
  }

  static Map<String, Object?>? _parseTuic(String link) {
    final uri = _parseProxyUri(link);
    if (uri == null) return null;
    final query = uri.queryParameters;
    final credentials = _decode(uri.userInfo).split(':');
    final proxy = <String, Object?>{
      'name': _uriName(uri, 'TUIC'),
      'type': 'tuic',
      'server': uri.host,
      'port': uri.hasPort ? uri.port : 443,
      'uuid': credentials.isNotEmpty ? credentials.first : '',
      'password': credentials.length > 1
          ? credentials.sublist(1).join(':')
          : '',
      'udp-relay-mode': query['udp-relay-mode'] ?? 'native',
      'congestion-controller': query['congestion-controller'] ?? 'bbr',
    };
    _copyIfNotEmpty(proxy, 'sni', query['sni']);
    _copyBool(
      proxy,
      'skip-cert-verify',
      query['allowInsecure'] ?? query['insecure'],
    );
    final alpn = _splitCsv(query['alpn']);
    if (alpn.isNotEmpty) proxy['alpn'] = alpn;
    return _hasServer(proxy) ? proxy : null;
  }

  static Uri? _parseProxyUri(String link) {
    try {
      return Uri.parse(link);
    } catch (_) {
      return null;
    }
  }

  static void _applyTransportOptions(
    Map<String, Object?> proxy,
    String network,
    Map<String, String> query,
  ) {
    if (network == 'ws') {
      proxy['ws-opts'] = {
        'path': query['path'] ?? '/',
        if ((query['host'] ?? '').isNotEmpty)
          'headers': {'Host': query['host']},
      };
    } else if (network == 'grpc') {
      proxy['grpc-opts'] = {
        'grpc-service-name': query['serviceName'] ??
            query['service-name'] ??
            query['path'] ??
            '',
      };
    }
  }

  static String _encodeConfig(List<Map<String, Object?>> proxies) {
    final proxyNames = proxies.map((proxy) => proxy['name'] as String).toList();
    final proxyGroupItems = <String>[
      if (proxyNames.isNotEmpty) 'AUTO',
      ...proxyNames,
      'DIRECT',
    ];

    final config = <String, Object?>{
      'proxies': proxies,
      'proxy-groups': [
        {
          'name': 'PROXY',
          'type': 'select',
          'proxies': proxyGroupItems,
        },
        if (proxyNames.isNotEmpty)
          {
            'name': 'AUTO',
            'type': 'url-test',
            'proxies': proxyNames,
            'url': _defaultTestUrl,
            'interval': 300,
            'tolerance': 50,
          },
      ],
      'rules': ['MATCH,PROXY'],
    };

    const encoder = JsonEncoder.withIndent('  ');
    return '${encoder.convert(config)}\n';
  }

  static String _uniqueName(String name, Set<String> names) {
    final clean = name.trim().isEmpty ? 'Proxy' : name.trim();
    if (names.add(clean)) return clean;
    var index = 2;
    while (!names.add('$clean ($index)')) {
      index++;
    }
    return '$clean ($index)';
  }

  static String _uriName(Uri uri, String fallback) {
    if (uri.fragment.isEmpty) return fallback;
    final decoded = _decode(uri.fragment).trim();
    return decoded.isEmpty ? fallback : decoded;
  }

  static bool _hasServer(Map<String, Object?> proxy) {
    return (proxy['server']?.toString() ?? '').isNotEmpty;
  }

  static String _normalizeBase64(String value) {
    final clean = value
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('-', '+')
        .replaceAll('_', '/');
    final padding = (4 - clean.length % 4) % 4;
    return clean + ('=' * padding);
  }

  static String _decode(String value) {
    try {
      return Uri.decodeComponent(value);
    } catch (_) {
      return value;
    }
  }

  static String _firstNotEmpty(List<Object?> values) {
    for (final value in values) {
      final string = value?.toString() ?? '';
      if (string.isNotEmpty) return string;
    }
    return '';
  }

  static int? _parseInt(Object? value) {
    return int.tryParse(value?.toString() ?? '');
  }

  static List<String> _splitCsv(Object? value) {
    return (value?.toString() ?? '')
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static void _copyIfNotEmpty(
    Map<String, Object?> target,
    String key,
    String? value,
  ) {
    if (value != null && value.isNotEmpty) {
      target[key] = value;
    }
  }

  static void _copyBool(
    Map<String, Object?> target,
    String key,
    String? value,
  ) {
    if (value == null || value.isEmpty) return;
    target[key] = value == '1' || value.toLowerCase() == 'true';
  }
}
