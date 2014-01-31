//
//  PeripheralViewController.m
//  BluetoothSharingApp
//
//  Created by ZZB on 13/2/10.
//  Copyright (c) 2013年 ZZB. All rights reserved.
//

#import "PeripheralViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>

#import "AppConstant.h"
#import "UIBubbleTableViewDataSource.h"
#import "UIBubbleTableView.h"
#import "UIBubbleTableViewDataSource.h"
#import "NSBubbleData.h"
#import "DAKeyboardControl.h"


@interface PeripheralViewController ()<CBPeripheralManagerDelegate, UITextFieldDelegate, UIBubbleTableViewDataSource, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIActionSheetDelegate, UIAlertViewDelegate> {
}

@property (nonatomic, assign) BOOL alertViewShowing;
@property (nonatomic, assign) BOOL isCameraSelected;
@property (nonatomic, assign) NSBubbleTypingType currentTypingBubble;
@property (weak, nonatomic) IBOutlet UITextField *messageTextField;
@property (strong, nonatomic) CBPeripheralManager *peripheralManager;
@property (strong, nonatomic) CBMutableCharacteristic *sendMessageCharacteristic;
@property (strong, nonatomic) CBMutableCharacteristic *receiveMessageCharacteristic;
@property (strong, nonatomic) CBMutableCharacteristic *photoSendingCharacteristic;
@property (strong, nonatomic) CBMutableCharacteristic *photoReceivingCharacteristic;
@property (strong, nonatomic) NSData *messageToSend;
@property (strong, nonatomic) NSMutableData *messageToReceive;
@property (strong, nonatomic) NSData *photoToSend;
@property (strong, nonatomic) NSMutableData *photoToReceive;
@property (nonatomic, readwrite) NSInteger sendMessageIndex;
@property (nonatomic, readwrite) NSInteger sendPhotoIndex;
@property (nonatomic, weak) IBOutlet UIBubbleTableView *bubbleTableView;
@property (nonatomic, strong) NSMutableArray *bubbleData;
@property (nonatomic, weak) IBOutlet UIToolbar *messageToolbar;
@property (nonatomic, weak) IBOutlet UIButton *sendMessageButton;
@property (nonatomic, weak) IBOutlet UIView *loadingView;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *photoButton;
@property (nonatomic, strong) UIImagePickerController *pickerCtrl;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *toolbarBottomSpaceContraint;

- (IBAction)sendMessage:(id)sender;
- (void)handleSendingMessage;
- (void)hideKeyboard:(UITapGestureRecognizer *)gesture;
- (IBAction)presentPhotoPciker:(id)sender;
- (void)handleSendingPhoto;

@end

@implementation PeripheralViewController

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
    self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
    self.messageToReceive = [[NSMutableData alloc] init];
    self.photoToReceive = [[NSMutableData alloc] init];
    self.bubbleData = [[NSMutableArray alloc] init];
    
    // The line below sets the snap interval in seconds. This defines how the bubbles will be grouped in time.
    // Interval of 120 means that if the next messages comes in 2 minutes since the last message, it will be added into the same group.
    // Groups are delimited with header which contains date and time for the first message in the group.
    self.bubbleTableView.snapInterval = kChatRefreshTime;
    self.bubbleTableView.showAvatars = NO;
    
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideKeyboard:)];
    [self.bubbleTableView addGestureRecognizer:singleTap];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    self.view.keyboardTriggerOffset = self.messageToolbar.bounds.size.height;
    self.isCameraSelected = NO;
    __weak PeripheralViewController *weakSelf = self;
    
    [self.view addKeyboardPanningWithActionHandler:^(CGRect keyboardFrameInView) {
        
        weakSelf.toolbarBottomSpaceContraint.constant = weakSelf.view.frame.size.height - keyboardFrameInView.origin.y;
        [weakSelf.bubbleTableView layoutIfNeeded];
    }];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (!self.isCameraSelected) {
        [self.peripheralManager removeAllServices];
    }
    [self.view removeKeyboardControl];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - CBPeripheralManagerDelegate

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
    if (peripheral.state == CBPeripheralManagerStateUnsupported) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil message:@"Your device hardware or iOS version doesn't support bluetooth 4.0." delegate:self cancelButtonTitle:@"" otherButtonTitles:nil];
        alertView.tag = 10;
        [alertView show];
    }
    if (peripheral.state != CBCentralManagerStatePoweredOn) {
        // In a real app, you'd deal with all the states correctly
        return;
    }
    
    [self.loadingView setHidden:NO];
    [self.photoButton setEnabled:NO];
    
    self.sendMessageCharacteristic = [[CBMutableCharacteristic alloc]
                               initWithType:kSendMessageCharacteristicUUID
                               properties:CBCharacteristicPropertyNotify                                                                          value:nil                                                                    permissions:CBAttributePermissionsReadable];
    
    self.receiveMessageCharacteristic = [[CBMutableCharacteristic alloc]
                                         initWithType:kReceiveMessageMessageCharacteristicUUID
                                         properties:CBCharacteristicPropertyWrite                                                                         value:nil                                                                    permissions:CBAttributePermissionsWriteable];
    
    self.photoSendingCharacteristic = [[CBMutableCharacteristic alloc]
                                       initWithType:kPhotoSendingCharacteristicUUID
                                       properties:CBCharacteristicPropertyNotify                                                                          value:nil                                                                    permissions:CBAttributePermissionsReadable];
    
    self.photoReceivingCharacteristic = [[CBMutableCharacteristic alloc]
                                       initWithType:kPhotoReceivingCharacteristicUUID
                                       properties:CBCharacteristicPropertyWrite                                                                          value:nil                                                                    permissions:CBAttributePermissionsWriteable];
    // Then the service
    CBMutableService *mService = [[CBMutableService alloc]
                                  initWithType:kAppServiceUUID
                                    primary:YES];
    
    // Add the characteristic to the service
    mService.characteristics = @[self.sendMessageCharacteristic, self.receiveMessageCharacteristic, self.photoReceivingCharacteristic, self.photoSendingCharacteristic];
    
    // And add it to the peripheral manager
    [self.peripheralManager addService:mService];
    
    [self.peripheralManager startAdvertising:@{ CBAdvertisementDataServiceUUIDsKey:@[kAppServiceUUID]
     , CBAdvertisementDataLocalNameKey:[[NSUserDefaults standardUserDefaults] objectForKey:@"USER_NICK_NAME"]}];
    
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic {
    if ([characteristic.UUID isEqual:kSendMessageCharacteristicUUID]) {
        NSLog(@"didSubscribeToCharacteristic Send Message");
    }
    else if ([characteristic.UUID isEqual:kReceiveMessageMessageCharacteristicUUID]) {
        NSLog(@"didSubscribeToCharacteristic Receive Message");
    }
    else if ([characteristic.UUID isEqual:kPhotoSendingCharacteristicUUID]) {
        NSLog(@"didSubscribeToCharacteristic Photo send");
    }
    else if ([characteristic.UUID isEqual:kPhotoReceivingCharacteristicUUID]) {
        NSLog(@"didSubscribeToCharacteristic Photo receive");
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic {
    NSLog(@"Central unsubscribed from characteristic");

    if (self.alertViewShowing == NO) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil message:@"You are losing the connection" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        alertView.tag = 10;
        [alertView show];
    }
    self.alertViewShowing = YES;
}

- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral {
    [self handleSendingMessage];
    [self handleSendingPhoto];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray *)requests {
    for (CBATTRequest *request in requests) {
        if ([request.characteristic.UUID isEqual:kReceiveMessageMessageCharacteristicUUID]) {
            NSString *stringFromData = [[NSString alloc] initWithData:request.value encoding:NSUTF8StringEncoding];
            
            // Have we got everything we need?
            if ([stringFromData isEqualToString:@"EOM"]) {
                
                // We have, so show the data,
                /*
                self.chatTextView.text = [self.chatTextView.text  stringByAppendingFormat:@"\n%@", [[NSString alloc] initWithData:self.messageToReceive encoding:NSUTF8StringEncoding]];
                 */
                
                NSString *message = [[NSString alloc] initWithData:self.messageToReceive encoding:NSUTF8StringEncoding];
                if ([message rangeOfString:@"USER_NICK_NAME"].location != NSNotFound) {
                    NSArray *nameArray = [message componentsSeparatedByString:@":"];
                    if ([nameArray objectAtIndex:1] != nil) {
                        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil message:[NSString stringWithFormat:@"%@ is connected with you.", [nameArray objectAtIndex:1]] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                        [alertView show];
                        [self.loadingView setHidden:YES];
                        [self.photoButton setEnabled:YES];
                    }
                }
                else {
                    NSBubbleData *sendBubble = [NSBubbleData dataWithText:message date:[NSDate dateWithTimeIntervalSinceNow:0] type:BubbleTypeSomeoneElse];
                    [self.bubbleData addObject:sendBubble];
                    [self.bubbleTableView reloadData];
                }
                
                [self.messageToReceive setLength:0];            
            }
            else {
            // Otherwise, just add the data on to what we already have
                [self.messageToReceive appendData:request.value];
            }
            
            // Log it
            NSLog(@"Received: %@", stringFromData);
            [self.peripheralManager respondToRequest:request withResult:CBATTErrorSuccess];
        }
        else if ([request.characteristic.UUID isEqual:kPhotoReceivingCharacteristicUUID]) {
            NSString *stringFromData = [[NSString alloc] initWithData:request.value encoding:NSUTF8StringEncoding];
            
            // Have we got everything we need?
            if ([stringFromData isEqualToString:@"EOF"]) {
                self.bubbleTableView.typingBubble = self.currentTypingBubble = NSBubbleTypingTypeNobody;
                // We have, so show the data,
                UIImage *image = [[UIImage alloc] initWithData:self.photoToReceive];
                NSBubbleData *sendBubble = [NSBubbleData dataWithImage:image date:[NSDate dateWithTimeIntervalSinceNow:0] type:BubbleTypeSomeoneElse];
                [self.bubbleData addObject:sendBubble];
                [self.bubbleTableView reloadData];
                [self.photoToReceive setLength:0];
            }
            else {
                if (self.currentTypingBubble == NSBubbleTypingTypeNobody) {
                    self.bubbleTableView.typingBubble = self.currentTypingBubble = NSBubbleTypingTypeSomebody;
                    [self.bubbleTableView reloadData];
                }
                // Otherwise, just add the data on to what we already have
                [self.photoToReceive appendData:request.value];
            }
            
            // Log it
            NSLog(@"Received: %@", stringFromData);
            [self.peripheralManager respondToRequest:request withResult:CBATTErrorSuccess];
        }
    }
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
        [self handleSendingMessage];
//        [self.view hideKeyboard];
    }
}

- (void)hideKeyboard:(UITapGestureRecognizer *)gesture {
    [self.view hideKeyboard];
}

- (IBAction)presentPhotoPciker:(id)sender {
    UIActionSheet *photoPickerSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"From Photo Album", @"From Camera", nil];
    
    [photoPickerSheet showInView:self.view];
}

#pragma mark - Handle Send
- (void)handleSendingMessage {
    // First up, check if we're meant to be sending an EOM
    static BOOL sendingEOM = NO;
    
    if (sendingEOM) {
        
        // send it
        BOOL didSend = [self.peripheralManager updateValue:[@"EOM" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:self.sendMessageCharacteristic onSubscribedCentrals:nil];
        
        // Did it send?
        if (didSend) {
            
            // It did, so mark it as sent
            sendingEOM = NO;
            
            NSLog(@"Sent: EOM");
        }
        
        // It didn't send, so we'll exit and wait for peripheralManagerIsReadyToUpdateSubscribers to call sendData again
        return;
    }
    
    // We're not sending an EOM, so we're sending data
    
    // Is there any left to send?
    
    if (self.sendMessageIndex >= self.messageToSend.length) {
        
        // No data left.  Do nothing
        return;
    }
    
    // There's data left, so send until the callback fails, or we're done.
    
    BOOL didSend = YES;
    
    while (didSend) {
        
        // Make the next chunk
        
        // Work out how big it should be
        NSInteger amountToSend = self.messageToSend.length - self.sendMessageIndex;
        
        // Can't be longer than 20 bytes
        if (amountToSend > NOTIFY_MTU) amountToSend = NOTIFY_MTU;
        
        // Copy out the data we want
        NSData *chunk = [NSData dataWithBytes:self.messageToSend.bytes+self.sendMessageIndex length:amountToSend];
        
        // Send it
        didSend = [self.peripheralManager updateValue:chunk forCharacteristic:self.sendMessageCharacteristic onSubscribedCentrals:nil];
        
        // If it didn't work, drop out and wait for the callback
        if (!didSend) {
            return;
        }
        
        NSString *stringFromData = [[NSString alloc] initWithData:chunk encoding:NSUTF8StringEncoding];
        NSLog(@"Sent: %@", stringFromData);
        
        // It did send, so update our index
        self.sendMessageIndex += amountToSend;
        
        // Was it the last one?
        if (self.sendMessageIndex >= self.messageToSend.length) {
            
            // It was - send an EOM
            
            // Set this so if the send fails, we'll send it next time
            sendingEOM = YES;
            
            // Send it
            BOOL eomSent = [self.peripheralManager updateValue:[@"EOM" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:self.sendMessageCharacteristic onSubscribedCentrals:nil];
            
            if (eomSent) {
                // It sent, we're all done
                sendingEOM = NO;
                
                NSLog(@"Sent: EOM");
            }
            
            return;
        }
    }
}

- (void)handleSendingPhoto {
    // First up, check if we're meant to be sending an EOM
    static BOOL sendingEOF = NO;
    
    if (sendingEOF) {
        
        // send it
        BOOL didSend = [self.peripheralManager updateValue:[@"EOF" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:self.photoSendingCharacteristic onSubscribedCentrals:nil];
        
        // Did it send?
        if (didSend) {
            
            // It did, so mark it as sent
            sendingEOF = NO;
            
            NSLog(@"Sent: EOF");
        }
        
        // It didn't send, so we'll exit and wait for peripheralManagerIsReadyToUpdateSubscribers to call sendData again
        return;
    }
    
    // We're not sending an EOF, so we're sending data
    
    // Is there any left to send?
    
    if (self.sendPhotoIndex >= self.photoToSend.length) {
        
        // No data left.  Do nothing
        return;
    }
    
    // There's data left, so send until the callback fails, or we're done.
    
    BOOL didSend = YES;
    
    while (didSend) {
        
        // Make the next chunk
        
        // Work out how big it should be
        NSInteger amountToSend = self.photoToSend.length - self.sendPhotoIndex;
        NSLog(@"%d", self.photoToSend.length);
        // Can't be longer than 20 bytes
        if (amountToSend > NOTIFY_MTU) amountToSend = NOTIFY_MTU;
        
        // Copy out the data we want
        NSData *chunk = [NSData dataWithBytes:self.photoToSend.bytes+self.sendPhotoIndex length:amountToSend];
        
        // Send it
        didSend = [self.peripheralManager updateValue:chunk forCharacteristic:self.photoSendingCharacteristic onSubscribedCentrals:nil];
        
        // If it didn't work, drop out and wait for the callback
        if (!didSend) {
            return;
        }
        
        NSString *stringFromData = [[NSString alloc] initWithData:chunk encoding:NSUTF8StringEncoding];
        NSLog(@"Sent: %@ %d", stringFromData, chunk.length);
        
        // It did send, so update our index
        self.sendPhotoIndex += amountToSend;
        
        // Was it the last one?
        if (self.sendPhotoIndex >= self.photoToSend.length) {
            
            // It was - send an EOM
            
            // Set this so if the send fails, we'll send it next time
            sendingEOF = YES;
            
            // Send it
            BOOL eofSent = [self.peripheralManager updateValue:[@"EOF" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:self.photoSendingCharacteristic onSubscribedCentrals:nil];
            
            if (eofSent) {
                // It sent, we're all done
                sendingEOF = NO;
                
                NSLog(@"Sent: EOF");
            }
            
            return;
        }
    }

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
    __weak PeripheralViewController *weakSelf = self;
    [self dismissViewControllerAnimated:YES completion:^{
        UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
        
        NSBubbleData *photoBubble = [NSBubbleData dataWithImage:image date:[NSDate dateWithTimeIntervalSinceNow:0] type:BubbleTypeMine];
        
        [weakSelf.bubbleData addObject:photoBubble];
        [weakSelf.bubbleTableView reloadData];
        
        weakSelf.sendPhotoIndex = 0;
        
        CGSize newSize = image.size;
        
        if (newSize.width > 320.0f)
        {
            newSize.height /= (newSize.width / 320.0f);
            newSize.width = 320.0f;
        }
        
        if (newSize.height > 460.0f) {
            newSize.width /= (newSize.height / 460.0f);
            newSize.height = 460.0f;
        }
        
        UIGraphicsBeginImageContext(newSize);
        
        [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
        // Get the new image from the context
        UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
        // End the context
        UIGraphicsEndImageContext();
        
        UIImageView *tempView = [[UIImageView alloc] initWithImage:newImage];
        weakSelf.photoToSend = [NSData dataWithData:UIImageJPEGRepresentation(tempView.image, 0)];
        
        [weakSelf handleSendingPhoto];
    }];
}

#pragma mark - UIAlertViewDelegate
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 10 && buttonIndex == 0) {
        __weak PeripheralViewController *weakSelf = self;
        if (self.pickerCtrl) {
            [self dismissViewControllerAnimated:YES completion:^{
                [weakSelf.navigationController  popToRootViewControllerAnimated:YES];
            }];
        }
        else {
            [self.navigationController popViewControllerAnimated:YES];
        }

    }
    self.alertViewShowing = NO;
}


@end
