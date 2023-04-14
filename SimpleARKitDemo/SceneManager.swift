//
//  SceneManager.swift
//  SimpleARKitDemo
//
// author: justin@domain17.net
//

import Foundation
import UIKit
import ARKit
import Combine

class SceneManager: NSObject, ObservableObject {
    
    static var staticMgr: SceneManager!
    
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
            
            node.scale = SCNVector3(SIMP_CUBE_SIZE, SIMP_CUBE_SIZE, SIMP_CUBE_SIZE)
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
    
    @Published var selectedNode: SCNNode? {
        didSet {
            // if no texture picked?
            oldValue?.geometry?.firstMaterial?.emission.contents = nil
        }
    }
    
    @Published var sceneDescription: String?
    
    // TODO: -- find out a way to stream video to the texture material
    var textureImage: UIImage!
    
    private var adjustSign = 1.0
    
    // MARK: -- implementation
    required init(scene: ARSCNView) {
        super.init()
        
        if let single = SceneManager.staticMgr {
            if single.scene != scene {
                fatalError() // cant do that yet
            }
            return
        }
        
        self.scene = scene
        self.textureImage = UIImage(named: "bullettex.png")

        SceneManager.staticMgr = self
    }
    
    func adjustScenePos(_ action: SceneAction) {
        adjustSign = 1
        adjustScene(action)
    }
    
    func adjustSceneNeg(_ action: SceneAction) {
        adjustSign = -1
        adjustScene(action)
    }
    
    func adjustScene(_ action: SceneAction) {
        
        guard let cam = scene.session.currentFrame?.camera else {
            return
        }
        
        // get camera orientation / position
        let tf = SCNMatrix4(cam.transform)

        let node: SCNNode! = selectedNode
        
        let S = adjustSign
        
        let R = S * ((.pi * 2.0) / SIMP_Q_ROTATE_STEPS)
        
        let Rqc = 0.9996875
        let qForAxes = [
            SCNQuaternion(R, 0, 0, Rqc),
            SCNQuaternion(0, R, 0, Rqc),
            SCNQuaternion(0, 0, R, Rqc)
        ]
        let tForAxes = [
            SCNVector3(SIMP_carryDist*S, 0, 0),
            SCNVector3(0, SIMP_carryDist*S, 0),
            SCNVector3(0, 0, SIMP_carryDist*S)
        ]
        
        guard node != nil || action == .ADDOBJECT
        else {
            print("\(DEBUG_PFX) no node - bail")
            return
        }
        
        switch action {
            
        case .ROTATE_X:
            node.localRotate(by: qForAxes[0])
            
        case .ROTATE_Y:
            node.localRotate(by: qForAxes[1])
            
        case .ROTATE_Z:
            node.localRotate(by: qForAxes[2])
            
            // case 3 ignored
            
        case .TRANSLATE_X:
            node.localTranslate(by: tForAxes[0])
            
        case .TRANSLATE_Y:
            node.localTranslate(by: tForAxes[1])
            
        case .TRANSLATE_Z:
            node.localTranslate(by: tForAxes[2])
            
        case .ADDOBJECT:
            do {
                // components inputs
                let carryDist = Float(SIMP_carryDist)
                let vvel = SCNVector3(0.000001, 0.000001, 0.000001)
                
                // (see AR anchors) and place object in front of the camera
                var tfnew = cam.transform
//                tfnew.columns.3 *= carryDist
                
                // add to scene
                selectedNode = addCube(SCNMatrix4(tfnew))
                
                if let node = selectedNode {
                    // set in motion
                    nodesInMotion.append(SCNMovingNode(node, withVelocity: vvel))
                }
                
                print("set weapons for stun in your unit test")
            }
            
        case .DELOBJECT:
            deleteSelected()
        
        default:
            fatalError()
            break
        }
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
        
        dragSelectedNode()
    }
    
    private func dragSelectedNode() {
        if let node = selectedNode,
           let cam = scene.session.currentFrame?.camera {
            var tform = SCNMatrix4(cam.transform)
    
            node.transform = SCNMatrix4(cam.transform)
            
            let cdistC = Float(SIMP_carryDist)
            // translate position along Z
            node.transform.m41 += cdistC * tform.m31
            node.transform.m42 += cdistC * tform.m32
            node.transform.m43 += cdistC * tform.m33
            
            /*
            node.position.x += V.x
            node.position.y += V.y
            node.position.z += V.z
            
            print("\(DEBUG_PFX) dragging node \(node.debugDescription) to cam-relative position \(V)")
             */
        }
    }
    
    private func updateTargets() {
        
        if framesTillNextTarget <= 0 {
        
            let jetScene = SCNScene(named: "newship.scn")
            
            if let jet = jetScene?.rootNode.childNodes.first {
                let camTranslation = scene.session.currentFrame!.camera.transform.translation
                
                jet.removeFromParentNode()
                
                // scale model to approximate size user expects
                jet.scale = SCNVector3(SIMP_JET_SCALE, SIMP_JET_SCALE, SIMP_JET_SCALE)

                jet.position = SCNVector3(camTranslation.x + Float.random(in: -spawnRange..<spawnRange),
                                            camTranslation.y /* + Float.random(in: -spawnRange..<spawnRange)*/,
                                            camTranslation.z + Float.random(in: -spawnRange..<spawnRange))
                
                let dist = sqrt(
                    (jet.position.x - camTranslation.x) * (jet.position.x - camTranslation.x) +
                    (jet.position.y - camTranslation.y) * (jet.position.y - camTranslation.y) +
                    (jet.position.z - camTranslation.z) * (jet.position.z - camTranslation.z)
                )
                let V = SCNVector3((jet.position.x - camTranslation.x) / dist,
                                   (jet.position.y - camTranslation.y) / dist,
                                   (jet.position.z - camTranslation.z) / dist
                )
                
                jet.orientation = SCNQuaternion(V.x, V.y, V.z, 1.0)
                
//                jet.eulerAngles = SCNVector3(Float.random(in: -3.14159..<3.14159),
//                                               Float.random(in: -3.14159..<3.14159),
//                                               Float.random(in: -3.14159..<3.14159))
                
                // camera position, then invert orientation along local Z and translate
                //let camTransformInvert = scene.session.currentFrame!.camera.eulerAngles.addingProduct(0, simd_float3(x: 0, y: 1, z: 0))
                
                //jet.eulerAngles = SCNVector3(camTransformInvert)
                //jet.localTranslate(by: SCNVector3(0, 0, -5.0))
                
                scene.scene.rootNode.addChildNode(jet)
                
                addTarget(jet, withVelocity: jet.convertVector(SCNVector3(0, 0, -0.2), to: nil), lifetime: 9999.0)
            }
            
            framesTillNextTarget = SIMP_SPAWN_INTERVAL_MS / 1000.0 * 120
        }
        
        framesTillNextTarget -= 1
    }
    
    // MARK: -- public methods
    
    var testFinished  = false
    
    func start() {
        
        scene.delegate = self
        
        timer = Timer(timeInterval: TimeInterval(1.0/fps), repeats: true) {
            [weak self] timer in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.updateMotion()
            strongSelf.updateTargets()
            
            strongSelf.dragSelectedNode()
            
            if !strongSelf.testFinished, strongSelf.scene.session.currentFrame != nil {
                strongSelf.test()
                strongSelf.testFinished = true
            }
        }
        
        RunLoop.main.add(timer, forMode: .default)
    }
    
    func stop() {
        timer.invalidate()
        timer = nil
    }
    
    func test() {
        ARTest().testTransMatrix(with: scene)
        print("sceneManager: test done")
    }
    
    func addTarget(_ node: SCNNode, withVelocity: SCNVector3, lifetime: Float) {
        let newNode = SCNMovingNode(node, withVelocity: withVelocity, lifetime: lifetime)
        nodesInMotion.append(newNode)
    }
    
    func addBullet(_ node: SCNNode, withVelocity: SCNVector3, lifetime: Float) {
        let newNode = SCNMovingBullet(node, withVelocity: withVelocity, lifetime: lifetime)
        bulletsInMotion.append(newNode)
    }
    
    func addCube(_ tf: SCNMatrix4) -> SCNNode {
        let box = SCNBox(width: 1.0, height: 1.0, length: 1.0, chamferRadius: 0)
        let img = textureImage
        let mat = SCNMaterial()
        
        mat.diffuse.contents = img
        box.materials = [mat]
        
        let node = SCNNode(geometry: box)
        let atDist = Float(SIMP_carryDist)
        
        scene.scene.rootNode.addChildNode(node)
        
        // column-major order for the SCNMatrix4
        node.transform = tf
        
        // TODO: remove this step
        node.scale = SCNVector3(SIMP_CUBE_SIZE, SIMP_CUBE_SIZE, SIMP_CUBE_SIZE)
        
        return node
    }
    
    func deleteSelected() {
        self.selectedNode?.removeFromParentNode()
        print("deleted node")
    }
}

extension SceneManager: ARSCNViewDelegate {
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // TODO: plane detection
    }
}
