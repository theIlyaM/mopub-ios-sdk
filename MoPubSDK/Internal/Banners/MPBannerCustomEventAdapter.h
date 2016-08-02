//
//  MPBannerCustomEventAdapter.h
//  MoPub
//
//  Copyright (c) 2012 MoPub, Inc. All rights reserved.
//

#import "MPBaseBannerAdapter.h"

#import "MPPrivateBannerCustomEventDelegate.h"

#import "MPBannerCustomEvent.h"

@interface MPBannerCustomEventAdapter : MPBaseBannerAdapter <MPPrivateBannerCustomEventDelegate>

@property (nonatomic, strong) MPBannerCustomEvent *bannerCustomEvent;
@property (nonatomic, strong) MPAdConfiguration *configuration;

@end
