//
//  ViewExtensions.swift
//  FrostKit
//
//  Created by James Barrow on 01/10/2014.
//  Copyright © 2014 - 2017 James Barrow - Frostlight Solutions. All rights reserved.
//

import UIKit

///
/// Extention functions for UIView
///
extension UIView {
    
    /// Returns a screen shot of the view.
    public var snapshotImage: UIImage? {
        
        var scale: CGFloat = 2.0
        if let window = self.window {
            scale = window.screen.scale
        } else {
            scale = UIScreen.main.scale
        }
        
        UIGraphicsBeginImageContextWithOptions(bounds.size, false, scale)
        drawHierarchy(in: bounds, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }
    
    /**
    Returns the parent view of a certain tpye.
     
    - parameter type: The type of parent view to match against.
     
    - returns: The parent view of the type passed in.
    */
    public func parentView<T>(ofType type: T.Type) -> T? {
        var currentView = self
        while currentView.superview != nil {
            if currentView is T {
                return currentView as? T
            }
            currentView = currentView.superview!
        }
        return nil
    }
}
