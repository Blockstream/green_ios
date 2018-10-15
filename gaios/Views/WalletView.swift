//
// WalletView.swift
//  gaios
//
//  Created by Strahinja Markovic on 7/15/18.
//  Copyright © 2018 Blockstream inc. All rights reserved.
//

import UIKit
import Foundation
import PromiseKit
/**
 The WalletView class manages an ordered collection of card view and presents them.
 */
open class WalletView: UIView, UITableViewDelegate, UITableViewDataSource {

    var items = [TransactionItem]()
    var delegate: WalletViewDelegate?
    var presentingWallet: WalletItem? = nil

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 65
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "transactionCell", for: indexPath) as! TransactionTableCell
        let item: TransactionItem = items.reversed()[indexPath.row]
        cell.amount.text = item.amount
        if(item.type == "incoming" || item.type == "redeposit") {
            cell.address.text = presentingWallet?.name
            cell.amount.textColor = UIColor.customMatrixGreen()
        } else {
            cell.address.text = item.address
            cell.amount.textColor = UIColor.white
        }
        if(item.blockheight == 0) {
            cell.status.text = "unconfirmed"
            cell.status.textColor = UIColor.red
        } else if (AccountStore.shared.getBlockheight() - item.blockheight < 6) {
            let confirmCount = AccountStore.shared.getBlockheight() - item.blockheight + 1
            cell.status.text = String(format: "(%d/6)", confirmCount)
            cell.status.textColor = UIColor.red
        } else {
            cell.status.text = "completed"
            cell.status.textColor = UIColor.customTitaniumLight()
        }
        cell.selectionStyle = .none
        cell.date.text = item.date
        cell.separatorInset = UIEdgeInsetsMake(0, 0, 0, 0)
        return cell;
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item: TransactionItem = items.reversed()[indexPath.row]
        delegate?.showTransaction(tx: item)
    }

    
    // MARK: Public methods

    /**
     Initializes and returns a newly allocated wallet view object with the specified frame rectangle.
     
     - parameter aRect: The frame rectangle for the wallet view, measured in points.
     - returns: An initialized wallet view.
     */
    override public init(frame: CGRect) {
        super.init(frame: frame)
        prepareWalletView()
        addObservers()
    }
    
    /**
     Returns a wallet view object initialized from data in a given unarchiver.
     
     - parameter aDecoder: An unarchiver object.
     - returns: A wallet view, initialized using the data in decoder.
     */
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepareWalletView()
        addObservers()
    }
    
    
    /**
     Reloads the wallet view with card views.
     
     - parameter cardViews: Card views to be inserted to the wallet view.
     */
    open func reload(cardViews: [CardView]) {
        
        insert(cardViews: cardViews)
        calculateLayoutValues()
        
    }
    
    func updateViewModel(account: Int) {
        items.removeAll(keepingCapacity: true)
        wrap {
            try getSession().getTransactions(subaccount: UInt32(account), page: 0)
        }.done { (transactions: [String : Any]?) in
            let list = transactions!["list"] as! NSArray
            for tx in list.reversed() {
                print(tx)
                let transaction = tx as! [String : Any]
                let satoshi:Int = transaction["satoshi"] as! Int
                let hash = transaction["txhash"] as! String
                let fee = transaction["fee"] as! UInt32
                let size = transaction["transaction_vsize"] as! UInt32
                let blockheight = transaction["block_height"] as! UInt32
                let memo = transaction["memo"] as! String

                let dateString = transaction["created_at"] as! String
                let type = transaction["type"] as! String
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .short
                let date = Date.dateFromString(dateString: dateString)
                let btcFormatted = String.satoshiToBTC(satoshi: satoshi)
                let formattedBalance: String = String(format: "%@ %@", btcFormatted, SettingsStore.shared.getDenominationSettings())
                let adressees = transaction["addressees"] as! [String]
                var counterparty = ""
                if (adressees.count > 0) {
                    counterparty = adressees[0]
                }
                let formatedTransactionDate = Date.dayMonthYear(date: date)
                //self.items.append(TransactionItem(timestamp: dateString, address: counterparty, amount: formattedBalance, fiatAmount: "", date: formatedTransactionDate, btc: Double(satoshi), type: type, ))
                let item = TransactionItem(timestamp: dateString, address: counterparty, amount: formattedBalance, fiatAmount: "", date: formatedTransactionDate, btc: Double(satoshi), type: type, hash: hash, blockheight: blockheight, fee: fee, size: size, memo: memo, dateRaw: date)
                self.items.append(item)
            }
            print("success")
        }.ensure {
            self.transactionTableView.reloadData()
        }.catch { error in
            print("error")
        }
    }

    /**
     Presents a card view.
     
     - parameter cardView: A card view to be presented.
     - parameter animated: If true, the view is being added to the wallet view using an animation.
     - parameter completion: A block object to be executed when the animation sequence ends.
     */
    open func present(cardView: CardView, animated: Bool, completion: LayoutCompletion? = nil) {
        let walletView = cardView as! ColoredCardView
        self.presentingWallet = walletView.wallet
        updateViewModel(account: Int((walletView.wallet?.pointer)!))
        delegate?.cardViewPresented(cardView: cardView)
        present(cardView: cardView, animated: animated, animationDuration: animated ? WalletView.presentingAnimationSpeed : nil, completion: completion)
        
    }
    
    
    /**
     Dismisses the card view that was presented by the wallet view.
     
     - parameter animated: If true, the view is being removed from the wallet view using an animation.
     - parameter completion: A block object to be executed when the animation sequence ends.
     */
    open func dismissPresentedCardView(animated: Bool, completion: LayoutCompletion? = nil) {
        dissmissFooter {
            guard self.presentedCardView != nil else {
                return
            }
            self.delegate?.cardViewDismissed(cardView: self.presentedCardView!)
            self.dismissPresentedCardView(animated: animated, animationDuration: animated ? WalletView.dismissingAnimationSpeed : nil, completion: completion)
        }
    }
    
    
    /**
     Inserts a card view to the beginning of the receiver’s list of card views.
     
     - parameter cardView: A card view to be inserted.
     - parameter animated: If true, the view is being added to the wallet view using an animation.
     - parameter presented: If true, the view is being added to the wallet view and presented right way.
     - parameter completion: A block object to be executed when the animation sequence ends.

     */
    open func insert(cardView: CardView, animated: Bool = false, presented: Bool = false,  completion: InsertionCompletion? = nil) {
        
        presentedCardView = presented ? cardView : self.presentedCardView
        
        if animated {
            
            let y = scrollView.convert(CGPoint(x: 0, y: frame.maxY), from: self).y
            cardView.frame = CGRect(x: 0, y: y, width: frame.width, height: cardViewHeight)
            cardView.layoutIfNeeded()
            scrollView.insertSubview(cardView, at: 0)
            
            UIView.animateKeyframes(withDuration: WalletView.insertionAnimationSpeed, delay: 0, options: [.beginFromCurrentState, .calculationModeCubic], animations: { [weak self] in
                
                UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 1.0, animations: {
                    self?.insert(cardViews: [cardView] + (self?.insertedCardViews ?? []))
                    self?.layoutWalletView(placeVisibleCardViews: false)
                })
                
                }, completion: { [weak self] (_) in
                    self?.reload(cardViews: self?.insertedCardViews ?? [])
                    completion?()
            })
            
            
        } else {
            reload(cardViews: [cardView] + insertedCardViews)
            placeVisibleCardViews()
            completion?()
        }
        
    }
    
    /**
     Removes the specified card view from the wallet view.
     
     - parameter cardView: A card view to be removed.
     - parameter animated: If true, the view is being remove from the wallet view using an animation.
     - parameter completion: A block object to be executed when the animation sequence ends.
     
     */
    open func remove(cardView: CardView, animated: Bool = false,  completion: RemovalCompletion? = nil) {
        
        if animated {
            
            let removalBlock = removalAnimation()
            present(cardView: cardView, animated: true, completion: { [weak self] (_) in
                self?.presentedCardView = nil
                removalBlock(cardView, completion)
            })
            
        } else {
            remove(cardViews: [cardView])
            completion?()
        }
        
    }
    
    /**
     Removes the specified card views from the wallet view.
     
     - parameter cardViews: Card views to be removed.
     
     */
    open func remove(cardViews: [CardView]) {
        
        for view in cardViews {
            view.removeFromSuperview()
        }

        let newInsertedCardViews = insertedCardViews.filter { !cardViews.contains($0) }
        
        if let presentedCardView = presentedCardView, !newInsertedCardViews.contains(presentedCardView) {
            self.presentedCardView = nil
        }
        
        if newInsertedCardViews.count == 1 {
            presentedCardView = newInsertedCardViews.first
        }
        
        reload(cardViews: newInsertedCardViews)
    }
    
    /** The desirable card view height value. Used when the wallet view has enough space. */
    public var preferableCardViewHeight: CGFloat = .greatestFiniteMagnitude { didSet { calculateLayoutValues() } }
    
    /** Number of card views to show in the bottom of the wallet view when presenting card view. */
    public var maximimNumberOfCollapsedCardViewsToShow: Int = 5 { didSet { calculateLayoutValues() } }
    
    /** The positioning of card views relative to each other when the wallet view is not presenting a card view. */
    public var minimalDistanceBetweenStackedCardViews: CGFloat = 52 { didSet { calculateLayoutValues() } }
    
    /** The positioning of card views relative to each other when the wallet view is presenting a card view. */
    public var minimalDistanceBetweenCollapsedCardViews: CGFloat = 8 { didSet { calculateLayoutValues() } }
    
    /** The positioning of card views relative to the receiver’s presenting card view. */
    public var distanceBetweetCollapsedAndPresentedCardViews: CGFloat = 10 { didSet { calculateLayoutValues() } }
    
    /** The pop up offset of a card view when a long tap detected. */
    public var grabPopupOffset: CGFloat = 20 { didSet { calculateLayoutValues() } }
    
    /** The total duration of the animations when the card view is being presented. */
    public static var presentingAnimationSpeed: TimeInterval = 0.35
    
    /** The total duration of the animations when the card view is being dismissed. */
    public static var dismissingAnimationSpeed: TimeInterval = 0.35
    
    /** The total duration of the animations when the card view is being insertred. */
    public static var insertionAnimationSpeed: TimeInterval = 0.6
    
    /** The total duration of the animations when the card view is being removed. */
    public static var removalAnimationSpeed: TimeInterval = 1.0
    
    /** The total duration of the animations when the card view is being grabbed. */
    public static var grabbingAnimationSpeed: TimeInterval = 0.2
    
    /** This block is called after the receiver’s card view is presented or dimissed. */
    public var didUpdatePresentedCardViewBlock: PresentedCardViewDidUpdateBlock?

    /** Returns an accessory view that is displayed above the wallet view. */
    @IBOutlet public weak var walletHeader: UIView? {
        willSet {
            if let walletHeader = newValue {
                scrollView.addSubview(walletHeader)
            }
        }
        didSet {
            oldValue?.removeFromSuperview()
            calculateLayoutValues()
        }
    }
    
    
    /** The card view that is presented by this wallet view. */
    public var presentedCardView: CardView? {
        
        didSet {
            oldValue?.presented = false
            presentedCardView?.presented = true
            didUpdatePresentedCardViewBlock?(presentedCardView)
        }
        
    }
    var presentedFooterView: cardFooter = cardFooter.nibForClass()
    var transactionTableView: UITableView = UITableView()
    
    /** The receiver’s immediate card views. */
    public var insertedCardViews = [CardView]()    {
        didSet {
            calculateLayoutValues(shouldLayoutWalletView: false)
        }
    }

    func updateBalance(forCardview: Int, sat: String) {
        for index in 0..<insertedCardViews.count {
            let wallet = insertedCardViews[index] as! ColoredCardView
            if(wallet.wallet?.pointer == UInt32(forCardview)) {
                let denomination = SettingsStore.shared.getDenominationSettings()
                let balance = String.satoshiToBTC(satoshi: sat)
                wallet.balanceLabel.text = String(format: "%@ %@", balance, denomination)
                return
            }
        }
    }

    func updateWallet(forCardview: Int) {
        for index in 0..<insertedCardViews.count {
            let wallet = insertedCardViews[index] as! ColoredCardView
            if(wallet.wallet?.pointer == UInt32(forCardview)) {
                wallet.addressLabel.text = wallet.wallet?.address
                let uri = bip21Helper.btcURIforAddress(address: (wallet.wallet?.address)!)
                wallet.QRImageView.image = QRImageGenerator.imageForTextDark(text: uri, frame: wallet.QRImageView.frame)
            }
        }
    }

    /** The distance that the wallet view is inset from the enclosing scroll view. */
    public var contentInset: UIEdgeInsets {
        set {
            scrollView.contentInset = newValue
            calculateLayoutValues()
        }
        get {
            return scrollView.contentInset
        }
    }
    
    public typealias PresentedCardViewDidUpdateBlock    = (CardView?) -> ()
    
    public typealias LayoutCompletion                   = (Bool) -> ()
    public typealias InsertionCompletion                = () -> ()
    public typealias RemovalCompletion                  = () -> ()
    
    /**
     Informs the observing object when the value at the specified key path relative to the observed object has changed.
     
     - parameter keyPath: The key path, relative to object, to the value that has changed.
     - parameter object: The source object of the key path keyPath.
     - parameter change: A dictionary that describes the changes that have been made to the value of the property at the key path keyPath relative to object. Entries are described in Change Dictionary Keys.
     - parameter context: The value that was provided when the observer was registered to receive key-value observation notifications.
     */
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if context == observerContext {
            
            if keyPath == #keyPath(UIScrollView.bounds) {
                layoutWalletView()
            } else if keyPath == #keyPath(UIScrollView.frame) {
                calculateLayoutValues()
            }
            
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    // MARK: Private methods
    
    private let observerContext = UnsafeMutableRawPointer.allocate(bytes: 4, alignedTo: 1)
    
    deinit {
        scrollView.removeObserver(self, forKeyPath: #keyPath(UIScrollView.frame))
        scrollView.removeObserver(self, forKeyPath: #keyPath(UIScrollView.bounds))
        observerContext.deallocate(bytes: 4, alignedTo: 1)
    }
    
    
    func addObservers() {
        
        let options: NSKeyValueObservingOptions = [.new, .old, .initial]
        
        scrollView.addObserver(self, forKeyPath: #keyPath(UIScrollView.frame), options: options, context: observerContext)
        scrollView.addObserver(self, forKeyPath: #keyPath(UIScrollView.bounds), options: options, context: observerContext)
    }
    
    func prepareScrollView() {
        
        addSubview(scrollView)
        
        scrollView.clipsToBounds = false
        
        scrollView.isExclusiveTouch = true
        scrollView.alwaysBounceVertical = true
        
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        
        scrollView.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleHeight, .flexibleWidth]
        scrollView.frame = bounds
        
        
    }
    
    func prepareWalletHeaderView() {
        
        let walletHeader = UILabel(frame: CGRect(x: 0, y: 0, width: 100, height: 44))
        
        walletHeader.textAlignment = .center
        walletHeader.text = "Wallet"
        
        self.walletHeader = walletHeader
    }
    
    let scrollView = UIScrollView()

    func prepareWalletView() {
        
        prepareScrollView()
        let nib = UINib(nibName: "TransactionCell", bundle: nil)
        transactionTableView.delegate = self
        transactionTableView.dataSource = self
        transactionTableView.tableFooterView = UIView()
        transactionTableView.register(nib, forCellReuseIdentifier: "transactionCell")
        transactionTableView.allowsSelection = true
        transactionTableView.isUserInteractionEnabled = true
        transactionTableView.separatorColor = UIColor.customTitaniumLight()
        //prepareWalletHeaderView()
        
    }
    
    func insert(cardViews: [CardView]) {
        
        self.insertedCardViews = cardViews
        
    }
    
    func present(cardView: CardView, animated: Bool, animationDuration: TimeInterval?, completion: LayoutCompletion? = nil) {

        if cardView == presentedCardView {

            completion?(true)
            return
            
        } else if presentedCardView != nil {
            
            dismissPresentedCardView(animated: animated, completion: nil)
            present(cardView: cardView, animated: animated, completion: completion)
            
        } else {
            
            presentedCardView = cardView
            self.bringSubview(toFront: presentedCardView!)
            layoutWalletView(animationDuration: animated ? animationDuration : nil, placeVisibleCardViews: false, completion: { [weak self] (_) in
                self?.placeVisibleCardViews()
                self?.presentFooter()
                completion?(true)
            })
            
        }
        
    }
    
    func dismissPresentedCardView(animated: Bool, animationDuration: TimeInterval?, completion: LayoutCompletion? = nil) {
        
        if insertedCardViews.count <= 0 || presentedCardView == nil {
            completion?(true)
            return
        }
        
        presentedCardView = nil
        layoutWalletView(animationDuration: animated ? animationDuration : nil, placeVisibleCardViews: true, completion: { [weak self] (_) in
            self?.calculateLayoutValues()
            completion?(true)
        })
    }
    
    typealias RemovalAnimation = (CardView, RemovalCompletion?) -> ()
    func removalAnimation() -> RemovalAnimation {
        
        return { [weak self] (cardView: CardView,  completion: RemovalCompletion?) in
            
            guard let strongSelf = self else {
                return
            }
            
            let removalSuperview = UIView()
            
            removalSuperview.clipsToBounds = true
            
            let overlay = UIView()
            overlay.backgroundColor = .red
            
            self?.addSubview(removalSuperview)
            removalSuperview.addSubview(overlay)
            removalSuperview.addSubview(cardView)
            
            removalSuperview.frame = strongSelf.scrollView.convert(cardView.frame, to: self)
            cardView.frame = removalSuperview.bounds
            overlay.frame = removalSuperview.bounds
            
            overlay.alpha = 0.0
            
            removalSuperview.layoutIfNeeded()
            removalSuperview.setNeedsDisplay()
            
            UIView.animateKeyframes(withDuration: WalletView.removalAnimationSpeed, delay: 0, options: [.calculationModeCubic], animations: {
                
                UIView.addKeyframe(withRelativeStartTime: 0.6, relativeDuration: 0.7, animations: {
                    self?.remove(cardViews: [cardView])
                })
                    
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.7, animations: {
                
                    removalSuperview.frame = removalSuperview.frame.insetBy(dx: 0, dy: removalSuperview.frame.height/2)
                    cardView.alpha = 0.0
                    
                    cardView.layoutIfNeeded()
                    cardView.setNeedsDisplay()
                    
                    removalSuperview.layoutIfNeeded()
                    removalSuperview.setNeedsDisplay()
                })
                
                UIView.addKeyframe(withRelativeStartTime: 0.3, relativeDuration: 0.4, animations: {
                    overlay.alpha = 1.0
                    overlay.setNeedsDisplay()
                })
                
            }, completion: { (_) in
                completion?()
                removalSuperview.removeFromSuperview()
                
            })
            
        }
    }
    
    weak var grabbedCardView: CardView?
    
    var grabbedCardViewOriginalY:                                           CGFloat = 0
    
    func grab(cardView: CardView, popup: Bool) {
        
        if insertedCardViews.count <= 0 || (presentedCardView != nil && presentedCardView != cardView) {
            return
        }
        scrollView.isScrollEnabled = false
        
        grabbedCardView = cardView
        grabbedCardViewOriginalY = cardView.frame.minY - (popup ? grabPopupOffset : 0)
        
        var cardViewFrame = cardView.frame
        cardViewFrame.origin.y = grabbedCardViewOriginalY
        
        UIView.animate(withDuration: WalletView.grabbingAnimationSpeed, delay: 0, options: [.beginFromCurrentState, .curveEaseInOut], animations: { [weak self] in
            self?.grabbedCardView?.frame = cardViewFrame
            self?.grabbedCardView?.layoutIfNeeded()
            }, completion: nil)
        
    }
    
    func updateGrabbedCardView(offset: CGFloat) {
        
        var cardViewFrame = grabbedCardView?.frame ?? CGRect.zero
        cardViewFrame.origin.y = grabbedCardViewOriginalY + offset
        grabbedCardView?.frame = cardViewFrame
        
        
    }
    
    func releaseGrabbedCardView() {
        
        defer {
            grabbedCardView = nil
        }
        
        if let grabbedCardView = grabbedCardView,
            grabbedCardView == presentedCardView && grabbedCardView.presented == true,
            grabbedCardView.frame.origin.y > grabbedCardViewOriginalY + maximumCardViewHeight / 4 {
            
            let presentationCenter = convert(self.presentationCenter, from: scrollView)
            let yPoints = frame.maxY - (presentationCenter.y - maximumCardViewHeight / 2)
            let velocityY = grabbedCardView.panGestureRecognizer.velocity(in: grabbedCardView).y
            let animationDuration = min(WalletView.dismissingAnimationSpeed * 1.5, TimeInterval(yPoints / velocityY))
            //dismissPresentedCardView(animated: true, animationDuration: animationDuration)
            dissmissFooter {
                self.delegate?.cardViewDismissed(cardView: self.presentedCardView!)
                self.dismissPresentedCardView(animated: true, animationDuration: animationDuration)
            }
        } else if let grabbedCardView = grabbedCardView,
            presentedCardView == nil && grabbedCardView.presented == false,
            grabbedCardView.frame.origin.y < grabbedCardViewOriginalY - maximumCardViewHeight / 4 {
            present(cardView: grabbedCardView, animated: true)
        } else {
            layoutWalletView(animationDuration: WalletView.grabbingAnimationSpeed)
        }
        
    }
    
    
    
    var presentationCenter: CGPoint {
        
        let centerRect = CGRect(x: 16, y: cardViewTopInset,
                                width: frame.width - 32,
                                height: frame.height - collapsedCardViewStackHeight - cardViewTopInset)
        
        return scrollView.convert( CGPoint(x: centerRect.midX, y: 100), from: self)
        
    }
    
    var collapsedCardViewStackHeight:   CGFloat = 0
    var walletHeaderHeight:         CGFloat = 0
    var cardViewTopInset:               CGFloat = 0
    var maximumCardViewHeight:          CGFloat = 100
    var cardViewHeight:                 CGFloat = 100
    var distanceBetweenCardViews:       CGFloat = 0
    
    func calculateLayoutValues(shouldLayoutWalletView: Bool = true) {
        
        
        walletHeaderHeight = walletHeader?.frame.height ?? 0
        
        cardViewTopInset = scrollView.contentInset.top + walletHeaderHeight
        
        collapsedCardViewStackHeight = (minimalDistanceBetweenCollapsedCardViews * CGFloat(maximimNumberOfCollapsedCardViewsToShow)) + distanceBetweetCollapsedAndPresentedCardViews
        
        maximumCardViewHeight = 250
        
        cardViewHeight = min(preferableCardViewHeight, maximumCardViewHeight)
        
        
        let usableCardViewsHeight = walletHeaderHeight + insertedCardViews.map { _ in cardViewHeight }.reduce(0, { $0 + $1 } )
        
        distanceBetweenCardViews = 65

        if shouldLayoutWalletView {
            layoutWalletView()
            updateScrolViewContentSize()
        }
        
    }
    
    func layoutWalletHeader() {
        
        if let walletHeader = walletHeader {
            
            var walletHeaderFrame = walletHeader.frame
            walletHeaderFrame.origin = convert(.zero, to: scrollView)
            walletHeaderFrame.origin.y += scrollView.contentInset.top
            walletHeaderFrame.size = CGSize(width: frame.width, height: walletHeader.frame.height)
            walletHeader.frame = walletHeaderFrame
            
        }
        
    }
    
    func layoutWalletView(animationDuration: TimeInterval? = nil,
                          animationOptions: UIViewKeyframeAnimationOptions = [.beginFromCurrentState, .calculationModeCubic],
                          placeVisibleCardViews: Bool = true,
                          completion: LayoutCompletion? = nil) {
        
        let animations = { [weak self] in
            
            self?.layoutWalletHeader()
            
            if let presentedCardView = self?.presentedCardView,
                let insertedCardViews = self?.insertedCardViews {
                self?.makeCollapseLayout(collapsePresentedCardView: !insertedCardViews.contains(presentedCardView))
            } else {
                self?.makeStackLayout()
            }
            
            if placeVisibleCardViews {
                self?.placeVisibleCardViews()
            }
            
            self?.layoutIfNeeded()
            
        }
        
        if let animationDuration = animationDuration, animationDuration > 0 {
            UIView.animateKeyframes(withDuration: animationDuration, delay: 0, options: animationOptions, animations: animations, completion: completion)
        } else {
            animations()
            completion?(true)
        }
    }
    
    func updateScrolViewContentSize() {
        
        var contentSize = CGSize(width: frame.width, height: 0)
        
        let walletHeaderHeight = walletHeader?.frame.height ?? 0
        
        contentSize.height = (insertedCardViews.last?.frame.maxY ?? walletHeaderHeight) - (maximumCardViewHeight/2)
        
        if !contentSize.equalTo(scrollView.contentSize) {
            scrollView.contentSize = contentSize
        }
        
    }
    
    
    func makeStackLayout() {
        
        scrollView.isScrollEnabled = true
        
        let zeroRectConvertedFromWalletView: CGRect = {
            var rect = convert(CGRect.zero, to: scrollView)
            rect.origin.y += scrollView.contentInset.top
            return rect
        }()
        
        let stretchingDistanse: CGFloat? = {
            
            let negativeScrollViewContentInsetTop = -(scrollView.contentInset.top)
            let scrollViewContentOffsetY = scrollView.contentOffset.y
            
            if negativeScrollViewContentInsetTop > scrollViewContentOffsetY {
                return fabs(fabs(negativeScrollViewContentInsetTop) + scrollViewContentOffsetY)
            }
            
            return nil
        }()
        
        let walletHeaderY = walletHeader?.frame.origin.y ?? zeroRectConvertedFromWalletView.origin.y
        
        var cardViewYPoint = walletHeaderHeight
        
        let cardViewHeight = self.cardViewHeight
        
        let firstCardView = insertedCardViews.first
        
        for cardViewIndex in 0..<insertedCardViews.count {
            
            let cardView = insertedCardViews[cardViewIndex]
            
            var cardViewFrame = CGRect(x: 16, y: max(cardViewYPoint, walletHeaderY), width: frame.width-32, height: cardViewHeight)
            
            if cardView == firstCardView {
                
                cardViewFrame.origin.y = min(cardViewFrame.origin.y, walletHeaderY + walletHeaderHeight)
                cardView.frame = cardViewFrame
                
            } else {
                
                if let stretchingDistanse = stretchingDistanse {
                    cardViewFrame.origin.y += stretchingDistanse * CGFloat((cardViewIndex - 1))
                }
                
                cardView.frame = cardViewFrame
            }
            
            cardViewYPoint += distanceBetweenCardViews
            
        }
        
    }
    
    func makeCollapseLayout(collapsePresentedCardView: Bool = false) {
        
        scrollView.isScrollEnabled = false
        
        let scrollViewFrameMaxY = scrollView.convert(CGPoint(x: 0, y: scrollView.frame.maxY), from: self).y
        var cardViewYPoint = scrollViewFrameMaxY - collapsedCardViewStackHeight
        
        cardViewYPoint += distanceBetweetCollapsedAndPresentedCardViews
        
        let cardViewHeight = self.cardViewHeight
        
        let distanceBetweenCardViews = minimalDistanceBetweenCollapsedCardViews
        
        let firstIndexToMoveY: Int = {
            
            guard let presentedCardView = presentedCardView,
                let presentedCardViewIndex = insertedCardViews.index(of: presentedCardView) else {
                    return 0
            }
            
            let halfMaximimNumberOfCollapsedCardViewsToShow = Int(round(CGFloat(maximimNumberOfCollapsedCardViewsToShow)/2))
            
            if presentedCardViewIndex >= insertedCardViews.count - 1 {
                return presentedCardViewIndex - (maximimNumberOfCollapsedCardViewsToShow - 1)
            } else {
                return presentedCardViewIndex - halfMaximimNumberOfCollapsedCardViewsToShow
            }
            
        }()
        
        var collapsedCardViewsCount = maximimNumberOfCollapsedCardViewsToShow
        
        for cardViewIndex in 0..<insertedCardViews.count {
            
            let cardView = insertedCardViews[cardViewIndex]
            
            var cardViewFrame = CGRect(x: 16, y: scrollViewFrameMaxY + (collapsedCardViewStackHeight * 2), width: frame.width - 32, height: cardViewHeight)
            
            if cardViewIndex >= firstIndexToMoveY && collapsedCardViewsCount > 0 {
                
                if presentedCardView != cardView || collapsePresentedCardView {
                    
                    let widthDelta = distanceBetweenCardViews * CGFloat(collapsedCardViewsCount)
                    cardViewFrame.size.width = cardViewFrame.size.width - widthDelta
                    cardViewFrame.origin.x += widthDelta/2
                    
                    collapsedCardViewsCount -= 1
                    cardViewFrame.origin.y = cardViewYPoint
                    cardViewYPoint += distanceBetweenCardViews
                }
                
            }
            
            cardView.frame = cardViewFrame
            
            if presentedCardView == cardView && !collapsePresentedCardView {
                cardView.center = presentationCenter
            }
            
        }
        
    }
    func dissmissFooter(completion: @escaping () -> ()) {
        if (presentedCardView?.superview != nil) {
            let animations = { [weak self] in
                var origin = self?.presentedCardView?.frame.origin
                origin?.y += (self?.presentedCardView?.frame.height)! - 80
                var size = self?.presentedCardView?.frame.size
                size?.height = 70
                if (origin == nil)  {
                    return
                }
                self?.presentedFooterView.frame = CGRect(origin: origin!, size: size!)
                self?.presentedFooterView.layer.opacity = 0
            }
            let animations1 = { [weak self] in
                if (self?.items.count == 0) {
                    return
                }
                var origin = self?.presentedCardView?.frame.origin
                origin?.y += (self?.presentedCardView?.frame.height)! - 80
                var size = self?.presentedCardView?.frame.size
                size?.height = 70
                if (origin == nil)  {
                    return
                }
                self?.transactionTableView.frame = CGRect(origin: origin!, size: size!)
                self?.transactionTableView.layer.opacity = 0
            }

            let options = UIViewKeyframeAnimationOptions.beginFromCurrentState
            UIView.animateKeyframes(withDuration: 0.35, delay: 0, options: options, animations: animations1, completion: { (_) in
                UIView.animateKeyframes(withDuration: 0.35, delay: 0, options: options, animations: animations, completion: { (_) in
                    self.presentedFooterView.removeFromSuperview()
                    completion()
                })
            })
                }
    }
    
    
    func presentFooter() {

        if(presentedCardView == nil) {
            return
        }

        if (presentedFooterView.superview == nil) {
            var origin = presentedCardView?.frame.origin
            origin?.y += (presentedCardView?.frame.height)! - 80
            var size = presentedCardView?.frame.size
            size?.height = 70
            presentedFooterView.layer.cornerRadius = 10
            presentedFooterView.frame = CGRect(origin: origin!, size: size!)
            presentedFooterView.layer.opacity = 0
            presentedFooterView.backgroundColor = UIColor.customTitaniumMedium()
            scrollView.insertSubview(presentedFooterView, belowSubview: presentedCardView!)
        }

        if (transactionTableView.superview == nil) {
            var origin = presentedCardView?.frame.origin
            origin?.y += (presentedCardView?.frame.height)! - 80
            var size = presentedCardView?.frame.size
            size?.height = 90
            transactionTableView.showsVerticalScrollIndicator = false
            transactionTableView.frame = CGRect(origin: origin!, size: size!)
            transactionTableView.layer.opacity = 0
            transactionTableView.backgroundColor = UIColor.customTitaniumDark()
            let header = UIView()
            header.backgroundColor = UIColor.customTitaniumDark()
            header.frame = CGRect(x: 0, y: 0, width: (size?.width)!, height: 65)
            let label = UILabel()
            label.frame = CGRect(x: 0, y: 0, width: 120, height: 20)
            label.text = "TRANSACTIONS"
            label.translatesAutoresizingMaskIntoConstraints = false
            label.textColor = UIColor.customTitaniumLight()
            label.sizeToFit()
            label.font = label.font.withSize(16)
            header.addSubview(label)

            let line = UIView()
            line.frame = CGRect(x: 0, y: 0, width: (size?.width)!, height: 1)
            line.backgroundColor = UIColor.customTitaniumLight()
            line.translatesAutoresizingMaskIntoConstraints = false
            header.addSubview(line)

            let imageView = UIImageView()
            line.frame = CGRect(x: 0, y: 0, width: 25, height: 25)
            imageView.image = #imageLiteral(resourceName: "transactionFilter")
            imageView.contentMode  = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            header.addSubview(imageView)

            //LABEL CONSTRAINTS
            NSLayoutConstraint(item: label, attribute: NSLayoutAttribute.centerY, relatedBy: NSLayoutRelation.equal, toItem: header, attribute: NSLayoutAttribute.centerY, multiplier: 1, constant: 8).isActive = true
            NSLayoutConstraint(item: label, attribute: NSLayoutAttribute.left, relatedBy: NSLayoutRelation.equal, toItem: header, attribute: NSLayoutAttribute.left, multiplier: 1, constant: 0).isActive = true
            //LINE CONSTRAINTS
            NSLayoutConstraint(item: line, attribute: NSLayoutAttribute.bottom, relatedBy: NSLayoutRelation.equal, toItem: header, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: 0).isActive = true
            NSLayoutConstraint(item: line, attribute: NSLayoutAttribute.left, relatedBy: NSLayoutRelation.equal, toItem: header, attribute: NSLayoutAttribute.left, multiplier: 1, constant: 0).isActive = true
            NSLayoutConstraint(item: line, attribute: NSLayoutAttribute.right, relatedBy: NSLayoutRelation.equal, toItem: header, attribute: NSLayoutAttribute.right, multiplier: 1, constant: 0).isActive = true
            NSLayoutConstraint(item: line, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.height, multiplier: 1, constant: 0.5).isActive = true
            //IMAGEVIEW
            NSLayoutConstraint(item: imageView, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.height, multiplier: 1, constant: 19).isActive = true
            NSLayoutConstraint(item: imageView, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.width, multiplier: 1, constant: 22).isActive = true
            NSLayoutConstraint(item: imageView, attribute: NSLayoutAttribute.right, relatedBy: NSLayoutRelation.equal, toItem: header, attribute: NSLayoutAttribute.right, multiplier: 1, constant: -15).isActive = true
            NSLayoutConstraint(item: imageView, attribute: NSLayoutAttribute.centerY, relatedBy: NSLayoutRelation.equal, toItem: header, attribute: NSLayoutAttribute.centerY, multiplier: 1, constant: 8).isActive = true

            transactionTableView.tableHeaderView = header
            scrollView.insertSubview(transactionTableView, belowSubview: presentedFooterView)
        }

        let animations = { [weak self] in
            var origin = self?.presentedCardView?.frame.origin
            origin?.y += (self?.presentedCardView?.frame.height)! - 10
            var size = self?.presentedCardView?.frame.size
            size?.height = 70
            self?.presentedFooterView.frame = CGRect(origin: origin!, size: size!)
            self?.presentedFooterView.layer.opacity = 1
        }

        let animations1 = { [weak self] in
            if (self?.items.count == 0) {
                return
            }

            var origin = self?.presentedFooterView.frame.origin
            origin?.y += (self?.presentedFooterView.frame.height)!
            var size = self?.presentedCardView?.frame.size
            let maxHeight = (self?.frame.origin.y)! + (self?.frame.size.height)! - (origin?.y)! - 20
            size?.height = maxHeight
            self?.transactionTableView.frame = CGRect(origin: origin!, size: size!)
            self?.transactionTableView.layer.opacity = 1
        }

        let options = UIViewKeyframeAnimationOptions.beginFromCurrentState
        UIView.animateKeyframes(withDuration: 0.35, delay: 0, options: options, animations: animations, completion: {
            _ in
            UIView.animateKeyframes(withDuration: 0.35, delay: 0, options: options, animations: animations1, completion:{ _ in
                self.transactionTableView.layer.zPosition = 3
            })
        })
    }

    func placeVisibleCardViews() {
        
        var cardViewIndex = [CGFloat: (index: Int, cardView: CardView)]()
        
        var viewsToRemoveFromScrollView = [CardView]()
        
        let shownScrollViewRect = CGRect(x: scrollView.contentOffset.x,
                                         y: scrollView.contentOffset.y,
                                         width: scrollView.frame.width,
                                         height: scrollView.frame.height)
        
        for index in 0..<insertedCardViews.count {
            
            let cardView = insertedCardViews[index]
            
            let intersection = shownScrollViewRect.intersection(cardView.frame)
            
            guard intersection.height > 0 || intersection.width > 0 else {
                viewsToRemoveFromScrollView.append(cardView)
                continue
            }
            
            let cardViewMinY = cardView.frame.minY
            
            if cardView == presentedCardView {
                cardViewIndex[CGFloat.greatestFiniteMagnitude] = (index, cardView)
                continue
            } else if let previousCardView = cardViewIndex[cardViewMinY]?.cardView {
                viewsToRemoveFromScrollView.append(previousCardView)
            }
            
            cardViewIndex[cardViewMinY] = (index, cardView)
            
        }
        
        for cardView in viewsToRemoveFromScrollView {
            cardView.removeFromSuperview()
        }
        
        let indexCardViewPairs = cardViewIndex.sorted(by: { $0.value.index < $1.value.index }).map { $0.value }
        
        guard let firstCardView = indexCardViewPairs.first?.cardView else { return }
        
        var previousCardView = firstCardView
        
        for pair in indexCardViewPairs {
            
            if pair.cardView == firstCardView {
                scrollView.addSubview(pair.cardView)
            } else {
                scrollView.insertSubview(pair.cardView, aboveSubview: previousCardView)
            }
            
            previousCardView = pair.cardView
        }
        
    }
    
}

protocol WalletViewDelegate: class {
    func cardViewPresented(cardView: CardView)
    func cardViewDismissed(cardView: CardView)
    func showTransaction(tx :TransactionItem)
}

