//
//  QubbiLoginController.swift
//  Qubbi
//
//  Created by Adrien Yvon on 6/30/17.
//  Copyright © 2017 Qubbi Team. All rights reserved.
//

import Foundation

// Login -> login, create Realm user, download and cache image, update timezone, store token
// Register -> register, create Realm user, update timezone, store token
// At login/signup the user is given an authId and accessToken, they must be stored in the Keychain using QubbiUserRealm.storeUserTokens()
// Logout -> delete qubbiUserRealm, delete user tokens
// UserInfos singleton properties update ( isLogged ) 

import TwitterKit
import FacebookCore
import Crashlytics

class QubbiLoginController {
	
	deinit {
		print("deinit QubbiLoginController")
	}
	
	enum SocialProviderError {
		case emailNotShared, other
	}
	
	func loginSocialUser(_ socialProvider: QubbiSocialUser.QubbiSocialProviderType,from controller: UIViewController?, completion: @escaping (QubbiUserRealm?,SocialProviderError?) -> Void) {
		if socialProvider == .facebook {
			// login FB
			guard let controller = controller else { return }
			loginFacebookUser(from: controller) { qubbiSocialUser, error in 
				if let qubbiSocialUser = qubbiSocialUser {
					self.registerSocialUser(qubbiSocialUser) { qubbiUserRealm in 
						guard let qubbiUserRealm = qubbiUserRealm else { completion(nil,.other); return }
						completion(qubbiUserRealm,nil)
					}
				} else if let error = error {
					completion(nil, error)
				}
			}
		} else {
			// login Twitter
			loginTwitterUser { qubbiSocialUser, error in 
				if let qubbiSocialUser = qubbiSocialUser {
					self.registerSocialUser(qubbiSocialUser) { qubbiUserRealm in 
						completion(qubbiUserRealm,nil)
					}
				} else if let error = error {
					completion(nil, error)
				}
			}
		}
	}
	
	/// Register user on Qubbi server DB, save user model in Realm, save tokens in Keychain
	private func registerSocialUser(_ socialUser: QubbiSocialUser, completion: @escaping (QubbiUserRealm?) -> Void) {
		loginSocialUserOnAPI(socialUser) { qubbiUserRealm, userTokens in 
			guard let qubbiUserRealm = qubbiUserRealm, let userTokens = userTokens else { completion(nil); return }
			self.saveUserTokens(userTokens)
			self.updateQubbiUserInRealm(qubbiUserRealm) { qubbiUserRealm in 
				completion(qubbiUserRealm)
			}
		}
	}
	
	private func loginTwitterUser(completion: @escaping (QubbiSocialUser?,SocialProviderError?) -> Void) {
		let twitterManager = TwitterManager()
		twitterManager.processTwitterUser { qubbiSocialUser, error in
			if let qubbiSocialUser = qubbiSocialUser {
				completion(qubbiSocialUser,nil)
			} else if let error = error {
				twitterManager.logout()
				if error == .emailNotShared {
					completion(nil, .emailNotShared)
				} else {
					completion(nil, .other)
				}
			}
		}
	}
	
	private func loginFacebookUser(from controller: UIViewController,completion: @escaping (QubbiSocialUser?,SocialProviderError?) -> Void) {
		let facebookManager = FacebookManager()
		facebookManager.processFacebookUser(from: controller) { qubbiSocialUser, error in
			if let qubbiSocialUser = qubbiSocialUser {
				completion(qubbiSocialUser,nil)
			} else if let error = error {
				facebookManager.logout()
				if error == .emailRefused {
					completion(nil, .emailNotShared)
				} else {
					completion(nil, .other)
				}
			}
		}
	}

	/// Register user on Qubbi server DB, save user model in Realm, save tokens in Keychain
	func registerUser(email: String, password: String, firstName: String, lastName: String, completion: @escaping (QubbiUserRealm?) -> Void) {
		registerUserOnAPI(email: email, password: password, firstName: firstName, lastName: lastName) { qubbiUserRealm, userTokens in 
			guard let qubbiUserRealm = qubbiUserRealm, let userTokens = userTokens else { completion(nil); return }
			self.saveUserTokens(userTokens)
			qubbiUserRealm.isNewUser = true 
			self.updateQubbiUserInRealm(qubbiUserRealm) { qubbiUserRealm in 
				completion(qubbiUserRealm)
			}
		}
	}
	
	/// login user via Qubbi, save user model in Realm, save tokens in Keychain
	func loginUser(username: String, password: String, completion: @escaping (QubbiUserRealm?) -> Void) {
		loginUserOnAPI(username: username, password: password) { qubbiUserRealm, userTokens in 
			guard let qubbiUserRealm = qubbiUserRealm, let userTokens = userTokens else { completion(nil); return }
			self.saveUserTokens(userTokens)
			self.updateQubbiUserInRealm(qubbiUserRealm) { qubbiUserRealm in 
				completion(qubbiUserRealm)
			}
		}
	}
	
	
	/// Logout user, logout social networks, delete user in Realm and tokens in Keychain, reset UserInfos, reset Crashlytics user infos
	func logoutUser() {
		guard let qubbiUserRealmController = QubbiUserRealmController() else { return }
		UserTokensController.deleteUserTokens()
		qubbiUserRealmController.deleteQubbiUserInRealm()
		UserInfos.shared.isLogged = false 
		UserInfos.shared.isQubbiNotificationAuthorized = false
        UserInfos.shared.loginType = .none
        FacebookManager.logoutFacebook()
        TwitterManager.logoutTwitter()
		QubbiNotifications.unregisterForRemoteNotifications()
        setCrashlyticsUserInfos(nil)
	}
	
	// Save user in Realm, save Crashlytics user infos
	private func updateQubbiUserInRealm(_ qubbiUserRealm: QubbiUserRealm, completion: @escaping (QubbiUserRealm) -> Void) {
		// Set bool for user logged
		UserInfos.shared.isLogged = true
        // Save user infos in Crashlytics
        setCrashlyticsUserInfos(qubbiUserRealm)
		let qubbiUserRealmController = QubbiUserRealmController(qubbiUserRealm)
		qubbiUserRealmController.downloadUserImage { _ in 
			qubbiUserRealmController.updateTimezone()
			qubbiUserRealmController.updateQubbiUserInRealm()
			completion(qubbiUserRealmController.qubbiUser)
		}
	}
	
	private func loginSocialUserOnAPI(_ socialUser: QubbiSocialUser, completion: @escaping (QubbiUserRealm?, UserTokens?) -> Void) {
		let body = socialUser.generateBodyDict()
		print(body)
		let requestAPI = RequestAPI()
		requestAPI.fireRequest(AuthRouter.createOrLoginSocial(body: body)) { jsonResponse in 
			guard let response = jsonResponse else { completion(nil,nil); return }
			print(response)
			if let qubbiUserRealm = QubbiUserRealm(response), let userTokens = UserTokens(response) {
				// assign social user image url if not already on server
				if qubbiUserRealm.profilePictureUrl == nil {
					qubbiUserRealm.profilePictureUrl = socialUser.imageUrl
				}
				completion(qubbiUserRealm, userTokens)
			} else {
				// error creating realm user
				print("Error cannot create QubbiUserRealm")
				completion(nil,nil)
			}
		}
	}
	
	// Register Qubbi user
	private func registerUserOnAPI(email: String, password: String, firstName: String, lastName: String, completion: @escaping (QubbiUserRealm?, UserTokens?) -> Void) {
		let requestAPI = RequestAPI()
		let body = ["username": email,"confirmPassword": password, "password": password, "firstName": firstName, "lastName": lastName, "timezoneId":TimeZone.autoupdatingCurrent.identifier]
		requestAPI.fireRequest(AuthRouter.createRegularUser(body: body)) { jsonResponse in
			guard let response = jsonResponse else { completion(nil,nil); return }
			print(response)
			if let qubbiUserRealm = QubbiUserRealm(response), let userTokens = UserTokens(response) {
				completion(qubbiUserRealm, userTokens)
			} else {
				// error creating realm user
				print("Error cannot create QubbiUserRealm")
				completion(nil,nil)
			}
		}
	}
	
	// Login Qubbi user
	private func loginUserOnAPI(username: String, password: String, completion: @escaping (QubbiUserRealm?, UserTokens?) -> Void) {
		let requestAPI = RequestAPI()
		let body = ["username":username, "password": password,"source":"mobile"]
		requestAPI.fireRequest(AuthRouter.loginRegular(body: body)) {
			jsonResponse in
			guard let response = jsonResponse else { completion(nil,nil); return }
			print(response)
			if let qubbiUserRealm = QubbiUserRealm(response), let userTokens = UserTokens(response) {
				completion(qubbiUserRealm, userTokens)
			} else {
				// error creating realm user
				print("Error cannot create QubbiUserRealm")
				completion(nil,nil)
			}
		}
	}
	
    // Store token in device Keychain received after login
	private func saveUserTokens(_ userTokens: UserTokens) {
		UserTokensController.storeUserTokens(userTokens)
	}
    
    // Setup Crashlytics shared instance to store user infos, in case of crash check on Crashlytics dashboard
    private func setCrashlyticsUserInfos(_ qubbiUserRealm: QubbiUserRealm?) {
        Crashlytics.sharedInstance().setUserEmail(qubbiUserRealm?.email)
        Crashlytics.sharedInstance().setUserName(qubbiUserRealm?.fullName)
        Crashlytics.sharedInstance().setUserIdentifier(qubbiUserRealm?.userId.description)
    }
}
