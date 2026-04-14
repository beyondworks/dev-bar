import Foundation
import Combine

@MainActor
final class BarStore: ObservableObject {
    @Published var slots: [BarSlot] = []
    @Published var groups: [WorkspaceGroup] = []

    func addSlot(_ slot: BarSlot) {
        slots.append(slot)
    }

    func removeSlot(id: UUID) {
        slots.removeAll { $0.id == id }
    }

    func updateLabel(id: UUID, label: String) {
        guard let i = slots.firstIndex(where: { $0.id == id }) else { return }
        slots[i].label = label
    }

    func updateStatus(id: UUID, status: SlotStatus) {
        guard let i = slots.firstIndex(where: { $0.id == id }) else { return }
        slots[i].status = status
    }

    func bumpBadge(id: UUID, by delta: Int = 1) {
        guard let i = slots.firstIndex(where: { $0.id == id }) else { return }
        slots[i].badgeCount = max(0, slots[i].badgeCount + delta)
    }

    func clearBadge(id: UUID) {
        guard let i = slots.firstIndex(where: { $0.id == id }) else { return }
        slots[i].badgeCount = 0
    }

    func setStashedPosition(id: UUID, _ position: CGPoint?) {
        guard let i = slots.firstIndex(where: { $0.id == id }) else { return }
        slots[i].stashedPosition = position
    }

    /// Reorder: move the slot with `sourceID` so it appears immediately before the slot with `targetID`.
    /// Returns true if anything changed.
    @discardableResult
    func move(sourceID: UUID, beforeID targetID: UUID) -> Bool {
        guard sourceID != targetID,
              let from = slots.firstIndex(where: { $0.id == sourceID }),
              let to = slots.firstIndex(where: { $0.id == targetID }) else { return false }
        let item = slots.remove(at: from)
        let insertAt = from < to ? to - 1 : to
        slots.insert(item, at: insertAt)
        return true
    }
}
