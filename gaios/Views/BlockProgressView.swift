//
//  BlockProgressView.swift
//  gaios
//
//  Created by Dawson Walker on 2019-02-23.
//  Copyright © 2019 Blockstream Corporation. All rights reserved.
//

import UIKit

class BlockProgressView: UIView {
    @IBOutlet var view: UIView!

    //row 1
    @IBOutlet weak var row1Image1: UIImageView!
    @IBOutlet weak var row1Image2: UIImageView!
    @IBOutlet weak var row1Image3: UIImageView!
    @IBOutlet weak var row1Image4: UIImageView!
    @IBOutlet weak var row1Image5: UIImageView!
    @IBOutlet weak var row1Image6: UIImageView!

    //row 2
    @IBOutlet weak var row2Image1: UIImageView!
    @IBOutlet weak var row2Image2: UIImageView!
    @IBOutlet weak var row2Image3: UIImageView!
    @IBOutlet weak var row2Image4: UIImageView!
    @IBOutlet weak var row2Image5: UIImageView!
    @IBOutlet weak var row2Image6: UIImageView!

    //row 3
    @IBOutlet weak var row3Image1: UIImageView!
    @IBOutlet weak var row3Image2: UIImageView!
    @IBOutlet weak var row3Image3: UIImageView!
    @IBOutlet weak var row3Image4: UIImageView!
    @IBOutlet weak var row3Image5: UIImageView!
    @IBOutlet weak var row3Image6: UIImageView!

    //row 4
    @IBOutlet weak var row4Image1: UIImageView!
    @IBOutlet weak var row4Image2: UIImageView!
    @IBOutlet weak var row4Image3: UIImageView!
    @IBOutlet weak var row4Image4: UIImageView!
    @IBOutlet weak var row4Image5: UIImageView!
    @IBOutlet weak var row4Image6: UIImageView!

    
    let nibName = "BlockProgressView"
    var contentView : UIView?
    var row1Array = Array<UIImageView>()
    var row2Array = Array<UIImageView>()
    var row3Array = Array<UIImageView>()
    var row4Array = Array<UIImageView>()
    var prevValue = 0
    var progress: Int = 0 {
        didSet {

            updateProgress()
            prevValue = progress - 1
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    func setImageDisplay(array: Array<UIImageView>, isEmpty: Bool, reversed: Bool) {
        var delay = 0.15
        let a = reversed ? array.reversed() : array
        
        a.forEach {
            if(isEmpty) {
                emptyImage(image: $0, delay: delay)
            } else {
                displayImageProgress(image: $0, delay: delay)
            }
            delay += 0.15
        }
    }
    func updateProgress() {
        switch progress {
        case 0:
            setImageDisplay(array: row1Array, isEmpty: false, reversed: false)
            setImageDisplay(array: row2Array, isEmpty: true, reversed: prevValue == progress)
            setImageDisplay(array: row3Array, isEmpty: true, reversed: false)
            setImageDisplay(array: row4Array, isEmpty: true, reversed: false)

        case 1:
            setImageDisplay(array: row1Array, isEmpty: false, reversed: false)
            setImageDisplay(array: row2Array, isEmpty: false, reversed: false)
            setImageDisplay(array: row3Array, isEmpty: true, reversed: prevValue == progress)
            setImageDisplay(array: row4Array, isEmpty: true, reversed: false)

        case 2:
            setImageDisplay(array: row1Array, isEmpty: false, reversed: false)
            setImageDisplay(array: row2Array, isEmpty: false, reversed: false)
            setImageDisplay(array: row3Array, isEmpty: false, reversed: false)
            setImageDisplay(array: row4Array, isEmpty: true, reversed: prevValue == progress)
        case 3:
            setImageDisplay(array: row1Array, isEmpty: false, reversed: false)
            setImageDisplay(array: row2Array, isEmpty: false, reversed: false)
            setImageDisplay(array: row3Array, isEmpty: false, reversed: false)
            setImageDisplay(array: row4Array, isEmpty: false, reversed: false)


        default:
            setImageDisplay(array: row1Array, isEmpty: false, reversed: false)
            setImageDisplay(array: row2Array, isEmpty: true, reversed: false)
            setImageDisplay(array: row3Array, isEmpty: true, reversed: false)
            setImageDisplay(array: row4Array, isEmpty: true, reversed: false)
        }
    }

    func emptyImage(image: UIImageView, delay: Double) {
        image.layer.borderColor = UIColor.customMatrixGreen().cgColor
        image.layer.borderWidth = 1
        UIView.animate(withDuration: 0.2, delay: delay, options: .curveEaseIn, animations: {
            image.backgroundColor = .clear
        }, completion: nil)

    }

    func displayImageProgress(image: UIImageView, delay: Double) {
        image.layer.borderColor = UIColor.customMatrixGreen().cgColor
        image.layer.borderWidth = 1
        UIView.animate(withDuration: 0.2, delay: delay, options: .curveEaseIn, animations: {
            image.backgroundColor = .customMatrixGreen()
        }, completion: nil)

    }
    func setup() {
        contentView = loadViewFromNib()
        contentView!.frame = bounds
        contentView!.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(contentView!)

        row1Array = [row1Image1, row1Image2, row1Image3, row1Image4, row1Image5, row1Image6]
        row2Array = [row2Image1, row2Image2, row2Image3, row2Image4, row2Image5, row2Image6]
        row3Array = [ row3Image1, row3Image2, row3Image3, row3Image4, row3Image5, row3Image6]
        row4Array = [row4Image1, row4Image2, row4Image3, row4Image4, row4Image5, row4Image6]

        setImageDisplay(array: row1Array, isEmpty: true, reversed: false)
        setImageDisplay(array: row2Array, isEmpty: true, reversed: false)
        setImageDisplay(array: row3Array, isEmpty: true, reversed: false)
        setImageDisplay(array: row4Array, isEmpty: true, reversed: false)
    }

    func loadViewFromNib() -> UIView! {
        let bundle = Bundle(for: type(of: self))
        let nib = UINib(nibName: nibName, bundle: bundle)
        let view = nib.instantiate(withOwner: self, options: nil).first as! UIView
        return view
    }

}
