//
//  ViewController.swift
//  MetalShaderCamera
//
//  Created by Alex Staravoitau on 24/04/2016.
//  Copyright © 2016 Old Yellow Bricks. All rights reserved.
//

import UIKit
import Metal

internal final class CameraViewController: MTKViewController {

    var session: MetalCameraSession?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        session = MetalCameraSession(delegate: self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        session?.start()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        session?.stop()
    }

}

// MARK: - MetalCameraSessionDelegate
extension CameraViewController: MetalCameraSessionDelegate {
    
    func metalCameraSession(_ session: MetalCameraSession, didReceiveFrameAsTextures textures: [MTLTexture], withTimestamp timestamp: Double) {
        self.texture = textures[0]
    }
    
    func metalCameraSession(_ cameraSession: MetalCameraSession, didUpdateState state: MetalCameraSessionState, error: MetalCameraSessionError?) {
        
        if error == .captureSessionRuntimeError {
            /**
             *  In this app we are going to ignore capture session runtime errors
             */
            cameraSession.start()
        }
        
        DispatchQueue.main.async { 
            self.title = "Metal camera: \(state)"
        }
        
        NSLog("Session changed state to \(state) with error: \(error?.localizedDescription ?? "None").")
    }

}
