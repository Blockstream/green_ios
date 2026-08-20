import Foundation
import UIKit

class PromoContainerCell: UITableViewCell {
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var pageControlHeightConstraint: NSLayoutConstraint!

    class var identifier: String { return String(describing: self) }

    private let promoCardSpacing: CGFloat = 24.0
    private let sidePadding: CGFloat = 24.0
    private let pageControlHeight: CGFloat = 6.0
    private var promos: [PromoCellModel] = []

    private var onAction: ((Promo) -> Void)?
    private var onDismiss: ((Promo) -> Void)?
    private var onImpression: ((Promo) -> Void)?

    var isPaginationVisible: Bool {
        promos.count > 1
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(UINib(nibName: PromoCell.identifier, bundle: nil), forCellWithReuseIdentifier: PromoCell.identifier)
        collectionView.showsHorizontalScrollIndicator = false
        setupCompositionalLayout()

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 6, height: 6))
        let circle = renderer.image { ctx in
            ctx.cgContext.setFillColor(UIColor.black.cgColor)
            ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: 6, height: 6))
        }.withRenderingMode(.alwaysTemplate)
        pageControl.preferredIndicatorImage = circle
        pageControl.pageIndicatorTintColor = UIColor(red: 0x3A / 255.0, green: 0x3A / 255.0, blue: 0x3A / 255.0, alpha: 1)
        pageControl.currentPageIndicatorTintColor = .gGrayTxt()
        pageControl.isUserInteractionEnabled = false
        pageControl.backgroundStyle = .minimal
        pageControl.allowsContinuousInteraction = false
    }

    func configure(
        with promos: [PromoCellModel],
        onAction: @escaping (Promo) -> Void,
        onDismiss: @escaping (Promo) -> Void,
        onImpression: @escaping (Promo) -> Void
    ) {
        self.onAction = onAction
        self.onDismiss = onDismiss
        self.onImpression = onImpression
        update(with: promos)
    }

    func update(with promos: [PromoCellModel]) {
        let oldIds = self.promos.map { $0.promo.id }
        let newIds = promos.map { $0.promo.id }

        self.promos = promos

        guard oldIds != newIds else { return }

        let newPageCount = promos.count
        let showsPagination = newPageCount > 1
        pageControl.numberOfPages = newPageCount
        pageControl.isHidden = !showsPagination
        pageControlHeightConstraint.constant = showsPagination ? pageControlHeight : 0

        let targetPage = min(pageControl.currentPage, max(0, newPageCount - 1))
        pageControl.currentPage = targetPage

        collectionView.reloadData()
        collectionView.layoutIfNeeded()

        if newPageCount > 0 {
            let indexPath = IndexPath(item: targetPage, section: 0)
            collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: false)

            let promo = promos[targetPage].promo
            onImpression?(promo)
        }
    }

    private func setupCompositionalLayout() {
        let layout = UICollectionViewCompositionalLayout { [weak self] _, environment in
            guard let self = self else { return nil }

            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let cellWidth = environment.container.contentSize.width - (self.sidePadding * 2)
            let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(cellWidth), heightDimension: .fractionalHeight(1.0))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = self.promoCardSpacing
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: self.sidePadding, bottom: 0, trailing: self.sidePadding)
            section.orthogonalScrollingBehavior = .groupPagingCentered
            section.visibleItemsInvalidationHandler = { [weak self] _, scrollOffset, _ in
                guard let self = self else { return }
                let pageWidth = cellWidth + self.promoCardSpacing
                guard pageWidth > 0 else { return }
                let currentPage = Int(round(scrollOffset.x / pageWidth))

                DispatchQueue.main.async { [weak self] in
                    guard let strongSelf = self else { return }
                    if strongSelf.pageControl.currentPage != currentPage, currentPage >= 0, currentPage < strongSelf.promos.count {
                        strongSelf.pageControl.currentPage = currentPage
                        let promo = strongSelf.promos[currentPage].promo

                        strongSelf.onImpression?(promo)
                    }
                }
            }

            return section
        }
        collectionView.collectionViewLayout = layout
    }
}

extension PromoContainerCell: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return promos.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PromoCell.identifier, for: indexPath) as? PromoCell {
            let model = promos[indexPath.row]
            cell.configure(
                with: model,
                onAction: { [weak self] in
                    self?.onAction?(model.promo)
                },
                onDismiss: { [weak self] in
                    self?.onDismiss?(model.promo)
                }
            )
            return cell
        }
        return UICollectionViewCell()
    }
}

extension PromoContainerCell: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let model = promos[indexPath.row]
        onAction?(model.promo)
    }
}
