#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "1 – Layer" asset catalog image resource.
static NSString * const ACImageName1Layer AC_SWIFT_PRIVATE = @"1 – Layer";

/// The "2 – Layer" asset catalog image resource.
static NSString * const ACImageName2Layer AC_SWIFT_PRIVATE = @"2 – Layer";

/// The "3 – Layer" asset catalog image resource.
static NSString * const ACImageName3Layer AC_SWIFT_PRIVATE = @"3 – Layer";

#undef AC_SWIFT_PRIVATE
