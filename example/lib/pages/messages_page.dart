import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'detail_page.dart';

class MessagesPage extends StatelessWidget {
  final String title;
  const MessagesPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: ListView.builder(
          itemBuilder: (context, index) {
            return
                // Card(
                // child:
                ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.accents[index % Colors.accents.length],
              ),
              trailing: Icon(Icons.arrow_forward_ios),
              title: Skeletonizer(
                effect: SoldColorEffect(),
                child: Text('$title $index'),
              ),
              subtitle: Skeletonizer(
                effect: SoldColorEffect(),
                child: Text('click to show detail'),
              ),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => DetailPage(title: title)));
              },
              // ),
            );
          },
        ),
      ),
    );
  }
}
