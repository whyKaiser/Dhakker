
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

void NextWidget({
  required context,
  required Widget screen,
})
{

  Navigator.pushAndRemoveUntil(context,
      MaterialPageRoute(
          builder: (context)=>screen),
          (route) => false);
}


void GoToScreen({
  required context,
  required Widget screen,
})
{
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context)=>screen),
  );
}