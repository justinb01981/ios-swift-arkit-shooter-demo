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
        
        init(_ node: SCNNode, withVelocity: SCNVector3, lifetime: Float = 9999.0) {
            self.scnNode = node
            self.vel = withVelocity
            self.destroyAfterSeconds = lifetime
            
            super.init()
        }
        var scnNode: SCNNode
        var vel: SCNVector3
        var destroyAfterSeconds: Float
    }
    
    // MARK: -- class vars
    private var scene: SCNScene
    private var nodesInMotion: [SCNMovingNode] = []
    private let fps: Float = 60.0
    private var timer: Timer!
    
    // MARK: -- implementation
    required init(scene: SCNScene) {
        self.scene = scene
        
        super.init()
    }
    
    // MARK: -- private helpers
    private func updateMotion() {
        
        for node in nodesInMotion {
            node.scnNode.position.x += node.vel.x / fps
            node.scnNode.position.y += node.vel.y / fps
            node.scnNode.position.z += node.vel.z / fps
            
            node.destroyAfterSeconds -= 1.0 / fps
        }
        
        for node in nodesInMotion {
            if node.destroyAfterSeconds <= 0 {
                node.scnNode.removeFromParentNode()
                nodesInMotion.removeAll(where: { $0.scnNode == node.scnNode })
            }
        }
    }
    
    // MARK: -- public methods
    
    func start() {
        timer = Timer(timeInterval: TimeInterval(1.0/fps), repeats: true) { [weak self] (_) in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.updateMotion()
        }
        
        RunLoop.main.add(timer, forMode: .defaultRunLoopMode)
    }
    
    func stop() {
        timer.invalidate()
        timer = nil
    }
    
    func addNode(_ node: SCNNode, withVelocity: SCNVector3, lifetime: Float = 9999.0) {
        let newNode = SCNMovingNode(node, withVelocity: withVelocity, lifetime: lifetime)
        nodesInMotion.append(newNode)
    }
}
