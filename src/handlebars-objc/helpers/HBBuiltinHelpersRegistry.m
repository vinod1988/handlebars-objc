//
//  HBBuiltinHelpersRegistry.m
//  handlebars-objc
//
//  Created by Bertrand Guiheneuf on 10/5/13.
//
//  The MIT License
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//


#import "HBBuiltinHelpersRegistry.h"
#import "HBHandlebars.h"

static HBBuiltinHelpersRegistry* _builtinHelpersRegistry = nil;

@interface HBBuiltinHelpersRegistry()

+ (void) registerIfBlock;
+ (void) registerUnlessBlock;
+ (void) registerEachHelper;
+ (void) registerWithBlock;
+ (void) registerLogBlock;
+ (void) registerLocalizeBlock;
@end

@implementation HBBuiltinHelpersRegistry

+ (instancetype) builtinRegistry
{
    return _builtinHelpersRegistry;
}

+ (void) initialize
{
    _builtinHelpersRegistry = [[HBBuiltinHelpersRegistry alloc] init];
    
    [self registerIfBlock];
    [self registerUnlessBlock];
    [self registerEachHelper];
    [self registerWithBlock];
    [self registerLogBlock];
    [self registerLocalizeBlock];
}

+ (void) registerIfBlock
{
    HBHelperBlock ifBlock = ^(HBHelperCallingInfo* callingInfo) {
        BOOL boolarg = [HBHelperUtils evaluateObjectAsBool:callingInfo[0]];
        if (boolarg) {
            return callingInfo.statements(callingInfo.context, callingInfo.data);
        } else {
            return callingInfo.inverseStatements(callingInfo.context, callingInfo.data);
        }
    };
    [_builtinHelpersRegistry registerHelperBlock:ifBlock forName:@"if"];
}

+ (void) registerUnlessBlock
{
    HBHelperBlock unlessBlock = ^(HBHelperCallingInfo* callingInfo) {
        BOOL boolarg = [HBHelperUtils evaluateObjectAsBool:callingInfo[0]];
        if (!boolarg) {
            return callingInfo.statements(callingInfo.context, callingInfo.data);
        } else {
            return callingInfo.inverseStatements(callingInfo.context, callingInfo.data);
        }
    };
    [_builtinHelpersRegistry registerHelperBlock:unlessBlock forName:@"unless"];
}

+ (void) registerEachHelper
{
    HBHelperBlock eachBlock = ^(HBHelperCallingInfo* callingInfo) {

        id expression = callingInfo[0];
        HBDataContext* currentData = callingInfo.data;
        
        if (expression && [HBHelperUtils isEnumerableByIndex:expression]) {
            // Array-like context
            id<NSFastEnumeration> arrayLike = expression;
            
            NSInteger index = 0;
            HBDataContext* arrayData = currentData ? [currentData copy] : [HBDataContext new];
            NSMutableString* result = [NSMutableString string];
            NSInteger objectCount = 0;
            for (id arrayElement in arrayLike) { objectCount++; } // compute element counts. Should be in helper utils and optimized in trivial cases.
            for (id arrayElement in arrayLike) {
                arrayData[@"index"] = @(index);
                arrayData[@"first"] = @(index == 0);
                arrayData[@"last"] = @(index == (objectCount-1));
                
                id statementEvaluation = callingInfo.statements(arrayElement, arrayData);
                if (statementEvaluation) [result appendString:statementEvaluation];
                index++;
            }
            [arrayData release];
            
            // special case for empty array-like contexts. Evaluate inverse section if they're empty (as per .js implementation).
            if (index == 0) {
                return callingInfo.inverseStatements(expression, currentData);
            } else {
                return (NSString*)result;
            }
            
        } else if (expression && [HBHelperUtils isEnumerableByKey:expression]) {
            // Dictionary-like context
            if (![expression conformsToProtocol:@protocol(NSFastEnumeration)]) return (NSString*)nil;
            id<NSFastEnumeration> dictionaryLike = expression;

            HBDataContext* dictionaryData = currentData ? [currentData copy] : [HBDataContext new];
            NSMutableString* result = [NSMutableString string];
            for (id key in dictionaryLike) {
                dictionaryData[@"key"] = key;
                id statementEvaluation = callingInfo.statements(dictionaryLike[key], dictionaryData);
                if (statementEvaluation) [result appendString:statementEvaluation];
            }
            [dictionaryData release];
            
            return (NSString*)result;
        }
        
        return (NSString*)nil;
    };
    
    [_builtinHelpersRegistry registerHelperBlock:eachBlock forName:@"each"];
}

+ (void) registerWithBlock
{
    HBHelperBlock withBlock = ^(HBHelperCallingInfo* callingInfo) {
            return callingInfo.statements(callingInfo[0], callingInfo.data);
    };
    [_builtinHelpersRegistry registerHelperBlock:withBlock forName:@"with"];

}

+ (void) registerLogBlock
{
    HBHelperBlock logBlock = ^(HBHelperCallingInfo* callingInfo) {
        NSInteger level = 1;
        if (callingInfo.data[@"level"]) {
            level = [callingInfo.data[@"level"] integerValue];
        }
        [HBHandlebars log:level object:callingInfo[0]];
        return (NSString*)nil;
    };
    [_builtinHelpersRegistry registerHelperBlock:logBlock forName:@"log"];
}

+ (void) registerLocalizeBlock
{
    HBHelperBlock localizeBlock = ^(HBHelperCallingInfo* callingInfo) {
        NSString* result = nil;
        if (callingInfo.positionalParameters.count > 0) {
            NSString* key = callingInfo[0];
            NSString* localizedVersion = [callingInfo.template localizedString:key];
            return localizedVersion;
        }
        return result;
    };
    [_builtinHelpersRegistry registerHelperBlock:localizeBlock forName:@"localize"];
}

@end
