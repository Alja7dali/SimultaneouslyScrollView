import Combine
import UIKit

/// Factory class to create `SimultaneouslyScrollViewHandler` instance
public final class SimultaneouslyScrollViewHandlerFactory: NSObject, SimultaneouslyScrollViewHandler {
  private var scrollViewsStore: WeakObjectStore<UIScrollView> = WeakObjectStore()
  private var scrollingScrollView: UIScrollView?
  
  private let scrolledToBottomSubject = PassthroughSubject<Bool, Never>()
  
  public var scrolledToBottomPublisher: AnyPublisher<Bool, Never> {
    scrolledToBottomSubject.eraseToAnyPublisher()
  }
  
  public func register(scrollView: UIScrollView) {
    guard !scrollViewsStore.contains(scrollView) else {
      return
    }
    
    scrollView.delegate = self
    scrollViewsStore.append(scrollView)
    
    // Scroll the new `ScrollView` to the current position of the others.
    // Using the first `ScrollView` should be enough as all should be synchronized at this point already.
    guard let currentContentOffset = scrollViewsStore.allObjects.first?.contentOffset else {
      return
    }
    scrollView.setContentOffset(currentContentOffset, animated: false)
    
    checkIsContentOffsetAtBottom()
  }
  
  public func scrollAllToBottom(animated: Bool) {
    guard !scrollViewsStore.allObjects.isEmpty,
          let scrollView = scrollViewsStore.allObjects.first,
          scrollView.hasContentToFillScrollView else {
            return
          }
    
    let bottomContentOffset = CGPoint(
      x: 0,
      y: scrollView.contentSize.height - scrollView.bounds.height + scrollView.contentInset.bottom
    )
    
    scrollViewsStore.allObjects
      .forEach { $0.setContentOffset(bottomContentOffset, animated: animated) }
  }
  
  private func checkIsContentOffsetAtBottom() {
    guard !scrollViewsStore.allObjects.isEmpty,
          let scrollView = scrollViewsStore.allObjects.first,
          scrollView.hasContentToFillScrollView else {
            scrolledToBottomSubject.send(true)
            return
          }
    
    if scrollView.isAtBottom {
      scrolledToBottomSubject.send(true)
    } else {
      scrolledToBottomSubject.send(false)
    }
  }
}

extension SimultaneouslyScrollViewHandlerFactory: UIScrollViewDelegate {
  public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    scrollingScrollView = scrollView
  }
  
  public func scrollViewDidScroll(_ scrollView: UIScrollView) {
    checkIsContentOffsetAtBottom()
    
    guard scrollingScrollView == scrollView else {
      return
    }
    
    scrollViewsStore.allObjects
      .filter { $0 != scrollingScrollView }
      .forEach { $0.setContentOffset(scrollView.contentOffset, animated: false) }
  }
  
  public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    scrollingScrollView = nil
  }
}

extension SimultaneouslyScrollViewHandlerFactory {
    /// Creates a new `SimultaneouslyScrollViewHandler` instance
    /// - Returns: A new `SimultaneouslyScrollViewHandler` instance
    public static func create() -> Self {
      Self()
    }
}