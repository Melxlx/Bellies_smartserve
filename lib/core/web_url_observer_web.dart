// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

void updateBrowserUrl(String urlPath) {
  try {
    web.window.history.pushState(web.window.history.state, '', urlPath);
  } catch (e) {
    debugPrint("Error updating browser history: $e");
  }
}

class WebUrlNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _updateUrl(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _updateUrl(newRoute);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _updateUrl(previousRoute);
    }
  }

  void _updateUrl(Route<dynamic> route) {
    final name = route.settings.name;
    if (name != null && name.isNotEmpty && name != '/') {
      updateBrowserUrl(name);
    }
  }
}
