//
//  ViewControllerExtensions.swift
//  SimpleARKitDemo
//
//  Created by Justin Brady on 11/14/19.
//  Copyright © 2019 AppCoda. All rights reserved.
//

import UIKit
import ARKit

extension ViewController {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard let frame = sceneView.session.currentFrame else {
            return
        }
        
        // get camera orientation / position
        let tf = SCNMatrix4(frame.camera.transform)
        let v = SCNVector3(-1 * tf.m31, -1 * tf.m32, -1 * tf.m33)
        let pos = SCNVector3(tf.m41, tf.m42, tf.m43)
        let Mag: Float = 4.0
        
        // add an object with velocity along our camera z-vector
        let planeScene = SCNScene(named: "bullet.scn")
        
        if let bullet = planeScene?.rootNode.childNodes.first {
            bullet.removeFromParentNode()
            
            bullet.scale = SCNVector3(0.2, 0.2, 0.2)
            bullet.position = pos
            bullet.transform = tf
            
            sceneView.scene.rootNode.addChildNode(bullet)
            
            /*
            SCNTransaction.animationDuration = 30
            SCNTransaction.begin()
            plane.position = SCNVector3(pos.x + v.x * Mag, pos.y + v.y * Mag, pos.z + v.z * Mag)
            SCNTransaction.commit()
            */
            
            scnManager.addBullet(bullet, withVelocity: SCNVector3(v.x * Mag, v.y * Mag, v.z * Mag), lifetime: 10)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        guard let node = selectedNode,
            let touch = touches.first else {
            return
        }
        
        let S = (touch.location(in: view).x - touch.previousLocation(in: view).x) / abs(touch.location(in: view).x - touch.previousLocation(in: view).x)
        
        if S.isNaN {
            return
        }
        
        let qForAxes = [
            SCNQuaternion(S * 0.0249974, 0, 0, 0.9996875),
            SCNQuaternion(0, S * 0.0249974, 0, 0.9996875),
            SCNQuaternion(0, 0, S * 0.0249974, 0.9996875)
        ]
        
        let tForAxes = [
            SCNVector3(S * 0.005, 0, 0),
            SCNVector3(0, S * 0.005, 0),
            SCNVector3(0, 0, S * 0.005)
        ]
        
        switch axisSelector.selectedSegmentIndex {
            case 0:
            node.localRotate(by: qForAxes[axisSelector.selectedSegmentIndex])
            
            case 1:
            node.localRotate(by: qForAxes[axisSelector.selectedSegmentIndex])
            
            case 2:
            node.localRotate(by: qForAxes[axisSelector.selectedSegmentIndex])

            // case 3 ignored
            
            case 4:
            node.localTranslate(by: tForAxes[0])
            
            case 5:
            node.localTranslate(by: tForAxes[1])
            
            case 6:
            node.localTranslate(by: tForAxes[2])
            
            default:
            break
        }
    }
}
