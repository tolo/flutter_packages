// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'configuration.dart';
import 'delegate.dart';
import 'information_provider.dart';
import 'logging.dart';
import 'match.dart';
import 'matching.dart';
import 'redirection.dart';

/// Converts between incoming URLs and a [RouteMatchList] using [RouteMatcher].
/// Also performs redirection using [RouteRedirector].
class GoRouteInformationParser extends RouteInformationParser<RouteMatchList> {
  /// Creates a [GoRouteInformationParser].
  GoRouteInformationParser({
    required this.configuration,
    this.debugRequireGoRouteInformationProvider = false,
  })  : matcher = RouteMatcher(configuration),
        redirector = redirect;

  /// The route configuration for the app.
  final RouteConfiguration configuration;

  /// The route matcher.
  final RouteMatcher matcher;

  /// The route redirector.
  final RouteRedirector redirector;

  /// A debug property to assert [GoRouteInformationProvider] is in use along
  /// with this parser.
  ///
  /// An assertion error will be thrown if this property set to true and the
  /// [GoRouteInformationProvider] is not in use.
  ///
  /// Defaults to false.
  final bool debugRequireGoRouteInformationProvider;

  /// The future of current route parsing.
  ///
  /// This is used for testing asynchronous redirection.
  @visibleForTesting
  Future<RouteMatchList>? debugParserFuture;

  /// Called by the [Router]. The
  @override
  Future<RouteMatchList> parseRouteInformationWithDependencies(
    RouteInformation routeInformation,
    BuildContext context,
  ) {
    late final RouteMatchList initialMatches;
    try {
      if (routeInformation is PreParsedRouteInformation) {
        initialMatches = routeInformation.matchlist;
      } else {
        initialMatches = matcher.findMatch(routeInformation.location!,
            extra: routeInformation.state);
      }
    } on MatcherError {
      log.info('No initial matches: ${routeInformation.location}');

      // If there is a matching error for the initial location, we should
      // still try to process the top-level redirects.
      initialMatches = RouteMatchList.empty;
    }
    Future<RouteMatchList> processRedirectorResult(RouteMatchList matches) {
      if (matches.isEmpty) {
        return SynchronousFuture<RouteMatchList>(errorScreen(
            Uri.parse(routeInformation.location!),
            MatcherError('no routes for location', routeInformation.location!)
                .toString()));
      }
      matches = _processShellNavigatorPreload(matches);
      return SynchronousFuture<RouteMatchList>(matches);
    }

    final FutureOr<RouteMatchList> redirectorResult = redirector(
      context,
      SynchronousFuture<RouteMatchList>(initialMatches),
      configuration,
      matcher,
      extra: routeInformation.state,
    );
    if (redirectorResult is RouteMatchList) {
      return processRedirectorResult(redirectorResult);
    }

    return debugParserFuture = redirectorResult.then(processRedirectorResult);
  }

  final Map<GlobalKey<NavigatorState>, RouteMatchList>
      _shellNavigatorPreloadMatchListCache =
      <GlobalKey<NavigatorState>, RouteMatchList>{};

  RouteMatchList? _parsePreloadMatchList(
      ShellNavigatorProperties shellNavigator, ShellRouteMatch match) {
    final String location =
        matcher.configuration.initialShellNavigationLocation(shellNavigator);
    RouteMatchList preloadMatches = matcher.findMatch(location);

    // Make sure the same shell route is present in the preloaded
    // match list
    final int parentShellRouteIndex = preloadMatches.matches
        .indexWhere((RouteMatch e) => e.route == match.route);
    if (parentShellRouteIndex >= 0 &&
        parentShellRouteIndex < (preloadMatches.matches.length - 1)) {
      // Process nested preload
      preloadMatches = _processShellNavigatorPreload(
          preloadMatches, parentShellRouteIndex + 1);
      _shellNavigatorPreloadMatchListCache[shellNavigator.navigatorKey] =
          preloadMatches;
      return preloadMatches;
    }
    return null;
  }

  RouteMatchList _processShellNavigatorPreload(RouteMatchList matchList,
      [int startIndex = 0]) {
    for (int i = startIndex; i < matchList.matches.length; i++) {
      final RouteMatch match = matchList.matches[i];
      if (match is! ShellRouteMatch) {
        continue;
      }
      final List<ShellNavigatorProperties> shellNavigators =
          match.route.statefulShellNavigatorProperties;
      final List<RouteMatchList> preloadMatchLists = <RouteMatchList>[];
      for (final ShellNavigatorProperties shellNavigator in shellNavigators) {
        // Preload shell navigator if preload is enabled (i.e. parse route match
        // list for nested navigators)
        if (shellNavigator.preload) {
          final RouteMatchList? preloadMatches =
              _shellNavigatorPreloadMatchListCache[
                      shellNavigator.navigatorKey] ??
                  _parsePreloadMatchList(shellNavigator, match);
          if (preloadMatches != null) {
            preloadMatchLists.add(preloadMatches);
          }
        }
      }
      match.preloadedNavigatorMatches.addAll(preloadMatchLists);
    }

    return matchList;
  }

  @override
  Future<RouteMatchList> parseRouteInformation(
      RouteInformation routeInformation) {
    throw UnimplementedError(
        'use parseRouteInformationWithDependencies instead');
  }

  /// for use by the Router architecture as part of the RouteInformationParser
  @override
  RouteInformation? restoreRouteInformation(RouteMatchList configuration) {
    if (configuration.isEmpty) {
      return null;
    }
    if (configuration.matches.last is ImperativeRouteMatch) {
      configuration =
          (configuration.matches.last as ImperativeRouteMatch).matches;
    }
    return RouteInformation(
      location: configuration.uri.toString(),
      state: configuration.extra,
    );
  }
}

/// Pre-parsed [RouteInformation] that contains a [RouteMatchList].
class PreParsedRouteInformation extends RouteInformation {
  /// Creates a [PreParsedRouteInformation].
  PreParsedRouteInformation(
      {super.location, super.state, required this.matchlist});

  /// The pre-parsed [RouteMatchList].
  final RouteMatchList matchlist;
}
