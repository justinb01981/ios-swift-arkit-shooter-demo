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
    
    static var selfStatic = SceneManager(scene: SceneManager.staticMgr.scene)
    
    func testTransMatrix(with sceneView: ARSCNView) {
        guard let sessionF = sceneView.session.currentFrame
        else {
            fatalError()
        }
        
        let cam = sessionF.camera
        let mgr = SceneManager.staticMgr!
        let movStep = Float(5.0)
        
        var M1 = SIMP_identMatrix
        M1.m43 -= 0.5
        
        let movCube1 = mgr.addCube(withTransform: M1)
        
        var M2 = M1
        M2.m42 += 0.02
        M2.m43 -= 0.05
        
        let movCube2 = mgr.addCube(withTransform: M2, with:
                                    SCNVector3(x: (M1.m41-M2.m41)/movStep, y: (M1.m42-M2.m42)/movStep, z: (M1.m43-M2.m43)/movStep))
        
        mgr.start()
        
        print("\(DEBUG_PFX) if you see 2 diff sided cubes without lifting the phone, test passed")
    }
}
