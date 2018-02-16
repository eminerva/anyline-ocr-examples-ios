//
//  ALRecordNumberScanViewController.m
//  AnylineExamples
//
//  Created by Daniel Albertini on 04/02/16.
//  Copyright © 2016 9yards GmbH. All rights reserved.
//

#import "ALRecordNumberScanViewController.h"
#import <Anyline/Anyline.h>
#import "ALBaseViewController.h"
#import "NSUserDefaults+ALExamplesAdditions.h"
#import "ALAppDemoLicenses.h"

// This is the license key for the examples project used to set up Aynline below
NSString * const kRecordNumberLicenseKey = kDemoAppLicenseKey;
// The controller has to conform to <AnylineOCRModuleDelegate> to be able to receive results
@interface ALRecordNumberScanViewController ()<AnylineOCRModuleDelegate, AnylineDebugDelegate>
// The Anyline module used for OCR
@property (nonatomic, strong) AnylineOCRModuleView *ocrModuleView;

@end

@implementation ALRecordNumberScanViewController
/*
 We will do our main setup in viewDidLoad. Its called once the view controller is getting ready to be displayed.
 */
- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Record Number";
    
    // Set the background color to black to have a nicer transition
    self.view.backgroundColor = [UIColor blackColor];
    
    // Initializing the module. Its a UIView subclass. We set the frame to fill the whole screen
    CGRect frame = [[UIScreen mainScreen] applicationFrame];
    frame = CGRectMake(frame.origin.x, frame.origin.y + self.navigationController.navigationBar.frame.size.height, frame.size.width, frame.size.height - self.navigationController.navigationBar.frame.size.height);
    self.ocrModuleView = [[AnylineOCRModuleView alloc] initWithFrame:frame];
    
    ALOCRConfig *config = [[ALOCRConfig alloc] init];
    config.charHeight = ALRangeMake(22, 105);
    NSString *engTraineddata = [[NSBundle mainBundle] pathForResource:@"eng_no_dict" ofType:@"traineddata"];
    NSString *deuTraineddata = [[NSBundle mainBundle] pathForResource:@"deu" ofType:@"traineddata"];
    config.languages = @[engTraineddata,deuTraineddata];
    config.charWhiteList = @"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-.";
    config.minConfidence = 75;
    config.validationRegex = @"^([A-Z]+\\s*-*\\s*)?[0-9A-Z-\\s\\.]{3,}$";
    config.scanMode = ALLine;
    config.removeSmallContours = NO;
    
    NSError *error = nil;
    // We tell the module to bootstrap itself with the license key and delegate. The delegate will later get called
    // by the module once we start receiving results.
    BOOL success = [self.ocrModuleView setupWithLicenseKey:kRecordNumberLicenseKey
                                                  delegate:self
                                                 ocrConfig:config
                                                     error:&error];
    // setupWithLicenseKey:delegate:error returns true if everything went fine. In the case something wrong
    // we have to check the error object for the error message.
    if (!success) {
        // Something went wrong. The error object contains the error description
        NSAssert(success, @"Setup Error: %@", error.debugDescription);
    }
        
    [self.ocrModuleView enableReporting:[NSUserDefaults AL_reportingEnabled]];
    
    NSString *confPath = [[NSBundle mainBundle] pathForResource:@"record_number_config" ofType:@"json"];
    ALUIConfiguration *ibanConf = [ALUIConfiguration cutoutConfigurationFromJsonFile:confPath];
    self.ocrModuleView.currentConfiguration = ibanConf;
    
    self.controllerType = ALScanHistoryRecordNumber;
    
    // After setup is complete we add the module to the view of this view controller
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
}

/*
 Cancel scanning to allow the module to clean up
 */
- (void)viewWillDisappear:(BOOL)animated {
    [self.ocrModuleView cancelScanningAndReturnError:nil];
}

- (void)viewDidLayoutSubviews {
    [self updateWarningPosition:
     self.ocrModuleView.cutoutRect.origin.y +
     self.ocrModuleView.cutoutRect.size.height +
     self.ocrModuleView.frame.origin.y +
     90];
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
        ALBaseViewController *vc = [[ALBaseViewController alloc] init];
        vc.result = result.result;
        NSString *url = [NSString stringWithFormat:@"https://www.google.at/search?q=\"%@\" site:discogs.com OR site:musbrainz.org OR site:allmusic.com", result.result];
        [vc startWebSearchWithURL:url];
        [self.navigationController pushViewController:vc animated:YES];
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


@end
