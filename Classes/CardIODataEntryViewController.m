//
//  CardIODataEntryViewController.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "CardIODataEntryViewController.h"
#import "CardIOContext.h"
#import "CardIOPaymentViewController.h"
#import "CardIOPaymentViewControllerContinuation.h"
#import "CardIONumbersTextFieldDelegate.h"
#import "CardIOCVVTextFieldDelegate.h"
#import "CardIOPostalCodeTextFieldDelegate.h"
#import "CardIOCardholderNameTextFieldDelegate.h"
#import "CardIOCreditCardNumber.h"
#import "CardIORowBasedTableViewSection.h"
#import "CardIOSectionBasedTableViewDelegate.h"
#import "CardIOCGGeometry.h"
#import "CardIOViewController.h"
#import "CardIOCreditCardInfo.h"
#import "CardIOMultipleFieldTableViewCell.h"
#import "CardIOExpiryTextFieldDelegate.h"
#import "CardIOCreditCardNumberFormatter.h"
#import "CardIOCreditCardExpiryFormatter.h"
#import "CardIOTableViewCell.h"
#import "CardIOStyles.h"
#import "CardIOMacros.h"
#import "CardIOAnalytics.h"
#import "CardIOLocalizer.h"
#import "CardIOOrientation.h"
#import "dmz_constants.h"

#define kStatusBarHeight  20
#define kiOS7TableViewBorderColor 0.78f
#define kMinimumDefaultRowWidth 320.0f

@interface CardIODataEntryViewController ()

- (void)cancel;
- (void)done;
- (BOOL)validate;
- (NSUInteger)cvvLength;
- (NSString *)cvvPlaceholder;

@property(nonatomic, assign, readwrite) BOOL statusBarHidden;
@property(nonatomic, strong, readwrite) UIScrollView *scrollView;
@property(nonatomic, strong, readwrite) UITableView *tableView;
@property(nonatomic, strong, readwrite) NSDictionary *inputViewInfo;
@property(nonatomic, strong, readwrite) NSMutableArray *visibleTextFields;
@property(nonatomic, strong, readwrite) CardIOSectionBasedTableViewDelegate *tableViewDelegate;
@property(nonatomic, strong, readwrite) CardIONumbersTextFieldDelegate *numberRowTextFieldDelegate;
@property(nonatomic, strong, readwrite) CardIOExpiryTextFieldDelegate* expiryTextFieldDelegate;
@property(nonatomic, strong, readwrite) CardIOCVVTextFieldDelegate *cvvRowTextFieldDelegate;
@property(nonatomic, strong, readwrite) CardIOPostalCodeTextFieldDelegate *postalCodeRowTextFieldDelegate;
@property(nonatomic, strong, readwrite) CardIOCardholderNameTextFieldDelegate *cardholderNameRowTextFieldDelegate;
@property(nonatomic, assign, readwrite) CGSize notificationSize;
@property(nonatomic, strong, readwrite) CardIOContext *context;
@property(nonatomic, assign, readwrite) CardIOCreditCardType cardTypeForLogo;
@property(nonatomic, weak, readwrite) UITextField *activeTextField;
@property(nonatomic, strong, readwrite) UIView *leftTableBorderForIOS7;
@property(nonatomic, strong, readwrite) UIView *rightTableBorderForIOS7;
@property (nonatomic, strong, readwrite) UIButton * doneButton;

@end


@implementation CardIODataEntryViewController

- (id)init {
  [NSException raise:@"Wrong initializer" format:@"CardIODataEntryViewController's designated initializer is initWithContext:"];
  return nil;
}

- (id)initWithContext:(CardIOContext *)aContext withStatusBarHidden:(BOOL)statusBarHidden {
  if((self = [super initWithNibName:nil bundle:nil])) {
    _cardInfo = [[CardIOCreditCardInfo alloc] init];
    _notificationSize = CGSizeZero;
    _context = aContext;
    _statusBarHidden = statusBarHidden;

    // set self.title in -viewDidLoad. the title is localized, which requires
    // access to the i18n context, but that is sometimes non-existent at this stage
    // (the developer sometimes hasn't even had the opportunity to tell us yet!).
  }
  return self;
}


- (void)viewDidLoad {
  [super viewDidLoad];

//  self.navigationController.navigationBar.opaque = true;
//  self.navigationController.navigationBar.barStyle = UIBarStyleDefault;

//    self.automaticallyAdjustsScrollViewInsets = YES;
//    self.edgesForExtendedLayout = UIRectEdgeNone;

  CardIOPaymentViewController *pvc = (CardIOPaymentViewController *)self.navigationController;
  self.title = CardIOLocalizedString(@"card_details_title", self.context.languageOrLocale);
  //CardIOLocalizedString(@"entry_title", self.context.languageOrLocale); // Enter card info

  // Need to set up the navItem here, because the OS calls the accessor before all the info needed to build it is available.

  BOOL showCancelButton = ([self.navigationController.viewControllers count] == 1);
  if(self.cardImage) {
    showCancelButton = YES;
  }

  if(showCancelButton) {
    NSString *cancelText = CardIOLocalizedString(@"cancel", self.context.languageOrLocale); // Cancel
    // show the cancel button if we've gone directly to manual entry.
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:cancelText style:UIBarButtonItemStylePlain target:self action:@selector(cancel)];
  } else {
    // Show fake "back" button, since real back button takes us back to the animation view, not back to the camera
//    NSString *cameraText = CardIOLocalizedString(@"camera", self.context.languageOrLocale); // Camera
//    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:cameraText style:UIBarButtonItemStyleBordered target:self action:@selector(popToTop)];
  }

  NSString *cardInfoText = CardIOLocalizedString(@"card_info", self.context.languageOrLocale); // Card Info
  self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:cardInfoText style:UIBarButtonItemStylePlain target:nil action:nil];

  self.navigationItem.rightBarButtonItem.enabled = NO;

  self.doneButton = [UIButton buttonWithType:UIButtonTypeCustom];
  self.doneButton.frame = CGRectMake(0, 0, self.view.frame.size.width, 44);
  [self.doneButton setTitle:@"Next" forState:UIControlStateNormal];
  [self.doneButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  [self.doneButton addTarget:self action:@selector(done) forControlEvents:UIControlEventTouchUpInside];
  [self.doneButton setBackgroundColor: [CardIOTableViewCell errorColor]];
  self.doneButton.enabled = false;
  
  self.collectExpiry = pvc.collectExpiry;
  self.collectCVV = pvc.collectCVV;
  self.collectPostalCode = pvc.collectPostalCode;
  self.restrictPostalCodeToNumericOnly = pvc.restrictPostalCodeToNumericOnly;
  self.collectCardholderName = pvc.collectCardholderName;

  self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];

  if(!self.manualEntry) {
    self.cardView = [[UIImageView alloc] initWithImage:self.cardImage];
    self.cardView.contentMode = UIViewContentModeScaleAspectFill;
    self.cardView.backgroundColor = kColorViewBackground;
    self.cardView.layer.masksToBounds = YES;

    self.cardView.hidden = NO;
    [self.scrollView addSubview:self.cardView];
  }

  self.tableView = [[UITableView alloc] initWithFrame:self.scrollView.bounds style:UITableViewStyleGrouped];
  self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
  self.tableView.scrollEnabled = NO;
  if (!self.manualEntry) {
    self.tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, 0.01f)];

  }
  
  UIView * footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 0.01)];
  self.tableView.tableFooterView = footerView;

  // On iOS 7, remove the edge inset from the table for a more consistent appearance
  // when there are multiple inputs in a row.
  if (iOS_7_PLUS) {
    self.tableView.separatorInset = UIEdgeInsetsZero;
  }

  NSMutableArray *sections = [NSMutableArray arrayWithCapacity:1];
  self.visibleTextFields = [NSMutableArray arrayWithCapacity:4];

  NSMutableArray *rows = [NSMutableArray arrayWithCapacity:4];

  if(self.manualEntry) {
    CardIOMultipleFieldTableViewCell *numberRow = [[CardIOMultipleFieldTableViewCell alloc] init];
    numberRow.backgroundColor = kColorDefaultCell;
    numberRow.numberOfFields = 1;
    numberRow.hiddenLabels = YES;
    numberRow.textAlignment = [CardIOLocalizer textAlignmentForLanguageOrLocale:self.context.languageOrLocale];

    NSString* numberText = CardIOLocalizedString(@"entry_number", self.context.languageOrLocale); // Number
    [numberRow.labels addObject:numberText];

    self.numberTextField = [numberRow.textFields lastObject];
    [self.visibleTextFields addObject:self.numberTextField];

    self.numberRowTextFieldDelegate = [[CardIONumbersTextFieldDelegate alloc] init];
    self.numberTextField.delegate = self.numberRowTextFieldDelegate;
    self.numberTextField.placeholder = CardIOLocalizedString(@"entry_card_number", self.context.languageOrLocale); // Card Number
    self.numberTextField.text = self.cardInfo.cardNumber ? self.cardInfo.cardNumber : @"";
    self.numberTextField.keyboardType = UIKeyboardTypeNumberPad;
    self.numberTextField.clearButtonMode = UITextFieldViewModeNever;
    self.numberTextField.backgroundColor = kColorDefaultCell;
    self.numberTextField.textAlignment = [CardIOLocalizer textAlignmentForLanguageOrLocale:self.context.languageOrLocale];
    self.numberTextField.autocorrectionType = UITextAutocorrectionTypeNo;

    // For fancier masking (e.g., by number group rather than by individual digit),
    // put fancier functionality into CardIONumbersTextFieldDelegate instead of setting secureTextEntry.
    self.numberTextField.secureTextEntry = self.context.maskManualEntryDigits;

    [self updateCardLogo];

    [rows addObject:numberRow];
  }

  if(self.collectExpiry || self.collectCVV) {
    CardIOMultipleFieldTableViewCell *multiFieldRow = [[CardIOMultipleFieldTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    multiFieldRow.backgroundColor = kColorDefaultCell;
    multiFieldRow.textAlignment = [CardIOLocalizer textAlignmentForLanguageOrLocale:self.context.languageOrLocale];

    BOOL collectBoth = self.collectExpiry && self.collectCVV;
    BOOL bothInOneRow = NO;
    if (collectBoth) {
      NSString *expiryText = CardIOLocalizedString(@"entry_expires", self.context.languageOrLocale); // Expires
      NSString* cvvText = [NSString stringWithFormat:CardIOLocalizedString(@"entry_cvv", self.context.languageOrLocale), self.cardInfo.cardType ? [NSNumber numberWithInteger:self.cvvLength] : @"3-4"]; // CVV
      CGFloat fieldWidthForTwoFieldsPerRow = kMinimumDefaultRowWidth / 2;
      bothInOneRow = ([multiFieldRow textFitsInMultiFieldForLabel:@"" forPlaceholder:expiryText forFieldWidth:fieldWidthForTwoFieldsPerRow] &&
                      [multiFieldRow textFitsInMultiFieldForLabel:@"" forPlaceholder:cvvText forFieldWidth:fieldWidthForTwoFieldsPerRow]);
    }

    multiFieldRow.hiddenLabels = YES;

    if(self.collectExpiry) {
      multiFieldRow.numberOfFields++;
      NSString *expiryText = CardIOLocalizedString(@"entry_expires", self.context.languageOrLocale); // Expires
      [multiFieldRow.labels addObject:expiryText];
      self.expiryTextField = [multiFieldRow.textFields lastObject];
      [self.visibleTextFields addObject:self.expiryTextField];

      self.expiryTextFieldDelegate = [[CardIOExpiryTextFieldDelegate alloc] init];
      self.expiryTextField.delegate = self.expiryTextFieldDelegate;
      self.expiryTextField.placeholder = CardIOLocalizedString(@"expires_placeholder", self.context.languageOrLocale); // MM/YY
      // Add a space on each side of the slash. (Do this in code rather than in the string, because the L10n process won't preserve the spaces.)
      self.expiryTextField.placeholder = [self.expiryTextField.placeholder stringByReplacingOccurrencesOfString:@"/" withString:@" / "];
      self.expiryTextField.placeholder = [self.expiryTextField.placeholder stringByReplacingOccurrencesOfString:@"  " withString:@" "];
      self.expiryTextField.keyboardType = UIKeyboardTypeNumberPad;
      self.expiryTextField.textAlignment = [CardIOLocalizer textAlignmentForLanguageOrLocale:self.context.languageOrLocale];
      self.expiryTextField.autocorrectionType = UITextAutocorrectionTypeNo;

      if(self.cardInfo.expiryMonth > 0 && self.cardInfo.expiryYear > 0) {
        self.expiryTextField.text = [self.expiryTextFieldDelegate.formatter stringForObjectValue:self.cardInfo];
        if (![[self class] cardExpiryIsValid:self.cardInfo]) {
          self.expiryTextField.textColor = [CardIOTableViewCell errorColor];
        }
      }
    }

    if (collectBoth && !bothInOneRow) {
      [rows addObject:multiFieldRow];
      multiFieldRow = [[CardIOMultipleFieldTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
      multiFieldRow.hiddenLabels = YES;
      multiFieldRow.backgroundColor = kColorDefaultCell;
      multiFieldRow.textAlignment = [CardIOLocalizer textAlignmentForLanguageOrLocale:self.context.languageOrLocale];
    }

    if(self.collectCVV) {
      multiFieldRow.numberOfFields++;
      if (bothInOneRow) {
        multiFieldRow.labelWidth = 0;
      }

      NSString* cvvText = [NSString stringWithFormat:CardIOLocalizedString(@"entry_cvv", self.context.languageOrLocale), self.cardInfo.cardType ? [NSNumber numberWithInteger:self.cvvLength] : @"3-4"]; // CVV
      [multiFieldRow.labels addObject:cvvText];
      self.cvvTextField = [multiFieldRow.textFields lastObject];
      [self.visibleTextFields addObject:self.cvvTextField];

      self.cvvRowTextFieldDelegate = [[CardIOCVVTextFieldDelegate alloc] init];
      self.cvvRowTextFieldDelegate.maxLength = [self cvvLength];

      self.cvvTextField.delegate = self.cvvRowTextFieldDelegate;
      self.cvvTextField.placeholder = cvvText;
      self.cvvTextField.text = self.cardInfo.cvv;
      self.cvvTextField.keyboardType = UIKeyboardTypeNumberPad;
      self.cvvTextField.clearButtonMode = UITextFieldViewModeNever;
      self.cvvTextField.text = @"";
      self.cvvTextField.textAlignment = [CardIOLocalizer textAlignmentForLanguageOrLocale:self.context.languageOrLocale];
      self.cvvTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    }

    [rows addObject:multiFieldRow];
  }

  if(self.collectPostalCode) {
    CardIOMultipleFieldTableViewCell *postalCodeRow = [[CardIOMultipleFieldTableViewCell alloc] init];
    postalCodeRow.backgroundColor = kColorDefaultCell;
    postalCodeRow.numberOfFields = 1;
    postalCodeRow.hiddenLabels = YES;
    postalCodeRow.textAlignment = [CardIOLocalizer textAlignmentForLanguageOrLocale:self.context.languageOrLocale];

    NSString *postalCodeText = CardIOLocalizedString(@"entry_postal_code", self.context.languageOrLocale); // Postal Code
    [postalCodeRow.labels addObject:postalCodeText];

    self.postalCodeTextField = [postalCodeRow.textFields lastObject];
    [self.visibleTextFields addObject:self.postalCodeTextField];

    self.postalCodeRowTextFieldDelegate = [[CardIOPostalCodeTextFieldDelegate alloc] init];
    self.postalCodeTextField.placeholder = postalCodeText;
    self.postalCodeTextField.delegate = self.postalCodeRowTextFieldDelegate;
    self.postalCodeTextField.text = self.cardInfo.postalCode;
    if (self.restrictPostalCodeToNumericOnly) {
      self.postalCodeTextField.keyboardType = UIKeyboardTypeNumberPad;
      self.postalCodeRowTextFieldDelegate.numbersOnly = YES;
    } else {
      self.postalCodeTextField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    }
    self.postalCodeTextField.clearButtonMode = UITextFieldViewModeNever;
    self.postalCodeTextField.text = @"";
    self.postalCodeTextField.textAlignment = [CardIOLocalizer textAlignmentForLanguageOrLocale:self.context.languageOrLocale];
    self.postalCodeTextField.autocorrectionType = UITextAutocorrectionTypeNo;

    [rows addObject:postalCodeRow];
  }

  if(self.collectCardholderName) {
    CardIOMultipleFieldTableViewCell *cardholderNameRow = [[CardIOMultipleFieldTableViewCell alloc] init];
    cardholderNameRow.backgroundColor = kColorDefaultCell;
    cardholderNameRow.numberOfFields = 1;
    cardholderNameRow.hiddenLabels = YES;
    cardholderNameRow.textAlignment = [CardIOLocalizer textAlignmentForLanguageOrLocale:self.context.languageOrLocale];

    NSString *cardholderNameText = CardIOLocalizedString(@"entry_cardholder_name", self.context.languageOrLocale); // Cardholder Name
    [cardholderNameRow.labels addObject:cardholderNameText];

    self.cardholderNameTextField = [cardholderNameRow.textFields lastObject];
    [self.visibleTextFields addObject:self.cardholderNameTextField];

    self.cardholderNameRowTextFieldDelegate = [[CardIOCardholderNameTextFieldDelegate alloc] init];
    self.cardholderNameTextField.placeholder = cardholderNameText;
    self.cardholderNameTextField.delegate = self.cardholderNameRowTextFieldDelegate;
    self.cardholderNameTextField.text = self.cardInfo.cardholderName;
    self.cardholderNameTextField.keyboardType = UIKeyboardTypeDefault;
    self.cardholderNameTextField.clearButtonMode = UITextFieldViewModeNever;
    self.cardholderNameTextField.text = @"";
    self.cardholderNameTextField.textAlignment = [CardIOLocalizer textAlignmentForLanguageOrLocale:self.context.languageOrLocale];
    self.cardholderNameTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.cardholderNameTextField.autocapitalizationType = UITextAutocapitalizationTypeWords;

    [rows addObject:cardholderNameRow];
  }

  CardIORowBasedTableViewSection *infoSection = [[CardIORowBasedTableViewSection alloc] init];
  infoSection.rows = rows;
  [sections addObject:infoSection];

  self.tableViewDelegate = [[CardIOSectionBasedTableViewDelegate alloc] init];
  self.tableViewDelegate.sections = sections;

  self.tableView.delegate = self.tableViewDelegate;
  self.tableView.dataSource = self.tableViewDelegate;
  self.tableView.backgroundColor = kColorViewBackground;
  self.tableView.opaque = YES;

  self.view.backgroundColor = kColorViewBackground;

  UIView *background = [[UIView alloc] initWithFrame:self.tableView.bounds];
  background.backgroundColor = kColorViewBackground;
  self.tableView.backgroundView = background;

  [self.scrollView addSubview:self.tableView];

  if (iOS_7_PLUS) {
//    self.leftTableBorderForIOS7 = [[UIView alloc] init];
//    self.leftTableBorderForIOS7.backgroundColor = [UIColor clearColor];
////    self.leftTableBorderForIOS7.backgroundColor = [UIColor colorWithWhite:kiOS7TableViewBorderColor alpha:1];
////    if (@available(iOS 13.0, *)) {
////      self.leftTableBorderForIOS7.backgroundColor = [UIColor separatorColor];
////    }
//
//    self.leftTableBorderForIOS7.hidden = YES;
//    [self.scrollView addSubview:self.leftTableBorderForIOS7];

    self.rightTableBorderForIOS7 = [[UIView alloc] init];
    self.rightTableBorderForIOS7.backgroundColor = [UIColor colorWithWhite:kiOS7TableViewBorderColor alpha:1];
    if (@available(iOS 13.0, *)) {
      self.rightTableBorderForIOS7.backgroundColor = [UIColor separatorColor];
    }
    self.rightTableBorderForIOS7.hidden = YES;
    [self.scrollView addSubview:self.rightTableBorderForIOS7];
  }

  if (self.cardView) {
    // Animations look better if the cardView is in front of the tableView
    [self.scrollView bringSubviewToFront:self.cardView];
  }

  [self.view addSubview:self.scrollView];
  [self.view addSubview:self.doneButton];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillMove:) name:UIKeyboardWillShowNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillMove:) name:UIKeyboardWillHideNotification object:nil];

  [self advanceToNextEmptyFieldFrom:nil];
  [self validate];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];


  if(self.manualEntry) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(cardNumberDidChange:)
                                                 name:UITextFieldTextDidChangeNotification
                                               object:self.numberTextField];
  }
  if(self.collectExpiry) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(expiryDidChange:)
                                                 name:UITextFieldTextDidChangeNotification
                                               object:self.expiryTextField];
  }
  if(self.collectCVV) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(cvvDidChange:)
                                                 name:UITextFieldTextDidChangeNotification
                                               object:self.cvvTextField];
  }
  if(self.collectPostalCode) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(postalCodeDidChange:)
                                                 name:UITextFieldTextDidChangeNotification
                                               object:self.postalCodeTextField];
  }
  if(self.collectCardholderName) {
		[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(cardholderNameDidChange:)
                                                 name:UITextFieldTextDidChangeNotification
                                               object:self.cardholderNameTextField];
  }

  [self validate];
}

- (void)keyboardWillMove:(NSNotification *)inputViewNotification {
  CGRect keyboardFrame = [[[inputViewNotification userInfo] valueForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];

//  CGRect keyboardFrameInView = [self.view convertRect:keyboardFrame fromView:nil];
//  CGRect intersection = CGRectIntersection(self.scrollView.frame, keyboardFrameInView);

  UIEdgeInsets ei = UIEdgeInsetsMake(0.0, 0.0, keyboardFrame.size.height + self.doneButton.frame.size.height, 0.0);
  self.scrollView.scrollIndicatorInsets = ei;
  self.scrollView.contentInset = ei;

  [self.view setNeedsLayout];
}

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];

  for(UITextField *tf in self.visibleTextFields) {
    [tf resignFirstResponder];
  }

  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidUnload {
  self.tableView.delegate = nil, self.tableView.dataSource = nil, self.tableView = nil;

  self.tableViewDelegate = nil;
  self.numberRowTextFieldDelegate = nil;
  self.expiryTextFieldDelegate = nil;
  self.cvvRowTextFieldDelegate = nil;
  self.postalCodeRowTextFieldDelegate = nil;
  self.cardholderNameRowTextFieldDelegate = nil;

  self.expiryTextField = nil;
  self.numberTextField = nil;
  self.cvvTextField = nil;
  self.postalCodeTextField = nil;
  self.cardholderNameTextField = nil;

  self.visibleTextFields = nil;

  [super viewDidUnload];
}

#pragma mark - orientation-based subview layout

- (void)showTableBorders:(BOOL)showTableBorders {
  if (iOS_7_PLUS) {
    self.leftTableBorderForIOS7.hidden = !showTableBorders;
    self.rightTableBorderForIOS7.hidden = !showTableBorders;
  }
}

- (void) viewWillLayoutSubviews {
  [super viewWillLayoutSubviews];

//  self.scrollView.frame = self.view.bounds;
  
  // Calculate height
  CGFloat availableHeight = self.view.frame.size.height - self.scrollView.contentInset.bottom;

  if (self.cardView) {
    CGFloat imageAvailableHeight = availableHeight - self.tableView.contentSize.height;

    CGRect cardViewFrame = self.cardView.frame;
    CGRect tableViewFrame = CGRectMake(0, 0, self.scrollView.bounds.size.width, self.tableView.contentSize.height);
    
    BOOL showTableView = ([self.tableView numberOfRowsInSection:0] > 0);

    cardViewFrame.size.width = (CGFloat)floor(self.scrollView.bounds.size.width * kPortraitZoomedInCardImageSizePercent);
    cardViewFrame.size.height = (CGFloat)floor(self.cardImage.size.height * (cardViewFrame.size.width / self.cardImage.size.width));

    if (showTableView) {
      cardViewFrame.origin.x = (CGFloat)floor((self.scrollView.bounds.size.width - cardViewFrame.size.width) / 2);
      
      //if image to big crop it
      if (imageAvailableHeight < cardViewFrame.size.height) {
        cardViewFrame.origin.y = 0;
        cardViewFrame.size.height = imageAvailableHeight;
        self.cardView.layer.cornerRadius = 0;
        tableViewFrame.origin.y = imageAvailableHeight;
      } else {
        cardViewFrame.origin.y = MIN(cardViewFrame.size.height + 20, imageAvailableHeight) - cardViewFrame.size.height;
        self.cardView.layer.cornerRadius = ((CGFloat) 9.0f) * (self.cardView.bounds.size.width / ((CGFloat) 300.0f)); // matches the card, adjusted for view size. (view is ~300 px wide on phone.)
        tableViewFrame.origin.y = MIN(imageAvailableHeight, CGRectGetMaxY(cardViewFrame) + 20);
      }

//      tableViewFrame = CGRectMake(0, CGRectGetMaxY(cardViewFrame) + (imageAvailableHeight > cardViewFrame.size.height + 20 ? 20 : 0), self.scrollView.bounds.size.width, self.tableView.contentSize.height);
//
      CGRect tableBorderFrame = CGRectMake(0, 0, 0, 0);
      self.leftTableBorderForIOS7.frame = tableBorderFrame;
      self.rightTableBorderForIOS7.frame = tableBorderFrame;
    
    }
    else {
      cardViewFrame.origin.x = (CGFloat)floor((self.scrollView.frame.size.width - cardViewFrame.size.width) / 2);
      cardViewFrame.origin.y = 30;
        self.cardView.layer.cornerRadius = ((CGFloat) 9.0f) * (self.cardView.bounds.size.width / ((CGFloat) 300.0f)); // matches the card, adjusted for view size. (view is ~300 px wide on phone.)
      
      tableViewFrame = CGRectZero;
    }
    
    self.cardView.frame = cardViewFrame;
    self.tableView.frame = tableViewFrame;

    self.scrollView.contentSize = CGSizeMake(self.scrollView.bounds.size.width,
                                             MAX(CGRectGetMaxY(self.tableView.frame), CGRectGetMaxY(self.cardView.frame)));
  }
  else {
    self.tableView.frame = CGRectMake(0, 0, self.tableView.frame.size.width, self.tableView.contentSize.height);
    self.scrollView.contentSize = CGSizeMake(self.scrollView.bounds.size.width,
                                             self.tableView.frame.origin.y +
                                              self.tableView.contentSize.height);
  }
  
  if (self.scrollView.contentInset.bottom > 0) {
    self.doneButton.frame = CGRectMake(0, self.view.frame.size.height - self.scrollView.contentInset.bottom , self.view.frame.size.width, self.doneButton.frame.size.height);
  } else {
    self.doneButton.frame = CGRectMake(0, MAX(CGRectGetMaxY(self.tableView.frame), CGRectGetMaxY(self.cardView.frame) + 20), self.view.frame.size.width, self.doneButton.frame.size.height);
  }
  
  if (@available(iOS 13.0, *)) {
      self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
  }
}


#pragma mark - Status bar preferences (iOS 7)

- (UIStatusBarStyle) preferredStatusBarStyle {
  return UIStatusBarStyleDefault;
}

- (BOOL)prefersStatusBarHidden {
  return NO;//self.statusBarHidden;
}

#pragma mark -

- (void)popToTop {
  if (iOS_7_PLUS) {
    // iOS 7 apparently has a quirk in which keyboard dismisses only after the pop.
    // We fix this by explicitly calling resignFirstResponder on all fields
    // to ensure keyboard dismisses immediately.
    for (UITextField *field in self.visibleTextFields) {
      [field resignFirstResponder];
    }
  }


  ((CardIOPaymentViewController *)self.navigationController).currentViewControllerIsDataEntry = NO;
  ((CardIOPaymentViewController *)self.navigationController).initialInterfaceOrientationForViewcontroller = [UIApplication sharedApplication].statusBarOrientation;
  [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)cancel {
  CardIOPaymentViewController *pvc = (CardIOPaymentViewController *)self.navigationController;
  [pvc.paymentDelegate userDidCancelPaymentViewController:pvc];
}

- (void)done {
  if(self.manualEntry) {
    self.cardInfo.cardNumber = [CardIOCreditCardNumber stringByRemovingNonNumbers:self.numberTextField.text];
  }

  self.cardInfo.cvv = self.cvvTextField.text;
  self.cardInfo.postalCode = [self.postalCodeTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  self.cardInfo.cardholderName = self.cardholderNameTextField.text;

  CardIOPaymentViewController *pvc = (CardIOPaymentViewController *)self.navigationController;
  [pvc.paymentDelegate userDidProvideCreditCardInfo:self.cardInfo inPaymentViewController:pvc];
}

- (void)advanceToNextEmptyFieldFrom:(id)fromField {
  NSUInteger startIndex = 0;

  // Define start index
  if (fromField) {
    NSUInteger indexOfSender = [self.visibleTextFields indexOfObject:fromField];
    if (indexOfSender != NSNotFound) {
      startIndex = indexOfSender + 1;
      if (startIndex >= self.visibleTextFields.count) {
        startIndex = 0;
      }
    }
  }
  // Iterate through
  for (NSUInteger i = startIndex; i < self.visibleTextFields.count; i++) {
    UITextField *tf = self.visibleTextFields[i];
    if(tf.text.length == 0) {
      [tf becomeFirstResponder];
      break;
    }
  }
}

- (void)cardNumberDidChange:(id)sender {
  static BOOL recursionBlock = NO;
  if (recursionBlock) {
    return;
  }

  BOOL fieldIsInFlux = ![self.numberRowTextFieldDelegate cleanupTextField:self.numberTextField];

  CardIOCreditCardInfo *cleanedInfo = self.cardInfo;
  [self.numberRowTextFieldDelegate.formatter getObjectValue:&cleanedInfo forString:self.numberTextField.text errorDescription:nil];
  self.cardInfo = cleanedInfo;

  self.cvvRowTextFieldDelegate.maxLength = [self cvvLength];
  [self updateCvvColor];

  CardIOCreditCardType cardType = [CardIOCreditCardNumber cardTypeForCardNumber:self.cardInfo.cardNumber];

  if([CardIOCreditCardNumber isValidNumber:self.cardInfo.cardNumber]) {
    if (!fieldIsInFlux) {
      recursionBlock = YES;
      [self advanceToNextEmptyFieldFrom:self.numberTextField];
      recursionBlock = NO;
    }
    self.numberTextField.textColor = [CardIOTableViewCell defaultDetailTextLabelColorForCellStyle:[CardIOTableViewCell defaultCellStyle]];
  } else if ([self.cardInfo.cardNumber length] > 0 &&
             ((cardType == CardIOCreditCardTypeUnrecognized && [self.cardInfo.cardNumber length] == 16) ||
              self.cardInfo.cardNumber.length == [CardIOCreditCardNumber numberLengthForCardNumber:self.cardInfo.cardNumber])) {
               self.numberTextField.textColor = [CardIOTableViewCell errorColor];
             } else {
               self.numberTextField.textColor = [CardIOTableViewCell defaultDetailTextLabelColorForCellStyle:[CardIOTableViewCell defaultCellStyle]];
             }

  [self updateCardLogo];

  [self validate];
}

- (void)updateCardLogo {
  NSString              *cardNumber = [CardIOCreditCardNumber stringbyRemovingSpaces:_numberTextField.text];
  CardIOCreditCardType  cardType = [CardIOCreditCardNumber cardTypeForCardNumber:cardNumber];
  if (_cardTypeForLogo != cardType) {
    self.cardTypeForLogo = cardType;
    UIImage *cardLogo = [CardIOCreditCardInfo logoForCardType:cardType];
    if (cardLogo) {
      UIImageView*	logoView = [[UIImageView alloc] initWithImage:cardLogo];
      logoView.contentMode = UIViewContentModeScaleAspectFit;
      logoView.bounds = CGRectMake(0, 0, cardLogo.size.width, cardLogo.size.height);
      logoView.accessibilityLabel = [CardIOCreditCardInfo displayStringForCardType:cardType usingLanguageOrLocale:self.context.languageOrLocale];
      logoView.isAccessibilityElement = YES;

      _numberTextField.rightView = logoView;
      _numberTextField.rightViewMode = UITextFieldViewModeAlways;
    }
    else {
      _numberTextField.rightView = nil;
      _numberTextField.rightViewMode = UITextFieldViewModeNever;
    }
  }
}

- (void)expiryDidChange:(id)sender {
  static BOOL recursionBlock = NO;
  if (recursionBlock) {
    return;
  }

  BOOL fieldIsInFlux = ![self.expiryTextFieldDelegate cleanupTextField:self.expiryTextField];

  CardIOCreditCardInfo *cleanedInfo = self.cardInfo;
  [self.expiryTextFieldDelegate.formatter getObjectValue:&cleanedInfo forString:self.expiryTextField.text errorDescription:nil];
  self.cardInfo = cleanedInfo;

  if([[self class] cardExpiryIsValid:self.cardInfo] ) {
    if (!fieldIsInFlux) {
      recursionBlock = YES;
      [self advanceToNextEmptyFieldFrom:self.expiryTextField];
      recursionBlock = NO;
    }
    self.expiryTextField.textColor = [CardIOTableViewCell defaultDetailTextLabelColorForCellStyle:[CardIOTableViewCell defaultCellStyle]];
  } else if(self.expiryTextField.text.length >= 7) {
    self.expiryTextField.textColor = [CardIOTableViewCell errorColor];
  } else {
    self.expiryTextField.textColor = [CardIOTableViewCell defaultDetailTextLabelColorForCellStyle:[CardIOTableViewCell defaultCellStyle]];
  }

  [self validate];
}

- (void)cvvDidChange:(id)sender {
  self.cardInfo.cvv = self.cvvTextField.text;

  [self updateCvvColor];

  CardIOCreditCardType cardType = [CardIOCreditCardNumber cardTypeForCardNumber:self.cardInfo.cardNumber];
  if(cardType != CardIOCreditCardTypeUnrecognized && cardType != CardIOCreditCardTypeAmbiguous &&
     [CardIOCVVTextFieldDelegate isValidCVV:self.cardInfo.cvv forNumber:self.cardInfo.cardNumber]) {
    [self advanceToNextEmptyFieldFrom:self.cvvTextField];
  }

  [self validate];
}

- (void)updateCvvColor {
  if([CardIOCVVTextFieldDelegate isValidCVV:self.cardInfo.cvv forNumber:self.cardInfo.cardNumber]) {
    self.cvvTextField.textColor = [CardIOTableViewCell defaultDetailTextLabelColorForCellStyle:[CardIOTableViewCell defaultCellStyle]];
  } else if(self.cvvTextField.text.length > [self cvvLength]) {
    self.cvvTextField.textColor = [CardIOTableViewCell errorColor];
  } else {
    self.cvvTextField.textColor = [CardIOTableViewCell defaultDetailTextLabelColorForCellStyle:[CardIOTableViewCell defaultCellStyle]];
  }
}

- (void)postalCodeDidChange:(id)sender {
  self.cardInfo.postalCode = [self.postalCodeTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

  // For globalization, we can't be sure of a valid postalCode length. So for now we'll skip all of this.
  //
  //  if([CardIOPostalCodeTextFieldDelegate isValidPostalCode:self.cardInfo.postalCode]) {
  //    [self advanceToNextEmptyFieldFrom:self.postalCodeTextField];
  //    self.postalCodeTextField.textColor = [CardIOTableViewCell defaultDetailTextLabelColorForCellStyle:[CardIOTableViewCell defaultCellStyle]];
  //  } else if(self.postalCodeTextField.text.length >= 5) {
  //    // probably won't reach this case, since length == 5 is the only validation rule, but we'll leave it here for consitency and for future enhancements.
  //    self.postalCodeTextField.textColor = [UIColor redColor];
  //  } else {
  //    self.postalCodeTextField.textColor = [CardIOTableViewCell defaultDetailTextLabelColorForCellStyle:[CardIOTableViewCell defaultCellStyle]];
  //  }

  [self validate];
}

- (void)cardholderNameDidChange:(id)sender {
  self.cardInfo.cardholderName = self.cardholderNameTextField.text;

  if([CardIOCardholderNameTextFieldDelegate isValidCardholderName:self.cardInfo.cardholderName]) {
    self.cardholderNameTextField.textColor = [CardIOTableViewCell defaultDetailTextLabelColorForCellStyle:[CardIOTableViewCell defaultCellStyle]];
  } else if(self.cardholderNameTextField.text.length >= 175) {
    // probably won't reach this case, since length == 175 is the only validation rule, but we'll leave it here for consitency and for future enhancements.
    self.cardholderNameTextField.textColor = [CardIOTableViewCell errorColor];
  } else {
    self.cardholderNameTextField.textColor = [CardIOTableViewCell defaultDetailTextLabelColorForCellStyle:[CardIOTableViewCell defaultCellStyle]];
  }

  [self validate];
}

- (BOOL)validate {
  BOOL numberIsValid = !self.manualEntry || [CardIOCreditCardNumber isValidNumber:self.cardInfo.cardNumber];
  BOOL expiryIsValid = !self.expiryTextField || [[self class] cardExpiryIsValid:self.cardInfo];
  BOOL cvvIsValid = !self.cvvTextField || [CardIOCVVTextFieldDelegate isValidCVV:self.cardInfo.cvv forNumber:self.cardInfo.cardNumber];
  BOOL postalCodeIsValid = !self.postalCodeTextField || [CardIOPostalCodeTextFieldDelegate isValidPostalCode:self.cardInfo.postalCode];
  BOOL cardholderNameIsValid = !self.cardholderNameTextField || [CardIOCardholderNameTextFieldDelegate isValidCardholderName:self.cardInfo.cardholderName];
  BOOL isValid = numberIsValid && expiryIsValid && cvvIsValid && postalCodeIsValid && cardholderNameIsValid;
  self.navigationItem.rightBarButtonItem.enabled = isValid;
  self.doneButton.enabled = isValid;
  
  CardIODataEntryViewController * _self = self;
  
  [UIView animateWithDuration:0.4 animations:^{
    if (!numberIsValid) {
      [_self.doneButton setTitle:CardIOLocalizedString(@"scan_button_pan", self.context.languageOrLocale) forState:UIControlStateNormal];
      [_self.doneButton setBackgroundColor:[CardIOTableViewCell errorButtonColor]];
    } else if (!expiryIsValid) {
      [_self.doneButton setTitle:CardIOLocalizedString(@"scan_button_expiry", self.context.languageOrLocale) forState:UIControlStateNormal];
      [_self.doneButton setBackgroundColor:[CardIOTableViewCell errorButtonColor]];
    } else if (!cvvIsValid) {
      [_self.doneButton setTitle:CardIOLocalizedString(@"scan_button_cvv", self.context.languageOrLocale) forState:UIControlStateNormal];
      [_self.doneButton setBackgroundColor:[CardIOTableViewCell errorButtonColor]];
    } else {
      [_self.doneButton setTitle:CardIOLocalizedString(@"scan_button_next", self.context.languageOrLocale) forState:UIControlStateNormal];
      [_self.doneButton setBackgroundColor:isValid ? [CardIOTableViewCell readyButtonColor] : [CardIOTableViewCell disabledButtonColor]];
    }
  }];
  
  return isValid;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// this could maybe become a property of CardIOCreditCardInfo, but that's public facing....
+ (BOOL)cardExpiryIsValid:(CardIOCreditCardInfo*)info {

  if(info.expiryMonth == 0 || info.expiryYear == 0) {
    return NO;
  }

  // we are under the assumption of a normal US calendar
  NSCalendar *cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];

  NSDateComponents *expiryComponents = [[NSDateComponents alloc] init];
  [expiryComponents setMonth:info.expiryMonth + 1]; // +1 to account for cards expiring "this month"
  [expiryComponents setYear:info.expiryYear];

  NSDate* expiryDate = [cal dateFromComponents:expiryComponents];

  if([expiryDate compare:[NSDate date]] == NSOrderedAscending) {
    return NO; // card is expired
  }

  NSDate *fifteenYearsFromNow = [[NSDate date] dateByAddingTimeInterval:3600 * 24 * 365.25 * 15]; // seconds/hr * hrs/day * days/yr * 15 (which roughly accounts for leap years, but without being very fussy about it)

  if([expiryDate compare:fifteenYearsFromNow] == NSOrderedDescending) {
    return NO; // expiry is more than 15 years out.
  }

  return YES;
}

- (NSUInteger)cvvLength {
  NSInteger cvvLength = [CardIOCreditCardNumber cvvLengthForCardType:self.cardInfo.cardType];
  if(cvvLength <= 0) {
    cvvLength = 4;
  }
  return cvvLength;
}

- (NSString *)cvvPlaceholder {
  return [@"1234567890" substringToIndex:[self cvvLength]];
}

@end
