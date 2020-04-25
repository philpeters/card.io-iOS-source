//
//  CardIOStyles.h
//  See the file "LICENSE.md" for the full license governing this code.
//

#import <Foundation/Foundation.h>

#define kColorViewBackground (@available(iOS 13.0, *) ? [UIColor systemGroupedBackgroundColor] : [UIColor colorWithWhite:0.92f alpha:1.0f])

// Compositing views with alpha < 1.0 is expensive. For older devices (esp. those running 3.0) it is better to precompute.
#define kColorDefaultCell (@available(iOS 13.0, *) ? [UIColor secondarySystemGroupedBackgroundColor] : [UIColor colorWithWhite:249.0f/255 alpha:1.0f])
