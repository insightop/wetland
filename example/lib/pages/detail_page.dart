import 'package:material_ui/material_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:auto_route/auto_route.dart';

import 'package:wetland/wetland.dart';
import '../router/router.gr.dart';

@RoutePage()
class DetailPage extends StatelessWidget {
  final String title;

  /// 打开该详情的列表条目序号（仅用于示例中区分不同条目，不参与路由路径）。
  final int? number;

  const DetailPage({
    @PathParam() this.title = 'Detail',
    this.number,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(number == null ? title : '$title #$number')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => context.wetland.push(
                      DetailRoute(
                        title: '$title > $title',
                        number: number,
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
