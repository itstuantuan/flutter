import 'package:bots/features/auth/startup_profile_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'interest completion survives reopening, is per account and resets',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      const store = StartupProfileStore();
      expect(await store.hasSelectedInterests('a'), isFalse);
      await store.write({'name': '小宝'});
      await store.saveSelectedInterests('a', ['音乐', '音乐']);
      const reopened = StartupProfileStore();
      expect(await reopened.hasSelectedInterests('a'), isTrue);
      expect(await reopened.hasSelectedInterests('b'), isFalse);
      expect((await reopened.read())['name'], '小宝');
      await expectLater(
        store.saveSelectedInterests('b', []),
        throwsArgumentError,
      );
      expect(await store.hasSelectedInterests('b'), isFalse);
      await store.clear();
      expect(await reopened.hasSelectedInterests('a'), isFalse);
    },
  );
}
