//
//  QZNewQuestViewController.m
//  Quezt
//
//  Created by T.J. Mercer on 3/4/15.
//  Copyright (c) 2015 T.J. All rights reserved.
//

#import "QZNewQuestViewController.h"
#import "QZData.h"
#import "QZBackend.h"
#import "AFAmazonS3Manager.h"

@interface QZNewQuestViewController () <UIImagePickerControllerDelegate,UINavigationControllerDelegate>
@property (weak, nonatomic) IBOutlet UITextField *question;
@property (weak, nonatomic) IBOutlet UITextField *answer1;
@property (weak, nonatomic) IBOutlet UIButton *addNewAnswerButton;
@property (weak, nonatomic) IBOutlet UIView *bottomBar;
@property (weak, nonatomic) IBOutlet UIButton *geoToggle;
@property (weak, nonatomic) IBOutlet UIButton *takePicture;
@property (weak, nonatomic) IBOutlet UIButton *share;
@property (weak, nonatomic) IBOutlet UIButton *publicPrivateToggle;
@property (weak, nonatomic) IBOutlet UIImageView *pictureHolder;
@property (nonatomic) UIImage * chosenPicture;

@end

@implementation QZNewQuestViewController
{
    NSDictionary * qAndA;
    NSMutableArray * answers;
    NSMutableArray * textFields;
    NSString * imagePath;
    NSString * destinationPath;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    qAndA = @{};
    answers = [@[]mutableCopy];
    textFields = [@[]mutableCopy];
    self.answer1.tag = 1;
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)addNewAnswer:(id)sender {
    if (![self.answer1.text isEqualToString:@""]) {
        [textFields addObject:self.answer1];
        UITextField * newAnswer = [[UITextField alloc]initWithFrame:self.answer1.frame];
        newAnswer.borderStyle = UITextBorderStyleRoundedRect;
        newAnswer.autocapitalizationType = UITextAutocapitalizationTypeNone;
        newAnswer.tag = self.answer1.tag + 1;
        [self.view insertSubview:newAnswer belowSubview:self.answer1];
        [self replaceTopConstraintOnView:self.addNewAnswerButton withConstant:self.addNewAnswerButton.frame.origin.y + 38];
        [UIView animateWithDuration:0.2 animations:^{
            [self.view layoutIfNeeded];
            if (newAnswer.tag ==4) self.addNewAnswerButton.alpha = 0;
            [newAnswer setFrame:CGRectMake(self.answer1.frame.origin.x, self.answer1.frame.origin.y + 38, self.answer1.frame.size.width, self.answer1.frame.size.height)];
        } completion:^(BOOL finished) {
            self.answer1 = newAnswer;
            if (newAnswer.tag ==4) [self.addNewAnswerButton removeFromSuperview];
        }];
    } else {
        [[[UIAlertView alloc]initWithTitle:@"I'm confused..." message:@"Why do you need a new answer? You haven't given that one yet." delegate:nil cancelButtonTitle:@"Right. I'll do that." otherButtonTitles: nil] show];
    }
    [self.answer1 resignFirstResponder];
}

-(IBAction)picture:(id)sender
{
    UIImagePickerController * imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.delegate = self;
    imagePicker.sourceType =  UIImagePickerControllerSourceTypeCamera;
    [self presentViewController:imagePicker animated:YES completion:nil];
}

-(void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage * picture = [info objectForKey:@"UIImagePickerControllerOriginalImage"];
    [self.pictureHolder setImage:picture];
    self.chosenPicture = picture;
    
    NSData *jPEGImage = UIImageJPEGRepresentation(self.chosenPicture, .3);
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSDate *currentDateTime = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyyMMddHHmmss"];
    NSString *dateInString = [dateFormatter stringFromDate:currentDateTime];
    
    destinationPath = [NSString stringWithFormat:@"%@%@%@.png",[QZData mainData].userID, self.question.text, dateInString];
    imagePath =[documentsDirectory stringByAppendingPathComponent:destinationPath];
    
    if ([jPEGImage writeToFile:imagePath atomically:NO]) {
//        NSLog(@"Successfully cached profile picture to %@.", imagePath);
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)sendQuezt:(id)sender {
    [textFields addObject:self.answer1];
    
    QZBackend * backend = [[QZBackend alloc]init];
    
    for (UITextField *textSource in textFields) {
        [answers addObject:textSource.text];
    }
    UIActivityIndicatorView * spinner = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [spinner setFrame:CGRectMake(self.view.frame.size.width/2 -30, self.view.frame.size.height/2-30, 60, 60)];
    [self.view addSubview:spinner];
    [spinner startAnimating];
    if (self.pictureHolder) {
        [backend sendAmazonPhoto:imagePath andThen:^{
            [backend sendNewQueztWithQuestion:self.question.text Photo:destinationPath andAnswers:answers andThen:^{
                [spinner stopAnimating];
                [self dismissViewControllerAnimated:YES completion:nil];
            }];
        }];
    } else {
        [backend sendNewQueztWithQuestion:self.question.text Photo:nil andAnswers:answers andThen:^{
            [spinner stopAnimating];
            [self dismissViewControllerAnimated:YES completion:nil];
        }];
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.answer1 resignFirstResponder];
}

- (void)replaceTopConstraintOnView:(UIView *)view withConstant:(float)constant
{
    [self.view.constraints enumerateObjectsUsingBlock:^(NSLayoutConstraint *constraint, NSUInteger idx, BOOL *stop) {
        if ((constraint.firstItem == view) && (constraint.firstAttribute == NSLayoutAttributeTop)) {
            constraint.constant = constant;
        }
    }];
}

- (IBAction)exit:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSString *)encodeToBase64String:(UIImage *)image {
    return [UIImagePNGRepresentation(image) base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
}

- (UIImage *)decodeBase64ToImage:(NSString *)strEncodeData {
    NSData *data = [[NSData alloc]initWithBase64EncodedString:strEncodeData options:NSDataBase64DecodingIgnoreUnknownCharacters];
    return [UIImage imageWithData:data];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
