//
//  ViewController.swift
//  SimpleARKitDemo
//
//  Created by Jayven N on 29/9/2017.
//  Copyright © 2017 AppCoda. All rights reserved.
//

import UIKit
import ARKit

class ViewController: UIViewController {

    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var axisSelector: UISegmentedControl!
    @IBOutlet var scnManager: SceneManager!
    
    private var imagePicker: ImagePicker!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        scnManager = SceneManager(scene: sceneView)
        
        addTapGestureToSceneView()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration)
        
        scnManager.start()
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    func addTapGestureToSceneView() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(ViewController.didTap(withGestureRecognizer:)))
        sceneView.addGestureRecognizer(tapGestureRecognizer)
    }
    
    @objc func didTap(withGestureRecognizer recognizer: UIGestureRecognizer) {

    }
    
    @IBAction func onChangeTexture(_ sender: Any) {
        
        imagePicker = ImagePicker(presentationController: self, delegate: self)
        
        imagePicker.present(from: sender as! UIView)
    }
    
    @IBAction func onDeleteSelected(_ sender: Any) {
        scnManager.deleteSelected()
    }
    
}

extension float4x4 {
    var translation: float3 {
        let translation = self.columns.3
        return float3(translation.x, translation.y, translation.z)
    }
}

extension ViewController {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard let frame = sceneView.session.currentFrame else {
            return
        }
        
        let tapLocation = touches.first!.location(in: sceneView)
        let hitTestResults = sceneView.hitTest(tapLocation)
        
        guard hitTestResults.count == 0
            else {
                scnManager.selectedNode = hitTestResults.first!.node
                print("selected node")
                return
        }
        
        // get camera orientation / position
        let tf = SCNMatrix4(frame.camera.transform)
        let v = SCNVector3(-1 * tf.m31, -1 * tf.m32, -1 * tf.m33)
        let pos = SCNVector3(tf.m41, tf.m42, tf.m43)
        let Mag: Float = 4.0
        
        // add an object with velocity along our camera z-vector
        /*
        let planeScene = SCNScene(named: "bullet.scn")
        
        if let bullet = planeScene?.rootNode.childNodes.first {
            bullet.removeFromParentNode()
            
            bullet.scale = SCNVector3(0.2, 0.2, 0.2)
            bullet.position = pos
            bullet.transform = tf
            
            sceneView.scene.rootNode.addChildNode(bullet)
        }
        */
        
        let newNode = scnManager.addCube(pos, withTransform: tf)
        
        scnManager.selectedNode = newNode
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        guard let node = scnManager.selectedNode,
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
        
        let nodeTranformMatrix = [
            [node.transform.m11, node.transform.m21, node.transform.m31, node.transform.m41],
            [node.transform.m12, node.transform.m22, node.transform.m32, node.transform.m42],
            [node.transform.m13, node.transform.m23, node.transform.m33, node.transform.m43],
            [node.transform.m14, node.transform.m24, node.transform.m34, node.transform.m44]
        ]

        var str = ""
        for c in 0..<4 {
            str += "\n"
            for r in 0..<4 {
                str += "\(nodeTranformMatrix[c][r]) "
            }
        }
        print("selectedNode:\n\(str)")
    }
}

extension ViewController: ImagePickerDelegate {
    public func didSelect(image: UIImage?) {
        scnManager.textureImage = image
    }
}
