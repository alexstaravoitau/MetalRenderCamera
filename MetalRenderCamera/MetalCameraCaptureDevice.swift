//
//  MetalCameraCaptureDevice.swift
//  MetalRenderCamera
//
//  Created by Alex Staravoitau on 25/07/2016.
//  Copyright © 2016 Old Yellow Bricks. All rights reserved.
//

import AVFoundation

/// A wrapper for the `AVFoundation`'s `AVCaptureDevice` that has instance methods instead of the class ones. This wrapper will make unit testing so much easier.
internal class MetalCameraCaptureDevice {
    /**
     Attempts to get a capture device with specified media type and position.

     - parameter for: Device media type
     - parameter with: Device position

     - returns: Capture device or `nil`.
     */
    internal func device(for mediaType: AVMediaType, with position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        return AVCaptureDevice.devices(for: mediaType).first { $0.position == position }
    }

    /**
     Requests access to capture device with specified media type.

     - parameter for: Device media type
     - parameter completionHandler: A block called with the result of requesting access
     */
    internal func requestAccess(for mediaType: AVMediaType, completionHandler handler: @escaping ((Bool) -> Void)) {
        AVCaptureDevice.requestAccess(for: mediaType, completionHandler: handler)
    }
}
