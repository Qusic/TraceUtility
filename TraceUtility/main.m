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
        DVTInitializeSharedFrameworks();
        [DVTDeveloperPaths initializeApplicationDirectoryName:@"Instruments"];
        [XRInternalizedSettingsStore configureWithAdditionalURLs:nil];
        PFTLoadPlugins();
        [PFTDocumentController sharedDocumentController];

        NSString *tracePath = @"/Users/banli/Downloads/Instruments.trace";

        NSError *error = nil;
        PFTTraceDocument *document = [[PFTTraceDocument alloc]initWithContentsOfURL:[NSURL fileURLWithPath:tracePath] ofType:@"Trace Document" error:&error];
        if (error) {
            TUPrint(@"Error: %@\n", error);
            return 1;
        }

        XRDevice *device = document.targetDevice;
        TUPrint(@"Device: %@ (%@ %@ %@)\n", device.deviceDisplayName, device.productType, device.productVersion, device.buildVersion);
        PFTProcess *process = document.defaultProcess;
        TUPrint(@"Process: %@ (%@)\n", process.displayName, process.bundleIdentifier);

        XRTrace *trace = document.trace;
        for (XRInstrument *instrument in trace.basicInstruments.allInstruments) {
            TUPrint(@"Instrument: %@\n", instrument.type.name);
            XRAnalysisCoreStandardController *analysisController = [[XRAnalysisCoreStandardController alloc]initWithInstrument:instrument document:document];
            instrument.viewController = analysisController;
            [analysisController instrumentDidChangeSwitches];
            [analysisController instrumentChangedTableRequirements];
            XRAnalysisCoreDetailViewController *detailController = analysisController.detailFilteredDataSource;
            [detailController _afterRebuildingUIPerformBlock:nil];
            id<XRContextContainer> detailContainer = detailController.contextRepresentation.container;
            if ([detailContainer isKindOfClass:XRCallTreeDetailView.class]) {
                TUPrint(@"");
            }
        }

        [document close];

//        // Each trace document consists of data from several different instruments.
//        for (XRInstrument *instrument in trace.basicInstruments.allInstruments) {
//            NSPrint(@"# %@\n", instrument.type.name);
//
//            // You can have multiple runs for each instrument.
//            for (XRRun *run in instrument.allRuns) {
//                NSPrint(@"## %@ - %@ (%@ %@ %@)\n", run.displayName, run.device.deviceDisplayName, run.device.productType, run.device.productVersion, run.device.buildVersion);
//
//                XRAnalysisCoreStandardController *controller = [XRAnalysisCoreStandardController alloc];
//
////                XRMultiProcessBacktraceRepository *backtraceRepository = [[XRMultiProcessBacktraceRepository alloc]initWithDevice:run.device trace:trace runNumber:run.runNumber weightCount:1];
////                [backtraceRepository refreshTreeRoot]; // Load the tree.
////                
////                // Process the data as you want.
////                static NSMutableArray * (^ const flattenTree)(PFTCallTreeNode *) = ^(PFTCallTreeNode *rootNode) {
////                    NSMutableArray *nodes = [NSMutableArray array];
////                    if (rootNode) {
////                        [nodes addObject:rootNode];
////                        for (PFTCallTreeNode *node in rootNode.children) {
////                            [nodes addObjectsFromArray:flattenTree(node)];
////                        }
////                    }
////                    return nodes;
////                };
////                NSMutableArray *nodes = flattenTree(backtraceRepository.rootNode);
////                [nodes sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:NSStringFromSelector(@selector(terminals)) ascending:NO]]];
////                for (PFTCallTreeNode *node in nodes) {
////                    // See the header file for more information about properties of nodes.
////                    NSPrint(@"%@ %@ %i ms", node.libraryName, node.symbolName, node.terminals);
////                }
//
//                NSPrint(@"\n");
//            }
//
//        }
    }
    return 0;
}
