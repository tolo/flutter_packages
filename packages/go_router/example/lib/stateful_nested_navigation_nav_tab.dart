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
      StatefulShellRoute(
        preloadBranches: true,
        branches: <ShellRouteBranch>[
          ShellRouteBranch(
            navigatorKey: _bottomNavANavigatorKey,
            defaultLocation: '/a',
            rootRoute: StatefulShellRoute.rootRoutes(
              preloadBranches: true,
              routes: <GoRoute>[
                GoRoute(
                  parentNavigatorKey: _tabANavigatorKey,
                  path: '/a',
                  builder: (BuildContext context, GoRouterState state) {
                    debugPrint('### detected route: /a');
                    return const CounterView(
                      label: 'A',
                    );
                  },
                  routes: <RouteBase>[
                    /// The details screen to display stacked on navigator of the
                    /// second tab. This will cover screen B but not the application
                    /// shell (bottom navigation bar).
                    GoRoute(
                      path: 'result/:count',
                      builder: (BuildContext context, GoRouterState state) {
                        debugPrint('### detected route: /a/result:count');
                        return ResultView(
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
                  builder: (BuildContext context, GoRouterState state) {
                    debugPrint('### detected route: /b');
                    return const CounterView(
                      label: 'B',
                    );
                  },
                  routes: <RouteBase>[
                    /// The details screen to display stacked on navigator of the
                    /// second tab. This will cover screen B but not the application
                    /// shell (bottom navigation bar).
                    GoRoute(
                      path: 'result/:count',
                      builder: (BuildContext context, GoRouterState state) {
                        debugPrint('### detected route: /b/result:count');
                        return ResultView(
                          label: 'B',
                          count: int.parse(state.params['count'] ?? '0'),
                        );
                      },
                    ),
                  ],
                ),
              ],
              builder: (BuildContext context, GoRouterState state, _) {
                final StatefulShellRouteState shellRouteState =
                    StatefulShellRoute.of(context);
                return TabScreen(
                  index: shellRouteState.index,
                  branchState: shellRouteState.branchState,
                );
              },
            ),
          ),
          ShellRouteBranch(
            navigatorKey: _bottomNavBNavigatorKey,
            defaultLocation: '/c',
            // The screen to display as the root in the second tab of the bottom
            // navigation bar.
            rootRoute: GoRoute(
              path: '/c',
              builder: (BuildContext context, GoRouterState state) {
                debugPrint('### detected route: /c');
                return const CounterScreen(
                  label: 'C',
                );
              },
              routes: <RouteBase>[
                /// The details screen to display stacked on navigator of the
                /// second tab. This will cover screen B but not the application
                /// shell (bottom navigation bar).
                GoRoute(
                  path: 'result/:count',
                  builder: (BuildContext context, GoRouterState state) {
                    debugPrint('### detected route: /c/result:count');
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
        builder: (BuildContext context, GoRouterState state,
            Widget navigationContainer) {
          final StatefulShellRouteState shellRouteState =
              StatefulShellRoute.of(context);
          return ScaffoldWithNavBar(
            index: shellRouteState.index,
            branchState: shellRouteState.branchState,
          );
        },
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
class ScaffoldWithNavBar extends StatefulWidget
    implements GoRouterShellStatefulWidget {
  /// Constructs an [ScaffoldWithNavBar].
  const ScaffoldWithNavBar({
    required this.branchState,
    required this.index,
    Key? key,
  }) : super(key: key ?? const ValueKey<String>('ScaffoldWithNavBar'));

  /// Gets the [ShellRouteBranchState]s for each of the route branches.
  @override
  final List<ShellRouteBranchState> branchState;

  /// the index of the currently selected navigator
  @override
  final int index;

  @override
  State<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState
    extends GoRouterShellStatefulWidgetState<ScaffoldWithNavBar> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TabBarView(
        controller: tabController,
        children: widget.branchState
            .map((ShellRouteBranchState e) => e.navigator!)
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
        currentIndex: index,
        onTap: (int index) {
          tabController.animateTo(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
      ),
    );
  }
}

/// Widget for the tab screen in the first item of the bottom navigation bar.
class TabScreen extends StatefulWidget implements GoRouterShellStatefulWidget {
  /// Creates a TabScreen
  const TabScreen({
    required this.branchState,
    required this.index,
    Key? key,
  }) : super(key: key);

  /// Gets the [ShellRouteBranchState]s for each of the route branches.
  @override
  final List<ShellRouteBranchState> branchState;

  /// the index of the currently selected navigator
  @override
  final int index;

  @override
  State<TabScreen> createState() => _TabScreenState();
}

class _TabScreenState extends GoRouterShellStatefulWidgetState<TabScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          index == 0 ? 'Tab screen (A)' : 'Tab screen (B)',
        ),
        bottom: TabBar(
          controller: tabController,
          tabs: const <Tab>[
            Tab(child: Text('One')),
            Tab(child: Text('Two')),
          ],
          onTap: (int index) {
            if (index == 0) {
              GoRouter.of(context).go('/a');
            } else {
              GoRouter.of(context).go('/b');
            }
          },
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: widget.branchState
            .map((ShellRouteBranchState e) => e.navigator!)
            .toList(),
      ),
    );
  }
}

/// Counter screen with counter
class CounterScreen extends StatelessWidget {
  /// Constructs a [CounterScreen].
  const CounterScreen({
    required this.label,
    Key? key,
  }) : super(key: key);

  /// The label to display in the center of the screen.
  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$label - Root Screen'),
      ),
      body: CounterView(
        label: label,
      ),
    );
  }
}

/// Counter view with counter
class CounterView extends StatefulWidget {
  /// Constructs a [CounterView].
  const CounterView({
    required this.label,
    Key? key,
  }) : super(key: key);

  /// The label to display in the center of the screen.
  final String label;

  @override
  State<StatefulWidget> createState() => CounterViewState();
}

/// The state for CounterView
class CounterViewState extends State<CounterView> {
  int _counter = 0;

  @override
  Widget build(BuildContext context) {
    return Center(
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
              _counter++;
              setState(() {});
            },
            child: const Text('Increment counter'),
          ),
          const Padding(padding: EdgeInsets.all(4)),
          TextButton(
            onPressed: () {
              context.go(
                '${GoRouter.of(context).location}/result/$_counter',
              );
            },
            child: const Text('Navigate'),
          ),
        ],
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
      body: ResultView(
        label: label,
        count: count,
        renderBackButton: false,
      ),
    );
  }
}

/// The result view for either the A, B or C screen.
class ResultView extends StatelessWidget {
  /// Constructs a [ResultView].
  const ResultView({
    required this.label,
    required this.count,
    this.renderBackButton = true,
    Key? key,
  }) : super(key: key);

  /// The label to display in the center of the screen.
  final String label;

  /// The counter to display in the center of the screen.
  final int count;

  /// Whether to render the back button.
  final bool renderBackButton;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        if (renderBackButton)
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new,
                color: Theme.of(context).primaryColor,
              ),
              onPressed: () => context.pop(),
            ),
          ),
        Positioned.fill(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                '$label counted to $count',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Widget for the tab screen in the first item of the bottom navigation bar.
abstract class GoRouterShellStatefulWidget implements StatefulWidget {
  /// Gets the [ShellRouteBranchState]s for each of the route branches.
  List<ShellRouteBranchState> get branchState;

  /// the index of the currently selected navigator
  int get index;
}

abstract class GoRouterShellStatefulWidgetState<
        T extends GoRouterShellStatefulWidget> extends State<T>
    with TickerProviderStateMixin {
  late TabController tabController;
  late int index;

  @override
  void initState() {
    index = widget.index;
    super.initState();
    tabController = TabController(
      initialIndex: widget.index,
      length: widget.branchState.length,
      vsync: this,
    );
    tabController.addListener(_tabListener);
  }

  void _tabListener() {
    if (tabController.index != index) {
      index = tabController.index;
      setState(() {});
      final String? location =
          widget.branchState[tabController.index].routeBranch.defaultLocation;
      if (location == null) {
        assert(false, 'No default location for branch');
        return;
      }
      GoRouter.of(context).go(location);
    }
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    if (oldWidget.index != widget.index) {
      if (widget.index != index) {
        index = widget.index;
        setState(() {});
        tabController.animateTo(
          widget.index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    tabController.removeListener(_tabListener);
    super.dispose();
  }
}
