//
//  ViewPagerController.m
//  ICViewPager
//
//  Created by Ilter Cengiz on 28/08/2013.
//  Copyright (c) 2013 Ilter Cengiz. All rights reserved.
//

#import "ViewPagerController.h"

#pragma mark - Constants and macros
#define kTabViewTag 38
#define kContentViewTag 34
#define IOS_VERSION_7 [[[UIDevice currentDevice] systemVersion] compare:@"7.0" options:NSNumericSearch] != NSOrderedAscending

#define kTabHeight 56.0
#define kTabOffset 10.0
#define kTabWidth 90.0
#define kTabLocation 1.0
#define kStartFromSecondTab 0.0
#define kCenterCurrentTab 0.0
#define kFixFormerTabsPositions 0.0
#define kFixLatterTabsPositions 0.0
#define kTabPadding 5.0


#define kIndicatorColor [UIColor colorWithRed:178.0/255.0 green:203.0/255.0 blue:57.0/255.0 alpha:0.75]
#define kTabsViewBackgroundColor [UIColor colorWithWhite:1.0 alpha:1.0]
#define kContentViewBackgroundColor [UIColor colorWithRed:248.0/255.0 green:248.0/255.0 blue:248.0/255.0 alpha:0.75]

#pragma mark - UIColor+Equality
@interface UIColor (Equality)
- (BOOL)isEqualToColor:(UIColor *)otherColor;
@end

@implementation UIColor (Equality)
// This method checks if two UIColors are the same
// Thanks to @samvermette for this method: http://stackoverflow.com/a/8899384/1931781
- (BOOL)isEqualToColor:(UIColor *)otherColor {

    CGColorSpaceRef colorSpaceRGB = CGColorSpaceCreateDeviceRGB();

    UIColor *(^convertColorToRGBSpace)(UIColor *) = ^(UIColor *color) {
        if (CGColorSpaceGetModel(CGColorGetColorSpace(color.CGColor)) == kCGColorSpaceModelMonochrome) {
            const CGFloat *oldComponents = CGColorGetComponents(color.CGColor);
            CGFloat components[4] = {oldComponents[0], oldComponents[0], oldComponents[0], oldComponents[1]};
            return [UIColor colorWithCGColor:CGColorCreate(colorSpaceRGB, components)];
        } else {
            return color;
        }
    };

    UIColor *selfColor = convertColorToRGBSpace(self);
    otherColor = convertColorToRGBSpace(otherColor);
    CGColorSpaceRelease(colorSpaceRGB);

    return [selfColor isEqual:otherColor];
}
@end

#pragma mark - TabView
@class TabView;

@interface TabView : UIView
@property (nonatomic, getter = isSelected) BOOL selected;
@property (nonatomic) UIColor *indicatorColor;
@end

@implementation TabView
- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}
- (void)setSelected:(BOOL)selected {
    _selected = selected;
    // Update view as state changed
    [self setNeedsDisplay];
}
- (void)drawRect:(CGRect)rect {

    [super drawRect:rect];
    self.layer.borderWidth = 0.5;
    self.layer.borderColor = [UIColor colorWithWhite:0 alpha:0.1].CGColor;

    UIBezierPath *bezierPath;
    // Draw top line
    bezierPath = [UIBezierPath bezierPath];
    [bezierPath moveToPoint:CGPointMake(0.0, 0.0)];
    [bezierPath addLineToPoint:CGPointMake(CGRectGetWidth(rect), 0.0)];
    [[UIColor colorWithWhite:197.0/255.0 alpha:0.75] setStroke];
    [bezierPath setLineWidth:1.0];
    [bezierPath stroke];

    // Draw bottom line
    bezierPath = [UIBezierPath bezierPath];
    [bezierPath moveToPoint:CGPointMake(0.0, CGRectGetHeight(rect))];
    [bezierPath addLineToPoint:CGPointMake(CGRectGetWidth(rect), CGRectGetHeight(rect))];
    [[UIColor colorWithWhite:197.0/255.0 alpha:0.75] setStroke];
    [bezierPath setLineWidth:1.0];
    [bezierPath stroke];

    // Draw an indicator line if tab is selected
    if (self.selected) {

        bezierPath = [UIBezierPath bezierPath];

        // Draw the indicator
        [bezierPath moveToPoint:CGPointMake(0.0, CGRectGetHeight(rect) - 1.0)];
        [bezierPath addLineToPoint:CGPointMake(CGRectGetWidth(rect), CGRectGetHeight(rect) - 1.0)];
        [bezierPath setLineWidth:3.0];
        [self.indicatorColor setStroke];
        [bezierPath stroke];
    }

}
@end

#pragma mark - ViewPagerController
@interface ViewPagerController () <UIPageViewControllerDataSource, UIPageViewControllerDelegate, UIScrollViewDelegate, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout>

// Tab and content stuff
@property (nonatomic) UICollectionView *tabsView;
@property (nonatomic) UIView *contentView;

@property UIPageViewController *pageViewController;
@property (assign) id<UIScrollViewDelegate> actualDelegate;

// Tab and content cache
@property NSMutableArray *tabs;
@property NSMutableArray *contents;

// Options
@property (nonatomic) NSNumber *tabHeight;
@property (nonatomic) NSNumber *tabOffset;
@property (nonatomic) NSNumber *tabWidth;
@property (nonatomic) NSNumber *tabLocation;
@property (nonatomic) NSNumber *startFromSecondTab;
@property (nonatomic) NSNumber *centerCurrentTab;
@property (nonatomic) NSNumber *fixFormerTabsPositions;
@property (nonatomic) NSNumber *fixLatterTabsPositions;

@property (nonatomic) NSArray *verticalConstraintsArray;
@property (nonatomic) NSArray *contentViewConstraints;
@property (nonatomic) NSArray *tabsViewConstraints;

@property (nonatomic) NSUInteger tabCount;
@property (nonatomic) NSUInteger activeTabIndex;
@property (nonatomic) NSUInteger activeContentIndex;

@property (getter = isAnimatingToTab, assign) BOOL animatingToTab;
@property (getter = isDefaultSetupDone, assign) BOOL defaultSetupDone;

// Colors
@property (nonatomic) UIColor *indicatorColor;
@property (nonatomic) UIColor *tabsViewBackgroundColor;
@property (nonatomic) UIColor *contentViewBackgroundColor;

@end

@implementation ViewPagerController

@synthesize tabHeight = _tabHeight;
@synthesize tabOffset = _tabOffset;
@synthesize tabWidth = _tabWidth;
@synthesize tabLocation = _tabLocation;
@synthesize startFromSecondTab = _startFromSecondTab;
@synthesize centerCurrentTab = _centerCurrentTab;
@synthesize fixFormerTabsPositions = _fixFormerTabsPositions;
@synthesize fixLatterTabsPositions = _fixLatterTabsPositions;

#pragma mark - Init
- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self defaultSettings];
    }
    return self;
}
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [self defaultSettings];
    }
    return self;
}

#pragma mark - View life cycle
- (void)viewDidLoad {
    [super viewDidLoad];
    self.edgesForExtendedLayout = UIRectEdgeNone;
}
- (void)viewWillAppear:(BOOL)animated {

    [super viewWillAppear:animated];
    // Do setup if it's not done yet
    if (![self isDefaultSetupDone]) {
        [self defaultSetup];
    }

    [self.contentView setNeedsLayout];
}

-(void)viewDidLayoutSubviews {
    [self.view layoutIfNeeded];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}



#pragma mark - IBAction
- (IBAction)handleTapGesture:(id)sender {

    // Get the desired page's index
    UITapGestureRecognizer *tapGestureRecognizer = (UITapGestureRecognizer *)sender;
    UIView *tabView = tapGestureRecognizer.view;
    __block NSUInteger index = [self.tabs indexOfObject:tabView];

    //if Tap is not selected Tab(new Tab)
    if (self.activeTabIndex != index) {
        // Select the tab
        [self selectTabAtIndex:index];
    }
}


#pragma mark - Setters
- (void)setTabHeight:(NSNumber *)tabHeight {

    if ([tabHeight floatValue] < 4.0)
        tabHeight = [NSNumber numberWithFloat:4.0];
    else if ([tabHeight floatValue] > CGRectGetHeight(self.view.frame))
        tabHeight = [NSNumber numberWithFloat:CGRectGetHeight(self.view.frame)];

    _tabHeight = tabHeight;
}
- (void)setTabOffset:(NSNumber *)tabOffset {

    if ([tabOffset floatValue] < 0.0)
        tabOffset = [NSNumber numberWithFloat:0.0];
    else if ([tabOffset floatValue] > CGRectGetWidth(self.view.frame) - [self.tabWidth floatValue])
        tabOffset = [NSNumber numberWithFloat:CGRectGetWidth(self.view.frame) - [self.tabWidth floatValue]];

    _tabOffset = tabOffset;
}
- (void)setTabWidth:(NSNumber *)tabWidth {

    if ([tabWidth floatValue] < 4.0)
        tabWidth = [NSNumber numberWithFloat:4.0];
    else if ([tabWidth floatValue] > CGRectGetWidth(self.view.frame))
        tabWidth = [NSNumber numberWithFloat:CGRectGetWidth(self.view.frame)];

    _tabWidth = tabWidth;
}
- (void)setTabLocation:(NSNumber *)tabLocation {

    if ([tabLocation floatValue] != 1.0 && [tabLocation floatValue] != 0.0)
        tabLocation = [tabLocation boolValue] ? [NSNumber numberWithBool:YES] : [NSNumber numberWithBool:NO];

    _tabLocation = tabLocation;
}
- (void)setStartFromSecondTab:(NSNumber *)startFromSecondTab {

    if ([startFromSecondTab floatValue] != 1.0 && [startFromSecondTab floatValue] != 0.0)
        startFromSecondTab = [startFromSecondTab boolValue] ? [NSNumber numberWithBool:YES] : [NSNumber numberWithBool:NO];

    _startFromSecondTab = startFromSecondTab;
}
- (void)setCenterCurrentTab:(NSNumber *)centerCurrentTab {

    if ([centerCurrentTab floatValue] != 1.0 && [centerCurrentTab floatValue] != 0.0)
        centerCurrentTab = [centerCurrentTab boolValue] ? [NSNumber numberWithBool:YES] : [NSNumber numberWithBool:NO];

    _centerCurrentTab = centerCurrentTab;
}
- (void)setFixFormerTabsPositions:(NSNumber *)fixFormerTabsPositions {

    if ([fixFormerTabsPositions floatValue] != 1.0 && [fixFormerTabsPositions floatValue] != 0.0)
        fixFormerTabsPositions = [fixFormerTabsPositions boolValue] ? [NSNumber numberWithBool:YES] : [NSNumber numberWithBool:NO];

    _fixFormerTabsPositions = fixFormerTabsPositions;
}
- (void)setFixLatterTabsPositions:(NSNumber *)fixLatterTabsPositions {

    if ([fixLatterTabsPositions floatValue] != 1.0 && [fixLatterTabsPositions floatValue] != 0.0)
        fixLatterTabsPositions = [fixLatterTabsPositions boolValue] ? [NSNumber numberWithBool:YES] : [NSNumber numberWithBool:NO];

    _fixLatterTabsPositions = fixLatterTabsPositions;
}

- (void)setActiveTabIndex:(NSUInteger)activeTabIndex {


    [self.tabsView deselectItemAtIndexPath:[self.tabsView indexPathsForSelectedItems].lastObject animated:YES];

    [self.tabsView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:activeTabIndex inSection:0] atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally animated:YES];
}
- (void)setActiveContentIndex:(NSUInteger)activeContentIndex {

    // Get the desired viewController
    UIViewController *viewController = [self viewControllerAtIndex:activeContentIndex];

    if (!viewController) {
        viewController = [[UIViewController alloc] init];
        viewController.view = [[UIView alloc] init];
        viewController.view.backgroundColor = [UIColor clearColor];
    }

    // __weak pageViewController to be used in blocks to prevent retaining strong reference to self
    __weak UIPageViewController *weakPageViewController = self.pageViewController;
    __weak ViewPagerController *weakSelf = self;

    if (activeContentIndex == self.activeContentIndex) {

        [self.pageViewController setViewControllers:@[viewController]
                                          direction:UIPageViewControllerNavigationDirectionForward
                                           animated:NO
                                         completion:^(BOOL completed) {
                                             weakSelf.animatingToTab = NO;
                                         }];

    } else if (!(activeContentIndex + 1 == self.activeContentIndex || activeContentIndex - 1 == self.activeContentIndex)) {

        [self.pageViewController setViewControllers:@[viewController]
                                          direction:(activeContentIndex < self.activeContentIndex) ? UIPageViewControllerNavigationDirectionReverse : UIPageViewControllerNavigationDirectionForward
                                           animated:YES
                                         completion:^(BOOL completed) {

                                             weakSelf.animatingToTab = NO;

                                             // Set the current page again to obtain synchronisation between tabs and content
                                             dispatch_async(dispatch_get_main_queue(), ^{
                                                 [weakPageViewController setViewControllers:@[viewController]
                                                                                  direction:(activeContentIndex < weakSelf.activeContentIndex) ? UIPageViewControllerNavigationDirectionReverse : UIPageViewControllerNavigationDirectionForward
                                                                                   animated:NO
                                                                                 completion:nil];
                                             });
                                         }];

    } else {

        [self.pageViewController setViewControllers:@[viewController]
                                          direction:(activeContentIndex < self.activeContentIndex) ? UIPageViewControllerNavigationDirectionReverse : UIPageViewControllerNavigationDirectionForward
                                           animated:YES
                                         completion:^(BOOL completed) {
                                             weakSelf.animatingToTab = NO;
                                         }];
    }

    // Clean out of sight contents
    NSInteger index;
    index = self.activeContentIndex - 1;
    if (index >= 0 &&
        index != activeContentIndex &&
        index != activeContentIndex - 1)
    {
        [self.contents replaceObjectAtIndex:index withObject:[NSNull null]];
    }
    index = self.activeContentIndex;
    if (index != activeContentIndex - 1 &&
        index != activeContentIndex &&
        index != activeContentIndex + 1)
    {
        [self.contents replaceObjectAtIndex:index withObject:[NSNull null]];
    }
    index = self.activeContentIndex + 1;
    if (index < self.contents.count &&
        index != activeContentIndex &&
        index != activeContentIndex + 1)
    {
        [self.contents replaceObjectAtIndex:index withObject:[NSNull null]];
    }

    _activeContentIndex = activeContentIndex;
}

#pragma mark - Getters
- (NSNumber *)tabHeight {

    if (!_tabHeight) {
        CGFloat value = kTabHeight;
        if ([self.delegate respondsToSelector:@selector(viewPager:valueForOption:withDefault:)])
            value = [self.delegate viewPager:self valueForOption:ViewPagerOptionTabHeight withDefault:value];
        self.tabHeight = [NSNumber numberWithFloat:value];
    }
    return _tabHeight;
}
- (NSNumber *)tabOffset {

    if (!_tabOffset) {
        CGFloat value = kTabOffset;
        if ([self.delegate respondsToSelector:@selector(viewPager:valueForOption:withDefault:)])
            value = [self.delegate viewPager:self valueForOption:ViewPagerOptionTabOffset withDefault:value];
        self.tabOffset = [NSNumber numberWithFloat:value];
    }
    return _tabOffset;
}
- (NSNumber *)tabWidth {

    if (!_tabWidth) {
        CGFloat value = kTabWidth;
        if ([self.delegate respondsToSelector:@selector(viewPager:valueForOption:withDefault:)])
            value = [self.delegate viewPager:self valueForOption:ViewPagerOptionTabWidth withDefault:value];
        self.tabWidth = [NSNumber numberWithFloat:value];
    }
    return _tabWidth;
}
- (NSNumber *)tabLocation {

    if (!_tabLocation) {
        CGFloat value = kTabLocation;
        if ([self.delegate respondsToSelector:@selector(viewPager:valueForOption:withDefault:)])
            value = [self.delegate viewPager:self valueForOption:ViewPagerOptionTabLocation withDefault:value];
        self.tabLocation = [NSNumber numberWithFloat:value];
    }
    return _tabLocation;
}
- (NSNumber *)startFromSecondTab {

    if (!_startFromSecondTab) {
        CGFloat value = kStartFromSecondTab;
        if ([self.delegate respondsToSelector:@selector(viewPager:valueForOption:withDefault:)])
            value = [self.delegate viewPager:self valueForOption:ViewPagerOptionStartFromSecondTab withDefault:value];
        self.startFromSecondTab = [NSNumber numberWithFloat:value];
    }
    return _startFromSecondTab;
}

- (NSNumber *)centerCurrentTab {

    if (!_centerCurrentTab) {
        CGFloat value = kCenterCurrentTab;
        if ([self.delegate respondsToSelector:@selector(viewPager:valueForOption:withDefault:)])
            value = [self.delegate viewPager:self valueForOption:ViewPagerOptionCenterCurrentTab withDefault:value];
        self.centerCurrentTab = [NSNumber numberWithFloat:value];
    }
    return _centerCurrentTab;
}
- (NSNumber *)fixFormerTabsPositions {

    if (!_fixFormerTabsPositions) {
        CGFloat value = kFixFormerTabsPositions;
        if ([self.delegate respondsToSelector:@selector(viewPager:valueForOption:withDefault:)])
            value = [self.delegate viewPager:self valueForOption:ViewPagerOptionFixFormerTabsPositions withDefault:value];
        self.fixFormerTabsPositions = [NSNumber numberWithFloat:value];
    }
    return _fixFormerTabsPositions;
}
- (NSNumber *)fixLatterTabsPositions {

    if (!_fixLatterTabsPositions) {
        CGFloat value = kFixLatterTabsPositions;
        if ([self.delegate respondsToSelector:@selector(viewPager:valueForOption:withDefault:)])
            value = [self.delegate viewPager:self valueForOption:ViewPagerOptionFixLatterTabsPositions withDefault:value];
        self.fixLatterTabsPositions = [NSNumber numberWithFloat:value];
    }
    return _fixLatterTabsPositions;
}

- (UIColor *)indicatorColor {

    if (!_indicatorColor) {
        UIColor *color = kIndicatorColor;
        if ([self.delegate respondsToSelector:@selector(viewPager:colorForComponent:withDefault:)]) {
            color = [self.delegate viewPager:self colorForComponent:ViewPagerIndicator withDefault:color];
        }
        self.indicatorColor = color;
    }
    return _indicatorColor;
}
- (UIColor *)tabsViewBackgroundColor {

    if (!_tabsViewBackgroundColor) {
        UIColor *color = kTabsViewBackgroundColor;
        if ([self.delegate respondsToSelector:@selector(viewPager:colorForComponent:withDefault:)]) {
            color = [self.delegate viewPager:self colorForComponent:ViewPagerTabsView withDefault:color];
        }
        self.tabsViewBackgroundColor = color;
    }
    return _tabsViewBackgroundColor;
}
- (UIColor *)contentViewBackgroundColor {

    if (!_contentViewBackgroundColor) {
        UIColor *color = kContentViewBackgroundColor;
        if ([self.delegate respondsToSelector:@selector(viewPager:colorForComponent:withDefault:)]) {
            color = [self.delegate viewPager:self colorForComponent:ViewPagerContent withDefault:color];
        }
        self.contentViewBackgroundColor = color;
    }
    return _contentViewBackgroundColor;
}

#pragma mark - Public methods
- (void)reloadData {

    // Empty all options and colors
    // So that, ViewPager will reflect the changes
    // Empty all options
    _tabHeight = nil;
    _tabOffset = nil;
    _tabWidth = nil;
    _tabLocation = nil;
    _startFromSecondTab = nil;
    _centerCurrentTab = nil;
    _fixFormerTabsPositions = nil;
    _fixLatterTabsPositions = nil;

    // Empty all colors
    _indicatorColor = nil;
    _tabsViewBackgroundColor = nil;
    _contentViewBackgroundColor = nil;

    [self setNeedsReloadOptions];

    // Call to setup again with the updated data
    [self defaultSetup];
    [self.tabsView reloadData];

}
- (void)selectTabAtIndex:(NSUInteger)index {

    if (index >= self.tabCount) {
        return;
    }

    self.animatingToTab = YES;

    // Set activeTabIndex
    self.activeTabIndex = index;

    // Set activeContentIndex
    self.activeContentIndex = index;

    [self.tabsView selectItemAtIndexPath:[NSIndexPath indexPathForItem:index inSection:0] animated:YES scrollPosition:UICollectionViewScrollPositionCenteredHorizontally];

    // Inform delegate about the change
    if ([self.delegate respondsToSelector:@selector(viewPager:didChangeTabToIndex:)]) {
        [self.delegate viewPager:self didChangeTabToIndex:self.activeTabIndex];
    }
}

- (void)setNeedsReloadOptions {

    // If our delegate doesn't respond to our options method, return
    // Otherwise reload options
    if (![self.delegate respondsToSelector:@selector(viewPager:valueForOption:withDefault:)]) {
        return;
    }

    // Update these options
    self.tabWidth = [NSNumber numberWithFloat:[self.delegate viewPager:self valueForOption:ViewPagerOptionTabWidth withDefault:kTabWidth]];
    self.tabOffset = [NSNumber numberWithFloat:[self.delegate viewPager:self valueForOption:ViewPagerOptionTabOffset withDefault:kTabOffset]];
    self.centerCurrentTab = [NSNumber numberWithFloat:[self.delegate viewPager:self valueForOption:ViewPagerOptionCenterCurrentTab withDefault:kCenterCurrentTab]];
    self.fixFormerTabsPositions = [NSNumber numberWithFloat:[self.delegate viewPager:self valueForOption:ViewPagerOptionFixFormerTabsPositions withDefault:kFixFormerTabsPositions]];
    self.fixLatterTabsPositions = [NSNumber numberWithFloat:[self.delegate viewPager:self valueForOption:ViewPagerOptionFixLatterTabsPositions withDefault:kFixLatterTabsPositions]];


    // Update tabsView's contentSize with the new width
    // self.tabsView.contentSize = CGSizeMake(contentSizeWidth, [self.tabHeight floatValue]);
    self.tabsView.dataSource = self;
    [self.tabsView reloadData];
}
- (void)setNeedsReloadColors {

    // If our delegate doesn't respond to our colors method, return
    // Otherwise reload colors
    if (![self.delegate respondsToSelector:@selector(viewPager:colorForComponent:withDefault:)]) {
        return;
    }

    // These colors will be updated
    UIColor *indicatorColor;
    UIColor *tabsViewBackgroundColor;
    UIColor *contentViewBackgroundColor;

    // Get indicatorColor and check if it is different from the current one
    // If it is, update it
    indicatorColor = [self.delegate viewPager:self colorForComponent:ViewPagerIndicator withDefault:kIndicatorColor];

    if (![self.indicatorColor isEqualToColor:indicatorColor]) {

        // We will iterate through all of the tabs to update its indicatorColor
        [self.tabs enumerateObjectsUsingBlock:^(TabView *tabView, NSUInteger index, BOOL *stop) {
            tabView.indicatorColor = indicatorColor;
        }];

        // Update indicatorColor to check again later
        self.indicatorColor = indicatorColor;
    }

    // Get tabsViewBackgroundColor and check if it is different from the current one
    // If it is, update it
    tabsViewBackgroundColor = [self.delegate viewPager:self colorForComponent:ViewPagerTabsView withDefault:kTabsViewBackgroundColor];

    if (![self.tabsViewBackgroundColor isEqualToColor:tabsViewBackgroundColor]) {

        // Update it
        self.tabsView.backgroundColor = tabsViewBackgroundColor;

        // Update tabsViewBackgroundColor to check again later
        self.tabsViewBackgroundColor = tabsViewBackgroundColor;
    }

    // Get contentViewBackgroundColor and check if it is different from the current one
    // Yeah update it, too
    contentViewBackgroundColor = [self.delegate viewPager:self colorForComponent:ViewPagerContent withDefault:kContentViewBackgroundColor];

    if (![self.contentViewBackgroundColor isEqualToColor:contentViewBackgroundColor]) {

        // Yup, update
        self.contentView.backgroundColor = contentViewBackgroundColor;

        // Update this, too, to check again later
        self.contentViewBackgroundColor = contentViewBackgroundColor;
    }

}

- (CGFloat)valueForOption:(ViewPagerOption)option {

    switch (option) {
        case ViewPagerOptionTabHeight:
            return [[self tabHeight] floatValue];
        case ViewPagerOptionTabOffset:
            return [[self tabOffset] floatValue];
        case ViewPagerOptionTabWidth:
            return [[self tabWidth] floatValue];
        case ViewPagerOptionTabLocation:
            return [[self tabLocation] floatValue];
        case ViewPagerOptionStartFromSecondTab:
            return [[self startFromSecondTab] floatValue];
        case ViewPagerOptionCenterCurrentTab:
            return [[self centerCurrentTab] floatValue];
        default:
            return NAN;
    }
}
- (UIColor *)colorForComponent:(ViewPagerComponent)component {

    switch (component) {
        case ViewPagerIndicator:
            return [self indicatorColor];
        case ViewPagerTabsView:
            return [self tabsViewBackgroundColor];
        case ViewPagerContent:
            return [self contentViewBackgroundColor];
        default:
            return [UIColor clearColor];
    }
}

#pragma mark - Private methods

- (void)updateViewConstraints {

    [super updateViewConstraints];

}


- (void)defaultSettings {

    // pageViewController
    self.pageViewController = [[UIPageViewController alloc] initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
                                                              navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                                                                            options:nil];
    [self addChildViewController:self.pageViewController];

    // Setup some forwarding events to hijack the scrollView
    // Keep a reference to the actual delegate
    self.actualDelegate = ((UIScrollView *)[self.pageViewController.view.subviews objectAtIndex:0]).delegate;
    // Set self as new delegate
    ((UIScrollView *)[self.pageViewController.view.subviews objectAtIndex:0]).delegate = self;

    self.pageViewController.dataSource = self;
    self.pageViewController.delegate = self;

    self.animatingToTab = NO;
    self.defaultSetupDone = NO;
}
- (void)defaultSetup {

    [self.tabs removeAllObjects];
    [self.contents removeAllObjects];

    // Get tabCount from dataSource
    self.tabCount = [self.dataSource numberOfTabsForViewPager:self];

    // Populate arrays with [NSNull null];
    self.tabs = [NSMutableArray arrayWithCapacity:self.tabCount];
    for (NSUInteger i = 0; i < self.tabCount; i++) {
        [self.tabs addObject:[NSNull null]];
    }

    self.contents = [NSMutableArray arrayWithCapacity:self.tabCount];
    for (NSUInteger i = 0; i < self.tabCount; i++) {
        [self.contents addObject:[NSNull null]];
    }

    // Add tabsView
    // self.tabsView = (UICollectionView *)[self.view viewWithTag:kTabViewTag];
    if (!self.tabsView) {
        UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
        layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
        self.tabsView = [[UICollectionView alloc] initWithFrame:CGRectMake(0.0, 0.0, CGRectGetWidth(self.view.frame), [self.tabHeight floatValue]) collectionViewLayout:layout];
        //UINib *tabNib = [UINib nibWithNibName:@"PagerTabCollectionViewCell" bundle:[NSBundle bundleForClass:[self class]]];
        [self.tabsView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"Cell"];
        self.tabsView.delegate = self;
        self.tabsView.dataSource = self;
        self.tabsView.backgroundColor = self.tabsViewBackgroundColor;
        self.tabsView.scrollsToTop = NO;
        self.tabsView.showsHorizontalScrollIndicator = NO;
        self.tabsView.showsVerticalScrollIndicator = NO;
        self.tabsView.tag = kTabViewTag;
        self.tabsView.translatesAutoresizingMaskIntoConstraints = NO;

        [self.view insertSubview:self.tabsView atIndex:0];
    }

    // Add contentView
    self.contentView = [self.view viewWithTag:kContentViewTag];

    if (!self.contentView) {

        self.contentView = self.pageViewController.view;
        self.contentView.backgroundColor = self.contentViewBackgroundColor;
        //self.contentView.frame = CGRectMake(self.view.bounds.origin.x, self.view.bounds.origin.y+self.tabHeight.floatValue, CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.frame));
        self.contentView.tag = kContentViewTag;
        self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.pageViewController willMoveToParentViewController:self];
        [self.view addSubview:self.contentView];
        [self.pageViewController didMoveToParentViewController:self];
    }

    // Select starting tab
    NSUInteger index = [self.startFromSecondTab boolValue] ? 1 : 0;

    if (_verticalConstraintsArray) {
        [self.view removeConstraints:_verticalConstraintsArray];
    }

    if (_contentViewConstraints) {
        [self.view removeConstraints:_contentViewConstraints];
    }

    if (_tabsViewConstraints) {
        [self.view removeConstraints:_tabsViewConstraints];
    }

    NSDictionary *views = @{@"contentView": self.contentView, @"tabsView": self.tabsView};

    _verticalConstraintsArray = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[tabsView(44)]-0-[contentView]-0-|" options:0 metrics:nil views:views];
    _contentViewConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[contentView]-0-|" options:0 metrics:nil views:views];
    _tabsViewConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[tabsView]-0-|" options:0 metrics:nil views:views];

    NSMutableArray *constraints = [NSMutableArray array];

    [constraints addObjectsFromArray:_verticalConstraintsArray];
    [constraints addObjectsFromArray:_contentViewConstraints];
    [constraints addObjectsFromArray:_tabsViewConstraints];

    [self.view addConstraints:constraints];

    // Set setup done
    self.defaultSetupDone = YES;
    self.tabsView.dataSource = self;
    [self.tabsView reloadData];
}

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [self.dataSource numberOfTabsForViewPager:self];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"Cell" forIndexPath:indexPath];

    [cell.contentView.subviews.lastObject removeFromSuperview];

    UIView *tabViewContent = [self tabViewAtIndex:indexPath.row];
    [cell.contentView addSubview:tabViewContent];
    tabViewContent.frame = CGRectMake(0, (cell.contentView.bounds.size.height-tabViewContent.bounds.size.height)/2, tabViewContent.bounds.size.width, tabViewContent.bounds.size.height);

    cell.contentView.center = tabViewContent.center;

    return cell;
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    UIView *tabViewContent = [self tabViewAtIndex:indexPath.row];
    [collectionView reloadData];
    return CGSizeMake(CGRectGetWidth(tabViewContent.bounds), [self.tabHeight floatValue]);
}

-(CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 0.0;
}

-(CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return 0.0;
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    TabView *activeTabView;

    // Set to-be-active tab selected
    activeTabView = [self.tabsView cellForItemAtIndexPath:indexPath].contentView.subviews.lastObject;
    activeTabView.selected = YES;

    [activeTabView setNeedsDisplay];

    // Set current activeTabIndex
    _activeTabIndex = indexPath.row;

    [self selectTabAtIndex:indexPath.row];
}

-(void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath {
    TabView *activeTabView;

    // Set to-be-active tab selected
    activeTabView = [self.tabsView cellForItemAtIndexPath:indexPath].contentView.subviews.lastObject;
    activeTabView.selected = NO;
}

- (TabView *)tabViewAtIndex:(NSUInteger)index {
    //
    //    if (index >= self.tabCount) {
    //        return nil;
    //    }
    //
    //    if ([[self.tabs objectAtIndex:index] isEqual:[NSNull null]]) {

    // Get view from dataSource
    UIView *tabViewContent = [self.dataSource viewPager:self viewForTabAtIndex:index];

    // Create TabView and subview the content
    TabView *tabView = [[TabView alloc] initWithFrame:CGRectMake(0.0, 0.0, CGRectGetWidth(tabViewContent.bounds)+ 32, [self.tabHeight floatValue])];

    [tabView addSubview:tabViewContent];
    [tabView setClipsToBounds:YES];
    [tabView setIndicatorColor:self.indicatorColor];

    tabViewContent.center = tabView.center;

    return tabView;
    //
    //        // Replace the null object with tabView
    //        [self.tabs replaceObjectAtIndex:index withObject:tabViewContent];
    //    }
    //
    //    return [self.tabs objectAtIndex:index];
}
- (NSUInteger)indexForTabView:(UIView *)tabView {

    return [self.tabs indexOfObject:tabView];
}

- (UIViewController *)viewControllerAtIndex:(NSUInteger)index {

    if (index >= self.tabCount) {
        return nil;
    }

    if ([[self.contents objectAtIndex:index] isEqual:[NSNull null]]) {

        UIViewController *viewController;

        if ([self.dataSource respondsToSelector:@selector(viewPager:contentViewControllerForTabAtIndex:)]) {
            viewController = [self.dataSource viewPager:self contentViewControllerForTabAtIndex:index];
        } else if ([self.dataSource respondsToSelector:@selector(viewPager:contentViewForTabAtIndex:)]) {

            UIView *view = [self.dataSource viewPager:self contentViewForTabAtIndex:index];

            // Adjust view's bounds to match the pageView's bounds
            UIView *pageView = [self.view viewWithTag:kContentViewTag];
            view.frame = pageView.bounds;

            viewController = [UIViewController new];
            viewController.view = view;
        } else {
            viewController = [[UIViewController alloc] init];
            viewController.view = [[UIView alloc] init];
        }

        [self.contents replaceObjectAtIndex:index withObject:viewController];
    }

    return [self.contents objectAtIndex:index];
}
- (NSUInteger)indexForViewController:(UIViewController *)viewController {

    return [self.contents indexOfObject:viewController];
}

#pragma mark - UIPageViewControllerDataSource
- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController {
    NSUInteger index = [self indexForViewController:viewController];
    index++;
    return [self viewControllerAtIndex:index];
}
- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController {
    NSUInteger index = [self indexForViewController:viewController];
    index--;
    return [self viewControllerAtIndex:index];
}

#pragma mark - UIPageViewControllerDelegate
- (void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray *)previousViewControllers transitionCompleted:(BOOL)completed {

    UIViewController *viewController = self.pageViewController.viewControllers[0];

    // Select tab
    NSUInteger index = [self indexForViewController:viewController];
    [self selectTabAtIndex:index];
}

#pragma mark - UIScrollViewDelegate, Responding to Scrolling and Dragging
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {

    //    if ([self.actualDelegate respondsToSelector:@selector(scrollViewDidScroll:)]) {
    //        [self.actualDelegate scrollViewDidScroll:scrollView];
    //    }
    //
    //    if (![self isAnimatingToTab]) {
    //        UIView *tabView = [self tabViewAtIndex:self.activeTabIndex];
    //
    //        // Get the related tab view position
    //        CGRect frame = tabView.frame;
    //
    //        CGFloat movedRatio = (scrollView.contentOffset.x / CGRectGetWidth(scrollView.frame)) - 1;
    //        frame.origin.x += movedRatio * CGRectGetWidth(frame);
    //
    //        if ([self.centerCurrentTab boolValue]) {
    //
    //            frame.origin.x += (frame.size.width / 2);
    //            frame.origin.x -= CGRectGetWidth(self.tabsView.frame) / 2;
    //            frame.size.width = CGRectGetWidth(self.tabsView.frame);
    //
    //            if (frame.origin.x < 0) {
    //                frame.origin.x = 0;
    //            }
    //
    //            if ((frame.origin.x + frame.size.width) > self.tabsView.contentSize.width) {
    //                frame.origin.x = (self.tabsView.contentSize.width - CGRectGetWidth(self.tabsView.frame));
    //            }
    //        } else {
    //
    //            frame.origin.x -= [self.tabOffset floatValue];
    //            frame.size.width = CGRectGetWidth(self.tabsView.frame);
    //        }
    //
    //        [self.tabsView scrollRectToVisible:frame animated:NO];
    //    }
}
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if ([self.actualDelegate respondsToSelector:@selector(scrollViewWillBeginDragging:)]) {
        [self.actualDelegate scrollViewWillBeginDragging:scrollView];
    }
}
- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
    if ([self.actualDelegate respondsToSelector:@selector(scrollViewWillEndDragging:withVelocity:targetContentOffset:)]) {
        [self.actualDelegate scrollViewWillEndDragging:scrollView withVelocity:velocity targetContentOffset:targetContentOffset];
    }
}
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate{
    if ([self.actualDelegate respondsToSelector:@selector(scrollViewDidEndDragging:willDecelerate:)]) {
        [self.actualDelegate scrollViewDidEndDragging:scrollView willDecelerate:decelerate];
    }
}
- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView{
    if ([self.actualDelegate respondsToSelector:@selector(scrollViewShouldScrollToTop:)]) {
        return [self.actualDelegate scrollViewShouldScrollToTop:scrollView];
    }
    return NO;
}
- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView {
    if ([self.actualDelegate respondsToSelector:@selector(scrollViewDidScrollToTop:)]) {
        [self.actualDelegate scrollViewDidScrollToTop:scrollView];
    }
}
- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView {
    if ([self.actualDelegate respondsToSelector:@selector(scrollViewWillBeginDecelerating:)]) {
        [self.actualDelegate scrollViewWillBeginDecelerating:scrollView];
    }
}
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if ([self.actualDelegate respondsToSelector:@selector(scrollViewDidEndDecelerating:)]) {
        [self.actualDelegate scrollViewDidEndDecelerating:scrollView];
    }
}

#pragma mark - UIScrollViewDelegate, Managing Zooming
- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    if ([self.actualDelegate respondsToSelector:@selector(viewForZoomingInScrollView:)]) {
        return [self.actualDelegate viewForZoomingInScrollView:scrollView];
    }
    return nil;
}
- (void)scrollViewWillBeginZooming:(UIScrollView *)scrollView withView:(UIView *)view {
    if ([self.actualDelegate respondsToSelector:@selector(scrollViewWillBeginZooming:withView:)]) {
        [self.actualDelegate scrollViewWillBeginZooming:scrollView withView:view];
    }
}
- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(CGFloat)scale {
    if ([self.actualDelegate respondsToSelector:@selector(scrollViewDidEndZooming:withView:atScale:)]) {
        [self.actualDelegate scrollViewDidEndZooming:scrollView withView:view atScale:scale];
    }
}
- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    if ([self.actualDelegate respondsToSelector:@selector(scrollViewDidZoom:)]) {
        [self.actualDelegate scrollViewDidZoom:scrollView];
    }
}

#pragma mark - UIScrollViewDelegate, Responding to Scrolling Animations
- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    if ([self.actualDelegate respondsToSelector:@selector(scrollViewDidEndScrollingAnimation:)]) {
        [self.actualDelegate scrollViewDidEndScrollingAnimation:scrollView];
    }
}

-(void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [self.view layoutIfNeeded];
    //    [self defaultSetup];
    [self.contentView setNeedsLayout];
}

-(NSUInteger)supportedInterfaceOrientations {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return UIInterfaceOrientationMaskAllButUpsideDown;
    } else {
        return UIInterfaceOrientationMaskPortrait;
    }
}

@end

