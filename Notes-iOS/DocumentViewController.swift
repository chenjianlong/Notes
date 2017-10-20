//
//  DocumentViewController.swift
//  Notes-iOS
//
//  Created by chenjianlong on 2017/10/1.
//  Copyright © 2017年 MyCompany. All rights reserved.
//

import UIKit
import AVFoundation
import MobileCoreServices
import CoreSpotlight
import AVKit
import Contacts
import ContactsUI

protocol AttachmentViewer: NSObjectProtocol {
    var attachmentFile : FileWrapper? { get set }
    var document : Document? { get set }
}


protocol AttachmentCellDelegate {
    func attachmentCellWasDeleted(cell: AttachmentCell)
}

class AttachmentCell : UICollectionViewCell {
    @IBOutlet weak var imageView : UIImageView?
    @IBOutlet weak var extensionLabel : UILabel?
    
    @IBOutlet weak var deleteButton : UIButton?
    
    var editMode = false {
        didSet {
            // transparency while not on edit mode
            deleteButton?.alpha = editMode ? 1 : 0
        }
    }
    
    var delegate : AttachmentCellDelegate?
    @IBAction func delete() {
        self.delegate?.attachmentCellWasDeleted(cell: self)
    }
}

class DocumentViewController: UIViewController, UITextViewDelegate {
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var attachmentsCollectionView : UICollectionView!
    
    let speechSynthesizer = AVSpeechSynthesizer()
    var isEditingAttachments = false
    var shouldCloseOnDisappear = true
    var stateChangedObserver : AnyObject?
    var document : Document?
    var documentURL : URL? {
        didSet {
            if let url = documentURL {
                self.document = Document(fileURL: url)
            }
        }
    }
    
    func documentStateChanged() {
        if let document = self.document, document.documentState.contains(UIDocumentState.inConflict) {
            guard var conflictedVersions = NSFileVersion.unresolvedConflictVersionsOfItem(at: document.fileURL) else {
                fatalError("The document is in conflict, but no conflicting version were found. This should not happen.")
            }
            
            let currentVersion = NSFileVersion.currentVersionOfItem(at: document.fileURL)!
            conflictedVersions += [currentVersion]
            
            let title = "Resolve conflicts"
            let message = "Choose a version of this document to keep."
            let picker = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.actionSheet)
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            
            let cancelAndClose = { (action: UIAlertAction) -> Void in
                self.navigationController?.popViewController(animated: true)
            }
            
            for version in conflictedVersions {
                let description = "Edited on \(version.localizedNameOfSavingComputer!) at " +
                "\(dateFormatter.string(from: version.modificationDate!))"
                
                let action = UIAlertAction(title: description, style: UIAlertActionStyle.default, handler: {
                    (action) -> Void in
                    
                    do {
                        if version != currentVersion {
                            try version.replaceItem(at: document.fileURL, options: NSFileVersion.ReplacingOptions.byMoving)
                            try NSFileVersion.removeOtherVersionsOfItem(at: document.fileURL)
                        }
                        
                        document.revert(toContentsOf: document.fileURL, completionHandler: { (success) -> Void in
                            self.textView.attributedText = document.text
                            self.attachmentsCollectionView?.reloadData()
                        })
                        
                        for version in conflictedVersions {
                            version.isResolved = true
                        }
                    } catch let error as NSError {
                        let errorView = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: UIAlertControllerStyle.alert)
                        
                        errorView.addAction(UIAlertAction(title: "Done", style: UIAlertActionStyle.cancel, handler: cancelAndClose))
                        
                        self.shouldCloseOnDisappear = false
                        self.present(errorView, animated: true, completion: nil)
                    }
                })
                
                picker.addAction(action)
            }
            
            picker.addAction(UIAlertAction(title: "Choose Later", style: UIAlertActionStyle.cancel, handler: cancelAndClose))
            self.shouldCloseOnDisappear = false
            self.present(picker, animated: true, completion: nil)
        } else {
            self.attachmentsCollectionView?.reloadData()
        }
    }
    
    func addAttachment(sourceView: UIView) {
        let actionSheet = UIAlertController(title: "Add attachment", message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
        
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.camera) {
            var handler : (_ action: UIAlertAction) -> Void
            switch AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) {
            case .authorized:
                fallthrough
            case .notDetermined:
                handler = { (action) in
                    self.addPhoto()
                }
            default:
                handler = { (action) in
                    let title = "Camera access required"
                    let message = "Go to Settings to grant permission to access the camera."
                    let cancelButton = "Cancel"
                    let settingsButton = "Settings"
                    
                    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                    
                    alert.addAction(UIAlertAction(title: cancelButton, style: .cancel, handler: nil))
                    alert.addAction(UIAlertAction(title: settingsButton, style: .default, handler: { (action) in
                        if let settingsURL = URL(string: UIApplicationOpenSettingsURLString) {
                            UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
                        }
                    }))
                    
                    self.present(alert, animated: true, completion: nil)
                }
            }
            
            actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: handler))
        }
        
        actionSheet.addAction(UIAlertAction(title: "Location", style: .default, handler: {
            (action) -> Void in
            self.addLocation()
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Audio", style: .default, handler: {
            (action) -> Void in
            self.addAudio()
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Contact", style: .default, handler: {
            (action) -> Void in
            self.addContact()
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        if UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad {
            actionSheet.modalPresentationStyle = .popover
            actionSheet.popoverPresentationController?.sourceView = sourceView
            actionSheet.popoverPresentationController?.sourceRect = sourceView.bounds
        }
        
        self.present(actionSheet, animated: true, completion: nil)
    }
    
    func addPhoto() {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = UIImagePickerController.availableMediaTypes(for: UIImagePickerControllerSourceType.camera)!
        picker.delegate = self
        self.shouldCloseOnDisappear = false
        self.present(picker, animated: true, completion: nil)
    }
    
    func addLocation() {
        self.performSegue(withIdentifier: "ShowLocationAttachment", sender: nil)
    }
    
    func addAudio() {
        self.performSegue(withIdentifier: "ShowAudioAttachment", sender: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let menuController = UIMenuController.shared
        let speakItem = UIMenuItem(title: "Speak", action: #selector(speakSelection))
        menuController.menuItems = [speakItem]
    }
    
    func speakSelection(sender: AnyObject) {
        if let range = self.textView?.selectedTextRange, let selectedText = self.textView?.text(in: range) {
            let utterance = AVSpeechUtterance(string: selectedText)
            speechSynthesizer.speak(utterance)
        }
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
                    self.attachmentsCollectionView?.reloadData()
                    
                    document.userActivity?.title = document.localizedName
                    let contentAttributeSet = CSSearchableItemAttributeSet(itemContentType: document.fileType!)
                    contentAttributeSet.title = document.localizedName
                    contentAttributeSet.contentDescription = document.text.string
                    document.userActivity?.contentAttributeSet = contentAttributeSet
                    document.userActivity?.isEligibleForSearch = true
                    
                    document.userActivity?.becomeCurrent()
                    
                    // register state changer notify
                    self.stateChangedObserver = NotificationCenter.default.addObserver(
                        forName: NSNotification.Name.UIDocumentStateChanged,
                        object: document,
                        queue: nil, using: { (notification) -> Void in
                            self.documentStateChanged()
                    })
                    
                    self.documentStateChanged()
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
        
        self.shouldCloseOnDisappear = true
        self.attachmentsCollectionView?.reloadData()
    }
    
    func textViewDidChange(_ textView: UITextView) {
        document?.text = textView.attributedText
        document?.updateChangeCount(.done)
    }
    
    func beginEditMode() {
        self.isEditingAttachments = true
        UIView.animate(withDuration: 0.1, animations: {
            () -> Void in
            for cell in self.attachmentsCollectionView!.visibleCells {
                if let attachmentCell = cell as? AttachmentCell {
                    attachmentCell.editMode = true
                } else {
                    cell.alpha = 0
                }
            }
        })
        
        let doneButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.done, target: self, action: #selector(DocumentViewController.endEditMode))
        self.navigationItem.rightBarButtonItem = doneButton
    }
    
    func endEditMode() {
        self.isEditingAttachments = false
        UIView.animate(withDuration: 0.1, animations: {
            () -> Void in
            for cell in self.attachmentsCollectionView!.visibleCells {
                if let attachmentCell = cell as? AttachmentCell {
                    attachmentCell.editMode = false
                } else {
                    cell.alpha = 1
                }
            }
        })
        
        self.navigationItem.rightBarButtonItem = nil
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        if shouldCloseOnDisappear == false {
            return
        }
        
        self.stateChangedObserver = nil
        self.document?.close(completionHandler: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let attachmentViewer = segue.destination as? AttachmentViewer {
            attachmentViewer.document = self.document!
            
            if let cell = sender as? UICollectionViewCell,
                let indexPath = self.attachmentsCollectionView?.indexPath(for: cell),
                let attachment = self.document?.attachFiles?[indexPath.row] {
                attachmentViewer.attachmentFile = attachment
            } else {
                // no attachment
            }
            
            // don't close the document while show the attachment
            self.shouldCloseOnDisappear = false
            
            if let popover = segue.destination.popoverPresentationController {
                popover.delegate = self
                popover.sourceView = self.attachmentsCollectionView
                popover.sourceRect = self.attachmentsCollectionView.bounds
            }
        }
    }
}

extension DocumentViewController : UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if self.document!.documentState.contains(.closed) {
            return 0
        }
        
        guard let attachments = self.document?.attachFiles else {
            return 0
        }
        
        return attachments.count + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let totalNumberOfCells = collectionView.numberOfItems(inSection: indexPath.section)
        let isAddCell = (indexPath.row == (totalNumberOfCells - 1))
        let cell : UICollectionViewCell
        
        if isAddCell {
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AddAttachmentCell", for: indexPath)
        } else {
            let attachmentCell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "AttachmentCell", for: indexPath) as! AttachmentCell
            
            let attachment = self.document?.attachFiles?[indexPath.row]
            var image = attachment?.thumbnailImage()
            
            if image == nil {
                image = UIImage(named: "File")
                
                attachmentCell.extensionLabel?.text = attachment?.fileExtension?.uppercased()
            } else {
                attachmentCell.extensionLabel?.text = nil
            }
            
            attachmentCell.imageView?.image = image
            attachmentCell.editMode = self.isEditingAttachments
            
            let longPressGestur = UILongPressGestureRecognizer(target: self, action: #selector(DocumentViewController.beginEditMode))
            attachmentCell.gestureRecognizers = [longPressGestur]
            attachmentCell.delegate = self
            
            cell = attachmentCell
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if self.isEditingAttachments {
            return
        }
        
        guard let selectedCell = collectionView.cellForItem(at: indexPath) else {
            return
        }
        
        let totalNumberOfCells = collectionView.numberOfItems(inSection: indexPath.section)
        if (indexPath.row == totalNumberOfCells - 1) {
            addAttachment(sourceView: selectedCell)
        } else {
            guard let attachment = self.document?.attachFiles![indexPath.row] else {
                NSLog("No attachment for this cell!")
                return
            }
            
            let segueName : String?
            if attachment.conformsToType(type: kUTTypeImage) {
                segueName = "ShowImageAttachment"
            } else if attachment.conformsToType(type: kUTTypeJSON) {
                segueName = "ShowLocationAttachment"
            } else if attachment.conformsToType(type: kUTTypeAudio) {
                segueName = "ShowAudioAttachment"
            } else if attachment.conformsToType(type: kUTTypeMovie) {
                self.document?.URLForAttachment(attachment: attachment, completion: {
                    (url) -> Void in
                    if let attachmentURL = url {
                        let media = AVPlayerViewController()
                        media.player = AVPlayer(url: attachmentURL)
                        
                        let _ = try? AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
                        self.present(media, animated: true, completion: nil)
                    }
                })
                
                segueName = nil
            } else if attachment.conformsToType(type: kUTTypeContact) {
                do {
                    if let data = attachment.regularFileContents, let contact = try CNContactVCardSerialization.contacts(with: data).first {
                        let contactViewController = CNContactViewController(for: contact)
                        let navigationController = UINavigationController(rootViewController: contactViewController)
                        contactViewController.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissModalView))
                        self.present(navigationController, animated: true, completion: nil)
                    }
                } catch let error as NSError {
                    NSLog("Error displaying contact: \(error)")
                }
                
                segueName = nil
            } else {
                // this attachment has not viewcontroller, show UIDocumentInteractionController
                self.document?.URLForAttachment(attachment: attachment, completion: {
                    (url) -> Void in
                    if let attachmentURL = url {
                        let documentInteraction = UIDocumentInteractionController(url: attachmentURL)
                        documentInteraction.presentOptionsMenu(from: selectedCell.bounds, in: selectedCell, animated: true)
                    }
                })
                
                segueName = nil
            }
            
            if let theSegue = segueName {
                self.performSegue(withIdentifier: theSegue, sender: selectedCell)
            }
        }
    }
}

extension DocumentViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        do {
            if let image = (info[UIImagePickerControllerEditedImage]
               ?? info[UIImagePickerControllerOriginalImage]) as? UIImage,
               let imageData = UIImageJPEGRepresentation(image, 0.8) {
                try self.document?.addAttachmentWithData(data: imageData, name: "Image \(arc4random()).jpg")
                self.dismiss(animated: true, completion: nil)
                self.attachmentsCollectionView?.reloadData()
            } else if let mediaURL = (info[UIImagePickerControllerMediaURL]) as? URL {
                try _ = self.document?.addAttachmentAtURL(url: mediaURL)
                self.dismiss(animated: true, completion: nil)
            } else {
                throw err(code: .CannotSaveAttachment)
            }
        } catch let error as NSError {
            NSLog("Error adding attachment: \(error)")
            self.dismiss(animated: true, completion: nil)
        }
    }
}

extension DocumentViewController: UIPopoverPresentationControllerDelegate {
    func presentationController(_ controller: UIPresentationController, viewControllerForAdaptivePresentationStyle style: UIModalPresentationStyle) -> UIViewController? {
        let presentedViewController = controller.presentedViewController
        if style == UIModalPresentationStyle.fullScreen && controller is UIPopoverPresentationController {
            let navigationController = UINavigationController(rootViewController: controller.presentedViewController)
            
            let closeButton = UIBarButtonItem(title: "Done", style: UIBarButtonItemStyle.done, target: self, action: #selector(DocumentViewController.dismissModalView))
            presentedViewController.navigationItem.rightBarButtonItem = closeButton
            return navigationController
        } else {
            return presentedViewController
        }
    }
    
    func dismissModalView() {
        self.dismiss(animated: true, completion: nil)
    }
}


extension DocumentViewController: AttachmentCellDelegate {
    func attachmentCellWasDeleted(cell: AttachmentCell) {
        guard let indexPath = self.attachmentsCollectionView?.indexPath(for: cell) else {
            return
        }
        
        guard let attachment = self.document?.attachFiles?[indexPath.row] else {
            return
        }
        
        do {
            try self.document?.deleteAttachment(attachment: attachment)
            self.attachmentsCollectionView?.deleteItems(at: [indexPath])
            self.endEditMode()
        } catch let error as NSError {
            NSLog("Failed to delete attachment: \(error)")
        }
    }
}

extension DocumentViewController: CNContactPickerDelegate {
    func addContact() {
        let contactPicker = CNContactPickerViewController()
        contactPicker.delegate = self
        self.shouldCloseOnDisappear = false
        self.present(contactPicker, animated: true, completion: nil)
    }
    
    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        do {
            if let data = try? CNContactVCardSerialization.data(with: [contact]) {
                let name = "\(contact.identifier)-\(contact.givenName)\(contact.familyName).vcf"
                
                try self.document?.addAttachmentWithData(data: data, name: name)
                self.attachmentsCollectionView?.reloadData()
            }
        } catch let error as NSError {
            NSLog("Failed to save contact: \(error)")
        }
    }
}

