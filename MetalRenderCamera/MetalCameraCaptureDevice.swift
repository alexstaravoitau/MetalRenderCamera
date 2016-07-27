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

    internal func deviceWithMediaType(mediaType: String, position: AVCaptureDevicePosition) -> AVCaptureDevice? {
        guard let devices = AVCaptureDevice.devicesWithMediaType(mediaType) as? [AVCaptureDevice] else { return nil }

        if let index = devices.indexOf({ $0.position == position }) {
            return devices[index]
        }

        return nil
    }

    internal func requestAccessForMediaType(mediaType: String!, completionHandler handler: ((Bool) -> Void)!) {
        AVCaptureDevice.requestAccessForMediaType(mediaType, completionHandler: handler)
    }
}
