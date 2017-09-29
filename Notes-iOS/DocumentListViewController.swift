//
//  ViewController.swift
//  Notes-iOS
//
//  Created by chenjianlong on 2017/9/6.
//  Copyright © 2017年 MyCompany. All rights reserved.
//

import UIKit

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
    
    var renameHander : ((Void) -> Void)?
    
    @IBAction func renameTapped() {
        renameHander?()
    }
}
