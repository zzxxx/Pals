//
//  PLLoginViewController.swift
//  Pals
//
//  Created by ruckef on 31.08.16.
//  Copyright © 2016 citirex. All rights reserved.
//

class PLLoginViewController: PLViewController {

	@IBOutlet weak var logoImage:  PLCircularImageView!
	@IBOutlet weak var loginTextField: PLFormTextField!
	@IBOutlet weak var passTextField:  PLFormTextField!
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        hideKeyboardWhenTapped = true
    }
    
    
    // MARK: - Private Methods
		
	private func loginToMainScreen() {
        var userName = ""
        var password = ""
        if loginTextField.text!.isEmpty && passTextField.text!.isEmpty {
            if let defaultUser = PLFacade.instance.settingsManager.defaultUser {
                userName = defaultUser.login
                password = defaultUser.password
            }
        } else {
            userName = loginTextField.text!
            password = passTextField.text!
        }

		if userName.isEmpty      { PLShowAlert("Login error!", message: "Please enter your login.") }
        else if password.isEmpty { PLShowAlert("Login error!", message: "Please enter your password.") }
        else {
            startActivityIndicator(.WhiteLarge)
            view.userInteractionEnabled = false
			PLFacade.login(userName, password: password, completion: { error in
                self.stopActivityIndicator()
                self.view.userInteractionEnabled = true
                
                guard error == nil else { return PLShowAlert("Login error!", message: (error?.localizedDescription)!) }
                self.showMainScreen()
			})
		}
	}
	
	private func showMainScreen() {
		let tabBarController = UIStoryboard.tabBarController()!
		present(tabBarController, animated: true)
	}
    
    private func getAccessCodeBy(email: String) {
        self.startActivityIndicator(.WhiteLarge)
        PLFacade.forgotPassword(email, completion: { [unowned self] error in
            self.stopActivityIndicator()
            guard error == nil else { return PLShowAlert("", message: "This email does not exist!") }
            
            PLShowAlert("", message: "A new generated password has been sent to your email.", completion: {
                let resetPasswordViewController = UIStoryboard.resetPasswordViewController()!
                resetPasswordViewController.email = email
                self.present(resetPasswordViewController, animated: true)
            })
        })
    }

}


// MARK: - UITextFieldDelegate

extension PLLoginViewController: UITextFieldDelegate {
    
    func textFieldDidBeginEditing(textField: UITextField) {
        textField.keyboardDistanceFromTextField = 40.0
    }
	
	func textFieldShouldReturn(textField: UITextField) -> Bool {
		let nextTag = textField.tag + 1
		if let nextResponder = textField.superview!.viewWithTag(nextTag) {
			nextResponder.becomeFirstResponder()
		} else {
			textField.resignFirstResponder()
			loginToMainScreen()
		}
		return false
	}
	
}


// MARK: - Actions

extension PLLoginViewController {

    @IBAction func tappedLoginButton(sender: UIButton) {
        loginToMainScreen()
    }
    
    @IBAction func tappedForgotButton(sender: UIButton) {
        dismissKeyboard(sender)
        
        let alert = UIAlertController(title: "We got your back!",
                                      message: "Enter below and we'll send your password!",
                                      preferredStyle: .Alert)
        
        let forgotAction = UIAlertAction(title: "OK", style: .Default, handler: { [unowned self] action in
            if let emailTextField = alert.textFields!.first where emailTextField.text!.trim().isValidEmail {
                self.getAccessCodeBy(emailTextField.text!)
            } else {
                PLShowAlert("Please, enter a valid user email.")
            }
        })
        forgotAction.enabled = false
        
        alert.addAction(forgotAction)
        alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        alert.addTextFieldWithConfigurationHandler { textField in
            textField.keyboardType = .EmailAddress
            textField.placeholder  = "Email"
            
            NSNotificationCenter.defaultCenter().addObserverForName(UITextFieldTextDidChangeNotification,
            object: textField, queue: .mainQueue()) { notification in
                forgotAction.enabled = !textField.text!.isEmpty
            }
        }
        present(alert, animated: true)
    }
    
    //FB
    @IBAction func facebookLoginButtonPressed(sender: UIButton) {
        startActivityIndicator(.WhiteLarge)
        PLFacade.loginFB { [unowned self] error in
            self.stopActivityIndicator()
            if error == nil {
                self.showMainScreen()
            } else {
                PLShowErrorAlert(error: error!)
            }
        }
    }
    
    // MARK: - Navigation
    
    @IBAction func unwindToLoginScreen(sender: UIStoryboardSegue) {
    }

}
