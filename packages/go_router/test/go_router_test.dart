// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: cascade_invocations, diagnostic_describe_all_properties

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:go_router/src/match.dart';
import 'package:logging/logging.dart';

import 'test_helpers.dart';

const bool enableLogs = true;
final Logger log = Logger('GoRouter tests');

Future<void> sendPlatformUrl(String url) async {
  final Map<String, dynamic> testRouteInformation = <String, dynamic>{
    'location': url,
  };
  final ByteData message = const JSONMethodCodec().encodeMethodCall(
    MethodCall('pushRouteInformation', testRouteInformation),
  );
  await ServicesBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage('flutter/navigation', message, (_) {});
}

void main() {
  if (enableLogs) {
    Logger.root.onRecord.listen((LogRecord e) => debugPrint('$e'));
  }

  group('path routes', () {
    testWidgets('match home route', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
            path: '/',
            builder: (BuildContext context, GoRouterState state) =>
                const HomeScreen()),
      ];

      final GoRouter router = await createRouter(routes, tester);
      final List<RouteMatch> matches = router.routerDelegate.matches.matches;
      expect(matches, hasLength(1));
      expect(matches.first.fullpath, '/');
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('If there is more than one route to match, use the first match',
        (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(path: '/', builder: dummy),
        GoRoute(path: '/', builder: dummy),
      ];

      final GoRouter router = await createRouter(routes, tester);
      router.go('/');
      final List<RouteMatch> matches = router.routerDelegate.matches.matches;
      expect(matches, hasLength(1));
      expect(matches.first.fullpath, '/');
      expect(find.byType(DummyScreen), findsOneWidget);
    });

    test('empty path', () {
      expect(() {
        GoRoute(path: '');
      }, throwsA(isAssertionError));
    });

    test('leading / on sub-route', () {
      expect(() {
        GoRoute(
          path: '/',
          builder: dummy,
          routes: <GoRoute>[
            GoRoute(
              path: '/foo',
              builder: dummy,
            ),
          ],
        );
      }, throwsA(isAssertionError));
    });

    test('trailing / on sub-route', () {
      expect(() {
        GoRoute(
          path: '/',
          builder: dummy,
          routes: <GoRoute>[
            GoRoute(
              path: 'foo/',
              builder: dummy,
            ),
          ],
        );
      }, throwsA(isAssertionError));
    });

    testWidgets('lack of leading / on top-level route',
        (WidgetTester tester) async {
      await expectLater(() async {
        final List<GoRoute> routes = <GoRoute>[
          GoRoute(path: 'foo', builder: dummy),
        ];
        await createRouter(routes, tester);
      }, throwsA(isAssertionError));
    });

    testWidgets('match no routes', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(path: '/', builder: dummy),
      ];

      final GoRouter router = await createRouter(routes, tester);
      router.go('/foo');
      await tester.pumpAndSettle();
      final List<RouteMatch> matches = router.routerDelegate.matches.matches;
      expect(matches, hasLength(1));
      expect(find.byType(TestErrorScreen), findsOneWidget);
    });

    testWidgets('match 2nd top level route', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
            path: '/',
            builder: (BuildContext context, GoRouterState state) =>
                const HomeScreen()),
        GoRoute(
            path: '/login',
            builder: (BuildContext context, GoRouterState state) =>
                const LoginScreen()),
      ];

      final GoRouter router = await createRouter(routes, tester);
      router.go('/login');
      await tester.pumpAndSettle();
      final List<RouteMatch> matches = router.routerDelegate.matches.matches;
      expect(matches, hasLength(1));
      expect(matches.first.subloc, '/login');
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('match 2nd top level route with subroutes',
        (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
                path: 'page1',
                builder: (BuildContext context, GoRouterState state) =>
                    const Page1Screen())
          ],
        ),
        GoRoute(
            path: '/login',
            builder: (BuildContext context, GoRouterState state) =>
                const LoginScreen()),
      ];

      final GoRouter router = await createRouter(routes, tester);
      router.go('/login');
      await tester.pumpAndSettle();
      final List<RouteMatch> matches = router.routerDelegate.matches.matches;
      expect(matches, hasLength(1));
      expect(matches.first.subloc, '/login');
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('match top level route when location has trailing /',
        (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (BuildContext context, GoRouterState state) =>
              const LoginScreen(),
        ),
      ];

      final GoRouter router = await createRouter(routes, tester);
      router.go('/login/');
      await tester.pumpAndSettle();
      final List<RouteMatch> matches = router.routerDelegate.matches.matches;
      expect(matches, hasLength(1));
      expect(matches.first.subloc, '/login');
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('match top level route when location has trailing / (2)',
        (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
            path: '/profile',
            builder: dummy,
            redirect: (_, __) => '/profile/foo'),
        GoRoute(path: '/profile/:kind', builder: dummy),
      ];

      final GoRouter router = await createRouter(routes, tester);
      router.go('/profile/');
      await tester.pumpAndSettle();
      final List<RouteMatch> matches = router.routerDelegate.matches.matches;
      expect(matches, hasLength(1));
      expect(matches.first.subloc, '/profile/foo');
      expect(find.byType(DummyScreen), findsOneWidget);
    });

    testWidgets('match top level route when location has trailing / (3)',
        (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
            path: '/profile',
            builder: dummy,
            redirect: (_, __) => '/profile/foo'),
        GoRoute(path: '/profile/:kind', builder: dummy),
      ];

      final GoRouter router = await createRouter(routes, tester);
      router.go('/profile/?bar=baz');
      await tester.pumpAndSettle();
      final List<RouteMatch> matches = router.routerDelegate.matches.matches;
      expect(matches, hasLength(1));
      expect(matches.first.subloc, '/profile/foo');
      expect(find.byType(DummyScreen), findsOneWidget);
    });

    testWidgets('can access GoRouter parameters from builder',
        (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(path: '/', redirect: (_, __) => '/1'),
        GoRoute(
            path: '/:id',
            builder: (BuildContext context, GoRouterState state) {
              return Text(GoRouter.of(context).location);
            }),
      ];

      final GoRouter router = await createRouter(routes, tester);
      expect(find.text('/1'), findsOneWidget);
      router.go('/123?id=456');
      await tester.pumpAndSettle();
      expect(find.text('/123?id=456'), findsOneWidget);
    });

    testWidgets('can access GoRouter parameters from error builder',
        (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(path: '/', builder: dummy),
      ];

      final GoRouter router = await createRouter(routes, tester,
          errorBuilder: (BuildContext context, GoRouterState state) {
        return Text(GoRouter.of(context).location);
      });
      router.go('/123?id=456');
      await tester.pumpAndSettle();
      expect(find.text('/123?id=456'), findsOneWidget);
      router.go('/1234?id=456');
      await tester.pumpAndSettle();
      expect(find.text('/1234?id=456'), findsOneWidget);
    });

    testWidgets('match sub-route', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'login',
              builder: (BuildContext context, GoRouterState state) =>
                  const LoginScreen(),
            ),
          ],
        ),
      ];

      final GoRouter router = await createRouter(routes, tester);
      router.go('/login');
      await tester.pumpAndSettle();
      final List<RouteMatch> matches = router.routerDelegate.matches.matches;
      expect(matches.length, 2);
      expect(matches.first.subloc, '/');
      expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);
      expect(matches[1].subloc, '/login');
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('match sub-routes', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'family/:fid',
              builder: (BuildContext context, GoRouterState state) =>
                  const FamilyScreen('dummy'),
              routes: <GoRoute>[
                GoRoute(
                  path: 'person/:pid',
                  builder: (BuildContext context, GoRouterState state) =>
                      const PersonScreen('dummy', 'dummy'),
                ),
              ],
            ),
            GoRoute(
              path: 'login',
              builder: (BuildContext context, GoRouterState state) =>
                  const LoginScreen(),
            ),
          ],
        ),
      ];

      final GoRouter router = await createRouter(routes, tester);
      {
        final List<RouteMatch> matches = router.routerDelegate.matches.matches;
        expect(matches, hasLength(1));
        expect(matches.first.fullpath, '/');
        expect(find.byType(HomeScreen), findsOneWidget);
      }

      router.go('/login');
      await tester.pumpAndSettle();
      {
        final List<RouteMatch> matches = router.routerDelegate.matches.matches;
        expect(matches.length, 2);
        expect(matches.first.subloc, '/');
        expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);
        expect(matches[1].subloc, '/login');
        expect(find.byType(LoginScreen), findsOneWidget);
      }

      router.go('/family/f2');
      await tester.pumpAndSettle();
      {
        final List<RouteMatch> matches = router.routerDelegate.matches.matches;
        expect(matches.length, 2);
        expect(matches.first.subloc, '/');
        expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);
        expect(matches[1].subloc, '/family/f2');
        expect(find.byType(FamilyScreen), findsOneWidget);
      }

      router.go('/family/f2/person/p1');
      await tester.pumpAndSettle();
      {
        final List<RouteMatch> matches = router.routerDelegate.matches.matches;
        expect(matches.length, 3);
        expect(matches.first.subloc, '/');
        expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);
        expect(matches[1].subloc, '/family/f2');
        expect(find.byType(FamilyScreen, skipOffstage: false), findsOneWidget);
        expect(matches[2].subloc, '/family/f2/person/p1');
        expect(find.byType(PersonScreen), findsOneWidget);
      }
    });

    testWidgets('return first matching route if too many subroutes',
        (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'foo/bar',
              builder: (BuildContext context, GoRouterState state) =>
                  const FamilyScreen(''),
            ),
            GoRoute(
              path: 'bar',
              builder: (BuildContext context, GoRouterState state) =>
                  const Page1Screen(),
            ),
            GoRoute(
              path: 'foo',
              builder: (BuildContext context, GoRouterState state) =>
                  const Page2Screen(),
              routes: <GoRoute>[
                GoRoute(
                  path: 'bar',
                  builder: (BuildContext context, GoRouterState state) =>
                      const LoginScreen(),
                ),
              ],
            ),
          ],
        ),
      ];

      final GoRouter router = await createRouter(routes, tester);
      router.go('/bar');
      await tester.pumpAndSettle();
      List<RouteMatch> matches = router.routerDelegate.matches.matches;
      expect(matches, hasLength(2));
      expect(find.byType(Page1Screen), findsOneWidget);

      router.go('/foo/bar');
      await tester.pumpAndSettle();
      matches = router.routerDelegate.matches.matches;
      expect(matches, hasLength(2));
      expect(find.byType(FamilyScreen), findsOneWidget);

      router.go('/foo');
      await tester.pumpAndSettle();
      matches = router.routerDelegate.matches.matches;
      expect(matches, hasLength(2));
      expect(find.byType(Page2Screen), findsOneWidget);
    });

    testWidgets('router state', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          name: 'home',
          path: '/',
          builder: (BuildContext context, GoRouterState state) {
            expect(state.location, '/');
            expect(state.subloc, '/');
            expect(state.name, 'home');
            expect(state.path, '/');
            expect(state.fullpath, '/');
            expect(state.params, <String, String>{});
            expect(state.error, null);
            if (state.extra != null) {
              expect(state.extra! as int, 1);
            }
            return const HomeScreen();
          },
          routes: <GoRoute>[
            GoRoute(
              name: 'login',
              path: 'login',
              builder: (BuildContext context, GoRouterState state) {
                expect(state.location, '/login');
                expect(state.subloc, '/login');
                expect(state.name, 'login');
                expect(state.path, 'login');
                expect(state.fullpath, '/login');
                expect(state.params, <String, String>{});
                expect(state.error, null);
                expect(state.extra! as int, 2);
                return const LoginScreen();
              },
            ),
            GoRoute(
              name: 'family',
              path: 'family/:fid',
              builder: (BuildContext context, GoRouterState state) {
                expect(
                  state.location,
                  anyOf(<String>['/family/f2', '/family/f2/person/p1']),
                );
                expect(state.subloc, '/family/f2');
                expect(state.name, 'family');
                expect(state.path, 'family/:fid');
                expect(state.fullpath, '/family/:fid');
                expect(state.params, <String, String>{'fid': 'f2'});
                expect(state.error, null);
                expect(state.extra! as int, 3);
                return FamilyScreen(state.params['fid']!);
              },
              routes: <GoRoute>[
                GoRoute(
                  name: 'person',
                  path: 'person/:pid',
                  builder: (BuildContext context, GoRouterState state) {
                    expect(state.location, '/family/f2/person/p1');
                    expect(state.subloc, '/family/f2/person/p1');
                    expect(state.name, 'person');
                    expect(state.path, 'person/:pid');
                    expect(state.fullpath, '/family/:fid/person/:pid');
                    expect(
                      state.params,
                      <String, String>{'fid': 'f2', 'pid': 'p1'},
                    );
                    expect(state.error, null);
                    expect(state.extra! as int, 4);
                    return PersonScreen(
                        state.params['fid']!, state.params['pid']!);
                  },
                ),
              ],
            ),
          ],
        ),
      ];

      final GoRouter router = await createRouter(routes, tester);
      router.go('/', extra: 1);
      await tester.pump();
      router.push('/login', extra: 2);
      await tester.pump();
      router.push('/family/f2', extra: 3);
      await tester.pump();
      router.push('/family/f2/person/p1', extra: 4);
      await tester.pump();
    });

    testWidgets('match path case insensitively', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
        ),
        GoRoute(
          path: '/family/:fid',
          builder: (BuildContext context, GoRouterState state) =>
              FamilyScreen(state.params['fid']!),
        ),
      ];

      final GoRouter router = await createRouter(routes, tester);
      const String loc = '/FaMiLy/f2';
      router.go(loc);
      await tester.pumpAndSettle();
      final List<RouteMatch> matches = router.routerDelegate.matches.matches;

      // NOTE: match the lower case, since subloc is canonicalized to match the
      // path case whereas the location can be any case; so long as the path
      // produces a match regardless of the location case, we win!
      expect(router.location.toLowerCase(), loc.toLowerCase());

      expect(matches, hasLength(1));
      expect(find.byType(FamilyScreen), findsOneWidget);
    });

    testWidgets(
        'If there is more than one route to match, use the first match.',
        (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(path: '/', builder: dummy),
        GoRoute(path: '/page1', builder: dummy),
        GoRoute(path: '/page1', builder: dummy),
        GoRoute(path: '/:ok', builder: dummy),
      ];

      final GoRouter router = await createRouter(routes, tester);
      router.go('/user');
      await tester.pumpAndSettle();
      final List<RouteMatch> matches = router.routerDelegate.matches.matches;
      expect(matches, hasLength(1));
      expect(find.byType(DummyScreen), findsOneWidget);
    });

    testWidgets('Handles the Android back button correctly',
        (WidgetTester tester) async {
      final List<RouteBase> routes = <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) {
            return const Scaffold(
              body: Text('Screen A'),
            );
          },
          routes: <RouteBase>[
            GoRoute(
              path: 'b',
              builder: (BuildContext context, GoRouterState state) {
                return const Scaffold(
                  body: Text('Screen B'),
                );
              },
            ),
          ],
        ),
      ];

      await createRouter(routes, tester, initialLocation: '/b');
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen B'), findsOneWidget);

      await simulateAndroidBackButton(tester);
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsOneWidget);
      expect(find.text('Screen B'), findsNothing);
    });

    testWidgets('Handles the Android back button correctly with ShellRoute',
        (WidgetTester tester) async {
      final GlobalKey<NavigatorState> rootNavigatorKey =
          GlobalKey<NavigatorState>();

      final List<RouteBase> routes = <RouteBase>[
        ShellRoute(
          builder: (BuildContext context, GoRouterState state, Widget child) {
            return Scaffold(
              appBar: AppBar(title: const Text('Shell')),
              body: child,
            );
          },
          routes: <GoRoute>[
            GoRoute(
              path: '/a',
              builder: (BuildContext context, GoRouterState state) {
                return const Scaffold(
                  body: Text('Screen A'),
                );
              },
              routes: <GoRoute>[
                GoRoute(
                  path: 'b',
                  builder: (BuildContext context, GoRouterState state) {
                    return const Scaffold(
                      body: Text('Screen B'),
                    );
                  },
                  routes: <GoRoute>[
                    GoRoute(
                      path: 'c',
                      builder: (BuildContext context, GoRouterState state) {
                        return const Scaffold(
                          body: Text('Screen C'),
                        );
                      },
                      routes: <GoRoute>[
                        GoRoute(
                          path: 'd',
                          parentNavigatorKey: rootNavigatorKey,
                          builder: (BuildContext context, GoRouterState state) {
                            return const Scaffold(
                              body: Text('Screen D'),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ];

      await createRouter(routes, tester,
          initialLocation: '/a/b/c/d', navigatorKey: rootNavigatorKey);
      expect(find.text('Shell'), findsNothing);
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen B'), findsNothing);
      expect(find.text('Screen C'), findsNothing);
      expect(find.text('Screen D'), findsOneWidget);

      await simulateAndroidBackButton(tester);
      await tester.pumpAndSettle();
      expect(find.text('Shell'), findsOneWidget);
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen B'), findsNothing);
      expect(find.text('Screen C'), findsOneWidget);
      expect(find.text('Screen D'), findsNothing);

      await simulateAndroidBackButton(tester);
      await tester.pumpAndSettle();
      expect(find.text('Shell'), findsOneWidget);
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen B'), findsOneWidget);
      expect(find.text('Screen C'), findsNothing);
    });

    testWidgets(
        'Handles the Android back button when parentNavigatorKey is set to the root navigator',
        (WidgetTester tester) async {
      final List<MethodCall> log = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform,
              (MethodCall methodCall) async {
        log.add(methodCall);
        return null;
      });

      Future<void> verify(AsyncCallback test, List<Object> expectations) async {
        log.clear();
        await test();
        expect(log, expectations);
      }

      final GlobalKey<NavigatorState> rootNavigatorKey =
          GlobalKey<NavigatorState>();

      final List<RouteBase> routes = <RouteBase>[
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/a',
          builder: (BuildContext context, GoRouterState state) {
            return const Scaffold(
              body: Text('Screen A'),
            );
          },
        ),
      ];

      await createRouter(routes, tester,
          initialLocation: '/a', navigatorKey: rootNavigatorKey);
      expect(find.text('Screen A'), findsOneWidget);

      await tester.runAsync(() async {
        await verify(() => simulateAndroidBackButton(tester), <Object>[
          isMethodCall('SystemNavigator.pop', arguments: null),
        ]);
      });
    });

    testWidgets("Handles the Android back button when ShellRoute can't pop",
        (WidgetTester tester) async {
      final List<MethodCall> log = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform,
              (MethodCall methodCall) async {
        log.add(methodCall);
        return null;
      });

      Future<void> verify(AsyncCallback test, List<Object> expectations) async {
        log.clear();
        await test();
        expect(log, expectations);
      }

      final GlobalKey<NavigatorState> rootNavigatorKey =
          GlobalKey<NavigatorState>();

      final List<RouteBase> routes = <RouteBase>[
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/a',
          builder: (BuildContext context, GoRouterState state) {
            return const Scaffold(
              body: Text('Screen A'),
            );
          },
        ),
        ShellRoute(
          builder: (BuildContext context, GoRouterState state, Widget child) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Shell'),
              ),
              body: child,
            );
          },
          routes: <RouteBase>[
            GoRoute(
              path: '/b',
              builder: (BuildContext context, GoRouterState state) {
                return const Scaffold(
                  body: Text('Screen B'),
                );
              },
            ),
          ],
        ),
      ];

      await createRouter(routes, tester,
          initialLocation: '/b', navigatorKey: rootNavigatorKey);
      expect(find.text('Screen B'), findsOneWidget);

      await tester.runAsync(() async {
        await verify(() => simulateAndroidBackButton(tester), <Object>[
          isMethodCall('SystemNavigator.pop', arguments: null),
        ]);
      });
    });
  });

  testWidgets(
      'Handles the Android back button when a second Shell has a GoRoute with parentNavigator key',
      (WidgetTester tester) async {
    final List<MethodCall> log = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform,
            (MethodCall methodCall) async {
      log.add(methodCall);
      return null;
    });

    Future<void> verify(AsyncCallback test, List<Object> expectations) async {
      log.clear();
      await test();
      expect(log, expectations);
    }

    final GlobalKey<NavigatorState> rootNavigatorKey =
        GlobalKey<NavigatorState>();
    final GlobalKey<NavigatorState> shellNavigatorKeyA =
        GlobalKey<NavigatorState>();
    final GlobalKey<NavigatorState> shellNavigatorKeyB =
        GlobalKey<NavigatorState>();

    final List<RouteBase> routes = <RouteBase>[
      ShellRoute(
        navigatorKey: shellNavigatorKeyA,
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Shell'),
            ),
            body: child,
          );
        },
        routes: <RouteBase>[
          GoRoute(
            path: '/a',
            builder: (BuildContext context, GoRouterState state) {
              return const Scaffold(
                body: Text('Screen A'),
              );
            },
            routes: <RouteBase>[
              ShellRoute(
                navigatorKey: shellNavigatorKeyB,
                builder:
                    (BuildContext context, GoRouterState state, Widget child) {
                  return Scaffold(
                    appBar: AppBar(
                      title: const Text('Shell'),
                    ),
                    body: child,
                  );
                },
                routes: <RouteBase>[
                  GoRoute(
                    path: 'b',
                    parentNavigatorKey: shellNavigatorKeyB,
                    builder: (BuildContext context, GoRouterState state) {
                      return const Scaffold(
                        body: Text('Screen B'),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ];

    await createRouter(routes, tester,
        initialLocation: '/a/b', navigatorKey: rootNavigatorKey);
    expect(find.text('Screen B'), findsOneWidget);

    // The first pop should not exit the app.
    await tester.runAsync(() async {
      await verify(() => simulateAndroidBackButton(tester), <Object>[]);
    });

    // The second pop should exit the app.
    await tester.runAsync(() async {
      await verify(() => simulateAndroidBackButton(tester), <Object>[
        isMethodCall('SystemNavigator.pop', arguments: null),
      ]);
    });
  });

  group('named routes', () {
    testWidgets('match home route', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
            name: 'home',
            path: '/',
            builder: (BuildContext context, GoRouterState state) =>
                const HomeScreen()),
      ];

      final GoRouter router = await createRouter(routes, tester);
      router.goNamed('home');
    });

    testWidgets('match too many routes', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(name: 'home', path: '/', builder: dummy),
        GoRoute(name: 'home', path: '/', builder: dummy),
      ];

      await expectLater(() async {
        await createRouter(routes, tester);
      }, throwsA(isAssertionError));
    });

    test('empty name', () {
      expect(() {
        GoRoute(name: '', path: '/');
      }, throwsA(isAssertionError));
    });

    testWidgets('match no routes', (WidgetTester tester) async {
      await expectLater(() async {
        final List<GoRoute> routes = <GoRoute>[
          GoRoute(name: 'home', path: '/', builder: dummy),
        ];
        final GoRouter router = await createRouter(routes, tester);
        router.goNamed('work');
      }, throwsA(isAssertionError));
    });

    testWidgets('match 2nd top level route', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          name: 'home',
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
        ),
        GoRoute(
          name: 'login',
          path: '/login',
          builder: (BuildContext context, GoRouterState state) =>
              const LoginScreen(),
        ),
      ];

      final GoRouter router = await createRouter(routes, tester);
      router.goNamed('login');
    });

    testWidgets('match sub-route', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          name: 'home',
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              name: 'login',
              path: 'login',
              builder: (BuildContext context, GoRouterState state) =>
                  const LoginScreen(),
            ),
          ],
        ),
      ];

      final GoRouter router = await createRouter(routes, tester);
      router.goNamed('login');
    });

    testWidgets('match w/ params', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          name: 'home',
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              name: 'family',
              path: 'family/:fid',
              builder: (BuildContext context, GoRouterState state) =>
                  const FamilyScreen('dummy'),
              routes: <GoRoute>[
                GoRoute(
                  name: 'person',
                  path: 'person/:pid',
                  builder: (BuildContext context, GoRouterState state) {
                    expect(state.params,
                        <String, String>{'fid': 'f2', 'pid': 'p1'});
                    return const PersonScreen('dummy', 'dummy');
                  },
                ),
              ],
            ),
          ],
        ),
      ];

      final GoRouter router = await createRouter(routes, tester);
      router.goNamed('person',
          params: <String, String>{'fid': 'f2', 'pid': 'p1'});
    });

    testWidgets('too few params', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          name: 'home',
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              name: 'family',
              path: 'family/:fid',
              builder: (BuildContext context, GoRouterState state) =>
                  const FamilyScreen('dummy'),
              routes: <GoRoute>[
                GoRoute(
                  name: 'person',
                  path: 'person/:pid',
                  builder: (BuildContext context, GoRouterState state) =>
                      const PersonScreen('dummy', 'dummy'),
                ),
              ],
            ),
          ],
        ),
      ];
      await expectLater(() async {
        final GoRouter router = await createRouter(routes, tester);
        router.goNamed('person', params: <String, String>{'fid': 'f2'});
        await tester.pump();
      }, throwsA(isAssertionError));
    });

    testWidgets('match case insensitive w/ params',
        (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          name: 'home',
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              name: 'family',
              path: 'family/:fid',
              builder: (BuildContext context, GoRouterState state) =>
                  const FamilyScreen('dummy'),
              routes: <GoRoute>[
                GoRoute(
                  name: 'PeRsOn',
                  path: 'person/:pid',
                  builder: (BuildContext context, GoRouterState state) {
                    expect(state.params,
                        <String, String>{'fid': 'f2', 'pid': 'p1'});
                    return const PersonScreen('dummy', 'dummy');
                  },
                ),
              ],
            ),
          ],
        ),
      ];

      final GoRouter router = await createRouter(routes, tester);
      router.goNamed('person',
          params: <String, String>{'fid': 'f2', 'pid': 'p1'});
    });

    testWidgets('too few params', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          name: 'family',
          path: '/family/:fid',
          builder: (BuildContext context, GoRouterState state) =>
              const FamilyScreen('dummy'),
        ),
      ];
      await expectLater(() async {
        final GoRouter router = await createRouter(routes, tester);
        router.goNamed('family');
      }, throwsA(isAssertionError));
    });

    testWidgets('too many params', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          name: 'family',
          path: '/family/:fid',
          builder: (BuildContext context, GoRouterState state) =>
              const FamilyScreen('dummy'),
        ),
      ];
      await expectLater(() async {
        final GoRouter router = await createRouter(routes, tester);
        router.goNamed('family',
            params: <String, String>{'fid': 'f2', 'pid': 'p1'});
      }, throwsA(isAssertionError));
    });

    testWidgets('sparsely named routes', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: dummy,
          redirect: (_, __) => '/family/f2',
        ),
        GoRoute(
          path: '/family/:fid',
          builder: (BuildContext context, GoRouterState state) => FamilyScreen(
            state.params['fid']!,
          ),
          routes: <GoRoute>[
            GoRoute(
              name: 'person',
              path: 'person:pid',
              builder: (BuildContext context, GoRouterState state) =>
                  PersonScreen(
                state.params['fid']!,
                state.params['pid']!,
              ),
            ),
          ],
        ),
      ];

      final GoRouter router = await createRouter(routes, tester);
      router.goNamed('person',
          params: <String, String>{'fid': 'f2', 'pid': 'p1'});
      await tester.pumpAndSettle();
      expect(find.byType(PersonScreen), findsOneWidget);
    });

    testWidgets('preserve path param spaces and slashes',
        (WidgetTester tester) async {
      const String param1 = 'param w/ spaces and slashes';
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          name: 'page1',
          path: '/page1/:param1',
          builder: (BuildContext c, GoRouterState s) {
            expect(s.params['param1'], param1);
            return const DummyScreen();
          },
        ),
      ];

      final GoRouter router = await createRouter(routes, tester);
      final String loc = router
          .namedLocation('page1', params: <String, String>{'param1': param1});
      log.info('loc= $loc');
      router.go(loc);
      await tester.pumpAndSettle();

      final List<RouteMatch> matches = router.routerDelegate.matches.matches;
      log.info('param1= ${matches.first.decodedParams['param1']}');
      expect(find.byType(DummyScreen), findsOneWidget);
      expect(matches.first.decodedParams['param1'], param1);
    });

    testWidgets('preserve query param spaces and slashes',
        (WidgetTester tester) async {
      const String param1 = 'param w/ spaces and slashes';
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          name: 'page1',
          path: '/page1',
          builder: (BuildContext c, GoRouterState s) {
            expect(s.queryParams['param1'], param1);
            return const DummyScreen();
          },
        ),
      ];

      final GoRouter router = await createRouter(routes, tester);
      final String loc = router.namedLocation('page1',
          queryParams: <String, String>{'param1': param1});
      router.go(loc);
      await tester.pumpAndSettle();
      final List<RouteMatch> matches = router.routerDelegate.matches.matches;
      expect(find.byType(DummyScreen), findsOneWidget);
      expect(matches.first.queryParams['param1'], param1);
    });
  });

  group('redirects', () {
    testWidgets('top-level redirect', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
                path: 'dummy',
                builder: (BuildContext context, GoRouterState state) =>
                    const DummyScreen()),
            GoRoute(
                path: 'login',
                builder: (BuildContext context, GoRouterState state) =>
                    const LoginScreen()),
          ],
        ),
      ];
      bool redirected = false;

      final GoRouter router = await createRouter(routes, tester,
          redirect: (BuildContext context, GoRouterState state) {
        redirected = true;
        return state.subloc == '/login' ? null : '/login';
      });

      expect(router.location, '/login');
      expect(redirected, isTrue);

      redirected = false;
      // Directly set the url through platform message.
      await sendPlatformUrl('/dummy');

      await tester.pumpAndSettle();
      expect(router.location, '/login');
      expect(redirected, isTrue);
    });

    testWidgets('redirect can redirect to same path',
        (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
                path: 'dummy',
                // Return same location.
                redirect: (_, GoRouterState state) => state.location,
                builder: (BuildContext context, GoRouterState state) =>
                    const DummyScreen()),
          ],
        ),
      ];

      final GoRouter router = await createRouter(routes, tester,
          redirect: (BuildContext context, GoRouterState state) {
        // Return same location.
        return state.location;
      });

      expect(router.location, '/');
      // Directly set the url through platform message.
      await sendPlatformUrl('/dummy');
      await tester.pumpAndSettle();
      expect(router.location, '/dummy');
    });

    testWidgets('top-level redirect w/ named routes',
        (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          name: 'home',
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              name: 'dummy',
              path: 'dummy',
              builder: (BuildContext context, GoRouterState state) =>
                  const DummyScreen(),
            ),
            GoRoute(
              name: 'login',
              path: 'login',
              builder: (BuildContext context, GoRouterState state) =>
                  const LoginScreen(),
            ),
          ],
        ),
      ];

      final GoRouter router = await createRouter(
        routes,
        tester,
        redirect: (BuildContext context, GoRouterState state) =>
            state.subloc == '/login' ? null : state.namedLocation('login'),
      );
      expect(router.location, '/login');
    });

    testWidgets('route-level redirect', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'dummy',
              builder: (BuildContext context, GoRouterState state) =>
                  const DummyScreen(),
              redirect: (BuildContext context, GoRouterState state) => '/login',
            ),
            GoRoute(
              path: 'login',
              builder: (BuildContext context, GoRouterState state) =>
                  const LoginScreen(),
            ),
          ],
        ),
      ];

      final GoRouter router = await createRouter(routes, tester);
      router.go('/dummy');
      await tester.pump();
      expect(router.location, '/login');
    });

    testWidgets('top-level redirect take priority over route level',
        (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
                path: 'dummy',
                builder: (BuildContext context, GoRouterState state) =>
                    const DummyScreen(),
                redirect: (BuildContext context, GoRouterState state) {
                  // should never be reached.
                  assert(false);
                  return '/dummy2';
                }),
            GoRoute(
                path: 'dummy2',
                builder: (BuildContext context, GoRouterState state) =>
                    const DummyScreen()),
            GoRoute(
                path: 'login',
                builder: (BuildContext context, GoRouterState state) =>
                    const LoginScreen()),
          ],
        ),
      ];
      bool redirected = false;
      final GoRouter router = await createRouter(routes, tester,
          redirect: (BuildContext context, GoRouterState state) {
        redirected = true;
        return state.subloc == '/login' ? null : '/login';
      });
      redirected = false;
      // Directly set the url through platform message.
      await sendPlatformUrl('/dummy');

      await tester.pumpAndSettle();
      expect(router.location, '/login');
      expect(redirected, isTrue);
    });

    testWidgets('route-level redirect w/ named routes',
        (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          name: 'home',
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              name: 'dummy',
              path: 'dummy',
              builder: (BuildContext context, GoRouterState state) =>
                  const DummyScreen(),
              redirect: (BuildContext context, GoRouterState state) =>
                  state.namedLocation('login'),
            ),
            GoRoute(
              name: 'login',
              path: 'login',
              builder: (BuildContext context, GoRouterState state) =>
                  const LoginScreen(),
            ),
          ],
        ),
      ];

      final GoRouter router = await createRouter(routes, tester);
      router.go('/dummy');
      await tester.pump();
      expect(router.location, '/login');
    });

    testWidgets('multiple mixed redirect', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'dummy1',
              builder: (BuildContext context, GoRouterState state) =>
                  const DummyScreen(),
            ),
            GoRoute(
              path: 'dummy2',
              builder: (BuildContext context, GoRouterState state) =>
                  const DummyScreen(),
              redirect: (BuildContext context, GoRouterState state) => '/',
            ),
          ],
        ),
      ];

      final GoRouter router = await createRouter(routes, tester,
          redirect: (BuildContext context, GoRouterState state) =>
              state.subloc == '/dummy1' ? '/dummy2' : null);
      router.go('/dummy1');
      await tester.pump();
      expect(router.location, '/');
    });

    testWidgets('top-level redirect loop', (WidgetTester tester) async {
      final GoRouter router = await createRouter(<GoRoute>[], tester,
          redirect: (BuildContext context, GoRouterState state) =>
              state.subloc == '/'
                  ? '/login'
                  : state.subloc == '/login'
                      ? '/'
                      : null);

      final List<RouteMatch> matches = router.routerDelegate.matches.matches;
      expect(matches, hasLength(1));
      expect(find.byType(TestErrorScreen), findsOneWidget);
      final TestErrorScreen screen =
          tester.widget<TestErrorScreen>(find.byType(TestErrorScreen));
      expect(screen.ex, isNotNull);
    });

    testWidgets('route-level redirect loop', (WidgetTester tester) async {
      final GoRouter router = await createRouter(
        <GoRoute>[
          GoRoute(
            path: '/',
            builder: dummy,
            redirect: (BuildContext context, GoRouterState state) => '/login',
          ),
          GoRoute(
            path: '/login',
            builder: dummy,
            redirect: (BuildContext context, GoRouterState state) => '/',
          ),
        ],
        tester,
      );

      final List<RouteMatch> matches = router.routerDelegate.matches.matches;
      expect(matches, hasLength(1));
      expect(find.byType(TestErrorScreen), findsOneWidget);
      final TestErrorScreen screen =
          tester.widget<TestErrorScreen>(find.byType(TestErrorScreen));
      expect(screen.ex, isNotNull);
    });

    testWidgets('mixed redirect loop', (WidgetTester tester) async {
      final GoRouter router = await createRouter(
        <GoRoute>[
          GoRoute(
            path: '/login',
            builder: dummy,
            redirect: (BuildContext context, GoRouterState state) => '/',
          ),
        ],
        tester,
        redirect: (BuildContext context, GoRouterState state) =>
            state.subloc == '/' ? '/login' : null,
      );

      final List<RouteMatch> matches = router.routerDelegate.matches.matches;
      expect(matches, hasLength(1));
      expect(find.byType(TestErrorScreen), findsOneWidget);
      final TestErrorScreen screen =
          tester.widget<TestErrorScreen>(find.byType(TestErrorScreen));
      expect(screen.ex, isNotNull);
    });

    testWidgets('top-level redirect loop w/ query params',
        (WidgetTester tester) async {
      final GoRouter router = await createRouter(
        <GoRoute>[],
        tester,
        redirect: (BuildContext context, GoRouterState state) =>
            state.subloc == '/'
                ? '/login?from=${state.location}'
                : state.subloc == '/login'
                    ? '/'
                    : null,
      );

      final List<RouteMatch> matches = router.routerDelegate.matches.matches;
      expect(matches, hasLength(1));
      expect(find.byType(TestErrorScreen), findsOneWidget);
      final TestErrorScreen screen =
          tester.widget<TestErrorScreen>(find.byType(TestErrorScreen));
      expect(screen.ex, isNotNull);
    });

    testWidgets('expect null path/fullpath on top-level redirect',
        (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
        ),
        GoRoute(
          path: '/dummy',
          builder: dummy,
          redirect: (BuildContext context, GoRouterState state) => '/',
        ),
      ];

      final GoRouter router = await createRouter(
        routes,
        tester,
        initialLocation: '/dummy',
      );
      expect(router.location, '/');
    });

    testWidgets('top-level redirect state', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (BuildContext context, GoRouterState state) =>
              const LoginScreen(),
        ),
      ];

      final GoRouter router = await createRouter(
        routes,
        tester,
        initialLocation: '/login?from=/',
        redirect: (BuildContext context, GoRouterState state) {
          expect(Uri.parse(state.location).queryParameters, isNotEmpty);
          expect(Uri.parse(state.subloc).queryParameters, isEmpty);
          expect(state.path, isNull);
          expect(state.fullpath, isNull);
          expect(state.params.length, 0);
          expect(state.queryParams.length, 1);
          expect(state.queryParams['from'], '/');
          return null;
        },
      );

      final List<RouteMatch> matches = router.routerDelegate.matches.matches;
      expect(matches, hasLength(1));
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('route-level redirect state', (WidgetTester tester) async {
      const String loc = '/book/0';
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/book/:bookId',
          redirect: (BuildContext context, GoRouterState state) {
            expect(state.location, loc);
            expect(state.subloc, loc);
            expect(state.path, '/book/:bookId');
            expect(state.fullpath, '/book/:bookId');
            expect(state.params, <String, String>{'bookId': '0'});
            expect(state.queryParams.length, 0);
            return null;
          },
          builder: (BuildContext c, GoRouterState s) => const HomeScreen(),
        ),
      ];

      final GoRouter router = await createRouter(
        routes,
        tester,
        initialLocation: loc,
      );

      final List<RouteMatch> matches = router.routerDelegate.matches.matches;
      expect(matches, hasLength(1));
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('sub-sub-route-level redirect params',
        (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext c, GoRouterState s) => const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'family/:fid',
              builder: (BuildContext c, GoRouterState s) =>
                  FamilyScreen(s.params['fid']!),
              routes: <GoRoute>[
                GoRoute(
                  path: 'person/:pid',
                  redirect: (BuildContext context, GoRouterState s) {
                    expect(s.params['fid'], 'f2');
                    expect(s.params['pid'], 'p1');
                    return null;
                  },
                  builder: (BuildContext c, GoRouterState s) => PersonScreen(
                    s.params['fid']!,
                    s.params['pid']!,
                  ),
                ),
              ],
            ),
          ],
        ),
      ];

      final GoRouter router = await createRouter(
        routes,
        tester,
        initialLocation: '/family/f2/person/p1',
      );

      final List<RouteMatch> matches = router.routerDelegate.matches.matches;
      expect(matches.length, 3);
      expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);
      expect(find.byType(FamilyScreen, skipOffstage: false), findsOneWidget);
      final PersonScreen page =
          tester.widget<PersonScreen>(find.byType(PersonScreen));
      expect(page.fid, 'f2');
      expect(page.pid, 'p1');
    });

    testWidgets('redirect limit', (WidgetTester tester) async {
      final GoRouter router = await createRouter(
        <GoRoute>[],
        tester,
        redirect: (BuildContext context, GoRouterState state) =>
            '/${state.location}+',
        redirectLimit: 10,
      );

      final List<RouteMatch> matches = router.routerDelegate.matches.matches;
      expect(matches, hasLength(1));
      expect(find.byType(TestErrorScreen), findsOneWidget);
      final TestErrorScreen screen =
          tester.widget<TestErrorScreen>(find.byType(TestErrorScreen));
      expect(screen.ex, isNotNull);
    });

    testWidgets('extra not null in redirect', (WidgetTester tester) async {
      bool isCallTopRedirect = false;
      bool isCallRouteRedirect = false;

      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          name: 'home',
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              name: 'login',
              path: 'login',
              builder: (BuildContext context, GoRouterState state) {
                return const LoginScreen();
              },
              redirect: (BuildContext context, GoRouterState state) {
                isCallRouteRedirect = true;
                expect(state.extra, isNotNull);
                return null;
              },
              routes: const <GoRoute>[],
            ),
          ],
        ),
      ];

      final GoRouter router = await createRouter(
        routes,
        tester,
        redirect: (BuildContext context, GoRouterState state) {
          if (state.location == '/login') {
            isCallTopRedirect = true;
            expect(state.extra, isNotNull);
          }

          return null;
        },
      );

      router.go('/login', extra: 1);
      await tester.pump();

      expect(isCallTopRedirect, true);
      expect(isCallRouteRedirect, true);
    });

    testWidgets('parent route level redirect take priority over child',
        (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
                path: 'dummy',
                builder: (BuildContext context, GoRouterState state) =>
                    const DummyScreen(),
                redirect: (BuildContext context, GoRouterState state) =>
                    '/other',
                routes: <GoRoute>[
                  GoRoute(
                    path: 'dummy2',
                    builder: (BuildContext context, GoRouterState state) =>
                        const DummyScreen(),
                    redirect: (BuildContext context, GoRouterState state) {
                      assert(false);
                      return '/other2';
                    },
                  ),
                ]),
            GoRoute(
                path: 'other',
                builder: (BuildContext context, GoRouterState state) =>
                    const DummyScreen()),
            GoRoute(
                path: 'other2',
                builder: (BuildContext context, GoRouterState state) =>
                    const DummyScreen()),
          ],
        ),
      ];

      final GoRouter router = await createRouter(routes, tester);

      // Directly set the url through platform message.
      await sendPlatformUrl('/dummy/dummy2');

      await tester.pumpAndSettle();
      expect(router.location, '/other');
    });
  });

  group('initial location', () {
    testWidgets('initial location', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'dummy',
              builder: (BuildContext context, GoRouterState state) =>
                  const DummyScreen(),
            ),
          ],
        ),
      ];

      final GoRouter router = await createRouter(
        routes,
        tester,
        initialLocation: '/dummy',
      );
      expect(router.location, '/dummy');
    });

    testWidgets('initial location w/ redirection', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
        ),
        GoRoute(
          path: '/dummy',
          builder: dummy,
          redirect: (BuildContext context, GoRouterState state) => '/',
        ),
      ];

      final GoRouter router = await createRouter(
        routes,
        tester,
        initialLocation: '/dummy',
      );
      expect(router.location, '/');
    });

    testWidgets(
        'does not take precedence over platformDispatcher.defaultRouteName',
        (WidgetTester tester) async {
      TestWidgetsFlutterBinding
          .instance.platformDispatcher.defaultRouteNameTestValue = '/dummy';

      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'dummy',
              builder: (BuildContext context, GoRouterState state) =>
                  const DummyScreen(),
            ),
          ],
        ),
      ];

      final GoRouter router = await createRouter(
        routes,
        tester,
      );
      expect(router.routeInformationProvider.value.location, '/dummy');
      TestWidgetsFlutterBinding
          .instance.platformDispatcher.defaultRouteNameTestValue = '/';
    });
  });

  group('params', () {
    testWidgets('preserve path param case', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
        ),
        GoRoute(
          path: '/family/:fid',
          builder: (BuildContext context, GoRouterState state) =>
              FamilyScreen(state.params['fid']!),
        ),
      ];

      final GoRouter router = await createRouter(routes, tester);
      for (final String fid in <String>['f2', 'F2']) {
        final String loc = '/family/$fid';
        router.go(loc);
        await tester.pumpAndSettle();
        final List<RouteMatch> matches = router.routerDelegate.matches.matches;

        expect(router.location, loc);
        expect(matches, hasLength(1));
        expect(find.byType(FamilyScreen), findsOneWidget);
        expect(matches.first.decodedParams['fid'], fid);
      }
    });

    testWidgets('preserve query param case', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
        ),
        GoRoute(
          path: '/family',
          builder: (BuildContext context, GoRouterState state) => FamilyScreen(
            state.queryParams['fid']!,
          ),
        ),
      ];

      final GoRouter router = await createRouter(routes, tester);
      for (final String fid in <String>['f2', 'F2']) {
        final String loc = '/family?fid=$fid';
        router.go(loc);
        await tester.pumpAndSettle();
        final List<RouteMatch> matches = router.routerDelegate.matches.matches;

        expect(router.location, loc);
        expect(matches, hasLength(1));
        expect(find.byType(FamilyScreen), findsOneWidget);
        expect(matches.first.queryParams['fid'], fid);
      }
    });

    testWidgets('preserve path param spaces and slashes',
        (WidgetTester tester) async {
      const String param1 = 'param w/ spaces and slashes';
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/page1/:param1',
          builder: (BuildContext c, GoRouterState s) {
            expect(s.params['param1'], param1);
            return const DummyScreen();
          },
        ),
      ];

      final GoRouter router = await createRouter(routes, tester);
      final String loc = '/page1/${Uri.encodeComponent(param1)}';
      router.go(loc);
      await tester.pumpAndSettle();

      final List<RouteMatch> matches = router.routerDelegate.matches.matches;
      log.info('param1= ${matches.first.decodedParams['param1']}');
      expect(find.byType(DummyScreen), findsOneWidget);
      expect(matches.first.decodedParams['param1'], param1);
    });

    testWidgets('preserve query param spaces and slashes',
        (WidgetTester tester) async {
      const String param1 = 'param w/ spaces and slashes';
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/page1',
          builder: (BuildContext c, GoRouterState s) {
            expect(s.queryParams['param1'], param1);
            return const DummyScreen();
          },
        ),
      ];

      final GoRouter router = await createRouter(routes, tester);
      router.go('/page1?param1=$param1');
      await tester.pumpAndSettle();

      final List<RouteMatch> matches = router.routerDelegate.matches.matches;
      expect(find.byType(DummyScreen), findsOneWidget);
      expect(matches.first.queryParams['param1'], param1);

      final String loc = '/page1?param1=${Uri.encodeQueryComponent(param1)}';
      router.go(loc);
      await tester.pumpAndSettle();

      final List<RouteMatch> matches2 = router.routerDelegate.matches.matches;
      expect(find.byType(DummyScreen), findsOneWidget);
      expect(matches2[0].queryParams['param1'], param1);
    });

    test('error: duplicate path param', () {
      try {
        GoRouter(
          routes: <GoRoute>[
            GoRoute(
              path: '/:id/:blah/:bam/:id/:blah',
              builder: dummy,
            ),
          ],
          errorBuilder: (BuildContext context, GoRouterState state) =>
              TestErrorScreen(state.error!),
          initialLocation: '/0/1/2/0/1',
        );
        expect(false, true);
      } on Exception catch (ex) {
        log.info(ex);
      }
    });

    testWidgets('duplicate query param', (WidgetTester tester) async {
      final GoRouter router = await createRouter(
        <GoRoute>[
          GoRoute(
            path: '/',
            builder: (BuildContext context, GoRouterState state) {
              log.info('id= ${state.params['id']}');
              expect(state.params.length, 0);
              expect(state.queryParams.length, 1);
              expect(state.queryParams['id'], anyOf('0', '1'));
              return const HomeScreen();
            },
          ),
        ],
        tester,
        initialLocation: '/?id=0&id=1',
      );
      final List<RouteMatch> matches = router.routerDelegate.matches.matches;
      expect(matches, hasLength(1));
      expect(matches.first.fullpath, '/');
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('duplicate path + query param', (WidgetTester tester) async {
      final GoRouter router = await createRouter(
        <GoRoute>[
          GoRoute(
            path: '/:id',
            builder: (BuildContext context, GoRouterState state) {
              expect(state.params, <String, String>{'id': '0'});
              expect(state.queryParams, <String, String>{'id': '1'});
              return const HomeScreen();
            },
          ),
        ],
        tester,
      );

      router.go('/0?id=1');
      await tester.pumpAndSettle();
      final List<RouteMatch> matches = router.routerDelegate.matches.matches;
      expect(matches, hasLength(1));
      expect(matches.first.fullpath, '/:id');
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('push + query param', (WidgetTester tester) async {
      final GoRouter router = await createRouter(
        <GoRoute>[
          GoRoute(path: '/', builder: dummy),
          GoRoute(
            path: '/family',
            builder: (BuildContext context, GoRouterState state) =>
                FamilyScreen(
              state.queryParams['fid']!,
            ),
          ),
          GoRoute(
            path: '/person',
            builder: (BuildContext context, GoRouterState state) =>
                PersonScreen(
              state.queryParams['fid']!,
              state.queryParams['pid']!,
            ),
          ),
        ],
        tester,
      );

      router.go('/family?fid=f2');
      await tester.pumpAndSettle();
      router.push('/person?fid=f2&pid=p1');
      await tester.pumpAndSettle();
      final FamilyScreen page1 = tester
          .widget<FamilyScreen>(find.byType(FamilyScreen, skipOffstage: false));
      expect(page1.fid, 'f2');

      final PersonScreen page2 =
          tester.widget<PersonScreen>(find.byType(PersonScreen));
      expect(page2.fid, 'f2');
      expect(page2.pid, 'p1');
    });

    testWidgets('push + extra param', (WidgetTester tester) async {
      final GoRouter router = await createRouter(
        <GoRoute>[
          GoRoute(path: '/', builder: dummy),
          GoRoute(
            path: '/family',
            builder: (BuildContext context, GoRouterState state) =>
                FamilyScreen(
              (state.extra! as Map<String, String>)['fid']!,
            ),
          ),
          GoRoute(
            path: '/person',
            builder: (BuildContext context, GoRouterState state) =>
                PersonScreen(
              (state.extra! as Map<String, String>)['fid']!,
              (state.extra! as Map<String, String>)['pid']!,
            ),
          ),
        ],
        tester,
      );

      router.go('/family', extra: <String, String>{'fid': 'f2'});
      await tester.pumpAndSettle();
      router.push('/person', extra: <String, String>{'fid': 'f2', 'pid': 'p1'});
      await tester.pumpAndSettle();
      final FamilyScreen page1 = tester
          .widget<FamilyScreen>(find.byType(FamilyScreen, skipOffstage: false));
      expect(page1.fid, 'f2');

      final PersonScreen page2 =
          tester.widget<PersonScreen>(find.byType(PersonScreen));
      expect(page2.fid, 'f2');
      expect(page2.pid, 'p1');
    });

    testWidgets('keep param in nested route', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
        ),
        GoRoute(
          path: '/family/:fid',
          builder: (BuildContext context, GoRouterState state) =>
              FamilyScreen(state.params['fid']!),
          routes: <GoRoute>[
            GoRoute(
              path: 'person/:pid',
              builder: (BuildContext context, GoRouterState state) {
                final String fid = state.params['fid']!;
                final String pid = state.params['pid']!;

                return PersonScreen(fid, pid);
              },
            ),
          ],
        ),
      ];

      final GoRouter router = await createRouter(routes, tester);
      const String fid = 'f1';
      const String pid = 'p2';
      const String loc = '/family/$fid/person/$pid';

      router.push(loc);
      await tester.pumpAndSettle();
      final List<RouteMatch> matches = router.routerDelegate.matches.matches;

      expect(router.location, loc);
      expect(matches, hasLength(2));
      expect(find.byType(PersonScreen), findsOneWidget);
      expect(matches.last.decodedParams['fid'], fid);
      expect(matches.last.decodedParams['pid'], pid);
    });

    testWidgets('goNames should allow dynamics values for queryParams',
        (WidgetTester tester) async {
      const Map<String, dynamic> queryParametersAll = <String, List<dynamic>>{
        'q1': <String>['v1'],
        'q2': <String>['v2', 'v3'],
      };
      void expectLocationWithQueryParams(String location) {
        final Uri uri = Uri.parse(location);
        expect(uri.path, '/page');
        expect(uri.queryParametersAll, queryParametersAll);
      }

      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
        ),
        GoRoute(
          name: 'page',
          path: '/page',
          builder: (BuildContext context, GoRouterState state) {
            expect(state.queryParametersAll, queryParametersAll);
            expectLocationWithQueryParams(state.location);
            return DummyScreen(
              queryParametersAll: state.queryParametersAll,
            );
          },
        ),
      ];

      final GoRouter router = await createRouter(routes, tester);

      router.goNamed('page', queryParams: const <String, dynamic>{
        'q1': 'v1',
        'q2': <String>['v2', 'v3'],
      });
      await tester.pumpAndSettle();
      final List<RouteMatch> matches = router.routerDelegate.matches.matches;

      expect(matches, hasLength(1));
      expectLocationWithQueryParams(router.location);
      expect(
        tester.widget<DummyScreen>(find.byType(DummyScreen)),
        isA<DummyScreen>().having(
          (DummyScreen screen) => screen.queryParametersAll,
          'screen.queryParametersAll',
          queryParametersAll,
        ),
      );
    });
  });

  testWidgets('go should preserve the query parameters when navigating',
      (WidgetTester tester) async {
    const Map<String, dynamic> queryParametersAll = <String, List<dynamic>>{
      'q1': <String>['v1'],
      'q2': <String>['v2', 'v3'],
    };
    void expectLocationWithQueryParams(String location) {
      final Uri uri = Uri.parse(location);
      expect(uri.path, '/page');
      expect(uri.queryParametersAll, queryParametersAll);
    }

    final List<GoRoute> routes = <GoRoute>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) =>
            const HomeScreen(),
      ),
      GoRoute(
        name: 'page',
        path: '/page',
        builder: (BuildContext context, GoRouterState state) {
          expect(state.queryParametersAll, queryParametersAll);
          expectLocationWithQueryParams(state.location);
          return DummyScreen(
            queryParametersAll: state.queryParametersAll,
          );
        },
      ),
    ];

    final GoRouter router = await createRouter(routes, tester);

    router.go('/page?q1=v1&q2=v2&q2=v3');
    await tester.pumpAndSettle();
    final List<RouteMatch> matches = router.routerDelegate.matches.matches;

    expect(matches, hasLength(1));
    expectLocationWithQueryParams(router.location);
    expect(
      tester.widget<DummyScreen>(find.byType(DummyScreen)),
      isA<DummyScreen>().having(
        (DummyScreen screen) => screen.queryParametersAll,
        'screen.queryParametersAll',
        queryParametersAll,
      ),
    );
  });

  testWidgets('goRouter should rebuild widget if ',
      (WidgetTester tester) async {
    const Map<String, dynamic> queryParametersAll = <String, List<dynamic>>{
      'q1': <String>['v1'],
      'q2': <String>['v2', 'v3'],
    };
    void expectLocationWithQueryParams(String location) {
      final Uri uri = Uri.parse(location);
      expect(uri.path, '/page');
      expect(uri.queryParametersAll, queryParametersAll);
    }

    final List<GoRoute> routes = <GoRoute>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) =>
            const HomeScreen(),
      ),
      GoRoute(
        name: 'page',
        path: '/page',
        builder: (BuildContext context, GoRouterState state) {
          expect(state.queryParametersAll, queryParametersAll);
          expectLocationWithQueryParams(state.location);
          return DummyScreen(
            queryParametersAll: state.queryParametersAll,
          );
        },
      ),
    ];

    final GoRouter router = await createRouter(routes, tester);

    router.go('/page?q1=v1&q2=v2&q2=v3');
    await tester.pumpAndSettle();
    final List<RouteMatch> matches = router.routerDelegate.matches.matches;

    expect(matches, hasLength(1));
    expectLocationWithQueryParams(router.location);
    expect(
      tester.widget<DummyScreen>(find.byType(DummyScreen)),
      isA<DummyScreen>().having(
        (DummyScreen screen) => screen.queryParametersAll,
        'screen.queryParametersAll',
        queryParametersAll,
      ),
    );
  });

  group('GoRouterHelper extensions', () {
    final GlobalKey<DummyStatefulWidgetState> key =
        GlobalKey<DummyStatefulWidgetState>();
    final List<GoRoute> routes = <GoRoute>[
      GoRoute(
        path: '/',
        name: 'home',
        builder: (BuildContext context, GoRouterState state) =>
            DummyStatefulWidget(key: key),
      ),
      GoRoute(
        path: '/page1',
        name: 'page1',
        builder: (BuildContext context, GoRouterState state) =>
            const Page1Screen(),
      ),
    ];

    const String name = 'page1';
    final Map<String, String> params = <String, String>{
      'a-param-key': 'a-param-value',
    };
    final Map<String, String> queryParams = <String, String>{
      'a-query-key': 'a-query-value',
    };
    const String location = '/page1';
    const String extra = 'Hello';

    testWidgets('calls [namedLocation] on closest GoRouter',
        (WidgetTester tester) async {
      final GoRouterNamedLocationSpy router =
          GoRouterNamedLocationSpy(routes: routes);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          title: 'GoRouter Example',
        ),
      );
      key.currentContext!.namedLocation(
        name,
        params: params,
        queryParams: queryParams,
      );
      expect(router.name, name);
      expect(router.params, params);
      expect(router.queryParams, queryParams);
    });

    testWidgets('calls [go] on closest GoRouter', (WidgetTester tester) async {
      final GoRouterGoSpy router = GoRouterGoSpy(routes: routes);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          title: 'GoRouter Example',
        ),
      );
      key.currentContext!.go(
        location,
        extra: extra,
      );
      expect(router.myLocation, location);
      expect(router.extra, extra);
    });

    testWidgets('calls [goNamed] on closest GoRouter',
        (WidgetTester tester) async {
      final GoRouterGoNamedSpy router = GoRouterGoNamedSpy(routes: routes);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          title: 'GoRouter Example',
        ),
      );
      key.currentContext!.goNamed(
        name,
        params: params,
        queryParams: queryParams,
        extra: extra,
      );
      expect(router.name, name);
      expect(router.params, params);
      expect(router.queryParams, queryParams);
      expect(router.extra, extra);
    });

    testWidgets('calls [push] on closest GoRouter',
        (WidgetTester tester) async {
      final GoRouterPushSpy router = GoRouterPushSpy(routes: routes);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          title: 'GoRouter Example',
        ),
      );
      key.currentContext!.push(
        location,
        extra: extra,
      );
      expect(router.myLocation, location);
      expect(router.extra, extra);
    });

    testWidgets('calls [pushNamed] on closest GoRouter',
        (WidgetTester tester) async {
      final GoRouterPushNamedSpy router = GoRouterPushNamedSpy(routes: routes);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          title: 'GoRouter Example',
        ),
      );
      key.currentContext!.pushNamed(
        name,
        params: params,
        queryParams: queryParams,
        extra: extra,
      );
      expect(router.name, name);
      expect(router.params, params);
      expect(router.queryParams, queryParams);
      expect(router.extra, extra);
    });

    testWidgets('calls [pop] on closest GoRouter', (WidgetTester tester) async {
      final GoRouterPopSpy router = GoRouterPopSpy(routes: routes);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          title: 'GoRouter Example',
        ),
      );
      key.currentContext!.pop();
      expect(router.popped, true);
    });
  });

  group('ShellRoute', () {
    testWidgets('defaultRoute', (WidgetTester tester) async {
      final List<RouteBase> routes = <RouteBase>[
        ShellRoute(
          builder: (BuildContext context, GoRouterState state, Widget child) {
            return Scaffold(
              body: child,
            );
          },
          routes: <RouteBase>[
            GoRoute(
              path: '/a',
              builder: (BuildContext context, GoRouterState state) {
                return const Scaffold(
                  body: Text('Screen A'),
                );
              },
            ),
            GoRoute(
              path: '/b',
              builder: (BuildContext context, GoRouterState state) {
                return const Scaffold(
                  body: Text('Screen B'),
                );
              },
            ),
          ],
        ),
      ];

      await createRouter(routes, tester, initialLocation: '/b');
      expect(find.text('Screen B'), findsOneWidget);
    });

    testWidgets(
        'Pops from the correct Navigator when the Android back button is pressed',
        (WidgetTester tester) async {
      final List<RouteBase> routes = <RouteBase>[
        ShellRoute(
          builder: (BuildContext context, GoRouterState state, Widget child) {
            return Scaffold(
              body: Column(
                children: <Widget>[
                  const Text('Screen A'),
                  Expanded(child: child),
                ],
              ),
            );
          },
          routes: <RouteBase>[
            GoRoute(
              path: '/b',
              builder: (BuildContext context, GoRouterState state) {
                return const Scaffold(
                  body: Text('Screen B'),
                );
              },
              routes: <RouteBase>[
                GoRoute(
                  path: 'c',
                  builder: (BuildContext context, GoRouterState state) {
                    return const Scaffold(
                      body: Text('Screen C'),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ];

      await createRouter(routes, tester, initialLocation: '/b/c');
      expect(find.text('Screen A'), findsOneWidget);
      expect(find.text('Screen B'), findsNothing);
      expect(find.text('Screen C'), findsOneWidget);

      await simulateAndroidBackButton(tester);
      await tester.pumpAndSettle();

      expect(find.text('Screen A'), findsOneWidget);
      expect(find.text('Screen B'), findsOneWidget);
      expect(find.text('Screen C'), findsNothing);
    });

    testWidgets(
        'Pops from the correct navigator when a sub-route is placed on '
        'the root Navigator', (WidgetTester tester) async {
      final GlobalKey<NavigatorState> rootNavigatorKey =
          GlobalKey<NavigatorState>();
      final GlobalKey<NavigatorState> shellNavigatorKey =
          GlobalKey<NavigatorState>();

      final List<RouteBase> routes = <RouteBase>[
        ShellRoute(
          navigatorKey: shellNavigatorKey,
          builder: (BuildContext context, GoRouterState state, Widget child) {
            return Scaffold(
              body: Column(
                children: <Widget>[
                  const Text('Screen A'),
                  Expanded(child: child),
                ],
              ),
            );
          },
          routes: <RouteBase>[
            GoRoute(
              path: '/b',
              builder: (BuildContext context, GoRouterState state) {
                return const Scaffold(
                  body: Text('Screen B'),
                );
              },
              routes: <RouteBase>[
                GoRoute(
                  path: 'c',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (BuildContext context, GoRouterState state) {
                    return const Scaffold(
                      body: Text('Screen C'),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ];

      await createRouter(routes, tester,
          initialLocation: '/b/c', navigatorKey: rootNavigatorKey);
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen B'), findsNothing);
      expect(find.text('Screen C'), findsOneWidget);

      await simulateAndroidBackButton(tester);
      await tester.pumpAndSettle();

      expect(find.text('Screen A'), findsOneWidget);
      expect(find.text('Screen B'), findsOneWidget);
      expect(find.text('Screen C'), findsNothing);
    });

    testWidgets(
        'Navigates to correct nested navigation tree in StatefulShellRoute '
        'and maintains state', (WidgetTester tester) async {
      final GlobalKey<NavigatorState> rootNavigatorKey =
          GlobalKey<NavigatorState>();
      final GlobalKey<DummyStatefulWidgetState> statefulWidgetKey =
          GlobalKey<DummyStatefulWidgetState>();

      final List<RouteBase> routes = <RouteBase>[
        StatefulShellRoute(
          builder: (_, __, Widget child) => child,
          branches: <ShellRouteBranch>[
            ShellRouteBranch(routes: <GoRoute>[
              GoRoute(
                path: '/a',
                builder: (BuildContext context, GoRouterState state) =>
                    const Text('Screen A'),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'detailA',
                    builder: (BuildContext context, GoRouterState state) =>
                        Column(children: <Widget>[
                      const Text('Screen A Detail'),
                      DummyStatefulWidget(key: statefulWidgetKey),
                    ]),
                  ),
                ],
              ),
            ]),
            ShellRouteBranch(routes: <GoRoute>[
              GoRoute(
                path: '/b',
                builder: (BuildContext context, GoRouterState state) =>
                    const Text('Screen B'),
              ),
            ]),
          ],
        ),
      ];

      final GoRouter router = await createRouter(routes, tester,
          initialLocation: '/a/detailA', navigatorKey: rootNavigatorKey);
      statefulWidgetKey.currentState?.increment();
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen A Detail'), findsOneWidget);
      expect(find.text('Screen B'), findsNothing);

      router.go('/b');
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen A Detail'), findsNothing);
      expect(find.text('Screen B'), findsOneWidget);

      router.go('/a/detailA');
      await tester.pumpAndSettle();
      expect(statefulWidgetKey.currentState?.counter, equals(1));

      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsOneWidget);
      expect(find.text('Screen A Detail'), findsNothing);
      router.go('/a/detailA');
      await tester.pumpAndSettle();
      expect(statefulWidgetKey.currentState?.counter, equals(0));
    });

    testWidgets(
        'Pops from the correct Navigator in a StatefulShellRoute when the '
        'Android back button is pressed', (WidgetTester tester) async {
      final GlobalKey<NavigatorState> rootNavigatorKey =
          GlobalKey<NavigatorState>();
      final GlobalKey<NavigatorState> sectionANavigatorKey =
          GlobalKey<NavigatorState>();
      final GlobalKey<NavigatorState> sectionBNavigatorKey =
          GlobalKey<NavigatorState>();

      final List<RouteBase> routes = <RouteBase>[
        StatefulShellRoute(
          builder: (_, __, Widget child) => child,
          branches: <ShellRouteBranch>[
            ShellRouteBranch(
                navigatorKey: sectionANavigatorKey,
                routes: <GoRoute>[
                  GoRoute(
                    path: '/a',
                    builder: (BuildContext context, GoRouterState state) =>
                        const Text('Screen A'),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'detailA',
                        builder: (BuildContext context, GoRouterState state) =>
                            const Text('Screen A Detail'),
                      ),
                    ],
                  ),
                ]),
            ShellRouteBranch(
                navigatorKey: sectionBNavigatorKey,
                routes: <GoRoute>[
                  GoRoute(
                    path: '/b',
                    builder: (BuildContext context, GoRouterState state) =>
                        const Text('Screen B'),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'detailB',
                        builder: (BuildContext context, GoRouterState state) =>
                            const Text('Screen B Detail'),
                      ),
                    ],
                  ),
                ]),
          ],
        ),
      ];

      final GoRouter router = await createRouter(routes, tester,
          initialLocation: '/a/detailA', navigatorKey: rootNavigatorKey);
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen A Detail'), findsOneWidget);
      expect(find.text('Screen B'), findsNothing);
      expect(find.text('Screen B Detail'), findsNothing);

      router.go('/b/detailB');
      await tester.pumpAndSettle();

      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen A Detail'), findsNothing);
      expect(find.text('Screen B'), findsNothing);
      expect(find.text('Screen B Detail'), findsOneWidget);

      await simulateAndroidBackButton(tester);
      await tester.pumpAndSettle();

      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen A Detail'), findsNothing);
      expect(find.text('Screen B'), findsOneWidget);
      expect(find.text('Screen B Detail'), findsNothing);
    });

    testWidgets(
        'Maintains extra navigation information when navigating '
        'between branches in StatefulShellRoute', (WidgetTester tester) async {
      final GlobalKey<NavigatorState> rootNavigatorKey =
          GlobalKey<NavigatorState>();
      StatefulShellRouteState? routeState;

      final List<RouteBase> routes = <RouteBase>[
        StatefulShellRoute(
          builder: (BuildContext context, _, Widget child) {
            routeState = StatefulShellRoute.of(context);
            return child;
          },
          branches: <ShellRouteBranch>[
            ShellRouteBranch(routes: <GoRoute>[
              GoRoute(
                path: '/a',
                builder: (BuildContext context, GoRouterState state) =>
                    const Text('Screen A'),
              ),
            ]),
            ShellRouteBranch(routes: <GoRoute>[
              GoRoute(
                path: '/b',
                builder: (BuildContext context, GoRouterState state) =>
                    Text('Screen B - ${state.extra}'),
              ),
            ]),
          ],
        ),
      ];

      final GoRouter router = await createRouter(routes, tester,
          initialLocation: '/a', navigatorKey: rootNavigatorKey);
      expect(find.text('Screen A'), findsOneWidget);

      router.go('/b', extra: 'X');
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen B - X'), findsOneWidget);

      routeState!.goBranch(0);
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsOneWidget);
      expect(find.text('Screen B - X'), findsNothing);

      routeState!.goBranch(1);
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen B - X'), findsOneWidget);
    });

    testWidgets(
        'Pushed non-descendant routes are correctly restored when '
        'navigating between branches in StatefulShellRoute',
        (WidgetTester tester) async {
      final GlobalKey<NavigatorState> rootNavigatorKey =
          GlobalKey<NavigatorState>();
      StatefulShellRouteState? routeState;

      final List<RouteBase> routes = <RouteBase>[
        GoRoute(
          path: '/common',
          builder: (BuildContext context, GoRouterState state) =>
              Text('Common - ${state.extra}'),
        ),
        StatefulShellRoute(
          builder: (BuildContext context, GoRouterState state, Widget child) {
            routeState = StatefulShellRoute.of(context);
            return child;
          },
          branches: <ShellRouteBranch>[
            ShellRouteBranch(routes: <GoRoute>[
              GoRoute(
                path: '/a',
                builder: (BuildContext context, GoRouterState state) =>
                    const Text('Screen A'),
              ),
            ]),
            ShellRouteBranch(routes: <GoRoute>[
              GoRoute(
                path: '/b',
                builder: (BuildContext context, GoRouterState state) =>
                    const Text('Screen B'),
              ),
            ]),
          ],
        ),
      ];

      final GoRouter router = await createRouter(routes, tester,
          initialLocation: '/a', navigatorKey: rootNavigatorKey);
      expect(find.text('Screen A'), findsOneWidget);

      router.go('/b');
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen B'), findsOneWidget);

      router.push('/common', extra: 'X');
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen B'), findsNothing);
      expect(find.text('Common - X'), findsOneWidget);

      routeState!.goBranch(0);
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsOneWidget);

      routeState!.goBranch(1);
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen B'), findsNothing);
      expect(find.text('Common - X'), findsOneWidget);
    });

    testWidgets('Preloads routes correctly in a StatefulShellRoute',
        (WidgetTester tester) async {
      final GlobalKey<NavigatorState> rootNavigatorKey =
          GlobalKey<NavigatorState>();
      final GlobalKey<DummyStatefulWidgetState> statefulWidgetKeyA =
          GlobalKey<DummyStatefulWidgetState>();
      final GlobalKey<DummyStatefulWidgetState> statefulWidgetKeyB =
          GlobalKey<DummyStatefulWidgetState>();
      final GlobalKey<DummyStatefulWidgetState> statefulWidgetKeyC =
          GlobalKey<DummyStatefulWidgetState>();
      final GlobalKey<DummyStatefulWidgetState> statefulWidgetKeyD =
          GlobalKey<DummyStatefulWidgetState>();
      final GlobalKey<DummyStatefulWidgetState> statefulWidgetKeyE =
          GlobalKey<DummyStatefulWidgetState>();

      final List<RouteBase> routes = <RouteBase>[
        StatefulShellRoute(
          builder: (BuildContext context, GoRouterState state, Widget child) =>
              child,
          branches: <ShellRouteBranch>[
            ShellRouteBranch(routes: <GoRoute>[
              GoRoute(
                path: '/a',
                builder: (BuildContext context, GoRouterState state) =>
                    DummyStatefulWidget(key: statefulWidgetKeyA),
              ),
            ]),
            ShellRouteBranch(routes: <GoRoute>[
              GoRoute(
                path: '/b',
                builder: (BuildContext context, GoRouterState state) =>
                    DummyStatefulWidget(key: statefulWidgetKeyB),
              ),
            ]),
          ],
        ),
        StatefulShellRoute(
          preloadBranches: true,
          builder: (BuildContext context, GoRouterState state, Widget child) =>
              child,
          branches: <ShellRouteBranch>[
            ShellRouteBranch(routes: <GoRoute>[
              GoRoute(
                path: '/c',
                builder: (BuildContext context, GoRouterState state) =>
                    DummyStatefulWidget(key: statefulWidgetKeyC),
              ),
            ]),
            ShellRouteBranch(routes: <GoRoute>[
              GoRoute(
                path: '/d',
                builder: (BuildContext context, GoRouterState state) =>
                    DummyStatefulWidget(key: statefulWidgetKeyD),
              ),
            ]),
            ShellRouteBranch(routes: <GoRoute>[
              GoRoute(
                  path: '/e',
                  builder: (BuildContext context, GoRouterState state) =>
                      const Text('E'),
                  routes: <RouteBase>[
                    GoRoute(
                      path: 'details',
                      builder: (BuildContext context, GoRouterState state) =>
                          DummyStatefulWidget(key: statefulWidgetKeyE),
                    ),
                  ]),
            ]),
          ],
        ),
      ];

      final GoRouter router = await createRouter(
        routes,
        tester,
        initialLocation: '/a',
        navigatorKey: rootNavigatorKey,
        redirect: (_, GoRouterState state) {
          if (state.location == '/e') {
            return '/e/details';
          }
          return null;
        },
      );
      expect(statefulWidgetKeyA.currentState?.counter, equals(0));
      expect(statefulWidgetKeyB.currentState?.counter, null);
      expect(statefulWidgetKeyC.currentState?.counter, null);
      expect(statefulWidgetKeyD.currentState?.counter, null);

      router.go('/c');
      await tester.pumpAndSettle();
      expect(statefulWidgetKeyC.currentState?.counter, equals(0));
      expect(statefulWidgetKeyD.currentState?.counter, equals(0));
      expect(statefulWidgetKeyE.currentState?.counter, equals(0));
    });

    testWidgets(
        'Redirects are correctly handled when switching branch in a '
        'StatefulShellRoute', (WidgetTester tester) async {
      final GlobalKey<NavigatorState> rootNavigatorKey =
          GlobalKey<NavigatorState>();
      StatefulShellRouteState? routeState;

      final List<RouteBase> routes = <RouteBase>[
        StatefulShellRoute(
          builder: (BuildContext context, GoRouterState state, Widget child) {
            routeState = StatefulShellRoute.of(context);
            return child;
          },
          branches: <ShellRouteBranch>[
            ShellRouteBranch(routes: <GoRoute>[
              GoRoute(
                path: '/a',
                builder: (BuildContext context, GoRouterState state) =>
                    const Text('Screen A'),
              ),
            ]),
            ShellRouteBranch(routes: <GoRoute>[
              GoRoute(
                path: '/b',
                builder: (BuildContext context, GoRouterState state) =>
                    const Text('Screen B'),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'details1',
                    builder: (BuildContext context, GoRouterState state) =>
                        const Text('Screen B Detail1'),
                  ),
                  GoRoute(
                    path: 'details2',
                    builder: (BuildContext context, GoRouterState state) =>
                        const Text('Screen B Detail2'),
                  ),
                ],
              ),
            ]),
            ShellRouteBranch(routes: <GoRoute>[
              GoRoute(
                path: '/c',
                redirect: (_, __) => '/c/main2',
              ),
              GoRoute(
                path: '/c/main1',
                builder: (BuildContext context, GoRouterState state) =>
                    const Text('Screen C1'),
              ),
              GoRoute(
                path: '/c/main2',
                builder: (BuildContext context, GoRouterState state) =>
                    const Text('Screen C2'),
              ),
            ]),
          ],
        ),
      ];

      String redirectDestinationBranchB = '/b/details1';
      await createRouter(
        routes,
        tester,
        initialLocation: '/a',
        navigatorKey: rootNavigatorKey,
        redirect: (_, GoRouterState state) {
          if (state.location.startsWith('/b')) {
            return redirectDestinationBranchB;
          }
          return null;
        },
      );
      expect(find.text('Screen A'), findsOneWidget);
      expect(find.text('Screen B Detail'), findsNothing);

      routeState!.goBranch(1);
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen B Detail1'), findsOneWidget);

      routeState!.goBranch(2);
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen B Detail1'), findsNothing);
      expect(find.text('Screen C2'), findsOneWidget);

      redirectDestinationBranchB = '/b/details2';
      routeState!.goBranch(1);
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen B Detail2'), findsOneWidget);
      expect(find.text('Screen C2'), findsNothing);
    });

    testWidgets('StatefulShellRoute is correctly reset',
        (WidgetTester tester) async {
      final GlobalKey<NavigatorState> rootNavigatorKey =
          GlobalKey<NavigatorState>();
      StatefulShellRouteState? routeState;

      final List<RouteBase> routes = <RouteBase>[
        StatefulShellRoute(
          builder: (BuildContext context, GoRouterState state, Widget child) {
            routeState = StatefulShellRoute.of(context);
            return child;
          },
          branches: <ShellRouteBranch>[
            ShellRouteBranch(routes: <GoRoute>[
              GoRoute(
                path: '/a',
                builder: (BuildContext context, GoRouterState state) =>
                    const Text('Screen A'),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'detail',
                    builder: (BuildContext context, GoRouterState state) =>
                        const Text('Screen A Detail'),
                  ),
                ],
              ),
            ]),
            ShellRouteBranch(routes: <GoRoute>[
              GoRoute(
                path: '/b',
                builder: (BuildContext context, GoRouterState state) =>
                    const Text('Screen B'),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'detail',
                    builder: (BuildContext context, GoRouterState state) =>
                        const Text('Screen B Detail'),
                  ),
                ],
              ),
            ]),
          ],
        ),
      ];

      final GoRouter router = await createRouter(routes, tester,
          initialLocation: '/a/detail', navigatorKey: rootNavigatorKey);
      expect(find.text('Screen A'), findsNothing);
      expect(find.text('Screen A Detail'), findsOneWidget);

      router.go('/b/detail');
      await tester.pumpAndSettle();
      expect(find.text('Screen B'), findsNothing);
      expect(find.text('Screen B Detail'), findsOneWidget);

      routeState!.reset();
      await tester.pumpAndSettle();
      expect(find.text('Screen B'), findsOneWidget);
      expect(find.text('Screen B Detail'), findsNothing);

      routeState!.goBranch(0);
      await tester.pumpAndSettle();
      expect(find.text('Screen A'), findsOneWidget);
      expect(find.text('Screen A Detail'), findsNothing);
    });
  });

  group('Imperative navigation', () {
    testWidgets('pop triggers pop on routerDelegate',
        (WidgetTester tester) async {
      final GoRouter router = await createGoRouter(tester)
        ..push('/error');
      router.routerDelegate.addListener(expectAsync0(() {}));
      router.pop();
      await tester.pump();
    });

    group('canPop', () {
      testWidgets(
        'It should return false if Navigator.canPop() returns false.',
        (WidgetTester tester) async {
          final GlobalKey<NavigatorState> navigatorKey =
              GlobalKey<NavigatorState>();
          final GoRouter router = GoRouter(
            initialLocation: '/',
            navigatorKey: navigatorKey,
            routes: <GoRoute>[
              GoRoute(
                path: '/',
                builder: (BuildContext context, _) {
                  return Scaffold(
                    body: TextButton(
                      onPressed: () async {
                        navigatorKey.currentState!.push(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) {
                              return const Scaffold(
                                body: Text('pageless route'),
                              );
                            },
                          ),
                        );
                      },
                      child: const Text('Push'),
                    ),
                  );
                },
              ),
              GoRoute(path: '/a', builder: (_, __) => const DummyScreen()),
            ],
          );

          await tester.pumpWidget(
            MaterialApp.router(
                routeInformationProvider: router.routeInformationProvider,
                routeInformationParser: router.routeInformationParser,
                routerDelegate: router.routerDelegate),
          );

          expect(router.canPop(), false);

          await tester.tap(find.text('Push'));
          await tester.pumpAndSettle();

          expect(
              find.text('pageless route', skipOffstage: false), findsOneWidget);
          expect(router.canPop(), true);
        },
      );

      testWidgets(
        'It checks if ShellRoute navigators can pop',
        (WidgetTester tester) async {
          final GlobalKey<NavigatorState> shellNavigatorKey =
              GlobalKey<NavigatorState>();
          final GoRouter router = GoRouter(
            initialLocation: '/a',
            routes: <RouteBase>[
              ShellRoute(
                navigatorKey: shellNavigatorKey,
                builder:
                    (BuildContext context, GoRouterState state, Widget child) {
                  return Scaffold(
                    appBar: AppBar(title: const Text('Shell')),
                    body: child,
                  );
                },
                routes: <GoRoute>[
                  GoRoute(
                    path: '/a',
                    builder: (BuildContext context, _) {
                      return Scaffold(
                        body: TextButton(
                          onPressed: () async {
                            shellNavigatorKey.currentState!.push(
                              MaterialPageRoute<void>(
                                builder: (BuildContext context) {
                                  return const Scaffold(
                                    body: Text('pageless route'),
                                  );
                                },
                              ),
                            );
                          },
                          child: const Text('Push'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          );

          await tester.pumpWidget(
            MaterialApp.router(
                routeInformationProvider: router.routeInformationProvider,
                routeInformationParser: router.routeInformationParser,
                routerDelegate: router.routerDelegate),
          );

          expect(router.canPop(), false);
          expect(find.text('Push'), findsOneWidget);

          await tester.tap(find.text('Push'));
          await tester.pumpAndSettle();

          expect(
              find.text('pageless route', skipOffstage: false), findsOneWidget);
          expect(router.canPop(), true);
        },
      );

      testWidgets(
        'It checks if StatefulShellRoute navigators can pop',
        (WidgetTester tester) async {
          final GlobalKey<NavigatorState> rootNavigatorKey =
              GlobalKey<NavigatorState>();
          final GoRouter router = GoRouter(
            navigatorKey: rootNavigatorKey,
            initialLocation: '/a',
            routes: <RouteBase>[
              StatefulShellRoute(
                builder:
                    (BuildContext context, GoRouterState state, Widget child) {
                  return Scaffold(
                    appBar: AppBar(title: const Text('Shell')),
                    body: child,
                  );
                },
                branches: <ShellRouteBranch>[
                  ShellRouteBranch(routes: <GoRoute>[
                    GoRoute(
                      path: '/a',
                      builder: (BuildContext context, _) {
                        return const Scaffold(
                          body: Text('Screen A'),
                        );
                      },
                    ),
                  ]),
                  ShellRouteBranch(routes: <GoRoute>[
                    GoRoute(
                      path: '/b',
                      builder: (BuildContext context, _) {
                        return const Scaffold(
                          body: Text('Screen B'),
                        );
                      },
                      routes: <RouteBase>[
                        GoRoute(
                          path: 'detail',
                          builder: (BuildContext context, _) {
                            return const Scaffold(
                              body: Text('Screen B detail'),
                            );
                          },
                        ),
                      ],
                    ),
                  ]),
                ],
              ),
            ],
          );

          await tester.pumpWidget(
            MaterialApp.router(
                routeInformationProvider: router.routeInformationProvider,
                routeInformationParser: router.routeInformationParser,
                routerDelegate: router.routerDelegate),
          );

          expect(router.canPop(), false);

          router.go('/b/detail');
          await tester.pumpAndSettle();

          expect(find.text('Screen B detail', skipOffstage: false),
              findsOneWidget);
          expect(router.canPop(), true);
          // Verify that it is actually the StatefulShellRoute that reports
          // canPop = true
          expect(rootNavigatorKey.currentState?.canPop(), false);
        },
      );
    });

    group('pop', () {
      testWidgets(
        'Should pop from the correct navigator when parentNavigatorKey is set',
        (WidgetTester tester) async {
          final GlobalKey<NavigatorState> root =
              GlobalKey<NavigatorState>(debugLabel: 'root');
          final GlobalKey<NavigatorState> shell =
              GlobalKey<NavigatorState>(debugLabel: 'shell');

          final GoRouter router = GoRouter(
            initialLocation: '/a/b',
            navigatorKey: root,
            routes: <GoRoute>[
              GoRoute(
                path: '/',
                builder: (BuildContext context, _) {
                  return const Scaffold(
                    body: Text('Home'),
                  );
                },
                routes: <RouteBase>[
                  ShellRoute(
                    navigatorKey: shell,
                    builder: (BuildContext context, GoRouterState state,
                        Widget child) {
                      return Scaffold(
                        body: Center(
                          child: Column(
                            children: <Widget>[
                              const Text('Shell'),
                              Expanded(child: child),
                            ],
                          ),
                        ),
                      );
                    },
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'a',
                        builder: (_, __) => const Text('A Screen'),
                        routes: <RouteBase>[
                          GoRoute(
                            parentNavigatorKey: root,
                            path: 'b',
                            builder: (_, __) => const Text('B Screen'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );

          await tester.pumpWidget(
            MaterialApp.router(
                routeInformationProvider: router.routeInformationProvider,
                routeInformationParser: router.routeInformationParser,
                routerDelegate: router.routerDelegate),
          );

          expect(router.canPop(), isTrue);
          expect(find.text('B Screen'), findsOneWidget);
          expect(find.text('A Screen'), findsNothing);
          expect(find.text('Shell'), findsNothing);
          expect(find.text('Home'), findsNothing);
          router.pop();
          await tester.pumpAndSettle();
          expect(find.text('A Screen'), findsOneWidget);
          expect(find.text('Shell'), findsOneWidget);
          expect(router.canPop(), isTrue);
          router.pop();
          await tester.pumpAndSettle();
          expect(find.text('Home'), findsOneWidget);
          expect(find.text('Shell'), findsNothing);
        },
      );
    });
  });
}
