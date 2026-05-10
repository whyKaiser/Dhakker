import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Testscren extends StatelessWidget {


  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Test Screen'
          ),
        ),
        body: Row(
          children:
          [
            Text(
              'Text 1'
            ),
            SizedBox(
              width: 100,
            ),
            Text(
                'Text 2'
            ),
          ],
        ),
      ),
    );
  }
}
