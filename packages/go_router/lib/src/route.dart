// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

import 'configuration.dart';
import 'misc/stateful_navigation_shell.dart';
import 'pages/custom_transition_page.dart';
import 'path_utils.dart';
import 'typedefs.dart';

/// The base class for [GoRoute] and [ShellRoute].
///
/// Routes are defined in a tree such that parent routes must match the
/// current location for their child route to be considered a match. For
/// example the location "/home/user/12" matches with parent route "/home" and
/// child route "user/:userId".
///
/// To create sub-routes for a route, provide them as a [GoRoute] list
/// with the sub routes.
///
/// For example these routes:
/// ```
/// /         => HomePage()
///   family/f1 => FamilyPage('f1')
///     person/p2 => PersonPage('f1', 'p2') ← showing this page, Back pops ↑
/// ```
///
/// Can be represented as:
///
/// ```
/// final GoRouter _router = GoRouter(
///   routes: <GoRoute>[
///     GoRoute(
///       path: '/',
///       pageBuilder: (BuildContext context, GoRouterState state) => MaterialPage<void>(
///         key: state.pageKey,
///         child: HomePage(families: Families.data),
///       ),
///       routes: <GoRoute>[
///         GoRoute(
///           path: 'family/:fid',
///           pageBuilder: (BuildContext context, GoRouterState state) {
///             final Family family = Families.family(state.params['fid']!);
///             return MaterialPage<void>(
///               key: state.pageKey,
///               child: FamilyPage(family: family),
///             );
///           },
///           routes: <GoRoute>[
///             GoRoute(
///               path: 'person/:pid',
///               pageBuilder: (BuildContext context, GoRouterState state) {
///                 final Family family = Families.family(state.params['fid']!);
///                 final Person person = family.person(state.params['pid']!);
///                 return MaterialPage<void>(
///                   key: state.pageKey,
///                   child: PersonPage(family: family, person: person),
///                 );
///               },
///             ),
///           ],
///         ),
///       ],
///     ),
///   ],
/// );
///
/// If there are multiple routes that match the location, the first match is used.
/// To make predefined routes to take precedence over dynamic routes eg. '/:id'
/// consider adding the dynamic route at the end of the routes
/// For example:
/// ```
/// final GoRouter _router = GoRouter(
///   routes: <GoRoute>[
///     GoRoute(
///       path: '/',
///       redirect: (_) => '/family/${Families.data[0].id}',
///     ),
///     GoRoute(
///       path: '/family',
///       pageBuilder: (BuildContext context, GoRouterState state) => ...,
///     ),
///     GoRoute(
///       path: '/:username',
///       pageBuilder: (BuildContext context, GoRouterState state) => ...,
///     ),
///   ],
/// );
/// ```
/// In the above example, if /family route is matched, it will be used.
/// else /:username route will be used.
///
/// See [Sub-routes](https://github.com/flutter/packages/blob/main/packages/go_router/example/lib/sub_routes.dart)
/// for a complete runnable example.
@immutable
abstract class RouteBase {
  const RouteBase._({
    this.routes = const <RouteBase>[],
  });

  /// The list of child routes associated with this route.
  final List<RouteBase> routes;
}

/// A route that is displayed visually above the matching parent route using the
/// [Navigator].
///
/// The widget returned by [builder] is wrapped in [Page] and provided to the
/// root Navigator, the nearest ShellRoute ancestor's Navigator, or the
/// Navigator with a matching [parentNavigatorKey].
///
/// The Page depends on the application type: [MaterialPage] for
/// [MaterialApp], [CupertinoPage] for [CupertinoApp], or
/// [NoTransitionPage] for [WidgetsApp].
class GoRoute extends RouteBase {
  /// Constructs a [GoRoute].
  /// - [path] and [name] cannot be empty strings.
  /// - One of either [builder] or [pageBuilder] must be provided.
  GoRoute({
    required this.path,
    this.name,
    this.builder,
    this.pageBuilder,
    this.parentNavigatorKey,
    this.redirect,
    List<RouteBase> routes = const <RouteBase>[],
  })  : assert(path.isNotEmpty, 'GoRoute path cannot be empty'),
        assert(name == null || name.isNotEmpty, 'GoRoute name cannot be empty'),
        assert(pageBuilder != null || builder != null || redirect != null,
            'builder, pageBuilder, or redirect must be provided'),
        super._(
          routes: routes,
        ) {
    // cache the path regexp and parameters
    _pathRE = patternToRegExp(path, _pathParams);
    assert(() {
      // check path params
      final Map<String, List<String>> groupedParams =
          _pathParams.groupListsBy<String>((String p) => p);
      final Map<String, List<String>> dupParams =
          Map<String, List<String>>.fromEntries(
        groupedParams.entries
            .where((MapEntry<String, List<String>> e) => e.value.length > 1),
      );
      assert(dupParams.isEmpty,
          'duplicate path params: ${dupParams.keys.join(', ')}');

      // check sub-routes
      for (final RouteBase route in routes) {
        // check paths
        if (route is GoRoute) {
          assert(
              route.path == '/' ||
                  (!route.path.startsWith('/') && !route.path.endsWith('/')),
              'sub-route path may not start or end with /: ${route.path}');
        }
      }
      return true;
    }());
  }

  /// Optional name of the route.
  ///
  /// If used, a unique string name must be provided and it can not be empty.
  ///
  /// This is used in [GoRouter.namedLocation] and its related API. This
  /// property can be used to navigate to this route without knowing exact the
  /// URI of it.
  ///
  /// {@tool snippet}
  /// Typical usage is as follows:
  ///
  /// ```dart
  /// GoRoute(
  ///   name: 'home',
  ///   path: '/',
  ///   builder: (BuildContext context, GoRouterState state) =>
  ///       HomeScreen(),
  ///   routes: <GoRoute>[
  ///     GoRoute(
  ///       name: 'family',
  ///       path: 'family/:fid',
  ///       builder: (BuildContext context, GoRouterState state) =>
  ///           FamilyScreen(),
  ///     ),
  ///   ],
  /// );
  ///
  /// context.go(
  ///   context.namedLocation('family'),
  ///   params: <String, String>{'fid': 123},
  ///   queryParams: <String, String>{'qid': 'quid'},
  /// );
  /// ```
  ///
  /// See the [named routes example](https://github.com/flutter/packages/blob/main/packages/go_router/example/lib/named_routes.dart)
  /// for a complete runnable app.
  final String? name;

  /// The path of this go route.
  ///
  /// For example:
  /// ```
  /// GoRoute(
  ///   path: '/',
  ///   pageBuilder: (BuildContext context, GoRouterState state) => MaterialPage<void>(
  ///     key: state.pageKey,
  ///     child: HomePage(families: Families.data),
  ///   ),
  /// ),
  /// ```
  ///
  /// The path also support path parameters. For a path: `/family/:fid`, it
  /// matches all URIs start with `/family/...`, e.g. `/family/123`,
  /// `/family/456` and etc. The parameter values are stored in [GoRouterState]
  /// that are passed into [pageBuilder] and [builder].
  ///
  /// The query parameter are also capture during the route parsing and stored
  /// in [GoRouterState].
  ///
  /// See [Query parameters and path parameters](https://github.com/flutter/packages/blob/main/packages/go_router/example/lib/sub_routes.dart)
  /// to learn more about parameters.
  final String path;

  /// A page builder for this route.
  ///
  /// Typically a MaterialPage, as in:
  /// ```
  /// GoRoute(
  ///   path: '/',
  ///   pageBuilder: (BuildContext context, GoRouterState state) => MaterialPage<void>(
  ///     key: state.pageKey,
  ///     child: HomePage(families: Families.data),
  ///   ),
  /// ),
  /// ```
  ///
  /// You can also use CupertinoPage, and for a custom page builder to use
  /// custom page transitions, you can use [CustomTransitionPage].
  final GoRouterPageBuilder? pageBuilder;

  /// A custom builder for this route.
  ///
  /// For example:
  /// ```
  /// GoRoute(
  ///   path: '/',
  ///   builder: (BuildContext context, GoRouterState state) => FamilyPage(
  ///     families: Families.family(
  ///       state.params['id'],
  ///     ),
  ///   ),
  /// ),
  /// ```
  ///
  final GoRouterWidgetBuilder? builder;

  /// An optional redirect function for this route.
  ///
  /// In the case that you like to make a redirection decision for a specific
  /// route (or sub-route), consider doing so by passing a redirect function to
  /// the GoRoute constructor.
  ///
  /// For example:
  /// ```
  /// final GoRouter _router = GoRouter(
  ///   routes: <GoRoute>[
  ///     GoRoute(
  ///       path: '/',
  ///       redirect: (_) => '/family/${Families.data[0].id}',
  ///     ),
  ///     GoRoute(
  ///       path: '/family/:fid',
  ///       pageBuilder: (BuildContext context, GoRouterState state) => ...,
  ///     ),
  ///   ],
  /// );
  /// ```
  ///
  /// If there are multiple redirects in the matched routes, the parent route's
  /// redirect takes priority over sub-route's.
  ///
  /// For example:
  /// ```
  /// final GoRouter _router = GoRouter(
  ///   routes: <GoRoute>[
  ///     GoRoute(
  ///       path: '/',
  ///       redirect: (_) => '/page1', // this takes priority over the sub-route.
  ///       routes: <GoRoute>[
  ///         GoRoute(
  ///           path: 'child',
  ///           redirect: (_) => '/page2',
  ///         ),
  ///       ],
  ///     ),
  ///   ],
  /// );
  /// ```
  ///
  /// The `context.go('/child')` will be redirected to `/page1` instead of
  /// `/page2`.
  ///
  /// Redirect can also be used for conditionally preventing users from visiting
  /// routes, also known as route guards. One canonical example is user
  /// authentication. See [Redirection](https://github.com/flutter/packages/blob/main/packages/go_router/example/lib/redirection.dart)
  /// for a complete runnable example.
  ///
  /// If [BuildContext.dependOnInheritedWidgetOfExactType] is used during the
  /// redirection (which is how `of` method is usually implemented), a
  /// re-evaluation will be triggered if the [InheritedWidget] changes.
  final GoRouterRedirect? redirect;

  /// An optional key specifying which Navigator to display this route's screen
  /// onto.
  ///
  /// Specifying the root Navigator will stack this route onto that
  /// Navigator instead of the nearest ShellRoute ancestor.
  final GlobalKey<NavigatorState>? parentNavigatorKey;

  /// Match this route against a location.
  RegExpMatch? matchPatternAsPrefix(String loc) =>
      _pathRE.matchAsPrefix(loc) as RegExpMatch?;

  /// Extract the path parameters from a match.
  Map<String, String> extractPathParams(RegExpMatch match) =>
      extractPathParameters(_pathParams, match);

  final List<String> _pathParams = <String>[];

  late final RegExp _pathRE;
}

/// Base class for classes that acts as a shell for sub-routes, such
/// as [ShellRoute] and [StatefulShellRoute].
abstract class ShellRouteBase extends RouteBase {
  const ShellRouteBase._({this.builder, this.pageBuilder, super.routes})
      : super._();

  /// The widget builder for a shell route.
  ///
  /// Similar to GoRoute builder, but with an additional child parameter. This
  /// child parameter is the Widget managing the nested navigation for the
  /// matching sub-routes. Typically, a shell route builds its shell around this
  /// Widget.
  final ShellRouteBuilder? builder;

  /// The page builder for a shell route.
  ///
  /// Similar to GoRoute builder, but with an additional child parameter. This
  /// child parameter is the Widget managing the nested navigation for the
  /// matching sub-routes. Typically, a shell route builds its shell around this
  /// Widget.
  final ShellRoutePageBuilder? pageBuilder;

  /// Returns the key for the [Navigator] that is to be used for the specified
  /// immediate sub-route of this shell route.
  GlobalKey<NavigatorState>? navigatorKeyForSubRoute(RouteBase subRoute);
}

/// A route that displays a UI shell around the matching child route.
///
/// When a ShellRoute is added to the list of routes on GoRouter or GoRoute, a
/// new Navigator that is used to display any matching sub-routes, instead of
/// placing them on the root Navigator.
///
/// To display a child route on a different Navigator, provide it with a
/// [parentNavigatorKey] that matches the key provided to either the [GoRouter]
/// or [ShellRoute] constructor. In this example, the _rootNavigator key is
/// passed to the /b/details route so that it displays on the root Navigator
/// instead of the ShellRoute's Navigator:
///
/// ```
/// final GlobalKey<NavigatorState> _rootNavigatorKey =
///     GlobalKey<NavigatorState>();
///
///   final GoRouter _router = GoRouter(
///     navigatorKey: _rootNavigatorKey,
///     initialLocation: '/a',
///     routes: [
///       ShellRoute(
///         navigatorKey: _shellNavigatorKey,
///         builder: (context, state, child) {
///           return ScaffoldWithNavBar(child: child);
///         },
///         routes: [
///           // This screen is displayed on the ShellRoute's Navigator.
///           GoRoute(
///             path: '/a',
///             builder: (context, state) {
///               return const ScreenA();
///             },
///             routes: <RouteBase>[
///               // This screen is displayed on the ShellRoute's Navigator.
///               GoRoute(
///                 path: 'details',
///                 builder: (BuildContext context, GoRouterState state) {
///                   return const DetailsScreen(label: 'A');
///                 },
///               ),
///             ],
///           ),
///           // Displayed ShellRoute's Navigator.
///           GoRoute(
///             path: '/b',
///             builder: (BuildContext context, GoRouterState state) {
///               return const ScreenB();
///             },
///             routes: <RouteBase>[
///               // Displayed on the root Navigator by specifying the
///               // [parentNavigatorKey].
///               GoRoute(
///                 path: 'details',
///                 parentNavigatorKey: _rootNavigatorKey,
///                 builder: (BuildContext context, GoRouterState state) {
///                   return const DetailsScreen(label: 'B');
///                 },
///               ),
///             ],
///           ),
///         ],
///       ),
///     ],
///   );
/// ```
///
/// The widget built by the matching sub-route becomes the child parameter
/// of the [builder].
///
/// For example:
///
/// ```
/// ShellRoute(
///   builder: (BuildContext context, GoRouterState state, Widget child) {
///     return Scaffold(
///       appBar: AppBar(
///         title: Text('App Shell')
///       ),
///       body: Center(
///         child: child,
///       ),
///     );
///   },
///   routes: [
///     GoRoute(
///       path: 'a'
///       builder: (BuildContext context, GoRouterState state) {
///         return Text('Child Route "/a"');
///       }
///     ),
///   ],
/// ),
/// ```
///
class ShellRoute extends ShellRouteBase {
  /// Constructs a [ShellRoute].
  ShellRoute({
    super.builder,
    super.pageBuilder,
    super.routes,
    GlobalKey<NavigatorState>? navigatorKey,
    this.restorationScopeId,
  })  : assert(routes.isNotEmpty),
        navigatorKey = navigatorKey ?? GlobalKey<NavigatorState>(),
        super._() {
    for (final RouteBase route in routes) {
      if (route is GoRoute) {
        assert(route.parentNavigatorKey == null ||
            route.parentNavigatorKey == navigatorKey);
      }
    }
  }

  /// The [GlobalKey] to be used by the [Navigator] built for this route.
  /// All ShellRoutes build a Navigator by default. Child GoRoutes
  /// are placed onto this Navigator instead of the root Navigator.
  final GlobalKey<NavigatorState> navigatorKey;

  /// Restoration ID to save and restore the state of the navigator, including
  /// its history.
  final String? restorationScopeId;

  @override
  GlobalKey<NavigatorState>? navigatorKeyForSubRoute(RouteBase subRoute) {
    if (routes.contains(subRoute)) {
      return navigatorKey;
    }
    return null;
  }
}

/// A route that displays a UI shell with separate [Navigator]s for its
/// sub-routes.
///
/// Similar to [ShellRoute], this route class places its sub-route on a
/// different Navigator than the root Navigator. However, this route class
/// differs in that it creates separate Navigators for each of its nested
/// route branches (route trees), making it possible to build an app with
/// stateful nested navigation. This is convenient when for instance
/// implementing a UI with a [BottomNavigationBar], with a persistent navigation
/// state for each tab.
///
/// A StatefulShellRoute is created by specifying a List of [ShellRouteBranch]
/// items, each representing a separate stateful branch in the route tree.
/// ShellRouteBranch provides the root routes and the Navigator key ([GlobalKey])
/// for the branch, as well as an optional default location.
///
/// Like [ShellRoute], you can provide a [builder] and [pageBuilder] when
/// creating a StatefulShellRoute. However, StatefulShellRoute differs in that
/// the builder is mandatory and the pageBuilder will be used in addition to the
/// builder. The child parameters of the builders are also a bit different, even
/// though this should normally not affect how you implemented the builders.
///
/// For the pageBuilder, the child parameter will simply be the stateful shell
/// already built for this route, using the builder function. In the builder
/// function however, the child parameter is a Widget that contains - and is
/// responsible for managing - the Navigators for the different route branches
/// of this StatefulShellRoute. This widget is meant to be used as the body of a
/// custom shell implementation, for example as the body of [Scaffold] with a
/// [BottomNavigationBar].
///
/// The builder function of a StatefulShellRoute will be invoked from within a
/// wrapper Widget that provides access to the current [StatefulShellRouteState]
/// associated with the route (via the method [StatefulShellRoute.of]). That
/// state object exposes information such as the current branch index, the state
/// of the route branches etc. It is also with the help this state object you
/// can change the active branch, i.e. restore the navigation stack of another
/// branch. This is accomplished using the method
/// [StatefulShellRouteState.goBranch]. For example:
///
/// ```
/// void _onBottomNavigationBarItemTapped(BuildContext context, int index) {
///   final StatefulShellRouteState shellState = StatefulShellRoute.of(context);
///   shellState.goBranch(index);
/// }
/// ```
///
/// Sometimes you need greater control over the layout and animations of the
/// Widgets representing the branch Navigators. In such cases, the child
/// argument in the builder function can be ignored, and a custom implementation
/// can instead be built using the child widgets of the branches
/// (see [StatefulShellRouteState.children]) directly. For example:
///
/// ```
/// final StatefulShellRouteState shellState = StatefulShellRoute.of(context);
/// final int currentIndex = shellState.index;
/// final List<Widget?> children = shellRouteState.children;
/// return MyCustomShell(currentIndex, children);
/// ```
///
/// Below is a simple example of how a router configuration with
/// StatefulShellRoute could be achieved. In this example, a
/// BottomNavigationBar with two tabs is used, and each of the tabs gets its
/// own Navigator. A container widget responsible for managing the Navigators
/// for all route branches will then be passed as the child argument
/// of the builder function.
///
/// ```
/// final GlobalKey<NavigatorState> _tabANavigatorKey =
///   GlobalKey<NavigatorState>(debugLabel: 'tabANavigator');
/// final GlobalKey<NavigatorState> _tabBNavigatorKey =
///   GlobalKey<NavigatorState>(debugLabel: 'tabBNavigator');
///^
/// final GoRouter _router = GoRouter(
///   initialLocation: '/a',
///   routes: <RouteBase>[
///     StatefulShellRoute(
///       builder: (BuildContext context, GoRouterState state,
///           Widget navigatorContainer) {
///         return ScaffoldWithNavBar(body: navigatorContainer);
///       },
///       branches: [
///         /// The first branch, i.e. tab 'A'
///         ShellRouteBranch(
///           navigatorKey: _tabANavigatorKey,
///           routes: <RouteBase>[
///             GoRoute(
///               path: '/a',
///               builder: (BuildContext context, GoRouterState state) =>
///                   const RootScreen(label: 'A', detailsPath: '/a/details'),
///               routes: <RouteBase>[
///                 /// Will cover screen A but not the bottom navigation bar
///                 GoRoute(
///                   path: 'details',
///                   builder: (BuildContext context, GoRouterState state) =>
///                       const DetailsScreen(label: 'A'),
///                 ),
///               ],
///             ),
///           ],
///         ),
///         /// The second branch, i.e. tab 'B'
///         ShellRouteBranch(
///           navigatorKey: _tabBNavigatorKey,
///           routes: <RouteBase>[
///             GoRoute(
///               path: '/b',
///               builder: (BuildContext context, GoRouterState state) =>
///                   const RootScreen(label: 'B', detailsPath: '/b/details'),
///               routes: <RouteBase>[
///                 /// Will cover screen B but not the bottom navigation bar
///                 GoRoute(
///                   path: 'details',
///                   builder: (BuildContext context, GoRouterState state) =>
///                       const DetailsScreen(label: 'B'),
///                 ),
///               ],
///             ),
///           ],
///         ),
///       ],
///     ),
///   ],
/// );
/// ```
///
/// When the [Page] for this route needs to be customized, you need to pass a
/// function for pageBuilder. Note that this page builder doesn't replace
/// the builder function, but instead receives the stateful shell built by
/// [StatefulShellRoute] (using the builder function) as input. In other words,
/// you need to specify both when customizing a page. For example:
///
/// ```
/// final GoRouter _router = GoRouter(
///   initialLocation: '/a',
///   routes: <RouteBase>[
///     StatefulShellRoute(
///       builder: (BuildContext context, GoRouterState state,
///           Widget navigationContainer) {
///         return ScaffoldWithNavBar(body: navigationContainer);
///       },
///       pageBuilder:
///           (BuildContext context, GoRouterState state, Widget statefulShell) {
///         return NoTransitionPage<dynamic>(child: statefulShell);
///       },
///       branches: <ShellRouteBranch>[
///         /// The first branch, i.e. root of tab 'A'
///         ShellRouteBranch(routes: <RouteBase>[
///           GoRoute(
///             parentNavigatorKey: _tabANavigatorKey,
///             path: '/a',
///             builder: (BuildContext context, GoRouterState state) =>
///               const RootScreen(label: 'A', detailsPath: '/a/details'),
///           ),
///         ]),
///         /// The second branch, i.e. root of tab 'B'
///         ShellRouteBranch(routes: <RouteBase>[
///           GoRoute(
///             parentNavigatorKey: _tabBNavigatorKey,
///             path: '/b',
///             builder: (BuildContext context, GoRouterState state) =>
///               const RootScreen(label: 'B', detailsPath: '/b/details/1'),
///           ),
///         ]),
///       ],
///     ),
///   ],
/// );
/// ```
///
/// To access the current state of this route, to for instance access the
/// index of the current route branch - use the method
/// [StatefulShellRoute.of]. For example:
///
/// ```
/// final StatefulShellRouteState shellState = StatefulShellRoute.of(context);
/// ```
///
/// See [Stateful Nested Navigation](https://github.com/flutter/packages/blob/main/packages/go_router/example/lib/stateful_nested_navigation.dart)
/// for a complete runnable example using StatefulShellRoute.
class StatefulShellRoute extends ShellRouteBase {
  /// Constructs a [StatefulShellRoute] from a list of [ShellRouteBranch], each
  /// representing a root in a stateful route branch.
  ///
  /// A separate [Navigator] will be created for each of the branches, using
  /// the navigator key specified in [ShellRouteBranch]. Note that unlike
  /// [ShellRoute], you must always provide a builder when creating
  /// a StatefulShellRoute. The pageBuilder however is optional, and is used
  /// in addition to the builder.
  StatefulShellRoute({
    required this.branches,
    required super.builder,
    super.pageBuilder,
    this.preloadBranches = false,
  })  : assert(branches.isNotEmpty),
        assert(_debugUniqueNavigatorKeys(branches).length == branches.length,
            'Navigator keys must be unique'),
        super._(routes: _routes(branches)) {
    for (int i = 0; i < routes.length; ++i) {
      final RouteBase route = routes[i];
      if (route is GoRoute) {
        assert(route.parentNavigatorKey == null ||
            route.parentNavigatorKey == branches[i].navigatorKey);
      }
    }
  }

  /// Representations of the different stateful route branches that this
  /// shell route will manage.
  ///
  /// Each branch identifies the [Navigator] to be used (via the navigatorKey)
  /// and the route that will be used as the root of the route branch.
  final List<ShellRouteBranch> branches;

  /// Whether the route branches should be preloaded when navigating to this
  /// route for the first time.
  ///
  /// If this is true, all the [branches] will be preloaded by navigating to
  /// their default locations (see [ShellRouteBranch] for more information).
  final bool preloadBranches;

  @override
  GlobalKey<NavigatorState>? navigatorKeyForSubRoute(RouteBase subRoute) {
    final ShellRouteBranch? branch = branches
        .firstWhereOrNull((ShellRouteBranch e) => e.routes.contains(subRoute));
    return branch?.navigatorKey;
  }

  /// Gets the state for the nearest stateful shell route in the Widget tree.
  static StatefulShellRouteState of(BuildContext context) {
    final InheritedStatefulNavigationShell? inherited = context
        .dependOnInheritedWidgetOfExactType<InheritedStatefulNavigationShell>();
    assert(inherited != null,
        'No InheritedStatefulNavigationShell found in context');
    return inherited!.routeState;
  }

  static Set<GlobalKey<NavigatorState>> _debugUniqueNavigatorKeys(
          List<ShellRouteBranch> branches) =>
      Set<GlobalKey<NavigatorState>>.from(
          branches.map((ShellRouteBranch e) => e.navigatorKey));

  static List<RouteBase> _routes(List<ShellRouteBranch> branches) =>
      branches.expand((ShellRouteBranch e) => e.routes).toList();
}

/// Representation of a separate branch in a stateful navigation tree, used to
/// configure [StatefulShellRoute].
///
/// The only required argument when creating a ShellRouteBranch is the
/// sub-routes ([routes]), however in some cases you may also need to specify
/// the [defaultLocation], for instance of you're using another shell route as
/// direct sub-route. A [navigatorKey] can be useful to provide in case you need
/// to use the [Navigator] created for this branch elsewhere.
class ShellRouteBranch {
  /// Constructs a [ShellRouteBranch].
  ShellRouteBranch({
    required this.routes,
    GlobalKey<NavigatorState>? navigatorKey,
    this.defaultLocation,
    this.restorationScopeId,
  })  : navigatorKey = navigatorKey ?? GlobalKey<NavigatorState>(),
        assert(routes.isNotEmpty);

  /// The [GlobalKey] to be used by the [Navigator] built for this route branch.
  ///
  /// A separate Navigator will be built for each ShellRouteBranch in a
  /// [StatefulShellRoute] and this key will be used to identify the Navigator.
  /// The [routes] and all sub-routes will be placed o onto this Navigator
  /// instead of the root Navigator.
  final GlobalKey<NavigatorState> navigatorKey;

  /// The list of child routes associated with this route branch.
  final List<RouteBase> routes;

  /// The default location for this route branch.
  ///
  /// If none is specified, the first descendant [GoRoute] will be used (i.e.
  /// first element in [routes], or a descendant).
  final String? defaultLocation;

  /// Restoration ID to save and restore the state of the navigator, including
  /// its history.
  final String? restorationScopeId;
}
