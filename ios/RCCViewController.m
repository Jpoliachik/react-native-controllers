#import "RCCViewController.h"
#import "RCCNavigationController.h"
#import "RCCTabBarController.h"
#import "RCCDrawerController.h"
#import "RCCTheSideBarManagerViewController.h"
#import "RCTRootView.h"
#import "RCCManager.h"
#import "RCTConvert.h"
#import "RCTUtils.h"

const NSInteger BLUR_STATUS_TAG = 78264801;
const NSInteger BLUR_NAVBAR_TAG = 78264802;

@interface RCCViewController()
@property (nonatomic) BOOL _hidesBottomBarWhenPushed;
@property (nonatomic) BOOL _statusBarHideWithNavBar;
@property (nonatomic) BOOL _statusBarHidden;
@property (nonatomic) BOOL _statusBarTextColorSchemeLight;
@property (nonatomic, strong) NSDictionary *originalNavBarImages;
@property (nonatomic, strong) UIImageView *navBarHairlineImageView;
@end

@implementation RCCViewController

-(UIImageView *)navBarHairlineImageView {
  if (!_navBarHairlineImageView) {
    _navBarHairlineImageView = [self findHairlineImageViewUnder:self.navigationController.navigationBar];
  }
  return _navBarHairlineImageView;
}

+ (UIViewController*)controllerWithLayout:(NSDictionary *)layout globalProps:(NSDictionary *)globalProps bridge:(RCTBridge *)bridge
{
  UIViewController* controller = nil;
  if (!layout) return nil;

  // get props
  if (!layout[@"props"]) return nil;
  if (![layout[@"props"] isKindOfClass:[NSDictionary class]]) return nil;
  NSDictionary *props = layout[@"props"];

  // get children
  if (!layout[@"children"]) return nil;
  if (![layout[@"children"] isKindOfClass:[NSArray class]]) return nil;
  NSArray *children = layout[@"children"];

  // create according to type
  NSString *type = layout[@"type"];
  if (!type) return nil;

  // regular view controller
  if ([type isEqualToString:@"ViewControllerIOS"])
  {
    controller = [[RCCViewController alloc] initWithProps:props children:children globalProps:globalProps bridge:bridge];
  }

  // navigation controller
  if ([type isEqualToString:@"NavigationControllerIOS"])
  {
    controller = [[RCCNavigationController alloc] initWithProps:props children:children globalProps:globalProps bridge:bridge];
  }

  // tab bar controller
  if ([type isEqualToString:@"TabBarControllerIOS"])
  {
    controller = [[RCCTabBarController alloc] initWithProps:props children:children globalProps:globalProps bridge:bridge];
  }

  // side menu controller
  if ([type isEqualToString:@"DrawerControllerIOS"])
  {
    NSString *drawerType = props[@"type"];
    
    if ([drawerType isEqualToString:@"TheSideBar"]) {
      
      controller = [[RCCTheSideBarManagerViewController alloc] initWithProps:props children:children globalProps:globalProps bridge:bridge];
    }
    else {
      controller = [[RCCDrawerController alloc] initWithProps:props children:children globalProps:globalProps bridge:bridge];
    }
  }

  // register the controller if we have an id
  NSString *componentId = props[@"id"];
  if (controller && componentId)
  {
    [[RCCManager sharedInstance] registerController:controller componentId:componentId componentType:type];
  }

  return controller;
}

- (instancetype)initWithProps:(NSDictionary *)props children:(NSArray *)children globalProps:(NSDictionary *)globalProps bridge:(RCTBridge *)bridge
{
  NSString *component = props[@"component"];
  if (!component) return nil;

  NSDictionary *passProps = props[@"passProps"];
  NSDictionary *navigatorStyle = props[@"style"];

  NSMutableDictionary *mergedProps = [NSMutableDictionary dictionaryWithDictionary:globalProps];
  [mergedProps addEntriesFromDictionary:passProps];
  
  RCTRootView *reactView = [[RCTRootView alloc] initWithBridge:bridge moduleName:component initialProperties:mergedProps];
  if (!reactView) return nil;
  
  if (mergedProps[@"loadingImage"]) {
    // Create loading view
    NSString *loadingImageName = mergedProps[@"loadingImage"];
    UIImage *image = [UIImage imageNamed:loadingImageName];
    if (image) {
      UIImageView *imageView = [[UIImageView alloc] initWithFrame:(CGRect){CGPointZero, RCTScreenSize()}];
      imageView.contentMode = UIViewContentModeScaleAspectFill;
      imageView.image = image;
      reactView.loadingView = imageView;
      reactView.loadingViewFadeDelay = 0.5;
      reactView.loadingViewFadeDuration = 0.3;
    }
  }

  self = [super init];
  if (!self) return nil;

  [self commonInit:reactView navigatorStyle:navigatorStyle];

  return self;
}

- (instancetype)initWithComponent:(NSString *)component passProps:(NSDictionary *)passProps navigatorStyle:(NSDictionary*)navigatorStyle globalProps:(NSDictionary *)globalProps bridge:(RCTBridge *)bridge
{
  NSMutableDictionary *mergedProps = [NSMutableDictionary dictionaryWithDictionary:globalProps];
  [mergedProps addEntriesFromDictionary:passProps];
  
  RCTRootView *reactView = [[RCTRootView alloc] initWithBridge:bridge moduleName:component initialProperties:mergedProps];
  if (!reactView) return nil;

  self = [super init];
  if (!self) return nil;

  [self commonInit:reactView navigatorStyle:navigatorStyle];

  return self;
}

- (void)commonInit:(RCTRootView*)reactView navigatorStyle:(NSDictionary*)navigatorStyle
{
  self.view = reactView;
  
  self.edgesForExtendedLayout = UIRectEdgeNone; // default
  self.automaticallyAdjustsScrollViewInsets = NO; // default
  
  self.navigatorStyle = [NSMutableDictionary dictionaryWithDictionary:navigatorStyle];
  
  [self setStyleOnInit];
  
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onRNReload) name:RCTReloadNotification object:nil];
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)onRNReload
{
  [[NSNotificationCenter defaultCenter] removeObserver:self.view];
  self.view = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
   
  [self setStyleOnAppear];
}

- (void)viewWillDisappear:(BOOL)animated
{
  [super viewWillDisappear:animated];
 
  [self setStyleOnDisappear];
}

// most styles should be set here since when we pop a view controller that changed them
// we want to reset the style to what we expect (so we need to reset on every willAppear)
- (void)setStyleOnAppear
{
  NSString *navBarBackgroundColor = self.navigatorStyle[@"navBarBackgroundColor"];
  if (navBarBackgroundColor)
  {
    UIColor *color = navBarBackgroundColor != (id)[NSNull null] ? [RCTConvert UIColor:navBarBackgroundColor] : nil;
    self.navigationController.navigationBar.barTintColor = color;
  }
  else
  {
    self.navigationController.navigationBar.barTintColor = nil;
  }
  
  NSString *navBarTextColor = self.navigatorStyle[@"navBarTextColor"];
  NSString *navBarFont = self.navigatorStyle[@"navBarFontName"];
  NSNumber *navBarFontSize = self.navigatorStyle[@"navBarFontSize"] ? self.navigatorStyle[@"navBarFontSize"] : @(17.0);
  if (navBarTextColor || navBarFont || navBarFontSize)
  {
    UIFont *font = (navBarFont && navBarFont != (id)[NSNull null]) ? [UIFont fontWithName:navBarFont size:[navBarFontSize floatValue]] : [UIFont systemFontOfSize:[navBarFontSize floatValue] weight:UIFontWeightSemibold];
    UIColor *color = (navBarTextColor && navBarTextColor != (id)[NSNull null]) ? [RCTConvert UIColor:navBarTextColor] : [UIColor blackColor];
    [self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName : color, UITextAttributeFont: font}];
  }
  else
  {
    [self.navigationController.navigationBar setTitleTextAttributes:nil];
  }
  
  NSString *navBarButtonColor = self.navigatorStyle[@"navBarButtonColor"];
  if (navBarButtonColor)
  {
    UIColor *color = navBarButtonColor != (id)[NSNull null] ? [RCTConvert UIColor:navBarButtonColor] : nil;
    self.navigationController.navigationBar.tintColor = color;
  }
  else
  {
    self.navigationController.navigationBar.tintColor = nil;
  }
  
  NSString *statusBarTextColorScheme = self.navigatorStyle[@"statusBarTextColorScheme"];
  if (statusBarTextColorScheme && [statusBarTextColorScheme isEqualToString:@"light"])
  {
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    self._statusBarTextColorSchemeLight = YES;
  }
  else
  {
    self.navigationController.navigationBar.barStyle = UIBarStyleDefault;
    self._statusBarTextColorSchemeLight = NO;
  }
  
  NSNumber *navBarHidden = self.navigatorStyle[@"navBarHidden"];
  BOOL navBarHiddenBool = navBarHidden ? [navBarHidden boolValue] : NO;
  if (self.navigationController.navigationBarHidden != navBarHiddenBool)
  {
    [self.navigationController setNavigationBarHidden:navBarHiddenBool animated:YES];
  }
  
  NSNumber *navBarHideOnScroll = self.navigatorStyle[@"navBarHideOnScroll"];
  BOOL navBarHideOnScrollBool = navBarHideOnScroll ? [navBarHideOnScroll boolValue] : NO;
  if (navBarHideOnScrollBool)
  {
    self.navigationController.hidesBarsOnSwipe = YES;
  }
  else
  {
    self.navigationController.hidesBarsOnSwipe = NO;
  }
  
  NSNumber *statusBarBlur = self.navigatorStyle[@"statusBarBlur"];
  BOOL statusBarBlurBool = statusBarBlur ? [statusBarBlur boolValue] : NO;
  if (statusBarBlurBool)
  {
    if (![self.view viewWithTag:BLUR_STATUS_TAG])
    {
      UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
      blur.frame = [[UIApplication sharedApplication] statusBarFrame];
      blur.tag = BLUR_STATUS_TAG;
      [self.view addSubview:blur];
    }
  }
  
  NSNumber *navBarBlur = self.navigatorStyle[@"navBarBlur"];
  BOOL navBarBlurBool = navBarBlur ? [navBarBlur boolValue] : NO;
  if (navBarBlurBool)
  {
    if (![self.navigationController.navigationBar viewWithTag:BLUR_NAVBAR_TAG])
    {
      NSMutableDictionary *originalNavBarImages = [@{} mutableCopy];
      UIImage *bgImage = [self.navigationController.navigationBar backgroundImageForBarMetrics:UIBarMetricsDefault];
      if (bgImage != nil)
      {
        originalNavBarImages[@"bgImage"] = bgImage;
      }
      UIImage *shadowImage = self.navigationController.navigationBar.shadowImage;
      if (shadowImage != nil)
      {
        originalNavBarImages[@"shadowImage"] = shadowImage;
      }
      self.originalNavBarImages = originalNavBarImages;
      
      [self.navigationController.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
      self.navigationController.navigationBar.shadowImage = [UIImage new];
      UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
      CGRect statusBarFrame = [[UIApplication sharedApplication] statusBarFrame];
      blur.frame = CGRectMake(0, -1 * statusBarFrame.size.height, self.navigationController.navigationBar.frame.size.width, self.navigationController.navigationBar.frame.size.height + statusBarFrame.size.height);
      blur.userInteractionEnabled = NO;
      blur.tag = BLUR_NAVBAR_TAG;
      [self.navigationController.navigationBar insertSubview:blur atIndex:0];
    }
  }
  else
  {
    UIView *blur = [self.navigationController.navigationBar viewWithTag:BLUR_NAVBAR_TAG];
    if (blur)
    {
      [blur removeFromSuperview];
      [self.navigationController.navigationBar setBackgroundImage:self.originalNavBarImages[@"bgImage"] forBarMetrics:UIBarMetricsDefault];
      self.navigationController.navigationBar.shadowImage = self.originalNavBarImages[@"shadowImage"];
      self.originalNavBarImages = nil;
    }
  }
  
  NSNumber *navBarTranslucent = self.navigatorStyle[@"navBarTranslucent"];
  BOOL navBarTranslucentBool = navBarTranslucent ? [navBarTranslucent boolValue] : NO;
  if (navBarTranslucentBool || navBarBlurBool)
  {
    self.navigationController.navigationBar.translucent = YES;
  }
  else
  {
    self.navigationController.navigationBar.translucent = NO;
  }
  
  NSNumber *drawUnderNavBar = self.navigatorStyle[@"drawUnderNavBar"];
  BOOL drawUnderNavBarBool = drawUnderNavBar ? [drawUnderNavBar boolValue] : NO;
  if (drawUnderNavBarBool)
  {
    self.edgesForExtendedLayout |= UIRectEdgeTop;
  }
  else
  {
    self.edgesForExtendedLayout &= ~UIRectEdgeTop;
  }
  
  NSNumber *drawUnderTabBar = self.navigatorStyle[@"drawUnderTabBar"];
  BOOL drawUnderTabBarBool = drawUnderTabBar ? [drawUnderTabBar boolValue] : NO;
  if (drawUnderTabBarBool)
  {
    self.edgesForExtendedLayout |= UIRectEdgeBottom;
  }
  else
  {
    self.edgesForExtendedLayout &= ~UIRectEdgeBottom;
  }
  
  NSNumber *removeNavBarBorder = self.navigatorStyle[@"navBarNoBorder"];
  BOOL removeNavBarBorderBool = removeNavBarBorder ? [removeNavBarBorder boolValue] : NO;
  if(removeNavBarBorderBool)
  {
      self.navBarHairlineImageView.hidden = YES;
  }
  else
  {
    self.navBarHairlineImageView.hidden = NO;
  }
  
  
  if (self.navigationController) {
    if (self == [self.navigationController.viewControllers firstObject]) {
      [[NSNotificationCenter defaultCenter] postNotificationName:@"didAppearNavigationRootController" object:nil];
    } else {
      [[NSNotificationCenter defaultCenter] postNotificationName:@"didAppearNavigationNonRootController" object:nil];
    }
  }
}

-(void)setStyleOnDisappear
{
  self.navBarHairlineImageView.hidden = NO;
}

// only styles that can't be set on willAppear should be set here
- (void)setStyleOnInit
{
  NSNumber *tabBarHidden = self.navigatorStyle[@"tabBarHidden"];
  BOOL tabBarHiddenBool = tabBarHidden ? [tabBarHidden boolValue] : NO;
  if (tabBarHiddenBool)
  {
    self._hidesBottomBarWhenPushed = YES;
  }
  else
  {
    self._hidesBottomBarWhenPushed = NO;
  }
  
  NSNumber *statusBarHideWithNavBar = self.navigatorStyle[@"statusBarHideWithNavBar"];
  BOOL statusBarHideWithNavBarBool = statusBarHideWithNavBar ? [statusBarHideWithNavBar boolValue] : NO;
  if (statusBarHideWithNavBarBool)
  {
    self._statusBarHideWithNavBar = YES;
  }
  else
  {
    self._statusBarHideWithNavBar = NO;
  }
  
  NSNumber *statusBarHidden = self.navigatorStyle[@"statusBarHidden"];
  BOOL statusBarHiddenBool = statusBarHidden ? [statusBarHidden boolValue] : NO;
  if (statusBarHiddenBool)
  {
    self._statusBarHidden = YES;
  }
  else
  {
    self._statusBarHidden = NO;
  }
}

- (BOOL)hidesBottomBarWhenPushed
{
  if (!self._hidesBottomBarWhenPushed) return NO;
  return (self.navigationController.topViewController == self);
}

- (BOOL)prefersStatusBarHidden
{
  if (self._statusBarHidden)
  {
    return YES;
  }
  if (self._statusBarHideWithNavBar)
  {
    return self.navigationController.isNavigationBarHidden;
  }
  else
  {
    return NO;
  }
}

- (void)setNavBarVisibilityChange:(BOOL)animated {
    [self.navigationController setNavigationBarHidden:[self.navigatorStyle[@"navBarHidden"] boolValue] animated:animated];
}


- (UIStatusBarStyle)preferredStatusBarStyle
{
  if (self._statusBarTextColorSchemeLight)
  {
    return UIStatusBarStyleLightContent;
  }
  else
  {
    return UIStatusBarStyleDefault;
  }
}

- (UIImageView *)findHairlineImageViewUnder:(UIView *)view {
  if ([view isKindOfClass:UIImageView.class] && view.bounds.size.height <= 1.0) {
    return (UIImageView *)view;
  }
  for (UIView *subview in view.subviews) {
    UIImageView *imageView = [self findHairlineImageViewUnder:subview];
    if (imageView) {
      return imageView;
    }
  }
  return nil;
}

@end
