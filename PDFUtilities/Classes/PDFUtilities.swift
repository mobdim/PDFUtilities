//
//  PDFUtilities - Tools for working with PDFs
//  PDFUtilities.swift
//
//  Created by Ben Bahrenburg on 3/23/16.
//  Copyright © 2016 bencoding.com. All rights reserved.
//

import UIKit

open class PDFUtilities {
    
    class func toDocumentInfo(password: String) -> [String: AnyObject] {
        var info: [String: AnyObject] = [:]
        info[String(kCGPDFContextUserPassword)] = password as AnyObject?
        info[String(kCGPDFContextOwnerPassword)] = password as AnyObject?
        return info
    }
    
    class open func imageFromPDFPage(page: CGPDFPage, pageNumber: Int) -> UIImage {
        let pageRect = page.getBoxRect(CGPDFBox.mediaBox)
        
        UIGraphicsBeginImageContext(pageRect.size)
        let ctx = UIGraphicsGetCurrentContext()
        ctx?.interpolationQuality = .high
        // Draw existing page
        ctx!.saveGState()
        ctx!.scaleBy(x: 1, y: -1)
        ctx!.translateBy(x: 0, y: -(pageRect.size.height))
        ctx!.drawPDFPage(page)
        ctx!.restoreGState()
        
        let backgroundImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return backgroundImage!
    }
    
    class open func hasPassword(fileURL: URL) -> Bool {
        return autoreleasepool { () -> Bool in
            do {
                let data = try Data(contentsOf: fileURL)
                return hasPassword(input: data)
            } catch {
                return false
            }
        }
    }
    
    class open func hasPassword(input: Data) -> Bool {
        return autoreleasepool { () -> Bool in
            let dataProvider = CGDataProvider(data: input as CFData)
            if let provider = dataProvider {
                if let pdf = CGPDFDocument(provider) {
                    if pdf.isUnlocked || pdf.isEncrypted {
                        return true
                    }
                }
            }
            
            return false
        }
    }
    
    class open func isValidPDF(input: Data) -> Bool {
        return autoreleasepool { () -> Bool in
            let dataProvider = CGDataProvider(data: input as CFData)
            if let provider = dataProvider {
                if let pdf = CGPDFDocument(provider) {
                    if pdf.isUnlocked || pdf.isEncrypted {
                        return true
                    }
                    return pdf.numberOfPages > 0
                }
            }
            
            return false
        }
    }
    
    class open func isValidPDF(fileURL: URL) -> Bool {
        return autoreleasepool { () -> Bool in
            do {
                let data = try Data(contentsOf: fileURL)
                return isValidPDF(input: data)
            } catch {
                return false
            }
        }
    }
    
    class open func canUnlock(fileURL: URL, password: String) -> Bool {
        return autoreleasepool { () -> Bool in
            do {
                let data = try Data(contentsOf: fileURL)
                return canUnlock(input: data, password: password)
            } catch {
                return false
            }
        }
    }
    
    class open func canUnlock(input: Data, password: String) -> Bool {
        return autoreleasepool { () -> Bool in
            let dataProvider = CGDataProvider(data: input as CFData)
            let pdf = CGPDFDocument(dataProvider!)
            
            // Try a blank password first, per Apple's Quartz PDF example
            if pdf?.isEncrypted == true &&
                pdf?.unlockWithPassword("") == false {
                // Nope, now let's try the provided password to unlock the PDF
                if let cPasswordString = password.cString(using: String.Encoding.utf8) {
                    if pdf?.unlockWithPassword(cPasswordString) == false {
                        return false
                    }
                }
            }
            return true
        }
    }
    
    class open func convertPdfToData(pdf: CGPDFDocument, password: String? = nil) throws -> Data {
        let data = NSMutableData()
        
        autoreleasepool {
            let pageCount = pdf.numberOfPages
            let options = (password != nil) ? self.toDocumentInfo(password: password!) : nil
            UIGraphicsBeginPDFContextToData(data, .zero, options)
            for index in 1...pageCount {
                
                let page = pdf.page(at: index)
                let pageRect = page?.getBoxRect(CGPDFBox.mediaBox)
                
                
                UIGraphicsBeginPDFPageWithInfo(pageRect!, nil)
                let ctx = UIGraphicsGetCurrentContext()
                ctx?.interpolationQuality = .high
                // Draw existing page
                ctx!.saveGState()
                ctx!.scaleBy(x: 1, y: -1)
                ctx!.translateBy(x: 0, y: -(pageRect?.size.height)!)
                ctx!.drawPDFPage(page!)
                ctx!.restoreGState()
                
            }
            
            UIGraphicsEndPDFContext()
        }
        return data as Data
    }
    
    class open func addPassword(input: Data, password: String) throws -> Data {
        let dataProvider = CGDataProvider(data: input as CFData)
        let pdf = CGPDFDocument(dataProvider!)
        return try convertPdfToData(pdf: pdf!, password: password)
    }
    
    
    class open func removePassword(fileURL: URL, password: String) throws -> Data? {
        return try autoreleasepool { () -> Data? in
            do {
                let data = try Data(contentsOf: fileURL)
                return try removePassword(input: data, password: password)
            } catch {
                return nil
            }
        }
    }
    
    class open func removePassword(input: Data, password: String) throws -> Data? {
        return try autoreleasepool { () -> Data? in
            let dataProvider = CGDataProvider(data: input as CFData)
            if let provider = dataProvider {
                if let pdf = CGPDFDocument(provider) {
                    // Try a blank password first, per Apple's Quartz PDF example
                    if pdf.isEncrypted == true &&
                        pdf.unlockWithPassword("") == false {
                        // Nope, now let's try the provided password to unlock the PDF
                        if let cPasswordString = password.cString(using: String.Encoding.utf8) {
                            if pdf.unlockWithPassword(cPasswordString) == false {
                                print("Unable to unlock")
                                return nil
                            }
                        }
                    }
                    
                    return try convertPdfToData(pdf: pdf)
                }
            }
            return nil
        }
    }
    
    class open func imageToPDF(image: UIImage, password: String? = nil, scaleFactor: CGFloat = 1) throws -> Data? {
        
        guard scaleFactor > 0.0 else {
            return nil
        }
        
        return autoreleasepool { () -> Data in
            let data = NSMutableData()
            
            autoreleasepool {
                let options = (password != nil) ? self.toDocumentInfo(password: password!) : nil
                UIGraphicsBeginPDFContextToData(data, .zero, options)
                
                let bounds = CGRect(
                    origin: .zero,
                    size: CGSize(
                        width: image.size.width * scaleFactor,
                        height: image.size.height * scaleFactor
                    )
                )
                UIGraphicsBeginPDFPageWithInfo(bounds, nil)
                image.draw(in: bounds)
                
                UIGraphicsEndPDFContext()
            }
            
            return data as Data
        }
    }
    
}