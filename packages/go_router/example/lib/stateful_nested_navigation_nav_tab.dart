// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final GlobalKey<NavigatorState> _bottomNavANavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'bottomNavA');
final GlobalKey<NavigatorState> _bottomNavBNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'bottomNavB');

final GlobalKey<NavigatorState> _tabANavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'tabA');
final GlobalKey<NavigatorState> _tabBNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'tabB');

// This example demonstrates how to setup nested navigation using a
// BottomNavigationBar, where each tab uses its own persistent navigator, i.e.
// navigation state is maintained separately for each tab. This setup also
// enables deep linking into nested pages.
//
// This example demonstrates how to display routes within a ShellRoute using a
// `nestedNavigationBuilder`. Navigators for the tabs ('Section A' and
// 'Section B') are created via nested ShellRoutes. Note that no navigator will
// be created by the "top" ShellRoute. This example is similar to the ShellRoute
// example, but differs in that it is able to maintain the navigation state of
// each tab.

void main() {
  runApp(NestedTabNavigationExampleApp());
}

/// An example demonstrating how to use nested navigators
class NestedTabNavigationExampleApp extends StatelessWidget {
  /// Creates a NestedTabNavigationExampleApp
  NestedTabNavigationExampleApp({Key? key}) : super(key: key);

  final GoRouter _router = GoRouter(
    initialLocation: '/a',
    routes: <RouteBase>[
      /// Application shell - wraps the below routes in a scaffold with
      /// a bottom tab navigator (ScaffoldWithNavBar). Each tab will use its own
      /// Navigator, as specified by the parentNavigatorKey for each root route
      /// (branch). For more customization options for the route branches, see
      /// the default constructor for StatefulShellRoute.
      StatefulShellRoute(
        builder: (BuildContext context, GoRouterState state,
            Widget navigationContainer) {
          final StatefulShellRouteState shellRouteState =
              StatefulShellRoute.of(context);
          return ScaffoldWithNavBar(
            index: shellRouteState.index,
            navigators: shellRouteState.navigators,
          );
        },
        branches: <ShellRouteBranch>[
          ShellRouteBranch(
            navigatorKey: _bottomNavANavigatorKey,
            rootRoute: StatefulShellRoute.rootRoutes(
              builder: (BuildContext context, GoRouterState state,
                  Widget navigationContainer) {
                final StatefulShellRouteState shellRouteState =
                    StatefulShellRoute.of(context);
                return TabScreen(
                  index: shellRouteState.index,
                  navigators: shellRouteState.navigators,
                );
              },
              routes: <GoRoute>[
                GoRoute(
                  parentNavigatorKey: _tabANavigatorKey,
                  path: '/a',
                  builder: (BuildContext context, GoRouterState state) {
                    return const CounterScreen(
                      label: 'A',
                    );
                  },
                  routes: <RouteBase>[
                    /// The details screen to display stacked on navigator of the
                    /// second tab. This will cover screen B but not the application
                    /// shell (bottom navigation bar).
                    GoRoute(
                      name: 'result',
                      path: 'result/:param',
                      builder: (BuildContext context, GoRouterState state) {
                        return ResultScreen(
                          label: 'A',
                          count: int.parse(state.params['count'] ?? '0'),
                        );
                      },
                    ),
                  ],
                ),
                GoRoute(
                  parentNavigatorKey: _tabBNavigatorKey,
                  path: '/b',
                  name: 'counter',
                  builder: (BuildContext context, GoRouterState state) {
                    return const CounterScreen(
                      label: 'B',
                    );
                  },
                  routes: <RouteBase>[
                    /// The details screen to display stacked on navigator of the
                    /// second tab. This will cover screen B but not the application
                    /// shell (bottom navigation bar).
                    GoRoute(
                      name: 'result',
                      path: 'result/:param',
                      builder: (BuildContext context, GoRouterState state) {
                        return ResultScreen(
                          label: 'B',
                          count: int.parse(state.params['count'] ?? '0'),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          ShellRouteBranch(
            navigatorKey: _bottomNavBNavigatorKey,
            // The screen to display as the root in the second tab of the bottom
            // navigation bar.
            rootRoute: GoRoute(
              path: '/c',
              builder: (BuildContext context, GoRouterState state) {
                return const CounterScreen(
                  label: 'C',
                );
              },
              routes: <RouteBase>[
                /// The details screen to display stacked on navigator of the
                /// second tab. This will cover screen B but not the application
                /// shell (bottom navigation bar).
                GoRoute(
                  name: 'result',
                  path: 'result/:param',
                  builder: (BuildContext context, GoRouterState state) {
                    return ResultScreen(
                      label: 'C',
                      count: int.parse(state.params['count'] ?? '0'),
                    );
                  },
                ),
              ],
            ),
          ),
        ],

        // /// If you need to customize the Page for StatefulShellRoute, pass a
        // /// pageProvider function in addition to the builder, for example:
        // pageProvider:
        //     (BuildContext context, GoRouterState state, Widget statefulShell) {
        //   return NoTransitionPage<dynamic>(child: statefulShell);
        // },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      routerConfig: _router,
    );
  }
}

/// Builds the "shell" for the app by building a Scaffold with a
/// BottomNavigationBar, where [child] is placed in the body of the Scaffold.
class ScaffoldWithNavBar extends StatefulWidget {
  /// Constructs an [ScaffoldWithNavBar].
  const ScaffoldWithNavBar({
    required this.navigators,
    required this.index,
    Key? key,
  }) : super(key: key ?? const ValueKey<String>('ScaffoldWithNavBar'));

  /// Gets the [Navigator]s for each of the route branches. Note that the
  /// Navigator for a particular branch may be null if the branch hasn't been
  /// visited yet.
  final List<Widget?> navigators;

  /// the index of the currently selected navigator
  final int index;

  @override
  State<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends State<ScaffoldWithNavBar> {
  late PageController _pageController;

  @override
  void initState() {
    _pageController = PageController(
      initialPage: widget.index,
    );
    super.initState();
  }

  @override
  void didUpdateWidget(covariant ScaffoldWithNavBar oldWidget) {
    if (oldWidget.index != widget.index) {
      _pageController.animateToPage(
        widget.index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    final StatefulShellRouteState shellState = StatefulShellRoute.of(context);
    return Scaffold(
      body: PageView(
        controller: _pageController,
        children: widget.navigators
            .map((Widget? e) => e ?? const SizedBox.expand())
            .cast<Widget>()
            .toList(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Section A',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Section B',
          ),
        ],
        currentIndex: widget.index,
        onTap: (int tappedIndex) => _onItemTapped(
          context,
          shellState.navigationBranchState[tappedIndex],
        ),
      ),
    );
  }

  void _onItemTapped(BuildContext context, ShellRouteBranchState routeState) {
    GoRouter.of(context).go(routeState.location);
  }
}

/// Widget for the tab screen in the first item of the bottom navigation bar.
class TabScreen extends StatefulWidget {
  /// Creates a TabScreen
  const TabScreen({
    required this.navigators,
    required this.index,
    Key? key,
  }) : super(key: key);

  /// Gets the [Navigator]s for each of the route branches. Note that the
  /// Navigator for a particular branch may be null if the branch hasn't been
  /// visited yet.
  final List<Widget?> navigators;

  /// the index of the currently selected navigator
  final int index;

  @override
  State<TabScreen> createState() => _TabScreenState();
}

class _TabScreenState extends State<TabScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    _tabController = TabController(
      initialIndex: widget.index,
      length: widget.navigators.length,
      vsync: this,
    );
    super.initState();
  }

  @override
  void didUpdateWidget(covariant TabScreen oldWidget) {
    if (oldWidget.index != widget.index) {
      _tabController.animateTo(
        widget.index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        TabBar(
          controller: _tabController,
          tabs: const <Tab>[
            Tab(child: Text('One')),
            Tab(child: Text('Two')),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: widget.navigators
                .map((Widget? e) => e ?? const SizedBox.expand())
                .toList(),
          ),
        ),
      ],
    );
  }
}

/// Counter screen with counter
class CounterScreen extends StatefulWidget {
  /// Constructs a [CounterScreen].
  const CounterScreen({
    required this.label,
    Key? key,
  }) : super(key: key);

  /// The label to display in the center of the screen.
  final String label;

  @override
  State<StatefulWidget> createState() => CounterScreenState();
}

/// The state for DetailsScreen
class CounterScreenState extends State<CounterScreen> {
  int _counter = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Root Screen'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              widget.label,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Padding(padding: EdgeInsets.all(4)),
            Text(
              'Counter: $_counter',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Padding(padding: EdgeInsets.all(4)),
            TextButton(
              onPressed: () {
                setState(() {
                  _counter++;
                });
              },
              child: const Text('Increment counter'),
            ),
            const Padding(padding: EdgeInsets.all(4)),
            TextButton(
              onPressed: () {
                context.goNamed(
                  'result',
                  params: <String, String>{'count': _counter.toString()},
                );
              },
              child: const Text('Navigate'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The result screen for either the A, B or C screen.
class ResultScreen extends StatelessWidget {
  /// Constructs a [ResultScreen].
  const ResultScreen({
    required this.label,
    required this.count,
    Key? key,
  }) : super(key: key);

  /// The label to display in the center of the screen.
  final String label;

  /// The counter to display in the center of the screen.
  final int count;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Result Screen'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '$label counted to $count',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }
}
