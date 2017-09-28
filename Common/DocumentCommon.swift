//
//  DocumentCommon.swift
//  Notes
//
//  Created by chenjianlong on 2017/9/7.
//  Copyright © 2017年 MyCompany. All rights reserved.
//

import Foundation

let ErrorDomain = "NotesErrorDomain"

func err(code: ErrorCode, _ userInfo: [NSObject: AnyObject]? = nil) -> NSError
{
    return NSError(domain: ErrorDomain,
                   code: code.rawValue,
                   userInfo: userInfo)
}

enum NoteDocumentFileNames: String {
    case TextFile = "Text.rtf"
    case AttachmentDirectory = "Attachments"
    case QuickLookDirectory = "QuickLook"
    case QuickLookTextFile = "Preview.rtf"
    case QuickLookThumbnail = "Thumbnail.png"
}

let NotesUseiCloudKey = "use_icloud"
let NotesHasPromptedForiCloudKey = "has_prompted_for_icloud"

enum ErrorCode : Int {
    case CannotAccessDocument
    case CannotLoadFileWrappers
    case CannotLoadText
    case CannotAccessAttachments
    case CannotSaveText
    case CannotSaveAttachment
}
