//
//  ViewController.swift
//  Notes
//
//  Created by chenjianlong on 2017/8/26.
//  Copyright © 2017年 MyCompany. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    @IBOutlet var textView: NSTextView!
    @IBOutlet weak var attachmentsList: NSCollectionView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    override func viewDidAppear() {
        // Fill the text view with the document's contents.
        let document = self.view.window?.windowController?.document as! Document
        textView.textStorage?.setAttributedString(document.text)
    }

}

