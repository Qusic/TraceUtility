//
//  main.m
//  TraceUtility
//
//  Created by Qusic on 7/9/15.
//  Copyright (c) 2015 Qusic. All rights reserved.
//

#import "InstrumentsPrivateHeader.h"
#import <objc/runtime.h>

#define TUPrint(format, ...) CFShow((__bridge CFStringRef)[NSString stringWithFormat:format, ## __VA_ARGS__])
#define TUIvarCast(object, name, type) (*(type *)(void *)&((char *)(__bridge void *)object)[ivar_getOffset(class_getInstanceVariable(object_getClass(object), #name))])
#define TUIvar(object, name) TUIvarCast(object, name, id const)

// Workaround to fix search paths for Instruments plugins and packages.
static NSBundle *(*NSBundle_mainBundle_original)(id self, SEL _cmd);
static NSBundle *NSBundle_mainBundle_replaced(id self, SEL _cmd) {
    return [NSBundle bundleWithPath:@"/Applications/Xcode.app/Contents/Applications/Instruments.app"];
}

static void __attribute__((constructor)) hook() {
    Method NSBundle_mainBundle = class_getClassMethod(NSBundle.class, @selector(mainBundle));
    NSBundle_mainBundle_original = (void *)method_getImplementation(NSBundle_mainBundle);
    method_setImplementation(NSBundle_mainBundle, (IMP)NSBundle_mainBundle_replaced);
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Required. Each instrument is a plugin and we have to load them before we can process their data.
        DVTInitializeSharedFrameworks();
        [DVTDeveloperPaths initializeApplicationDirectoryName:@"Instruments"];
        [XRInternalizedSettingsStore configureWithAdditionalURLs:nil];
        [[XRCapabilityRegistry applicationCapabilities]registerCapability:@"com.apple.dt.instruments.track_pinning" versions:NSMakeRange(1, 1)];
        PFTLoadPlugins();

        // Instruments has its own subclass of NSDocumentController without overriding sharedDocumentController method.
        // We have to call this eagerly to make sure the correct document controller is initialized.
        [PFTDocumentController sharedDocumentController];

        // Open a trace document.
        NSArray<NSString *> *arguments = NSProcessInfo.processInfo.arguments;
        if (arguments.count < 2) {
            TUPrint(@"Usage: %@ [%@]\n", arguments.firstObject.lastPathComponent, @"trace document");
            return 1;
        }
        NSString *tracePath = arguments[1];
        NSError *error = nil;
        PFTTraceDocument *document = [[PFTTraceDocument alloc]initWithContentsOfURL:[NSURL fileURLWithPath:tracePath] ofType:@"com.apple.instruments.trace" error:&error];
        if (error) {
            TUPrint(@"Error: %@\n", error);
            return 1;
        }
        TUPrint(@"Trace: %@\n", tracePath);

        // List some useful metadata of the document.
        XRDevice *device = document.targetDevice;
        TUPrint(@"Device: %@ (%@ %@ %@)\n", device.deviceDisplayName, device.productType, device.productVersion, device.buildVersion);
        PFTProcess *process = document.defaultProcess;
        TUPrint(@"Process: %@ (%@)\n", process.displayName, process.bundleIdentifier);

        // Each trace document consists of data from several different instruments.
        XRTrace *trace = document.trace;
        for (XRInstrument *instrument in trace.allInstrumentsList.allInstruments) {
            TUPrint(@"\nInstrument: %@ (%@)\n", instrument.type.name, instrument.type.uuid);

            // Each instrument can have multiple runs.
            NSArray<XRRun *> *runs = instrument.allRuns;
            if (runs.count == 0) {
                TUPrint(@"No data.\n");
                continue;
            }
            for (XRRun *run in runs) {
                TUPrint(@"Run #%@: %@\n", @(run.runNumber), run.displayName);
                instrument.currentRun = run;

                // Common routine to obtain contexts for the instrument.
                NSMutableArray<XRContext *> *contexts = [NSMutableArray array];
                if (![instrument isKindOfClass:XRLegacyInstrument.class]) {
                    XRAnalysisCoreStandardController *standardController = [[XRAnalysisCoreStandardController alloc]initWithInstrument:instrument document:document];
                    instrument.viewController = standardController;
                    [standardController instrumentDidChangeSwitches];
                    [standardController instrumentChangedTableRequirements];
                    XRAnalysisCoreDetailViewController *detailController = TUIvar(standardController, _detailController);
                    [detailController restoreViewState];
                    XRAnalysisCoreDetailNode *detailNode = TUIvar(detailController, _firstNode);
                    while (detailNode) {
                        [contexts addObject:XRContextFromDetailNode(detailController, detailNode)];
                        detailNode = detailNode.nextSibling;
                    }
                }

                // Different instruments can have different data structure.
                // Here are some straightforward example code demonstrating how to process the data from several commonly used instruments.
                NSString *instrumentID = instrument.type.uuid;
                if ([instrumentID isEqualToString:@"com.apple.xray.instrument-type.coresampler2"]) {
                    // Time Profiler: print out all functions in descending order of self execution time.
                    // 3 contexts: Profile, Narrative, Samples
                    XRContext *context = contexts[0];
                    [context display];
                    XRAnalysisCoreCallTreeViewController *controller = TUIvar(context.container, _callTreeViewController);
                    XRBacktraceRepository *backtraceRepository = TUIvar(controller, _backtraceRepository);
                    static NSMutableArray<PFTCallTreeNode *> * (^ const flattenTree)(PFTCallTreeNode *) = ^(PFTCallTreeNode *rootNode) { // Helper function to collect all tree nodes.
                        NSMutableArray *nodes = [NSMutableArray array];
                        if (rootNode) {
                            [nodes addObject:rootNode];
                            for (PFTCallTreeNode *node in rootNode.children) {
                                [nodes addObjectsFromArray:flattenTree(node)];
                            }
                        }
                        return nodes;
                    };
                    NSMutableArray<PFTCallTreeNode *> *nodes = flattenTree(backtraceRepository.rootNode);
                    [nodes sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:NSStringFromSelector(@selector(terminals)) ascending:NO]]];
                    for (PFTCallTreeNode *node in nodes) {
                        TUPrint(@"%@ %@ %i ms\n", node.libraryName, node.symbolName, node.terminals);
                    }
                } else if ([instrumentID isEqualToString:@"com.apple.xray.instrument-type.oa"]) {
                    // Allocations: print out the memory allocated during each second in descending order of the size.
                    XRObjectAllocInstrument *allocInstrument = (XRObjectAllocInstrument *)instrument;
                    // 4 contexts: Statistics, Call Trees, Allocations List, Generations.
                    [allocInstrument._topLevelContexts[2] display];
                    XRManagedEventArrayController *arrayController = TUIvar(TUIvar(allocInstrument, _objectListController), _ac);
                    NSMutableDictionary<NSNumber *, NSNumber *> *sizeGroupedByTime = [NSMutableDictionary dictionary];
                    for (XRObjectAllocEvent *event in arrayController.arrangedObjects) {
                        NSNumber *time = @(event.timestamp / NSEC_PER_SEC);
                        NSNumber *size = @(sizeGroupedByTime[time].integerValue + event.size);
                        sizeGroupedByTime[time] = size;
                    }
                    NSArray<NSNumber *> *sortedTime = [sizeGroupedByTime.allKeys sortedArrayUsingComparator:^(NSNumber *time1, NSNumber *time2) {
                        return [sizeGroupedByTime[time2] compare:sizeGroupedByTime[time1]];
                    }];
                    NSByteCountFormatter *byteFormatter = [[NSByteCountFormatter alloc]init];
                    byteFormatter.countStyle = NSByteCountFormatterCountStyleBinary;
                    for (NSNumber *time in sortedTime) {
                        NSString *size = [byteFormatter stringForObjectValue:sizeGroupedByTime[time]];
                        TUPrint(@"%@ %@\n", time, size);
                    }
                } else if ([instrumentID isEqualToString:@"com.apple.dt.coreanimation-fps"]) {
                    // Core Animation FPS: print out all FPS data samples.
                    // 2 contexts: Measurements, Statistics
                    XRContext *context = contexts[0];
                    [context display];
                    XRAnalysisCoreTableViewController *controller = TUIvar(context.container, _tabularViewController);
                    XRAnalysisCorePivotArray *array = controller._currentResponse.content.rows;
                    XREngineeringTypeFormatter *formatter = TUIvarCast(array.source, _filter, XRAnalysisCoreTableQuery * const).fullTextSearchSpec.formatter;
                    [array access:^(XRAnalysisCorePivotArrayAccessor *accessor) {
                        [accessor readRowsStartingAt:0 dimension:0 block:^(XRAnalysisCoreReadCursor *cursor) {
                            while (XRAnalysisCoreReadCursorNext(cursor)) {
                                BOOL result = NO;
                                XRAnalysisCoreValue *object = nil;
                                result = XRAnalysisCoreReadCursorGetValue(cursor, 0, &object);
                                NSString *timestamp = result ? [formatter stringForObjectValue:object] : @"";
                                result = XRAnalysisCoreReadCursorGetValue(cursor, 2, &object);
                                double fps = result ? [object.objectValue doubleValue] : 0;
                                result = XRAnalysisCoreReadCursorGetValue(cursor, 3, &object);
                                double gpu = result ? [object.objectValue doubleValue] : 0;
                                TUPrint(@"%@ %2.0f FPS %4.1f%% GPU\n", timestamp, fps, gpu);
                            }
                        }];
                    }];
                } else if ([instrumentID isEqualToString:@"com.apple.dt.network-connections"]) {
                    // Connections: print out connection history with protocol, addresses and bytes transferred.
                    // 4 contexts: Summary By Process, Summary By Interface, History, Active Connections
                    XRContext *context = contexts[2];
                    [context display];
                    XRAnalysisCoreTableViewController *controller = TUIvar(context.container, _tabularViewController);
                    XRAnalysisCorePivotArray *array = controller._currentResponse.content.rows;
                    XREngineeringTypeFormatter *formatter = TUIvarCast(array.source, _filter, XRAnalysisCoreTableQuery * const).fullTextSearchSpec.formatter;
                    [array access:^(XRAnalysisCorePivotArrayAccessor *accessor) {
                        [accessor readRowsStartingAt:0 dimension:0 block:^(XRAnalysisCoreReadCursor *cursor) {
                            while (XRAnalysisCoreReadCursorNext(cursor)) {
                                BOOL result = NO;
                                XRAnalysisCoreValue *object = nil;
                                result = XRAnalysisCoreReadCursorGetValue(cursor, 4, &object);
                                NSString *interface = result ? [formatter stringForObjectValue:object] : @"";
                                result = XRAnalysisCoreReadCursorGetValue(cursor, 5, &object);
                                NSString *protocol = result ? [formatter stringForObjectValue:object] : @"";
                                result = XRAnalysisCoreReadCursorGetValue(cursor, 6, &object);
                                NSString *local = result ? [formatter stringForObjectValue:object] : @"";
                                result = XRAnalysisCoreReadCursorGetValue(cursor, 7, &object);
                                NSString *remote = result ? [formatter stringForObjectValue:object] : @"";
                                result = XRAnalysisCoreReadCursorGetValue(cursor, 10, &object);
                                NSString *bytesIn = result ? [formatter stringForObjectValue:object] : @"";
                                result = XRAnalysisCoreReadCursorGetValue(cursor, 12, &object);
                                NSString *bytesOut = result ? [formatter stringForObjectValue:object] : @"";
                                TUPrint(@"%@ %@ %@<->%@, %@ in, %@ out\n", interface, protocol, local, remote, bytesIn, bytesOut);
                            }
                        }];
                    }];
                } if ([instrumentID isEqualToString:@"com.apple.xray.instrument-type.vmtrack"]) {
                    XRVMInstrument *vm = (XRVMInstrument *)instrument;
                    [vm _refreshDataSources];
                    NSArray *displayArray = [vm valueForKey:@"_displayArray"];
                    if (displayArray && displayArray.count > 0) {
                        TUPrint(@"Type Resident(byte) Dirty(byte) Swapped(byte) Virtual(byte) \n");
                    }
                    [displayArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        if ( [obj isKindOfClass:XRVMCoalescedRegion.class] ) {
                            XRVMCoalescedRegion *region = (XRVMCoalescedRegion *)obj;
                            TUPrint(@"\"%@\" %@ %@ %@ %@ \n", region.displayType ? region.displayType : [region valueForKey:@"_groupName"],
                                    @(region.residentSize), @(region.dirtySize), @(region.swappedSize), @(region.virtualSize));
                        }
                    }];
                } else {
                    TUPrint(@"Data processor has not been implemented for(%@) this type of instrument.\n", instrumentID);
                }

                // Common routine to cleanup after done.
                if (![instrument isKindOfClass:XRLegacyInstrument.class]) {
                    [instrument.viewController instrumentWillBecomeInvalid];
                    instrument.viewController = nil;
                }
            }
        }

        // Close the document safely.
        [document close];
        PFTClosePlugins();
    }
    return 0;
}
