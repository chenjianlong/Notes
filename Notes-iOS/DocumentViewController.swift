//
//  DocumentViewController.swift
//  Notes-iOS
//
//  Created by chenjianlong on 2017/10/1.
//  Copyright © 2017年 MyCompany. All rights reserved.
//

import UIKit

class DocumentViewController: UIViewController, UITextViewDelegate {
    @IBOutlet weak var textView: UITextView!
    
    private var document : Document?
    var documentURL : URL? {
        didSet {
            if let url = documentURL {
                self.document = Document(fileURL: url)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        guard let document = self.document else {
            NSLog("No document to display")
            self.navigationController?.popToRootViewController(animated: true)
            return
        }
        
        if document.documentState.contains(UIDocumentState.closed) {
            document.open(completionHandler: { (success) -> Void in
                if success == true {
                    self.textView?.attributedText = document.text
                } else {
                    let alertTitle = "Error"
                    let alertMessage = "Failed to open document"
                    let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: UIAlertControllerStyle.alert)
                    
                    alert.addAction(UIAlertAction(title: "Close", style: .default, handler: { (action) -> Void in
                        self.navigationController?.popViewController(animated: true)
                    }))
                    
                    self.present(alert, animated: true, completion: nil)
                }
            })
        }
    }
    
    func textViewDidChange(_ textView: UITextView) {
        document?.text = textView.attributedText
        document?.updateChangeCount(.done)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        self.document?.close(completionHandler: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
