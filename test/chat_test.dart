import 'package:flutter_test/flutter_test.dart';
import 'package:pacer/src/chat/chat_model.dart';

void main() {
  group('ChatMessage JSON round-trip', () {
    test('preserves all fields', () {
      const msg = ChatMessage(
        id: 'm1',
        teamId: 't1',
        userId: 'u1',
        userNama: 'Budi',
        body: 'Siap ikut Sabtu ini!',
        createdAt: null,
      );
      final restored = ChatMessage.fromJson(msg.toJson());
      expect(restored.id, 'm1');
      expect(restored.teamId, 't1');
      expect(restored.userId, 'u1');
      expect(restored.body, 'Siap ikut Sabtu ini!');
    });

    test('reads nested users(nama) join row', () {
      final msg = ChatMessage.fromJson({
        'id': 'm2',
        'team_id': 't1',
        'user_id': 'u2',
        'body': 'Hadir!',
        'created_at': '2026-10-10T06:00:00+00:00',
        'users': {'nama': 'Siti'},
      });
      expect(msg.userNama, 'Siti');
      expect(msg.createdAt, isNotNull);
    });

    test('tolerates missing join (realtime payloads carry no nama)', () {
      final msg = ChatMessage.fromJson({
        'id': 'm3',
        'team_id': 't1',
        'user_id': 'u3',
        'body': 'Gas!',
      });
      expect(msg.userNama, '');
      expect(msg.createdAt, isNull);
    });
  });

  group('isSendableBody', () {
    test('rejects blank and over-long bodies', () {
      expect(isSendableBody(''), isFalse);
      expect(isSendableBody('   '), isFalse);
      expect(isSendableBody('Halo'), isTrue);
      expect(isSendableBody(List.filled(1001, 'x').join()), isFalse);
      expect(isSendableBody(List.filled(1000, 'x').join()), isTrue);
    });
  });
}
