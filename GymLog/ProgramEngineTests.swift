////
////  ProgramEngineTests.swift
////  GymLog
////
////  Created by Ali Al-Khazali on 9/12/25.
////
//
//import Foundation
//import XCTest
//import SwiftData
//@testable import GymLog
//
//final class ProgramEngineTests: XCTestCase {
//    var container: ModelContainer!
//    var ctx: ModelContext!
//
//    override func setUp() {
//        super.setUp()
//        let schema = Schema([Program.self, ProgramDay.self, ProgramExercise.self,
//                             WorkoutSession.self, WorkoutEntry.self, WorkoutSet.self])
//        let config = ModelConfiguration(isStoredInMemoryOnly: true)
//        container = try! ModelContainer(for: schema, configurations: [config])
//        ctx = ModelContext(container)
//    }
//
//    override func tearDown() {
//        container = nil
//        ctx = nil
//        super.tearDown()
//    }
//
//    // زرع برنامج بسيط 3 أيام
//    @discardableResult
//    private func seedSimpleProgram() -> Program {
//        let p = Program(name: "Test PPL", isActive: true)
//        let push = ProgramDay(title: "Push", orderIndex: 0, program: p)
//        let pull = ProgramDay(title: "Pull", orderIndex: 1, program: p)
//        let legs = ProgramDay(title: "Legs", orderIndex: 2, program: p)
//        p.days = [push, pull, legs]
//        push.exercises = [ProgramExercise(name: "Bench", targetSets: 3, targetReps: 8, orderIndex: 0, day: push)]
//        pull.exercises = [ProgramExercise(name: "Row", targetSets: 3, targetReps: 8, orderIndex: 0, day: pull)]
//        legs.exercises = [ProgramExercise(name: "Squat", targetSets: 3, targetReps: 8, orderIndex: 0, day: legs)]
//        ctx.insert(p)
//        try? ctx.save()
//        return p
//    }
//
//    func testCurrentProgramDayStartsAtFirst() {
//        let p = seedSimpleProgram()
//        let day = ProgramEngine.currentProgramDay(for: p, ctx: ctx)
//        XCTAssertEqual(day?.title, "Push")
//    }
//
//    func testAdvanceToNextDayAfterCompletingSession() {
//        let p = seedSimpleProgram()
//
//        // اليوم الأول
//        var day = ProgramEngine.currentProgramDay(for: p, ctx: ctx)!
//        // أنشئ جلسة وأنهِها
//        let s1 = WorkoutSession(date: Date(), programId: p.id, dayOrderIndex: day.orderIndex, titleSnapshot: day.title, isCompleted: true)
//        ctx.insert(s1)
//        try? ctx.save()
//
//        // الآن يجب أن ينتقل لليوم التالي
//        day = ProgramEngine.currentProgramDay(for: p, ctx: ctx)!
//        XCTAssertEqual(day.title, "Pull")
//    }
//
//    func testWrapAroundAfterLegs() {
//        let p = seedSimpleProgram()
//        // أكمل Push, Pull, Legs
//        for i in 0..<3 {
//            let d = ProgramEngine.currentProgramDay(for: p, ctx: ctx)!
//            let s = WorkoutSession(date: Date(), programId: p.id, dayOrderIndex: d.orderIndex, titleSnapshot: d.title, isCompleted: true)
//            ctx.insert(s); try? ctx.save()
//            XCTAssertEqual(d.orderIndex, i)
//        }
//        // يجب أن يرجع Push
//        let next = ProgramEngine.currentProgramDay(for: p, ctx: ctx)!
//        XCTAssertEqual(next.orderIndex, 0)
//        XCTAssertEqual(next.title, "Push")
//    }
//
//    func testSkipsRestDaysByDate() {
//        let p = seedSimpleProgram()
//        // جلسة مكتملة أمس على Push
//        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
//        let push = ProgramEngine.currentProgramDay(for: p, ctx: ctx)!
//        let s = WorkoutSession(date: yesterday, programId: p.id, dayOrderIndex: push.orderIndex, titleSnapshot: push.title, isCompleted: true)
//        ctx.insert(s); try? ctx.save()
//
//        // اليوم يجب يكون Pull
//        let todayDay = ProgramEngine.currentProgramDay(for: p, ctx: ctx)!
//        XCTAssertEqual(todayDay.title, "Pull")
//    }
//}
