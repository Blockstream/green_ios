//
//  CreatePageViewController.swift
//  GreenBitsIOS
//

import UIKit

class CreatePageViewController: UIPageViewController, UIPageViewControllerDelegate, UIPageViewControllerDataSource {
    
    lazy var pageViewControllers: [UIViewController] = {
        return [instantiateViewController(withIdentifier: "Verify Mnemonic"),
                instantiateViewController(withIdentifier: "Two Factor")]
    }()
    
    var pageControl: UIPageControl = UIPageControl()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.dataSource = self
        if let initialViewController = pageViewControllers.first {
            setViewControllers([initialViewController], direction: .forward, animated: true, completion: nil)
        }
        
        self.delegate = self
    }
    
    override func viewDidLayoutSubviews() {
        createUIPageControl()
    }

    @IBAction func pageControlValueChanged(sender: AnyObject) {
        let currPageControl = sender as! UIPageControl
        let currPageViewController = pageViewControllers[currPageControl.currentPage]
        setViewControllers([currPageViewController], direction: .forward, animated: true, completion: nil)
    }

    func createUIPageControl() {
        pageControl.removeFromSuperview()
        pageControl = UIPageControl(frame: CGRect(x: 0, y: UIScreen.main.bounds.maxY - 50, width: UIScreen.main.bounds.width, height: 50))
        pageControl.numberOfPages = pageViewControllers.count
        pageControl.currentPage = 0
        pageControl.pageIndicatorTintColor = UIColor.gray
        pageControl.currentPageIndicatorTintColor = UIColor.black
        pageControl.tintColor = UIColor.black
        pageControl.addTarget(self, action: #selector(self.pageControlValueChanged(sender:)), for: .touchUpInside)
        view.addSubview(pageControl)
    }
    
    func instantiateViewController(withIdentifier: String) -> UIViewController {
        return UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: withIdentifier)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let currIndex = pageViewControllers.index(of: viewController) else {
            return nil
        }
        
        let previousIndex = currIndex - 1
        guard previousIndex >= 0 && previousIndex < pageViewControllers.count else {
            return nil
        }
        
        return pageViewControllers[previousIndex]
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let currIndex = pageViewControllers.index(of: viewController) else {
            return nil
        }

        let nextIndex = currIndex + 1
        guard nextIndex > 0 && nextIndex < pageViewControllers.count else {
            return nil
        }
        
        return pageViewControllers[nextIndex]
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        let currPageViewController = pageViewController.viewControllers![0]
        pageControl.currentPage = pageViewControllers.index(of: currPageViewController)!
    }
}
