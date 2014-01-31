//
//  MainViewController.h
//  BluetoothSharingApp
//
//  Created by ZZB on 13/2/10.
//  Copyright (c) 2013年 ZZB. All rights reserved.
//

#import "FlipsideViewController.h"

@interface MainViewController : UIViewController <FlipsideViewControllerDelegate, UIPopoverControllerDelegate>

@property (strong, nonatomic) UIPopoverController *flipsidePopoverController;

@end
