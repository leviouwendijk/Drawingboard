import TestFlows

enum DrawingboardFlowSuite: TestFlowRegistry {
    static let title = "Drawingboard"

    static let flows: [TestFlow] = [
        documentFlow,
        messageCodecFlow,
        runtimeFlow,
        viewportFlow,
        eventLogFlow,
        loopbackTransportFlow,
        networkTransportFlow,
        padBatchingFlow,
        padAppRuntimeFlow,
        padNetworkSessionFlow,
        renderCommandFlow,
        hostEventLogFlow,
        eventLogStoreFlow,
        recordingManifestFlow,
        recordingReplayFlow,
        eventLogIncrementalStoreFlow,
        eventLogTimingFlow,
    ]
}
