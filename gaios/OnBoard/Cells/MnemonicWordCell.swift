import UIKit

protocol MnemonicWordCellDelegate: AnyObject {
    func collectionView(valueChangedIn textField: UITextField, from cell: MnemonicWordCell)
    func collectionView(pastedIn text: String, from cell: MnemonicWordCell)
}

class MnemonicWordCell: UICollectionViewCell {

    @IBOutlet weak var wordLabel: UILabel!
    @IBOutlet weak var wordText: UITextField!
    @IBOutlet weak var wordSeparator: UIView!

    weak var delegate: MnemonicWordCellDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()

        wordText.delegate = self
    }

    @IBAction func editingChanged(_ sender: UITextField) {
        delegate?.collectionView(valueChangedIn: sender, from: self)
    }
}

extension MnemonicWordCell: UITextFieldDelegate {

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if !string.isEmpty {
            delegate?.collectionView(pastedIn: string, from: self)
        }
        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        endEditing(true)
        return false
    }
}
