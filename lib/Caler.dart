import 'dart:async';
import 'dart:html' as html;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/enums.dart';
import 'package:flutter_webrtc/web/media_stream.dart';
import 'package:flutter_webrtc/web/rtc_ice_candidate.dart';
import 'package:flutter_webrtc/web/rtc_peerconnection_factory.dart';
import 'package:flutter_webrtc/web/rtc_peerconnection.dart';
import 'package:flutter_webrtc/web/rtc_session_description.dart';
import 'package:flutter_webrtc/web/rtc_video_view.dart';
import 'package:talkto/Callee.dart';
import 'package:talkto/RTCVideoPlayer.dart';

import 'main.dart';

class Caler extends StatefulWidget {
  final String _callerId;
  final String _callId;
  final DocumentSnapshot doc;

  Caler(this._callerId, this._callId, this.doc);

  @override
  _CalerState createState() => _CalerState();
}

class _CalerState extends State<Caler> with WidgetsBindingObserver {
  StreamSubscription _fSubs;
  RTCPeerConnection _peerConnection;


  DocumentReference callRef;
  bool gotCandid = false;
  RTCVideoRenderer remteRender = RTCVideoRenderer();
  MediaStream remte;

  RTCVideoPlayer localPlayer = RTCVideoPlayer();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    callRef = Firestore.instance.document("Calls/${widget._callId}");
    initAll();
  }

  Map<String, dynamic> config = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': HomePage.agree},
    ],
  };

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async{
    if (state == AppLifecycleState.inactive) {
        localPlayer.dispose();
        await remteRender?.dispose();
        await remte?.dispose();
      if(!disposing){
        _disposePeer(_peerConnection, callRef);
      }
    }
    super.didChangeAppLifecycleState(state);
  }

  String streamId = "";
  List<Map> cdds = [];

  initAll() async {
    this.localPlayer.setStream(await html.window.navigator.mediaDevices
        .getUserMedia({'video': true, 'audio': true}));
    await localPlayer.init();
    localPlayer.setMute(true);
    setState(() {
      streamId = localPlayer.mediaStream.id;
    });
    _peerConnection = await createPeerConnection(servers, config);
    _peerConnection.onIceCandidate = (candid) async {
      cdds.add(candid.toMap());
      await _peerConnection.addCandidate(candid);
    };
    _peerConnection.onIceConnectionState = (state) async {
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
        this.localPlayer.refreshStream();
      }
    };
    _peerConnection.onAddStream = (stream) async {
    this.remte = stream;
    remteRender.srcObject = remte;
    };
    _peerConnection.onRemoveStream = (stream) {
      remte.dispose();
    };
    RTCSessionDescription description = RTCSessionDescription(
        widget.doc['offer']['sdp'], widget.doc['offer']['type']);
    await _peerConnection.setRemoteDescription(description);
    await _peerConnection.addStream(MediaStream(localPlayer.mediaStream));
    final answer = await _peerConnection.createAnswer(constraints);
    await _peerConnection.setLocalDescription(answer);
    await callRef.setData(
        {"answer": (await _peerConnection.getLocalDescription()).toMap()},
        merge: true);
    await callRef.setData({"callee_candidate": cdds}, merge: true);
    _fSubs = callRef.snapshots().listen((event) async {
      if(event.exists){
        if (!(event['active'] ?? true)) {
          _fSubs?.cancel();
          Navigator.popUntil(context, (route) => route.isFirst);
          return;
        }
        if (event['caller_candidate'] != null) {
          List cds = List.of(event['caller_candidate'] ?? []);
          for (Map cd in cds) {
            RTCIceCandidate candid = RTCIceCandidate(
                cd['candidate'], cd['sdpMid'], cd['spdMineIndex']);
            await _peerConnection.addCandidate(candid);
          }
        }
      }
      else{
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    });
  }

  @override
  void dispose() {
    localPlayer.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _fSubs?.cancel();
    super.dispose();
  }

  static _disposePeer(
      RTCPeerConnection peer,
      DocumentReference ref) async {
    await ref.setData({"active": false}, merge: true);
    await peer?.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          RTCVideoView(remteRender),
          Positioned(
            right: 10,
            bottom: 10,
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.2,
              child: AspectRatio(
                aspectRatio: MediaQuery.of(context).size.aspectRatio,
                child: (streamId??"").isEmpty?Center(child: CircularProgressIndicator(),):localPlayer.getView()//RTCVideoView(_localRender),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          disposing = true;
          await _disposePeer(_peerConnection, callRef);
//          Navigator.pop(context);
        },
        elevation: 1,
        child: Icon(
          Icons.call_end,
          color: Colors.white,
        ),
        backgroundColor: Colors.red,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: BottomAppBar(
        child: Card(
          margin: EdgeInsets.all(0),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text("CALLEE: $streamId"),
          ),
        ),
      ),
    );
  }

  bool disposing = false;

}
