// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AccountSession _$AccountSessionFromJson(Map<String, dynamic> json) =>
    $checkedCreate('AccountSession', json, ($checkedConvert) {
      final val = AccountSession(
        registered: $checkedConvert('registered', (v) => (v as num).toInt()),
        uid: $checkedConvert('uid', (v) => v as String),
        nick: $checkedConvert('nick', (v) => v as String),
        avatar: $checkedConvert('avatar', (v) => v as String? ?? ''),
        phone: $checkedConvert('phone', (v) => v as String? ?? ''),
        product: $checkedConvert('product', (v) => v as String),
        platform: $checkedConvert('platform', (v) => v as String),
        token: $checkedConvert('token', (v) => v as String),
        email: $checkedConvert('email', (v) => v as String? ?? ''),
      );
      return val;
    });

Map<String, dynamic> _$AccountSessionToJson(AccountSession instance) =>
    <String, dynamic>{
      'registered': instance.registered,
      'uid': instance.uid,
      'nick': instance.nick,
      'avatar': instance.avatar,
      'phone': instance.phone,
      'product': instance.product,
      'platform': instance.platform,
      'token': instance.token,
      'email': instance.email,
    };
