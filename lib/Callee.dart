import 'dart:async';
import 'dart:ui' as ui;
import 'dart:html' as html;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/enums.dart';
import 'package:flutter_webrtc/web/media_stream.dart';
import 'package:flutter_webrtc/web/rtc_ice_candidate.dart';
import 'package:flutter_webrtc/web/rtc_peerconnection.dart';
import 'package:flutter_webrtc/web/rtc_peerconnection_factory.dart';
import 'package:flutter_webrtc/web/rtc_session_description.dart';
import 'package:flutter_webrtc/web/rtc_video_view.dart';
import 'package:talkto/RTCVideoPlayer.dart';
import 'package:talkto/main.dart';

const servers = {
  'iceServers': [
    {
      'urls': 'turn:numb.viagenie.ca',
      'credential': '123456',
      'username': 'lokesh.verma25n@gmail.com'
    },
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun.l.test.com:19000'},
    {'urls': 'stun:stun.services.mozilla.com'},
    {'url': 'stun:stun1.l.google.com:19302'},
    {'url': 'stun:stun2.l.google.com:19302'},
    {'urls': 'stun:stun.2.google.com:19302'},
    {'url': 'stun:stun3.l.google.com:19302'},
    {'url': 'stun:stun4.l.google.com:19302'},
    {'url': 'stun:stunserver.org'},
    {'url': 'stun:stun.softjoys.com'},
    {'url': 'stun:stun.voiparound.com'},
    {'url': 'stun:stun.voipbuster.com'},
  ]
};

const Map<String, dynamic> constraints = {
  'mandatory': {
    'OfferToReceiveAudio': true,
    'OfferToReceiveVideo': true,
  },
  'optional': [],
};

class Callee extends StatefulWidget {
  final String id;

  Callee(this.id);

  @override
  _CalleeState createState() => _CalleeState();
}

class _CalleeState extends State<Callee> with WidgetsBindingObserver {
  RTCPeerConnection _peerConnection;


  DocumentReference _targetRef;

  RTCVideoPlayer localPlayer = RTCVideoPlayer();

  RTCVideoRenderer remoteRender = RTCVideoRenderer();
  MediaStream mediaStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initialize();
    initFirebase();
  }

  StreamSubscription fSubs;

  bool accepted = false;
  bool gotCandid = false;
  bool ansered = false;

  initFirebase() async {
    _targetRef = Firestore.instance.collection("Calls").document();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async{
    if (state == AppLifecycleState.inactive) {
      localPlayer.dispose();
      await remoteRender.dispose();
      await mediaStream?.dispose();
      if(!disposing){
        _disposePeer(_peerConnection, _targetRef);
      }
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  void dispose() {
    localPlayer.dispose();
    WidgetsBinding.instance.removeObserver(this);
    fSubs?.cancel();
    super.dispose();
  }

  static _disposePeer(
      RTCPeerConnection peer,
      DocumentReference ref) async {
    try {
      await ref.setData({"active": false}, merge: true);
      await peer?.dispose();
    } catch (err) {}
  }

  Map<String, dynamic> config = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': HomePage.agree},
    ],
  };

  List cdds = [];
  String streamId = "";

  initialize() async {
    await localPlayer.setStream(await html.window.navigator.mediaDevices
        .getUserMedia({'video': true, 'audio': true}));
    await localPlayer.init();
    localPlayer.setMute(true);
    streamId = localPlayer.mediaStream.id;
    setState(() {

    });
    _peerConnection = await createPeerConnection(servers, config);
    _peerConnection.onIceCandidate = (candid) async {
      cdds.add(candid.toMap());
    };
    _peerConnection.onIceConnectionState = (state) async {
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
        this.localPlayer.refreshStream();
      }
    };
    _peerConnection.onAddStream = (stream) async {
      mediaStream = stream;
      remoteRender.srcObject = mediaStream;
    };
    _peerConnection.onRemoveStream = (stream) {
      mediaStream.dispose();
    };
    await _peerConnection.addStream(MediaStream(localPlayer.mediaStream));
    final offer = await _peerConnection.createOffer(constraints);
    await _peerConnection.setLocalDescription(offer);
    await _targetRef.setData({
      "target": widget.id,
      "caller": HomePage.userID,
      "active": true,
      "offer": (await _peerConnection.getLocalDescription()).toMap()
    });
    fSubs = _targetRef.snapshots().listen((event) async {
      if (event.exists) {
        if (!(event['active'] ?? true)) {
          fSubs?.cancel();
          Navigator.popUntil(context, (route) => route.isFirst);
          return;
        }
        if (!accepted) {
          if (event['target_accept'] ?? false) {
            accepted = true;
          }
          return;
        }
        if (!ansered) {
          if (event['answer'] != null) {
            ansered = true;
            RTCSessionDescription _answer = RTCSessionDescription(
                event['answer']['sdp'], event['answer']['type']);
            await _peerConnection.setRemoteDescription(_answer);
            await _targetRef.setData({"caller_candidate": cdds}, merge: true);
          }
          return;
        }
        if (event['callee_candidate'] != null) {
          gotCandid = true;
          List cds = List.of(event['callee_candidate'] ?? []);
          for (Map cd in cds) {
            RTCIceCandidate candid = RTCIceCandidate(
                cd['candidate'], cd['sdpMid'], cd['spdMineIndex']);
            await _peerConnection.addCandidate(candid);
          }
        }
      } else {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          RTCVideoView(remoteRender),
          Positioned(
            right: 10,
            bottom: 20,
            child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.2,
                child: AspectRatio(
                    aspectRatio: MediaQuery.of(context).size.aspectRatio,
                    child: (streamId??"").isEmpty?Center(child: CircularProgressIndicator(),):localPlayer.getView(),)
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          disposing = true;
          await _disposePeer(_peerConnection, _targetRef);
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
