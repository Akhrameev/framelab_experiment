import XCTest
import UIKit
import FrameLab

final class FrameRendererTests: XCTestCase {
    func testEffectsExportFrames() throws {
        let renderer = try FrameRenderer()
        for effect in Effect.allCases {
            for frame: UInt32 in [0, 1] {
                let image = try renderer.render(frame: frame, effect: effect)
                XCTAssertEqual(image.size, CGSize(width: 256, height: 192))
                let png = try XCTUnwrap(image.pngData())
                XCTAssertNotNil(UIImage(data: png))
                let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
                attachment.name = "\(effect.rawValue)-frame-\(frame)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }
}
