import UIKit
class DynamicTableView: UITableView {

    var dynamicRowHeight: CGFloat = UITableView.automaticDimension {
        didSet {
            rowHeight = UITableView.automaticDimension
            estimatedRowHeight = dynamicRowHeight
        }
    }

    public override var intrinsicContentSize: CGSize { contentSize }

    public override func layoutSubviews() {
        super.layoutSubviews()
        if !bounds.size.equalTo(intrinsicContentSize) {
            invalidateIntrinsicContentSize()
        }
    }
}

// A self-sizing table view that safely supports being compressed by external Auto Layout constraints.
// Use this for bottom sheets that need to scroll when max height is reached (e.g., when constrained by Safe Area).
class SelfSizedTableView: UITableView {
    override var contentSize: CGSize {
        didSet {
            // Only invalidate if height changes significantly to prevent infinite layout loops
            if abs(oldValue.height - contentSize.height) > 0.5 {
                invalidateIntrinsicContentSize()
            }
        }
    }
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: contentSize.height)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let shouldScroll = contentSize.height > bounds.size.height
        if isScrollEnabled != shouldScroll {
            isScrollEnabled = shouldScroll
        }
    }
}
