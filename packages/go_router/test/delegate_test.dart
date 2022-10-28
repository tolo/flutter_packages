// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:go_router/src/match.dart';
import 'package:go_router/src/misc/error_screen.dart';
import 'package:go_router/src/misc/errors.dart';

Future<GoRouter> createGoRouter(
  WidgetTester tester, {
  Listenable? refreshListenable,
}) async {
  final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: <GoRoute>[
      GoRoute(path: '/', builder: (_, __) => const DummyStatefulWidget()),
      GoRoute(path: '/a', builder: (_, __) => const DummyStatefulWidget()),
      GoRoute(
        path: '/error',
        builder: (_, __) => const ErrorScreen(null),
      ),
    ],
    refreshListenable: refreshListenable,
  );
  await tester.pumpWidget(MaterialApp.router(
    routerConfig: router,
  ));
  return router;
}

Future<GoRouter> createGoRouterWithStatefulShellRoute(
    WidgetTester tester) async {
  final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (_, __) => const DummyStatefulWidget()),
      GoRoute(path: '/a', builder: (_, __) => const DummyStatefulWidget()),
      StatefulShellRoute.rootRoutes(routes: <GoRoute>[
        GoRoute(
            path: '/c',
            builder: (_, __) => const DummyStatefulWidget(),
            routes: <RouteBase>[
              GoRoute(
                  path: 'c1', builder: (_, __) => const DummyStatefulWidget()),
              GoRoute(
                  path: 'c2', builder: (_, __) => const DummyStatefulWidget()),
            ]),
        GoRoute(
            path: '/d',
            builder: (_, __) => const DummyStatefulWidget(),
            routes: <RouteBase>[
              GoRoute(
                  path: 'd1', builder: (_, __) => const DummyStatefulWidget()),
            ]),
      ], builder: (_, __, Widget child) => child),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(
    routerConfig: router,
  ));
  return router;
}

void main() {
  group('pop', () {
    testWidgets('removes the last element', (WidgetTester tester) async {
      final GoRouter goRouter = await createGoRouter(tester)
        ..push('/error');

      goRouter.routerDelegate.addListener(expectAsync0(() {}));
      final RouteMatch last = goRouter.routerDelegate.matches.matches.last;
      goRouter.routerDelegate.pop();
      expect(goRouter.routerDelegate.matches.matches.length, 1);
      expect(goRouter.routerDelegate.matches.matches.contains(last), false);
    });

    testWidgets('throws when it pops more than matches count',
        (WidgetTester tester) async {
      final GoRouter goRouter = await createGoRouter(tester)
        ..push('/error');
      expect(
        () => goRouter.routerDelegate
          ..pop()
          ..pop(),
        throwsA(isAssertionError),
      );
    });
  });

  group('push', () {
    testWidgets(
      'It should return different pageKey when push is called',
      (WidgetTester tester) async {
        final GoRouter goRouter = await createGoRouter(tester);
        expect(goRouter.routerDelegate.matches.matches.length, 1);
        expect(
          goRouter.routerDelegate.matches.matches[0].pageKey,
          null,
        );

        goRouter.push('/a');
        await tester.pumpAndSettle();

        expect(goRouter.routerDelegate.matches.matches.length, 2);
        expect(
          goRouter.routerDelegate.matches.matches[1].pageKey,
          const Key('/a-p1'),
        );

        goRouter.push('/a');
        await tester.pumpAndSettle();

        expect(goRouter.routerDelegate.matches.matches.length, 3);
        expect(
          goRouter.routerDelegate.matches.matches[2].pageKey,
          const Key('/a-p2'),
        );
      },
    );

    testWidgets(
      'It should throw GoError if pushing a route that is descendant of a '
      'different StatefulShellRoute branch',
      (WidgetTester tester) async {
        final GoRouter goRouter =
            await createGoRouterWithStatefulShellRoute(tester);
        goRouter.push('/c/c1');
        await tester.pumpAndSettle();

        expect(
          () => goRouter.push('/d/d1'),
          throwsA(isA<GoError>()),
        );
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'It should throw GoError if pushing a route that is not descendant of '
      'the current StatefulShellRoute',
      (WidgetTester tester) async {
        final GoRouter goRouter =
            await createGoRouterWithStatefulShellRoute(tester);
        goRouter.push('/c/c1');
        await tester.pumpAndSettle();

        expect(
          () => goRouter.push('/a'),
          throwsA(isA<GoError>()),
        );
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'It should successfully push a route that is a descendant of the current '
      'StatefulShellRoute branch',
      (WidgetTester tester) async {
        final GoRouter goRouter = await createGoRouter(tester);
        goRouter.push('/c/c1');
        await tester.pumpAndSettle();

        goRouter.push('/c/c2');
        await tester.pumpAndSettle();

        expect(goRouter.routerDelegate.matches.matches.length, 3);
        expect(
          goRouter.routerDelegate.matches.matches[2].pageKey,
          const Key('/c/c2-p1'),
        );
      },
    );
  });

  group('canPop', () {
    testWidgets(
      'It should return false if there is only 1 match in the stack',
      (WidgetTester tester) async {
        final GoRouter goRouter = await createGoRouter(tester);

        await tester.pumpAndSettle();
        expect(goRouter.routerDelegate.matches.matches.length, 1);
        expect(goRouter.routerDelegate.canPop(), false);
      },
    );
    testWidgets(
      'It should return true if there is more than 1 match in the stack',
      (WidgetTester tester) async {
        final GoRouter goRouter = await createGoRouter(tester)
          ..push('/a');

        await tester.pumpAndSettle();
        expect(goRouter.routerDelegate.matches.matches.length, 2);
        expect(goRouter.routerDelegate.canPop(), true);
      },
    );
  });

  group('replace', () {
    testWidgets(
      'It should replace the last match with the given one',
      (WidgetTester tester) async {
        final GoRouter goRouter = GoRouter(
          initialLocation: '/',
          routes: <GoRoute>[
            GoRoute(path: '/', builder: (_, __) => const SizedBox()),
            GoRoute(path: '/page-0', builder: (_, __) => const SizedBox()),
            GoRoute(path: '/page-1', builder: (_, __) => const SizedBox()),
          ],
        );
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: goRouter,
          ),
        );

        goRouter.push('/page-0');

        goRouter.routerDelegate.addListener(expectAsync0(() {}));
        final RouteMatch first = goRouter.routerDelegate.matches.matches.first;
        final RouteMatch last = goRouter.routerDelegate.matches.last;
        goRouter.replace('/page-1');
        expect(goRouter.routerDelegate.matches.matches.length, 2);
        expect(
          goRouter.routerDelegate.matches.matches.first,
          first,
          reason: 'The first match should still be in the list of matches',
        );
        expect(
          goRouter.routerDelegate.matches.last,
          isNot(last),
          reason: 'The last match should have been removed',
        );
        expect(
          goRouter.routerDelegate.matches.last.fullpath,
          '/page-1',
          reason: 'The new location should have been pushed',
        );
      },
    );
  });

  group('replaceNamed', () {
    testWidgets(
      'It should replace the last match with the given one',
      (WidgetTester tester) async {
        final GoRouter goRouter = GoRouter(
          initialLocation: '/',
          routes: <GoRoute>[
            GoRoute(path: '/', builder: (_, __) => const SizedBox()),
            GoRoute(
                path: '/page-0',
                name: 'page0',
                builder: (_, __) => const SizedBox()),
            GoRoute(
                path: '/page-1',
                name: 'page1',
                builder: (_, __) => const SizedBox()),
          ],
        );
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: goRouter,
          ),
        );

        goRouter.pushNamed('page0');

        goRouter.routerDelegate.addListener(expectAsync0(() {}));
        final RouteMatch first = goRouter.routerDelegate.matches.matches.first;
        final RouteMatch last = goRouter.routerDelegate.matches.last;
        goRouter.replaceNamed('page1');
        expect(goRouter.routerDelegate.matches.matches.length, 2);
        expect(
          goRouter.routerDelegate.matches.matches.first,
          first,
          reason: 'The first match should still be in the list of matches',
        );
        expect(
          goRouter.routerDelegate.matches.last,
          isNot(last),
          reason: 'The last match should have been removed',
        );
        expect(
          goRouter.routerDelegate.matches.last,
          isA<RouteMatch>()
              .having(
                (RouteMatch match) => match.fullpath,
                'match.fullpath',
                '/page-1',
              )
              .having(
                (RouteMatch match) => (match.route as GoRoute).name,
                'match.route.name',
                'page1',
              ),
          reason: 'The new location should have been pushed',
        );
      },
    );
  });

  testWidgets('dispose unsubscribes from refreshListenable',
      (WidgetTester tester) async {
    final FakeRefreshListenable refreshListenable = FakeRefreshListenable();
    final GoRouter goRouter =
        await createGoRouter(tester, refreshListenable: refreshListenable);
    await tester.pumpWidget(Container());
    goRouter.dispose();
    expect(refreshListenable.unsubscribed, true);
  });
}

class FakeRefreshListenable extends ChangeNotifier {
  bool unsubscribed = false;

  @override
  void removeListener(VoidCallback listener) {
    unsubscribed = true;
    super.removeListener(listener);
  }
}

class DummyStatefulWidget extends StatefulWidget {
  const DummyStatefulWidget({super.key});

  @override
  State<DummyStatefulWidget> createState() => _DummyStatefulWidgetState();
}

class _DummyStatefulWidgetState extends State<DummyStatefulWidget> {
  @override
  Widget build(BuildContext context) => Container();
}
