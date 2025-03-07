import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:payu_web_checkout/payu_web_checkout.dart';

// ignore: must_be_immutable
class PayuWebCheckoutWidget extends StatefulWidget {
  PayuWebCheckoutModel payuWebCheckoutModel;
  Function(Map<String, dynamic>) onSuccess;
  Function(Map<String, dynamic>) onFailed;

  PayuWebCheckoutWidget(
      {Key? key,
      required this.payuWebCheckoutModel,
      required this.onSuccess,
      required this.onFailed})
      : super(key: key);

  @override
  _PayuWebCheckoutWidgetState createState() => _PayuWebCheckoutWidgetState();
}

class _PayuWebCheckoutWidgetState extends State<PayuWebCheckoutWidget> {
  bool isLoading = true;
  final GlobalKey webViewKey = GlobalKey();

  InAppWebViewController? webViewController;

  InAppWebViewGroupOptions options = InAppWebViewGroupOptions(
      crossPlatform: InAppWebViewOptions(
          useShouldOverrideUrlLoading: true,
          mediaPlaybackRequiresUserGesture: false),
      android: AndroidInAppWebViewOptions(
        useHybridComposition: true,
      ),
      ios: IOSInAppWebViewOptions(
        allowsInlineMediaPlayback: true,
      ));

  double progress = 0;

  @override
  void initState() {
    _loadHtmlFromUrl();
    super.initState();
  }

  String webViewClientPost() {
    var buffer = StringBuffer();
    buffer.write("<html><head></head>");
    buffer.write("<body onload='form1.submit()'>");
    buffer.write(
        "<form id='form1' action='${widget.payuWebCheckoutModel.baseUrl}/_payment' method='POST'>");

    widget.payuWebCheckoutModel.webParameter().forEach((key, value) {
      buffer.write("<input name='$key' type='hidden' value='$value' />");
    });
    buffer.write("</form></body></html>");
    return buffer.toString();
  }

  @override
  void dispose() {
    super.dispose();
  }

  showPaymentCancelDialog(BuildContext context) {
    // set up the button
    Widget yesButton = TextButton(
      child: const Text("YES"),
      onPressed: () {
        Navigator.pop(context);
        Navigator.pop(context);
        widget.onFailed({
          "status": "failure",
          "error_message": "User canceled the payment"
        });
      },
    );

    Widget noButton = TextButton(
      child: const Text("NO"),
      onPressed: () {
        Navigator.pop(context);
      },
    );

    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: Row(
        children: const [
          Text("Exiting payment"),
        ],
      ),
      content: const Text("Are you sure you want to exit payment?"),
      actions: [noButton, yesButton],
    );

    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        showPaymentCancelDialog(context);
        return Future.value(false);
      },
      child: Scaffold(
        // appBar: AppBar(
        //   centerTitle: false,
        //   titleSpacing: 0.0,
        //   title: Text("Order #${widget.payuWebCheckoutModel.txnId}",
        //       style:
        //           const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        //   actions: [
        //     Center(
        //       child: Text(
        //         "₹ ${widget.payuWebCheckoutModel.amount}",
        //         style:
        //             const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        //       ),
        //     ),
        //     const SizedBox(
        //       width: 10,
        //     ),
        //   ],
        // ),
        body: Stack(
          children: [
            InAppWebView(
              key: webViewKey,
              // contextMenu: contextMenu,
              // initialUrlRequest:
              //     URLRequest(url: ),
              // initialFile: "assets/index.html",
              initialUserScripts: UnmodifiableListView<UserScript>([]),
              initialOptions: options,
              onWebViewCreated: (controller) {
                webViewController = controller;
                _loadHtmlFromUrl();
              },
              onLoadStart: (controller, url) {
                // setState(() {
                //   this.url = url.toString();
                //   urlController.text = this.url;
                // });
              },
              androidOnPermissionRequest:
                  (controller, origin, resources) async {
                return PermissionRequestResponse(
                    resources: resources,
                    action: PermissionRequestResponseAction.GRANT);
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                return NavigationActionPolicy.ALLOW;
              },
              onLoadStop: (controller, url) async {
                print(url.toString());
                if (url.toString() == widget.payuWebCheckoutModel.successUrl) {
                  Map<String, dynamic> parameter = {};
                  dynamic pTagLagth = await webViewController?.evaluateJavascript(
                      source:
                          'window.document.getElementsByTagName("p").length;');
                  int tmpLagth = 0;
                  if (pTagLagth is double) {
                    tmpLagth = pTagLagth.toInt();
                  } else if (pTagLagth is int) {
                    tmpLagth = pTagLagth;
                  } else {
                    return;
                  }

                  for (int i = 0; i < tmpLagth; i++) {
                    String keyValue = await webViewController?.evaluateJavascript(
                        source:
                            'window.document.getElementsByTagName("p")[$i].innerHTML;');

                    parameter[keyValue.replaceAll("\"", "").split(":")[0]] =
                        keyValue.replaceAll("\"", "").split(":")[1];
                  }
                  widget.onSuccess(parameter);
                  Navigator.pop(context);
                } else if (url.toString() ==
                    widget.payuWebCheckoutModel.failedUrl) {
                  Map<String, dynamic> parameter = {};

                  dynamic pTagLagth = await webViewController?.evaluateJavascript(
                      source:
                          'window.document.getElementsByTagName("p").length;');

                  int tmpLagth = 0;
                  if (pTagLagth is double) {
                    tmpLagth = pTagLagth.toInt();
                  } else if (pTagLagth is int) {
                    tmpLagth = pTagLagth;
                  } else {
                    return;
                  }

                  for (int i = 0; i < tmpLagth; i++) {
                    String keyValue = await webViewController?.evaluateJavascript(
                        source:
                            'window.document.getElementsByTagName("p")[$i].innerHTML;');

                    parameter[keyValue.replaceAll("\"", "").split(":")[0]] =
                        keyValue.replaceAll("\"", "").split(":")[1];
                  }
                  widget.onFailed(parameter);
                  Navigator.pop(context);
                }
              },
              onLoadError: (controller, url, code, message) {},
              onProgressChanged: (controller, progress) {
                setState(() {
                  this.progress = progress / 100;
                });
              },
              onUpdateVisitedHistory: (controller, url, androidIsReload) {},
              onConsoleMessage: (controller, consoleMessage) {},
              onReceivedServerTrustAuthRequest: (controller, challenge) async {
                return ServerTrustAuthResponse(
                    action: ServerTrustAuthResponseAction.PROCEED);
              },
            ),
            progress < 1.0
                ? LinearProgressIndicator(value: progress)
                : Container(),
            // WebView(
            //   key: _key,
            //   initialUrl: "about:blank",
            //   onWebViewCreated: (WebViewController webViewController) {
            //     _controller = webViewController;
            //     _loadHtmlFromUrl();
            //   },
            //   javascriptMode: JavascriptMode.unrestricted,
            //   onPageFinished: (value) async {
            //     await Future.delayed(const Duration(seconds: 2), () {
            //       setState(() {
            //         isLoading = false;
            //       });
            //     });
            //     if (value == widget.payuWebCheckoutModel.successUrl) {
            //       Map<String, dynamic> parameter = {};
            //       String pTagLagth =
            //           await _controller.runJavascriptReturningResult(
            //               'window.document.getElementsByTagName("p").length;');
            //       for (int i = 0; i < int.parse(pTagLagth); i++) {
            //         String keyValue =
            //             await _controller.runJavascriptReturningResult(
            //                 'window.document.getElementsByTagName("p")[$i].innerHTML;');

            //         parameter[keyValue.replaceAll("\"", "").split(":")[0]] =
            //             keyValue.replaceAll("\"", "").split(":")[1];
            //       }
            //       widget.onSuccess(parameter);
            //       Navigator.pop(context);
            //     } else if (value == widget.payuWebCheckoutModel.failedUrl) {
            //       Map<String, dynamic> parameter = {};

            //       String pTagLagth =
            //           await _controller.runJavascriptReturningResult(
            //               'window.document.getElementsByTagName("p").length;');

            //       for (int i = 0; i < int.parse(pTagLagth); i++) {
            //         String keyValue =
            //             await _controller.runJavascriptReturningResult(
            //                 'window.document.getElementsByTagName("p")[$i].innerHTML;');

            //         parameter[keyValue.replaceAll("\"", "").split(":")[0]] =
            //             keyValue.replaceAll("\"", "").split(":")[1];
            //       }
            //       widget.onFailed(parameter);
            //       Navigator.pop(context);
            //     }
            //   },
            // ),
            // isLoading
            //     ? const Center(
            //         child: CircularProgressIndicator(),
            //       )
            //     : Stack(),
          ],
        ),
      ),
    );
  }

  _loadHtmlFromUrl() async {
    webViewController?.loadData(data: webViewClientPost());
    // webViewController?.loadUrl(Uri.dataFromString(webViewClientPost(),
    //         mimeType: 'text/html', encoding: Encoding.getByName('utf-8'))
    //     .toString());
  }
}
