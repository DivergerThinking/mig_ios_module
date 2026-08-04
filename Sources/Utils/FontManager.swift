//
//  FontManager.swift
//  Pods
//
//  Created by Arnau Rivas Rivas on 11/2/25.
//

import Foundation
import FontBlaster

public class FontManager {
    func loadCustomFonts() {
        FontBlaster.debugEnabled = true
        
        // Bundle.main no contiene la fuente ni bajo SPM ni bajo CocoaPods
        // con resource_bundles: hay que escanear el bundle de recursos del SDK.
        FontBlaster.blast(bundle: .podBundle ?? .main) { fonts in
            Logger.shared.log(fonts.joined(separator: "\n"))
        }
    }
}

