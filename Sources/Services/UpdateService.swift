import Foundation
import Sparkle
import Combine

final class UpdateService: ObservableObject, @unchecked Sendable {
    static let shared = UpdateService()
    
    private let updaterController: SPUStandardUpdaterController
    private var cancellables = Set<AnyCancellable>()
    
    @Published var automaticallyChecksForUpdates: Bool {
        didSet {
            updaterController.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        }
    }
    
    @Published var automaticallyDownloadsUpdates: Bool {
        didSet {
            updaterController.updater.automaticallyDownloadsUpdates = automaticallyDownloadsUpdates
        }
    }
    
    @Published var updateCheckInterval: TimeInterval {
        didSet {
            updaterController.updater.updateCheckInterval = updateCheckInterval
        }
    }
    
    private init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        
        let updater = updaterController.updater
        
        automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
        updateCheckInterval = updater.updateCheckInterval
        
        setupBindings()
    }
    
    private func setupBindings() {
        $automaticallyChecksForUpdates
            .dropFirst()
            .sink { [weak self] value in
                self?.updaterController.updater.automaticallyChecksForUpdates = value
            }
            .store(in: &cancellables)
        
        $automaticallyDownloadsUpdates
            .dropFirst()
            .sink { [weak self] value in
                self?.updaterController.updater.automaticallyDownloadsUpdates = value
            }
            .store(in: &cancellables)
        
        $updateCheckInterval
            .dropFirst()
            .sink { [weak self] value in
                self?.updaterController.updater.updateCheckInterval = value
            }
            .store(in: &cancellables)
    }
    
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
    
    func checkForUpdatesInBackground() {
        updaterController.updater.checkForUpdatesInBackground()
    }
    
    var lastUpdateCheckDate: Date? {
        updaterController.updater.lastUpdateCheckDate
    }
    
    var updateCheckIntervalInDays: Double {
        updateCheckInterval / 86400
    }
    
    func setUpdateCheckInterval(days: Double) {
        updateCheckInterval = days * 86400
    }
}
