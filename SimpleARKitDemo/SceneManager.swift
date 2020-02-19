//
//  SceneManager.swift
//  SimpleARKitDemo
//
//  Created by Justin Brady on 11/29/19.
//  Copyright © 2019 AppCoda. All rights reserved.
//

import Foundation
import UIKit
import ARKit


class SceneManager: NSObject {
    
    //MARK: -- private types
    class SCNMovingNode: NSObject {
        
        init(_ node: SCNNode, withVelocity: SCNVector3, lifetime: Float = 999.0) {
            self.scnNode = node
            self.vel = withVelocity
            self.destroyAfterSeconds = lifetime
            
            super.init()
        }
        var scnNode: SCNNode
        var vel: SCNVector3
        var destroyAfterSeconds: Float
        
        func distance(fromNode: SCNNode) -> Float {
            let dX = scnNode.position.x - fromNode.position.x
            let dY = scnNode.position.y - fromNode.position.y
            let dZ = scnNode.position.z - fromNode.position.z
            
            return sqrt(dX*dX + dY*dY + dZ*dZ)
        }
    }

    class SCNMovingBullet: SCNMovingNode {
        override init(_ node: SCNNode, withVelocity: SCNVector3, lifetime: Float = 999.0) {
            super.init(node, withVelocity: withVelocity, lifetime: lifetime)
            
            node.scale = SCNVector3(0.2, 0.2, 0.2)
        }
    }
    
    // MARK: -- class vars
    var scene: ARSCNView!
    var nodesInMotion: [SCNMovingNode] = []
    var bulletsInMotion: [SCNMovingBullet] = []
    let fps: Float = 60.0
    var timer: Timer!
    var framesTillNextTarget = 120.0
    var spawnRange: Float = 2.0
    
    // MARK: -- implementation
    required init(scene: ARSCNView) {
        self.scene = scene

        super.init()
    }
    
    // MARK: -- private helpers
    private func updateMotion() {
        
        // check collisions
        for bullet in bulletsInMotion {
            
            for node in nodesInMotion {
                
                let b1 = bullet.scnNode.position
                let b2 = node.scnNode.boundingBox
                let b2o = node.scnNode.position
                
                if b2.max.x+b2o.x >= b1.x && b2.min.x+b2o.x <= b1.x {
                    if b2.max.y+b2o.y >= b1.y && b2.min.y+b2o.y <= b1.y {
                        if b2.max.z+b2o.z >= b1.z && b2.min.z+b2o.z <= b1.z {
                            // collision
                            node.destroyAfterSeconds = 0
                            bullet.destroyAfterSeconds = 0
                            
                            //print("collision @distance: \(node.distance(fromNode: bullet.scnNode))")
                        }
                    }
                }
            }
        }
        
        for node in nodesInMotion + bulletsInMotion {
            node.scnNode.position.x += node.vel.x / fps
            node.scnNode.position.y += node.vel.y / fps
            node.scnNode.position.z += node.vel.z / fps
            
            node.destroyAfterSeconds -= 1.0 / fps
        }
        
        for node in nodesInMotion + bulletsInMotion {
            if node.destroyAfterSeconds <= 0 {
                node.scnNode.removeFromParentNode()
                nodesInMotion.removeAll(where: { $0.scnNode == node.scnNode })
                bulletsInMotion.removeAll(where: { $0.scnNode == node.scnNode })
            }
        }
    }
    
    private func updateTargets() {
        
        if framesTillNextTarget <= 0 {
        
            let planeScene = SCNScene(named: "newship.scn")
            
            if let plane = planeScene?.rootNode.childNodes.first {
                let camTranslation = scene.session.currentFrame!.camera.transform.translation
                
                plane.removeFromParentNode()
                
                // scale model to approximate size user expects
                plane.scale = SCNVector3(0.2, 0.2, 0.2)

                plane.position = SCNVector3(camTranslation.x + Float.random(in: -spawnRange..<spawnRange),
                                            camTranslation.y /* + Float.random(in: -spawnRange..<spawnRange)*/,
                                            camTranslation.z + Float.random(in: -spawnRange..<spawnRange))
                
                let dist = sqrt(
                    (plane.position.x - camTranslation.x) * (plane.position.x - camTranslation.x) +
                    (plane.position.y - camTranslation.y) * (plane.position.y - camTranslation.y) +
                    (plane.position.z - camTranslation.z) * (plane.position.z - camTranslation.z)
                )
                let V = SCNVector3((plane.position.x - camTranslation.x) / dist,
                                   (plane.position.y - camTranslation.y) / dist,
                                   (plane.position.z - camTranslation.z) / dist
                )
                
                plane.orientation = SCNQuaternion(V.x, V.y, V.z, 1.0)
                
//                plane.eulerAngles = SCNVector3(Float.random(in: -3.14159..<3.14159),
//                                               Float.random(in: -3.14159..<3.14159),
//                                               Float.random(in: -3.14159..<3.14159))
                
                // camera position, then invert orientation along local Z and translate
                //let camTransformInvert = scene.session.currentFrame!.camera.eulerAngles.addingProduct(0, simd_float3(x: 0, y: 1, z: 0))
                
                //plane.eulerAngles = SCNVector3(camTransformInvert)
                //plane.localTranslate(by: SCNVector3(0, 0, -5.0))
                
                scene.scene.rootNode.addChildNode(plane)
                
                addTarget(plane, withVelocity: plane.convertVector(SCNVector3(0, 0, -0.2), to: nil), lifetime: 9999.0)
            }
            
            framesTillNextTarget = 120 * 4.0
        }
        
        framesTillNextTarget -= 1
    }
    
    // MARK: -- public methods
    
    func start() {
        timer = Timer(timeInterval: TimeInterval(1.0/fps), repeats: true) {
            [weak self] timer in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.updateMotion()
            strongSelf.updateTargets()
        }
        
        RunLoop.main.add(timer, forMode: .default)
    }
    
    func stop() {
        timer.invalidate()
        timer = nil
    }
    
    func addTarget(_ node: SCNNode, withVelocity: SCNVector3, lifetime: Float) {
        let newNode = SCNMovingNode(node, withVelocity: withVelocity, lifetime: lifetime)
        nodesInMotion.append(newNode)
    }
    
    func addBullet(_ node: SCNNode, withVelocity: SCNVector3, lifetime: Float) {
        let newNode = SCNMovingBullet(node, withVelocity: withVelocity, lifetime: lifetime)
        bulletsInMotion.append(newNode)
    }
}
