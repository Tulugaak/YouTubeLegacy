#import <HBLog.h>
#import <UIKit/UIView.h>
#import <YouTubeHeader/SRLRegistry.h>
#import <YouTubeHeader/YTIElementRenderer.h>
#import <YouTubeHeader/YTIMenuItemSupportedRenderers.h>

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

%hook YTMenuController

- (NSMutableArray *)actionsForRenderers:(NSMutableArray <YTIMenuItemSupportedRenderers *> *)renderers fromView:(UIView *)view entry:(YTIElementRenderer *)entry shouldLogItems:(BOOL)shouldLogItems firstResponder:(id)firstResponder {
    if ([entry isKindOfClass:%c(YTIElementRenderer)]) {
        NSString *description = [entry description];
        NSRange range = [description rangeOfString:@"/vi/"];
        if (range.location != NSNotFound) {
            NSString *playText = _LOC([NSBundle mainBundle], @"mdx.actionview.play");
            NSString *videoID = [description substringWithRange:NSMakeRange(range.location + 4, 11)];
            NSString *playlistID = nil;
            YTICommand *command = nil;
            HBLogDebug(@"videoID: %@", videoID);
            NSRange listRange = [description rangeOfString:@"&list="];
            if (listRange.location != NSNotFound) {
                NSRange idRange = [description rangeOfString:@"\\" options:0 range:NSMakeRange(listRange.location + 6, description.length - (listRange.location + 6))];
                if (idRange.location != NSNotFound) {
                    playlistID = [description substringWithRange:NSMakeRange(listRange.location + 6, idRange.location - (listRange.location + 6))];
                    HBLogDebug(@"playlistID: %@", playlistID);
                    command = [%c(YTICommand) watchNavigationEndpointWithPlaylistID:playlistID videoID:videoID index:0 watchNextToken:nil];
                }
            } else {
                command = [%c(YTICommand) watchNavigationEndpointWithVideoID:videoID];
            }
            if (command) {
                YTIIcon *icon = [%c(YTIIcon) new];
                icon.iconType = YT_PLAY_ALL;
                YTIMenuNavigationItemRenderer *navigationItemRenderer = [%c(YTIMenuNavigationItemRenderer) new];
                navigationItemRenderer.menuItemIdentifier = @"PlayVideo";
                navigationItemRenderer.navigationEndpoint = command;
                navigationItemRenderer.icon = icon;
                navigationItemRenderer.text = [%c(YTIFormattedString) formattedStringWithString:playText];
                YTIMenuItemSupportedRenderers *menuItemRenderers = [%c(YTIMenuItemSupportedRenderers) new];
                menuItemRenderers.menuNavigationItemRenderer = navigationItemRenderer;
                [renderers insertObject:menuItemRenderers atIndex:0];
            }
        }
    }
    return %orig(renderers, view, entry, shouldLogItems, firstResponder);
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