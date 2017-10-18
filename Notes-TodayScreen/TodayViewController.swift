//
//  TodayViewController.swift
//  Notes-TodayScreen
//
//  Created by chenjianlong on 2017/10/17.
//  Copyright © 2017年 MyCompany. All rights reserved.
//

import UIKit
import NotificationCenter

class TodayViewController: UIViewController, NCWidgetProviding, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var tableView: UITableView!
    
    var fileList : [URL] = []
    
    func loadAvailableFiles() -> [URL] {
        let fileManager = FileManager.default
        var allFiles : [URL] = []
        
        //if let localDocumentsFolder = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.myCompany.notes") {
        if let localDocumentsFolder = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            do {
                let localFiles = try fileManager.contentsOfDirectory(atPath: localDocumentsFolder.path).map({
                    localDocumentsFolder.appendingPathComponent($0, isDirectory: false)
                })
                
                allFiles.append(contentsOf: localFiles)
            } catch {
                NSLog("Failed to get list of local files!")
            }
        }
        
        if let documentsFolder = fileManager.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents", isDirectory: true) {
            do {
                let iCloudFiles = try fileManager.contentsOfDirectory(atPath: documentsFolder.path).map({
                    documentsFolder.appendingPathComponent($0, isDirectory: false)
                })
                
                allFiles.append(contentsOf: iCloudFiles)
            } catch {
                NSLog("Failed to get contents of iCloud container")
            }
        }
        
        return allFiles.filter({ $0.lastPathComponent.hasSuffix("note")})
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        fileList = loadAvailableFiles()
        self.preferredContentSize = CGSize(width: 0, height: 1)
        if let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
            NSLog("Extension's container: \(containerURL)")
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func widgetPerformUpdate(completionHandler: (@escaping (NCUpdateResult) -> Void)) {
        // Perform any setup necessary in order to update the view.
        
        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData
        
        let newFileList = loadAvailableFiles()
        self.preferredContentSize = self.tableView.contentSize
        if newFileList == fileList {
            completionHandler(.noData)
        } else {
            fileList = newFileList
            completionHandler(NCUpdateResult.newData)
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let url = fileList[indexPath.row]
        
        var keys = Set<URLResourceKey>()
        keys.insert(URLResourceKey.nameKey)
        let name = try? url.resourceValues(forKeys: keys).name ?? "Note"
        cell.textLabel?.text = name
        return cell
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fileList.count
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let url = fileList[indexPath.row]
        let appURLComponents = NSURLComponents()
        appURLComponents.scheme = "notes"
        appURLComponents.host = nil
        appURLComponents.path = url.path
        if let appURL = appURLComponents.url {
            self.extensionContext?.open(appURL, completionHandler: nil)
        }
    }
}
