import 'package:bots/features/auth/startup_profile_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'legacy unowned name and intro are never inherited by an account',
    () async {
      const store = StartupProfileStore();
      await store.write({
        'name': 'Legacy name',
        'introDone': true,
        'page': 'world',
        'registrationChats': {'a': 'done', 'b': 'pending'},
      });
      expect(await store.readUser('a'), {
        'registrationChat': 'done',
        'introDone': true,
      });
      expect(await store.readUser('b'), {'registrationChat': 'pending'});
      expect(await store.readUser('new-account'), isEmpty);
    },
  );

  test(
    'names, intro, registration and interests survive switching independently',
    () async {
      const store = StartupProfileStore();
      await store.writeUser('a', {
        'name': 'Alice',
        'introDone': true,
        'registrationChat': 'done',
      });
      await store.saveSelectedInterests('a', ['音乐']);
      await store.writeUser('b', {
        'name': 'Bob',
        'page': 'world',
        'registrationChat': 'pending',
      });
      await store.saveSelectedInterests('b', ['旅行']);
      const reopened = StartupProfileStore();
      expect(await reopened.readUser('a'), {
        'name': 'Alice',
        'introDone': true,
        'registrationChat': 'done',
      });
      expect(await reopened.readUser('b'), {
        'name': 'Bob',
        'page': 'world',
        'registrationChat': 'pending',
      });
      expect((await reopened.read())['interestsByUser'], {
        'a': ['音乐'],
        'b': ['旅行'],
      });
      expect(await reopened.readUser('c'), isEmpty);
      expect(await reopened.hasSelectedInterests('c'), isFalse);
      await expectLater(store.readUser(''), throwsArgumentError);
      await expectLater(
        store.writeUser('', {'name': 'invalid'}),
        throwsArgumentError,
      );
    },
  );
}
