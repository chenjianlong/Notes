//
//  Document.swift
//  Notes
//
//  Created by chenjianlong on 2017/8/26.
//  Copyright © 2017年 MyCompany. All rights reserved.
//

import Cocoa

/*extension FileWrapper {
    dynamic var fileExtension: String? {
        return self.preferredFilename?.components(separatedBy: ".").last
    }
    
    dynamic var thumbnailImage: NSImage {
        if let fileExtension = self.fileExtension {
            return NSWorkspace.shared().icon(forFileType: fileExtension)
        } else {
            return NSWorkspace.shared().icon(forFileType: "")
        }
    }
    
    func conformsToType(type: String) -> Bool {
        guard let fileExtension = self.fileExtension else {
            return false
        }
        
        // get file type from extension
        guard let fileType = UTTypeCreatePreferredIdentifierForTag(
            kUTTagClassFilenameExtension, fileExtension as CFString, nil)?.takeRetainedValue() else {
                return false
        }
        
        return UTTypeConformsTo(fileType, type as CFString)
    }
}*/

enum NoteDocumentFileNames : String {
    case TextFile = "Text.rtf"
    case AttachmentsDirectory = "Attachments"
}

enum ErrorCode : Int {
    case CannotAccessDocument
    case CannotLoadFileWrappers
    case CannotLoadText
    case CannotAccessAttachments
    case CannotSaveText
    case CannotSaveAttachment
}

let ErrorDomain = "NotesErrorDomain"

func err(code: ErrorCode, _ userInfo: [NSObject: AnyObject]? = nil) -> NSError {
    return NSError(domain: ErrorDomain, code: code.rawValue, userInfo: userInfo)
}

class Document: NSDocument {
    var text : NSAttributedString = NSAttributedString()
    var documentFileWrapper = FileWrapper(directoryWithFileWrappers: [:])
    var vc: ViewController!

    override init() {
        super.init()
        // Add your subclass-specific initialization here.
    }

    override class func autosavesInPlace() -> Bool {
        return true
    }

    override func makeWindowControllers() {
        // Returns the Storyboard that contains your Document window.
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: "Document Window Controller") as! NSWindowController
        self.addWindowController(windowController)
        vc = windowController.contentViewController as! ViewController
    }

    override func data(ofType typeName: String) throws -> Data {
        // Save the text view contents to disk
        if let textView = vc.textView,
            let rangeLength = textView.string?.characters.count {
            
            textView.breakUndoCoalescing()
            let textRange = NSRange(location: 0, length: rangeLength)
            if let contents = textView.rtf(from: textRange) {
                return contents
            }
        }
        
        throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }

    /*override func read(from data: Data, ofType typeName: String) throws {
        if let contents = NSAttributedString(rtf: data, documentAttributes: nil) {
            text = contents
        }
    }*/

    override func fileWrapper(ofType typeName: String) throws -> FileWrapper {
        let textRTFData = try self.data(ofType: String())
        /*let textRTFData = try self.text.data(
            from: NSRange(0 ..< self.text.length),
            documentAttributes: [
            NSDocumentTypeDocumentAttribute: NSRTFTextDocumentType
            ]
        )*/
        
        if let oldTextFileWrapper = self.documentFileWrapper
            .fileWrappers?[NoteDocumentFileNames.TextFile.rawValue] {
            self.documentFileWrapper.removeFileWrapper(oldTextFileWrapper)
        }
        
        self.documentFileWrapper.addRegularFile(
            withContents: textRTFData,
            preferredFilename: NoteDocumentFileNames.TextFile.rawValue
        )
        
        return self.documentFileWrapper
    }
    
    override func read(from fileWrapper: FileWrapper, ofType typeName: String) throws {
        guard let fileWrappers = fileWrapper.fileWrappers else {
            throw err(code: .CannotLoadFileWrappers)
        }
        
        guard let documentTextData =
            fileWrappers[NoteDocumentFileNames.TextFile.rawValue]?
                .regularFileContents else {
                    throw err(code: .CannotLoadText)
        }
        
        
        
        guard let documentText = NSAttributedString(rtf: documentTextData,
            documentAttributes: nil) else {
                throw err(code: .CannotLoadText)
        }
        
        self.documentFileWrapper = fileWrapper
        self.text = documentText
    }
}

