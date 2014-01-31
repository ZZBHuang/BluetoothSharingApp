//
//  FlipsideViewController.m
//  BluetoothSharingApp
//
//  Created by ZZB on 13/2/10.
//  Copyright (c) 2013年 ZZB. All rights reserved.
//

#import "FlipsideViewController.h"

@interface FlipsideViewController ()

@property (nonatomic, weak) IBOutlet UILabel *versionLabel;

- (IBAction)feedbackToMe:(id)sender;
- (IBAction)rateThisApp:(id)sender;

@end

@implementation FlipsideViewController

- (void)awakeFromNib
{
    self.preferredContentSize = CGSizeMake(320.0, 480.0);
    [super awakeFromNib];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    self.versionLabel.text = [NSString stringWithFormat:@"%@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Actions

- (IBAction)done:(id)sender
{
    NSLog(@"%@", self.delegate);
    [self.delegate flipsideViewControllerDidFinish:self];
}

- (IBAction)feedbackToMe:(id)sender {
    NSString *path = @"mailto:zzbhhuang@gmail.com?subject=Bluetooth Messenger App Feedback";
    NSURL *url = [NSURL URLWithString:[path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    [[UIApplication sharedApplication] openURL:url];
    
}

- (IBAction)rateThisApp:(id)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://itunes.apple.com/app/bluetooth-photo-share-messenger/id604386827"]];

}

@end
