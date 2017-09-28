//
//  Document.swift
//  Notes
//
//  Created by chenjianlong on 2017/9/7.
//  Copyright © 2017年 MyCompany. All rights reserved.
//

import UIKit

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
}
