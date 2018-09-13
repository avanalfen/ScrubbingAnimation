//
//  ViewController.swift
//  ScrubbingAnimation
//
//  Created by Austin Van Alfen on 9/12/18.
//  Copyright © 2018 Austin Van Alfen. All rights reserved.
//

import UIKit
import UIKit.UIGestureRecognizerSubclass

class TouchDownPanGestureRecognizer: UIPanGestureRecognizer {
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if (self.state == UIGestureRecognizerState.began) { return }
        super.touchesBegan(touches, with: event)
        self.state = UIGestureRecognizerState.began
    }
    
}

private enum State {
    case closed
    case open
    
    var opposite: State {
        switch self {
        case .open: return .closed
        case .closed: return .open
        }
    }
}

class ViewController: UIViewController {
    
    private let popupOffset: CGFloat = 440
    private var bottomConstraint = NSLayoutConstraint()
    private var currentState: State = .closed
    private var animators = [UIViewPropertyAnimator]()
    private var animatorProgress = [CGFloat]()
    
    private lazy var panRecognizer: TouchDownPanGestureRecognizer = {
        let recognizer = TouchDownPanGestureRecognizer()
        recognizer.addTarget(self, action: #selector(popupViewPanned(recognizer:)))
        return recognizer
    }()
    
    private lazy var popupView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .lightGray
        view.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowRadius = 10
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        layout()
        popupView.addGestureRecognizer(panRecognizer)
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    private func layout() {
        
        view.addSubview(popupView)
        
        addActivateConstraints()
    }
    
    private func addActivateConstraints() {
        bottomConstraint = popupView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: popupOffset)
        
        NSLayoutConstraint.activate([
            
            popupView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            popupView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomConstraint,
            popupView.heightAnchor.constraint(equalToConstant: 500)
        ])
    }
    
    private func animateTransitionIfNeeded(to state: State, duration: TimeInterval) {
        
        guard animators.isEmpty else { return }
        
        let transitionAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1, animations: {
            switch state {
            case .open:
                self.bottomConstraint.constant = 0
                self.popupView.layer.cornerRadius = 20
            case .closed:
                self.bottomConstraint.constant = self.popupOffset
                self.popupView.layer.cornerRadius = 0
            }
            self.view.layoutIfNeeded()
        })
        
        transitionAnimator.addCompletion { position in
            
            switch position {
            case .start:
                self.currentState = state.opposite
            case .end:
                self.currentState = state
            case .current:
                ()
            }
            
            switch self.currentState {
            case .open:
                self.bottomConstraint.constant = 0
            case .closed:
                self.bottomConstraint.constant = self.popupOffset
            }
            
            self.animators.removeAll()
            
        }
        
        transitionAnimator.startAnimation()
        
        animators.append(transitionAnimator)
        
    }
    
    @objc private func popupViewPanned(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            
            animateTransitionIfNeeded(to: currentState.opposite, duration: 1)
            animators.forEach { $0.pauseAnimation() }
            
            animatorProgress = animators.map { $0.fractionComplete }
            
        case .changed:
            
            let translation = recognizer.translation(in: popupView)
            var fraction = -translation.y / popupOffset
            
            if currentState == .open || animators[0].isReversed { fraction *= -1 }
            
            for (index, animator) in animators.enumerated() {
                animator.fractionComplete = fraction + animatorProgress[index]
            }
            
        case .ended:
            
            let yVelocity = recognizer.velocity(in: popupView).y
            let closePopup = yVelocity > 0
            
            if yVelocity == 0 {
                animators.forEach { $0.continueAnimation(withTimingParameters: nil, durationFactor: 0) }
                break
            }
            
            switch currentState {
            case .open:
                if !closePopup && !animators[0].isReversed { animators.forEach { $0.isReversed = !$0.isReversed } }
                if closePopup && animators[0].isReversed { animators.forEach { $0.isReversed = !$0.isReversed } }
            case .closed:
                if closePopup && !animators[0].isReversed { animators.forEach { $0.isReversed = !$0.isReversed } }
                if !closePopup && animators[0].isReversed { animators.forEach { $0.isReversed = !$0.isReversed } }
            }
            
            animators.forEach { $0.continueAnimation(withTimingParameters: nil, durationFactor: 0) }
            
        default:
            ()
        }
    }
    
}

