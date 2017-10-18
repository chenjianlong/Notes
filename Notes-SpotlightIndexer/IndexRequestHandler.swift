//
//  IndexRequestHandler.swift
//  Notes-SpotlightIndexer
//
//  Created by chenjianlong on 2017/10/17.
//  Copyright © 2017年 MyCompany. All rights reserved.
//

import CoreSpotlight
import UIKit

class IndexRequestHandler: CSIndexExtensionRequestHandler {
    var availableFiles : [URL] {
        let fileManager = FileManager.default
        var allFiles : [URL] = []
        
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
                return []
            }
        }
        
        return allFiles.filter({ $0.lastPathComponent.hasSuffix(".note") })
    }
    
    func itemForURL(url: URL) -> CSSearchableItem? {
        do {
            if try url.checkResourceIsReachable() == false {
                return nil
            }
        } catch {
            return nil
        }
        
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: "au.com.secretlab.Note")
        attributeSet.title = url.lastPathComponent
        
        let textFileURL = url.appendingPathComponent(NoteDocumentFileNames.TextFile.rawValue, isDirectory: false)
        if let textData = try? Data(contentsOf: textFileURL),
            let text = try? NSAttributedString(data: textData, options: [NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
            attributeSet.contentDescription = text.string
        } else {
            attributeSet.contentDescription = ""
        }
        
        let item = CSSearchableItem(uniqueIdentifier: url.absoluteString, domainIdentifier: "au.com.secretlab.Note", attributeSet: attributeSet)
        return item
    }

    override func searchableIndex(_ searchableIndex: CSSearchableIndex, reindexAllSearchableItemsWithAcknowledgementHandler acknowledgementHandler: @escaping () -> Void) {
        let files = availableFiles
        var allItems: [CSSearchableItem] = []
        
        for file in files {
            if let item = itemForURL(url: file) {
                allItems.append(item)
            }
        }
        
        searchableIndex.indexSearchableItems(allItems, completionHandler: {
            (error) -> Void in
            acknowledgementHandler()
        })
    }
    
    override func searchableIndex(_ searchableIndex: CSSearchableIndex, reindexSearchableItemsWithIdentifiers identifiers: [String], acknowledgementHandler: @escaping () -> Void) {
        var itemsToIndex : [CSSearchableItem] = []
        var itemsToRemove : [String] = []
        
        for identifier in identifiers {
            if let url = URL(string: identifier), let item = itemForURL(url: url) {
                itemsToIndex.append(item)
            } else {
                itemsToRemove.append(identifier)
            }
        }
        
        searchableIndex.indexSearchableItems(itemsToIndex, completionHandler: {
            (error) -> Void in
            searchableIndex.deleteSearchableItems(withIdentifiers: itemsToRemove, completionHandler: {
                (error) -> Void in
                acknowledgementHandler()
            })
        })
    }
    
    override func data(for searchableIndex: CSSearchableIndex, itemIdentifier: String, typeIdentifier: String) throws -> Data {
        // Replace with Data representation of requested type from item identifier
        
        return Data()
    }
    
    override func fileURL(for searchableIndex: CSSearchableIndex, itemIdentifier: String, typeIdentifier: String, inPlace: Bool) throws -> URL {
        // Replace with to return file url based on requested type from item identifier
        
        return URL(string:"file://")!
    }
    
}
