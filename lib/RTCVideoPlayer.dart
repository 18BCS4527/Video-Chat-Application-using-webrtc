import 'dart:html' as html;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
class RTCVideoPlayer{
  html.VideoElement _videoElement = html.VideoElement();
  html.MediaStream mediaStream = html.MediaStream();
  RTCVideoPlayer();


  Future<void> init() async{
    await ui.platformViewRegistry.registerViewFactory(mediaStream.id, (id) {
      _videoElement.setAttribute("autoplay", "true");
      _videoElement.setAttribute("playsinline", "true");
      return _videoElement;
    });
  }

  setStream(html.MediaStream stream){
    this._videoElement.srcObject = null;
    this.mediaStream = stream;
    this._videoElement.srcObject = mediaStream;
  }

//  addStream(html.MediaStream stream) async{
//    this._videoElement.srcObject = null;
//    this.mediaStream = html.MediaStream();
//    for(html.MediaStreamTrack track in stream.getTracks()){
//      this.mediaStream.addTrack(track);
//    }
//     _videoElement.srcObject = mediaStream;
//  }

  refreshStream(){
    this._videoElement.srcObject = mediaStream;
  }

  setMute(bool mute){
    this._videoElement.muted = mute;
  }

  dispose() {
    try{
      _videoElement?.srcObject = null;
    for(html.MediaStreamTrack track in mediaStream?.getTracks()){
      track?.stop();
    }
      _videoElement?.remove();
    }catch(err){
      print(err);
    }
  }

  HtmlElementView getView(){
    return HtmlElementView(viewType: mediaStream.id);
  }



}