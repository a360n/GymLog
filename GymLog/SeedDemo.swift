//
//  SeedDemo.swift
//  GymLog
//
//  Created by Ali Al-Khazali on 9/9/25.
//

import Foundation
import SwiftData

enum SeedDemo {

    /// شغّل هذه الدالة مرة واحدة فقط (مثلاً عند كون قاعدة البيانات فاضية)
    static func run(into ctx: ModelContext) {
        // لو فيه بيانات قديمة لا نكرر الزرع
        let hasPrograms = ((try? ctx.fetch(FetchDescriptor<Program>()))?.isEmpty == false)
        if hasPrograms { return }

        // 1) برنامج 6 أشهر بنظام PPL
        let start = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        let program = Program(
            name: "Demo PPL • 6M",
            startDate: start,
            durationMonths: 6,
            isActive: true
        )

        // 2) أيّام البرنامج (PPL)
        let dayPush = ProgramDay(orderIndex: 0, title: "Push")
        let dayPull = ProgramDay(orderIndex: 1, title: "Pull")
        let dayLegs = ProgramDay(orderIndex: 2, title: "Legs")
        program.days = [dayPush, dayPull, dayLegs]

        // 3) تمارين كل يوم + العضلة المستهدفة + التكرارات لكل مجموعة
        // Push
        let exBench = ProgramExercise(
            name: "Barbell Bench Press",
            targetSets: 4, targetReps: 8, orderIndex: 0,
            perSetReps: [8, 8, 8, 8],
            targetMuscle: .chestMid
        )
        let exOHP = ProgramExercise(
            name: "Dumbbell Shoulder Press",
            targetSets: 3, targetReps: 10, orderIndex: 1,
            perSetReps: [10, 10, 10],
            targetMuscle: .deltAnterior
        )
        let exTriceps = ProgramExercise(
            name: "Cable Triceps Pushdown",
            targetSets: 3, targetReps: 12, orderIndex: 2,
            perSetReps: [12, 12, 12],
            targetMuscle: .tricepsLateral
        )
        dayPush.exercises = [exBench, exOHP, exTriceps]

        // Pull
        let exLatPulldown = ProgramExercise(
            name: "Lat Pulldown",
            targetSets: 4, targetReps: 10, orderIndex: 0,
            perSetReps: [10, 10, 10, 10],
            targetMuscle: .lats
        )
        let exRow = ProgramExercise(
            name: "Seated Cable Row",
            targetSets: 3, targetReps: 12, orderIndex: 1,
            perSetReps: [12, 12, 12],
            targetMuscle: .midBack
        )
        let exBiceps = ProgramExercise(
            name: "EZ-Bar Curl",
            targetSets: 3, targetReps: 10, orderIndex: 2,
            perSetReps: [10, 10, 10],
            targetMuscle: .bicepsShort
        )
        dayPull.exercises = [exLatPulldown, exRow, exBiceps]

        // Legs
        let exSquat = ProgramExercise(
            name: "Back Squat",
            targetSets: 4, targetReps: 6, orderIndex: 0,
            perSetReps: [6, 6, 6, 6],
            targetMuscle: .quadsVM
        )
        let exRDL = ProgramExercise(
            name: "Romanian Deadlift",
            targetSets: 3, targetReps: 8, orderIndex: 1,
            perSetReps: [8, 8, 8],
            targetMuscle: .hamBF
        )
        let exCalf = ProgramExercise(
            name: "Standing Calf Raise",
            targetSets: 4, targetReps: 12, orderIndex: 2,
            perSetReps: [12, 12, 12, 12],
            targetMuscle: .calfSoleus
        )
        dayLegs.exercises = [exSquat, exRDL, exCalf]

        ctx.insert(program)
        try? ctx.save()

        // 4) نُولّد جلسات مكتملة يومًا بعد يوم عبر 6 أشهر (مع تخطّي عشوائي خفيف)
        // ترتيب PPL يتكرر: 0,1,2 ثم يعاد
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .month, value: 6, to: start) ?? Date()
        var dayIndex = 0
        var date = start

        // قواعد أوزان مبدئية + تقدم أسبوعي بسيط
        struct Base {
            var base: Double
            var incPerWeek: Double
        }
        // خريطة اسم التمرين → قاعدة تقدم
        let baseMap: [String: Base] = [
            "Barbell Bench Press": Base(base: 50, incPerWeek: 1.0),
            "Dumbbell Shoulder Press": Base(base: 18, incPerWeek: 0.5),
            "Cable Triceps Pushdown": Base(base: 25, incPerWeek: 0.5),

            "Lat Pulldown": Base(base: 45, incPerWeek: 0.8),
            "Seated Cable Row": Base(base: 40, incPerWeek: 0.7),
            "EZ-Bar Curl": Base(base: 20, incPerWeek: 0.4),

            "Back Squat": Base(base: 70, incPerWeek: 1.5),
            "Romanian Deadlift": Base(base: 60, incPerWeek: 1.2),
            "Standing Calf Raise": Base(base: 30, incPerWeek: 0.5),
        ]

        // دالة تُعيد تمارين يوم معيّن
        func exercises(for orderIndex: Int) -> [ProgramExercise] {
            switch orderIndex {
            case 0: return dayPush.exercises
            case 1: return dayPull.exercises
            default: return dayLegs.exercises
            }
        }

        // مولّد الأوزان (يزيد أسبوعيًا، مع اختلاف بسيط بين المجموعات)
        func weight(for exName: String, on date: Date, setIndex: Int) -> Double {
            let base = baseMap[exName] ?? Base(base: 30, incPerWeek: 0.5)
            let weekNo = calendar.component(.weekOfYear, from: date)
            let inc = Double(weekNo % 52) * base.incPerWeek
            let setBump = Double(setIndex - 1) * 1.5   // زيادة صغيرة للمجموعات التالية
            let val = base.base + inc + setBump
            return round(val * 2) / 2.0                // تقريب لنصف الكيلو/الباوند
        }

        while date <= end {
            // احتمال تخطي 1 من كل 6 أيام لمحاكاة الواقع
            let skip = Int.random(in: 0..<6) == 0
            if !skip {
                let oi = dayIndex % 3
                let ddef = program.days.first(where: { $0.orderIndex == oi })!
                let session = WorkoutSession(
                    date: date,
                    programId: program.id,
                    dayOrderIndex: oi,
                    titleSnapshot: ddef.title,
                    isCompleted: true
                )
                ctx.insert(session)

                // لكل تمرين في هذا اليوم، أنشئ Entry + Sets
                // داخل حلقة إنشاء الإدخالات لكل تمرين
                for ex in exercises(for: oi) {
                    // ✅ استعمل sessionId بدل session
                    let entry = WorkoutEntry(exerciseName: ex.name, session: session)
                    // ابنِ المجموعات بدون تمرير entry في الـ init
                    var setsArr: [WorkoutSet] = []
                    for s in 1...max(1, ex.targetSets) {
                        let reps = ex.repsForSet(s)
                        let w = weight(for: ex.name, on: date, setIndex: s)
                        // ✅ لا تمرر entry هنا
                        setsArr.append(WorkoutSet(setIndex: s, reps: reps, weight: w))
                    }

                    // اربط العلاقة من جهة الـ entry (SwiftData يحدّث العكس تلقائيًا)
                    entry.sets = setsArr

                    // إن كان عندك علاقة Session.entries فعّالة:
                    session.entries.append(entry)

                    // ولو ما عندك علاقة Session.entries (لو شلتها لاحقًا)، يكفي تخلي ctx.insert(entry)
                    // ctx.insert(entry)
                }
            }

            // اليوم التالي
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            dayIndex += 1
        }

        try? ctx.save()
    }
}
