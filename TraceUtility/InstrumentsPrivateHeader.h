//
//  InstrumentsPrivateHeader.h
//  TraceUtility
//
//  Created by Qusic on 8/9/15.
//  Copyright (c) 2015 Qusic. All rights reserved.
//

#import <AppKit/AppKit.h>

#ifdef __cplusplus
extern "C" {
#endif
    NSString *PFTDeveloperDirectory(void);
    void DVTInitializeSharedFrameworks(void);
    BOOL PFTLoadPlugins(void);
#ifdef __cplusplus
}
#endif

@interface DVTDeveloperPaths : NSObject
+ (NSString *)applicationDirectoryName;
+ (void)initializeApplicationDirectoryName:(NSString *)name;
@end

@interface XRInternalizedSettingsStore : NSObject
+ (NSDictionary *)internalizedSettings;
+ (void)configureWithAdditionalURLs:(NSArray *)urls;
@end

typedef NSUInteger XRTime; // in nanoseconds
typedef struct { XRTime start, length; } XRTimeRange;

@interface XRRun : NSObject
- (NSInteger)runNumber;
- (NSString *)displayName;
- (XRTimeRange)timeRange;
@end

@interface PFTInstrumentType : NSObject
- (NSString *)uuid;
- (NSString *)name;
- (NSString *)category;
@end

@protocol XRInstrumentViewController;

@interface XRInstrument : NSObject
- (PFTInstrumentType *)type;
- (id<XRInstrumentViewController>)viewController;
- (void)setViewController:(id<XRInstrumentViewController>)viewController;
- (NSArray<XRRun *> *)allRuns;
- (XRRun *)currentRun;
- (void)setCurrentRun:(XRRun *)run;
@end

@interface PFTInstrumentList : NSObject
- (NSArray<XRInstrument *> *)allInstruments;
@end

@interface XRTrace : NSObject
- (PFTInstrumentList *)basicInstruments;
- (PFTInstrumentList *)recordingInstruments;
@end

@interface XRDevice : NSObject
- (NSString *)deviceIdentifier;
- (NSString *)deviceDisplayName;
- (NSString *)deviceDescription;
- (NSString *)productType;
- (NSString *)productVersion;
- (NSString *)buildVersion;
@end

@interface PFTProcess : NSObject
- (NSString *)bundleIdentifier;
- (NSString *)processName;
- (NSString *)displayName;
@end

@interface PFTTraceDocument : NSDocument
- (XRTrace *)trace;
- (XRDevice *)targetDevice;
- (PFTProcess *)defaultProcess;
@end

@interface PFTDocumentController : NSDocumentController
@end

@protocol XRContextContainer;

@interface XRContext : NSObject
- (NSString *)label;
- (id<NSCoding>)value;
- (id<XRContextContainer>)container;
- (instancetype)parentContext;
- (instancetype)rootContext;
@end

@protocol XRContextContainer <NSObject>
- (XRContext *)contextRepresentation;
@end

@protocol XRFilteredDataSource <NSObject>
@end

@protocol XRAnalysisCoreViewSubcontroller <XRContextContainer, XRFilteredDataSource>
@end

@interface XRAnalysisCoreDetailViewController : NSViewController <XRAnalysisCoreViewSubcontroller>
@end

@protocol XRInstrumentViewController <NSObject>
- (id<XRContextContainer>)detailContextContainer;
- (id<XRFilteredDataSource>)detailFilteredDataSource;
- (void)instrumentDidChangeSwitches;
- (void)instrumentChangedTableRequirements;
- (void)instrumentWillBecomeInvalid;
@end

@interface XRAnalysisCoreStandardController : NSObject <XRInstrumentViewController>
- (instancetype)initWithInstrument:(XRInstrument *)instrument document:(PFTTraceDocument *)document;
@end

@interface PFTCallTreeNode : NSObject
- (NSString *)libraryName;
- (NSString *)symbolName;
- (NSUInteger)address;
- (NSArray *)symbolNamePath; // Call stack
- (instancetype)root;
- (instancetype)parent;
- (NSArray *)children;
- (int)numberChildren;
- (int)terminals; // An integer value of this node, such as self running time in millisecond.
- (int)count; // Total value of all nodes of the subtree whose root node is this node. It means that if you increase terminals by a value, count will also be increased by the same value, and that the value of count is calculated automatically and you connot modify it.
- (NSUInteger)weightCount; // Count of different kinds of double values;
- (double)selfWeight:(NSUInteger)index; // A double value similar to terminal at the specific index.
- (double)weight:(NSUInteger)index; // A double value similar to count at the specific index. The difference is that you decide how weigh should be calculated.
- (double)selfCountPercent; // self.terminal / root.count
- (double)totalCountPercent; // self.count / root.count
- (double)parentCountPercent; // parent.count / root.count
- (double)selfWeightPercent:(NSUInteger)index; // self.selfWeight / root.weight
- (double)totalWeightPercent:(NSUInteger)index; // self.weight / root.weight
- (double)parentWeightPercent:(NSUInteger)index; // parent.weight / root.weight
@end

@interface XRBacktraceRepository : NSObject
- (PFTCallTreeNode *)rootNode;
@end

@interface XRMultiProcessBacktraceRepository : XRBacktraceRepository
@end

@interface XRCallTreeDetailView : NSView
- (XRBacktraceRepository *)backtraceRepository;
@end

@interface XRLegacyInstrument : XRInstrument <XRInstrumentViewController, XRContextContainer>
@end

@interface XRObjectAllocInstrument : XRLegacyInstrument
@end
