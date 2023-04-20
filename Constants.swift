//
//  Constants.swift
//  SimpleARKitDemo
//
//  Created by Justin Brady on 4/13/23.
//  Copyright © 2023 AppCoda. All rights reserved.
//

import Foundation
import ARKit

// prefix everything with SIMP_
let SIMP_CUBE_SIZE = 0.03 // cube is approx size of a alphabet block
let SIMP_carryDist = -0.1
let SIMP_SPAWN_INTERVAL_MS = 300000.0
let SIMP_JET_SCALE = 0.02
let SIMP_Q_ROTATE_STEPS = 18.0
let SIMP_MOTION_TIMER_FPS = 60.0
let SIMP_identMatrix =
    SCNMatrix4(m11: 1.0, m12: 0.0, m13: 0.0, m14: 0.0,
               m21: 0.0, m22: 1.0, m23: 0.0, m24: 0.0,
               m31: 0.0, m32: 0.0, m33: 1.0, m34: 0.0,
               m41: 0.0, m42: 0.0, m43: 0.0, m44: 1.0)
let SIMP_decelC: Float = 1.01
