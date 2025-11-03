//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

enum NotificationType {
  announcement,
  supportMessage,
  customerSupportNewMessage,
  customerSupportCloseIssue,
  navigate,
  general,
  ;

  // toString method
  @override
  String toString() {
    switch (this) {
      case NotificationType.announcement:
        return 'announcement';
      case NotificationType.supportMessage:
        return 'support_messages';
      case NotificationType.customerSupportNewMessage:
        return 'customer_support_new_message';
      case NotificationType.customerSupportCloseIssue:
        return 'customer_support_close_issue';
      case NotificationType.navigate:
        return 'navigate';
      case NotificationType.general:
        return 'general';
    }
  }

  // fromString method
  static NotificationType fromString(String value) {
    switch (value) {
      case 'announcement':
        return NotificationType.announcement;
      case 'support_messages':
        return NotificationType.supportMessage;
      case 'customer_support_new_message':
        return NotificationType.customerSupportNewMessage;
      case 'customer_support_close_issue':
        return NotificationType.customerSupportCloseIssue;
      case 'navigate':
        return NotificationType.navigate;
      default:
        return NotificationType.general;
    }
  }
}
