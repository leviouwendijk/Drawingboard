import DrawingboardCore
import DrawingboardProtocol
import TestFlows

let messageCodecFlow = TestFlow(
    "message.codec",
    title: "Message codec"
) {
    let message = DrawingMessage.hello(
        DrawingHello(
            role: .pad,
            deviceName: "iPad Mini"
        )
    )

    let codec = DrawingMessageCodec()
    let data = try codec.encode(
        message
    )
    let decoded = try codec.decode(
        data
    )

    try Expect.equal(
        decoded,
        message,
        "message survives JSON roundtrip"
    )

    return []
}
