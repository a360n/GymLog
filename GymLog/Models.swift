import Foundation
import SwiftData

@Model
final class Program {
    @Attribute(.unique) var id: UUID
    var name: String
    var startDate: Date
    var durationMonths: Int
    var isActive: Bool
    @Relationship(deleteRule: .cascade) var days: [ProgramDay] = []

    init(id: UUID = UUID(), name: String, startDate: Date, durationMonths: Int, isActive: Bool) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.durationMonths = durationMonths
        self.isActive = isActive
    }
}

@Model
final class ProgramDay {
    @Attribute(.unique) var id: UUID
    var orderIndex: Int
    var title: String
    @Relationship(inverse: \Program.days) var program: Program?
    @Relationship(deleteRule: .cascade) var exercises: [ProgramExercise] = []

    init(id: UUID = UUID(), orderIndex: Int, title: String) {
        self.id = id
        self.orderIndex = orderIndex
        self.title = title
    }
}
enum TargetMuscle: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }

    // ⬇️ Comprehensive list of muscle subdivisons
    case bicepsLong        = "Biceps • Long head"
    case bicepsShort       = "Biceps • Short head"
    case brachialis        = "Biceps • Brachialis"

    case tricepsLong       = "Triceps • Long head"
    case tricepsLateral    = "Triceps • Lateral head"
    case tricepsMedial     = "Triceps • Medial head"

    case forearmFlexors    = "Forearms • Flexors"
    case forearmExtensors  = "Forearms • Extensors"
    case brachioradialis   = "Forearms • Brachioradialis"

    case deltAnterior      = "Shoulders • Anterior"
    case deltLateral       = "Shoulders • Lateral"
    case deltPosterior     = "Shoulders • Posterior"

    case chestUpper        = "Chest • Upper"
    case chestMid          = "Chest • Mid"
    case chestLower        = "Chest • Lower"

    case lats              = "Back • Lats"
    case upperBack         = "Back • Upper"
    case midBack           = "Back • Mid"
    case lowerBack         = "Back • Lower"

    case quadsRF           = "Thighs • Rectus Femoris"
    case quadsVL           = "Thighs • Vastus Lateralis"
    case quadsVM           = "Thighs • Vastus Medialis"
    case hamBF             = "Thighs • Biceps Femoris"
    case hamST             = "Thighs • Semitendinosus"
    case hamSM             = "Thighs • Semimembranosus"
    case gluteMax          = "Glutes • Maximus"
    case gluteMed          = "Glutes • Medius"

    case calfGastroMed     = "Calves • Gastrocnemius (Medial)"
    case calfGastroLat     = "Calves • Gastrocnemius (Lateral)"
    case calfSoleus        = "Calves • Soleus"

    var group: String {
        if rawValue.hasPrefix("Biceps") { return "Biceps" }
        if rawValue.hasPrefix("Triceps") { return "Triceps" }
        if rawValue.hasPrefix("Forearms") { return "Forearms" }
        if rawValue.hasPrefix("Shoulders") { return "Shoulders" }
        if rawValue.hasPrefix("Chest") { return "Chest" }
        if rawValue.hasPrefix("Back") { return "Back" }
        if rawValue.hasPrefix("Thighs") { return "Thighs" }
        if rawValue.hasPrefix("Glutes") { return "Glutes" }
        if rawValue.hasPrefix("Calves") { return "Calves" }
        return "Other"
    }

    var display: String { rawValue }
}
// Models.swift
@Model
final class ProgramExercise {
    @Attribute(.unique) var id: UUID
    var name: String
    var targetSets: Int
    var targetReps: Int
    var orderIndex: Int
    @Relationship(inverse: \ProgramDay.exercises) var day: ProgramDay?

    var perSetReps: [Int] = []

    // NEW: persist as raw string
    var targetMuscleRaw: String = TargetMuscle.chestMid.rawValue 

    init(
        id: UUID = UUID(),
        name: String,
        targetSets: Int,
        targetReps: Int,
        orderIndex: Int = 0,
        perSetReps: [Int] = [],
        targetMuscle: TargetMuscle = .chestMid
    ) {
        self.id = id
        self.name = name
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.orderIndex = orderIndex
        self.perSetReps = perSetReps
        self.targetMuscleRaw = targetMuscle.rawValue
    }
}

extension ProgramExercise {
    var targetMuscle: TargetMuscle {
        get { TargetMuscle(rawValue: targetMuscleRaw) ?? .chestMid }
        set { targetMuscleRaw = newValue.rawValue }
    }

    func repsForSet(_ setIndex: Int) -> Int {
        let i = setIndex - 1
        guard i >= 0, i < perSetReps.count else { return targetReps }
        return perSetReps[i]
    }
}

// Helper you can put at bottom of Models.swift
//extension ProgramExercise {
//    /// 1-based setIndex -> reps
//    func repsForSet(_ setIndex: Int) -> Int {
//        let i = setIndex - 1
//        if i >= 0, i < perSetReps.count { return perSetReps[i] }
//        return targetReps
//    }
//}


@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var date: Date
    var programId: UUID
    var isSkipped: Bool = false
    var dayOrderIndex: Int
    var titleSnapshot: String
    var isCompleted: Bool
    @Relationship(deleteRule: .cascade) var entries: [WorkoutEntry] = []

    init(id: UUID = UUID(), date: Date, programId: UUID, dayOrderIndex: Int, titleSnapshot: String, isCompleted: Bool) {
        self.id = id
        self.date = date
        self.programId = programId
        self.dayOrderIndex = dayOrderIndex
        self.titleSnapshot = titleSnapshot
        self.isCompleted = isCompleted
    }
}

// WorkoutSet: Includes RPE and an optional note
@Model
final class WorkoutSet {
    @Attribute(.unique) var id: UUID
    var setIndex: Int // 1..N
    var reps: Int
    var weight: Double

    // NEW
    var rpe: Int?        // 1..10
    var note: String?    // short comment

    @Relationship(inverse: \WorkoutEntry.sets) var entry: WorkoutEntry?

    init(id: UUID = UUID(), setIndex: Int, reps: Int, weight: Double, entry: WorkoutEntry? = nil, rpe: Int? = nil, note: String? = nil) {
        self.id = id
        self.setIndex = setIndex
        self.reps = reps
        self.weight = weight
        self.entry = entry
        self.rpe = rpe
        self.note = note
    }
}

// WorkoutEntry: PR flags
@Model
final class WorkoutEntry {
    @Attribute(.unique) var id: UUID
    var exerciseName: String
    @Relationship(deleteRule: .cascade) var sets: [WorkoutSet] = []
    @Relationship(inverse: \WorkoutSession.entries) var session: WorkoutSession?

    // Snapshot identifiers & metadata (optional)
    var programExerciseId: UUID?
    var targetMuscleAtLogRaw: String?
    var exerciseDisplayNameAtLog: String?
    var targetSetsAtLog: Int?
    var targetRepsAtLog: Int?
    var estimatedOneRM: Double?

    // NEW: PR flags
    var prMaxWeight: Bool = false
    var prVolume: Bool = false
    var prOneRM: Bool = false

    // Initialize default values for PR flags
    init(id: UUID = UUID(), exerciseName: String, session: WorkoutSession? = nil) {
        self.id = id
        self.exerciseName = exerciseName
        self.session = session
        self.prMaxWeight = false
        self.prVolume = false
        self.prOneRM = false

        self.programExerciseId = nil
        self.targetMuscleAtLogRaw = nil
        self.exerciseDisplayNameAtLog = exerciseName
        self.targetSetsAtLog = nil
        self.targetRepsAtLog = nil
        self.estimatedOneRM = nil
    }


}

