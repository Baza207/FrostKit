//
//  SocialHelper.swift
//  FrostKit
//
//  Created by James Barrow on 30/09/2014.
//  Copyright © 2014 - 2017 James Barrow - Frostlight Solutions. All rights reserved.
//

#if os(OSX)
import AppKit
#else
import UIKit
#endif
import Social
import MessageUI

/// 
/// The social helper class allows quick access to some social aspects, such as presenting an email/message. This class has a private singleton it used for dleegate methods, so that every presenting view controller does not have to impliment them seperately.
///
public class SocialHelper: NSObject, UINavigationControllerDelegate, MFMailComposeViewControllerDelegate, MFMessageComposeViewControllerDelegate {
    
    // MARK: - Singleton & Init
    
    // For use with delegate methods only, hence private NOT public
    private static let shared = SocialHelper()
    
    private override init() {
        super.init()
    }
    
    // MARK: - Scocial Methods
    
    /**
    Presents a compose view controller with the details passed in.
     
    - parameter serviceType:    The type of service type to present. For a list of possible values, see Service Type Constants.
    - parameter initialText:    The initial text to show in the `SLComposeViewController`.
    - parameter urls:           The URLs to attach to the `SLComposeViewController`.
    - parameter images:         The images to attach to the `SLComposeViewController`.
    - parameter viewController: The view controller to present the `SLComposeViewController` in.
    - parameter animated:       If the presentation should be animated or not.
     
    - returns: Returns `false` if there is an issue or the service is unavailable, otherwise `true`.
    */
    public class func presentComposeViewController(serviceType: String, initialText: String? = nil, urls: [URL]? = nil, images: [UIImage]? = nil, inViewController viewController: UIViewController, animated: Bool = true) -> Bool {
        
        if SLComposeViewController.isAvailable(forServiceType: serviceType) {
            
            guard let composeViewController = SLComposeViewController(forServiceType: serviceType) else {
                return false
            }
            composeViewController.setInitialText(initialText)
            
            if let urlsArray = urls {
                for url in urlsArray {
                    composeViewController.add(url)
                }
            }
            
            if let imagesArray = images {
                for image in imagesArray {
                    composeViewController.add(image)
                }
            }
            
            viewController.present(composeViewController, animated: animated, completion: nil)
            
        } else {
            // TODO: Handle social service unavailability
            DLog("Error: Social Service Unavailable!")
            return false
        }
        
        return true
    }
    
    // MARK: - Prompt Methods
    
    /**
    Returns a URL to call with `openURL(_:)` in `UIApplication` parsed from a number string.
     
    Note: `openURL(_:)` can not be called directly within a Framework so that has to be done manually inside the main application.
     
    - parameter number: The number to parse in to create the URL.
     
    - returns: The URL of the parsed phone number, prefixed with `telprompt://`.
    */
    public class func phonePrompt(_ number: String) -> URL? {
        
        let hasPlusPrefix = number.range(of: "+")
        
        let characterSet = NSCharacterSet.decimalDigits.inverted
        let componentsArray = number.components(separatedBy: characterSet)
        var parsedNumber = componentsArray.joined(separator: "")
        
        if hasPlusPrefix != nil {
            parsedNumber = "+" + parsedNumber
        }
        
        return URL(string: "telprompt://\(parsedNumber)")
    }
    
    /**
    Creates a prompt for an email with the following parameters to pass into the `MFMailComposeViewController`.
     
    - parameter toRecipients:   The email addresses of the recipients of the email.
    - parameter ccRecipients:   The email addresses of the CC recipients of the email.
    - parameter bccRecipients:  The email addresses of the BCC recipients of the email.
    - parameter subject:        The subject of the email.
    - parameter messageBody:    The main body of the email.
    - parameter isBodyHTML:     Tells the `MFMailComposeViewController` if the message body is HTML.
    - parameter attachments:    The attachments to add to the email, passed in as a tuple of data, mime type and the file name.
    - parameter viewController: The view controller to present the `MFMailComposeViewController` in.
    - parameter animated:       If the presentation should be animated or not.
    */
    public class func emailPrompt(toRecipients: [String], ccRecipients: [String]? = nil, bccRecipients: [String]? = nil, subject: String = "", messageBody: String = "", isBodyHTML: Bool = false, attachments: [(data: Data, mimeType: String, fileName: String)]? = nil, viewController: UIViewController, animated: Bool = true) {
        
        if MFMailComposeViewController.canSendMail() {
            
            let emailsString = toRecipients.joined(separator: ", ")
            
            let alertController = UIAlertController(title: emailsString, message: nil, preferredStyle: .alert)
            alertController.view.tintColor = FrostKit.tintColor
            let cancelAlertAction = UIAlertAction(title: FKLocalizedString("CANCEL"), style: .cancel) { (_) in
                alertController.dismiss(animated: true, completion: nil)
            }
            alertController.addAction(cancelAlertAction)
            let openAlertAction = UIAlertAction(title: FKLocalizedString("EMAIL"), style: .default) { (_) in
                
                SocialHelper.presentMailComposeViewController(toRecipients: toRecipients, ccRecipients: ccRecipients, bccRecipients: bccRecipients, subject: subject, messageBody: messageBody, isBodyHTML: isBodyHTML, attachments: attachments, viewController: viewController, animated: animated)
            }
            
            alertController.addAction(openAlertAction)
            viewController.present(alertController, animated: true, completion: nil)
            
        } else {
            // TODO: Handle eamil service unavailability
            DLog("Error: Email Service Unavailable!")
        }
    }
    
    public class func presentMailComposeViewController(toRecipients: [String]? = nil, ccRecipients: [String]? = nil, bccRecipients: [String]? = nil, subject: String = "", messageBody: String = "", isBodyHTML: Bool = false, attachments: [(data: Data, mimeType: String, fileName: String)]? = nil, viewController: UIViewController, animated: Bool) {
        
        let mailVC = MFMailComposeViewController()
        mailVC.view.tintColor = FrostKit.tintColor
        mailVC.mailComposeDelegate = SocialHelper.shared
        mailVC.setSubject(subject)
        mailVC.setToRecipients(toRecipients)
        mailVC.setCcRecipients(ccRecipients)
        mailVC.setBccRecipients(bccRecipients)
        mailVC.setMessageBody(messageBody, isHTML: isBodyHTML)
        
        if attachments != nil {
            for (data, mimeType, fileName) in attachments! {
                mailVC.addAttachmentData(data, mimeType: mimeType, fileName: fileName)
            }
        }
        
        viewController.present(mailVC, animated: animated, completion: nil)
    }
    
    /**
    Creates a prompt for a message with the following parameters to pass into the `MFMessageComposeViewController`.
     
    - parameter recipients:     The recipients of the message.
    - parameter subject:        The subject of the message.
    - parameter body:           The main body of the message.
    - parameter attachments:    The attachments to add to the message, passed in as a tuple of attachment URL and alternate filename.
    - parameter viewController: The view controller to present the `MFMailComposeViewController` in.
    - parameter animated:       If the presentation should be animated or not.
    */
    public class func messagePrompt(recipients: [String], subject: String = "", body: String = "", attachments: [(attachmentURL: URL, alternateFilename: String)] = [], viewController: UIViewController, animated: Bool = true) {
        
        if MFMessageComposeViewController.canSendText() {
            
            let recipientsString = recipients.joined(separator: ", ")
            
            let alertController = UIAlertController(title: recipientsString, message: nil, preferredStyle: .alert)
            alertController.view.tintColor = FrostKit.tintColor
            let cancelAlertAction = UIAlertAction(title: FKLocalizedString("CANCEL"), style: .cancel) { (_) in
                alertController.dismiss(animated: true, completion: nil)
            }
            alertController.addAction(cancelAlertAction)
            let openAlertAction = UIAlertAction(title: FKLocalizedString("MESSAGE"), style: .default) { (_) in
                
                SocialHelper.presentMessageComposeViewController(recipients: recipients, subject: subject, body: body, attachments: attachments, viewController: viewController, animated: animated)
            }
            
            alertController.addAction(openAlertAction)
            viewController.present(alertController, animated: true, completion: nil)
            
        } else {
            // TODO: Handle message service unavailability
            DLog("Error: Message Service Unavailable!")
        }
    }
    
    public class func presentMessageComposeViewController(recipients: [String]? = nil, subject: String? = nil, body: String? = nil, attachments: [(attachmentURL: URL, alternateFilename: String)]? = nil, viewController: UIViewController, animated: Bool) {
        
        let messageVC = MFMessageComposeViewController()
        messageVC.messageComposeDelegate = SocialHelper.shared
        messageVC.recipients = recipients
        
        if MFMessageComposeViewController.canSendSubject() {
            messageVC.subject = subject
        }
        
        if MFMessageComposeViewController.canSendAttachments() && attachments != nil {
            for (attachmentURL, alternateFilename) in attachments! {
                messageVC.addAttachmentURL(attachmentURL, withAlternateFilename: alternateFilename)
            }
        }
        
        messageVC.body = body
        
        viewController.present(messageVC, animated: animated, completion: nil)
    }
    
    // MARK: - MFMailComposeViewControllerDelegate Methods
    
    public func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        
        switch result {
        case .cancelled:
            DLog("Email cancelled")
        case .saved:
            DLog("Email saved")
        case .sent:
            DLog("Email sent")
        case .failed:
            if let anError = error {
                DLog("Email send failed: \(anError.localizedDescription)")
            } else {
                DLog("Email send failed!")
            }
        @unknown default:
            break
        }
        
        controller.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - MFMessageComposeViewControllerDelegate Methods
    
    public func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        
        switch result {
        case .cancelled:
            DLog("Message cancelled")
        case .sent:
            DLog("Message sent")
        case .failed:
            DLog("Message failed")
        @unknown default:
            break
        }
        
        controller.dismiss(animated: true, completion: nil)
    }
}
