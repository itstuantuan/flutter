import 'dart:async';

import 'package:bots/features/chat/chat_pet.dart';

/// The chat companion animates continuously, which would keep
/// `pumpAndSettle` from ever settling. Pet tests opt back in explicitly.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  ChatPet.enabled = false;
  await testMain();
}
