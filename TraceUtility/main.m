//
//  main.m
//  TraceUtility
//
//  Created by Qusic on 7/9/15.
//  Copyright (c) 2015 Qusic. All rights reserved.
//

#import "InstrumentsPrivateHeader.h"

#define TUPrint(format, ...) CFShow((__bridge CFStringRef)[NSString stringWithFormat:format, ## __VA_ARGS__])

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Required. Each instrument is a plugin and we have to load them before we can process their data.
        DVTInitializeSharedFrameworks();
        [DVTDeveloperPaths initializeApplicationDirectoryName:@"Instruments"];
        [XRInternalizedSettingsStore configureWithAdditionalURLs:nil];
        PFTLoadPlugins();

        // Instruments has its own subclass of NSDocumentController without overriding sharedDocumentController method.
        // We have to call this eagerly to make sure the correct document controller is initialized.
        [PFTDocumentController sharedDocumentController];

        // Open a trace document.
        NSString *tracePath = @"/Users/qusic/Downloads/Instruments.trace";
        NSError *error = nil;
        PFTTraceDocument *document = [[PFTTraceDocument alloc]initWithContentsOfURL:[NSURL fileURLWithPath:tracePath] ofType:@"Trace Document" error:&error];
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
        for (XRInstrument *instrument in trace.basicInstruments.allInstruments) {
            TUPrint(@"\nInstrument: %@ (%@)\n", instrument.type.name, instrument.type.uuid);

            // Common routine to obtain the data container.
            instrument.viewController = [[XRAnalysisCoreStandardController alloc]initWithInstrument:instrument document:document];
            id<XRInstrumentViewController> controller = instrument.viewController;
            [controller instrumentDidChangeSwitches];
            [controller instrumentChangedTableRequirements];
            id<XRContextContainer> container = controller.detailContextContainer.contextRepresentation.container;

            // Each instrument can have multiple runs.
            NSArray<XRRun *> *runs = instrument.allRuns;
            if (runs.count == 0) {
                TUPrint(@"No data.\n");
                continue;
            }
            for (XRRun *run in runs) {
                TUPrint(@"Run #%@: %@\n", @(run.runNumber), run.displayName);
                instrument.currentRun = run;

                // Different instruments can have different data structure.
                // Here are some straightforward example code demonstrating how to process the data from several commonly used instruments.
                NSString *instrumentID = instrument.type.uuid;
                if ([instrumentID isEqualToString:@"com.apple.xray.instrument-type.coresampler2"]) {
                    continue;
                    // Time Profiler: print out all functions in descending order of self execution time.
                    XRCallTreeDetailView *callTreeView = (XRCallTreeDetailView *)container;
                    XRBacktraceRepository *backtraceRepository = callTreeView.backtraceRepository;
                    static NSMutableArray * (^ const flattenTree)(PFTCallTreeNode *) = ^(PFTCallTreeNode *rootNode) {
                        NSMutableArray *nodes = [NSMutableArray array];
                        if (rootNode) {
                            [nodes addObject:rootNode];
                            for (PFTCallTreeNode *node in rootNode.children) {
                                [nodes addObjectsFromArray:flattenTree(node)];
                            }
                        }
                        return nodes;
                    };
                    NSMutableArray *nodes = flattenTree(backtraceRepository.rootNode);
                    [nodes sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:NSStringFromSelector(@selector(terminals)) ascending:NO]]];
                    for (PFTCallTreeNode *node in nodes) {
                        TUPrint(@"%@ %@ %ims\n", node.libraryName, node.symbolName, node.terminals);
                    }
                } else if ([instrumentID isEqualToString:@"com.apple.xray.instrument-type.oa"]) {
                    // Allocations:
                    XRObjectAllocInstrument *allocInstrument = (XRObjectAllocInstrument *)container;
                } else if ([instrumentID isEqualToString:@"com.apple.xray.instrument-type.coreanimation"]) {
                    continue;
                    // Core Animation:
                } else if ([instrumentID isEqualToString:@"com.apple.xray.instrument-type.networking"]) {
                    continue;
                    // Connections:
                } else if ([instrumentID isEqualToString:@"com.apple.xray.power.mobile.energy"]) {
                    continue;
                    // Energy Usage Log:
                } else {
                    TUPrint(@"Data processor has not been implemented for this type of instrument.\n");
                }
            }
        }

        // Close the document safely.
        [document close];
    }
    return 0;
}
