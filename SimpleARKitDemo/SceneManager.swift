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

class SceneManager: NSObject, ObservableObject, SerializedSceneDelegate {
    
    static var staticMgr: SceneManager!
    
    //MARK: -- private types
    class SCNMovingNode: NSObject {
        
        init(_ node: SCNNode, withVelocity: SCNVector3, lifetime: Float = 999.0) {
            self.scnNode = node
            self.vel = withVelocity
            self.destroyAfterSeconds = lifetime
            
            super.init()
        }
        
        let VEL_ZERO = SCNVector3(x: 0.0, y: Float.infinity, z: 0.0)
        
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
    let fps: Float = 60.0
    
    var scene: ARSCNView!
    var nodesInMotion: [SCNMovingNode] = []
    var bulletsInMotion: [SCNMovingBullet] = []
    var serializer = SerializeScene()
    var timer: Timer!
    var framesTillNextTarget = 120.0
    var spawnRange: Float = 2.0
    var cam: ARCamera {
        get {
            return self.scene.session.currentFrame!.camera
        }
    }
    
    @Published var selectedNode: SCNMovingNode? {
        didSet {
            // if no texture picked?
            oldValue?.scnNode.geometry?.firstMaterial?.emission.contents = nil
        }
    }
    
    @Published var sceneDescription: String?
    
    // TODO: -- find out a way to stream video to the texture material
    var textureImage: UIImage!
    
    private var adjustSign = 1.0
    
    // MARK: -- implementation
    required init(scene: ARSCNView) {
        super.init()
        
        self.scene = scene
        
        if let single = SceneManager.staticMgr {
            if single.scene != scene {
                fatalError() // cant do that yet
            }
            return
        }

        self.textureImage = UIImage(named: "bullettex.png")

        SceneManager.staticMgr = self
        
        serializer.delegate = self
    }
    
    func disappear() {
        serializer.save(nodesInMotion.map({ $0.scnNode }))
    }
    
    func appear() {
        serializer.load()
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
        
        let S = adjustSign
        
        let R = S * 0.0249974
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
        
        var node: SCNNode! = nil
        
        if action != .ADDOBJECT {
            guard let mov = selectedNode
            else {
                print("\(DEBUG_PFX) no node - bail")
                return
            }
            node = mov.scnNode
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
            
        case .SCALE:
            let sc: Float = S > 0.0 ? 1.1 : 0.9
            node.scale = SCNVector3(node.scale.x * sc, node.scale.y * sc, node.scale.z * sc)
            
        case .ADDOBJECT:
            do {
                
                var tfnew = cam.transform
                
                // place object in front of the camera
                tfnew.columns.3.x += tfnew.columns.2.x*Float(SIMP_carryDist)
                tfnew.columns.3.y += tfnew.columns.2.y*Float(SIMP_carryDist)
                tfnew.columns.3.z += tfnew.columns.2.z*Float(SIMP_carryDist)
                
                // add to scene
                let createdNode = addCube(withTransform: SCNMatrix4(tfnew))
                
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
            
            if sqrt(pow(node.vel.x+node.vel.y+node.vel.z, 2)) > 0.00001 {
                node.scnNode.position.x += node.vel.x / fps
                node.scnNode.position.y += node.vel.y / fps
                node.scnNode.position.z += node.vel.z / fps

                node.vel.x /= SIMP_decelC
                node.vel.y /= SIMP_decelC
                node.vel.z /= SIMP_decelC
            }
//            node.destroyAfterSeconds -= 1.0 / fps
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

        guard let cam = scene.session.currentFrame?.camera else {
            return
        }
        
        var desctmp = ""
        
        if let selectedNodeVel = selectedNode,
           let node = selectedNodeVel.scnNode as SCNNode?,
           var rec = nodesInMotion.first(where: { $0.scnNode == node }) {
            
            let tform = SCNMatrix4(cam.transform)
                        
            // carry in front of camera
            let dstX = cam.transform.translation.x + Float(SIMP_carryDist)*tform.m31
            let dstY = cam.transform.translation.y +  Float(SIMP_carryDist)*tform.m32
            let dstZ = cam.transform.translation.z + Float(SIMP_carryDist)*tform.m33
            let intr = Float(4.0)
            
            // duplicate orientation
            node.eulerAngles = SCNVector3(cam.eulerAngles)
            
            rec.vel.x += (dstX-node.position.x) / intr // 4 seconds to arrive at dst
            rec.vel.y += (dstY-node.position.y) / intr // 4 seconds to arrive at dst
            rec.vel.z += (dstZ-node.position.z) / intr // 4 seconds to arrive at dst
            
            desctmp += "node: \(node.transform.m41) \(node.transform.m42) \(node.transform.m43)"
        }
        else {
            desctmp += "cam: \(cam.transform.translation)"
        }
        
        sceneDescription = desctmp
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
        
        timer = Timer(timeInterval: TimeInterval(1.0/SIMP_MOTION_TIMER_FPS), repeats: true) {
            [weak self] timer in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.updateMotion()
            strongSelf.updateTargets()
            
            if !strongSelf.testFinished, strongSelf.scene.session.currentFrame != nil {
                strongSelf.test()
                strongSelf.testFinished = true
                // exit
                timer.invalidate()
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
    
    private func addVelocity(_ node: SCNNode, _ v: SCNVector3) -> SCNMovingNode {
        
        // TODO: get rid of nodesInMotion and use single list with optimized searching for nodes with V
        
        var movr: SCNMovingNode
        
        if let mov = nodesInMotion.first(where: { $0 == node }) {
            mov.vel.x += v.x
            mov.vel.y += v.y
            mov.vel.z += v.z
            
            movr = mov
        }
        else {
            movr = SCNMovingNode(node, withVelocity: v)
            nodesInMotion.append(movr)
        }
        
        return movr
    }
    
    func addCube(withTransform tf: SCNMatrix4, with vel: SCNVector3 = SCNVector3()) -> SCNMovingNode {
        let box = SCNBox(width: 1.0, height: 1.0, length: 1.0, chamferRadius: 0)
        let img = textureImage
        let mat = SCNMaterial()
        
        mat.diffuse.contents = img
        box.materials = [mat]
        
        let node = SCNNode(geometry: box)
        
        scene.scene.rootNode.addChildNode(node)
        
        // column-major order for the SCNMatrix4
        node.transform = tf
        
        node.scale = SCNVector3(SIMP_CUBE_SIZE, SIMP_CUBE_SIZE, SIMP_CUBE_SIZE)
        
        return addVelocity(node, vel)
    }
    
    func deleteSelected() {
        self.selectedNode?.scnNode.removeFromParentNode()
        print("\(DEBUG_PFX)deleted node")
    }
}

extension SceneManager: ARSCNViewDelegate {
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // TODO: plane detection
    }
}

// serializedScene delegate
extension SceneManager {
    func recordObj(_ node: SCNNode, _ serial: inout SerializeScene.SerializedScnNode) {
        serial.scale = (node.scale.x + node.scale.y + node.scale.z)/3.0 // all 3 axes congruent
        serial.m = node.transform
        
        let firstMat = node.geometry?.materials.first
        serial.mat = firstMat ?? SCNMaterial()
    }
    
    func instantiateObj(_ obj: SerializeScene.SerializedScnNode) {
        let aobj = addCube(withTransform: obj.m)
        aobj.scnNode.geometry?.materials += [obj.mat]
    }
}
