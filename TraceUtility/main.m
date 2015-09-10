//
//  main.m
//  TraceUtility
//
//  Created by Qusic on 7/9/15.
//  Copyright (c) 2015 Qusic. All rights reserved.
//

#import "InstrumentsPrivateHeader.h"

#define NSPrint(format, ...) CFShow((__bridge CFStringRef)[NSString stringWithFormat:format, ## __VA_ARGS__])

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Required. Each instrument is a plugin and we have to load them before we can process their data.
        PFTLoadPlugins();

        // Open a trace document.
        XRTrace *trace = [[XRTrace alloc]initForCommandLine:NO];
        NSError *error;
        NSString *tracePath = @"/Users/qusic/Downloads/Instruments.trace";
        [trace loadDocument:[NSURL fileURLWithPath:tracePath] error:&error];
        if (error) {
            NSLog(@"Error: %@", error);
            return 1;
        }

        // Each trace document consists of data from several different instruments.
        for (XRInstrument *instrument in trace.basicInstruments.allInstruments) {
            NSPrint(@"%@: %@ - %@ (%@ %@ %@)\n", instrument.type.name, instrument.target.displayName, instrument.target.device.deviceDisplayName, instrument.target.device.productType, instrument.target.device.productVersion, instrument.target.device.buildVersion);

            // You can have multiple runs for each instrument.
            for (XRRun *run in instrument.allRuns) {

                // Here is only one example for runs of the instrument Time Profiler. However it is not difficult for other instruments once we get started.
                if ([run isKindOfClass:NSClassFromString(@"XRSamplerRun")]) {
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

                    XRBacktraceRepository *backtraceRepository = ((XRSamplerRun *)run).backtraceRepository;
                    [backtraceRepository refreshTreeRoot]; // Load the tree.

                    // Process the data as you want.
                    NSMutableArray *nodes = flattenTree(backtraceRepository.rootNode);
                    [nodes sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:NSStringFromSelector(@selector(terminals)) ascending:NO]]];
                    for (PFTCallTreeNode *node in nodes) {
                        // See the header file for more information about properties of nodes.
                        NSPrint(@"%@ %@ %i ms", node.libraryName, node.symbolName, node.terminals);
                    }

                }
                NSPrint(@"\n");
            }

        }
    }
    return 0;
}
