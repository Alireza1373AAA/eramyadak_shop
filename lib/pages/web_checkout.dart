import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebCheckout extends StatefulWidget{ final Uri initialUrl; const WebCheckout({super.key, required this.initialUrl}); @override State<WebCheckout> createState()=>_WebCheckoutState(); }
class _WebCheckoutState extends State<WebCheckout>{ 
  late final WebViewController _c; bool _loading=true; 
  @override void initState(){ 
    super.initState(); 
    _c=WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(onPageFinished: (_){ if(mounted) setState(()=>_loading=false);} ))
      ..loadRequest(widget.initialUrl);
  } 
  @override Widget build(BuildContext context){ 
    return Scaffold(appBar: AppBar(title: const Text('Checkout')), body: Stack(children:[ WebViewWidget(controller:_c), if(_loading) const LinearProgressIndicator()])); 
  }
}