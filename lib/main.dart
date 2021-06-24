import 'dart:async';
import 'dart:html' as html;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_for_web/image_picker_for_web.dart';
import 'package:talkto/Caler.dart';
import 'package:talkto/Callee.dart';
import 'package:talkto/EnterID.dart';
import 'package:firebase/firebase.dart' as fb;


void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Talk To',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget{
  static String userID;
  static bool agree = false;
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver{

  List<DocumentSnapshot> post = [];
  StreamSubscription _subs;
  ValueNotifier<bool> _dirty = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    initAll();
    html.window.onUnload.listen((event) async{
      await _goOffline(HomePage.userID);
    });
    WidgetsBinding.instance.addObserver(this);
  }

  bool inCall = false;
  initAll() async{
    await Future.delayed(Duration(seconds: 1));
    HomePage.userID = await showDialog(context: context,builder: (context)=>EnterID(),barrierDismissible: false);
    if(HomePage.userID==null){
      return;
    }
    print(HomePage.userID);
    await Firestore.instance.document("Users/${HomePage.userID}").setData({
      "time":DateTime.now().millisecondsSinceEpoch,
      "active":true,
    });
    _subCal = Firestore.instance.collection("Calls").where("target",isEqualTo: HomePage.userID).where("active", isEqualTo: true).snapshots().listen((event) {
      if(event.documents.isNotEmpty){
      if(inCall){
        return;
      }
        DocumentSnapshot doc = event.documents.first;
        showDialog(context: context,builder:(ctx)=>AlertDialog(
          title: Text("NEW CALL FROM ${doc['caller']}"),
          actions: [
            FlatButton(
              onPressed: () async{
                doc.reference.setData({
                  "target_accept":true
                },merge: true);
                inCall = true;
                Navigator.pop(ctx);
                await Navigator.push(context, MaterialPageRoute(builder: (context)=>Caler(doc['caller'], doc.documentID,doc)));
                inCall = false;
              },
              child: Text("ACCEPT"),
            ),
            FlatButton(
              onPressed: (){
                doc.reference.delete();
                Navigator.pop(ctx);
              },
              child: Text("REJECT"),
            ),
          ],
        ));
      }
    }, onError: (err){
      print("ERROR $err");
    });
    Firestore.instance.document("Params/agree").get().then((value){
      HomePage.agree = value['agree']??true;
    }).catchError((err){
      print("ERRRRR AGREE $err");
    });
    _subs = Firestore.instance.collection("Users").snapshots().listen((event) {
      setState(() {
        post.clear();
        event.documents.forEach((element) {
          if(element.documentID!=HomePage.userID){
            this.post.add(element);
          }
        });
      });
    }, onError: (err){
      print("ERRRRR LISTEN $err");
    });
  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async{
    if(state==AppLifecycleState.inactive){
      await _goOffline(HomePage.userID);
    }else if(state == AppLifecycleState.resumed){
      if(HomePage.userID!=null && HomePage.userID.isNotEmpty){
        await Firestore.instance.document("Users/${HomePage.userID}").setData({
          "active":true
        },merge: true);
      }
    }
  }

  StreamSubscription _subCal;
  TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subs?.cancel();
    _subCal?.cancel();
    _controller.dispose();
    super.dispose();
  }

  static _goOffline(String id) async{
    await Firestore.instance.document("Users/$id").setData({
      "active":false
    },merge: true);
  }
  
//  mode model = mode.MODE_SCREEN;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async{
        await _goOffline(HomePage.userID);
        return true;
      },
      child: SafeArea(
        child: Scaffold(
        appBar:AppBar(
        title: Text("Talkto"),
        ),
          body: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: "Enter Caller ID",
                  ),
                  controller: _controller,
                  onChanged: (value){
                    _dirty.value = value.length>2;
                  },
                ),
                SizedBox(height: 12,),
                Text("Available Users", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),textScaleFactor: 1,),
                SizedBox(height: 12,),
                Flexible(
                  fit: FlexFit.tight,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount:post.length ,
                    itemBuilder: (context,index){
                      return ListTile(
                        title: Text(post[index].documentID),
                        subtitle: Text("CALLER ID . (${(post[index]['active']??false)?"ACTIVE NOW":"OFFLINE"})"),
                        trailing: Icon(Icons.call, color: (post[index]['active']??false)?Colors.green:Colors.grey,),
                        onTap:(post[index]['active']??false)? (){
                          _dirty.value = true;
                          _controller.text = post[index].documentID;
                        }:null,
                      );
                    },
                  ),
                ),
                SizedBox(height: 48,),
              ],
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          floatingActionButton: ValueListenableBuilder(
            valueListenable: _dirty,
            builder: (context,value,_) {
              return FloatingActionButton.extended(onPressed: value?() async{
                inCall = true;
                await Navigator.push(context, MaterialPageRoute(builder: (context)=>Callee(_controller.text), maintainState: true));
                inCall = false;
              }:null, label: Padding(
                padding: const EdgeInsets.symmetric(horizontal:20.0),
                child: Text("CALL"),
              ),
              disabledElevation: 1,
                elevation: 1,
                foregroundColor: Colors.white,
                backgroundColor: value?Colors.blue:Colors.grey,
              );
            },
          ),
          bottomNavigationBar: BottomAppBar(
            child: path.isEmpty?FlatButton(
              onPressed: (){
                ImagePickerPlugin().pickImage(source: ImageSource.gallery).then((value) async{
                  if(value!=null){
                    this.path = value.path;
                    final ref = fb.storage().refFromURL("gs://talkto-33284.appspot.com").child("Test");
                    final task = ref.put(await value.readAsBytes());
                    await task.future;
                    final url = (await ref.getDownloadURL()).toString();
                    this.path = url;
                    setState(() {

                    });
                  }
                });
              },
              child: Text("PICK MEDIA"),
            ):Image.network(path),
          ),
        ),
      ),
    );
  }
  String path = "";
}

//enum mode{MODE_SCREEN,MODE_VIDE,MODE_AUDIO}