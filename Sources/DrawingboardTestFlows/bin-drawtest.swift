import TestFlows

@main
enum DrawingboardTestFlowsMain {
    static func main() async {
        await TestFlowCLI.run(
            suite: DrawingboardFlowSuite.self
        )
    }
}
