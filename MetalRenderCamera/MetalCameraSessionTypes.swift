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
    
    case Ready
    case Streaming
    case Stopped
    case Waiting
    case Error
}

public enum MetalCameraPixelFormat {
    
    case RGB
    case YCbCr
    
    var coreVideoType: OSType {
        switch self {
        case RGB:
            return kCVPixelFormatType_32BGRA
        case YCbCr:
            return kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        }
    }
}

/**
 Streaming error
 */
public enum MetalCameraSessionError: ErrorType {

    /**
     * Streaming errors
     *///
    case NoHardwareAccess
    case FailedToAddCaptureInputDevice
    case FailedToAddCaptureOutput
    case RequestedHardwareNotFound
    case InputDeviceNotAvailable
    case CaptureSessionRuntimeError
    
    /**
     * Conversion errors
     *///
    case FailedToCreateTextureCache
    case MissingSampleBuffer
    case FailedToGetImageBuffer
    case FailedToCreateTextureFromImage
    case FailedToRetrieveTimestamp
    
    /**
     Indicates if the error is related to streaming the media.
     
     - returns: True if the error is related to streaming, false otherwise
     */
    public func isStreamingError() -> Bool {
        switch self {
        case NoHardwareAccess, FailedToAddCaptureInputDevice, FailedToAddCaptureOutput, RequestedHardwareNotFound, InputDeviceNotAvailable, CaptureSessionRuntimeError:
            return true
        default:
            return false
        }
    }
    
    public var description: String {
        switch self {
        case NoHardwareAccess:
            return "Failed to get access to the hardware for a given media type."
        case FailedToAddCaptureInputDevice:
            return "Failed to add a capture input device to the capture session."
        case FailedToAddCaptureOutput:
            return "Failed to add a capture output data channel to the capture session."
        case RequestedHardwareNotFound:
            return "Specified hardware is not available on this device."
        case InputDeviceNotAvailable:
            return "Capture input device cannot be opened, probably because it is no longer available or because it is in use."
        case CaptureSessionRuntimeError:
            return "AVCaptureSession runtime error."
        case FailedToCreateTextureCache:
            return "Failed to initialize texture cache."
        case MissingSampleBuffer:
            return "No sample buffer to convert the image from."
        case FailedToGetImageBuffer:
            return "Failed to retrieve an image buffer from camera's output sample buffer."
        case FailedToCreateTextureFromImage:
            return "Failed to convert the frame to a Metal texture."
        case FailedToRetrieveTimestamp:
            return "Failed to retrieve timestamp from the sample buffer."

        }
    }
}
