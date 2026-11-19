import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project/core/config/app_config.dart';
import 'package:project/core/errors/app_exception.dart';
import 'package:project/di/app_dependencies.dart';
import 'package:project/domain/enums/complaint_category.dart';
import 'package:project/domain/enums/complaint_status.dart';
import 'package:project/domain/models/complaint.dart';

void main() {
  test('Live submission sends category and omits device-only photos', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/auth/login')) {
        return http.Response(
          '{"data":{"token":"jwt","user":{"id":"1","name":"Ali","email":"ali@student.com","role":"STUDENT"}}}',
          200,
        );
      }
      expect(request.url.path, '/api/v1/complaints');
      expect(request.headers['Authorization'], 'Bearer jwt');
      expect(jsonDecode(request.body), {
        'category': 'LIBRARY',
        'title': 'Library lights',
        'description': 'The upstairs lights do not turn on.',
      });
      return http.Response(
        '{"data":{"id":"1","ticket":"CC-2026-0001","title":"Library lights","description":"The upstairs lights do not turn on.","category":"LIBRARY","department":{"id":"lib","name":"Library","slug":"library"},"status":"PENDING","createdAt":"2026-11-19T09:00:00Z","rowVersion":"version"}}',
        201,
      );
    });
    addTearDown(client.close);
    final live = AppDependencies.create(
      const AppConfig(
        apiBaseUrl: 'https://example.test/api/v1',
        useMock: false,
      ),
      client: client,
    );
    await live.auth.login(
      email: 'ali@student.com',
      password: 'example-password',
    );
    final complaint = await live.complaints.submit(
      category: ComplaintCategory.library,
      title: 'Library lights',
      description: 'The upstairs lights do not turn on.',
    );
    expect(complaint.summary.department.id, 'lib');
    expect(complaint.timeline, isEmpty);
  });

  late AppDependencies dependencies;
  setUp(() {
    dependencies = AppDependencies.create(
      const AppConfig(apiBaseUrl: '', useMock: true),
    );
  });

  test(
    'Mock data keeps student complaints private and routes new complaints',
    () async {
      await dependencies.auth.login(
        email: 'ali@student.com',
        password: 'Ali@1234',
      );
      final firstPage = await dependencies.complaints.list(pageSize: 3);
      expect(firstPage.total, 7);
      expect(firstPage.items, hasLength(3));
      expect(firstPage.hasNextPage, isTrue);
      await expectLater(
        dependencies.complaints.detail('demo-8'),
        throwsA(isA<ForbiddenException>()),
      );
      await expectLater(
        dependencies.dashboard.summary(),
        throwsA(isA<ForbiddenException>()),
      );

      final newComplaint = await dependencies.complaints.submit(
        category: ComplaintCategory.library,
        title: 'Library lights are broken',
        description:
            'The lights above the upstairs reading desks do not turn on.',
      );
      expect(newComplaint.summary.department.id, 'library');
      expect((await dependencies.complaints.list()).total, 8);
      expect(
        Complaint.fromJson(newComplaint.toJson()).summary.ticket,
        newComplaint.summary.ticket,
      );
    },
  );

  test(
    'Mock department access enforces scope, remarks and row versions',
    () async {
      await dependencies.auth.login(
        email: 'library.admin@campus.com',
        password: 'Admin@1234',
      );
      await expectLater(
        dependencies.complaints.detail('demo-1'),
        throwsA(isA<ForbiddenException>()),
      );
      final complaint = await dependencies.complaints.detail('demo-2');
      final id = complaint.summary.id;
      expect(complaint.allowedTransitions, contains(ComplaintStatus.rejected));
      await expectLater(
        dependencies.complaints.updateStatus(
          id: id,
          rowVersion: complaint.rowVersion,
          status: ComplaintStatus.rejected,
        ),
        throwsA(isA<ValidationException>()),
      );
      final updated = await dependencies.complaints.updateStatus(
        id: id,
        rowVersion: complaint.rowVersion,
        status: ComplaintStatus.rejected,
        remark: 'This complaint duplicates a report already assigned.',
      );
      expect(updated.summary.status, ComplaintStatus.rejected);
      expect(updated.allowedTransitions, isEmpty);
      await expectLater(
        dependencies.complaints.updateStatus(
          id: id,
          rowVersion: complaint.rowVersion,
          status: ComplaintStatus.resolved,
        ),
        throwsA(isA<ConflictException>()),
      );
      final stats = await dependencies.dashboard.byDepartment();
      expect(stats.single.department.id, 'library');
    },
  );
}
