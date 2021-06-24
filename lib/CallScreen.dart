import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/web/rtc_ice_candidate.dart';
import 'package:flutter_webrtc/web/rtc_peerconnection_factory.dart';
import 'package:flutter_webrtc/web/get_user_media.dart';
import 'package:flutter_webrtc/web/media_stream.dart';
import 'package:flutter_webrtc/web/rtc_peerconnection.dart';
import 'package:flutter_webrtc/web/rtc_video_view.dart';
import 'package:talkto/main.dart';

class CallScreen extends StatefulWidget{
  final String doc;

  CallScreen(this.doc);

  @override
  _CallScreenState createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {

  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  MediaStream _localStream;
  RTCPeerConnection _peerConnection;
  MediaStream _remoteStream;

  ValueNotifier<String> _msg = ValueNotifier("");

  Map<String, dynamic> _iceServers = {
    'iceServers': [
      {
        'urls': [
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
        ],
      },
    ],
    'iceCandidatePoolSize': 10,
  };
//
//  final Map<String, dynamic> _config = {
//    'mandatory': {},
//    'optional': [
//      {'DtlsSrtpKeyAgreement': true},
//    ],
//  };

  final Map<String, dynamic> _constraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': true,
    },
    'optional': [],
  };


  @override
  void initState() {
    super.initState();
   initialize();
  }

  initialize(){
    _localRenderer.initialize();
    _remoteRenderer.initialize();
  }

  @override
  void deactivate() {
    handUp();
    super.deactivate();
  }



  bool _mediaOpen = false;
  bool _roomCreated = false;
  bool _roomJoined = false;
  bool _inCalling = false;


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Tallk To"),
        elevation: 1,
        actions: [
          IconButton(
            onPressed: (){
              getUserMedia();
            },
            icon: Icon(Icons.camera),
          ),
          IconButton(
            onPressed: (){
              createRoom();
            },
            icon: Icon(Icons.add),
          ),

          IconButton(
            onPressed:(){
              joinRoom();
            },
            icon: Icon(Icons.merge_type),
          )
        ],
      ),
      body: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.blue,
              child: RTCVideoView(_remoteRenderer),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.amber,
              child: RTCVideoView(_localRenderer),
            ),
          ),
          Flexible(
            child: ValueListenableBuilder<String>(
              valueListenable: _msg,
              builder: (context,value,_){
                return Text(value);
              },
            ),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async{
          final Map<String, dynamic> _constraints = {
            'mandatory': {
              'OfferToReceiveAudio': true,
              'OfferToReceiveVideo': true,
            },
            'optional': [],
          };
          await _peerConnection.createOffer(_constraints);
        },
        child: Icon(_inCalling?Icons.call_end:Icons.call),
        elevation: 1,
      ),
    );
  }


  Future<void> createRoom() async{
    _peerConnection = await createPeerConnection(_iceServers, _constraints);
    registerPeerListeners();
    await _peerConnection.addStream(_localStream);
     _peerConnection.onAddStream = (stream){
      this._remoteStream = stream;
      _remoteRenderer.srcObject = _remoteStream;
      _msg.value = _msg.value+"  || "+"NEW STREAM ADDED CR";
    };

    _msg.value = _msg.value+"  || "+"ROOM CREATED PEERS";
     setState(() {
       _roomCreated = true;
     });
  }

  registerPeerListeners(){
    _peerConnection.onIceGatheringState = (state){
      print("ICE ICE GATHERING STATE");
      _msg.value = _msg.value+"  || "+"ICE GATHERING $state";
      print(state.toString());
    };
    _peerConnection.onSignalingState = (state){
      print("ICE SIGNALING STATE");
      _msg.value = _msg.value+"  || "+"SIGNALING STATE $state";
      print(state.toString());
    };
    _peerConnection.onIceConnectionState = (state){
      print("ICE CONNECTION STATE");
      _msg.value = _msg.value+"  || "+"ICE STATE $state";
      print(state.toString());
    };
  }

  joinRoom() async{
    await joinRoomById(widget.doc);
  }

  joinRoomById(String id) async{
    DocumentSnapshot doc = await Firestore.instance.document("Rooms/$id").get();
    if(doc.exists){
      _peerConnection = await createPeerConnection(_iceServers, _constraints);
      _msg.value = _msg.value+"  || "+"PEER SETUP";
      registerPeerListeners();
      await _peerConnection.addStream(_localStream);
      _peerConnection.onAddStream = (stream){
        _msg.value = _msg.value+"  || "+"NEW STREAM ADDED";
        this._remoteStream = stream;
        _remoteRenderer.srcObject = _remoteStream;
      };
      _msg.value = _msg.value+"  || "+"STREAM ADDED TO PEER";
    }else{
      await Firestore.instance.document("Rooms/$id").setData({
        "members.${HomePage.userID}":true
      });
      _msg.value = _msg.value+"  || "+"NEW ROOM CREATED";
//      createRoom();
    }
  }

  getUserMedia() async{
    _localStream = await navigator.getUserMedia({'audio': false,
        'video': {
        'mandatory': {
        'minWidth':
        '640', // Provide your own width, height and frame rate here
        'minHeight': '480',
        'minFrameRate': '30',
        },
        'facingMode': 'user',
        'optional': [],
        }});
    _localRenderer.srcObject = _localStream;
    _msg.value = _msg.value+"  || "+"LOCAL VIDEO INT";
//    _remoteStream = new MediaStream("testClient", "OWN");
//    _remoteRenderer.srcObject = _remoteStream;
  }

  handUp() async{
  _remoteStream.dispose();
  _localStream.dispose();
  _localRenderer.dispose();
  _remoteRenderer.dispose();
  _peerConnection.dispose();
  }

}