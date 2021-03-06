//
//  ALLicensePlateViewController.m
//  AnylineExamples
//
//  Created by Matthias Gasser on 04/02/16.
//  Copyright © 2016 9yards GmbH. All rights reserved.
//

#import "ALLicensePlateATViewController.h"
#import <Anyline/Anyline.h>
#import "ALResultOverlayView.h"
#import "ALIntroHelpView.h"
#import "NSUserDefaults+ALExamplesAdditions.h"
#import "ALLicensePlateResultOverlayView.h"
#import "ALAppDemoLicenses.h"


// This is the license key for the examples project used to set up Aynline below
NSString * const kLicensePlateLicenseKeyAT = kDemoAppLicenseKey;
// The controller has to conform to <AnylineOCRModuleDelegate> to be able to receive results
@interface ALLicensePlateATViewController ()<AnylineOCRModuleDelegate,ALIntroHelpViewDelegate, AnylineDebugDelegate>
// The Anyline module used for OCR
@property (nonatomic, strong) AnylineOCRModuleView *ocrModuleView;

@end

@implementation ALLicensePlateATViewController
/*
 We will do our main setup in viewDidLoad. Its called once the view controller is getting ready to be displayed.
 */
- (void)viewDidLoad {
    [super viewDidLoad];
    // Set the background color to black to have a nicer transition
    self.view.backgroundColor = [UIColor blackColor];
    self.title = @"License Plates AT";
    
    // Initializing the module. Its a UIView subclass. We set the frame to fill the whole screen
    CGRect frame = [[UIScreen mainScreen] applicationFrame];
    frame = CGRectMake(frame.origin.x, frame.origin.y + self.navigationController.navigationBar.frame.size.height, frame.size.width, frame.size.height - self.navigationController.navigationBar.frame.size.height);
    self.ocrModuleView = [[AnylineOCRModuleView alloc] initWithFrame:frame];
    
    ALOCRConfig *config = [[ALOCRConfig alloc] init];
    
    config.customCmdFilePath = [[NSBundle mainBundle] pathForResource:@"license_plates_a" ofType:@"ale"];
    
    NSError *error = nil;
    // We tell the module to bootstrap itself with the license key and delegate. The delegate will later get called
    // by the module once we start receiving results.
    BOOL success = [self.ocrModuleView setupWithLicenseKey:kLicensePlateLicenseKeyAT
                                                  delegate:self
                                                 ocrConfig:config
                                                     error:&error];
    // setupWithLicenseKey:delegate:error returns true if everything went fine. In the case something wrong
    // we have to check the error object for the error message.
    if (!success) {
        // Something went wrong. The error object contains the error description
        NSAssert(success, @"Setup Error: %@", error.debugDescription);
    }
    
    error = nil;
    success = [self.ocrModuleView copyTrainedData:[[NSBundle mainBundle] pathForResource:@"Alte" ofType:@"traineddata"]
                                         fileHash:@"f52e3822cdd5423758ba19ed75b0cc32"
                                            error:&error];
    if (!success) {
        // Something went wrong. The error object contains the error description
        NSAssert(success, @"Copy Traineddata Error: %@", error.debugDescription);
    }
    
    error = nil;
    success = [self.ocrModuleView copyTrainedData:[[NSBundle mainBundle] pathForResource:@"Arial" ofType:@"traineddata"]
                                         fileHash:@"9a5555eb6ac51c83cbb76d238028c485"
                                            error:&error];
    if (!success) {
        // Something went wrong. The error object contains the error description
        NSAssert(success, @"Copy Traineddata Error: %@", error.debugDescription);
    }
    
    error = nil;
    success = [self.ocrModuleView copyTrainedData:[[NSBundle mainBundle] pathForResource:@"GL-Nummernschild-Mtl7_uml" ofType:@"traineddata"]
                                         fileHash:@"8ea050e8f22ba7471df7e18c310430d8"
                                            error:&error];
    if (!success) {
        // Something went wrong. The error object contains the error description
        NSAssert(success, @"Copy Traineddata Error: %@", error.debugDescription);
    }
    
    NSString *confPath = [[NSBundle mainBundle] pathForResource:@"license_plate_view_config" ofType:@"json"];
    ALUIConfiguration *ibanConf = [ALUIConfiguration cutoutConfigurationFromJsonFile:confPath];
    self.ocrModuleView.currentConfiguration = ibanConf;
    
    [self.ocrModuleView enableReporting:[NSUserDefaults AL_reportingEnabled]];
    self.controllerType = ALScanHistoryLicensePlatesAT;
    
    // After setup is complete we add the scanView to the view of this view controller
    [self.view addSubview:self.ocrModuleView];
    [self.view sendSubviewToBack:self.ocrModuleView];
    [self startListeningForMotion];
}

/*
 This method will be called once the view controller and its subviews have appeared on screen
 */
-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // We use this subroutine to start Anyline. The reason it has its own subroutine is
    // so that we can later use it to restart the scanning process.
    [self startAnyline];
    BOOL wasHelpNotShown = [NSUserDefaults AL_createEntryOnce:NSStringFromClass([self class])];
    if(wasHelpNotShown) {
        [self helpPressed:nil];
    }
}

- (void)viewDidLayoutSubviews {
    [self updateWarningPosition:
     self.ocrModuleView.cutoutRect.origin.y +
     self.ocrModuleView.cutoutRect.size.height +
     self.ocrModuleView.frame.origin.y +
     90];
}

/*
 Cancel scanning to allow the module to clean up
 */
- (void)viewWillDisappear:(BOOL)animated {
    [self.ocrModuleView cancelScanningAndReturnError:nil];
}

/*
 This method is used to tell Anyline to start scanning. It gets called in
 viewDidAppear to start scanning the moment the view appears. Once a result
 is found scanning will stop automatically (you can change this behaviour
 with cancelOnResult:). When the user dismisses self.identificationView this
 method will get called again.
 */
- (void)startAnyline {
    NSError *error;
    BOOL success = [self.ocrModuleView startScanningAndReturnError:&error];
    if( !success ) {
        // Something went wrong. The error object contains the error description
        NSAssert(success, @"Start Scanning Error: %@", error.debugDescription);
    }
    
    self.startTime = CACurrentMediaTime();
}

#pragma mark -- AnylineOCRModuleDelegate

/*
 This is the main delegate method Anyline uses to report its results
 */
- (void)anylineOCRModuleView:(AnylineOCRModuleView *)anylineOCRModuleView
               didFindResult:(ALOCRResult *)result {
    // We are done. Cancel scanning
    [self anylineDidFindResult:result.result barcodeResult:@"" image:result.image module:anylineOCRModuleView completion:^{
        // Display an overlay showing the result
        UIImage *image = [UIImage imageNamed:@"license_plate_background"];
        ALLicensePlateResultOverlayView *overlay = [[ALLicensePlateResultOverlayView alloc] initWithFrame:self.view.bounds];
        [overlay setImage:image];
        
        NSArray<NSString *> *licenseComponents = [result.result componentsSeparatedByString:@"-"];
        
        if (licenseComponents.count > 1) {
            [overlay setCountryCode:[licenseComponents firstObject]];
        }
        
        [overlay setText:[licenseComponents lastObject]];
        
        __weak typeof(self) welf = self;
        __weak ALResultOverlayView *woverlay = overlay;
        [overlay setTouchDownBlock:^{
            // Remove the view when touched and restart scanning
            [welf startAnyline];
            [woverlay removeFromSuperview];
        }];
        [self.view addSubview:overlay];
    }];
}

- (void)anylineOCRModuleView:(AnylineOCRModuleView *)anylineOCRModuleView
             reportsVariable:(NSString *)variableName
                       value:(id)value {
    if ([variableName isEqualToString:@"$brightness"]) {
        [self updateBrightness:[value floatValue] forModule:self.ocrModuleView];
    }
}

- (void)anylineModuleView:(AnylineAbstractModuleView *)anylineModuleView
               runSkipped:(ALRunFailure)runFailure {
    switch (runFailure) {
        case ALRunFailureResultNotValid:
            break;
        case ALRunFailureConfidenceNotReached:
            break;
        case ALRunFailureNoLinesFound:
            break;
        case ALRunFailureNoTextFound:
            break;
        case ALRunFailureUnkown:
            break;
        default:
            break;
    }
}

- (IBAction)helpPressed:(id)sender {
    [self.ocrModuleView cancelScanningAndReturnError:nil];
    
    ALIntroHelpView *helpView = [[ALIntroHelpView alloc] initWithFrame:self.ocrModuleView.frame];
    
    helpView.cutoutPath = self.ocrModuleView.currentConfiguration.cutoutPath;
    helpView.delegate = self;
    helpView.sampleImageView.image = [UIImage imageNamed:@"intro_license_plate"];
    
    [self.view addSubview:helpView];
}

#pragma mark - ALIntroHelpViewDelegate

- (void)goButtonPressedOnIntroHelpView:(ALIntroHelpView *)introHelpView {
    [introHelpView removeFromSuperview];
    
    [self.ocrModuleView startScanningAndReturnError:nil];
}


@end
