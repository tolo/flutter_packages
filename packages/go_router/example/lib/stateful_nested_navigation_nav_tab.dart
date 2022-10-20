// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final GlobalKey<NavigatorState> _tabANavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'tabANav');
final GlobalKey<NavigatorState> _tabBNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'tabBNav');

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
      StatefulShellRoute.rootRoutes(
        builder: (BuildContext context, GoRouterState state, _) {
          return ScaffoldWithNavBar(
            index: shellRouteState.index,
            children: shellRouteState.navigators,
          );
        },
        routes: <GoRoute>[
          /// The screen to display as the root in the first tab of the bottom
          /// navigation bar.
          GoRoute(
            parentNavigatorKey: _tabANavigatorKey,
            path: '/a',
            builder: (BuildContext context, GoRouterState state) {
              return const RootScreen(
                label: 'A',
                detailsPath: '/a/details',
              );
            },
            routes: <RouteBase>[
              /// The details screen to display stacked on navigator of the
              /// first tab. This will cover screen A but not the application
              /// shell (bottom navigation bar).
              GoRoute(
                path: 'details',
                builder: (BuildContext context, GoRouterState state) {
                  return const DetailsScreen(
                    label: 'A',
                  );
                },
              ),
            ],
          ),

          /// The screen to display as the root in the second tab of the bottom
          /// navigation bar.
          GoRoute(
            parentNavigatorKey: _tabBNavigatorKey,
            path: '/b',
            builder: (BuildContext context, GoRouterState state) {
              return const RootScreen(
                label: 'B',
                detailsPath: '/b/details/1',
                detailsPath2: '/b/details/2',
              );
            },
            routes: <RouteBase>[
              /// The details screen to display stacked on navigator of the
              /// second tab. This will cover screen B but not the application
              /// shell (bottom navigation bar).
              GoRoute(
                path: 'details/:param',
                builder: (BuildContext context, GoRouterState state) =>
                    DetailsScreen(label: 'B', param: state.params['param']),
              ),
            ],
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
    required this.children,
    required this.index,
    Key? key,
  }) : super(key: key ?? const ValueKey<String>('ScaffoldWithNavBar'));

  final List<Widget> children;
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
        children: widget.children,
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
    required this.children,
    required this.index,
    Key? key,
  }) : super(key: key);

  final List<Widget> children;
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
      length: widget.children.length,
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
            children: widget.children,
          ),
        ),
      ],
    );
  }
}

/// Widget for the root/initial pages in the bottom navigation bar.
class RootScreen extends StatelessWidget {
  /// Creates a RootScreen
  const RootScreen(
      {required this.label,
      required this.detailsPath,
      this.detailsPath2,
      Key? key})
      : super(key: key);

  /// The label
  final String label;

  /// The path to the detail page
  final String detailsPath;

  /// The path to another detail page
  final String? detailsPath2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tab root - $label'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Screen $label',
                style: Theme.of(context).textTheme.titleLarge),
            const Padding(padding: EdgeInsets.all(4)),
            TextButton(
              onPressed: () {
                GoRouter.of(context).go(detailsPath);
              },
              child: const Text('View details'),
            ),
            const Padding(padding: EdgeInsets.all(4)),
            if (detailsPath2 != null)
              TextButton(
                onPressed: () {
                  GoRouter.of(context).go(detailsPath2!);
                },
                child: const Text('View more details'),
              ),
          ],
        ),
      ),
    );
  }
}

/// The details screen for either the A or B screen.
class DetailsScreen extends StatefulWidget {
  /// Constructs a [DetailsScreen].
  const DetailsScreen({
    required this.label,
    this.param,
    Key? key,
  }) : super(key: key);

  /// The label to display in the center of the screen.
  final String label;

  /// Optional param
  final String? param;

  @override
  State<StatefulWidget> createState() => DetailsScreenState();
}

/// The state for DetailsScreen
class DetailsScreenState extends State<DetailsScreen> {
  int _counter = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Details Screen - ${widget.label}'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (widget.param != null)
              Text('Parameter: ${widget.param!}',
                  style: Theme.of(context).textTheme.titleLarge),
            const Padding(padding: EdgeInsets.all(4)),
            Text('Details for ${widget.label} - Counter: $_counter',
                style: Theme.of(context).textTheme.titleLarge),
            const Padding(padding: EdgeInsets.all(4)),
            TextButton(
              onPressed: () {
                setState(() {
                  _counter++;
                });
              },
              child: const Text('Increment counter'),
            ),
          ],
        ),
      ),
    );
  }
}
