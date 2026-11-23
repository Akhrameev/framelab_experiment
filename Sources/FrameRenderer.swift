import Metal
import UIKit

public enum Effect: String, CaseIterable {
    case tone, poster, sticker
}

public final class FrameRenderer {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLComputePipelineState
    private let colorSpace = CGColorSpaceCreateDeviceRGB()

    public init() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else { throw RenderError.metalUnavailable }
        self.device = device
        self.queue = queue
        let library = try device.makeLibrary(source: """
        #include <metal_stdlib>
        using namespace metal;
        kernel void processFrame(texture2d<float, access::write> output [[texture(0)]],
                                 constant uint &frame [[buffer(0)]],
                                 constant uint &effect [[buffer(1)]],
                                 uint2 p [[thread_position_in_grid]]) {
            if (p.x >= output.get_width() || p.y >= output.get_height()) return;
            float3 source = float3((p.x + frame) % 2, p.y % 2, (p.x + p.y / 2 + frame) % 2);
            float3 result = effect == 0 ? 1.0 - source : source;
            output.write(float4(result, 1.0), p);
        }
        """, options: nil)
        guard let function = library.makeFunction(name: "processFrame") else { throw RenderError.allocation }
        pipeline = try device.makeComputePipelineState(function: function)
    }

    public func render(frame: UInt32, effect: Effect) throws -> UIImage {
        let texture = try processedTexture(frame: frame, effect: effect)
        let image: CGImage
        switch effect {
        case .tone:
            image = try exportTexture(texture)
        case .poster, .sticker:
            image = try snapshot(texture)
        }
        // The export surface is opaque, as in a video frame. Artwork can remain
        // visible even when some other part of the composition is missing.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: 256, height: 192), format: format).image { renderer in
            UIColor.black.setFill()
            renderer.fill(CGRect(x: 0, y: 0, width: 256, height: 192))
            renderer.cgContext.interpolationQuality = .none
            UIImage(cgImage: image).draw(in: CGRect(x: 0, y: 0, width: 256, height: 192))
            if effect == .sticker {
                UIColor(red: 1, green: 0.25, blue: 0.1, alpha: 1).setFill()
                renderer.fill(CGRect(x: 176, y: 16, width: 64, height: 48))
                ("FX" as NSString).draw(at: CGPoint(x: 186, y: 24), withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 28), .foregroundColor: UIColor.white
                ])
            }
        }
    }

    private func processedTexture(frame: UInt32, effect: Effect) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                                                                  width: 8, height: 8, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: descriptor),
              let command = queue.makeCommandBuffer(),
              let encoder = command.makeComputeCommandEncoder() else { throw RenderError.allocation }
        var frameValue = frame
        var effectValue: UInt32 = effect == .tone ? 0 : 1
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(texture, index: 0)
        encoder.setBytes(&frameValue, length: MemoryLayout<UInt32>.size, index: 0)
        encoder.setBytes(&effectValue, length: MemoryLayout<UInt32>.size, index: 1)
        encoder.dispatchThreadgroups(MTLSize(width: 1, height: 1, depth: 1),
                                     threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
        encoder.endEncoding()
        command.commit()
        command.waitUntilCompleted()
        guard command.status == .completed else { throw command.error ?? RenderError.commandFailed }
        return texture
    }

    private func exportTexture(_ texture: MTLTexture) throws -> CGImage {
        guard let context = CGContext(data: nil, width: texture.width, height: texture.height,
                                      bitsPerComponent: 8, bytesPerRow: texture.width * 4,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let pointer = context.data else { throw RenderError.allocation }
        texture.getBytes(pointer, bytesPerRow: texture.width * 4,
                         from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
        guard let image = context.makeImage() else { throw RenderError.allocation }
        return image
    }

    private func snapshot(_ texture: MTLTexture) throws -> CGImage {
        let width = texture.width, height = texture.height
        let bytesPerRow = width * 4
        var data = [UInt8](repeating: 0, count: bytesPerRow * height)
        texture.getBytes(&data, bytesPerRow: bytesPerRow,
                         from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        guard let context = CGContext(data: &data, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let image = context.makeImage() else { throw RenderError.allocation }
        return image
    }
}

private enum RenderError: Error {
    case metalUnavailable, allocation, commandFailed
}
