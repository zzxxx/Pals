//
//  PLFacade.swift
//  Pals
//
//  Created by ruckef on 01.09.16.
//  Copyright © 2016 citirex. All rights reserved.
//

typealias PLErrorCompletion = (error: NSError?) -> ()

protocol PLFacadeInterface {
    static func login(userName:String, password: String, completion: PLErrorCompletion)
    static func logout(completion: PLErrorCompletion)
    static func signUp(data: PLSignUpData, completion: PLErrorCompletion)
    static func sendOrder(order: PLCheckoutOrder, completion: PLErrorCompletion)
    static func updateProfile(data: PLEditableUser, completion: PLErrorCompletion)//FIXME: signupdata.
    static func sendPassword(email: String, completion: PLErrorCompletion)
    static func fetchNearRegion(completion: PLLocationRegionCompletion)
    static func fetchNearRegion(size: CGSize, completion: PLLocationRegionCompletion)
    static var profile: PLUser? {get}
}

class PLFacade : PLFacadeInterface {
    static let instance = _PLFacade()
    static var profile: PLUser? {
        return instance.profileManager.profile
    }
    
    class func hasValidToken() -> Bool {
        return instance.profileManager.hasValidToken()
    }
    
    class func restoreUserProfile() {
        instance.profileManager.restoreProfile()
    }
    
    class func login(userName:String, password: String, completion: PLErrorCompletion) {
        instance._login(userName, password: password, completion: completion)
    }
    
    class func logout(completion: PLErrorCompletion) {
        instance._logout(completion)
    }
    
    class func signUp(data: PLSignUpData, completion: PLErrorCompletion) {
        instance._signUp(data, completion: completion)
    }
    
    class func sendPassword(email: String, completion: PLErrorCompletion) {
        instance._sendPassword(email, completion: completion)
    }
    
    class func updateProfile(data: PLEditableUser, completion: PLErrorCompletion) {
        instance._updateProfile(data, completion: completion)
    }
    
    class func sendOrder(order: PLCheckoutOrder, completion: PLErrorCompletion) {
        instance._sendOrder(order, completion: completion)
    }
    
    class func fetchNearRegion(size: CGSize, completion: PLLocationRegionCompletion) {
        instance._fetchNearRegion(size, completion: completion)
    }
    
    class func fetchNearRegion(completion: PLLocationRegionCompletion) {
        instance._fetchNearRegion(completion)
    }
    
    class _PLFacade {
        let settingsManager = PLSettingsManager()
        let locationManager = PLLocationManager()
        let profileManager  = PLProfileManager()
    }
}

let kMimePng = "image/png"

extension PLFacade._PLFacade {
    
    private func createAttachment(image: UIImage?) -> PLUploadAttachment? {
        var attachment: PLUploadAttachment?
        if image != nil {
            let imageData = UIImagePNGRepresentation(image!)!
            attachment = PLUploadAttachment(name: PLKeys.picture.string, mimeType: kMimePng, data: imageData)
        }
        return attachment
    }
    
    func _signUp(data: PLSignUpData, completion: PLErrorCompletion) {
        let params = data.params
        let attachment = createAttachment(data.picture)
        PLNetworkManager.post(PLAPIService.SignUp, parameters: params, attachment: attachment) { (dic, error) in
            self.handleUserLogin(error, dic: dic, completion: completion)
        }
    }
    
    func _login(userName:String, password: String, completion: PLErrorCompletion) {
        let params = [PLKeys.login.string : userName, PLKeys.password.string : password]
        PLNetworkManager.get(PLAPIService.Login, parameters: params) { (dic, error) in
            self.handleUserLogin(error, dic: dic, completion: completion)
        }
    }
    
    func _logout(completion: PLErrorCompletion) {
        PLNetworkManager.get(PLAPIService.Logout, parameters: nil) { (dic, error) in
            print(dic)
            if let success = dic[PLKeys.dinosaur.string] as? Bool {
                if success {
                    self.profileManager.resetProfileAndToken()
                    completion(error: nil)
                    return
                }
            }
            completion(error: error)
        }
    }
    
    func _sendPassword(email: String, completion: PLErrorCompletion) {
        let passService = PLAPIService.SendPassword
        let params = [PLKeys.email.string : email]
        PLNetworkManager.get(passService, parameters: params, completion: { (dic, error) in
            self.handleErrorCompletion(error, errorCompletion: completion, completion: { () -> NSError? in
                if let response = dic[PLKeys.response.string] as? [String : AnyObject] {
                    if let success = response[PLKeys.success.string] as? Bool {
                        if success {
                            completion(error: nil)
                            return nil
                        }
                        return PLError(domain: .User, type: kPLErrorTypeWrongEmail)
                    }
                }
                return kPLErrorUnknown
            })
        })
    }
    
    func _updateProfile(data: PLEditableUser, completion: PLErrorCompletion) {
        let params = data.params()
        let attachment = createAttachment(data.picture)
        PLNetworkManager.post(PLAPIService.UpdateProfile, parameters: params, attachment: attachment) { (dic, error) in
//            self.handleUserLogin(error, dic: dic, completion: completion)
        }
    }
    
    func _sendOrder(order: PLCheckoutOrder, completion: PLErrorCompletion) {
        let params = order.serialize()
        PLNetworkManager.post(PLAPIService.SendOrder, parameters: params) { (dic, error) in
            self.handleCheckoutOrder(error, dic: dic, completion: completion)
        }
    }
    
    func handleErrorCompletion(error: NSError?, errorCompletion: PLErrorCompletion, completion: () -> NSError? ) {
        if error != nil {
            errorCompletion(error: error)
        } else {
            if var error = completion() {
                if error.domain ==  PLErrorDomain.Unknown.string {
                    error = PLError(domain: .User, type: kPLErrorTypeBadResponse)
                }
                errorCompletion(error: error)
            }
        }
    }
    
    func handleUserLogin(error: NSError?, dic: [String:AnyObject], completion: PLErrorCompletion) {
        handleErrorCompletion(error, errorCompletion: completion) { () -> NSError? in
            if let response = dic[PLKeys.response.string] as? [String : AnyObject] {
                if let userDic = response[PLKeys.user.string] as? [String : AnyObject] {
                    let token = response[PLKeys.token.string] as? [String : AnyObject]
                    if self.profileManager.saveProfile(userDic) {
                        self.profileManager.saveToken(token)
                        completion(error: nil)
                        return nil
                    }
                }
            }
            return NSError(domain: PLErrorDomain.Unknown.string, code: 0, userInfo: nil)
        }
    }
    
    func handleCheckoutOrder(error: NSError?, dic: [String:AnyObject], completion: PLErrorCompletion) {
        self.handleErrorCompletion(error, errorCompletion: completion, completion: { () -> NSError? in
            if let response = dic[PLKeys.response.string] as? [String : AnyObject] {
                if let success = response[PLKeys.success.string] as? Bool {
                    if success {
                        completion(error: nil)
                        return nil
                    }
                    return PLError(domain: .User, type: kPLErrorTypeCheckoutFailed)
                }
            }
            return kPLErrorUnknown
        })
    }
    
    func _fetchNearRegion(size: CGSize, completion: PLLocationRegionCompletion) {
        locationManager.fetchNearRegion(size, completion: completion)
    }
    func _fetchNearRegion(completion: PLLocationRegionCompletion) {
        locationManager.fetchNearRegion(completion)
    }
}