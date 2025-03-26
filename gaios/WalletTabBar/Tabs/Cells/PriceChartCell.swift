import UIKit
import DGCharts

class PriceChartCell: UITableViewCell {

    @IBOutlet weak var bg: UIView!
    @IBOutlet weak var btnBuy: UIButton!

    @IBOutlet weak var btnW: UIButton!
    @IBOutlet weak var btnM: UIButton!
    @IBOutlet weak var btnY: UIButton!
    @IBOutlet weak var btnYTD: UIButton!
    @IBOutlet weak var btnAll: UIButton!

    @IBOutlet weak var iconAsset: UIImageView!
    @IBOutlet weak var lblAsset: UILabel!
    @IBOutlet weak var lblGain: UILabel!
    @IBOutlet weak var iconGain: UIImageView!
    @IBOutlet weak var lblQuote: UILabel!
    @IBOutlet weak var lblNoData: UILabel!

    @IBOutlet weak var chartView: LineChartView!
    var model: PriceChartCellModel?
    var isReloading: Bool = false
    var onBuy: (() -> Void)?
    var onNewFrame: ((ChartTimeFrame) -> Void)?

    var timeFrame: ChartTimeFrame = .week
    @IBOutlet weak var loader: UIActivityIndicatorView!

    class var identifier: String { return String(describing: self) }

    override func prepareForReuse() {
        lblGain.text = ""
        lblQuote.text = ""
        iconGain.image = nil
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        bg.setStyle(CardStyle.defaultStyle)
        btnBuy.setStyle(.primary)
        btnBuy.setTitle("Buy Now".localized, for: .normal)
        btnBuy.setTitleColor(UIColor.gBlackBg(), for: .normal)
        btnBuy.titleLabel?.font = UIFont.systemFont(ofSize: 16.0, weight: .medium)
        [btnW, btnM, btnY, btnYTD, btnAll].forEach {
            $0?.titleLabel?.font = UIFont.systemFont(ofSize: 14.0, weight: .regular)
            $0?.setTitleColor(UIColor.gGrayTxt(), for: .normal)
            $0?.layer.cornerRadius = 11.0
            $0?.backgroundColor = UIColor.clear
        }
        btnW.setTitle(ChartTimeFrame.week.name, for: .normal)
        btnM.setTitle(ChartTimeFrame.month.name, for: .normal)
        btnY.setTitle(ChartTimeFrame.year.name, for: .normal)
//        btnYTD.setTitle(ChartTimeFrame.ytd.name, for: .normal)
        btnAll.setTitle(ChartTimeFrame.all.name, for: .normal)
        lblAsset.setStyle(.txtBigger)
        lblGain.setStyle(.txtBold)
        lblGain.textColor = UIColor.gGreenMatrix()
        lblQuote.setStyle(.txt)
        lblNoData.setStyle(.txtSmaller)
        lblNoData.text = "No data available, try later".localized
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func configure(_ model: PriceChartCellModel,
                   timeFrame: ChartTimeFrame,
                   onBuy: (() -> Void)?,
                   onNewFrame: ((ChartTimeFrame) -> Void)?) {
        self.model = model
        self.timeFrame = timeFrame
        self.onBuy = onBuy
        self.onNewFrame = onNewFrame
        updateBtn(btn: btnW, isSelected: timeFrame == .week)
        updateBtn(btn: btnM, isSelected: timeFrame == .month)
        updateBtn(btn: btnY, isSelected: timeFrame == .year)
//        updateBtn(btn: btnYTD, isSelected: timeFrame == .ytd)
        updateBtn(btn: btnAll, isSelected: timeFrame == .all)
        iconAsset.image = UIImage(named: "ntw_btc")
        lblAsset.text = "Bitcoin"
        isReloading = model.isReloading == true
        chart()
        loader.isHidden = !isReloading
        loader.startAnimating()
    }

    func updateBtn(btn: UIButton, isSelected: Bool) {
        btn.setTitleColor(isSelected ? .white : UIColor.gGrayTxt(), for: .normal)
        btn.backgroundColor = isSelected ? UIColor.gGrayCardBorder() : UIColor.clear
    }
    func chart() {
        var list: [ChartPoint] = []
        lblGain.text = ""
        lblQuote.text = ""
        iconGain.image = UIImage()

        if let model = model?.priceChartModel {
            list = model.list
            switch timeFrame {
            case .week:
                list = list.suffix(7)
            case .month:
                list = list.suffix(30)
            case .year:
                list = list.suffix(365)
            // case .ytd:
                // break
            case .all:
                list = list.suffix(365 * 5)
            }
            lblQuote.text = "\(String(format: "%.2f", list.last?.value ?? 0.0))\(model.currency)"
            if let last = list.last?.value, let first = list.first?.value, first > 0 {
                let ratio = ((last / first) - 1) * 100
                let sign = ratio > 0 ? "+" : ""
                lblGain.text = "\(sign)\(String(format: "%.2f", ratio))%"
                iconGain.image = UIImage(named: "ic_chart_up")
            }
        }

        let values: [ChartDataEntry] = list.map {
            return ChartDataEntry(x: $0.ts, y: $0.value)
        }

        let set1 = LineChartDataSet(entries: values, label: "Data")

        let gradientColors = [UIColor.clear.cgColor,
                              UIColor.gGreenMatrix().withAlphaComponent(0.7).cgColor
                              ]
        let gradient = CGGradient(colorsSpace: nil, colors: gradientColors as CFArray, locations: nil)!

        set1.fillAlpha = 1
        set1.fill = LinearGradientFill(gradient: gradient, angle: 90)
        set1.drawFilledEnabled = true
        set1.drawCirclesEnabled = false
        set1.lineWidth = 2
        set1.setColor(UIColor.gGreenMatrix())
        set1.drawValuesEnabled = false
        set1.mode = .cubicBezier
        chartView.drawBordersEnabled = false
        chartView.borderColor = UIColor.gGreenMatrix()
        chartView.xAxis.enabled = false
        chartView.leftAxis.enabled = false
        chartView.rightAxis.enabled = false
        chartView.legend.enabled = false
        chartView.minOffset = 0.0
        chartView.doubleTapToZoomEnabled = false
        chartView.dragEnabled = false
        chartView.highlightPerTapEnabled = false
        chartView.extraRightOffset = 10
        chartView.noDataText = ""
        lblNoData.isHidden = isReloading || !values.isEmpty
        var data: LineChartData?
        if values.count > 0 {
            data = LineChartData(dataSets: [set1])
        }
        if let last = list.last {
            let values2: [ChartDataEntry] = [ChartDataEntry(x: last.ts, y: last.value, icon: UIImage(named: "ic_chart_point"))]

            let set2 = LineChartDataSet(entries: values2, label: "Data")
            set2.drawValuesEnabled = false
            set2.drawCirclesEnabled = true
            set2.circleRadius = 0
            set2.circleColors = [UIColor.gGreenMatrix()]
            data = LineChartData(dataSets: [set1, set2])
        }
        chartView.data = data
    }

    @IBAction func btnW(_ sender: Any) {
        onNewFrame?(.week)
    }
    @IBAction func btnM(_ sender: Any) {
        onNewFrame?(.month)
    }
    @IBAction func btnY(_ sender: Any) {
        onNewFrame?(.year)
    }
    @IBAction func btnYTD(_ sender: Any) {
//        onNewFrame?(.ytd)
    }
    @IBAction func btnAll(_ sender: Any) {
        onNewFrame?(.all)
    }

    @IBAction func btnBuy(_ sender: Any) {
        onBuy?()
    }
}
