//
//  MetalCameraSessionDelegate.swift
//  MetalShaderCamera
//
//  Created by Alex Staravoitau on 25/04/2016.
//  Copyright © 2016 Old Yellow Bricks. All rights reserved.
//

import AVFoundation

/**
 States of capturing session
 
 - Ready:     Ready to start capturing
 - Streaming: Capture in progress
 - Stopped:   Capturing stopped
 - Waiting:   Waiting to get access to hardware
 - Error:     An error has occured
 */
public enum MetalCameraSessionState {
    case ready
    case streaming
    case stopped
    case waiting
    case error
}

public enum MetalCameraPixelFormat {
    case rgb
    case yCbCr
    
    var coreVideoType: OSType {
        switch self {
        case .rgb:
            return kCVPixelFormatType_32BGRA
        case .yCbCr:
            return kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        }
    }
}

/**
 Streaming error
 */
public enum MetalCameraSessionError: Error {
    /**
     * Streaming errors
     *///
    case noHardwareAccess
    case failedToAddCaptureInputDevice
    case failedToAddCaptureOutput
    case requestedHardwareNotFound
    case inputDeviceNotAvailable
    case captureSessionRuntimeError
    
    /**
     * Conversion errors
     *///
    case failedToCreateTextureCache
    case missingSampleBuffer
    case failedToGetImageBuffer
    case failedToCreateTextureFromImage
    case failedToRetrieveTimestamp
    
    /**
     Indicates if the error is related to streaming the media.
     
     - returns: True if the error is related to streaming, false otherwise
     */
    public func isStreamingError() -> Bool {
        switch self {
        case .noHardwareAccess, .failedToAddCaptureInputDevice, .failedToAddCaptureOutput, .requestedHardwareNotFound, .inputDeviceNotAvailable, .captureSessionRuntimeError:
            return true
        default:
            return false
        }
    }
    
    public var localizedDescription: String {
        switch self {
        case .noHardwareAccess:
            return "Failed to get access to the hardware for a given media type"
        case .failedToAddCaptureInputDevice:
            return "Failed to add a capture input device to the capture session"
        case .failedToAddCaptureOutput:
            return "Failed to add a capture output data channel to the capture session"
        case .requestedHardwareNotFound:
            return "Specified hardware is not available on this device"
        case .inputDeviceNotAvailable:
            return "Capture input device cannot be opened, probably because it is no longer available or because it is in use"
        case .captureSessionRuntimeError:
            return "AVCaptureSession runtime error"
        case .failedToCreateTextureCache:
            return "Failed to initialize texture cache"
        case .missingSampleBuffer:
            return "No sample buffer to convert the image from"
        case .failedToGetImageBuffer:
            return "Failed to retrieve an image buffer from camera's output sample buffer"
        case .failedToCreateTextureFromImage:
            return "Failed to convert the frame to a Metal texture"
        case .failedToRetrieveTimestamp:
            return "Failed to retrieve timestamp from the sample buffer"
        }
    }
}
