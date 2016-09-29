//
//  PLSelector.swift
//  Pals
//
//  Created by Vitaliy Delidov on 9/29/16.
//  Copyright © 2016 citirex. All rights reserved.
//

import Foundation

extension Selector {

    static let dismissTap = #selector(PLViewController.dismissKeyboard(_:))
    static let backButtonTap = #selector(PLBackBarButtonItem.backButtonTapped(_:))
    static let completeButtonTap = #selector(PLCardInfoViewController.completeButtonTapped(_:))
    static let keyboardWillShow = #selector(PLSignUpViewController.keyboardWillShow(_:))
    static let keyboardWillHide = #selector(PLSignUpViewController.keyboardWillHide(_:))
}