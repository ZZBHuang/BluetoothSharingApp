//
//  AppConstant.h
//  BluetoothSharingApp
//
//  Created by ZZB on 13/2/10.
//  Copyright (c) 2013年 ZZB. All rights reserved.
//

#ifndef BluetoothSharingApp_AppConstant_h
#define BluetoothSharingApp_AppConstant_h


#define kSendMessageCharacteristicUUID      [CBUUID UUIDWithString:@"9AAA4C67-8162-4BCD-A093-BA1C78A5222F"]
#define kReceiveMessageMessageCharacteristicUUID      [CBUUID UUIDWithString:@"04CFE68F-A1C2-4F1B-B385-A162A0CB4215"]
#define kPhotoSendingCharacteristicUUID     [CBUUID UUIDWithString:@"04B85A02-5E91-444D-BA5E-41BA4675829B"]
#define kPhotoReceivingCharacteristicUUID     [CBUUID UUIDWithString:@"46E00B64-D786-4BB4-917E-5851A3F432FB"]
#define kAppServiceUUID                     [CBUUID UUIDWithString:@"917377DF-CD47-42B2-A5B4-E776E3BA9EDF"]

#define NOTIFY_MTU  20
#define WRITE_MAX   128

#define kChatRefreshTime    30.0f

#endif
