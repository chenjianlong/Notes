//
//  ImageAttachmentViewController.swift
//  Notes-iOS
//
//  Created by chenjianlong on 2017/10/15.
//  Copyright © 2017年 MyCompany. All rights reserved.
//

import UIKit

class ImageAttachmentViewController: UIViewController, AttachmentViewer {
    @IBOutlet weak var imageView : UIImageView?
    var attachmentFile: FileWrapper?
    var document: Document?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if let data = attachmentFile?.regularFileContents, let image = UIImage(data: data) {
            self.imageView?.image = image
        }
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
