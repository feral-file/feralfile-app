//
//  NotificationService.swift
//  Runner Notification
//
//  Created by Nguyen Phuoc Sang on 16/12/25.
//

import UserNotifications
import OneSignalExtension

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var receivedRequest: UNNotificationRequest?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        self.receivedRequest = request
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        if let bestAttemptContent = bestAttemptContent {
            // Let OneSignal handle the notification first
            OneSignalExtension.didReceiveNotificationExtensionRequest(
                request,
                with: bestAttemptContent,
                withContentHandler: contentHandler
            )
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        if let request = receivedRequest,
           let contentHandler = contentHandler,
           let bestAttemptContent = bestAttemptContent {
            // Let OneSignal handle expiration
            OneSignalExtension.serviceExtensionTimeWillExpireRequest(
                request,
                with: bestAttemptContent
            )
            contentHandler(bestAttemptContent)
        }
    }

}
