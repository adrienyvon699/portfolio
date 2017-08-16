//
//  MyProfileTableViewController.swift
//  Qubbi
//
//  Created by Created by Adrien YVON 12/15/15.
//  Copyright © 2015 Adrien YVON. All rights reserved.
//

import UIKit

import FBSDKLoginKit
import FacebookCore
import TwitterKit
import UserNotifications


// MARK: - ImagePicker delegate
extension MyProfileTableViewController: UserImagePickerControllerDelegate {
    func userDidPickImage(_ image: UIImage) {
        DispatchQueue.global(qos: .userInitiated).async {
            PhotosManager.shared.resizeImage(image, toFill: self.avatarImage.frame.size, roundedBy: self.avatarImage.frame.height / 2) { image in
                guard let imageData = image.jpegRepresentationData else { return }
                DispatchQueue.main.async {
                    self.avatarImage.image = image
                    self.qubbiUserRealmController.saveUserImage(imageData)
                }
            }
        }
    }
}

class MyProfileTableViewController: UITableViewController {
    
    // MARK: - Outlets and Properties
    
    @IBOutlet weak var fullName: UILabel!
    @IBOutlet weak var email: UILabel!
    @IBOutlet weak var numberOfPoints: UILabel!
    @IBOutlet weak var addPictureImage: UIImageView!
    @IBOutlet weak var avatarImage: UIImageView!
    @IBOutlet weak var facebookSwitch: UISwitch!
    @IBOutlet weak var twitterSwitch: UISwitch!
	@IBOutlet weak var notificationsSwitch: UISwitch!
    @IBOutlet weak var twitterActivityIndicator: UIActivityIndicatorView!
    
    private let userImagePickerController = UserImagePickerController()
    
    var qubbiUserRealmController: QubbiUserRealmController!
	private var userInfos: UserInfos { return .shared }
    
    enum LogoutType {
        case facebook
        case twitter
        case qubbi
    }
    
    // MARK: - Lifecycle
    deinit {
        print("MyProfile deinit")
		NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
		NotificationCenter.default.addObserver(self, 
		                                       selector: #selector(checkNotif), 
		                                       name: Notification.Name.UIApplicationDidBecomeActive, 
		                                       object: nil)
    }
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		checkNotif()
		print("Will appear")
	}
	
    // MARK: - Methods
    
    private func setupView() {
        let navBarConfig = NavBarConfig(navBar: self.navigationController!.navigationBar)
        navBarConfig.initNavBar()
        numberOfPoints.text = "Loading..."
        userImagePickerController.userImagePickerControllerDelegate = self
        avatarImage.tintColor = Colors.lightGray
        addPictureImage.tintColor = Colors.qubbiOrange
        
        if FacebookManager.isLoggedInFacebook() {
            facebookSwitch.setOn(true, animated: false)
        } else {
            facebookSwitch.setOn(false, animated: false)
        }
        if TwitterManager.isLoggedInTwitter() {
            twitterSwitch.setOn(true, animated: false)
        } else {
            twitterSwitch.setOn(false, animated: false)
        }
		
        updateUI(qubbiUserRealmController.qubbiUser)
        
    }
    
    func updateUI(_ qubbiUserRealm: QubbiUserRealm) {
        fullName.text = qubbiUserRealm.fullName
        email.text = qubbiUserRealm.email
        numberOfPoints.text = qubbiUserRealm.points.description + " Points"
        if let userImage = qubbiUserRealm.userImage {
            avatarImage.image = userImage
        }
    }
	
	func checkNotif() {
		notificationsSwitch.setOn(UserInfos.shared.isQubbiNotificationAuthorized, animated: true)
	}
    
    
    
    private func logoutUser(type: LogoutType) {
        Alert.confirmLogout.displayAlert(from: self, style: .actionSheet) { logout in
            if logout {
                // delete user infos, logout socials, back to login
                let loginManager = QubbiLoginController()
                loginManager.logoutUser()
                self.backToLogin()
            } else {
                switch type {
                case .facebook:
                    self.facebookSwitch.setOn(true, animated: true)
                case .twitter:
                    self.twitterSwitch.setOn(true, animated: true)
                default: break
                }
            }
        }
        
    }
    
    private func backToLogin() {
        if let presentingVC = navigationController?.presentingViewController as? SWRevealViewController, let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            print("dismiss swreveal")
            presentingVC.frontViewController = nil
            presentingVC.rearViewController = nil
            presentingVC.dismiss(animated: false, completion: nil)
            appDelegate.changeRootViewController(with: "LoginNav", forStoryboard: "Login", withAnimation: true)
        }
        
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 4
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 35
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 2 {
            if indexPath.row == 0 {
                performSegue(withIdentifier: "Categories", sender: nil)
            }
        }
    }
   
    // MARK: - Actions
    @IBAction func backToHomeButton(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func signOut(_ sender: UIButton) {
        logoutUser(type: .qubbi)
    }
  
    @IBAction func facebookSwitch(_ sender: UISwitch) {
		if sender.isOn {
            // Login Facebook
            FacebookManager.loginUser(from: self) { logged in
                self.facebookSwitch.setOn(logged, animated: true)
                if !logged {
                    Alert.facebookIssue.displayAlert(from: self)
                }
            }
        } else if !sender.isOn {
            // Check if user is only logged with Facebook
            if userInfos.loginType == .facebook {
                logoutUser(type: .facebook)
            } else {
                FacebookManager.logoutFacebook()
            }
        }
    }
    
    @IBAction func twitterSwitch(_ sender: UISwitch) {
        if sender.isOn {
            // Login twitter
            twitterActivityIndicator.startAnimating()
            view.isUserInteractionEnabled = false
            TwitterManager.loginUser(from: self) { logged in
                self.twitterActivityIndicator.stopAnimating()
                self.view.isUserInteractionEnabled = true
                self.twitterSwitch.setOn(logged, animated: true)
                if !logged {
                    Alert.twitterIssue.displayAlert(from: self)
                }
            }
        } else if !sender.isOn {
            // Check if user is only logged with Twitter
            if userInfos.loginType == .twitter {
                logoutUser(type: .twitter)
            } else {
                TwitterManager.logoutTwitter()
            }
        }
    }
	
	@IBAction func notificationSwitch(_ sender: UISwitch) {
		if sender.isOn {
			// Check if notif authorization
			QubbiNotifications.checkNotificationAuthorizationStatus { authorizationStatus in 
				if authorizationStatus == .denied {
					// show alert, switch back to off
					DispatchQueue.main.async {
						sender.setOn(false, animated: true)
						self.notificationAlert()
					}
				} else {
					// register for notif
					QubbiNotifications.registerForRemoteNotifications { granted in 
						self.userInfos.isQubbiNotificationAuthorized = granted 
					}
				}
			}
		} else {
			QubbiNotifications.unregisterForRemoteNotifications()
			self.userInfos.isQubbiNotificationAuthorized = false 
		}
	}
	
	private func notificationAlert() {
		Alert.authorizeNotifications.displayAlert(from: self, style: .alert) { openSettings in
			if openSettings {
				self.openAppSettings()
			} 
		}
	}
	
	private func openAppSettings() {
		guard let settingsUrl = URL(string: UIApplicationOpenSettingsURLString) else {
			return
		}
		UIApplication.shared.open(settingsUrl, options: [:], completionHandler: nil)
	}
	
    
    @IBAction func addPicture(_ sender: UIButton) {
        userImagePickerController.selectMediaType(from: self)
    }
    
}
