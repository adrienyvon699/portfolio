//
//  UserTokensController.swift
//  Qubbi
//
//  Created by Adrien Yvon on 7/7/17.
//  Copyright © 2017 Qubbi Team. All rights reserved.
//

import Foundation

class UserTokensController {
	
	private static let authIdKey = "authId"
	private static let accessTokenKey = "accessToken"
	
	static var authId: Int? {
		return KeychainWrapper.standard.integer(forKey: authIdKey)
	}
	
	static var accessToken: String? {
		return KeychainWrapper.standard.string(forKey: accessTokenKey)
	}
	
	// Delete tokens in Keychain
	class func deleteUserTokens() {
		_ = KeychainWrapper.standard.removeObject(forKey: authIdKey)
		_ = KeychainWrapper.standard.removeObject(forKey: accessTokenKey)
	}
	
	// Store authId and accessToken in Keychain.
	class func storeUserTokens(_ userTokens: UserTokens) {
		_ = KeychainWrapper.standard.set(userTokens.accessToken, forKey: accessTokenKey) 
		if let authId = userTokens.authId {
			_ = KeychainWrapper.standard.set(authId, forKey: authIdKey)
		}
	}
	
	class func sendFirebaseTokenToAPI(with token: String, forUserId userId: Int) {
		print("sending \(token) to API")
		let requestAPI = RequestAPI()
		requestAPI.fireRequestNoErrorDisplaying(APIRouter.updateFirebaseToken(userId: userId, token: token)) { response in
			print("token sent to API")
		}
	}
	
	
	
}
