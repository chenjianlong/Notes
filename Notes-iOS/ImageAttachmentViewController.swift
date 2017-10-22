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
  @IBOutlet var filterButtons: [UIButton]!
    
    @IBAction func showFilteredImage(_ sender: UIButton) {
        self.imageView?.image = sender.image(for: UIControlState.normal)
        self.imageView?.contentMode = .scaleAspectFit
    }
    
    @IBAction func shareImage(_ sender: UIBarButtonItem) {
        guard let image = self.imageView?.image else {
            return
        }
        
        let activityController = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        
        if UIApplication.shared.keyWindow?.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClass.regular {
            activityController.modalPresentationStyle = .popover
            activityController.popoverPresentationController?.barButtonItem = sender
        }
        
        self.present( activityController, animated: true, completion: nil)
    }
    
    func prepareFilterPreviews() {
        let filters : [CIFilter?] = [
            CIFilter(name: "CIPhotoEffectChrome"),
            CIFilter(name: "CIPhotoEffectNoir"),
            CIFilter(name: "CIPhotoEffectInstant"),
        ]
        
        guard let image = self.imageView?.image else {
            return
        }
        
        for (number, filter) in filters.enumerated() {
            let button = filterButtons[number]
            let unprocessedImage = CIImage(image: image)
            filter?.setValue(unprocessedImage, forKey: kCIInputImageKey)
            if let processedCIImage = filter?.value(forKey: kCIOutputImageKey) as? CIImage {
                button.setImage(UIImage(ciImage: processedCIImage), for: UIControlState.normal)
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if let data = attachmentFile?.regularFileContents, let image = UIImage(data: data) {
            self.imageView?.image = image
            prepareFilterPreviews()
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
