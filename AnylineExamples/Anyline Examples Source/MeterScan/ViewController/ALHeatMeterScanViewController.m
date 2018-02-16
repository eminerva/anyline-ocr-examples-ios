//
//  ALElectric7MeterScanViewController.m
//  AnylineExamples
//
//  Created by Daniel Albertini on 01/12/15.
//  Copyright © 2015 9yards GmbH. All rights reserved.
//

#import "ALHeatMeterScanViewController.h"
#import "ALMeterScanResultViewController.h"
#import <Anyline/Anyline.h>
#import "ALMeterSelectView.h"
#import "NSUserDefaults+ALExamplesAdditions.h"
#import "ALAppDemoLicenses.h"

// This is the license key for the examples project used to set up Aynline below
NSString * const kHeatMeterScanLicenseKey = kDemoAppLicenseKey;

static const NSInteger padding = 7;

// The controller has to conform to <AnylineEnergyModuleDelegate> to be able to receive results
@interface ALHeatMeterScanViewController ()<AnylineEnergyModuleDelegate,ALMeterSelectViewDelegate, AnylineNativeBarcodeDelegate>

// The Anyline module used to scan
@property (nonatomic, strong) AnylineEnergyModuleView *anylineEnergyView;
// A widget used to choose between meter types
@property (nonatomic, strong) ALMeterSelectView *meterTypeSegment;



//Native barcode scanning properties
@property (nonatomic, strong) NSString *barcodeResult;

@property (nonatomic, strong) UIView *enableBarcodeView;
@property (nonatomic, strong) UISwitch *enableBarcodeSwitch;
@property (nonatomic, strong) UILabel *enableBarcodeLabel;

@end

@implementation ALHeatMeterScanViewController

/*
 We will do our main setup in viewDidLoad. Its called once the view controller is getting ready to be displayed.
 */
- (void)viewDidLoad {
    [super viewDidLoad];
    // Set the background color to black to have a nicer transition
    self.view.backgroundColor = [UIColor blackColor];
    
    self.title = @"Heat Meter";
    // Initializing the energy module. Its a UIView subclass. We set its frame to fill the whole screen
    CGRect frame = [[UIScreen mainScreen] applicationFrame];
    frame = CGRectMake(frame.origin.x, frame.origin.y + self.navigationController.navigationBar.frame.size.height, frame.size.width, frame.size.height - self.navigationController.navigationBar.frame.size.height);
    self.anylineEnergyView = [[AnylineEnergyModuleView alloc] initWithFrame:frame];
    
    NSError *error = nil;
    // We tell the module to bootstrap itself with the license key and delegate. The delegate will later get called
    // once we start receiving results.
    BOOL success = [self.anylineEnergyView setupWithLicenseKey:kHeatMeterScanLicenseKey delegate:self error:&error];
    
    // setupWithLicenseKey:delegate:error returns true if everything went fine. In the case something wrong
    // we have to check the error object for the error message.
    if( !success ) {
        // Something went wrong. The error object contains the error description
        [[[UIAlertView alloc] initWithTitle:@"Setup Error"
                                    message:error.debugDescription
                                   delegate:self
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil] show];
    }
    
    success = [self.anylineEnergyView setScanMode:ALHeatMeter5 error:&error];
    
    if( !success ) {
        // Something went wrong. The error object contains the error description
        [[[UIAlertView alloc] initWithTitle:@"SetScanMode Error"
                                    message:error.debugDescription
                                   delegate:self
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil] show];
    }
    
    self.anylineEnergyView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // After setup is complete we add the module to the view of this view controller
    [self.view addSubview:self.anylineEnergyView];
    [self.view sendSubviewToBack:self.anylineEnergyView];
    
    [[self view] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[moduleView]|" options:0 metrics:nil views:@{@"moduleView" : self.anylineEnergyView}]];
    
    id topGuide = self.topLayoutGuide;
    [[self view] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[topGuide]-0-[moduleView]|" options:0 metrics:nil views:@{@"moduleView" : self.anylineEnergyView, @"topGuide" : topGuide}]];
    
    
    
    [self.anylineEnergyView enableReporting:[NSUserDefaults AL_reportingEnabled]];
    
    self.controllerType = ALScanHistoryHeatMeter;
    
    
    // This widget is used to choose between meter types
    self.meterTypeSegment = [[ALMeterSelectView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 50) maxDigits:6 minDigits:4 startDigits:5];
    self.meterTypeSegment.center = CGPointMake(self.view.center.x, self.view.frame.size.height - 50 - 44 - 45);
    
    self.meterTypeSegment.delegate = self;
    
    [self.view addSubview:self.meterTypeSegment];
    
    //set delegate for nativeBarcodeScanning => simultaneus barcode scanning
//    [self.anylineEnergyView.videoView setBarcodeDelegate:self];
    self.barcodeResult = @"";
    [self.anylineEnergyView addSubview:[self createBarcoeSwitchView]];
}

- (void)viewDidLayoutSubviews {
    
    [self updateWarningPosition:
     self.anylineEnergyView.cutoutRect.origin.y +
     self.anylineEnergyView.cutoutRect.size.height +
     self.anylineEnergyView.frame.origin.y +
     90];
    
    [self updateLayoutBarcodeSwitchView];
}

/*
 This method will be called once the view controller and its subviews have appeared on screen
 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    /*
     This is the place where we tell Anyline to start receiving and displaying images from the camera.
     Success/error tells us if everything went fine.
     */
    NSError *error = nil;
    BOOL success = [self.anylineEnergyView startScanningAndReturnError:&error];
    if( !success ) {
        // Something went wrong. The error object contains the error description
        [[[UIAlertView alloc] initWithTitle:@"Start Scanning Error"
                                    message:error.debugDescription
                                   delegate:self
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil] show];
    }
}

/*
 Cancel scanning to allow the module to clean up
 */
- (void)viewWillDisappear:(BOOL)animated {
    [self.anylineEnergyView cancelScanningAndReturnError:nil];
}

/*
 If the user changes the meter type with the segment control we will tell Anyline it should
 change its scanMode.
 */
- (IBAction)meterCountChanged:(NSInteger)newCount {
    BOOL success = YES;
    NSError *error = nil;
    
    switch (newCount) {
        case 4:
            success = [self.anylineEnergyView setScanMode:ALHeatMeter4 error:&error];
            break;
        case 5:
            success = [self.anylineEnergyView setScanMode:ALHeatMeter5 error:&error];
            break;
        case 6:
        default:
            success = [self.anylineEnergyView setScanMode:ALHeatMeter6 error:&error];
            break;
    }
    
    if( !success ) {
        // Something went wrong. The error object contains the error description
        [[[UIAlertView alloc] initWithTitle:@"ChangeScanMode Error"
                                    message:error.debugDescription
                                   delegate:self
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil] show];
    }
}
- (IBAction)toggleBarcodeScanning:(id)sender {
    
    if (self.anylineEnergyView.captureDeviceManager.barcodeDelegate) {
        self.enableBarcodeSwitch.on = false;
        [self.anylineEnergyView.captureDeviceManager setBarcodeDelegate:nil];
        //reset found barcode
        self.barcodeResult = @"";
    } else {
        self.enableBarcodeSwitch.on = true;
        [self.anylineEnergyView.captureDeviceManager setBarcodeDelegate:self];
    }
}

#pragma mark - Barcode View layouting
- (UIView *)createBarcoeSwitchView {
    //Add UISwitch for toggling barcode scanning
    self.enableBarcodeView = [[UIView alloc] init];
    self.enableBarcodeView.frame = CGRectMake(0, 0, 150, 50);
    
    self.enableBarcodeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 100, 30)];
    self.enableBarcodeLabel.text = @"Barcode Detection";
    UIFont *font = [UIFont systemFontOfSize:14 weight:UIFontWeightThin];
    self.enableBarcodeLabel.font = font;
    self.enableBarcodeLabel.numberOfLines = 0;
    
    self.enableBarcodeLabel.textColor = [UIColor whiteColor];
    [self.enableBarcodeLabel sizeToFit];
    
    self.enableBarcodeSwitch = [[UISwitch alloc] init];
    [self.enableBarcodeSwitch setOn:false];
    self.enableBarcodeSwitch.onTintColor = [UIColor whiteColor];
    [self.enableBarcodeSwitch setOnTintColor:[UIColor colorWithRed:0.0/255.0 green:153.0/255.0 blue:255.0/255.0 alpha:1.0]];
    [self.enableBarcodeSwitch addTarget:self action:@selector(toggleBarcodeScanning:) forControlEvents:UIControlEventValueChanged];
    
    [self.enableBarcodeView addSubview:self.enableBarcodeLabel];
    [self.enableBarcodeView addSubview:self.enableBarcodeSwitch];
    
    return self.enableBarcodeView;
}

- (void)updateLayoutBarcodeSwitchView {
    self.enableBarcodeLabel.center = CGPointMake(self.enableBarcodeLabel.frame.size.width/2,
                                                 self.enableBarcodeView.frame.size.height/2);
    
    self.enableBarcodeSwitch.center = CGPointMake(self.enableBarcodeLabel.frame.size.width + self.enableBarcodeSwitch.frame.size.width/2 + padding,
                                                  self.enableBarcodeView.frame.size.height/2);
    
//    CGFloat posY = self.meterTypeSegment.frame.origin.y-self.enableBarcodeView.frame.size.height-55;
    CGFloat posY = self.anylineEnergyView.frame.size.height-self.enableBarcodeView.frame.size.height-55;
    CGFloat width = self.enableBarcodeSwitch.frame.size.width + padding + self.enableBarcodeLabel.frame.size.width;
    self.enableBarcodeView.frame = CGRectMake(self.anylineEnergyView.frame.size.width-width-15,
                                              posY,
                                              width,
                                              50);
}

#pragma mark - AnylineNativeBarcodeDelegate methods
/*
 An additional delegate which will add all found, and unique, barcodes to a Dictionary simultaneously.
 */
- (void)anylineCaptureDeviceManager:(ALCaptureDeviceManager *)captureDeviceManager didFindBarcodeResult:(NSString *)scanResult type:(NSString *)barcodeType {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([scanResult length] > 0 && ![self.barcodeResult isEqualToString:scanResult]) {
            self.barcodeResult = scanResult;
        }
    });
}

#pragma mark - AnylineControllerDelegate methods
/*
 The main delegate method Anyline uses to report its scanned codes
 */

- (void)anylineEnergyModuleView:(AnylineEnergyModuleView *)anylineEnergyModuleView
                  didFindResult:(ALEnergyResult *)scanResult {
    
    [self anylineDidFindResult:scanResult.result barcodeResult:self.barcodeResult image:(UIImage*)scanResult.image module:anylineEnergyModuleView completion:^{
        ALMeterScanResultViewController *vc = [[ALMeterScanResultViewController alloc] init];
        /*
         To present the scanned result to the user we use a custom view controller.
         */
        vc.scanMode = scanResult.scanMode;
        vc.meterImage = scanResult.image;
        vc.result = scanResult.result;
        vc.barcodeResult = self.barcodeResult;
        
        [self.navigationController pushViewController:vc animated:YES];
    }];
    self.barcodeResult = @"";
}

- (NSString *)addon {
//    return [NSString stringWithFormat:@"(%li pre-decimal)",(long)self.meterTypeSegment.digitCount];
    return [NSString stringWithFormat:@"%li",(long)self.meterTypeSegment.digitCount];
}

#pragma mark - ALMeterSelectViewDelegate

- (void)meterSelectView:(ALMeterSelectView *)meterSelectView didChangeDigitCount:(NSInteger)digitCount {
    [self meterCountChanged:digitCount];
}

@end
