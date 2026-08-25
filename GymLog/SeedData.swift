////
////  SeedData.swift
////  GymLog
////
////  Created by Ali Al-Khazali on 9/9/25.
////
//
//import Foundation
//import SwiftData
//
//enum SeedData {
//    static func seed(into ctx: ModelContext) {
//        let program = Program(name: "برنامج 6 أشهر", startDate: Date(), durationMonths: 6, isActive: true)
//
//        let day1 = ProgramDay(orderIndex: 0, title: "صدر وبايسبس")
//        day1.exercises = [
//            ProgramExercise(name: "بنش بريس", targetSets: 4, targetReps: 10),
//            ProgramExercise(name: "دمبل بايسبس", targetSets: 3, targetReps: 12)
//        ]
//
//        let day2 = ProgramDay(orderIndex: 1, title: "ظهر وترايسبس")
//        day2.exercises = [
//            ProgramExercise(name: "سحب علوي", targetSets: 4, targetReps: 10),
//            ProgramExercise(name: "ترايسبس كيبل", targetSets: 3, targetReps: 12)
//        ]
//
//        let day3 = ProgramDay(orderIndex: 2, title: "كتف وساقين")
//        day3.exercises = [
//            ProgramExercise(name: "شوْلدر برس", targetSets: 4, targetReps: 10),
//            ProgramExercise(name: "سكوات", targetSets: 4, targetReps: 8)
//        ]
//
//        program.days = [day1, day2, day3]
//        ctx.insert(program)
//        try? ctx.save()
//    }
//}
