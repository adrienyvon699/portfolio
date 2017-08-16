//
//  UserImagePickerController.swift
//  Qubbi
//
//  Created by Adrien Yvon on 8/14/17.
//  Copyright © 2017 Qubbi Team. All rights reserved.
//

import UIKit

protocol UserImagePickerControllerDelegate: class {
    func userDidPickImage(_ image: UIImage)
}

extension UserImagePickerController: UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        guard let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage,
            let pickerDelegate = userImagePickerControllerDelegate else {
            print("Error during image picking")
            dismiss(animated: true, completion: nil)
            return
        }
        pickerDelegate.userDidPickImage(pickedImage)
        dismiss(animated: true, completion: nil)
    }
}

class UserImagePickerController: UIImagePickerController {
    
    weak var userImagePickerControllerDelegate: UserImagePickerControllerDelegate?
    
    deinit {
        print("PICKER DEINIT")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
    }
    
    func selectMediaType(from controller: UIViewController) {
        Alert.changeProfilePicture.displaySheetAlert(from: controller) { actionNumber in
            switch actionNumber {
            case 0: break
            case 1:
                self.sourceType = .camera
                self.cameraFlashMode = .off
                self.cameraCaptureMode = .photo
                self.cameraDevice = .rear
                controller.present(self, animated: true, completion: nil)
            case 2:
                self.sourceType = .photoLibrary
                controller.present(self, animated: true, completion: nil)
            default: break
            }
        }
    }

}
