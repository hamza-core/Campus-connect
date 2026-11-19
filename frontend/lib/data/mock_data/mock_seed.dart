import '../../domain/enums/complaint_category.dart';
import '../../domain/enums/complaint_status.dart';
import '../../domain/enums/user_role.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/complaint.dart';
import '../../domain/models/complaint_summary.dart';
import '../../domain/models/department.dart';
import '../../domain/models/timeline_entry.dart';
import 'mock_complaint_record.dart';

abstract final class MockSeed {
  static const departments = {
    ComplaintCategory.cafeteria: Department(
      id: 'cafeteria',
      name: 'Cafeteria Administration',
      slug: 'cafeteria',
    ),
    ComplaintCategory.library: Department(
      id: 'library',
      name: 'Library Administration',
      slug: 'library',
    ),
    ComplaintCategory.labsAndIt: Department(
      id: 'labit',
      name: 'Laboratory / IT Administration',
      slug: 'labit',
    ),
    ComplaintCategory.academic: Department(
      id: 'teaching',
      name: 'Teaching Manager / Academic Coordination',
      slug: 'teaching',
    ),
  };

  static const students = [
    AppUser(
      id: 'ali',
      name: 'Ali Raza',
      email: 'ali@student.com',
      role: UserRole.student,
    ),
    AppUser(
      id: 'sara',
      name: 'Sara Khan',
      email: 'sara@student.com',
      role: UserRole.student,
    ),
    AppUser(
      id: 'ahmed',
      name: 'Ahmed Malik',
      email: 'ahmed@student.com',
      role: UserRole.student,
    ),
  ];

  static Map<String, ({AppUser user, String password})> accounts() => {
    for (final (user, password) in [
      (students[0], 'Ali@1234'),
      (students[1], 'Sara@1234'),
      (students[2], 'Ahmed@1234'),
      for (final department in departments.values)
        (
          AppUser(
            id: '${department.id}-admin',
            name: department.name,
            email: '${department.slug}.admin@campus.com',
            role: UserRole.departmentAdmin,
            department: department,
          ),
          'Admin@1234',
        ),
      (
        const AppUser(
          id: 'super-admin',
          name: 'Super Admin',
          email: 'super.admin@campus.com',
          role: UserRole.superAdmin,
        ),
        'Admin@1234',
      ),
    ])
      user.email: (user: user, password: password),
  };

  static List<MockComplaintRecord> complaints(DateTime now) {
    const entries = [
      (
        'Projector not working in Lab 3',
        'The projector shows no signal during morning lectures.',
        ComplaintCategory.labsAndIt,
      ),
      (
        'Library closes too early before exams',
        'The study area closes before evening revision groups can finish.',
        ComplaintCategory.library,
      ),
      (
        'Stale food served in cafeteria',
        'The rice from the lunch counter smelled stale.',
        ComplaintCategory.cafeteria,
      ),
      (
        'Lecture notes are missing',
        'The course portal has no notes for the last two lectures.',
        ComplaintCategory.academic,
      ),
      (
        'Wi-Fi down in CS block',
        'The student network keeps disconnecting near the main lab.',
        ComplaintCategory.labsAndIt,
      ),
      (
        'Insufficient books for databases',
        'All copies of the recommended textbook are checked out.',
        ComplaintCategory.library,
      ),
      (
        'Long queue at lunch',
        'Only one counter opens during the lunch rush.',
        ComplaintCategory.cafeteria,
      ),
      (
        'Classroom speakers are distorted',
        'Students in the back cannot hear recorded lectures.',
        ComplaintCategory.academic,
      ),
      (
        'Missing lab software',
        'The lab stations do not have the software needed for the assignment.',
        ComplaintCategory.labsAndIt,
      ),
      (
        'Not enough library seating',
        'Several library desks are blocked by stored boxes.',
        ComplaintCategory.library,
      ),
      (
        'No vegetarian lunch option',
        'The cafeteria had no vegetarian main dish this week.',
        ComplaintCategory.cafeteria,
      ),
      (
        'Tutorial room change not announced',
        'The class waited at the posted room for fifteen minutes.',
        ComplaintCategory.academic,
      ),
      (
        'Keyboard broken in lab',
        'Several keys on station twelve do not register.',
        ComplaintCategory.labsAndIt,
      ),
    ];
    return List.generate(entries.length, (index) {
      final (title, description, category) = entries[index];
      final id = index + 1;
      final user =
          students[index < 7
              ? 0
              : index < 10
              ? 1
              : 2];
      final department = departments[category]!;
      final createdAt = now.subtract(Duration(days: index * 2 + 1));
      final status =
          ComplaintStatus.values[index % ComplaintStatus.values.length];
      final started =
          status == ComplaintStatus.inProgress ||
          status == ComplaintStatus.resolved;
      final terminal =
          status == ComplaintStatus.resolved ||
          status == ComplaintStatus.rejected;
      return MockComplaintRecord(
        user.id,
        Complaint(
          summary: ComplaintSummary(
            id: 'demo-$id',
            ticket: ticket(id),
            title: title,
            category: category,
            department: department,
            status: status,
            createdAt: createdAt,
          ),
          rowVersion: 'demo-version-$id-1',
          description: description,
          authorName: user.name,
          isOverdue:
              !terminal &&
              now.difference(createdAt) > const Duration(hours: 72),
          timeline: [
            TimelineEntry(
              id: '$id-created',
              type: 'CREATED',
              createdAt: createdAt,
              actorName: user.name,
              actorRole: user.role,
              toStatus: ComplaintStatus.pending,
            ),
            if (started)
              TimelineEntry(
                id: '$id-started',
                type: 'STATUS_CHANGE',
                createdAt: createdAt.add(const Duration(hours: 2)),
                actorName: department.name,
                actorRole: UserRole.departmentAdmin,
                fromStatus: ComplaintStatus.pending,
                toStatus: ComplaintStatus.inProgress,
                body: 'We are looking into this complaint.',
              ),
            if (terminal)
              TimelineEntry(
                id: '$id-closed',
                type: 'STATUS_CHANGE',
                createdAt: createdAt.add(const Duration(hours: 6)),
                actorName: department.name,
                actorRole: UserRole.departmentAdmin,
                fromStatus: started
                    ? ComplaintStatus.inProgress
                    : ComplaintStatus.pending,
                toStatus: status,
                body: started ? 'The department completed the requested work.' : 'This report duplicates an issue already assigned to the department.',
              ),
          ],
          allowedTransitions: const [],
        ),
      );
    });
  }

  static String ticket(int sequence) =>
      'CC-${sequence.toString().padLeft(4, '0')}';
}
