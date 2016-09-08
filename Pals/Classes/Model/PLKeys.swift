//
//  PLKey.swift
//  Pals
//
//  Created by ruckef on 07.09.16.
//  Copyright © 2016 citirex. All rights reserved.
//

// https://api.pals.com/login?login=username&password=12345
// https://api.pals.com/friends?id=666&page=0&per_page=20

enum PLKeys : String {
    case id
    case name
    case picture
    case email
    case balance
    case user
    case response
    case login
    case password
    case success
    case per_page
    case since
    case page
    var string : String {
        return rawValue
    }
}