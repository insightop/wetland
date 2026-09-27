import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:wetland/wetland.dart';
import '../router/router.gr.dart';

/// 可复用的实体列表页。
///
/// 消息 / 联系人 / 发现三个主 tab 共用此实现，仅 [title] 不同，
/// 避免三处近乎逐行相同的列表代码（DRY）。
class EntityListPage extends StatelessWidget {
  /// 列表标题，同时作为详情页标题的来源。
  final String title;

  const EntityListPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.builder(
        itemBuilder: (context, index) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.accents[index % Colors.accents.length],
            ),
            trailing: const Icon(Icons.arrow_forward_ios),
            title: Skeletonizer(
              effect: const SolidColorEffect(),
              child: Text('$title $index'),
            ),
            subtitle: Skeletonizer(
              effect: const SolidColorEffect(),
              child: const Text('tap to open detail'),
            ),
            onTap: () => context.wetland.push(DetailRoute(title: title)),
          );
        },
      ),
    );
  }
}
