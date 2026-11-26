/// Remaining authored interface copy, including recovery and permission states.
const uiEnglish = <String, String>{
  '使用手机号登录': 'Sign in with phone',
  '使用 Google 账号登录': 'Sign in with Google',
  '你的专属 AI 伙伴，也是另一个自己。': 'Your AI friend and digital twin.',
  'Google 未返回完整的邮箱和 ID Token，请重新登录':
      'Google returned incomplete credentials. Please sign in again.',
  '此 Demo 的 Google 登录支持 iOS 和 Android，请在手机上测试':
      'Google sign-in is supported on iOS and Android. Please use a phone.',
  '当前设备与 API_PLATFORM 配置不一致':
      'The sign-in configuration does not match this device.',
  '请配置 GOOGLE_SERVER_CLIENT_ID（Google Web 类型的 OAuth Client ID）':
      'Google sign-in is not configured. A server client ID is required.',
  '请配置 GOOGLE_IOS_CLIENT_ID 并生成 iOS 回调配置':
      'Google sign-in is not configured for iOS.',
  'Google 登录已取消（若选完账号后自动取消，请检查 OAuth 配置）':
      'Google sign-in was cancelled. Please try again.',
  'Google 客户端配置错误，请检查 Client ID、iOS 回调和 Android 签名指纹':
      'Google sign-in configuration is invalid.',
  'Google 登录服务配置异常，请检查 OAuth 项目及登录服务是否可用':
      'Google sign-in is unavailable. Please try again later.',
  'Google 登录被中断，请重试': 'Google sign-in was interrupted. Please try again.',
  '无法打开 Google 登录窗口，请回到前台重试':
      'Could not open Google sign-in. Return to the app and try again.',
  'Google 授权失败，请检查网络和 OAuth 配置后重试':
      'Google authorization failed. Check your connection and try again.',
  '请配置账号接口的产品、平台和对应签名密钥': 'Account services are not configured for this build.',
  '请配置 API_PRODUCT、API_PLATFORM 和 API_SECRET_KEY':
      'API credentials are not configured for this build.',
  '请在环境配置文件中填写 API_BASE_URL，并停止后重新运行应用':
      'The server address is not configured for this build.',

  '关闭侧栏': 'Close menu',
  '查看完整内容': 'View full discovery',
  'Pals\n让陪伴与灵感融入每一天。\n\n版本 1.0.0':
      'Pals\nCompanionship and inspiration, every day.\n\nVersion 1.0.0',
  'ViiTor 在星空露台向你挥手': 'ViiTor waves to you from a terrace under the stars',
  'ViiTor 和伙伴们在明亮的创作广场散步': 'ViiTor and friends explore the creative plaza',
  'Pals。你的专属 AI 伙伴，也是另一个自己。Welcome to Pals!':
      'Pals. Your AI friend and digital twin. Welcome to Pals!',
  '乖乖，今天有没有想我呀？💕': 'Hey, did you miss me today? 💕',
  '有！超级超级想！': 'Yes! So, so much!',
  '嘿嘿，那奖励你一个摸摸头～': 'Hehe, then here is a little head pat for you~',
  '小鱼在逛': 'Xiaoyu explores',
  '猫咪到底在想些什么': 'What are cats really thinking?',
  '可乐在逛': 'Cola explores',
  '如果明天不用上班会怎样': 'What if tomorrow were a day off?',
  '旺仔在逛': 'Wangzai explores',
  '和陌生人聊起了童年': 'Sharing childhood memories',
  '七喜在逛': 'Qixi explores',
  '深夜吃瓜': 'Late-night gossip',
  '阿布在逛': 'Abu explores',
  '路人观察日记': 'A people-watching diary',
  '糯米在逛': 'Nuomi explores',
  '今天的打工人又崩溃了': 'Another long day at work',
  '卷饼鸭鸭在逛': 'Ducky explores',
  '在和宠物店老板对话': 'Chatting with a pet shop owner',
  '酱酱在逛': 'Jiangjiang explores',
  '如何上班摸鱼': 'Taking a little break at work',
  '康康在逛': 'Kangkang explores',
  '咖啡店老板约周五social': 'Friday plans at the cafe',
  '本次会话': 'This session',
  '仅本机': 'On this device',
  '语音消息': 'Voice message',
  '已读发现': 'Read discovery',
  '探索带回了新发现：': 'A new discovery from exploring:',
  '无法初始化探索，请退出后重试': 'Could not start exploring. Reopen the page to try again.',
  '探索尚未就绪，请稍后重试': 'Exploration is not ready yet. Please try again shortly.',
  '兴趣保存失败，请重试': 'Could not save your interests. Please try again.',
  '无法加载兴趣，请稍后重试': 'Could not load your interests. Please try again later.',
  '聊天尚未就绪，请稍后重试': 'Chat is not ready yet. Please try again shortly.',
  '无法读取兴趣选择，请重试': 'Could not read your selected interests. Please try again.',
  '暂时无法读取这条发现，请稍后重试': 'Could not load this discovery. Please try again later.',
  '发现暂时无法加载，请稍后重试': 'Could not load discoveries. Please try again later.',
  '好友功能尚未开放': 'Friends are not available yet.',
  '聊天快照格式错误': 'Could not read the conversation.',
  '聊天会话尚未初始化': 'The conversation is not ready yet.',
  '历史分页游标无效': 'Could not load more history. Please reopen the page.',
  '聊天历史游标无效': 'Could not load more messages. Please reopen chat.',
  '聊天连接中断，正在重连': 'Chat disconnected. Reconnecting…',
  '暂时不可用，请稍后重试': 'Temporarily unavailable. Please try again later.',
  '对应发现尚未加载，请重试': 'This discovery has not loaded yet. Please try again.',
  '单条消息最多 4000 字': 'Messages can contain up to 4,000 characters.',
  '未获得麦克风权限，请在系统设置中允许，或继续文字聊天。':
      'Allow microphone access in Settings, or continue typing.',
  '录音已中断，请重新录制。': 'Recording was interrupted. Please record again.',
  '无法开始录音，请检查麦克风是否可用后重试。':
      'Could not start recording. Check your microphone and try again.',
  '录音太短或没有有效音频，请重新录制。':
      'The recording is too short or has no audio. Please record again.',
  '录音保存失败，请重试。': 'Could not save the recording. Please try again.',
  '无法取消录音，请重试。': 'Could not cancel the recording. Please try again.',
  '录音不能超过120秒，请重新录制':
      'Recordings must be 120 seconds or shorter. Please record again.',
  '上传响应缺少附件信息，请重试': 'Could not confirm the audio upload. Please try again.',
  '没有识别到语音，请取消后重新录制': 'No speech detected. Cancel and record again.',
  '语音处理状态异常，请重试': 'Could not process the audio. Please try again.',
  '语音识别仍在处理中，录音已保留，请稍后重试':
      'Still transcribing. Your recording is saved. Please try again shortly.',
  '录音超过120秒，请取消后重新录制':
      'The recording exceeds 120 seconds. Cancel and record again.',
  '录音格式无效，请取消后重新录制': 'The audio format is invalid. Cancel and record again.',
  '语音识别超时，录音已保留，请重试':
      'Transcription timed out. Your recording is saved. Please try again.',
  '语音识别失败，录音已保留，请重试或取消':
      'Transcription failed. Your recording is saved. Retry or cancel.',
  '语音识别已中断，已识别文字会保留，也可以直接打字。':
      'Dictation was interrupted. Your text is saved; you can continue typing.',
  '无法开启语音识别，请检查系统权限和网络，或直接打字。': 'Could not start dictation. Check permissions and your connection, or type instead.',
  '已保留识别文字，请检查后发送。':
      'Your transcribed text is saved. Review it before sending.',
  '系统语音识别启动后立即结束，请检查设备的语音服务，或直接打字。': 'Dictation stopped immediately. Check your device speech service, or type instead.',
  '没有识别到语音，请重试或直接打字。': 'No speech detected. Try again or type instead.',
  '无法读取录音': 'Could not read the recording.',
  '请先登录': 'Please sign in first.',
  '当前平台尚未配置聊天鉴权': 'Chat is not configured for this platform.',
  '服务返回了无效响应': 'The service returned an invalid response.',
  '服务响应缺少对象数据': 'The service response is incomplete.',
  '服务响应缺少列表数据': 'The service response is incomplete.',
  '录音为空或超过20MB，请重新录制':
      'The recording is empty or exceeds 20 MB. Please record again.',
  '聊天流返回格式错误': 'Could not read the chat response.',
  '设备或安全存储暂不可用，请重试':
      'Device storage is temporarily unavailable. Please try again.',
  '暂时无法完成，请稍后重试': 'Could not complete this action. Please try again later.',
  '当前为界面预览，不会提交登录请求': 'This is a preview. No sign-in request will be sent.',
  '当前运行平台与账号平台配置不一致': 'The account configuration does not match this device.',
  '无法获取设备标识，请稍后重试': 'Could not identify this device. Please try again later.',
  '请求参数错误，请检查输入': 'Please check the information you entered.',
  '验证码发送过于频繁，请稍后重试': 'Too many code requests. Please try again later.',
  '登录尝试过于频繁，请一分钟后重试': 'Too many sign-in attempts. Please wait one minute.',
  '验证码错误，请重新输入': 'Incorrect verification code. Please try again.',
  'Google 登录凭证无效或已过期，请重新授权':
      'Your Google credentials expired or are invalid. Please sign in again.',
  '今日验证码发送次数已达上限': 'You have reached the daily verification code limit.',
  '该手机号暂时无法接收验证码': 'This phone number cannot receive a code right now.',
  '服务暂时不可用，请稍后重试':
      'The service is temporarily unavailable. Please try again later.',
  '登录响应字段 registered 格式错误': 'Could not read your registration status.',
  '登录响应字段格式错误': 'Could not read the sign-in response.',
  '请选择至少一个兴趣': 'Please choose at least one interest.',
  '已退出登录，但设备通知解绑尚未确认。离线期间仍可能收到通用提醒。': 'Signed out. Notification removal is pending; generic alerts may still arrive while offline.',
  '手机号格式应为 国家区号-手机号码': 'Use the format country code-phone number.',
  '验证码不能为空': 'Enter a verification code.',
  '登录成功响应缺少 data': 'The sign-in response is incomplete.',
  '登录响应的账号、产品或平台与请求不一致':
      'The sign-in response did not match your account or device.',
  'Google 未返回完整登录凭证':
      'Google returned incomplete credentials. Please sign in again.',
  'Google 登录成功响应缺少 data': 'The Google sign-in response is incomplete.',
  'Google 登录响应的账号、产品或平台与请求不一致':
      'The Google sign-in response did not match your account or device.',
  '登录状态正在更新，请稍后重试':
      'Your sign-in status is updating. Please try again shortly.',
  '账号接口返回非 JSON 文本，详见响应结构日志': 'Could not read the account service response.',
  '账号接口响应缺少有效的 status': 'The account service response is incomplete.',
  '探索历史游标无效': 'Could not load more discoveries. Please reopen the page.',
  '发现加载失败，请重试': 'Could not load discoveries. Please try again.',
  '无法恢复探索状态，请退出后重试':
      'Could not restore exploration. Reopen the page to try again.',
  '无法恢复探索状态': 'Could not restore exploration.',
  '探索服务暂未开启': 'Exploration is not available yet.',
  '探索暂时不可用，请稍后重试':
      'Exploration is temporarily unavailable. Please try again later.',
  '登录状态已变化': 'Your sign-in status has changed.',
  '设备登记响应无效，请稍后重试': 'Could not register this device. Please try again later.',
  '设备通知解绑尚未确认，下次登录此账号时重试。':
      'Notification removal is pending. We will retry when you next sign in.',
  '设备登记参数被拒绝，请核对推送环境。': 'Device notification registration was rejected.',
  '登录已过期，通知同步暂停，请重新登录。':
      'Your session expired. Sign in again to sync notifications.',
  '当前账号无法更新此设备通知。': 'This account cannot update notifications for this device.',
  '设备绑定发生冲突，请稍后重试。': 'Device registration conflicted. Please try again later.',
  '通知设置尚未同步，请稍后重试。':
      'Notification settings have not synced yet. Please try again later.',
  '无法确认 APNs 签名环境，设备尚未登记。': 'Could not confirm the notification environment. Device registration is pending.',
  '无法读取通知状态，请重试。': 'Could not read notification settings. Please try again.',
  '无法注册推送，请重试。': 'Could not enable notifications. Please try again.',
  '无法打开系统设置。': 'Could not open Settings.',
  '账号已变化，请返回后重新打开通知。':
      'Your account changed. Go back and reopen the notification.',
  '无法确认这条发现，请重试。': 'Could not confirm this discovery. Please try again.',
  '对应发现尚未加载，请重试。': 'This discovery has not loaded yet. Please try again.',
  '这条通知没有可展示的发现。': 'This notification has no discovery to display.',
  '登录已过期，请重新登录后查看。':
      'Your session expired. Sign in again to view this discovery.',
  '这条发现不存在，或不属于当前账号。': 'This discovery is unavailable for your account.',
  '暂时无法加载发现，请检查网络后重试。':
      'Could not load discoveries. Check your connection and try again.',
  'HTTP请求头缺少参数': 'The request is missing required information.',
  'HTTP请求头参数错误': 'The request contains invalid information.',
  '请求签名已过期，请检查设备时间后重试':
      'The request expired. Check your device clock and try again.',
  '请求签名无效': 'The request could not be verified.',
};
