//
//  AuthorizationToken.swift
//  FrostKit
//
//  Created by James Barrow on 19/01/2015.
//  Copyright (c) 2015 Frostlight Solutions. All rights reserved.
//

import UIKit

public class AuthorizationToken: NSObject, NSCoding, NSCopying {
    
    lazy var accessToken = ""
    lazy var refreshToken = ""
    lazy var expiresAt: NSTimeInterval = 0
    var expiresAtDate: NSDate {
        return NSDate(timeIntervalSinceReferenceDate: expiresAt)
    }
    var expired: Bool {
        return NSDate.timeIntervalSinceReferenceDate() > expiresAt
    }
    lazy var tokenType = ""
    lazy var scope = ""
    
    override init() {
        super.init()
    }
    
    convenience init(accessToken: String, refreshToken: String, expiresAt: NSTimeInterval, tokenType: String, scope: String) {
        self.init()
        
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.tokenType = tokenType
        self.scope = scope
    }
    
    convenience init(json: [String: AnyObject], requestDate: NSDate = NSDate()) {
        self.init()
        
        if let accessToken = json["access_token"] as? String {
            self.accessToken = accessToken
        }
        
        if let refreshToken = json["refresh_token"] as? String {
            self.refreshToken = refreshToken
        }
        
        if let expiresIn = json["expires_in"] as? Int {
            self.expiresAt = requestDate.timeIntervalSinceReferenceDate + NSTimeInterval(expiresIn)
        }
        
        if let tokenType = json["token_type"] as? String {
            self.tokenType = tokenType
        }
        
        if let scope = json["scope"] as? String {
            self.scope = scope
        }
    }
    
    // MARK: - NSCoding Methods
    
    public required init(coder aDecoder: NSCoder) {
        super.init()
        
        accessToken = aDecoder.decodeObjectForKey("access_token") as String
        refreshToken = aDecoder.decodeObjectForKey("refresh_token") as String
        expiresAt = aDecoder.decodeDoubleForKey("expires_at")
        tokenType = aDecoder.decodeObjectForKey("token_type") as String
        scope = aDecoder.decodeObjectForKey("scope") as String
    }
    
    public func encodeWithCoder(aCoder: NSCoder) {
        
        aCoder.encodeObject(accessToken, forKey: "access_token")
        aCoder.encodeObject(refreshToken, forKey: "refresh_token")
        aCoder.encodeDouble(expiresAt, forKey: "expires_at")
        aCoder.encodeObject(tokenType, forKey: "token_type")
        aCoder.encodeObject(scope, forKey: "scope")
    }
    
    // MARK: - NSCopying Methods
    
    public func copyWithZone(zone: NSZone) -> AnyObject {
        return AuthorizationToken(accessToken: self.accessToken, refreshToken: self.refreshToken, expiresAt: self.expiresAt, tokenType: self.tokenType, scope: self.scope)
    }
    
}
