//
//  ColorExtensionsTest.swift
//  FrostKit
//
//  Created by Niels Lemmens on 01/10/2014.
//  Copyright © 2014 - 2017 James Barrow - Frostlight Solutions. All rights reserved.
//

import XCTest
@testable import FrostKit

class ColorExtensionsTest: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSimpleHexColors() {
        
        measure { () in
            
            XCTAssert(Color.color(hexString: "#ffffff") == Color(red: 1, green: 1, blue: 1, alpha: 1), "Pass")
            XCTAssert(Color.color(hexString: "#123456") == Color(red: 18.0 / 255, green: 52.0 / 255, blue: 86.0 / 255, alpha: 1), "Pass")
        }
    }
    
    func testHexHashtag() {
        
        measure { () in
            
            // With or without #
            XCTAssert(Color.color(hexString: "#479123") == Color.color(hexString: "479123"), "Pass")
        }
    }
    
    func testShortHex() {
        
        measure { () in
            
            // 3 chars work as well as 6
            XCTAssert(Color.color(hexString: "#123") == Color.color(hexString: "#112233"), "Pass")
            // Regardless of #
            XCTAssert(Color.color(hexString: "123") == Color.color(hexString: "#112233"), "Pass")
        }
    }
    
    func testUnsuposedHexFormat() {
        
        measure { () in
            
            // 4 char hex should not parse and return default clearColor()
            XCTAssert(Color.color(hexString: "#1234") == Color.clear, "Pass")
            // Regardless of #
            XCTAssert(Color.color(hexString: "1234") == Color.clear, "Pass")
        }
    }
}
