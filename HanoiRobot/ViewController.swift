import UIKit
import QuartzCore
import SceneKit

var scenePtr:SCNScene!
var hanoi:Hanoi!
var timer = Timer()

class ViewController: UIViewController {
    @IBOutlet var sView: SCNView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sView.backgroundColor = UIColor.black
        sView.autoenablesDefaultLighting = true
        sView.allowsCameraControl = true
        sView.scene = SCNScene()
        
        scenePtr = sView.scene
        
        hanoi = Hanoi(SCNVector3(-0.1,0.1,0))
        timer = Timer.scheduledTimer(timeInterval: 1.0/60.0, target:self, selector: #selector(ViewController.timerHandler), userInfo: nil, repeats:true)
    }
    
    @objc func timerHandler() { hanoi.update() }
    
    override var prefersStatusBarHidden : Bool { return true }
}
