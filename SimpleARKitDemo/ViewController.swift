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
    
    var selectedNode: SCNNode!
    
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
    
    /*
    func addBox(x: Float = 0, y: Float = 0, z: Float = -0.2) {
        
        let planeScene = SCNScene(named: "newship.scn")
        
        if let plane = planeScene?.rootNode.childNodes.first {
            plane.scale = SCNVector3(0.2, 0.2, 0.2)
            plane.position = SCNVector3(x, y, z)
            sceneView.scene.rootNode.addChildNode(plane)
        }
    }
    */
    
    func addTapGestureToSceneView() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(ViewController.didTap(withGestureRecognizer:)))
        sceneView.addGestureRecognizer(tapGestureRecognizer)
    }
    
    @objc func didTap(withGestureRecognizer recognizer: UIGestureRecognizer) {
        let tapLocation = recognizer.location(in: sceneView)
        let hitTestResults = sceneView.hitTest(tapLocation)
       
        guard let node = hitTestResults.first?.node else {
            
//            let hitTestResultsWithFeaturePoints = sceneView.hitTest(tapLocation, types: .featurePoint)
//            
//            if let hitTestResultWithFeaturePoints = hitTestResultsWithFeaturePoints.first {
//                let translation = hitTestResultWithFeaturePoints.worldTransform.translation
//                addBox(x: translation.x, y: translation.y, z: translation.z)
//            }
            
            return
        }
        
        selectedNode = node

        /*
        SCNTransaction.animationDuration = 4.0
        SCNTransaction.begin()
        //node.scale = SCNVector3(0.001, 0.001, 0.001)
        node.localRotate(by: SCNQuaternion(0, 0.9999997, 0, 0.0007963))
        SCNTransaction.commit()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            node.removeFromParentNode()
        }
        */
    }
}

extension float4x4 {
    var translation: float3 {
        let translation = self.columns.3
        return float3(translation.x, translation.y, translation.z)
    }
}

