//
//  PLOrderViewController.swift
//  Pals
//
//  Created by Maks Sergeychuk on 9/5/16.
//  Copyright © 2016 citirex. All rights reserved.
//

private let kStillHeaderIdentifier = "stillHeader"
private let kStickyHeaderIdentifier = "stickyHeader"
private let kCoverCellIdentifier = "coverCell"

private let kCheckoutButtonHeight: CGFloat = 74

enum PLOrderSection {
    case Covers
    case Drinks
}

class PLOrderViewController: PLViewController {
    
    @IBOutlet private var collectionView: UICollectionView!
    @IBOutlet private var bgImageView: UIImageView!
    
    var order = PLCheckoutOrder()
    
    private var drinksOffset = CGPointZero
    private var coversOffset = CGPointZero
    
    private var drinksDatasource = PLDrinksDatasource()
    private var coversDatasource = PLCoversDatasource()
    
    private var currentSection: PLOrderSection = .Drinks
    
    private var stillHeader: PLOrderStillHeader!
    private var stickyHeader: PLOrdeStickyHeader!
    
    private let animableVipView = UINib(nibName: "PLOrderAnimableVipView",
        bundle: nil).instantiateWithOwner(nil, options: nil)[0] as! PLOrderAnimableVipView
 
    private lazy var noItemsView: PLEmptyBackgroundView = {
        let emptyView = PLEmptyBackgroundView(topText: "No drinks", bottomText: nil)
        emptyView.hidden = true
        
        self.collectionView.addSubview(emptyView)
        emptyView.autoCenterInSuperview()
        return emptyView
    }()
    
    private var vipButton: UIBarButtonItem?
    private var checkoutButton = UIButton(frame: CGRectZero)
    private var checkoutButtonOnScreen = false
    
    private let placeholderUserName = "User"
    private let placeholderPlaceName = "Venue"
    
    private var sendPopup: PLOrderCheckoutPopupViewController?
    
    
    //MARK: - View lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        automaticallyAdjustsScrollViewInsets = false
        setupCheckoutButton()
        setupCollectionView()
    }
    
    override func viewWillAppear(animated: Bool) {
        PLNotifications.addObserver(self, selector: #selector(onDidSelectNewPlace(_:)), type: .PlaceDidSelect)
        PLNotifications.addObserver(self, selector: .sendButtonPressedNotification, type: .SendButtonPressed)
        
        super.viewWillAppear(animated)
        
        if currentSection == .Drinks {
            if !drinksDatasource.loading {
                loadDrinks()
            }
        } else {
            if !coversDatasource.loading {
                loadCovers()
            }
        }
        
        if navigationItem.titleView != animableVipView {
            navigationItem.titleView = animableVipView
        }
        
        navigationController?.navigationBar.barStyle     = .Black
        navigationController?.navigationBar.tintColor    = .whiteColor()
        navigationController?.navigationBar.translucent  = false
        navigationController?.navigationBar.barTintColor = order.isVIP ? .goldColor() : .affairColor()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        PLNotifications.removeObserver(self)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        if navigationItem.titleView != animableVipView {
            navigationItem.titleView = animableVipView
        }
        sendPopup?.show(from: tabBarController!)
    }

    func setNewPlace(place: PLPlace) {
        order.place = place
        updateDataForSelectedPlace()
    }
    
    
    // MARK: - Notifications
    
    func sendButtonPressedNotification(notification: NSNotification) {
        guard let object = notification.object as? PLFriendNotification else { return }
        order.user = object.friend
        switchSection(object.section)
    }
 
    func onDidSelectNewPlace(notification: NSNotification) {
        if let notifObj = notification.object as? PLPlaceEventNotification {
            let selectedPlace = notifObj.place
            
            // set a new place if only no place or selected another place
            if order.place == nil || order.place!.id != selectedPlace.id {
                setNewPlace(notifObj.place)
            }
            if let event = notifObj.event {
                order.appendCover(event)
                if currentSection != .Covers {
                    switchSection(.Covers)
                } else {
                    let visibleItems = collectionView.indexPathsForVisibleItems()
                    collectionView.reloadItemsAtIndexPaths(visibleItems)
                }
                updateCheckoutButtonState()
            }
        }
    }
}

//MARK: - Checkout behavior

extension PLOrderViewController {
    
    func cancelLoadingDatasources() {
        coversDatasource.cancel()
        drinksDatasource.cancel()
    }
    
    private func loadDrinks() {
        if order.place == nil {
            return
        }
        startActivityIndicator(.WhiteLarge)
        cancelLoadingDatasources()
        drinksDatasource.loadPage { [unowned self] indices, error in
            self.stopActivityIndicator()
            self.collectionViewInsertItems(indices, withError: error)
        }
    }
    
    private func loadCovers() {
        if order.place == nil {
            return
        }
        startActivityIndicator(.WhiteLarge)
        cancelLoadingDatasources()
        coversDatasource.loadPage { [unowned self] indices, error in
            self.stopActivityIndicator()
            self.collectionViewInsertItems(indices, withError: error)
        }
    }
    
    private func collectionViewInsertItems(indices: [NSIndexPath], withError error: NSError?) {
        guard error == nil else { return PLShowErrorAlert(error: error!) }
        if indices.count > 0 {
            noItemsView.hidden = true
            let newIndexPaths = indices.map({ NSIndexPath(forItem: $0.row, inSection: 1) })
            self.collectionView?.performBatchUpdates({
                self.collectionView?.insertItemsAtIndexPaths(newIndexPaths)
                }, completion: { (complete) in
            })
        } else {
            switch currentSection {
            case .Drinks:
                if drinksDatasource.pagesLoaded == 0 && order.place != nil {
                    noItemsView.setupTextLabels("No drinks", bottomText: nil)
                    noItemsView.hidden = false
                }
            case .Covers:
                if coversDatasource.pagesLoaded == 0 && order.place != nil {
                    noItemsView.setupTextLabels("No covers", bottomText: nil)
                    noItemsView.hidden = false
                }
            }
        }
    }
    
    //MARK: - Actions
    @objc private func vipButtonPressed(sender: UIBarButtonItem) {
        sender.image = order.isVIP ? UIImage(named: "sharp_crown") : UIImage(named: "Edit")
        
        stickyHeader.line.backgroundColor = order.isVIP ? .affairColor() : .goldColor()
        
//        stillHeader.backgroundColor = order.isVIP ? .affairColor() : .goldColor()
        
        order.isVIP = !order.isVIP
        performTransitionToVipState(order.isVIP)
    }
    
    private func restore() {
        order.isVIP = false
        bgImageView.image = UIImage(named: "order_bg")
        navigationItem.rightBarButtonItem = vipButton
        animableVipView.restoreToDefaultState()
    }
    
    private func performTransitionToVipState(isVIP: Bool) {
        isVIP ? animableVipView.animateVip() : animableVipView.restoreToDefaultState()
        
        bgImageView.image = isVIP ? UIImage(named: "order_bg_vip") : UIImage(named: "order_bg")
        navigationController?.navigationBar.barTintColor = isVIP ? .goldColor() : .affairColor()
        
        drinksDatasource.isVIP = order.isVIP
        coversDatasource.isVIP = order.isVIP
        if order.place != nil {
            order.clean()
            resetOffsets()
            resetDataSources()
            updateCheckoutButtonState()
            collectionView.reloadSections(NSIndexSet(index: 1))
            currentSection == .Drinks ? loadDrinks() : loadCovers()
        }
    }
    
    private func resetOffsets() {
        coversOffset = CGPointZero
        drinksOffset = CGPointZero
    }
    
    private func resetDataSources() {
        drinksDatasource.clean()
        coversDatasource.clean()
    }
    
    // MARK: - Navigation
    @IBAction private func backBarButtonItemTapped(sender: UIBarButtonItem) {
        dismiss(false)
    }
    
    func updateCheckoutButtonState() {
        let criteria = (order.drinkSetCount > 0 || order.coverSetCount > 0) && order.place != nil && order.user != nil
        criteria ? showCheckoutButton() : hideCheckoutButton()
    }
    
    private func showCheckoutButton() {
        if checkoutButtonOnScreen == false {
            checkoutButtonOnScreen = true
            checkoutButton.layer.removeAllAnimations()
            let originYFinish = view.bounds.size.height - kCheckoutButtonHeight + 10
            var frame = checkoutButton.frame
            frame.origin.y = collectionView.bounds.size.height
            checkoutButton.frame = frame
            checkoutButton.hidden = false
            frame.origin.y = originYFinish
            shiftCollectionView(true)
            
            UIView.animateWithDuration(0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.1, options: [UIViewAnimationOptions.BeginFromCurrentState, .AllowUserInteraction], animations: {
                self.checkoutButton.frame = frame
                }, completion: nil)
        }
    }
    
    private func hideCheckoutButton() {
        if checkoutButtonOnScreen == true {
            checkoutButtonOnScreen = false
            var frame = checkoutButton.frame
            frame.origin.y = collectionView.bounds.size.height
            shiftCollectionView(false)
            
            UIView.animateWithDuration(0.3, delay: 0, options: [.BeginFromCurrentState, .AllowUserInteraction, .CurveLinear], animations: {
                                        self.checkoutButton.frame = frame
                }, completion: { (completion) in
                    if completion == true {
                        self.checkoutButton.hidden = true
                    }
            })
        }
    }
    
    func shiftCollectionView(shift: Bool) {
        let newOffsetShift = collectionView.contentOffset.y
		if (UIScreen.mainScreen().bounds.height - navigationController!.navigationBar.frame.size.height - tabBarController!.tabBar.frame.size.height - collectionView.contentSize.height) <= kCheckoutButtonHeight {
				UIView.animateWithDuration(0.3, delay: 0, options: .BeginFromCurrentState, animations: {
				self.collectionView.contentOffset.y = shift ? newOffsetShift + kCheckoutButtonHeight : newOffsetShift - kCheckoutButtonHeight
				}) { (complete) in
				self.collectionView.contentInset.bottom = shift ? kCheckoutButtonHeight : 0
				}
		}
    }
    
    
    //MARK: - Send Button
    func checkoutButtonPressed(sender: UIButton) {
        guard order.user != nil else {
            checkoutButton.shake()
            return PLShowAlert("Need to chose user")
        }
        guard order.place != nil else {
            checkoutButton.shake()
            return PLShowAlert("Need to chose place")
        }
        
        let popup = PLOrderCheckoutPopupViewController(nibName: "PLOrderCheckoutPopupViewController", bundle: nil)
        popup.delegate = self
        popup.modalPresentationStyle = .OverCurrentContext
        popup.order = order
        popup.show(from: tabBarController!)
        sendPopup = popup
    }
    
    func sendCurrentOrder() {
        startActivityIndicator(.WhiteLarge)
        PLFacade.sendOrder(order) {[unowned self] (orders,error) in
            self.stopActivityIndicator()
            if error == nil {
                self.resetOrderState()
                self.updateProfileWithOrders(orders)
            } else {
                PLShowErrorAlert(error: error!)
            }
            self.sendPopup = nil
        }
    }
	
    private func resetOrderState() {
        self.order = PLCheckoutOrder()
        self.resetOffsets()
        self.performTransitionToVipState(false)
        self.resetDataSources()
        self.updateCheckoutButtonState()
        self.collectionView.reloadData()
    }
    
    private func updateProfileWithOrders(orders: [PLOrder]) {
        let myId = PLFacade.profile!.id
        var myOrders = [PLOrder]()
        for order in orders {
            if myId == order.user.id {
                myOrders.append(order)
			}
        }
        
        if myOrders.count > 0 {
            tabBarController?.switchTabBarItemTo(.ProfileItem, completion: { 
                PLNotifications.postNotification(.OrdersDidCreate, object: myOrders)
            })
        } else {
            PLShowAlert("Success")
        }
    }
}

extension PLOrderViewController : PLCardInfoViewControllerDelegate {
    func cardInfoViewControllerDidAddPaymentInfo(vc: PLCardInfoViewController) {
        sendPopup = nil
        sendCurrentOrder()
    }
}

extension PLOrderViewController : PLOrderHeaderDelegate {
    func orderHeader(header: PLOrdeStickyHeader, didChangeSection section: PLOrderSection) {
        switchSection(section)
    }
}

//MARK: - Order items delegate, Tab changed delegate
extension PLOrderViewController: OrderHeaderBehaviourDelegate, CheckoutOrderPopupDelegate{
    
    //MARK: Cnange user
    func userNamePressed(sender: AnyObject) {
        guard let friendsViewController = UIStoryboard.friendsViewController() else { return }
        friendsViewController.delegate = self
        navigationController?.pushViewController(friendsViewController, animated: true)
    }

    //MARK: Cnange place
    func placeNamePressed(sender: AnyObject) {
        guard let placesViewController = UIStoryboard.placesViewController() else { return }
        placesViewController.delegate = self
        navigationController?.pushViewController(placesViewController, animated: true)
    }

    func updateDataForSelectedPlace() {
        resetOffsets()
        order.clean()
        updateCheckoutButtonState()
        if collectionView != nil {
            collectionView.reloadData()
        }
        drinksDatasource.placeId = order.place!.id
        coversDatasource.placeId = order.place!.id
        currentSection == .Drinks ? loadDrinks() : loadCovers()
    }
    
    //MARK: Order change tab
    func switchSection(section: PLOrderSection) {
        noItemsView.hidden = true
        stopActivityIndicator()
        cancelLoadingDatasources()
        switch currentSection {
        case .Drinks:
            drinksOffset = collectionView.contentOffset
            if coversDatasource.pagesLoaded < 1 && order.place != nil {
                loadCovers()
            }
        case .Covers:
            coversOffset = collectionView.contentOffset
            if drinksDatasource.pagesLoaded < 1 && order.place != nil {
                loadDrinks()
            }
        }
        
        currentSection = section
        collectionView.contentOffset = currentSection == .Drinks ? drinksOffset : coversOffset
        collectionView.reloadData()
    }
    
    //MARK: - Send Popup
    func orderPopupCancelClicked(popup: PLOrderCheckoutPopupViewController) {
        popup.hide()
        sendPopup = nil
    }
    
    func orderPopupSendClicked(popup: PLOrderCheckoutPopupViewController) {
        popup.hide()
        if PLFacade.profile!.hasPaymentCard == false {
            if let addPaymentCardVC = UIStoryboard.viewControllerWithType(.CardInfo) as? PLCardInfoViewController {
                addPaymentCardVC.delegate = self
                navigationController?.pushViewController(addPaymentCardVC, animated: true)
                return
            }
        }
        sendCurrentOrder()
    }
    
    //MARK: - Setup
    func setupCollectionView() {
        animableVipView.frame = PLOrderAnimableVipView.suggestedFrame
        
        vipButton = UIBarButtonItem(image: UIImage(named: "sharp_crown"), style: .Plain, target: self, action: #selector(vipButtonPressed(_:)))
        
        navigationItem.rightBarButtonItem = vipButton
        
        collectionView.registerNib(UINib(nibName: "PLOrderStillHeader", bundle: nil), forSupplementaryViewOfKind: UICollectionElementKindSectionHeader, withReuseIdentifier: kStillHeaderIdentifier)
        collectionView.registerNib(UINib(nibName: "PLOrdeStickyHeader", bundle: nil), forSupplementaryViewOfKind: UICollectionElementKindSectionHeader, withReuseIdentifier: kStickyHeaderIdentifier)
        collectionView.registerNib(UINib(nibName: PLOrderDrinkCell.nibName, bundle: nil), forCellWithReuseIdentifier: PLOrderDrinkCell.reuseIdentifier)
        collectionView.registerNib(UINib(nibName: "PLOrderCoverCell", bundle: nil), forCellWithReuseIdentifier: kCoverCellIdentifier)
    }
    
    func setupCheckoutButton() {
        checkoutButton.frame = CGRectMake(0,0,view.bounds.size.width, kCheckoutButtonHeight)
        checkoutButton.setTitle("Send", forState: .Normal)
        checkoutButton.backgroundColor = UIColor(red:0.25, green:0.57, blue:0.42, alpha:1.0)
        checkoutButton.setTitleColor(.whiteColor(), forState: .Normal)
        checkoutButton.titleLabel?.font = .systemFontOfSize(24)
        checkoutButton.round([.TopLeft, .TopRight], radius: 10)
        checkoutButton.hidden = true
        view.addSubview(checkoutButton)
        checkoutButton.addTarget(self, action: .checkoutPressed, forControlEvents: .TouchUpInside)
    }
    
    
}


//MARK: - CollectionView dataSource
extension PLOrderViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if UIDevice.SYSTEM_VERSION_LESS_THAN("9.0") {
            self.collectionView.collectionViewLayout.invalidateLayout()
        }
        
        if section == 1 {
            switch currentSection {
            case .Drinks:
                return drinksDatasource.count
            case .Covers:
                return coversDatasource.count
            }
        }
        return 0
    }
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 2
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let identifier = currentSection == .Drinks ? PLOrderDrinkCell.reuseIdentifier : kCoverCellIdentifier
        let dequeuedCell = collectionView.dequeueReusableCellWithReuseIdentifier(identifier, forIndexPath: indexPath)
        
        switch currentSection {
        case .Drinks:
            let cell = dequeuedCell as! PLOrderDrinkCell
            let drink = drinksDatasource[indexPath.row]
            cell.drink = drink
            cell.delegate = self
            updateDrinkCount(drink, inCell: cell)
            return cell
        case .Covers:
            let cell = dequeuedCell as! PLOrderCoverCell
            let cover = coversDatasource[indexPath.row]
            cell.event = cover
            cell.delegate = self
            updateCoverCount(cover, inCell: cell)
            return cell
        }
    }
    
    func updateDrinkCount(drink: PLDrink, inCell cell: PLOrderDrinkCell) {
        cell.drinkCount = 0
        if let item = order.itemById(drink.id, inSection: .Drinks) {
            cell.drinkCount = item.quantity
        }
    }
    
    
    func updateCoverCount(cover: PLEvent, inCell cell: PLOrderCoverCell) {
        cell.coverNumber = 0
        if let item = order.itemById(cover.id, inSection: .Covers) {
            cell.coverNumber = item.quantity
        }
    }
    
    func collectionView(collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionReusableView {
        if indexPath.section == 0 {
            
            stillHeader = collectionView.dequeueReusableSupplementaryViewOfKind(UICollectionElementKindSectionHeader, withReuseIdentifier: kStillHeaderIdentifier, forIndexPath: indexPath) as! PLOrderStillHeader
            stillHeader.delegate = self
            stillHeader.userName = order.user?.name ?? placeholderUserName
            stillHeader.placeName = order.place?.name ?? placeholderPlaceName
            return stillHeader
        } else {
            
            stickyHeader = collectionView.dequeueReusableSupplementaryViewOfKind(UICollectionElementKindSectionHeader, withReuseIdentifier: kStickyHeaderIdentifier, forIndexPath: indexPath) as! PLOrdeStickyHeader
            stickyHeader.delegate = self
            stickyHeader.currentSection = currentSection
            stickyHeader.line.backgroundColor = order.isVIP ? .goldColor() : .affairColor()
            return stickyHeader
        }
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        let height = (section == 0) ? PLOrderStillHeader.height : PLOrdeStickyHeader.height
        return CGSizeMake(collectionView.bounds.size.width, height)
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        let height = currentSection == .Drinks ? PLOrderDrinkCell.height : PLOrderCoverCell.height
        return CGSizeMake(collectionView.bounds.size.width, height)
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAtIndex section: Int) -> CGFloat {
        return 0
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAtIndex section: Int) -> CGFloat {
        return 0
    }
    
    func collectionView(collectionView: UICollectionView, willDisplayCell cell: UICollectionViewCell, forItemAtIndexPath indexPath: NSIndexPath) {
        switch currentSection {
        case .Drinks: if drinksDatasource.shouldLoadNextPage(indexPath) { loadDrinks() }
        case .Covers: if coversDatasource.shouldLoadNextPage(indexPath) { loadCovers() }
        }
    }
}


// MARK: - PLOrderDrinkCellDelegate

extension PLOrderViewController: PLOrderDrinkCellDelegate {
    
    func drinkCell(cell: PLOrderDrinkCell, didUpdateDrink drink: PLDrink, withCount count: UInt) {
        order.updateWithDrink(drink, andCount: count)
        updateCheckoutButtonState()
    }
    
}


extension PLOrderViewController : PLCoverCellDelegate {
    func coverCell(cell: PLOrderCoverCell, didUpdateCover event: PLEvent, withCount count: UInt) {
        order.updateWithCover(event, andCount: count)
        updateCheckoutButtonState()
    }
}


// MARK: - PLPlacesViewControllerDelegate

extension PLOrderViewController: PLPlacesViewControllerDelegate {
    
    func didSelectPlace(controller: PLPlacesViewController, place: PLPlace) {
        setNewPlace(place)
        controller.navigationController?.popViewControllerAnimated(true)
    }
    
}


// MARK: - PLFriendsViewControllerDelegate

extension PLOrderViewController: PLFriendsViewControllerDelegate {
    
    func didSelectFriend(controller: PLFriendsViewController, friend: PLUser) {
        order.user = friend
        collectionView.reloadSections(NSIndexSet(index: 0))
        controller.navigationController?.popViewControllerAnimated(true)
        updateCheckoutButtonState()
    }
    
}


