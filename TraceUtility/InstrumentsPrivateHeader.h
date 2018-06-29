//
//  InstrumentsPrivateHeader.h
//  TraceUtility
//
//  Created by Qusic on 8/9/15.
//  Copyright (c) 2015 Qusic. All rights reserved.
//

#import <AppKit/AppKit.h>

NSString *PFTDeveloperDirectory(void);
void DVTInitializeSharedFrameworks(void);
BOOL PFTLoadPlugins(void);
void PFTClosePlugins(void);

@interface DVTDeveloperPaths : NSObject
+ (NSString *)applicationDirectoryName;
+ (void)initializeApplicationDirectoryName:(NSString *)name;
@end

@interface XRInternalizedSettingsStore : NSObject
+ (NSDictionary *)internalizedSettings;
+ (void)configureWithAdditionalURLs:(NSArray *)urls;
@end

@interface XRCapabilityRegistry : NSObject
+ (instancetype)applicationCapabilities;
- (void)registerCapability:(NSString *)capability versions:(NSRange)versions;
@end

typedef UInt64 XRTime; // in nanoseconds
typedef struct { XRTime start, length; } XRTimeRange;

@interface XRRun : NSObject
- (SInt64)runNumber;
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
- (void)invalidate;
@end

@interface PFTInstrumentList : NSObject
- (NSArray<XRInstrument *> *)allInstruments;
@end

@interface XRTrace : NSObject
- (PFTInstrumentList *)allInstrumentsList;
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
- (void)display;
@end

@protocol XRContextContainer <NSObject>
- (XRContext *)contextRepresentation;
- (NSArray<XRContext *> *)siblingsForContext:(XRContext *)context;
- (void)displayContext:(XRContext *)context;
@end

@protocol XRFilteredDataSource <NSObject>
@end

@protocol XRSearchTarget <NSObject>
@end

@protocol XRCallTreeDataSource <NSObject>
@end

@protocol XRAnalysisCoreViewSubcontroller <XRContextContainer, XRFilteredDataSource>
@end

typedef NS_ENUM(SInt32, XRAnalysisCoreDetailViewType) {
    XRAnalysisCoreDetailViewTypeProjection = 1,
    XRAnalysisCoreDetailViewTypeCallTree = 2,
    XRAnalysisCoreDetailViewTypeTabular = 3,
};

@interface XRAnalysisCoreDetailNode : NSObject
- (instancetype)firstSibling;
- (instancetype)nextSibling;
- (XRAnalysisCoreDetailViewType)viewKind;
@end

@class XRAnalysisCoreProjectionViewController, XRAnalysisCoreCallTreeViewController, XRAnalysisCoreTableViewController;

@interface XRAnalysisCoreDetailViewController : NSViewController <XRAnalysisCoreViewSubcontroller> {
    XRAnalysisCoreDetailNode *_firstNode;
    XRAnalysisCoreProjectionViewController *_projectionViewController;
    XRAnalysisCoreCallTreeViewController *_callTreeViewController;
    XRAnalysisCoreTableViewController *_tabularViewController;
}
- (void)restoreViewState;
@end

XRContext *XRContextFromDetailNode(XRAnalysisCoreDetailViewController *detailController, XRAnalysisCoreDetailNode *detailNode);

@protocol XRInstrumentViewController <NSObject>
- (id<XRContextContainer>)detailContextContainer;
- (id<XRFilteredDataSource>)detailFilteredDataSource;
- (id<XRSearchTarget>)detailSearchTarget;
- (void)instrumentDidChangeSwitches;
- (void)instrumentChangedTableRequirements;
- (void)instrumentWillBecomeInvalid;
@end

@interface XRAnalysisCoreStandardController : NSObject <XRInstrumentViewController>
- (instancetype)initWithInstrument:(XRInstrument *)instrument document:(PFTTraceDocument *)document;
@end

@interface XRAnalysisCoreProjectionViewController : NSViewController <XRSearchTarget>
@end

@interface PFTCallTreeNode : NSObject
- (NSString *)libraryName;
- (NSString *)symbolName;
- (UInt64)address;
- (NSArray *)symbolNamePath; // Call stack
- (instancetype)root;
- (instancetype)parent;
- (NSArray *)children;
- (SInt32)numberChildren;
- (SInt32)terminals; // An integer value of this node, such as self running time in millisecond.
- (SInt32)count; // Total value of all nodes of the subtree whose root node is this node. It means that if you increase terminals by a value, count will also be increased by the same value, and that the value of count is calculated automatically and you connot modify it.
- (UInt64)weightCount; // Count of different kinds of double values;
- (Float64)selfWeight:(UInt64)index; // A double value similar to terminal at the specific index.
- (Float64)weight:(UInt64)index; // A double value similar to count at the specific index. The difference is that you decide how weigh should be calculated.
- (Float64)selfCountPercent; // self.terminal / root.count
- (Float64)totalCountPercent; // self.count / root.count
- (Float64)parentCountPercent; // parent.count / root.count
- (Float64)selfWeightPercent:(UInt64)index; // self.selfWeight / root.weight
- (Float64)totalWeightPercent:(UInt64)index; // self.weight / root.weight
- (Float64)parentWeightPercent:(UInt64)index; // parent.weight / root.weight
@end

@interface XRBacktraceRepository : NSObject
- (PFTCallTreeNode *)rootNode;
@end

@interface XRMultiProcessBacktraceRepository : XRBacktraceRepository
@end

@interface XRAnalysisCoreCallTreeViewController : NSViewController <XRFilteredDataSource, XRCallTreeDataSource> {
    XRBacktraceRepository *_backtraceRepository;
}
@end

typedef void XRAnalysisCoreReadCursor;

typedef union {
    UInt32 uint32;
    UInt64 uint64;
    UInt32 iid;
} XRStoredValue;

@interface XRAnalysisCoreValue : NSObject
- (XRStoredValue)storedValue;
- (id)objectValue;
@end

BOOL XRAnalysisCoreReadCursorNext(XRAnalysisCoreReadCursor *cursor);
SInt64 XRAnalysisCoreReadCursorColumnCount(XRAnalysisCoreReadCursor *cursor);
XRStoredValue XRAnalysisCoreReadCursorGetStored(XRAnalysisCoreReadCursor *cursor, UInt8 column);
BOOL XRAnalysisCoreReadCursorGetValue(XRAnalysisCoreReadCursor *cursor, UInt8 column, XRAnalysisCoreValue * __strong *pointer);

@interface XREngineeringTypeFormatter : NSFormatter
@end

@interface XRAnalysisCoreFullTextSearchSpec : NSObject
- (XREngineeringTypeFormatter *)formatter;
@end

@interface XRAnalysisCoreTableQuery : NSObject
- (XRAnalysisCoreFullTextSearchSpec *)fullTextSearchSpec;
@end

@interface XRAnalysisCoreRowArray : NSObject {
    XRAnalysisCoreTableQuery *_filter;
}
@end

@interface XRAnalysisCorePivotArrayAccessor : NSObject
- (UInt64)rowInDimension:(UInt8)dimension closestToTime:(XRTime)time intersects:(SInt8 *)intersects;
- (void)readRowsStartingAt:(UInt64)index dimension:(UInt8)dimension block:(void (^)(XRAnalysisCoreReadCursor *cursor))block;
@end

@interface XRAnalysisCorePivotArray : NSObject
- (XRAnalysisCoreRowArray *)source;
- (UInt64)count;
- (void)access:(void (^)(XRAnalysisCorePivotArrayAccessor *accessor))block;
@end

@interface XRAnalysisCoreTableViewControllerResponse : NSObject
- (XRAnalysisCorePivotArray *)rows;
@end

@interface DTRenderableContentResponse : NSObject
- (XRAnalysisCoreTableViewControllerResponse *)content;
@end

@interface XRAnalysisCoreTableViewController : NSViewController <XRFilteredDataSource, XRSearchTarget>
- (DTRenderableContentResponse *)_currentResponse;
@end

@interface XRManagedEventArrayController : NSArrayController
@end

@interface XRLegacyInstrument : XRInstrument <XRInstrumentViewController, XRContextContainer>
- (NSArray<XRContext *> *)_permittedContexts;
@end

@interface XRRawBacktrace : NSObject
@end

@interface XRManagedEvent : NSObject
- (UInt32)identifier;
@end

@interface XRObjectAllocEvent : XRManagedEvent
- (UInt32)allocationEvent;
- (UInt32)destructionEvent;
- (UInt32)pastEvent;
- (UInt32)futureEvent;
- (BOOL)isAliveThroughIdentifier:(UInt32)identifier;
- (NSString *)eventTypeName;
- (NSString *)categoryName;
- (XRTime)timestamp; // Time elapsed from the beginning of the run.
- (SInt32)size; // in bytes
- (SInt32)delta; // in bytes
- (UInt64)address;
- (UInt64)slot;
- (UInt64)data;
- (XRRawBacktrace *)backtrace;
@end

@interface XRObjectAllocEventViewController : NSObject {
    XRManagedEventArrayController *_ac;
}
@end

@interface XRObjectAllocInstrument : XRLegacyInstrument {
    XRObjectAllocEventViewController *_objectListController;
}
- (NSArray<XRContext *> *)_topLevelContexts;
@end

//@interface XRVideoCardRun : XRRun {
//    NSArrayController *_controller;
//}
//@end
//
//@interface XRVideoCardInstrument : XRLegacyInstrument
//@end

//@interface XRNetworkAddressFormatter : NSFormatter
//@end
//
//@interface XRNetworkingInstrument : XRLegacyInstrument {
//    XRContext * __strong *_topLevelContexts;
//    NSArrayController * __strong *_controllersByTable;
//    XRNetworkAddressFormatter *_localAddrFmtr;
//    XRNetworkAddressFormatter *_remoteAddrFmtr;
//}
//- (void)selectedRunRecomputeSummaries;
//@end

//typedef struct {
//    XRTimeRange range;
//    UInt64 idx;
//    UInt32 recno;
//} XRPowerTimelineEntry;
//
//@interface XRPowerTimeline : NSObject
//- (UInt64)count;
//- (UInt64)lastIndex;
//- (XRTime)lastTimeOffset;
//- (void)enumerateTimeRange:(XRTimeRange)timeRange sequenceNumberRange:(NSRange)numberRange block:(void (^)(const XRPowerTimelineEntry *entry, BOOL *stop))block;
//@end
//
//@interface XRPowerStreamDefinition : NSObject
//- (UInt64)columnsInDataStreamCount;
//@end
//
//@interface XRPowerDatum : NSObject
//- (XRTimeRange)time;
//- (NSString *)labelForColumn:(SInt64)column;
//- (id)objectValueForColumn:(SInt64)column;
//@end
//
//@interface XRPowerDetailController : NSObject
//- (XRPowerDatum *)datumAtObjectIndex:(UInt64)index;
//@end
//
//@interface XRStreamedPowerInstrument : XRLegacyInstrument {
//    XRPowerDetailController *_detailController;
//}
//- (XRPowerStreamDefinition *)definitionForCurrentDetailView;
//- (XRPowerTimeline *)selectedEventTimeline;
//@end
