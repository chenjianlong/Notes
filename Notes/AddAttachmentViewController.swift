//
//  AddAttachmentViewController.swift
//  Notes
//
//  Created by chenjianlong on 2017/9/5.
//  Copyright © 2017年 MyCompany. All rights reserved.
//

import Cocoa

protocol AddAttachmentDelegate {
    func addFile()
}

class AddAttachmentViewController: NSViewController {
    @IBOutlet weak var addFile: AnyObject!
    var delegate: AddAttachmentDelegate?
    
    @IBAction func addFile(sender: AnyObject) {
        self.delegate?.addFile()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
}
