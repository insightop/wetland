import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

class DetailPage extends StatelessWidget {
  final String title;
  const DetailPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) =>
            [
          SliverAppBar(
            expandedHeight: 150.0,
            floating: false,
            pinned: true,
            // snap: true,
            stretch: true,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              collapseMode: CollapseMode.parallax,
              title: Text(title),
              // background: background,
            ),
          )
        ],
        body: Column(
          children: [
            Skeletonizer(
              effect: SoldColorEffect(),
              child: ListTile(
                isThreeLine: true,
                leading: CircleAvatar(),
                // trailing: Icon(Icons.arrow_forward_ios),
                title: Text('$title Detail '),
                subtitle: Container(
                  height: 500,
                  child: Wrap(children: [
                    Text('${List.generate(100, (index) => 'wetland')}')
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
