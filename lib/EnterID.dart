import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class EnterID extends StatelessWidget{
  final TextEditingController _controller = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Card(
          margin: EdgeInsets.symmetric(horizontal: 12),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: "ENTER YOUR ID"
                  ),
                  autofocus: true,
                  controller: _controller,
                ),
                SizedBox(height: 12,),
                Center(
                  child: FlatButton(
                    onPressed: (){
                      Navigator.pop(context,_controller.text);
                    },
                    child: Text("SAVE"),
                  ),
                ),
                SizedBox(height: 12,),
              ],
            ),
          ),
        ),
      ),
    );
  }
}