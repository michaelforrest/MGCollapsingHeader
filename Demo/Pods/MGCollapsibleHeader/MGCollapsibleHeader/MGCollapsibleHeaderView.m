//
//  The MIT License (MIT)
//
//  Copyright (c) 2015 Matthew Gardner
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

#import "MGCollapsibleHeaderView.h"

@implementation MGTransformAttribute

+ (instancetype)attribute:(MGAttribute)attr value:(CGFloat)val
{
    MGTransformAttribute *a = [MGTransformAttribute alloc];
    a.attribute             = attr;
    a.value                 = val;
    a.curve                 = MGTransformCurveLinear;

    return a;
}

@end

@implementation MGCollapsibleHeaderView

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit
{
    transfViews = [@[] mutableCopy];
    fadeViews   = [@[] mutableCopy];
    transfAttrs = [@{} mutableCopy];
    constrs     = [@{} mutableCopy];
    constrVals  = [@{} mutableCopy];
    alphaRatios = [@{} mutableCopy];
	
    header_ht  = self.frame.size.height;
	[self setMinimumHeaderHeight:60.];
}

- (void)setMinimumHeaderHeight:(CGFloat)minimumHeaderHeight {
	_minimumHeaderHeight = minimumHeaderHeight;
	offset_max = header_ht - _minimumHeaderHeight;
}

- (void)collapseToOffset:(CGPoint)offset
{
    CGFloat dy = offset.y;

    if (dy > 0.) {
        if (header_ht - dy > _minimumHeaderHeight) {
            [self scrollHeaderToOffset:dy];
        } else if (header_ht - lastOffset > _minimumHeaderHeight) {
            [self scrollHeaderToOffset:offset_max];
        }
    } else if (lastOffset > 0.) {
        [self scrollHeaderToOffset:0.];
    }

    lastOffset = dy;
}

- (BOOL)addTransformingSubview:(UIView *)view attributes:(NSArray *)attrs
{
    NSMutableDictionary *constrDict    = [@{} mutableCopy];
    NSMutableDictionary *constrValDict = [@{} mutableCopy];
	
	UIView *v = view;
	while(v) {
		for (NSLayoutConstraint *c in v.constraints) {
			if (c.firstItem == view || c.secondItem == view) {
				[constrDict setObject:c forKey:@(c.firstAttribute)];
				[constrValDict setObject:@(c.constant) forKey:@(c.firstAttribute)];
			}
		}
		v = v.superview;
	}

    for (MGTransformAttribute *ta in attrs) {
        ta.origValue = [self getViewAttribute:[ta attribute] view:view];
        ta.dValue    = ta.value - ta.origValue;
    }

    [transfViews addObject:view];

    [transfAttrs setObject:attrs forKey:@(view.hash)];

    [constrs setObject:constrDict forKey:@(view.hash)];

    [constrVals setObject:constrValDict forKey:@(view.hash)];

    return YES;
}

- (BOOL)addFadingSubview:(UIView *)view fadeBy:(CGFloat)ratio
{
    if (ratio < 0. || ratio > 1.) {
        return NO;
    }

    [fadeViews addObject:view];

    [alphaRatios setObject:@(ratio) forKey:@(view.hash)];

    return YES;
}

- (void)scrollHeaderToOffset:(CGFloat)offset
{
    CGFloat ratio = offset / offset_max;

    for (UIView *view in fadeViews) {
        CGFloat alphaRatio = [[alphaRatios objectForKey:@(view.hash)] doubleValue];
        view.alpha         = -ratio / alphaRatio + 1;
    }

    for (UIView *view in transfViews) {
        NSDictionary *cs  = [constrs objectForKey:@(view.hash)];
        NSDictionary *cvs = [constrVals objectForKey:@(view.hash)];
        NSDictionary *as  = [transfAttrs objectForKey:@(view.hash)];

        for (MGTransformAttribute *a in as) {
            [self setAttribute:a view:view ratio:ratio constraints:cs constraintValues:cvs];
        }
    }

    CGRect bnrFrame   = self.frame;
    bnrFrame.origin.y = -offset;
    self.frame        = bnrFrame;

    self.bodyViewTop.constant = -offset;

    [self.superview layoutIfNeeded];
}

#pragma mark - Helpers

- (CGFloat)getViewAttribute:(MGAttribute)attribute view:(UIView *)view
{
    switch (attribute) {
    case MGAttributeX:
        return view.frame.origin.x;
    case MGAttributeY:
        return view.frame.origin.y;
    case MGAttributeWidth:
        return view.frame.size.width;
    case MGAttributeHeight:
        return view.frame.size.height;
    case MGAttributeAlpha:
        return view.alpha;
    case MGAttributeCornerRadius:
        return view.layer.cornerRadius;
    case MGAttributeShadowOpacity:
        return view.layer.shadowOpacity;
    case MGAttributeShadowRadius:
        return view.layer.shadowRadius;
    }
}

- (void)setAttribute:(MGTransformAttribute *)attr
                view:(UIView *)view
               ratio:(CGFloat)ratio
         constraints:(NSDictionary *)cs
    constraintValues:(NSDictionary *)cvals
{
    switch (attr.attribute) {
    case MGAttributeX:
        [self updateConstraint:[cs objectForKey:@(NSLayoutAttributeLeading)]
                   constrValue:[[cvals objectForKey:@(NSLayoutAttributeLeading)] doubleValue]
                     transform:attr
                         ratio:ratio];
        [self updateConstraint:[cs objectForKey:@(NSLayoutAttributeLeadingMargin)]
                   constrValue:[[cvals objectForKey:@(NSLayoutAttributeLeadingMargin)] doubleValue]
                     transform:attr
                         ratio:ratio];
        [self updateConstraint:[cs objectForKey:@(NSLayoutAttributeTrailing)]
                   constrValue:[[cvals objectForKey:@(NSLayoutAttributeTrailing)] doubleValue]
                     transform:attr
                         ratio:ratio];
        [self updateConstraint:[cs objectForKey:@(NSLayoutAttributeTrailingMargin)]
                   constrValue:[[cvals objectForKey:@(NSLayoutAttributeLeadingMargin)] doubleValue]
                     transform:attr
                         ratio:ratio];
        break;
    case MGAttributeY:
        [self updateConstraint:[cs objectForKey:@(NSLayoutAttributeTop)]
                   constrValue:[[cvals objectForKey:@(NSLayoutAttributeTop)] doubleValue]
                     transform:attr
                         ratio:ratio];
        [self updateConstraint:[cs objectForKey:@(NSLayoutAttributeTopMargin)]
                   constrValue:[[cvals objectForKey:@(NSLayoutAttributeTopMargin)] doubleValue]
                     transform:attr
                         ratio:ratio];
        [self updateConstraint:[cs objectForKey:@(NSLayoutAttributeBottom)]
                   constrValue:[[cvals objectForKey:@(NSLayoutAttributeBottom)] doubleValue]
                     transform:attr
                         ratio:ratio];
        [self updateConstraint:[cs objectForKey:@(NSLayoutAttributeBottomMargin)]
                   constrValue:[[cvals objectForKey:@(NSLayoutAttributeBottomMargin)] doubleValue]
                     transform:attr
                         ratio:ratio];
        break;
    case MGAttributeWidth:
        [self updateConstraint:[cs objectForKey:@(NSLayoutAttributeWidth)]
                   constrValue:[[cvals objectForKey:@(NSLayoutAttributeWidth)] doubleValue]
                     transform:attr
                         ratio:ratio];
        break;
    case MGAttributeHeight:
        [self updateConstraint:[cs objectForKey:@(NSLayoutAttributeHeight)]
                   constrValue:[[cvals objectForKey:@(NSLayoutAttributeHeight)] doubleValue]
                     transform:attr
                         ratio:ratio];
        break;
    case MGAttributeCornerRadius:
        view.layer.cornerRadius = attr.origValue + ratio * (attr.value - attr.origValue);
        break;
    case MGAttributeAlpha:
        view.alpha = attr.origValue + ratio * (attr.value - attr.origValue);
        break;
    case MGAttributeShadowRadius:
        view.layer.shadowRadius = attr.origValue + ratio * (attr.value - attr.origValue);
        break;
    case MGAttributeShadowOpacity:
        view.layer.shadowOpacity = attr.origValue + ratio * (attr.value - attr.origValue);
        break;
    }
}

- (void)updateConstraint:(NSLayoutConstraint *)constraint constrValue:(CGFloat)cv transform:(MGTransformAttribute *)ta ratio:(CGFloat)ratio
{
    if (constraint) {
        switch (constraint.firstAttribute) {
        case NSLayoutAttributeTop:
        case NSLayoutAttributeTopMargin:
        case NSLayoutAttributeLeading:
        case NSLayoutAttributeLeadingMargin:
        case NSLayoutAttributeWidth:
        case NSLayoutAttributeHeight:
            constraint.constant = cv + ratio * ta.dValue;
            break;
        case NSLayoutAttributeBottom:
        case NSLayoutAttributeBottomMargin:
        case NSLayoutAttributeTrailing:
        case NSLayoutAttributeTrailingMargin:
            constraint.constant = cv - ratio * ta.dValue;
            break;
        default:
            break;
        }
    }
}

@end
