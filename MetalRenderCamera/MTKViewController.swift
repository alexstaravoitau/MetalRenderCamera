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
public class MTKViewController: UIViewController {

    // MARK: - Public interface
    
    /// Metal texture to be drawn whenever the view controller is asked to render its view. Please note that if you set this `var` too frequently some of the textures may not being drawn, as setting a texture does not force the view controller's view to render its content.
    public var texture: MTLTexture?
    
    /**
     This method is called prior rendering view's content. Use `inout` `texture` parameter to update the texture that is about to be drawn.
     
     - parameter texture:       Texture to be drawn
     - parameter commandBuffer: Command buffer that will be used for drawing
     - parameter device:        Metal device
     */
    public func willRenderTexture(inout texture: MTLTexture, withCommandBuffer commandBuffer: MTLCommandBuffer, device: MTLDevice) {
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
    public func didRenderTexture(texture: MTLTexture, withCommandBuffer commandBuffer: MTLCommandBuffer, device: MTLDevice) {
        /**
         * Override if neccessary
         */
    }

    // MARK: - Public overrides
    
    override public func loadView() {
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
    private func initializeMetalView() {
#if arch(i386) || arch(x86_64)
#else
        metalView = MTKView(frame: view.bounds, device: device)
        metalView.delegate = self
        metalView.framebufferOnly = true
        metalView.colorPixelFormat = .BGRA8Unorm
        metalView.contentScaleFactor = UIScreen.mainScreen().scale
        metalView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        view.insertSubview(metalView, atIndex: 0)
#endif
    }

#if arch(i386) || arch(x86_64)
#else
    /// `UIViewController`'s view
    private var metalView: MTKView!
#endif

    /// Metal device
    private var device = MTLCreateSystemDefaultDevice()

    /// Metal pipeline state we use for rendering
    private var renderPipelineState: MTLRenderPipelineState?

    /// A semaphore we use to syncronize drawing code.
    private let semaphore = dispatch_semaphore_create(1)

    /**
     initializes render pipeline state with a default vertex function mapping texture to the view's frame and a simple fragment function returning texture pixel's value.
     */
    private func initializeRenderPipelineState() {
        guard let
            device = device,
            library = device.newDefaultLibrary()
        else { return }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.sampleCount = 1
        pipelineDescriptor.colorAttachments[0].pixelFormat = .BGRA8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .Invalid
        
        /**
         *  Vertex function to map the texture to the view controller's view
         */
        pipelineDescriptor.vertexFunction = library.newFunctionWithName("mapTexture")
        /**
         *  Fragment function to display texture's pixels in the area bounded by vertices of `mapTexture` shader
         */
        pipelineDescriptor.fragmentFunction = library.newFunctionWithName("displayTexture")
        
        do {
            try renderPipelineState = device.newRenderPipelineStateWithDescriptor(pipelineDescriptor)
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
    
    public func mtkView(view: MTKView, drawableSizeWillChange size: CGSize) {
        NSLog("MTKView drawable size will change to \(size)")
    }
    
    public func drawInMTKView(view: MTKView) {
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)

        autoreleasepool {
            guard
                var texture = texture,
                let device = device
            else {
                dispatch_semaphore_signal(semaphore)
                return
            }
            
            let commandBuffer = device.newCommandQueue().commandBuffer()

            willRenderTexture(&texture, withCommandBuffer: commandBuffer, device: device)
            render(texture, withCommandBuffer: commandBuffer, device: device)
        }
    }
    
    /**
     Renders texture into the `UIViewController`'s view.
     
     - parameter texture:       Texture to be rendered
     - parameter commandBuffer: Command buffer we will use for drawing
     */
    private func render(texture: MTLTexture, withCommandBuffer commandBuffer: MTLCommandBuffer, device: MTLDevice) {
        guard let
            currentRenderPassDescriptor = metalView.currentRenderPassDescriptor,
            currentDrawable = metalView.currentDrawable,
            renderPipelineState = renderPipelineState
        else {
            dispatch_semaphore_signal(semaphore)
            return
        }
        
        let encoder = commandBuffer.renderCommandEncoderWithDescriptor(currentRenderPassDescriptor)
        encoder.pushDebugGroup("RenderFrame")
        encoder.setRenderPipelineState(renderPipelineState)
        encoder.setFragmentTexture(texture, atIndex: 0)
        encoder.drawPrimitives(.TriangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: 1)
        encoder.popDebugGroup()
        encoder.endEncoding()
        
        commandBuffer.addScheduledHandler { [weak self] (buffer) in
            guard let unwrappedSelf = self else { return }
            
            unwrappedSelf.didRenderTexture(texture, withCommandBuffer: buffer, device: device)
            dispatch_semaphore_signal(unwrappedSelf.semaphore)
        }
        commandBuffer.presentDrawable(currentDrawable)
        commandBuffer.commit()
    }
}

#endif
