//
//  OneSignalWebView.swift
//  OneSignal
//
//  Created by Joseph Kalash on 7/6/16.
//  Copyright © 2016 Joseph Kalash. All rights reserved.
//

import Foundation
import UIKit

class OneSignalWebView: UIViewController, UIWebViewDelegate {
    
    var url : URL!
    var webView : UIWebView!
    var uiBusy : UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        
        //Add a webview and a back button alongside an activity indicator
        webView = UIWebView(frame: self.view.frame)
        webView.delegate = self
        self.view.addSubview(webView)
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.done, target: self, action: #selector(OneSignalWebView.dismiss(_:)))
        
        uiBusy = UIActivityIndicatorView(activityIndicatorStyle: .white)
        uiBusy.color = UIColor.black()
        uiBusy.hidesWhenStopped = true
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: uiBusy)

    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if self.url != nil {
           webView.loadRequest(URLRequest(url: url))
        }
    }
    
    func dismiss(_ sender: AnyObject) {
        self.navigationController?.dismiss(animated: true, completion: nil)
    }
    
    func webViewDidStartLoad(_ webView: UIWebView) {
        uiBusy.startAnimating()
    }
    
    // MARK : UIWebViewDelegate
    func webViewDidFinishLoad(_ webView: UIWebView) {
        self.title = webView.stringByEvaluatingJavaScript(from: "document.title")
        self.navigationController?.title = self.title
        uiBusy.stopAnimating()
    }
    
    func showInApp() {
        
        if self.navigationController == nil {return}
        
        self.navigationController!.modalTransitionStyle = .coverVertical
        if let topController = UIApplication.topmostController() {
            
            topController.present(self.navigationController!, animated: true, completion: nil)
        }
    }
}
