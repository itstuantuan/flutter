import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/chat/chat_discovery_detail.dart';
import 'features/chat/chat_page.dart';
import 'features/chat/chat_message.dart';
import 'features/discoveries/all_discoveries_page.dart';
import 'features/home/home_page.dart';

// Explicit offline design entry point. Production still starts at main.dart.
const previewDiscoveries = <Map<String, dynamic>>[
  {
    'materialId': 'pets',
    'title': '奶牛猫的花纹你见过哪一种?',
    'category': 'pets',
    'timeLabel': '今天 10:32',
    'summary': '每一只奶牛猫都有不同的花纹，来聊聊你见过的可爱猫咪。',
  },
  {
    'materialId': 'music',
    'title': '听歌时,你更在意旋律还是歌词?',
    'category': 'music',
    'timeLabel': '今天 10:32',
    'summary': '从格莱美说唱类奖项页面寻找作品，比较不同的节奏与叙事。哪句表达让你记住一首歌？不用会唱，也能聊聊自己的感受。',
  },
  {
    'materialId': 'film',
    'title': '电影结局,要不要留白?',
    'category': 'film_tv',
    'timeLabel': '昨天',
    'summary': '一个开放的结局，可能让故事在散场后继续。你喜欢怎样的电影结局？',
  },
  {
    'materialId': 'travel',
    'title': '电影结局,要不要留白?哈哈哈哈哈哈哈哈 还得去呼呼呼',
    'category': 'travel',
    'timeLabel': '10-11',
    'summary': '从熟悉的街道出发，发现城市里不一样的风景。',
  },
];

void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    home: const DiscoveryPreview(),
  ),
);

class DiscoveryPreview extends StatelessWidget {
  const DiscoveryPreview({super.key});
  @override
  Widget build(BuildContext context) {
    void chat({Map<String, dynamic>? selected}) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ChatPage(
          name: 'Tony',
          returningUser: true,
          discoveryCards: [
            ?selected,
            ...previewDiscoveries.where((c) => c != selected),
          ],
          messages: const [
            ChatMessage('先认识一下你', isUser: true),
            ChatMessage('好呀,我挺好奇的,喜欢到处逛逛碰到有意思的东西就想找人分享,不过今天还没出门,先陪你待会儿.'),
            ChatMessage('那你平时没事的时候喜欢干什么', isUser: true),
            ChatMessage('听听歌,随便走走,有时候一首歌循环好几遍,路都感觉走短了.'),
          ],
          onExit: () => Navigator.pop(context),
          onExplore: () => showDialog<void>(
            context: context,
            builder: (_) => ChatDiscoveryDetail(card: previewDiscoveries.first),
          ),
        ),
      ),
    );
    return HomePage(
      onMenu: () {},
      onExplore: () => chat(),
      onChat: () => chat(),
      onVoice: () => chat(),
      onDiscovery: (i) => chat(selected: previewDiscoveries[i]),
      onAllDiscoveries: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AllDiscoveriesPage(
            cards: previewDiscoveries,
            onOpen: (card) => chat(selected: card),
          ),
        ),
      ),
    );
  }
}
