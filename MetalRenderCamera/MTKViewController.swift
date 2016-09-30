//
//  MTKViewController.swift
//  MetalShaderCamera
//
//  Created by Alex Staravoitau on 26/04/2016.
//  Copyright © 2016 Old Yellow Bricks. All rights reserved.
//

import UIKit
import Metal

#if arch(i386) || arch(x86_64)
#else
    import MetalKit
#endif

/**
 * A `UIViewController` that allows quick and easy rendering of Metal textures. Currently only supports textures from single-plane pixel buffers, e.g. it can only render a single RGB texture and won't be able to render multiple YCbCr textures. Although this functionality can be added by overriding `MTKViewController`'s `willRenderTexture` method.
 */
open class MTKViewController: UIViewController {

    // MARK: - Public interface
    
    /// Metal texture to be drawn whenever the view controller is asked to render its view. Please note that if you set this `var` too frequently some of the textures may not being drawn, as setting a texture does not force the view controller's view to render its content.
    open var texture: MTLTexture?
    
    /**
     This method is called prior rendering view's content. Use `inout` `texture` parameter to update the texture that is about to be drawn.
     
     - parameter texture:       Texture to be drawn
     - parameter commandBuffer: Command buffer that will be used for drawing
     - parameter device:        Metal device
     */
    open func willRenderTexture(_ texture: inout MTLTexture, withCommandBuffer commandBuffer: MTLCommandBuffer, device: MTLDevice) {
        /**
         * Override if neccessary
         */
    }
    
    /**
     This method is called after rendering view's content.
     
     - parameter texture:       Texture that was drawn
     - parameter commandBuffer: Command buffer we used for drawing
     - parameter device:        Metal device
     */
    open func didRenderTexture(_ texture: MTLTexture, withCommandBuffer commandBuffer: MTLCommandBuffer, device: MTLDevice) {
        /**
         * Override if neccessary
         */
    }

    // MARK: - Public overrides
    
    override open func loadView() {
        super.loadView()
#if arch(i386) || arch(x86_64)
        NSLog("Failed creating a default system Metal device, since Metal is not available on iOS Simulator.")
#else
        assert(device != nil, "Failed creating a default system Metal device. Please, make sure Metal is available on your hardware.")
#endif
        initializeMetalView()
        initializeRenderPipelineState()
    }
    
    // MARK: - Private Metal-related properties and methods
    
    /**
     initializes and configures the `MTKView` we use as `UIViewController`'s view.
     
     */
    fileprivate func initializeMetalView() {
#if arch(i386) || arch(x86_64)
#else
        metalView = MTKView(frame: view.bounds, device: device)
        metalView.delegate = self
        metalView.framebufferOnly = true
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.contentScaleFactor = UIScreen.main.scale
        metalView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(metalView, at: 0)
#endif
    }

#if arch(i386) || arch(x86_64)
#else
    /// `UIViewController`'s view
    internal var metalView: MTKView!
#endif

    /// Metal device
    internal var device = MTLCreateSystemDefaultDevice()

    /// Metal pipeline state we use for rendering
    internal var renderPipelineState: MTLRenderPipelineState?

    /// A semaphore we use to syncronize drawing code.
    fileprivate let semaphore = DispatchSemaphore(value: 1)

    /**
     initializes render pipeline state with a default vertex function mapping texture to the view's frame and a simple fragment function returning texture pixel's value.
     */
    fileprivate func initializeRenderPipelineState() {
        guard
            let device = device,
            let library = device.newDefaultLibrary()
        else { return }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.sampleCount = 1
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .invalid
        
        /**
         *  Vertex function to map the texture to the view controller's view
         */
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "mapTexture")
        /**
         *  Fragment function to display texture's pixels in the area bounded by vertices of `mapTexture` shader
         */
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "displayTexture")
        
        do {
            try renderPipelineState = device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        }
        catch {
            assertionFailure("Failed creating a render state pipeline. Can't render the texture without one.")
            return
        }
    }
}

#if arch(i386) || arch(x86_64)
#else

// MARK: - MTKViewDelegate and rendering
extension MTKViewController: MTKViewDelegate {

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        NSLog("MTKView drawable size will change to \(size)")
    }
    
    public func draw(in: MTKView) {
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)

        autoreleasepool {
            guard
                var texture = texture,
                let device = device
            else {
                _ = semaphore.signal()
                return
            }
            
            let commandBuffer = device.makeCommandQueue().makeCommandBuffer()

            willRenderTexture(&texture, withCommandBuffer: commandBuffer, device: device)
            render(texture: texture, withCommandBuffer: commandBuffer, device: device)
        }
    }
    
    /**
     Renders texture into the `UIViewController`'s view.
     
     - parameter texture:       Texture to be rendered
     - parameter commandBuffer: Command buffer we will use for drawing
     */
    private func render(texture: MTLTexture, withCommandBuffer commandBuffer: MTLCommandBuffer, device: MTLDevice) {
        guard
            let currentRenderPassDescriptor = metalView.currentRenderPassDescriptor,
            let currentDrawable = metalView.currentDrawable,
            let renderPipelineState = renderPipelineState
        else {
            semaphore.signal()
            return
        }
        
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: currentRenderPassDescriptor)
        encoder.pushDebugGroup("RenderFrame")
        encoder.setRenderPipelineState(renderPipelineState)
        encoder.setFragmentTexture(texture, at: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: 1)
        encoder.popDebugGroup()
        encoder.endEncoding()
        
        commandBuffer.addScheduledHandler { [weak self] (buffer) in
            guard let unwrappedSelf = self else { return }
            
            unwrappedSelf.didRenderTexture(texture, withCommandBuffer: buffer, device: device)
            unwrappedSelf.semaphore.signal()
        }
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
}

#endif
