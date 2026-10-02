//
//  ZoomableImageScrollView.swift
//  Fotoz
//
//  Pure-UIKit vertical pager + per-page zoom. Avoids nesting a zoom UIScrollView
//  inside a SwiftUI ScrollView (gesture conflicts that break zoom / blank pages).
//

import SwiftUI
import UIKit

struct VerticalImageBrowser: UIViewControllerRepresentable {
    let images: [LibraryImage]
    @Binding var currentID: LibraryImage.ID?
    let imageProvider: (LibraryImage) -> UIImage?
    let onSingleTap: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> VerticalImageBrowserController {
        let controller = VerticalImageBrowserController(
            images: images,
            currentID: currentID ?? images.first?.id,
            imageProvider: imageProvider,
            onSingleTap: onSingleTap,
            onCurrentIDChange: { id in
                DispatchQueue.main.async {
                    context.coordinator.parent.currentID = id
                }
            }
        )
        context.coordinator.controller = controller
        return controller
    }

    func updateUIViewController(_ controller: VerticalImageBrowserController, context: Context) {
        context.coordinator.parent = self
        controller.imageProvider = imageProvider
        controller.onSingleTap = onSingleTap
        controller.updateImages(images, preferredID: currentID)
    }

    final class Coordinator {
        var parent: VerticalImageBrowser
        weak var controller: VerticalImageBrowserController?

        init(parent: VerticalImageBrowser) {
            self.parent = parent
        }
    }
}

// MARK: - Browser (vertical UIPageViewController)

final class VerticalImageBrowserController: UIViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    private var images: [LibraryImage]
    var imageProvider: (LibraryImage) -> UIImage?
    var onSingleTap: () -> Void
    private let onCurrentIDChange: (LibraryImage.ID) -> Void

    private let pageController: UIPageViewController
    private var currentID: LibraryImage.ID?
    private var isPagingEnabled = true

    init(
        images: [LibraryImage],
        currentID: LibraryImage.ID?,
        imageProvider: @escaping (LibraryImage) -> UIImage?,
        onSingleTap: @escaping () -> Void,
        onCurrentIDChange: @escaping (LibraryImage.ID) -> Void
    ) {
        self.images = images
        self.currentID = currentID ?? images.first?.id
        self.imageProvider = imageProvider
        self.onSingleTap = onSingleTap
        self.onCurrentIDChange = onCurrentIDChange
        self.pageController = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .vertical,
            options: [.interPageSpacing: 0]
        )
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        pageController.dataSource = self
        pageController.delegate = self
        addChild(pageController)
        pageController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageController.view)
        NSLayoutConstraint.activate([
            pageController.view.topAnchor.constraint(equalTo: view.topAnchor),
            pageController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            pageController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        pageController.didMove(toParent: self)

        showPage(for: currentID, animated: false)
    }

    func updateImages(_ images: [LibraryImage], preferredID: LibraryImage.ID?) {
        let previous = self.images.map(\.id)
        let next = images.map(\.id)
        self.images = images

        let target = preferredID
            ?? currentID
            ?? images.first?.id

        if previous != next || currentPageController()?.imageID != target {
            currentID = target
            showPage(for: target, animated: false)
        }
    }

    private func showPage(for id: LibraryImage.ID?, animated: Bool) {
        guard let id, let index = images.firstIndex(where: { $0.id == id }) else { return }
        let direction: UIPageViewController.NavigationDirection = .forward
        let page = makePage(for: images[index])
        pageController.setViewControllers([page], direction: direction, animated: animated)
        currentID = id
    }

    private func makePage(for image: LibraryImage) -> ZoomableImagePageController {
        let page = ZoomableImagePageController(
            imageID: image.id,
            image: imageProvider(image),
            onSingleTap: { [weak self] in self?.onSingleTap() },
            onZoomedChange: { [weak self] zoomed in
                self?.setPagingEnabled(!zoomed)
            }
        )
        return page
    }

    private func currentPageController() -> ZoomableImagePageController? {
        pageController.viewControllers?.first as? ZoomableImagePageController
    }

    private func setPagingEnabled(_ enabled: Bool) {
        isPagingEnabled = enabled
        for subview in pageController.view.subviews {
            if let scrollView = subview as? UIScrollView {
                scrollView.isScrollEnabled = enabled
            }
        }
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
    ) -> UIViewController? {
        guard isPagingEnabled else { return nil }
        guard let page = viewController as? ZoomableImagePageController,
              let index = images.firstIndex(where: { $0.id == page.imageID }),
              index > 0
        else { return nil }
        return makePage(for: images[index - 1])
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
    ) -> UIViewController? {
        guard isPagingEnabled else { return nil }
        guard let page = viewController as? ZoomableImagePageController,
              let index = images.firstIndex(where: { $0.id == page.imageID }),
              index < images.count - 1
        else { return nil }
        return makePage(for: images[index + 1])
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        guard completed,
              let page = pageViewController.viewControllers?.first as? ZoomableImagePageController
        else { return }
        currentID = page.imageID
        onCurrentIDChange(page.imageID)
        setPagingEnabled(page.zoomScale <= 1.01)
    }
}

// MARK: - Zoom page

final class ZoomableImagePageController: UIViewController, UIScrollViewDelegate {
    let imageID: LibraryImage.ID
    private let image: UIImage?
    private let onSingleTap: () -> Void
    private let onZoomedChange: (Bool) -> Void

    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private var hasLaidOut = false

    var zoomScale: CGFloat { scrollView.zoomScale }

    init(
        imageID: LibraryImage.ID,
        image: UIImage?,
        onSingleTap: @escaping () -> Void,
        onZoomedChange: @escaping (Bool) -> Void
    ) {
        self.imageID = imageID
        self.image = image
        self.onSingleTap = onSingleTap
        self.onZoomedChange = onZoomedChange
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        scrollView.delegate = self
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .black
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delaysContentTouches = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.backgroundColor = .black
        scrollView.addSubview(imageView)

        // At 1x, leave vertical swipes to UIPageViewController.
        scrollView.isScrollEnabled = false
        scrollView.panGestureRecognizer.isEnabled = false

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
        singleTap.numberOfTapsRequired = 1
        singleTap.require(toFail: doubleTap)
        scrollView.addGestureRecognizer(singleTap)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard view.bounds.width > 1, view.bounds.height > 1 else { return }
        let needsFitLayout = !hasLaidOut
            || (imageView.frame.size != view.bounds.size && scrollView.zoomScale <= 1.01)
        if needsFitLayout {
            hasLaidOut = true
            layoutImageForFit()
        }
    }

    private func layoutImageForFit() {
        scrollView.zoomScale = 1
        let bounds = scrollView.bounds
        imageView.frame = CGRect(origin: .zero, size: bounds.size)
        scrollView.contentSize = bounds.size
        scrollView.contentOffset = .zero
        scrollView.isScrollEnabled = false
        scrollView.panGestureRecognizer.isEnabled = false
        centerImage()
        onZoomedChange(false)
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImage()
        let zoomed = scrollView.zoomScale > 1.01
        scrollView.isScrollEnabled = zoomed
        scrollView.panGestureRecognizer.isEnabled = zoomed
        onZoomedChange(zoomed)
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        if scale < 1.01 {
            scrollView.setZoomScale(1, animated: true)
            scrollView.isScrollEnabled = false
            scrollView.panGestureRecognizer.isEnabled = false
            centerImage()
            onZoomedChange(false)
        } else {
            scrollView.isScrollEnabled = true
            scrollView.panGestureRecognizer.isEnabled = true
            onZoomedChange(true)
        }
    }

    private func centerImage() {
        let boundsSize = scrollView.bounds.size
        var frame = imageView.frame

        if frame.width < boundsSize.width {
            frame.origin.x = (boundsSize.width - frame.width) / 2
        } else {
            frame.origin.x = 0
        }

        if frame.height < boundsSize.height {
            frame.origin.y = (boundsSize.height - frame.height) / 2
        } else {
            frame.origin.y = 0
        }

        imageView.frame = frame
    }

    @objc private func handleSingleTap() {
        onSingleTap()
    }

    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        if scrollView.zoomScale > 1.01 {
            scrollView.setZoomScale(1, animated: true)
            onZoomedChange(false)
            return
        }

        let targetScale: CGFloat = 2.5
        let point = recognizer.location(in: imageView)
        let size = scrollView.bounds.size
        let width = max(size.width / targetScale, 1)
        let height = max(size.height / targetScale, 1)
        let zoomRect = CGRect(
            x: point.x - width / 2,
            y: point.y - height / 2,
            width: width,
            height: height
        )
        scrollView.zoom(to: zoomRect, animated: true)
    }
}
