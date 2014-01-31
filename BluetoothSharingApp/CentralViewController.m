//
//  CentralViewController.m
//  BluetoothSharingApp
//
//  Created by ZZB on 13/2/10.
//  Copyright (c) 2013年 ZZB. All rights reserved.
//

#import "CentralViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>

#import "AppConstant.h"
#import "UIBubbleTableViewDataSource.h"
#import "UIBubbleTableView.h"
#import "UIBubbleTableViewDataSource.h"
#import "NSBubbleData.h"
#import "DAKeyboardControl.h"
#import "SBTableAlert.h"



@interface CentralViewController ()<CBCentralManagerDelegate, CBPeripheralDelegate, UITextFieldDelegate, UIBubbleTableViewDataSource, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIAlertViewDelegate, UIActionSheetDelegate, SBTableAlertDataSource, SBTableAlertDelegate> {
}

@property (nonatomic, assign) BOOL isEOM;
@property (nonatomic, assign) BOOL isEOF;
@property (nonatomic, assign) BOOL isCameraSelected;
@property (nonatomic, assign) NSBubbleTypingType currentTypingBubble;
@property (weak, nonatomic) IBOutlet UITextField *messageTextField;
@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) CBPeripheral *targetPeripheral;
@property (strong, nonatomic) CBCharacteristic *sendMessageCharacteristic;
@property (strong, nonatomic) CBCharacteristic *sendPhotoCharacteristic;
@property (strong, nonatomic) NSData *messageToSend;
@property (strong, nonatomic) NSMutableData *messageToReceive;
@property (strong, nonatomic) NSData *photoToSend;
@property (strong, nonatomic) NSMutableData *photoToReceive;
@property (nonatomic, readwrite) NSInteger sendMessageIndex;
@property (nonatomic, readwrite) NSInteger lastAmountMessageToSend;
@property (nonatomic, readwrite) NSInteger sendPhotoIndex;
@property (nonatomic, readwrite) NSInteger lastAmountPhotoToSend;
@property (nonatomic, weak) IBOutlet UIBubbleTableView *bubbleTableView;
@property (nonatomic, strong) NSMutableArray *bubbleData;
@property (nonatomic, weak) IBOutlet UIToolbar *messageToolbar;
@property (nonatomic, weak) IBOutlet UIView *loadingView;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *photoButton;
@property (nonatomic, strong) NSMutableDictionary *peripherals;
@property (nonatomic, strong) SBTableAlert *tableAlertView;
@property (nonatomic, strong) UIImagePickerController *pickerCtrl;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *toolbarBottomSpaceContraint;


- (IBAction)sendMessage:(id)sender;
- (void)handleSendingMessage;
- (void)hideKeyboard:(UITapGestureRecognizer *)gesture;
- (void)handleSendingPhoto;
- (IBAction)presentPhotoPciker:(id)sender;
- (void)sendName;

@end

@implementation CentralViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    self.messageToReceive = [[NSMutableData alloc] init];
    self.photoToReceive = [[NSMutableData alloc] init];
    self.bubbleData = [[NSMutableArray alloc] init];
    self.peripherals = [[NSMutableDictionary alloc] init];
    
    // The line below sets the snap interval in seconds. This defines how the bubbles will be grouped in time.
    // Interval of 120 means that if the next messages comes in 2 minutes since the last message, it will be added into the same group.
    // Groups are delimited with header which contains date and time for the first message in the group.
    self.bubbleTableView.snapInterval = kChatRefreshTime;
    self.bubbleTableView.showAvatars = NO;
//    self.bubbleTableView.typingBubble = NSBubbleTypingTypeSomebody;
    
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideKeyboard:)];
    [self.bubbleTableView addGestureRecognizer:singleTap];
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    self.isCameraSelected = NO;
    self.view.keyboardTriggerOffset = self.messageToolbar.bounds.size.height;
    UIToolbar *toolBar = self.messageToolbar;
    self.currentTypingBubble = NSBubbleTypingTypeNobody;
    
    __weak CentralViewController *weakSelf = self;
    
    [self.view addKeyboardPanningWithActionHandler:^(CGRect keyboardFrameInView) {
        
        CGRect toolBarFrame = toolBar.frame;
        toolBarFrame.origin.y = keyboardFrameInView.origin.y - toolBarFrame.size.height;
        //        toolBar.frame = toolBarFrame;
        weakSelf.toolbarBottomSpaceContraint.constant = weakSelf.view.frame.size.height - keyboardFrameInView.origin.y;

        
//        weakSelf.tableViewHeightContraint.constant = toolBarFrame.origin.y - 64.0f;
        [weakSelf.bubbleTableView layoutIfNeeded];
        
    }];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.view removeKeyboardControl];
    if (CBPeripheralStateConnected == self.targetPeripheral.state && self.isCameraSelected == NO) {
        [self.centralManager cancelPeripheralConnection:self.targetPeripheral];        
    }

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - CBCentralManagerDelegate
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central.state == CBPeripheralManagerStateUnsupported) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil message:@"Your device hardware or iOS version doesn't support bluetooth 4.0." delegate:self cancelButtonTitle:@"" otherButtonTitles:nil];
        alertView.tag = 10;
        [alertView show];
    }
    if (central.state != CBCentralManagerStatePoweredOn) {
        // In a real app, you'd deal with all the states correctly
        return;
    }
    
    
    // The state must be CBCentralManagerStatePoweredOn...
    
    // ... so start scanning
    [self.centralManager scanForPeripheralsWithServices:@[kAppServiceUUID] options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@YES}];
    [self.loadingView setHidden:NO];
    [self.photoButton setEnabled:NO];
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    
    if ([[advertisementData allValues] count] > 2) {
        BOOL hasPeripheral = NO;
        
        for (NSDictionary *peripheralObject in [self.peripherals allValues]) {
            CBPeripheral *existPeripheral = [peripheralObject objectForKey:@"pKey"];
            
            if ([existPeripheral.identifier isEqual:peripheral.identifier]) {
                [self.peripherals removeObjectForKey:advertisementData];
                hasPeripheral = YES;
                break;
            }
        }
        
        [self.peripherals setObject:@{@"pKey":peripheral} forKey:advertisementData];
        
        if (hasPeripheral == NO) {
            self.tableAlertView = [[SBTableAlert alloc] initWithTitle:@"Select a broadcaster" cancelButtonTitle:@"Cancel" messageFormat:nil];
            [self.tableAlertView setStyle:SBTableAlertStyleApple];
            [self.tableAlertView setDelegate:self];
            [self.tableAlertView setDataSource:self];
            [self.tableAlertView show];
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{

    [self.tableAlertView.view dismissWithClickedButtonIndex:0 animated:YES];
    NSLog(@"Peripheral Connected");
    // Stop scanning
    [self.centralManager stopScan];
    NSLog(@"Scanning stopped");
    
    // Clear the data that we may already have
    [self.messageToReceive setLength:0];
    [self.photoToReceive setLength:0];
    
    // Make sure we get the discovery callbacks
    peripheral.delegate = self;
    
    // Search only for services that match our UUID
    [peripheral discoverServices:@[kAppServiceUUID]];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:@[kReceiveMessageMessageCharacteristicUUID, kSendMessageCharacteristicUUID, kPhotoReceivingCharacteristicUUID, kPhotoSendingCharacteristicUUID] forService:service];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    
    for (CBCharacteristic *characteristic in service.characteristics) {
        
        // And check if it's the right one
        if ([characteristic.UUID isEqual:kSendMessageCharacteristicUUID]) {
            [self.loadingView setHidden:YES];

            // If it is, subscribe to it
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            [self performSelector:@selector(sendName) withObject:nil afterDelay:1.5f];
        }
        else if ([characteristic.UUID isEqual:kReceiveMessageMessageCharacteristicUUID]) {
            self.sendMessageCharacteristic = characteristic;
        }
        else if ([characteristic.UUID isEqual:kPhotoSendingCharacteristicUUID]) {
            [self.photoButton setEnabled:YES];
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
        else if ([characteristic.UUID isEqual:kPhotoReceivingCharacteristicUUID]) {
            self.sendPhotoCharacteristic = characteristic;
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    
    if ([characteristic.UUID isEqual:kSendMessageCharacteristicUUID]) {
        NSString *stringFromData = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
        
        // Have we got everything we need?
        if ([stringFromData isEqualToString:@"EOM"]) {
            
            // We have, so show the data,
            /*
             self.chatTextView.text = [self.chatTextView.text  stringByAppendingFormat:@"\n%@", [[NSString alloc] initWithData:self.messageToReceive encoding:NSUTF8StringEncoding]];
             */
            NSBubbleData *receiveBubble = [NSBubbleData dataWithText:[[NSString alloc] initWithData:self.messageToReceive encoding:NSUTF8StringEncoding] date:[NSDate dateWithTimeIntervalSinceNow:0] type:BubbleTypeSomeoneElse];
            [self.bubbleData addObject:receiveBubble];
            [self.bubbleTableView reloadData];
            
            [self.messageToReceive setLength:0];
            
            /*
             // Cancel our subscription to the characteristic
             [peripheral setNotifyValue:NO forCharacteristic:characteristic];
             
             // and disconnect from the peripehral
             [self.centralManager cancelPeripheralConnection:peripheral];
             */
        }
        else {
            // Otherwise, just add the data on to what we already have
            [self.messageToReceive appendData:characteristic.value];
        }
        
        // Log it
        NSLog(@"Received: %@", stringFromData);
    }
    else if ([characteristic.UUID isEqual:kPhotoSendingCharacteristicUUID]) {
        NSString *stringFromData = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
        
        // Have we got everything we need?
        if ([stringFromData isEqualToString:@"EOF"]) {
            
            // We have, so show the data,
            self.bubbleTableView.typingBubble = self.currentTypingBubble = NSBubbleTypingTypeNobody;
            UIImage *image = [[UIImage alloc] initWithData:self.photoToReceive];
            
            NSBubbleData *photoBubble = [NSBubbleData dataWithImage:image date:[NSDate dateWithTimeIntervalSinceNow:0] type:BubbleTypeSomeoneElse];
            
            [self.bubbleData addObject:photoBubble];
            [self.bubbleTableView reloadData];
            
            [self.photoToReceive setLength:0];
            
            /*
             // Cancel our subscription to the characteristic
             [peripheral setNotifyValue:NO forCharacteristic:characteristic];
             
             // and disconnect from the peripehral
             [self.centralManager cancelPeripheralConnection:peripheral];
             */
        }
        else {
            // Otherwise, just add the data on to what we already have
            if (self.currentTypingBubble == NSBubbleTypingTypeNobody) {
                self.bubbleTableView.typingBubble = self.currentTypingBubble = NSBubbleTypingTypeSomebody;
                [self.bubbleTableView reloadData];
            }
            [self.photoToReceive appendData:characteristic.value];
        }
        NSLog(@"Received: %@", stringFromData);

    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    NSLog(@"didWriteValueForCharacteristic");
    
    if (error.code == CBATTErrorSuccess) {
        
        if ([characteristic.UUID isEqual:kReceiveMessageMessageCharacteristicUUID]) {
            if (self.isEOM == YES) {
                return;
            }
            
            self.sendMessageIndex += self.lastAmountMessageToSend;
            
            // We're not sending an EOM, so we're sending data
            
            // Is there any left to send?
            
            if (self.isEOM == NO && self.sendMessageIndex >= self.messageToSend.length) {
                self.isEOM = YES;
                // No data left.  Do nothing
                [self.targetPeripheral writeValue:[@"EOM" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:self.sendMessageCharacteristic type:CBCharacteristicWriteWithResponse];
                return;
            }
            
            NSInteger amountToSend = self.messageToSend.length - self.sendMessageIndex;
            
            // Can't be longer than 20 bytes
            if (amountToSend > WRITE_MAX) amountToSend = WRITE_MAX;
            
            self.lastAmountMessageToSend = amountToSend;
            
            // Copy out the data we want
            NSData *chunk = [NSData dataWithBytes:self.messageToSend.bytes+self.sendMessageIndex length:amountToSend];
            
            // Send it
            [self.targetPeripheral writeValue:chunk forCharacteristic:self.sendMessageCharacteristic type:CBCharacteristicWriteWithResponse];
            
            
            NSString *stringFromData = [[NSString alloc] initWithData:chunk encoding:NSUTF8StringEncoding];
            NSLog(@"Sent: %@", stringFromData);
            
            /*
             // Was it the last one?
             if (self.sendMessageIndex >= self.messageToSend.length) {
             
             // It was - send an EOM
             
             // Set this so if the send fails, we'll send it next time
             
             // Send it
             [self.targetPeripheral writeValue:[@"EOM" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:self.sendMessageCharacteristic type:CBCharacteristicWriteWithResponse];
             
             return;
             }
             */
        }
        else if ([characteristic.UUID isEqual:kPhotoReceivingCharacteristicUUID]) {
            if (self.isEOF == YES) {
                return;
            }
            
            self.sendPhotoIndex += self.lastAmountPhotoToSend;
            
            // We're not sending an EOM, so we're sending data
            
            // Is there any left to send?
            
            if (self.isEOF == NO && self.sendPhotoIndex >= self.photoToSend.length) {
                self.isEOF = YES;
                // No data left.  Do nothing
                [self.targetPeripheral writeValue:[@"EOF" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:self.sendPhotoCharacteristic type:CBCharacteristicWriteWithResponse];
                return;
            }
            
            NSInteger amountToSend = self.photoToSend.length - self.sendPhotoIndex;
            
            // Can't be longer than 20 bytes
            if (amountToSend > WRITE_MAX) amountToSend = WRITE_MAX;
            
            self.lastAmountPhotoToSend = amountToSend;
            
            // Copy out the data we want
            NSData *chunk = [NSData dataWithBytes:self.photoToSend.bytes+self.sendPhotoIndex length:amountToSend];
            
            // Send it
            [self.targetPeripheral writeValue:chunk forCharacteristic:self.sendPhotoCharacteristic type:CBCharacteristicWriteWithResponse];
        }
    }
}

- (void)peripheralDidInvalidateServices:(CBPeripheral *)peripheral {
    [self.centralManager cancelPeripheralConnection:peripheral];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil message:@"You are losing the connection" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
    alertView.tag = 10;
    [alertView show];
}

#pragma mark - UITextFieldDelegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self sendMessage:nil];
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - IBAction
- (IBAction)sendMessage:(id)sender {
    if (![self.messageTextField.text isEqualToString:@""]) {
        if (self.messageToSend != nil) {
            self.messageToSend = nil;
        }
        self.messageToSend = [self.messageTextField.text dataUsingEncoding:NSUTF8StringEncoding];
        NSBubbleData *sendBubble = [NSBubbleData dataWithText:self.messageTextField.text date:[NSDate dateWithTimeIntervalSinceNow:0] type:BubbleTypeMine];
        [self.bubbleData addObject:sendBubble];
        [self.bubbleTableView reloadData];
        
        self.messageTextField.text = @"";
        self.sendMessageIndex = 0;
        self.lastAmountPhotoToSend = 0;
        [self handleSendingMessage];
//        [self.view hideKeyboard];
    }
}

- (IBAction)presentPhotoPciker:(id)sender {
    UIActionSheet *photoPickerSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"From Photo Album", @"From Camera", nil];
    
    [photoPickerSheet showInView:self.view];
}

#pragma mark - Handle Send
- (void)sendName {
    NSString *nameString = [NSString stringWithFormat:@"USER_NICK_NAME:%@", [[NSUserDefaults standardUserDefaults] objectForKey:@"USER_NICK_NAME"]];
    self.messageToSend = [nameString dataUsingEncoding:NSUTF8StringEncoding];
    self.sendMessageIndex = 0;
    self.lastAmountPhotoToSend = 0;
    [self handleSendingMessage];
}

- (void)handleSendingMessage {
    
    self.isEOM = NO;
    
    NSLog(@"%@", [[NSString alloc] initWithData:self.messageToSend encoding:NSUTF8StringEncoding]);
    
    
    // Work out how big it should be
    NSInteger amountToSend = self.messageToSend.length;
    
    // Can't be longer than 20 bytes
    if (amountToSend > WRITE_MAX) amountToSend = WRITE_MAX;

    // Copy out the data we want
    NSData *chunk = [NSData dataWithBytes:self.messageToSend.bytes+self.sendMessageIndex length:amountToSend];
    
    // Send it
    [self.targetPeripheral writeValue:chunk forCharacteristic:self.sendMessageCharacteristic type:CBCharacteristicWriteWithResponse];
    
    self.lastAmountMessageToSend = WRITE_MAX;
}

- (void)handleSendingPhoto {
    self.isEOF = NO;
    
    NSLog(@"%@", [[NSString alloc] initWithData:self.photoToSend encoding:NSUTF8StringEncoding]);
    
    
    // Work out how big it should be
    NSInteger amountToSend = self.photoToSend.length;
    
    // Can't be longer than 20 bytes
    if (amountToSend > WRITE_MAX) amountToSend = WRITE_MAX;
    
    // Copy out the data we want
    NSData *chunk = [NSData dataWithBytes:self.photoToSend.bytes+self.sendPhotoIndex length:amountToSend];
    
    // Send it
    [self.targetPeripheral writeValue:chunk forCharacteristic:self.sendPhotoCharacteristic type:CBCharacteristicWriteWithResponse];
    
    self.lastAmountPhotoToSend = WRITE_MAX;
}


#pragma mark - UIBubbleTableViewDataSource implementation

- (NSInteger)rowsForBubbleTable:(UIBubbleTableView *)tableView
{
    return [self.bubbleData count];
}

- (NSBubbleData *)bubbleTableView:(UIBubbleTableView *)tableView dataForRow:(NSInteger)row
{
    return [self.bubbleData objectAtIndex:row];
}

- (void)hideKeyboard:(UITapGestureRecognizer *)gesture {
    [self.view hideKeyboard];
}

#pragma mark - UIActionSheetDelegate
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) {
        if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
            self.isCameraSelected = YES;
            self.pickerCtrl = [[UIImagePickerController alloc] init];
            self.pickerCtrl.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
            self.pickerCtrl.delegate = self;
            [self presentViewController:self.pickerCtrl animated:YES completion:^{}];
        }
        else
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"Photo album is not available on your device." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
            [alert show];
        }
    }
    else if (buttonIndex == 1) {
        if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
            self.isCameraSelected = YES;
            self.pickerCtrl = [[UIImagePickerController alloc] init];
            self.pickerCtrl.sourceType = UIImagePickerControllerSourceTypeCamera;
            self.pickerCtrl.delegate = self;
            [self presentViewController:self.pickerCtrl animated:YES completion:^{}];
        }
        else
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"Camera is not available on your device." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
            [alert show];
        }
    }
}

#pragma mark - UIImagePickerControllerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    [self dismissViewControllerAnimated:YES completion:^{}];
    
    UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];

    NSBubbleData *photoBubble = [NSBubbleData dataWithImage:image date:[NSDate dateWithTimeIntervalSinceNow:0] type:BubbleTypeMine];
    
    [self.bubbleData addObject:photoBubble];
    [self.bubbleTableView reloadData];
    
//    self.photoToSend = [[NSData alloc] initWithData:UIImageJPEGRepresentation(image, 0)];
//    NSLog(@"%d", self.photoToSend.length);
    self.sendPhotoIndex = 0;
    
    CGSize newSize = image.size;
    
    if (newSize.width > 320)
    {
        newSize.height /= (newSize.width / 320);
        newSize.width = 320;
    }
    
    if (newSize.height > 460) {
        newSize.width /= (newSize.height / 460);
        newSize.height = 460;
    }
    
    UIGraphicsBeginImageContext(newSize);
    
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    // Get the new image from the context
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    // End the context
    UIGraphicsEndImageContext();
    
    UIImageView *tempView = [[UIImageView alloc] initWithImage:newImage];
    self.photoToSend = [NSData dataWithData:UIImageJPEGRepresentation(tempView.image, 0)];

    NSLog(@"data:%d", self.photoToSend.length);
    
    [self handleSendingPhoto];
}

#pragma mark - UIAlertViewDelegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 10 && buttonIndex == 0) {
        __weak CentralViewController *weakSelf = self;
        if (self.pickerCtrl) {
            [self dismissViewControllerAnimated:YES completion:^{        [weakSelf.navigationController  popToRootViewControllerAnimated:YES];
            }];
        }
        else {
            [self.navigationController  popToRootViewControllerAnimated:YES];
        }
    }
}

#pragma mark - SBTableAlertDataSource
- (UITableViewCell *)tableAlert:(SBTableAlert *)tableAlert cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"cellForRowAtIndexPath");

    UITableViewCell *cell = [[SBTableAlertCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    
    NSMutableArray *peripheralsArray = [[NSMutableArray alloc] init];
    for (NSDictionary *peripheralObject in [self.peripherals allValues]) {
        if (![peripheralsArray containsObject:[peripheralObject objectForKey:@"pKey"]]) {
            [peripheralsArray addObject:[peripheralObject objectForKey:@"pKey"]];
        }
    }
    
    if ([peripheralsArray count] > indexPath.row) {
        cell.userInteractionEnabled = YES;
        NSLog(@"%@", [[[self.peripherals allKeys] objectAtIndex:indexPath.row] objectForKey:CBAdvertisementDataLocalNameKey]);
        NSString *deviceName = nil;
        if ([[[[self.peripherals allKeys] objectAtIndex:indexPath.row] objectForKey:CBAdvertisementDataLocalNameKey] length] == 0) {
            deviceName = @"Unknown";
        }
        else {
            deviceName = [[[self.peripherals allKeys] objectAtIndex:indexPath.row] objectForKey:CBAdvertisementDataLocalNameKey];
        }
        
        cell.textLabel.text = deviceName;
    }
    else {
        cell.userInteractionEnabled = NO;
    }
	
	return cell;
}

- (NSInteger)tableAlert:(SBTableAlert *)tableAlert numberOfRowsInSection:(NSInteger)section {
    if ([self.peripherals count] < 3) {
        return 3;
    }
    return [self.peripherals count];
}

- (NSInteger)numberOfSectionsInTableAlert:(SBTableAlert *)tableAlert {
    return 1;
}

- (NSString *)tableAlert:(SBTableAlert *)tableAlert titleForHeaderInSection:(NSInteger)section {
    return nil;
}

#pragma mark - SBTableAlertDelegate
- (void)tableAlert:(SBTableAlert *)tableAlert didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSMutableArray *peripheralsArray = [[NSMutableArray alloc] init];
    for (NSDictionary *peripheralObject in [self.peripherals allValues]) {
        [peripheralsArray addObject:[peripheralObject objectForKey:@"pKey"]];
    }
    // Save a local copy of the peripheral, so CoreBluetooth doesn't get rid of it
    if ([peripheralsArray objectAtIndex:indexPath.row] != nil) {
        self.targetPeripheral = [peripheralsArray objectAtIndex:indexPath.row];
        
        // And connect
        NSLog(@"Connecting to peripheral %@", self.targetPeripheral);
        [self.centralManager connectPeripheral:self.targetPeripheral options:nil];
    }
}

- (void)tableAlert:(SBTableAlert *)tableAlert didDismissWithButtonIndex:(NSInteger)buttonIndex {
    NSLog(@"dismiss");
    tableAlert = nil;
}

@end
