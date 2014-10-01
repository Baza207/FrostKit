//
//  UIViewExtensions.swift
//  FrostKit
//
//  Created by James Barrow on 01/10/2014.
//  Copyright (c) 2014 Frostlight Solutions. All rights reserved.
//

import UIKit

extension UIView {
    
    public func screenshot() -> UIImage {
        
        var scale: CGFloat = 2.0
        if let window = self.window {
            scale = window.screen.scale
        } else {
            scale = UIScreen.mainScreen().scale
        }
        
        UIGraphicsBeginImageContextWithOptions(bounds.size, false, scale)
        drawViewHierarchyInRect(bounds, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        return image
    }
    
}