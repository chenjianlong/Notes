//
//  ViewController.swift
//  Notes-iOS
//
//  Created by chenjianlong on 2017/9/6.
//  Copyright © 2017年 MyCompany. All rights reserved.
//

import UIKit
import CoreSpotlight

class DocumentListViewController: UICollectionViewController {
    var availableFiles: [URL] = []
    
    class var iCloudAvaiable: Bool {
        if UserDefaults.standard.bool(forKey: NotesUseiCloudKey) == false {
            return false;
        }
        
        return FileManager.default.ubiquityIdentityToken != nil
    }
    
    var queryDidFinishGatheringObserver : AnyObject?
    var queryDidUpdateObserver : AnyObject?
    
    var metadataQuery : NSMetadataQuery = {
        let metadataQuery = NSMetadataQuery()
        
        metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        metadataQuery.predicate = NSPredicate(format: "%K LIKE '*.note'")
        metadataQuery.sortDescriptors = [
            NSSortDescriptor(key: NSMetadataItemFSContentChangeDateKey, ascending: false)
        ]
        
        return metadataQuery
    }()
    
    class var localDocumentsDirectoryURL : NSURL {
        return FileManager.default.urls(for: .documentDirectory,
                                        in: .userDomainMask).first! as NSURL
    }
    
    class var ubiquitousDocumentsDirectoryURL : NSURL? {
        return FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") as NSURL?
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(DocumentListViewController.createDocument))
        self.navigationItem.rightBarButtonItem = addButton
        
        self.queryDidUpdateObserver = NotificationCenter.default
            .addObserver(forName: NSNotification.Name.NSMetadataQueryDidUpdate, object: metadataQuery,
                                queue: OperationQueue.main) {
                                    (notification) in
                                    self.queryUpdated()
        }
        
        self.queryDidFinishGatheringObserver = NotificationCenter.default
        .addObserver(forName: NSNotification.Name.NSMetadataQueryDidFinishGathering,
                            object: metadataQuery,
                            queue: OperationQueue.main) {
                                (notification) in
                                self.queryUpdated()
        }
        
        self.navigationItem.leftBarButtonItem = self.editButtonItem
        
        let hasPromptedForiCloud = UserDefaults.standard.bool(forKey: NotesHasPromptedForiCloudKey)
        if hasPromptedForiCloud == false {
            let alert = UIAlertController(title: "Use iCloud?",
                                          message: "Do you want to store your document in iCloud, " +
                "or store them locally?", preferredStyle: UIAlertControllerStyle.alert)
            
            alert.addAction(UIAlertAction(title: "iCloud",
                                          style: .default,
                                          handler: {
                                            (action) in
                                            UserDefaults.standard.set(true, forKey: NotesUseiCloudKey)
                                            self.metadataQuery.start()
            }))
            
            alert.addAction(UIAlertAction(title: "Local Only",
                                          style: .default,
                                          handler: {
                                            (action) in
                                            UserDefaults.standard.set(false, forKey: NotesUseiCloudKey)
                                            self.refreshLocalFileList()
            }))
            self.present(alert, animated: true, completion: nil)
            
            UserDefaults.standard.set(true, forKey: NotesHasPromptedForiCloudKey)
        } else {
            metadataQuery.start()
            refreshLocalFileList()
        }
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        for visibleCell in self.collectionView?.visibleCells as! [FileCollectionViewCell] {
            visibleCell.setEditing(editing: editing, animated: animated)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func refreshLocalFileList() {
        do {
            var localFiles = try FileManager.default.contentsOfDirectory(
                at: DocumentListViewController.localDocumentsDirectoryURL as URL,
            includingPropertiesForKeys: [URLResourceKey.nameKey],
            options: [
                .skipsPackageDescendants,
                .skipsSubdirectoryDescendants
            ])
            
            localFiles = localFiles.filter({
                (url) in
                return url.pathExtension == "note"
            })
            
            if (DocumentListViewController.iCloudAvaiable) {
                for file in localFiles {
                    let documentName = file.lastPathComponent
                    if let ubiquitousDestinationURL =
                        DocumentListViewController.ubiquitousDocumentsDirectoryURL?.appendingPathComponent(documentName) {
                            do {
                                try FileManager.default.setUbiquitous(true,
                                                                      itemAt: file,
                                                                      destinationURL: ubiquitousDestinationURL)
                            } catch let error as NSError {
                                NSLog("Failed to move file \(file) to iCloud: \(error)")
                            }
                    }
                }
            } else {
                availableFiles.append(contentsOf: localFiles)
            }
        } catch let error as NSError {
            NSLog("Failed to list local docuemnts: \(error)")
        }
    }
    
    func queryUpdated() {
        self.collectionView?.reloadData()
        guard let items = self.metadataQuery.results as? [NSMetadataItem]
            else {
                return
        }
        
        guard DocumentListViewController.iCloudAvaiable else {
            return;
        }
        
        availableFiles = []
        refreshLocalFileList()
        for item in items {
            guard let url = item.value(forAttribute: NSMetadataItemURLKey) as! URL? else {
                continue
            }
            
            availableFiles.append(url)
            
            if itemIsOpenable(url: url) == true {
                continue
            }
            
            do {
                try FileManager.default.startDownloadingUbiquitousItem(at: url)
            } catch let error as NSError {
                print("Error downloading item! \(error)")
            }
        }
    }
    
    override func restoreUserActivityState(_ activity: NSUserActivity) {
        if let url = activity.userInfo?[NSUserActivityDocumentURLKey] as? URL {
            self.performSegue(withIdentifier: "ShowDocument", sender: url)
        }
        
        if let searchableItemIdentifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
            let url = URL(string: searchableItemIdentifier) {
            self.performSegue(withIdentifier: "ShowDocument", sender: url)
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.availableFiles.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FileCell", for: indexPath) as! FileCollectionViewCell
        
        let url = availableFiles[indexPath.row]
        
        do {
            var keys = Set<URLResourceKey>()
            keys.insert(URLResourceKey.nameKey)
            let fileName = try url.resourceValues(forKeys: keys)
            if let fileName2 = fileName.name {
                cell.fileNameLabel!.text = fileName2
            }
            
            cell.setEditing(editing: self.isEditing, animated: false)
            cell.deletionHander = {
                self.deleteDocumentAtURL(url: url)
            }
            
            let labelTapRecognizer = UITapGestureRecognizer(target: cell, action: #selector(FileCollectionViewCell.renameTapped))
            cell.fileNameLabel?.gestureRecognizers = [labelTapRecognizer]
            cell.renameHander = {
                self.renameDocumentAtURL(url: url)
            }
        } catch {
            cell.fileNameLabel!.text = "Loading..."
        }
        
        if (itemIsOpenable(url: url)) {
            cell.alpha = 1.0
            cell.isUserInteractionEnabled = true
        } else {
            cell.alpha = 0.5
            cell.isUserInteractionEnabled = false
        }
        
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedItem = availableFiles[indexPath.row]
        if itemIsOpenable(url: selectedItem) {
            self.performSegue(withIdentifier: "ShowDocument", sender: selectedItem)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowDocument", let documentVC = segue.destination as? DocumentViewController {
            if let url = sender as? URL {
                documentVC.documentURL = url
            } else {
                fatalError("ShowDocument segue was called with an invalid sender of type \(type(of: sender))")
            }
        }
    }
    
    func deleteDocumentAtURL(url: URL) {
        let fileCoordinator = NSFileCoordinator(filePresenter: nil)
        fileCoordinator.coordinate(writingItemAt: url, options: .forDeleting, error: nil, byAccessor: {
            (urlForModifying) -> Void in
            do {
                try FileManager.default.removeItem(at: urlForModifying)
                
                self.availableFiles = self.availableFiles.filter {
                    $0 != url
                }
                
                self.collectionView?.reloadData()
            } catch let error as NSError {
                let alert = UIAlertController(title: "Error deleting", message: error.localizedDescription, preferredStyle: UIAlertControllerStyle.alert)
                alert.addAction(UIAlertAction(title: "Done", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        })
    }
    
    func renameDocumentAtURL(url: URL) {
        let renameBox = UIAlertController(title: "Rename Document", message: nil, preferredStyle: .alert)
        renameBox.addTextField(configurationHandler: {
            (textField) -> Void in
            let filename = url.lastPathComponent.replacingOccurrences(of: ".note", with: "")
            textField.text = filename
        })
        
        renameBox.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        renameBox.addAction(UIAlertAction(title: "Rename", style: .default) { (action) in
            if let newName = renameBox.textFields?.first?.text {
                let destinationURL = url.deletingLastPathComponent().appendingPathComponent(newName + ".note")
                let fileCoordinator = NSFileCoordinator(filePresenter: nil)
                fileCoordinator.coordinate(writingItemAt: url, options: [], writingItemAt: destinationURL, options: [], error: nil, byAccessor: { (origin, destination) -> Void in
                    do {
                        try FileManager.default.moveItem(at: origin, to: destination)
                        self.availableFiles = self.availableFiles.filter {
                            $0 != url
                        }
                        
                        self.availableFiles.append(destination)
                        self.collectionView?.reloadData()
                    } catch let error as NSError {
                        NSLog("Failed to move \(origin) to \(destination): \(error)")
                    }
                })
            }
        })
        
        self.present(renameBox, animated: true, completion: nil)
    }
    
    func openDocumentWithPath(path: String) {
        let url = URL(fileURLWithPath: path)
        self.performSegue(withIdentifier: "ShowDocument", sender: url)
    }
    
    func createDocument() {
        let documentName = "Document \(arc4random()).note"
        
        let documentDestinationURL = DocumentListViewController.localDocumentsDirectoryURL.appendingPathComponent(documentName)
        let newDocument = Document(fileURL: documentDestinationURL!)
        newDocument.save(to: documentDestinationURL!, for: .forCreating) {
            (success) -> Void in
            if (DocumentListViewController.iCloudAvaiable) {
                if success == true, let ubiquitousDestinationURL = DocumentListViewController.ubiquitousDocumentsDirectoryURL?.appendingPathComponent(documentName) {
                    OperationQueue().addOperation {
                        () -> Void in
                        do {
                            try FileManager.default.setUbiquitous(true, itemAt: documentDestinationURL!, destinationURL: ubiquitousDestinationURL)
                            
                            OperationQueue.main.addOperation { () -> Void in
                                self.availableFiles.append(ubiquitousDestinationURL)
                                
                                let path = ubiquitousDestinationURL.path
                                self.openDocumentWithPath(path: path)
                                
                                self.collectionView?.reloadData()
                            }
                        }catch let error as NSError {
                            NSLog("Error storing document in iCloud! \(error.localizedDescription)")
                        }
                    }
                }
            } else {
                self.availableFiles.append(documentDestinationURL!)
                self.collectionView?.reloadData()
                
                if let path = documentDestinationURL?.path {
                    self.openDocumentWithPath(path: path)
                }
            }
        }
    }
    
    func itemIsOpenable(url: URL?) -> Bool {
        guard let itemURL = url else {
            return false
        }
        
        if DocumentListViewController.iCloudAvaiable == false {
            return true
        }
        
        var downloadStatus: URLResourceValues?
        do {
            var keys = Set<URLResourceKey>()
            keys.insert(URLResourceKey.ubiquitousItemDownloadingStatusKey)
            downloadStatus = try itemURL.resourceValues(forKeys: keys)
        } catch let error as NSError {
            NSLog("Failed to get downloading status for \(itemURL):\(error)")
            return false
        }
        
        guard let status = downloadStatus else {
            return false
        }
        
        if status.ubiquitousItemDownloadingStatus == URLUbiquitousItemDownloadingStatus.current {
            return true
        } else {
            return false
        }
    }
}

class FileCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var fileNameLabel: UILabel?
    @IBOutlet weak var imageView: UIImageView?
    @IBOutlet weak var deleteButton: UIButton!
    @IBAction func deleteTapped(_ sender: UIButton) {
        deletionHander?()
    }
    
    var renameHander : (() -> Void)?
    var deletionHander : (() -> Void)?
    
    @IBAction func renameTapped() {
        renameHander?()
    }
    
    func setEditing(editing: Bool, animated: Bool) {
        let alpha : CGFloat = editing ? 1.0 : 0.0
        if animated {
            UIView.animate(withDuration: 0.25, animations: { () -> Void in
                self.deleteButton?.alpha = alpha
            })
        } else {
            self.deleteButton?.alpha = alpha
        }
    }
}
