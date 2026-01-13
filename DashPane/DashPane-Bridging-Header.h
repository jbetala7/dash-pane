//
//  DashPane-Bridging-Header.h
//  DashPane
//
//  Bridging header for private APIs
//

#ifndef DashPane_Bridging_Header_h
#define DashPane_Bridging_Header_h

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ApplicationServices/ApplicationServices.h>

// Private API to get CGWindowID from AXUIElement
extern AXError _AXUIElementGetWindow(AXUIElementRef element, CGWindowID *windowID);

// Private Space APIs (optional - for advanced Space management)
// These are undocumented and may break in future macOS versions

typedef uint64_t CGSConnectionID;
typedef uint64_t CGSSpaceID;

// Get the main connection ID
extern CGSConnectionID CGSMainConnectionID(void);

// Copy spaces information
// Mask values:
// 0x1 - Current space
// 0x2 - Other spaces
// 0x4 - All spaces
extern CFArrayRef CGSCopySpaces(CGSConnectionID cid, int mask);

// Get space ID for a window
extern CGSSpaceID CGSGetWindowWorkspace(CGSConnectionID cid, CGWindowID wid);

// Move window to a space
extern void CGSMoveWindowToSpace(CGSConnectionID cid, CGWindowID wid, CGSSpaceID space);

#endif /* DashPane_Bridging_Header_h */
