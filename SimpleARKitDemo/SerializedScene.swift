//
//  SerializedScene.swift
//  SimpleARKitDemo
//
//  Created by Justin Brady on 4/19/23.
//  Copyright © 2023 AppCoda. All rights reserved.
//

import Foundation
import ARKit

protocol SerializedSceneDelegate {
    func recordObj(_ node: SCNNode, _ serial: inout SerializeScene.SerializedScnNode)
    func instantiateObj(_ obj: SerializeScene.SerializedScnNode)
}

class SerializeScene {

    var delegate: SerializedSceneDelegate!
    
    struct SerializedScnNode {
        var m: SCNMatrix4
        var mat: SCNMaterial
        var scale: Float
        
        init() {
            self.m = SCNMatrix4()
            self.mat = SCNMaterial()
            self.scale = 1.0
        }
    }
    
    func save(_ scene: [SCNNode]) {
        var all: [SerializedScnNode] = []
        
        for obj in scene {
            var rec = SerializedScnNode()
            delegate.recordObj(obj, &rec)
            all += [rec]
        }
        // write to disk
        UserDefaults.standard.set(all, forKey: "sceneObjects")
    }
    
    func load() {
        if let prefs = UserDefaults.standard.value(forKey: "sceneObjects") as? [SerializedScnNode] {
            for rp in prefs {
                delegate?.instantiateObj(rp)
            }
        }
    }
}
