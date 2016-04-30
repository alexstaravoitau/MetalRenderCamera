//
//  AVCaptureDevice+QueryDevice.swift
//  MetalShaderCamera
//
//  Created by Alex Staravoitau on 24/04/2016.
//  Copyright © 2016 Old Yellow Bricks. All rights reserved.
//

import AVFoundation

extension AVCaptureDevice {
    
    class func deviceWithMediaType(mediaType: String, position: AVCaptureDevicePosition) -> AVCaptureDevice? {
        guard let devices = AVCaptureDevice.devicesWithMediaType(mediaType) as? [AVCaptureDevice] else { return nil }
        
        if let index = devices.indexOf({ $0.position == position }) {
            return devices[index]
        }
        
        return nil
    }
    
}