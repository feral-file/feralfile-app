//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

enum NotificationType {
  announcement,
  supportMessage,
  dailyArtworkReminders,
  galleryNewNft,
  newPostcardTrip,
  postcardShareExpired,
  customerSupportNewMessage,
  customerSupportCloseIssue,
  artworkCreated,
  artworkReceived,
  newMessage,
  jgCrystallineWorkHasArrived,
  jgCrystallineWorkGenerated,
  exhibitionViewingOpening,
  exhibitionSalesOpening,
  exhibitionSaleClosing,
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
      case NotificationType.dailyArtworkReminders:
        return 'daily_artwork_reminders';
      case NotificationType.galleryNewNft:
        return 'gallery_new_nft';
      case NotificationType.newPostcardTrip:
        return 'new_postcard_trip';
      case NotificationType.postcardShareExpired:
        return 'postcard_share_expired';
      case NotificationType.customerSupportNewMessage:
        return 'customer_support_new_message';
      case NotificationType.customerSupportCloseIssue:
        return 'customer_support_close_issue';
      case NotificationType.artworkCreated:
        return 'artwork_created';
      case NotificationType.artworkReceived:
        return 'artwork_received';
      case NotificationType.newMessage:
        return 'new_message';
      case NotificationType.jgCrystallineWorkHasArrived:
        return 'jg_artwork_solar_day_arrived';
      case NotificationType.jgCrystallineWorkGenerated:
        return 'jg_artwork_generated';
      case NotificationType.exhibitionViewingOpening:
        return 'exhibition_view_opening';
      case NotificationType.exhibitionSalesOpening:
        return 'exhibition_sale_opening';
      case NotificationType.exhibitionSaleClosing:
        return 'exhibition_sale_closing';
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
      case 'daily_artwork_reminders':
        return NotificationType.dailyArtworkReminders;
      case 'gallery_new_nft':
        return NotificationType.galleryNewNft;
      case 'new_postcard_trip':
        return NotificationType.newPostcardTrip;
      case 'postcard_share_expired':
        return NotificationType.postcardShareExpired;
      case 'customer_support_new_message':
        return NotificationType.customerSupportNewMessage;
      case 'customer_support_close_issue':
        return NotificationType.customerSupportCloseIssue;
      case 'artwork_created':
        return NotificationType.artworkCreated;
      case 'artwork_received':
        return NotificationType.artworkReceived;
      case 'new_message':
        return NotificationType.newMessage;
      case 'jg_artwork_solar_day_arrived':
        return NotificationType.jgCrystallineWorkHasArrived;
      case 'jg_artwork_generated':
        return NotificationType.jgCrystallineWorkGenerated;
      case 'exhibition_view_opening':
        return NotificationType.exhibitionViewingOpening;
      case 'exhibition_sale_opening':
        return NotificationType.exhibitionSalesOpening;
      case 'exhibition_sale_closing':
        return NotificationType.exhibitionSaleClosing;
      case 'navigate':
        return NotificationType.navigate;
      default:
        return NotificationType.general;
    }
  }
}
