import UIKit
import SceneKit
import Accelerate
import Foundation
import SceneKit

let NUMPOLE = 3
let NUMDISK = 6
private let NONE = 999
let poleX = [Float](arrayLiteral: -0.2,0,0.15)
let poleZ = [Float](arrayLiteral: -0.2,0.17,-0.1)
var movingDiskIndex:Int = NONE

let baseSize:CGFloat = 0.03
let jointBoxSize:CGFloat = 0.015
let segmentThickness:CGFloat = 0.01
let handThickness:CGFloat = 0.005
let chamfer:CGFloat = 0.005
let segmentLength:Float = 0.15
let gripperArmLength:Float = 0.03
let gripperWidth:Float = 0.17
let handLength:Float = 0.1
let maxHandOffset:Float = 0.075
let closeEnough:Float = 0.01

let BASE = 0
let SEG1 = 1
let SEG2 = 2
let SEG3 = 3
let GRIP = 4
let NUMANGLE = 5

var ptr:Hanoi!
var hScale:Float = 1

// MARK: DiskData

struct DiskData {
    var x:Int
    var y:Int
    var logicalWidth:Int
    var node:SCNNode!
    
    init( _ index:Int) {
        x = 0
        y = 0
        logicalWidth = 1 + index
        let radius:CGFloat = 0.02 + CGFloat(index) * 0.005
        let d = SCNTorus(ringRadius: radius, pipeRadius: 0.01)
        
        let hue:CGFloat = CGFloat(index) / CGFloat(NUMDISK)
        let color = UIColor(hue: hue, saturation: 1.0, brightness: 1.0, alpha:1.0)
        d.firstMaterial?.diffuse.contents = color
        
        node = SCNNode(geometry: d)
        scenePtr.rootNode.addChildNode(node)
    }
    
    func calcPosition() -> SCNVector3 { return  SCNVector3Make(poleX[x], Float(y-3) * 0.018, poleZ[x]) }
    func updatePosition() { node.position = calcPosition() }
};

// MARK: PoleData

struct PoleData {
    var pole:SCNCone
    var node:SCNNode!
    
    init( _ index:Int) {
        pole = SCNCone(topRadius: 0.005, bottomRadius: 0.008, height: 0.13)
        pole.firstMaterial?.diffuse.contents = UIColor(red:1, green:1, blue:1, alpha:1.0)
        
        node = SCNNode(geometry: pole)
        node.position = SCNVector3(x:Float(poleX[index]), y:0.0, z:Float(poleZ[index]))
        
        scenePtr.rootNode.addChildNode(node)
    }
};

// MARK: Joints

struct Joints {
    var angle = Array<Float>()
    init() { for _ in BASE ... GRIP { angle.append(Float()) } }
}

// MARK: ArmData

struct ArmData {
    var segment = Array<SCNNode>()
    var gripper1:SCNNode!
    var gripper2:SCNNode!
    var gCircle:SCNNode!
    var hand = Array<SCNNode>()
    var joints:Joints
    var destJoints:Joints
    var deltaJoints:Joints
    var currentHandOffset:Float
    var destHandOffset:Float
    
    init() {
        currentHandOffset = maxHandOffset
        destHandOffset = maxHandOffset
        
        let armColor = UIColor(red: 1, green:0.7, blue:0.1, alpha:1.0)
        let jointColor = UIColor(red: 1, green:0.3, blue:0.1, alpha:1.0)
        
        let armBox = SCNBox(width:segmentThickness, height:CGFloat(segmentLength), length:segmentThickness, chamferRadius:chamfer)
        armBox.firstMaterial?.diffuse.contents = armColor
        
        let jointBox = SCNBox(width:jointBoxSize, height:jointBoxSize, length:jointBoxSize, chamferRadius:chamfer)
        jointBox.firstMaterial?.diffuse.contents = jointColor
        
        let ga = SCNBox(width:segmentThickness, height:CGFloat(gripperArmLength), length:segmentThickness, chamferRadius:chamfer)
        ga.firstMaterial?.diffuse.contents = armColor
        
        let gg = SCNBox(width:CGFloat(gripperWidth), height:CGFloat(segmentThickness), length:segmentThickness, chamferRadius:chamfer)
        gg.firstMaterial?.diffuse.contents = armColor
        
        let gc = SCNTorus(ringRadius:CGFloat(gripperWidth/2.0), pipeRadius: 0.005)
        gc.firstMaterial?.diffuse.contents = armColor
        
        // base --------
        let baseBox = SCNBox(width:baseSize, height:baseSize, length:baseSize, chamferRadius:chamfer)
        baseBox.firstMaterial?.diffuse.contents = jointColor
        segment.append(SCNNode(geometry:baseBox))
        segment[BASE].position = SCNVector3(x: 0, y:0.35, z:0) // -0.05, z:0)
        
        // seg1 --------
        segment.append(SCNNode(geometry:armBox))
        segment[SEG1].position = SCNVector3(x: 0, y:0, z:0)
        segment[SEG1].pivot = SCNMatrix4MakeTranslation(0,segmentLength/2,0)
        
        let endBox1 = SCNNode(geometry:jointBox)
        endBox1.position = SCNVector3(x: 0, y:-segmentLength/2, z:0)
        
        // seg2 --------
        segment.append(SCNNode(geometry:armBox))
        segment[SEG2].position = endBox1.position
        segment[SEG2].pivot = SCNMatrix4MakeTranslation(0,segmentLength/2,0)
        
        let endBox2 = SCNNode(geometry:jointBox)
        endBox2.position = SCNVector3(x: 0, y:-segmentLength/2, z:0)
        
        // seg3 --------
        segment.append(SCNNode(geometry:armBox))
        segment[SEG3].position = endBox2.position
        segment[SEG3].pivot = SCNMatrix4MakeTranslation(0,segmentLength/2,0)
        
        let endBox3 = SCNNode(geometry:jointBox)
        endBox3.position = SCNVector3(x: 0, y:-segmentLength/2, z:0)
        
        // grip arm ---------
        segment.append(SCNNode(geometry:ga))
        segment[GRIP].position = endBox3.position
        segment[GRIP].pivot = SCNMatrix4MakeTranslation(0,gripperArmLength/2,0)
        
        // gCircle ----------
        gCircle = SCNNode(geometry:gc)
        gCircle.position = SCNVector3(x: 0, y:-gripperArmLength/2, z:0)
        
        // grip bars ---------
        gripper1 = SCNNode(geometry:gg)
        gripper1.position = SCNVector3(x: 0, y:-gripperArmLength/2, z:0)
        gripper2 = SCNNode(geometry:gg)
        gripper2.transform = SCNMatrix4MakeRotation(Float(Double.pi/2.0),0,1,0)
        gripper2.position = SCNVector3(x: 0, y:-gripperArmLength/2, z:0)
        
        for _ in 0..<4 {
            let box = SCNBox(width:handThickness, height:CGFloat(handLength), length:handThickness, chamferRadius:0)
            box.firstMaterial?.diffuse.contents = jointColor
            hand.append(SCNNode(geometry:box))
        }
        
        scenePtr.rootNode.addChildNode(segment[BASE])
        segment[BASE].addChildNode(segment[SEG1])
        segment[SEG1].addChildNode(endBox1)
        segment[SEG1].addChildNode(segment[SEG2])
        segment[SEG2].addChildNode(endBox2)
        segment[SEG2].addChildNode(segment[SEG3])
        segment[SEG3].addChildNode(endBox3)
        segment[SEG3].addChildNode(segment[GRIP])
        segment[GRIP].addChildNode(gripper1)
        segment[GRIP].addChildNode(gripper2)
        segment[GRIP].addChildNode(gCircle)
        for i in 0..<4 { segment[GRIP].addChildNode(hand[i]) }
        
        joints = Joints()
        destJoints = Joints()
        deltaJoints = Joints()
        
        // init joint angles -------------
        joints.angle[SEG2] = Float(Double.pi/4)
        joints.angle[SEG3] = Float(Double.pi/2.5)
        updateTransforms()
        
        destJoints = joints
        updateHandPositions()
    }
    
    mutating func updateHandPositions() // hands set currentHandOffset from center
    {
        for i in 0..<2 {
            hand[i].position = gripper1.position
            hand[i].position.y -= handLength/2
            
            let v = Float(i) * currentHandOffset * 2
            hand[i].position.x = v - currentHandOffset
        }
        for i in 2..<4 {
            hand[i].position = gripper2.position
            hand[i].position.y -= handLength/2
            
            let v = Float(i-2) * currentHandOffset * 2
            hand[i].position.z = v - currentHandOffset
        }
    }
    
    mutating func updateTransforms() // gripper always points down, all segments match joint[] angles
    {
        joints.angle[GRIP] = -joints.angle[SEG1] - joints.angle[SEG2] - joints.angle[SEG3]
        
        for ii in BASE ... GRIP {
            let tt = SCNMatrix4MakeTranslation(segment[ii].position.x,segment[ii].position.y,segment[ii].position.z)
            let rr = (ii == BASE) ? SCNMatrix4MakeRotation(joints.angle[ii], 0,1,0) : SCNMatrix4MakeRotation(joints.angle[ii], 0,0,1)
            segment[ii].transform = SCNMatrix4Mult(rr,tt)
        }
    }
    
    func effectorPosition(_ jjoints:Joints) -> SCNVector3 // position of center of tips of hands
    {
        var pos = segment[BASE].position
        var total = SCNVector3()
        var j = jjoints
        j.angle[GRIP] = -j.angle[SEG1] - j.angle[SEG2] - j.angle[SEG3]
        
        total.z  = j.angle[SEG1];   pos.add(SCNVector3(sinf(total.z)*segmentLength,-cosf(total.z)*segmentLength,0))
        total.z += j.angle[SEG2];   pos.add(SCNVector3(sinf(total.z)*segmentLength,-cosf(total.z)*segmentLength,0))
        total.z += j.angle[SEG3];   pos.add(SCNVector3(sinf(total.z)*segmentLength,-cosf(total.z)*segmentLength,0))
        
        total.z += j.angle[GRIP]
        let gLen = gripperArmLength + handLength - 0.01
        pos.add(SCNVector3(sinf(total.z)*gLen,-cosf(total.z)*gLen,0))
        
        let p5 = pos
        pos.x = +cosf(j.angle[BASE]) * pos.x
        pos.z = -sinf(j.angle[BASE]) * p5.x
        
        return pos
    }
    
    func effectorPosition() -> SCNVector3 { return effectorPosition(joints) }
    
    func distance(_ joints:Joints, _ dest:SCNVector3) -> Float // distance from hands to dest
    {
        let pos = effectorPosition(joints)
        let dx = pos.x - dest.x
        let dy = pos.y - dest.y
        let dz = pos.z - dest.z
        return sqrtf(dx*dx + dy*dy + dz*dz)
    }
    
    func ik(_ dest:SCNVector3) -> Joints // adjust segment angles until hands reach dest
    {
        var j = joints
        var dist:Float = 0
        let aHop:Float = 0.01
        
        var trials:Int = 0
        
        repeat {
            for _ in 0 ... 200 {
                for i in BASE ... SEG3 {
                    var d0 = distance(j,dest)   // current distance
                    
                    var j1 = j
                    j1.angle[i] -= aHop
                    let d1 = distance(j1,dest)  // distance if we rotate left
                    
                    var j2 = j
                    j2.angle[i] += aHop
                    let d2 = distance(j2,dest)  // distance if we rotate right
                    
                    if d1 < d0 { d0 = d1; j.angle[i] = j1.angle[i] }
                    if d2 < d0 { j.angle[i] = j2.angle[i] }
                }
                
                // gripper always points down
                j.angle[GRIP] = -j.angle[SEG1] - j.angle[SEG2] - j.angle[SEG3]
                
                trials += 1
                if trials > 10000 {
                    dist = distance(j,dest)
                    Swift.print("Impossible destination: ", dest, " best Dist: ", dist)
                    exit(0)
                }
            }
            
            dist = distance(j,dest)
            
        } while dist > closeEnough
        
        return j
    }
    
    mutating func updateDestJoints(_ jj:Joints)
    {
        destJoints = jj
        
        for i in BASE ... SEG3 {
            deltaJoints.angle[i] = (destJoints.angle[i] - joints.angle[i]) / 100.0
        }
    }
    
    mutating func moveToDestination() -> Bool
    {
        var isMoving = false
        
        for i in BASE ... SEG3 {
            if fabs(joints.angle[i] - destJoints.angle[i]) > closeEnough {
                isMoving = true
                joints.angle[i] += deltaJoints.angle[i]
            }
        }
        
        // are hands moving?
        let dx = destHandOffset - currentHandOffset
        if fabs(dx) > 0.003 {
            currentHandOffset += dx * 0.03
            if dx > 0 { currentHandOffset += dx * 0.03 }
            updateHandPositions()
            isMoving = true
        }
        
        if !isMoving {  // close enough to stop moving, now set final position perfectly
            for i in BASE ... SEG3 {
                joints.angle[i] = destJoints.angle[i]
            }
            
            currentHandOffset = destHandOffset
            updateHandPositions()
        }
        
        updateTransforms()
        return isMoving
    }
};


// MARK: Hanoi

class Hanoi {
    var arm:ArmData!
    var disk = Array<DiskData>()
    var pole = Array<PoleData>()
    var previousMoveIndex = NONE
    let idleY:Float = 0.1
    
    init(_ base:SCNVector3) {
        for i in 0 ..< NUMPOLE { pole.append(PoleData(i)) } // ,base)) }
        for i in 0 ..< NUMDISK { disk.append(DiskData(i)) } // ,base)) }
        arm = ArmData() // base)
        reset()
    }
    
    //---------------------------------
    var bAngle:Float = 0
    var grippedIndex:Int = NONE
    enum MoveState { case idle,aboveSrc,atSrc,closeGrip,gripAboveSrc,gripAboveDest,gripAtDest,releaseGrip }
    var state:MoveState = .idle
    
    func update() {
        let isMoving = arm.moveToDestination()
        
        if !isMoving {
            switch(state) {
            case .idle :
                performAutoMove()
                var pos = disk[movingDiskIndex].node.position // where disk is now
                pos.y = idleY
                arm.updateDestJoints(arm.ik(pos))
                state = .aboveSrc
                break
                
            case .aboveSrc :
                arm.updateDestJoints(arm.ik(disk[movingDiskIndex].node.position))
                state = .atSrc
                break
                
            case .atSrc :
                arm.destHandOffset = 0.03 + Float(movingDiskIndex) * 0.005
                state = .closeGrip
                break
                
            case .closeGrip :
                grippedIndex = movingDiskIndex
                var pos = disk[movingDiskIndex].node.position // where disk is now
                pos.y = idleY
                arm.updateDestJoints(arm.ik(pos))
                
                state = .gripAboveSrc
                break
                
            case .gripAboveSrc :
                var pos = disk[movingDiskIndex].calcPosition() // where disk is going
                pos.y = idleY
                arm.updateDestJoints(arm.ik(pos))
                state = .gripAboveDest
                break
                
            case .gripAboveDest :
                arm.updateDestJoints(arm.ik(disk[movingDiskIndex].calcPosition()))
                state = .gripAtDest
                break
                
            case .gripAtDest :
                state = .releaseGrip
                arm.destHandOffset = maxHandOffset
                grippedIndex = NONE
                break
                
            case .releaseGrip :
                var pos = disk[movingDiskIndex].calcPosition() // where disk is going
                pos.y = idleY
                arm.updateDestJoints(arm.ik(pos))
                state = .idle
                break
            }
        }
        
        if isMoving {
            if grippedIndex != NONE {
                disk[grippedIndex].node.position = arm.effectorPosition()
            }
        }
    }
    
    required init(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func reset() {
        for i in 0..<NUMDISK {
            disk[i].x = 0
            disk[i].y = NUMDISK - i - 1
            disk[i].updatePosition()
        }
        
        previousMoveIndex = NONE
    }
    
    // index of topmost disk in specifed column, or NONE
    func topDiskIndexInColumn(_ column:Int) -> Int {
        var diskIndex = NONE;
        var width = 9999
        
        for i in 0..<NUMDISK {
            if disk[i].x == column && disk[i].logicalWidth < width {
                diskIndex = i
                width = disk[i].logicalWidth
            }
        }
        
        return diskIndex
    }
    
    func performAutoMove() {
        //1. find smallest disk to move (not the just moved piece)
        var cTop = [Int](arrayLiteral: NONE,NONE,NONE)
        for i in 0..<NUMPOLE {
            if previousMoveIndex != i  {
                cTop[i] = topDiskIndexInColumn(i)
            }
        }
        
        if cTop[0] == NONE && cTop[1] == NONE && cTop[2] == NONE { previousMoveIndex = NONE; return }
        
        var smallest = 0
        if cTop[1] < cTop[0] && cTop[1] < cTop[2] { smallest = 1 } else
            if cTop[2] < cTop[0] && cTop[2] < cTop[1] { smallest = 2 }
        
        movingDiskIndex = cTop[smallest]
        
        //2. find 1st legal destination
        var dest = smallest + 1
        if(dest > 2) { dest = 0 }
        
        let destTop = topDiskIndexInColumn(dest)
        if destTop != NONE && destTop < movingDiskIndex { // illegal destination, next one must be okay
            dest = dest + 1
            if dest > 2 { dest = 0 }
        }
        
        let topMostDisk = topDiskIndexInColumn(dest)
        
        disk[movingDiskIndex].x = dest
        disk[movingDiskIndex].y = topMostDisk == NONE ? 0 : disk[topMostDisk].y+1
        
        previousMoveIndex = dest
    }
}

extension SCNVector3 {
    mutating func add(_ v:SCNVector3) {
        self.x += v.x
        self.y += v.y
        self.z += v.z
    }
}

