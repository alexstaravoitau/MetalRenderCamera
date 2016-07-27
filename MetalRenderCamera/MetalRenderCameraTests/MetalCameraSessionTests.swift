//
//  MetalCameraSessionTests.swift
//  MetalRenderCamera
//
//  Created by Alex Staravoitau on 25/07/2016.
//  Copyright © 2016 Old Yellow Bricks. All rights reserved.
//

import XCTest
import AVFoundation

@testable import Metal_Camera

class MetalCameraSessionTests: XCTestCase {

    /**
     Test that camera session reports a corresponding error to its delegate if there is no access to hardware.
     */
    func testErrorWithoutDeviceAccess() {
        /// A class faking `MetalCameraCaptureDevice` that would mock access requests and devices availability
        class StubCaptureDevice: MetalCameraCaptureDevice {
            override func requestAccessForMediaType(mediaType: String!, completionHandler handler: ((Bool) -> Void)!) { handler(false) }
        }

        let delegate = ErrorTrackingDelegate()
        let session = MetalCameraSession(delegate: delegate)
        let expectation = expectationWithDescription("MetalCameraSession calls delegate with an updated state and error.")
        delegate.expectation = expectation
        session.captureDevice = StubCaptureDevice()
        session.start()

        waitForExpectationsWithTimeout(1) { error in
            if let error = error {
                /**
                 Apparently the error was never reported and the expectation timed out.
                 */
                XCTFail(error.description)
            }

            XCTAssert(delegate.error == .NoHardwareAccess, "Camera session reported a inconsistent error.")
        }
    }

    /**
     Test that camera session reports a corresponding state to its delegate if access to hardware was successfully granted.
     */
    func testStateWithDeviceAccess() {
        /// A class faking `MetalCameraCaptureDevice` that would mock access requests and devices availability
        class StubCaptureDevice: MetalCameraCaptureDevice {
            override func requestAccessForMediaType(mediaType: String!, completionHandler handler: ((Bool) -> Void)!) { handler(true) }
        }

        let delegate = StateTrackingDelegate()
        let session = MetalCameraSession(delegate: delegate)
        let expectation = expectationWithDescription("MetalCameraSession calls delegate with an updated state and error.")
        delegate.expectation = expectation
        session.captureDevice = StubCaptureDevice()
        session.start()

        waitForExpectationsWithTimeout(1) { error in
            if let error = error {
                /**
                 Apparently the status was never reported and the expectation timed out.
                 */
                XCTFail(error.description)
            }

            XCTAssert(delegate.state == .Ready)
        }
    }

    /**
     Test that camera session reports a corresponding error to its delegate if there is no required hardware available.
     */
    func testErrorWithNoHardwareAvailable() {
        /// A class faking `MetalCameraCaptureDevice` that would mock access requests and devices availability
        class StubCaptureDevice: MetalCameraCaptureDevice {
            override func requestAccessForMediaType(mediaType: String!, completionHandler handler: ((Bool) -> Void)!) { handler(true) }
            override func deviceWithMediaType(mediaType: String, position: AVCaptureDevicePosition) -> AVCaptureDevice? { return nil }
        }

        let delegate = ErrorTrackingDelegate()
        let session = MetalCameraSession(delegate: delegate)
        let expectation = expectationWithDescription("MetalCameraSession calls delegate with an updated state and error.")
        delegate.expectation = expectation
        session.captureDevice = StubCaptureDevice()
        session.start()

        waitForExpectationsWithTimeout(1) { error in
            if let error = error {
                /**
                 Apparently the error was never reported and the expectation timed out.
                 */
                XCTFail(error.description)
            }

            XCTAssert(delegate.error == .RequestedHardwareNotFound, "Camera session reported a inconsistent error.")
        }
    }
}
