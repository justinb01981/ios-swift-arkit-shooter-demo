//
//  ViewController.swift
//  SimpleARKitDemo
//
// author: justin@domain17.net
//

import UIKit
import ARKit
import Combine

class ViewController: UIViewController {

    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var axisSelector: UISegmentedControl!
    @IBOutlet weak var btnPlus: UIButton!
    @IBOutlet weak var btnMinus: UIButton!
    @IBOutlet var scnManager: SceneManager!
    @IBOutlet weak var textField: UITextView!
    
    private var imagePicker: ImagePicker!
    private var cancelme: Cancellable?!
    private var selCancelme: Cancellable?!
    private var obsText: AnyCancellable! // retained and freed automatically stops observing
    private var untested = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        scnManager = SceneManager(scene: sceneView)
        
        addTapGestureToSceneView()
        
        obsText = scnManager.objectWillChange.sink {
            guard let sel = self.scnManager.selectedNode else {
                self.textField.text = ""
                return
            }
            
            self.textField.text = self.scnManager.sceneDescription
        }
        
        selCancelme = axisSelector.publisher(for: \.selectedSegmentIndex).sink(receiveValue: {
            newVal in
            //self.scnManager.adjustScene(SceneAction(rawValue: newVal)!)
        })
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration)

        // now start
        scnManager.start()
        
        cancelme = scnManager.objectWillChange.sink(receiveValue: {
            //
        })
        
        scnManager.appear()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
        
        scnManager.disappear()
    }
    
    func addTapGestureToSceneView() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(ViewController.didTap(withGestureRecognizer:)))
        sceneView.addGestureRecognizer(tapGestureRecognizer)
    }
    
    @objc func didTap(withGestureRecognizer recognizer: UIGestureRecognizer) {
        // TODO? focusing on buttons for now
    }
    
    // MARK: buttons handling
    
    var delt: Float = 1.0
    var deltS: Float = 0.1
    
    @IBAction func onMinus(_ sender: Any) {
        // -
        delt = -deltS
        scnManager.adjustSceneNeg(SceneAction(rawValue: axisSelector.selectedSegmentIndex)!)
    }
    
    @IBAction func onPlus(_ sender: Any) {
        // +
        delt = deltS
        scnManager.adjustScenePos(SceneAction(rawValue: axisSelector.selectedSegmentIndex)!)
    }
    
    @IBAction func onSelImage(_ sender: Any) {
        imagePicker = ImagePicker(presentationController: self, delegate: self)
        imagePicker.present(from: sender as! UIView)
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
        
        let tapLocation = touches.first!.location(in: sceneView)
        let hitTestResults = sceneView.hitTest(tapLocation)
        
        guard hitTestResults.count == 0
        else {
            scnManager.selectedNode =
            scnManager.nodesInMotion.first(where: { n in
                n.scnNode == hitTestResults.first!.node
            })!
            
            print("\(DEBUG_PFX) node \(scnManager.selectedNode) selected")
            return
        }
        print("\(DEBUG_PFX) node \(scnManager.selectedNode) deselected")
        scnManager.selectedNode = nil
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        guard let node = scnManager.selectedNode,
            let touch = touches.first else {
            return
        }
        
        let touchDelt: CGFloat = (touch.location(in: view).x - touch.previousLocation(in: view).x)
        /
        abs(touch.location(in: view).x - touch.previousLocation(in: view).x)
        
        if touchDelt.isNaN {
            return
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        // TODO: handle? maybe drop carried node - for now deselect by touching again
    }
    
    func updateScene() {
        scnManager.adjustScene(SceneAction(rawValue: axisSelector.selectedSegmentIndex)!)
    }
}

// MARK: -- extensions

extension ViewController {
    func printMatrix(_ node: SCNNode) {
        
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
        print("\(DEBUG_PFX) selectedNode:\n\(str)")
        
        scnManager.adjustScene(SceneAction(rawValue: axisSelector.selectedSegmentIndex)!)
    }
}

extension ViewController: ImagePickerDelegate {
    public func didSelect(image: UIImage?) {
        scnManager.textureImage = image
    }
}
