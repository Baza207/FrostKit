//
//  KeychainHelperTests.swift
//  FrostKit
//
//  Created by James Barrow on 04/10/2014.
//  Copyright (c) 2014-2015 James Barrow - Frostlight Solutions. All rights reserved.
//

import XCTest
import FrostKit

class KeychainHelperTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testKeychainWorkflow() {
        
        let username = "myName"
        let password = "qwerty1234567890!_<>,.!@#$%^&*()_+-=/?"
        
        let setDetailsComplete = KeychainHelper.setDetails(details: password, username: username)
        let updateDetailsComplete = KeychainHelper.setDetails(details: password, username: username)
        let getDetailsComplete = (password == KeychainHelper.details(username: username) as String)
        let deleteDetailsComplete = KeychainHelper.deleteKeychain()
        
        XCTAssert(setDetailsComplete, "Pass")
        XCTAssert(updateDetailsComplete, "Pass")
        XCTAssert(getDetailsComplete, "Pass")
        XCTAssert(deleteDetailsComplete, "Pass")
    }
    
}
