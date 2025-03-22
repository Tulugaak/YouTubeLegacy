#import <YouTubeHeader/SRLRegistry.h>
#import <string.h>

%hook SRLRegistry

- (id)internalService:(struct _SRLAPIRegistrationData *)service scopeTags:(struct SRLScopeTagSet)tags {
    if (strcmp(service->name, "YTECatcherLogger_API") == 0)
        return nil;
    return %orig;
}

%end
