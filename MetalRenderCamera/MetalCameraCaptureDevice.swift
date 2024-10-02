//
//  MetalCameraCaptureDevice.swift
//  MetalRenderCamera
//
//  Created by Alex Staravoitau on 25/07/2016.
//  Copyright © 2016 Old Yellow Bricks. All rights reserved.
//

import AVFoundation

/// A wrapper for AVFoundation's `AVCaptureDevice`, providing instance methods instead of class methods. This wrapper simplifies unit testing.
internal class MetalCameraCaptureDevice {

    /**
     Attempts to retrieve a capture device for the specified media type and position.

     - parameter mediaType: The media type of the device (e.g., video, audio).
     - parameter deviceType: The type of the capture device (e.g., built-in microphone, wide-angle camera).
     - parameter position: The position of the device (e.g., front, back).

     - returns: The capture device if available, otherwise `nil`.
     */
    internal func device(for mediaType: AVMediaType, type deviceType: AVCaptureDevice.DeviceType, position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        return AVCaptureDevice.DiscoverySession(deviceTypes: [deviceType], mediaType: mediaType, position: position).devices.first
    }

    /**
     Requests access to the capture device for the specified media type.

     - parameter mediaType: The media type for which access is requested (e.g., video, audio).
     - parameter handler: The completion handler to be called with the result of the access request, returning a `Bool` indicating success or failure.
     */
    internal func requestAccess(for mediaType: AVMediaType, completionHandler handler: @escaping ((Bool) -> Void)) {
        AVCaptureDevice.requestAccess(for: mediaType, completionHandler: handler)
    }
}
