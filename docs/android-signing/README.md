# Android 正式签名与备案

当前包名为 `com.viitor.bot`。Release 使用本地 PKCS12 密钥库，未配置时不会退回 debug 签名。

## 本地签名材料

- `android/app/release.keystore`：正式签名私钥及证书，别名 `release`。
- `android/key.properties`：密钥库位置及密码。

这两个文件已被 Git 忽略，权限为 600。请将二者一起备份到安全位置；换电脑或 CI 构建时恢复到相同位置。后续版本继续使用同一密钥，不要重新生成或丢失。密码不放入文档、日志或版本库。

## 备案信息

`filing-info.txt` 包含可复制的包名、十六进制 RSA 公钥模数及证书 MD5；`release-certificate.pem` 为对应的公开证书，不含私钥。信息从本次生成的正式签名证书提取，尚未经过最终 APK 核对。

准备好 Java、Android SDK 和 Flutter Android 工具链后执行：

```bash
flutter build apk --release
```

输出为 `build/app/outputs/flutter-apk/app-release.apk`。使用 Android SDK 的 `apksigner verify --verbose --print-certs` 校验最终 APK，其 signer certificate MD5 应与 `filing-info.txt` 一致。也可以用 JADX 的 APK signature 查看公钥和 MD5。

如果分发平台重新签名，应以实际分发 APK 的签名证书信息为准。
