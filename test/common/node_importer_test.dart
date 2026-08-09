import 'dart:convert';

import 'package:bett_box/common/node_importer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates a blank local profile config', () {
    final content = NodeImporter.blankProfileContent();

    expect(content, contains('"proxy-groups"'));
    expect(content, contains('"DIRECT"'));
    expect(content, contains('"MATCH,PROXY"'));
  });

  test('imports a vmess node', () {
    final payload = base64.encode(
      utf8.encode(
        json.encode({
          'v': '2',
          'ps': 'demo',
          'add': 'example.com',
          'port': '443',
          'id': '00000000-0000-0000-0000-000000000000',
          'aid': '0',
          'net': 'ws',
          'type': 'none',
          'host': 'example.com',
          'path': '/ws',
          'tls': 'tls',
        }),
      ),
    );

    final result = NodeImporter.fromText('vmess://$payload');

    expect(result.count, 1);
    expect(result.content, contains('"type": "vmess"'));
    expect(result.content, contains('"name": "demo"'));
    expect(result.content, contains('"ws-opts"'));
  });

  test('imports multiple links from a base64 subscription', () {
    final subscription = base64.encode(
      utf8.encode(
        [
          'trojan://password@example.com:443?sni=example.com#trojan-demo',
          'vless://00000000-0000-0000-0000-000000000000@example.org:443?security=tls&type=tcp#vless-demo',
        ].join('\n'),
      ),
    );

    final result = NodeImporter.fromText(subscription);

    expect(result.count, 2);
    expect(result.content, contains('"type": "trojan"'));
    expect(result.content, contains('"type": "vless"'));
    expect(result.content, contains('"AUTO"'));
  });
}
