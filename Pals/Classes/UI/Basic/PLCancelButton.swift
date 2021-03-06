//
//  PLCancelButton.swift
//  Pals
//
//  Created by Vitaliy Delidov on 11/22/16.
//  Copyright © 2016 citirex. All rights reserved.
//

import UIKit

@IBDesignable
class PLCancelButton: PLHighlightedButton {
    
    @IBInspectable var fillColor: UIColor = .redColor()
    @IBInspectable var strokeColor: UIColor = .whiteColor()
    @IBInspectable var lineWidth: CGFloat = 2.0
    
    let paddingPercent: CGFloat = 0.32
    
    
    override func drawRect(rect: CGRect) {
        fillColor.set()
        let circlePath = UIBezierPath(roundedRect: bounds, cornerRadius: bounds.size.width / 2.0)
        circlePath.fill()
 
        strokeColor.set()
        
        // First slash: \
        let firstSlash = UIBezierPath()
        styleBezierPath(firstSlash)
        
        // Give the 'X' a bit of padding from the bounds
        let slashPadding = bounds.size.width * paddingPercent
        
        // Start in the upper-left
        var topLeft = CGPointMake(bounds.origin.x + slashPadding, bounds.origin.y + slashPadding)
        firstSlash.moveToPoint(topLeft)
        
        // Slide down, and to the right
        topLeft.x = bounds.origin.x + bounds.size.width - slashPadding
        topLeft.y = bounds.origin.y + bounds.size.height - slashPadding
        firstSlash.addLineToPoint(topLeft)
        firstSlash.stroke()
        
        // Create a copy of the first slash: \
        let secondSlash = UIBezierPath(CGPath: firstSlash.CGPath)
        styleBezierPath(secondSlash)
        
        // Mirror the slash over the Y axis: /
        let mirrorTransform = CGAffineTransformMakeScale(1.0, -1.0)
        secondSlash.applyTransform(mirrorTransform)
        
        // And translate ("move") the path to intersect the first slash
        let translateOverY = CGAffineTransformMakeTranslation(0.0, bounds.size.height)
        secondSlash.applyTransform(translateOverY)
        secondSlash.stroke()
    }
    
    private func styleBezierPath(path: UIBezierPath) {
        path.lineWidth = lineWidth
        path.lineCapStyle = .Square
    }
    
}
