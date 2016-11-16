//
//  PLOrderCardCell.swift
//  Pals
//
//  Created by ruckef on 16.11.16.
//  Copyright © 2016 citirex. All rights reserved.
//

enum PLCardType {
    case Beer
    case Liquor
    case Cover
    case VIP
    case My
    case Unknown
    var color: UIColor {
        switch self {
        case .Beer:
            return UIColor(r: 0, g: 153, b: 158)
        case .Liquor:
            return UIColor(r: 50, g: 44, b: 88)
        case .Cover:
            return UIColor(r: 100, g: 66, b: 147)
        case .VIP:
            return UIColor(r: 193, g: 61, b: 61)
        case .My:
            return UIColor(r: 130, g: 48, b: 81)
        case .Unknown:
            return UIColor(r: 102, g: 102, b: 255)
        }
    }
}

extension PLOrder {
    var cardType: PLCardType {
        if let myProfile = PLFacade.profile {
            if user.id == myProfile.id {
                return .My
            }
        }
        
        if isVIP {
            return .VIP
        }
        
        if coverSets.count > 0 {
            return .Cover
        }
        
        if drinkSets.count > 0 {
            let fistDrinkType = drinkSets.first!.item.type
            if fistDrinkType == .Strong {
                return .Liquor
            } else {
                return .Beer
            }
        }
        return .Unknown
    }
}

enum PLCardMode : Int {
    case List
    case Scan
}

class PLOrderCardCell: UICollectionViewCell {

    @IBOutlet var underlay: UIView!
    @IBOutlet var headerView: UIView!
    @IBOutlet var placeTitleLabel: UILabel!
    @IBOutlet var musicGenresLabel: UILabel!
    @IBOutlet var cardModeButton: UIButton!
    
    private lazy var listContainerView: PLOrderCardListView = PLOrderCardListView()
    private lazy var scanContainerView: PLOrderCardScanView = PLOrderCardScanView()
    private var currentContainer: UIView?
    
    
    var mode: PLCardMode = .List {
        didSet {
            var iconName = ""
            var container: UIView!
            switch mode {
            case .List:
                iconName = "qr_icon"
                container = listContainerView
            case .Scan:
                iconName = "list_icon"
                container = scanContainerView
            }
            cardModeButton.setBackgroundImage(UIImage(named: iconName), forState: .Normal)
            showContainer(container)
        }
    }
    
    func showContainer(view: UIView) {
        currentContainer?.removeFromSuperview()
        underlay.addSubview(view)
        let views = ["header" : headerView, "view" : view]
        let strings = ["|-0-[view]-0-|", "V:[header]-0-[view]-0-|"]
        underlay.addConstraints(strings, views: views)
        currentContainer = view
        if var aContainer = view as? PLOrderContainable {
            aContainer.order = order
        }
        
    }
    
    var order: PLOrder? {
        didSet {
            if let o = order {
                placeTitleLabel.text = o.place.name
                musicGenresLabel.text = o.place.musicGengres
                headerView.backgroundColor = o.cardType.color
            } else {
                placeTitleLabel.text = "<Error>"
                musicGenresLabel.text = "<Error>"
                headerView.backgroundColor = PLCardType.Unknown.color
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // add shadow
        contentView.layer.shadowColor = UIColor.blackColor().CGColor
        contentView.layer.shadowOffset = CGSizeMake(0.0, 5.0)
        contentView.layer.shadowOpacity = 0.9
        contentView.layer.shadowRadius = 7
        scanContainerView.translatesAutoresizingMaskIntoConstraints = false
        listContainerView.translatesAutoresizingMaskIntoConstraints = false
        showContainer(listContainerView)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.layer.shadowPath = UIBezierPath(rect: bounds).CGPath
        // round top corners
        var myBounds = bounds
        myBounds.size.width = UIScreen.mainScreen().bounds.size.width
        let path = UIBezierPath(roundedRect: myBounds, byRoundingCorners: [.TopLeft,.TopRight], cornerRadii: CGSize(width: 20, height: 20))
        let mask = CAShapeLayer()
        mask.path = path.CGPath
        underlay.layer.mask = mask
    }
    
    func onCardDidSelect(selected: Bool) {
        cardModeButton.enabled = selected
    }
    
    @IBAction func switchModeButtonClicked() {
        mode = (mode != .List) ? .List : .Scan
    }
}

extension PLOrderCardCell : PLReusableCell {
    static func identifier() -> String {
        return "PLOrderCardCell"
    }
    static func nibName() -> String {
        return "PLOrderCardCell"
    }
}
