//
//  MetalCameraSessionTestsDelegates.swift
//  MetalRenderCamera
//
//  Created by Alex Staravoitau on 27/07/2016.
//  Copyright © 2016 Old Yellow Bricks. All rights reserved.
//

import XCTest
import Metal

@testable import Metal_Camera

/// This class is acting as a `MetalCameraSessionDelegate` that tracks the first error received from the camera session and reports it with a `XCTestExpectation`.
internal final class ErrorTrackingDelegate: MetalCameraSessionDelegate {

    /// Stores the camera session error, so that it's available for a test
    var error: MetalCameraSessionError?

    /// Expectation that is waiting for the delegate
    var expectation: XCTestExpectation?

    internal func metalCameraSession(_ session: MetalCameraSession, didReceiveFrameAsTextures: [MTLTexture], withTimestamp: Double) { }

    internal func metalCameraSession(_ session: MetalCameraSession, didUpdateState: MetalCameraSessionState, error newError: MetalCameraSessionError?) {
        guard let expectation = expectation, (error == nil && newError != nil) else { return }

        error = newError
        expectation.fulfill()
    }
}

/// This class is acting as a `MetalCameraSessionDelegate` that tracks the first state received from the camera session and reports it with a `XCTestExpectation`.
internal final class StateTrackingDelegate: MetalCameraSessionDelegate {

    /// Stores the camera session state, so that it's available for a test
    var state: MetalCameraSessionState?

    /// Expectation that is waiting for the delegate
    var expectation: XCTestExpectation?

    internal func metalCameraSession(_ session: MetalCameraSession, didReceiveFrameAsTextures: [MTLTexture], withTimestamp: Double) { }

    internal func metalCameraSession(_ session: MetalCameraSession, didUpdateState newState: MetalCameraSessionState, error: MetalCameraSessionError?) {
        guard let expectation = expectation, state == nil else { return }

        state = newState
        expectation.fulfill()
    }
}
