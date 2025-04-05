#import <HBLog.h>
#import <YouTubeHeader/ELMNodeController.h>
#import <YouTubeHeader/ELMTouchCommandPropertiesHandler.h>
#import <YouTubeHeader/SRLRegistry.h>
#import <YouTubeHeader/YTCommandResponderEvent.h>
#import <YouTubeHeader/YTIElementRenderer.h>
#import <YouTubeHeader/YTIInlinePlaybackRenderer.h>
#import <YouTubeHeader/YTIMenuItemSupportedRenderers.h>
#import <YouTubeHeader/YTIPlaylistPanelRenderer.h>
#import <YouTubeHeader/YTIPlaylistPanelVideoRenderer.h>
#import <YouTubeHeader/YTPlaylistPanelProminentThumbnailVideoCellController.h>
#import <YouTubeHeader/YTPlaylistPanelSectionController.h>
#import <YouTubeHeader/YTVideoElementCellController.h>
#import <YouTubeHeader/YTVideoWithContextNode.h>

#define DidApplyDefaultSettingsKey @"YTL_DidApplyDefaultSettings"
#define YouSpeedEnabledKey @"YTVideoOverlay-YouSpeed-Enabled"
#define YouSpeedButtonPositionKey @"YTVideoOverlay-YouSpeed-Position"

#define _LOC(b, x) [b localizedStringForKey:x value:nil table:nil]

%hook SRLRegistry

- (id)internalService:(struct _SRLAPIRegistrationData *)service scopeTags:(struct SRLScopeTagSet)tags {
    if (strcmp(service->name, "YTECatcherLogger_API") == 0)
        return nil;
    return %orig;
}

%end

static YTICommand *createRelevantCommandFromElementRenderer(YTIElementRenderer *elementRenderer) {
    YTICommand *command = nil;
    NSString *description = [elementRenderer description];
    NSRange range = [description rangeOfString:@"/vi/"];
    if (range.location != NSNotFound) {
        NSString *videoID = [description substringWithRange:NSMakeRange(range.location + 4, 11)];
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
        if (obj.playlistPanelVideoRenderer == playlistPanelVideoRenderer) {
            *stop = YES;
            return YES;
        }
        return NO;
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

static YTIMenuItemSupportedRenderers *createPlayMenuRenderer(YTICommand *command) {
    NSString *playText = _LOC([NSBundle mainBundle], @"mdx.actionview.play");
    YTIIcon *icon = [%c(YTIIcon) new];
    icon.iconType = YT_PLAY_ALL;
    YTIMenuNavigationItemRenderer *navigationItemRenderer = [%c(YTIMenuNavigationItemRenderer) new];
    navigationItemRenderer.menuItemIdentifier = @"PlayVideo";
    navigationItemRenderer.navigationEndpoint = command;
    navigationItemRenderer.icon = icon;
    navigationItemRenderer.text = [%c(YTIFormattedString) formattedStringWithString:playText];
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
        command = createRelevantCommandFromElementRenderer(entry);
    else if ([entry isKindOfClass:%c(YTIPlaylistPanelVideoRenderer)])
        command = createRelevantCommandFromPlaylistPanelVideoRenderer(entry, firstResponder);
    else if ([entry isKindOfClass:%c(YTIInlinePlaybackRenderer)])
        command = createRelevantCommandFromInlinePlaybackRenderer(entry);
    if (command) {
        YTIMenuItemSupportedRenderers *menuItemRenderers = createPlayMenuRenderer(command);
        [renderers insertObject:menuItemRenderers atIndex:0];
    }
    return %orig(renderers, view, entry, shouldLogItems, firstResponder);
}

%end

%hook ELMTouchCommandPropertiesHandler

- (void)handleTap {
    ELMNodeController *nodeController = [self valueForKey:@"_controller"];
    YTVideoWithContextNode *parentNode = (YTVideoWithContextNode *)((ELMNodeController *)(nodeController.parent)).node;
    if ([parentNode isKindOfClass:%c(YTVideoWithContextNode)]) {
        YTVideoElementCellController *cellController = (YTVideoElementCellController *)parentNode.parentResponder;
        YTIElementRenderer *renderer = [cellController elementEntry];
        YTICommand *command = createRelevantCommandFromElementRenderer(renderer);
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

%ctor {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults boolForKey:DidApplyDefaultSettingsKey]) {
        [defaults setBool:YES forKey:DidApplyDefaultSettingsKey];
        [defaults setBool:YES forKey:YouSpeedEnabledKey];
        [defaults setInteger:1 forKey:YouSpeedButtonPositionKey];
    }
    %init;
}