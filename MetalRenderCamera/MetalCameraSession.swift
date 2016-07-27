//
//  MetalCameraSession.swift
//  MetalShaderCamera
//
//  Created by Alex Staravoitau on 24/04/2016.
//  Copyright © 2016 Old Yellow Bricks. All rights reserved.
//

import AVFoundation
import Metal

/**
 *  A protocol for a delegate that may be notified about the capture session events.
 */
public protocol MetalCameraSessionDelegate {

    /**
     Camera session did receive a new frame and converted it to an array of Metal textures. For instance, if the RGB pixel format was selected, the array will have a single texture, whereas if YCbCr was selected, then there will be two textures: the Y texture at index 0, and CbCr texture at index 1 (following the order in a sample buffer).
     
     - parameter session:                   Session that triggered the update
     - parameter didReceiveFrameAsTextures: Frame converted to an array of Metal textures
     - parameter withTimestamp:             Frame timestamp in seconds
     */
    func metalCameraSession(session: MetalCameraSession, didReceiveFrameAsTextures: [MTLTexture], withTimestamp: Double)
    
    /**
     Camera session did update capture state
     
     - parameter session:        Session that triggered the update
     - parameter didUpdateState: Capture session state
     - parameter error:          Capture session error or `nil`
     */
    func metalCameraSession(session: MetalCameraSession, didUpdateState: MetalCameraSessionState, error: MetalCameraSessionError?)
}

/**
 * A convenient hub for accessing camera data as a stream of Metal textures with corresponding timestamps.
 *
 * Keep in mind that frames arrive in a hardware orientation by default, e.g. `.LandscapeRight` for the rear camera. You can set the `frameOrientation` property to override this behavior and apply auto rotation to each frame.
 */
public final class MetalCameraSession: NSObject {
    
    // MARK: Public interface
    
    /// Frame orienation. If you want to receive frames in orientation other than the hardware default one, set this `var` and this value will be picked up when converting next frame. Although keep in mind that any rotation comes at a performance cost.
    public var frameOrientation: AVCaptureVideoOrientation? {
        didSet {
            guard let
                frameOrientation = frameOrientation,
                outputData = outputData
                where outputData.connectionWithMediaType(AVMediaTypeVideo).supportsVideoOrientation
            else { return }

            outputData.connectionWithMediaType(AVMediaTypeVideo).videoOrientation = frameOrientation
        }
    }
    /// Requested capture device position, e.g. camera
    public let captureDevicePosition: AVCaptureDevicePosition

    /// Delegate that will be notified about state changes and new frames
    public var delegate: MetalCameraSessionDelegate?

    /// Pixel format to be used for grabbing camera data and converting textures
    public let pixelFormat: MetalCameraPixelFormat
    
    /**
     initialized a new instance, providing optional values.
     
     - parameter pixelFormat:           Pixel format. Defaults to `.RGB`
     - parameter captureDevicePosition: Camera to be used for capturing. Defaults to `.Back`.
     - parameter delegate:              Delegate. Defaults to `nil`.
     
     */
    public init(pixelFormat: MetalCameraPixelFormat = .RGB, captureDevicePosition: AVCaptureDevicePosition = .Back, delegate: MetalCameraSessionDelegate? = nil) {
        self.pixelFormat = pixelFormat
        self.captureDevicePosition = captureDevicePosition
        self.delegate = delegate
        super.init();

        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector(captureSessionRuntimeError()), name: AVCaptureSessionRuntimeErrorNotification, object: nil)
    }
    
    /**
     Starts the capture session. Call this method to start receiving delegate updates with the sample buffers.
     */
    public func start() {
        requestCameraAccess()

        dispatch_async(captureSessionQueue, {
            do {
                self.captureSession.beginConfiguration()
                try self.initializeInputDevice()
                try self.initializeOutputData()
                self.captureSession.commitConfiguration()
                try self.initializeTextureCache()
                self.captureSession.startRunning()
                self.state = .Streaming
            }
            catch let error as MetalCameraSessionError {
                self.handleError(error)
            }
            catch {
                /**
                 * We only throw `MetalCameraSessionError` errors.
                 */
            }
        })
    }

    /**
     Stops the capture session.
     */
    public func stop() {
        dispatch_async(captureSessionQueue, {
            self.captureSession.stopRunning()
            self.state = .Stopped
        })
    }
    
    // MARK: Private properties and methods
    
    /// Current session state.
    private var state: MetalCameraSessionState = .Waiting {
        didSet {
            guard state != .Error else { return }
            
            delegate?.metalCameraSession(self, didUpdateState: state, error: nil)
        }
    }

    /// `AVFoundation` capture session object.
    private var captureSession = AVCaptureSession()

    /// Our internal wrapper for the `AVCaptureDevice`. Making it internal to stub during testing.
    internal var captureDevice = MetalCameraCaptureDevice()

    /// Dispatch queue for capture session events.
    private var captureSessionQueue = dispatch_queue_create("MetalCameraSessionQueue", DISPATCH_QUEUE_SERIAL)

#if arch(i386) || arch(x86_64)
#else
    /// Texture cache we will use for converting frame images to textures
    private var textureCache: Unmanaged<CVMetalTextureCacheRef>?
#endif

    /// `MTLDevice` we need to initialize texture cache
    private var metalDevice = MTLCreateSystemDefaultDevice()

    /// Current capture input device.
    internal var inputDevice: AVCaptureDeviceInput? {
        didSet {
            if let oldValue = oldValue {
                captureSession.removeInput(oldValue)
            }

            captureSession.addInput(inputDevice)
        }
    }
    
    /// Current capture output data stream.
    internal var outputData: AVCaptureVideoDataOutput? {
        didSet {
            if let oldValue = oldValue {
                captureSession.removeOutput(oldValue)
            }
            
            captureSession.addOutput(outputData)
        }
    }

    /**
     Requests access to camera hardware.
     */
    private func requestCameraAccess() {
        captureDevice.requestAccessForMediaType(AVMediaTypeVideo) {
            (granted: Bool) -> Void in
            guard granted else {
                self.handleError(.NoHardwareAccess)
                return
            }
            
            if self.state != .Streaming && self.state != .Error {
                self.state = .Ready
            }
        }
    }
    
    private func handleError(error: MetalCameraSessionError) {
        if error.isStreamingError() {
            state = .Error
        }

        delegate?.metalCameraSession(self, didUpdateState: state, error: error)
    }

    /**
     initialized the texture cache. We use it to convert frames into textures.
     
     */
    private func initializeTextureCache() throws {
#if arch(i386) || arch(x86_64)
        throw MetalCameraSessionError.FailedToCreateTextureCache
#else
        guard let
            metalDevice = metalDevice
            where CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, metalDevice, nil, &textureCache) == kCVReturnSuccess
        else {
            throw MetalCameraSessionError.FailedToCreateTextureCache
        }
#endif
    }

    /**
     initializes capture input device with specified media type and device position.
     
     - throws: `MetalCameraSessionError` if we failed to initialize and add input device.
     
     */
    private func initializeInputDevice() throws {
        var captureInput: AVCaptureDeviceInput!

        guard let inputDevice = captureDevice.deviceWithMediaType(AVMediaTypeVideo, position: captureDevicePosition) else {
            throw MetalCameraSessionError.RequestedHardwareNotFound
        }

        do {
            captureInput = try AVCaptureDeviceInput(device: inputDevice)
        }
        catch {
            throw MetalCameraSessionError.InputDeviceNotAvailable
        }
        
        guard captureSession.canAddInput(captureInput) else {
            throw MetalCameraSessionError.FailedToAddCaptureInputDevice
        }
        
        self.inputDevice = captureInput
    }
    
    /**
     initializes capture output data stream.
     
     - throws: `MetalCameraSessionError` if we failed to initialize and add output data stream.
     
     */
    private func initializeOutputData() throws {
        let outputData = AVCaptureVideoDataOutput()

        outputData.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey : Int(pixelFormat.coreVideoType)
        ]
        outputData.alwaysDiscardsLateVideoFrames = true
        outputData.setSampleBufferDelegate(self, queue: captureSessionQueue)
        
        guard captureSession.canAddOutput(outputData) else {
            throw MetalCameraSessionError.FailedToAddCaptureOutput
        }
        
        self.outputData = outputData
    }
    
    /**
     `AVCaptureSessionRuntimeErrorNotification` callback.
     */
    private func captureSessionRuntimeError() {
        if state == .Streaming {
            handleError(.CaptureSessionRuntimeError)
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension MetalCameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {

#if arch(i386) || arch(x86_64)
#else

    /**
     Converts a sample buffer received from camera to a Metal texture
     
     - parameter sampleBuffer: Sample buffer
     - parameter textureCache: Texture cache
     - parameter planeIndex:   Index of the plane for planar buffers. Defaults to 0.
     - parameter pixelFormat:  Metal pixel format. Defaults to `.BGRA8Unorm`.
     
     - returns: Metal texture or nil
     */
    private func textureWithSampleBuffer(sampleBuffer: CMSampleBuffer?, textureCache: Unmanaged<CVMetalTextureCacheRef>?, planeIndex: Int = 0, pixelFormat: MTLPixelFormat = .BGRA8Unorm) throws -> MTLTexture {
        guard let sampleBuffer = sampleBuffer else {
            throw MetalCameraSessionError.MissingSampleBuffer
        }
        guard let textureCache = textureCache else {
            throw MetalCameraSessionError.FailedToCreateTextureCache
        }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            throw MetalCameraSessionError.FailedToGetImageBuffer
        }
        
        let isPlanar = CVPixelBufferIsPlanar(imageBuffer)
        let width = isPlanar ? CVPixelBufferGetWidthOfPlane(imageBuffer, planeIndex) : CVPixelBufferGetWidth(imageBuffer)
        let height = isPlanar ? CVPixelBufferGetHeightOfPlane(imageBuffer, planeIndex) : CVPixelBufferGetHeight(imageBuffer)
        
        var textureRef: Unmanaged<CVMetalTextureRef>?
        
        let result = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache.takeUnretainedValue(), imageBuffer, nil, pixelFormat, width, height, planeIndex, &textureRef)

        guard let
            unwrappedTextureRef = textureRef,
            texture = CVMetalTextureGetTexture(unwrappedTextureRef.takeUnretainedValue())
            where result == kCVReturnSuccess
        else {
            throw MetalCameraSessionError.FailedToCreateTextureFromImage
        }
        
        unwrappedTextureRef.release()
        
        return texture
    }
    
    /**
     Strips out the timestamp value out of the sample buffer received from camera.
     
     - parameter sampleBuffer: Sample buffer with the frame data
     
     - returns: Double value for a timestamp in seconds or nil
     */
    private func timestampWithSampleBuffer(sampleBuffer: CMSampleBuffer?) throws -> Double {
        guard let sampleBuffer = sampleBuffer else {
            throw MetalCameraSessionError.MissingSampleBuffer
        }
        
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        guard time != kCMTimeInvalid else {
            throw MetalCameraSessionError.FailedToRetrieveTimestamp
        }
        
        return (Double)(time.value) / (Double)(time.timescale);
    }
    
    @objc public func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        do {
            var textures: [MTLTexture]!
            
            switch pixelFormat {
            case .RGB:
                let textureRGB = try textureWithSampleBuffer(sampleBuffer, textureCache: textureCache)
                textures = [textureRGB]
            case .YCbCr:
                let textureY = try textureWithSampleBuffer(sampleBuffer, textureCache: textureCache, planeIndex: 0, pixelFormat: .R8Unorm)
                let textureCbCr = try textureWithSampleBuffer(sampleBuffer, textureCache: textureCache, planeIndex: 1, pixelFormat: .RG8Unorm)
                textures = [textureY, textureCbCr]
            }
            
            let timestamp = try timestampWithSampleBuffer(sampleBuffer)
            
            delegate?.metalCameraSession(self, didReceiveFrameAsTextures: textures, withTimestamp: timestamp)
        }
        catch let error as MetalCameraSessionError {
            self.handleError(error)
        }
        catch {
            /**
             * We only throw `MetalCameraSessionError` errors.
             */
        }
    }

#endif

}
