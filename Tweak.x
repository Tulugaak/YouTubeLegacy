#import <HBLog.h>
#import <YouTubeHeader/_ASDisplayView.h>
#import <YouTubeHeader/ASCollectionView.h>
#import <YouTubeHeader/ELMNodeController.h>
#import <YouTubeHeader/ELMNodeFactory.h>
#import <YouTubeHeader/ELMTextNode.h>
#import <YouTubeHeader/ELMTouchCommandPropertiesHandler.h>
#import <YouTubeHeader/SRLRegistry.h>
#import <YouTubeHeader/UIImage+YouTube.h>
#import <YouTubeHeader/YTCommandResponderEvent.h>
#import <YouTubeHeader/YTICompactLinkRenderer.h>
#import <YouTubeHeader/YTIElementRenderer.h>
#import <YouTubeHeader/YTIInlinePlaybackRenderer.h>
#import <YouTubeHeader/YTIMenuItemSupportedRenderers.h>
#import <YouTubeHeader/YTIPivotBarItemRenderer.h>
#import <YouTubeHeader/YTIPlaylistPanelRenderer.h>
#import <YouTubeHeader/YTIPlaylistPanelVideoRenderer.h>
#import <YouTubeHeader/YTIReelPlayerOverlayRenderer.h>
#import <YouTubeHeader/YTPivotBarItemView.h>
#import <YouTubeHeader/YTPlaylistPanelProminentThumbnailVideoCellController.h>
#import <YouTubeHeader/YTPlaylistPanelSectionController.h>
#import <YouTubeHeader/YTRendererForOfflineVideo.h>
#import <YouTubeHeader/YTVideoElementCellController.h>
#import <YouTubeHeader/YTVideoWithContextNode.h>

@interface ELMTextNode2 : ELMTextNode
- (BOOL)isLikeDislikeNode;
@end

#define DidApplyDefaultSettingsKey @"YTL_DidApplyDefaultSettings"
#define DidApplyDefaultSettings2Key @"YTL_DidApplyDefaultSettings2"
#define YouSpeedEnabledKey @"YTVideoOverlay-YouSpeed-Enabled"
#define YouSpeedButtonPositionKey @"YTVideoOverlay-YouSpeed-Position"
#define RYDUseItsDataKey @"RYD-USE-LIKE-DATA"

#define _LOC(b, x) [b localizedStringForKey:x value:nil table:nil]

%hook SRLRegistry

- (id)internalService:(struct _SRLAPIRegistrationData *)service scopeTags:(struct SRLScopeTagSet)tags {
    if (strcmp(service->name, "YTECatcherLogger_API") == 0)
        return nil;
    return %orig;
}

%end

%hook YTInterstitialPromoEventGroupHandler

- (void)addEventHandlers {}

%end

%hook YTPromosheetEventGroupHandler

- (void)addEventHandlers {}

%end

static BOOL isRelevantContainerView(UIView *view) {
    return [view.accessibilityIdentifier isEqualToString:@"eml.vwc"] || [view.accessibilityIdentifier isEqualToString:@"horizontal-video-shelf.view"];
}

static YTICommand *createRelevantCommandFromElementRenderer(YTIElementRenderer *elementRenderer, _ASDisplayView *view, id firstResponder) {
    NSInteger preferredIndex = NSNotFound;
    if (view) {
        UIView *parentView = view;
        do {
            parentView = parentView.superview;
        } while (parentView && !isRelevantContainerView(parentView));
        if (isRelevantContainerView(parentView)) {
            if ([parentView.accessibilityIdentifier isEqualToString:@"horizontal-video-shelf.view"]) {
                ELMNodeController *nodeController = [view.keepalive_node controller];
                do {
                    nodeController = nodeController.parent;
                } while (nodeController && ![[nodeController key] isEqualToString:@"video-card-cell"]);
                ELMNodeController *containerNodeController = ((ELMNodeController *)nodeController.parent).parent;
                preferredIndex = [[containerNodeController children] indexOfObjectPassingTest:^BOOL(ELMComponent *obj, NSUInteger idx, BOOL *stop) {
                    ELMNodeController *childNodeController = [obj materializedInstance];
                    return [[[childNodeController children] firstObject] materializedInstance] == nodeController;
                }];
            } else
                preferredIndex = [parentView.superview.subviews indexOfObject:parentView];
        }
    }
    YTICommand *command = nil;
    NSString *description = [elementRenderer description];
    NSString *videoSearchString = @"//www.youtube.com/watch?v=";
    NSRange range = [description rangeOfString:videoSearchString];
    if (preferredIndex != NSNotFound) {
        while (preferredIndex-- > 0) {
            range = [description rangeOfString:videoSearchString options:0 range:NSMakeRange(range.location + videoSearchString.length, description.length - (range.location + videoSearchString.length))];
        }
    }
    if (range.location != NSNotFound) {
        NSString *videoID = [description substringWithRange:NSMakeRange(range.location + videoSearchString.length, 11)];
        NSString *playlistID = nil;
        HBLogDebug(@"videoID: %@", videoID);
        NSRange listRange = [description rangeOfString:@"&list="];
        if (listRange.location != NSNotFound) {
            NSRange idRange = [description rangeOfString:@"\\" options:0 range:NSMakeRange(listRange.location + 6, description.length - (listRange.location + 6))];
            if (idRange.location != NSNotFound) {
                playlistID = [description substringWithRange:NSMakeRange(listRange.location + 6, idRange.location - (listRange.location + 6))];
                HBLogDebug(@"playlistID: %@", playlistID);
                command = [%c(YTICommand) watchNavigationEndpointWithPlaylistID:playlistID videoID:videoID index:0 watchNextToken:nil];
            }
        } else
            command = [%c(YTICommand) watchNavigationEndpointWithVideoID:videoID];
    } else {
        NSString *playlistSearchString = @"//www.youtube.com/playlist?list=";
        NSRange playlistRange = [description rangeOfString:playlistSearchString];
        if (playlistRange.location != NSNotFound) {
            NSRange idRange = [description rangeOfString:@"\\" options:0 range:NSMakeRange(playlistRange.location + playlistSearchString.length, description.length - (playlistRange.location + playlistSearchString.length))];
            if (idRange.location != NSNotFound) {
                NSString *playlistID = [description substringWithRange:NSMakeRange(playlistRange.location + playlistSearchString.length, idRange.location - (playlistRange.location + playlistSearchString.length))];
                if ([playlistID hasSuffix:@"Z"])
                    playlistID = [playlistID substringToIndex:playlistID.length - 1];
                HBLogDebug(@"playlistID: %@", playlistID);
                command = [%c(YTICommand) watchNavigationEndpointWithPlaylistID:playlistID videoID:nil index:0 watchNextToken:nil];
            }
        }
    }
    if (command == nil && [firstResponder isKindOfClass:%c(YTVideoElementCellController)]) {
        videoSearchString = @"/vi/";
        range = [description rangeOfString:videoSearchString];
        if (range.location != NSNotFound) {
            NSString *videoID = [description substringWithRange:NSMakeRange(range.location + videoSearchString.length, 11)];
            HBLogDebug(@"videoID: %@", videoID);
            command = [%c(YTICommand) watchNavigationEndpointWithVideoID:videoID];
        }
    }
    return command;
}

static YTICommand *createRelevantCommandFromPlaylistPanelVideoRenderer(YTIPlaylistPanelVideoRenderer *playlistPanelVideoRenderer, id firstResponder) {
    NSString *videoID = playlistPanelVideoRenderer.videoId;
    HBLogDebug(@"videoID: %@", videoID);
    YTPlaylistPanelProminentThumbnailVideoCellController *cellController = (YTPlaylistPanelProminentThumbnailVideoCellController *)firstResponder;
    YTPlaylistPanelSectionController *sectionController = cellController.parentResponder;
    YTIPlaylistPanelRenderer *panelRenderer = (YTIPlaylistPanelRenderer *)[sectionController renderer];
    NSUInteger index = [panelRenderer.contentsArray indexOfObjectPassingTest:^BOOL(YTIPlaylistPanelRenderer_PlaylistPanelVideoSupportedRenderers *obj, NSUInteger idx, BOOL *stop) {
        return obj.playlistPanelVideoRenderer == playlistPanelVideoRenderer;
    }];
    NSString *playlistID = panelRenderer.playlistId;
    HBLogDebug(@"playlistID: %@", playlistID);
    return [%c(YTICommand) watchNavigationEndpointWithPlaylistID:playlistID videoID:videoID index:index watchNextToken:nil];
}

static YTICommand *createRelevantCommandFromInlinePlaybackRenderer(YTIInlinePlaybackRenderer *inlinePlaybackRenderer) {
    NSString *videoID = inlinePlaybackRenderer.videoId;
    HBLogDebug(@"videoID: %@", videoID);
    return [%c(YTICommand) watchNavigationEndpointWithVideoID:videoID];
}

static YTICommand *createRelevantCommandFromOfflineVideoRenderer(id <YTRendererForOfflineVideo> renderer) {
    NSString *videoID = renderer.videoId;
    HBLogDebug(@"videoID: %@", videoID);
    return [%c(YTICommand) watchNavigationEndpointWithVideoID:videoID];
}

static YTIMenuItemSupportedRenderers *createMenuRenderer(YTICommand *command, NSString *text, NSString *identifier, YTIcon iconType) {
    YTIIcon *icon = [%c(YTIIcon) new];
    icon.iconType = iconType;
    YTIMenuNavigationItemRenderer *navigationItemRenderer = [%c(YTIMenuNavigationItemRenderer) new];
    navigationItemRenderer.menuItemIdentifier = identifier;
    navigationItemRenderer.navigationEndpoint = command;
    navigationItemRenderer.icon = icon;
    navigationItemRenderer.text = [%c(YTIFormattedString) formattedStringWithString:text];
    YTIMenuItemSupportedRenderers *menuItemRenderers = [%c(YTIMenuItemSupportedRenderers) new];
    menuItemRenderers.menuNavigationItemRenderer = navigationItemRenderer;
    return menuItemRenderers;
}

%hook YTMenuController

- (NSMutableArray *)actionsForRenderers:(NSMutableArray <YTIMenuItemSupportedRenderers *> *)renderers fromView:(UIView *)view entry:(id)entry shouldLogItems:(BOOL)shouldLogItems firstResponder:(id)firstResponder {
    HBLogDebug(@"actionsForRenderers: %@", renderers);
    HBLogDebug(@"view: %@", view);
    HBLogDebug(@"entry: %@", entry);
    HBLogDebug(@"firstResponder: %@", firstResponder);
    YTICommand *command = nil;
    if ([entry isKindOfClass:%c(YTIElementRenderer)])
        command = createRelevantCommandFromElementRenderer(entry, (_ASDisplayView *)view, firstResponder);
    else if ([entry isKindOfClass:%c(YTIPlaylistPanelVideoRenderer)])
        command = createRelevantCommandFromPlaylistPanelVideoRenderer(entry, firstResponder);
    else if ([entry isKindOfClass:%c(YTIInlinePlaybackRenderer)])
        command = createRelevantCommandFromInlinePlaybackRenderer(entry);
    else if ([entry conformsToProtocol:@protocol(YTRendererForOfflineVideo)])
        command = createRelevantCommandFromOfflineVideoRenderer(entry);
    if (command) {
        NSString *playText = _LOC([NSBundle mainBundle], @"mdx.actionview.play");
        YTIMenuItemSupportedRenderers *menuItemRenderers = createMenuRenderer(command, playText, @"PlayVideo", YT_PLAY_ALL);
        [renderers insertObject:menuItemRenderers atIndex:0];
    }
    if ([firstResponder isKindOfClass:%c(YTHeaderViewController)]) {
        NSString *switchAccountText = _LOC([NSBundle mainBundle], @"sign_in_retroactive.select_another_account");
        command = [%c(YTICommand) signInNavigationEndpoint];
        YTIMenuItemSupportedRenderers *menuItemRenderers = createMenuRenderer(command, switchAccountText, @"SwitchAccount", 182);
        [renderers insertObject:menuItemRenderers atIndex:0];
    }
    return %orig(renderers, view, entry, shouldLogItems, firstResponder);
}

%end

%hook ELMTouchCommandPropertiesHandler

- (void)handleTap {
    ELMNodeController *nodeController = [self valueForKey:@"_controller"];
    HBLogDebug(@"nodeController: %@", nodeController);
    if ([nodeController isKindOfClass:%c(ELMNodeController)] && [nodeController.node.accessibilityIdentifier isEqualToString:@"eml.overflow_button"]) {
        %orig;
        return;
    }
    id parentNode = nil;
    ELMNodeController *currentController = nodeController.parent;
    do {
        parentNode = currentController.node;
        if ([parentNode isKindOfClass:%c(YTVideoWithContextNode)])
            break;
        currentController = currentController.parent;
    } while (currentController);
    if ([parentNode isKindOfClass:%c(YTVideoWithContextNode)]) {
        YTVideoElementCellController *cellController = (YTVideoElementCellController *)((YTVideoWithContextNode *)parentNode).parentResponder;
        YTIElementRenderer *renderer = [cellController elementEntry];
        YTICommand *command = createRelevantCommandFromElementRenderer(renderer, nil, cellController);
        if (command) {
            UIView *view = nodeController.node.view;
            YTCommandResponderEvent *event = [%c(YTCommandResponderEvent) eventWithCommand:command fromView:view entry:renderer sendClick:NO firstResponder:cellController];
            [event send];
            return;
        }
    }
    %orig;
}

%end

%subclass ELMTextNode2 : ELMTextNode

%new(B@:)
- (BOOL)isLikeDislikeNode {
    NSString *identifier = self.yogaParent.accessibilityIdentifier;
    return [identifier isEqualToString:@"id.video.like.button"] || [identifier isEqualToString:@"id.video.dislike.button"];
}

- (void)controllerDidApplyProperties {
    if ([self isLikeDislikeNode])
        HBLogDebug(@"controllerDidApplyProperties");
    else
        %orig;
}

%end

%hook YTWatchLayerViewController

- (id)initWithParentResponder:(id)parentResponder {
    self = %orig;
    [[%c(ELMNodeFactory) sharedInstance] registerNodeClass:%c(ELMTextNode2) forTypeExtension:525000000];
    return self;
}

%end

%hook YTHotConfig

- (BOOL)isFixAvatarFlickersEnabled { return NO; }

%end

%hook YTColdConfig

- (BOOL)mainAppCoreClientIosTopBarAvatarFix { return NO; }
- (BOOL)mainAppCoreClientIosTransientVisualGlitchInPivotBarFix { return YES; }

%end

%hook YTPivotBarItemView

- (void)setRenderer:(YTIPivotBarItemRenderer *)renderer {
    %orig;
    YTQTMButton *navigationButton = self.navigationButton;
    NSString *imageURL;
    @try {
        imageURL = [renderer.thumbnail.thumbnailsArray firstObject].URL;
    } @catch (id ex) {
        GPBMessage *message = [[renderer messageForFieldNumber:15] messageForFieldNumber:1];
        GPBUnknownFieldSet *unknownFields = [message unknownFields];
        GPBUnknownField *field = [unknownFields getField:1];
        NSData *data = [field.lengthDelimitedList firstObject];
        imageURL = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    HBLogDebug(@"imageURL: %@", imageURL);
    if (imageURL == nil) return;
    NSURL *url = [NSURL URLWithString:imageURL];
    if (url == nil) return;
    UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:url]];
    if (image == nil) return;
    image = [image yt_imageScaledToSize:CGSizeMake(24, 24)];
    [navigationButton setImage:image forState:UIControlStateNormal];
    [navigationButton setImage:image forState:UIControlStateHighlighted];
    navigationButton.imageView.layer.cornerRadius = 12;
    [self setNeedsLayout];
}

%end

%hook YTIIcon

- (UIImage *)iconImageWithColor:(UIColor *)color {
    int unknownIconType = [[[self.unknownFields getField:1].varintList yt_numberAtIndex:0] intValue];
    if (unknownIconType == YT_CLAPPERBOARD)
        self.iconType = YT_MOVIES;
    return %orig;
}

%end

%hook YTReelWatchPlaybackOverlayView

- (void)setActionBarElementRenderer:(id)renderer {}

%end

%hook YTReelContentView

- (void)setOverlayRenderer:(YTIReelPlayerOverlayRenderer *)renderer {
    renderer.likeButton = renderer.doubleTapLikeButton;
    %orig;
}

%end

%group PlaylistPageRefresh

BOOL (*YTPlaylistPageRefreshSupported)(void) = NULL;
%hookf(BOOL, YTPlaylistPageRefreshSupported) {
    return YES;
}

%end

%ctor {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults boolForKey:DidApplyDefaultSettingsKey]) {
        [defaults setBool:YES forKey:DidApplyDefaultSettingsKey];
        [defaults setBool:YES forKey:YouSpeedEnabledKey];
        [defaults setInteger:1 forKey:YouSpeedButtonPositionKey];
        [defaults synchronize];
    }
    if (![defaults boolForKey:DidApplyDefaultSettings2Key]) {
        [defaults setBool:YES forKey:DidApplyDefaultSettings2Key];
        [defaults setBool:YES forKey:RYDUseItsDataKey];
        [defaults synchronize];
    }
    NSString *bundlePath = [NSString stringWithFormat:@"%@/Frameworks/Module_Framework.framework", NSBundle.mainBundle.bundlePath];
    [[NSBundle bundleWithPath:bundlePath] load];
    MSImageRef ref = MSGetImageByName([[bundlePath stringByAppendingString:@"/Module_Framework"] UTF8String]);
    YTPlaylistPageRefreshSupported = MSFindSymbol(ref, "_YTPlaylistPageRefreshSupported");
    if (YTPlaylistPageRefreshSupported) {
        %init(PlaylistPageRefresh);
    }
    %init;
}