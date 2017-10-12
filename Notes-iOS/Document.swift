//
//  Document.swift
//  Notes
//
//  Created by chenjianlong on 2017/9/7.
//  Copyright © 2017年 MyCompany. All rights reserved.
//

import UIKit
import MobileCoreServices

extension FileWrapper {
    var fileExtension : String? {
        return self.preferredFilename?.components(separatedBy: ".").last
    }
    
    func conformsToType(type: CFString) -> Bool {
        guard let fileExtension = fileExtension else {
            return false
        }
        
        guard let fileType = UTTypeCreatePreferredIdentifierForTag(
            kUTTagClassFilenameExtension, fileExtension as CFString, nil)?.takeRetainedValue() else {
            return false
        }
        
        return UTTypeConformsTo(fileType, type)
    }
    
    func thumbnailImage() -> UIImage? {
        if self.conformsToType(type: kUTTypeImage) {
            guard let attachmentContent = self.regularFileContents else {
                return nil
            }
            
            return UIImage(data: attachmentContent)
        }
        
        return nil
    }
}

class Document: UIDocument {
    var text = NSAttributedString(string: "") {
        didSet {
            self.updateChangeCount(UIDocumentChangeKind.done)
        }
    }
    
    var documentFileWrapper = FileWrapper(directoryWithFileWrappers: [:])
    
    override func contents(forType typeName: String) throws -> Any {
        let textRTFData = try self.text.data(from: NSRange(0..<self.text.length), documentAttributes: [NSDocumentTypeDocumentAttribute: NSRTFTextDocumentType])
        
        if let oldTextFileWrapper = self.documentFileWrapper.fileWrappers?[NoteDocumentFileNames.TextFile.rawValue] {
            self.documentFileWrapper.removeFileWrapper(oldTextFileWrapper)
        }
        
        self.documentFileWrapper.addRegularFile(withContents: textRTFData, preferredFilename: NoteDocumentFileNames.TextFile.rawValue)
        
        return self.documentFileWrapper
    }
    
    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        guard let fileWrapper = contents as? FileWrapper else {
            throw err(code: .CannotLoadFileWrappers)
        }
        
        guard let textFileWrapper = fileWrapper.fileWrappers?[NoteDocumentFileNames.TextFile.rawValue],
            let textFileData = textFileWrapper.regularFileContents else {
                throw err(code: .CannotLoadText)
        }
        
        self.text = try NSAttributedString(data: textFileData, options: [NSDocumentTypeDocumentAttribute: NSRTFTextDocumentType], documentAttributes: nil)
        
        self.documentFileWrapper = fileWrapper
    }
    
    private var attachmentsDirectoryWrapper : FileWrapper? {
        guard let fileWrappers = self.documentFileWrapper.fileWrappers else {
            NSLog("Attempting to access document's contents, but none found!")
            return nil
        }
    
        var attachmentsDirectoryWrapper = fileWrappers[NoteDocumentFileNames.AttachmentDirectory.rawValue]
    
        if attachmentsDirectoryWrapper == nil {
            attachmentsDirectoryWrapper = FileWrapper(directoryWithFileWrappers: [:])
            attachmentsDirectoryWrapper?.preferredFilename = NoteDocumentFileNames.AttachmentDirectory.rawValue
            
            self.documentFileWrapper.addFileWrapper(attachmentsDirectoryWrapper!)
            self.updateChangeCount(UIDocumentChangeKind.done)
        }
        
        return attachmentsDirectoryWrapper
    }
    
    dynamic var attachFiles : [FileWrapper]? {
        guard let attachmentsFileWrappers = attachmentsDirectoryWrapper?.fileWrappers else {
            NSLog("Can't access the attachments directory!")
            return nil
        }
        
        return Array(attachmentsFileWrappers.values)
    }
    
    func addAttachmentAtURL(url: URL) throws -> FileWrapper {
        guard attachmentsDirectoryWrapper != nil else {
            throw err(code: .CannotAccessAttachments)
        }
        
        let newAttachment = try FileWrapper(url: url, options: FileWrapper.ReadingOptions.immediate)
        
        attachmentsDirectoryWrapper?.addFileWrapper(newAttachment)
        self.updateChangeCount(UIDocumentChangeKind.done)
        return newAttachment
    }
}
