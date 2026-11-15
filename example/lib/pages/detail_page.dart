import 'package:material_ui/material_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:auto_route/auto_route.dart';

import 'package:wetland/wetland.dart';
import '../router/router.gr.dart';

@RoutePage()
class DetailPage extends StatelessWidget {
  final String title;

  /// 打开该详情的列表条目（仅用于示例中区分不同条目，不参与路由路径）。
  final String? item;

  const DetailPage({
    @PathParam() this.title = 'Detail',
    this.item,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          if (item != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('item: $item'),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => context.wetland.push(
                      DetailRoute(
                        title: '$title > $title',
                        item: item == null ? null : '$item > $item',
                      ),
                    ),
                    child: const Text('drill-down'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.wetland.pop(),
                    child: const Text('pop-detail'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                Skeletonizer(
                  effect: const SolidColorEffect(),
                  child: ListTile(
                    isThreeLine: true,
                    leading: const CircleAvatar(),
                    title: Text('$title Detail '),
                    subtitle: SizedBox(
                      height: 500,
                      child: Wrap(
                        children: [
                          Text('${List.generate(100, (index) => 'wetland')}'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
