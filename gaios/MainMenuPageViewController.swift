//
//  MainMenuPageViewController.swift
//  gaios
//
//  Created by Strahinja Markovic on 7/17/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation
import UIKit

class MainMenuPageViewController: UIPageViewController, UIPageViewControllerDelegate, UIPageViewControllerDataSource, NotificationDelegate
{
    var pageControl = UIPageControl()
    var button:UIButton = UIButton()
    var button1:UIButton = UIButton()
    var button2:UIButton = UIButton()
    var viewControllerIndex = 1

    fileprivate lazy var pages: [UIViewController] = {
        return [
            self.getViewController(withIdentifier: "settings"),
            self.getViewController(withIdentifier: "wallets"),
            self.getViewController(withIdentifier: "notifications")
        ]
    }()

    fileprivate func getViewController(withIdentifier identifier: String) -> UIViewController
    {
        return UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: identifier)
    }

    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.dataSource = self
        self.delegate   = self
        NotificationStore.shared.delegate = self
        let firstVC: UINavigationController = pages[viewControllerIndex] as! UINavigationController
        let view = firstVC.viewControllers[0] as! ViewController
        view.pager = self
        let settings: UINavigationController = pages[0] as! UINavigationController
        let settingsVC = settings.viewControllers[0] as! SettingsViewController
        settingsVC.pager = self
        setViewControllers([firstVC], direction: .forward, animated: true, completion: nil)
        let appearance = UIPageControl.appearance(whenContainedInInstancesOf: [IntroPageViewController.self])
        appearance.pageIndicatorTintColor = UIColor.customTitaniumMedium()
        appearance.currentPageIndicatorTintColor = .white
        addButtons()
    }

    func addButtons() {
        button = UIButton(frame: CGRect(x: 0 , y: 0, width: 60, height: 30))
        button.backgroundColor = UIColor.clear
        button.setTitle("", for: UIControlState.normal)
        button.setImage(UIImage(named: "settings"), for: UIControlState.normal)
        self.view.addSubview(button)
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint(item: button, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.height, multiplier: 1, constant: 27).isActive = true
         NSLayoutConstraint(item: button, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.width, multiplier: 1, constant: 27).isActive = true
        
        NSLayoutConstraint(item: button, attribute: NSLayoutAttribute.leading, relatedBy: NSLayoutRelation.equal, toItem: self.view, attribute: NSLayoutAttribute.leading, multiplier: 1, constant: 22).isActive = true
        
        if #available(iOS 11, *) {
            NSLayoutConstraint(item: button, attribute: NSLayoutAttribute.bottom, relatedBy: NSLayoutRelation.equal, toItem: self.view.safeAreaLayoutGuide, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: -16).isActive = true
        } else {
            NSLayoutConstraint(item: button, attribute: NSLayoutAttribute.bottom, relatedBy: NSLayoutRelation.equal, toItem: self.view, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: -16).isActive = true
        }
        button.addTarget(self, action:#selector(self.settingsButtonClicked), for: .touchUpInside)

        button1 = UIButton(frame: CGRect(x: 0 , y: 0, width: 60, height: 30))
        button1.backgroundColor = UIColor.clear
        button1.setTitle("", for: UIControlState.normal)
        button1.setImage(UIImage(named: "notification"), for: UIControlState.normal)
        self.view.addSubview(button1)
       // button1.contentEdgeInsets = UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)
        button1.titleLabel?.adjustsFontSizeToFitWidth = true
        button1.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint(item: button1, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.height, multiplier: 1, constant: 27).isActive = true
        NSLayoutConstraint(item: button1, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.width, multiplier: 1, constant: 22).isActive = true
        
        NSLayoutConstraint(item: button1, attribute: NSLayoutAttribute.trailing, relatedBy: NSLayoutRelation.equal, toItem: self.view, attribute: NSLayoutAttribute.trailing, multiplier: 1, constant: -22).isActive = true
        
        if #available(iOS 11, *) {
            NSLayoutConstraint(item: button1, attribute: NSLayoutAttribute.bottom, relatedBy: NSLayoutRelation.equal, toItem: self.view.safeAreaLayoutGuide, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: -16).isActive = true
        } else {
            NSLayoutConstraint(item: button1, attribute: NSLayoutAttribute.bottom, relatedBy: NSLayoutRelation.equal, toItem: self.view, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: -16).isActive = true
        }
        button1.addTarget(self, action:#selector(self.notificationButtonClicked), for: .touchUpInside)

        button2 = UIButton(frame: CGRect(x: 0 , y: 0, width: 60, height: 30))
        button2.backgroundColor = UIColor.clear
        button2.setTitle("", for: UIControlState.normal)
        button2.setImage(UIImage(named: "iconMenu"), for: UIControlState.normal)
        self.view.addSubview(button2)
       // button2.contentEdgeInsets = UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)
        button2.titleLabel?.adjustsFontSizeToFitWidth = true
        button2.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint(item: button2, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.height, multiplier: 1, constant: 27).isActive = true
        NSLayoutConstraint(item: button2, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.width, multiplier: 1, constant: 22).isActive = true
        
        NSLayoutConstraint(item: button2, attribute: NSLayoutAttribute.centerX, relatedBy: NSLayoutRelation.equal, toItem: self.view, attribute: NSLayoutAttribute.centerX, multiplier: 1, constant: 0).isActive = true
        
        if #available(iOS 11, *) {
            NSLayoutConstraint(item: button2, attribute: NSLayoutAttribute.bottom, relatedBy: NSLayoutRelation.equal, toItem: self.view.safeAreaLayoutGuide, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: -16).isActive = true
        } else {
            NSLayoutConstraint(item: button2, attribute: NSLayoutAttribute.bottom, relatedBy: NSLayoutRelation.equal, toItem: self.view, attribute: NSLayoutAttribute.bottom, multiplier: 1, constant: -16).isActive = true
        }
        button2.addTarget(self, action:#selector(self.walletButtonClicked), for: .touchUpInside)

    }

    @objc func settingsButtonClicked(_ sender: UIButton) {
        let viewController = pages[0]
        setViewControllers([viewController], direction:
            UIPageViewControllerNavigationDirection.reverse, animated: true, completion: {_ in self.viewControllerIndex = 0})
    }

    @objc func walletButtonClicked(_ sender: UIButton) {
        let viewController = pages[1]
        if (viewControllerIndex == 0) {
            setViewControllers([viewController], direction:
                UIPageViewControllerNavigationDirection.forward, animated: true, completion: {_ in self.viewControllerIndex = 1})
        } else if (viewControllerIndex == 2){
            setViewControllers([viewController], direction:
                UIPageViewControllerNavigationDirection.reverse, animated: true, completion: {_ in self.viewControllerIndex = 1})
        }
    }

    @objc func notificationButtonClicked(_ sender: UIButton) {
        let viewController = pages[2]
        setViewControllers([viewController], direction:
            UIPageViewControllerNavigationDirection.forward, animated: true, completion: {_ in self.viewControllerIndex = 2})
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {

        guard let viewControllerIndex = pages.index(of: viewController) else { return nil }

        let previousIndex = viewControllerIndex - 1

        guard previousIndex >= 0          else { return pages.last }

        guard pages.count > previousIndex else { return nil        }

        return pages[previousIndex]
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController?
    {
        guard let viewControllerIndex = pages.index(of: viewController) else { return nil }

        let nextIndex = viewControllerIndex + 1

        guard nextIndex < pages.count else { return pages.first }

        guard pages.count > nextIndex else { return nil         }

        return pages[nextIndex]
    }

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        let pageContentViewController = pageViewController.viewControllers![0]
        viewControllerIndex = pages.index(of: pageContentViewController)!
    }

    func presentationCountForPageViewController(pageViewController: UIPageViewController) -> Int {
        return 3
    }

    func presentationIndexForPageViewController(pageViewController: UIPageViewController) -> Int {
        return 0
    }

    func newNotification() {
        button1.setImage(UIImage(named: "newNotification"), for: UIControlState.normal)
    }

    func dismissNotification() {
        button1.setImage(UIImage(named: "notification"), for: UIControlState.normal)
    }

    func notificationChanged() {

    }

    func hideButtons() {
        button.isHidden = true
        button1.isHidden = true
        button2.isHidden = true
    }

    func showButtons() {
        button.isHidden = false
        button1.isHidden = false
        button2.isHidden = false
    }

}
