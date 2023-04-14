//
//  ARSceneTest.swift
//  SimpleARKitDemo
//
//  Created by Justin Brady on 4/12/23.
//  Copyright © 2023 AppCoda. All rights reserved.
//

import Foundation
import ARKit
class ARTest {
    
    var scn: ARSCNView!
    
    func testTransMatrix(with sceneView: ARSCNView) {
        guard let sessionF = sceneView.session.currentFrame
        else {
            fatalError()
        }
        
        let cam = sessionF.camera
        let mgr = SceneManager.staticMgr!
        
        mgr.start()
        
        let cube = mgr.addCube(SCNMatrix4(cam.transform))
        
        cube.localTranslate(by: SCNVector3(x: 0, y: 0, z: 0.4))
        
        print("if you see a cube without lifting the phone, test passed")
        
        mgr.stop()
    }
}
