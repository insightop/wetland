// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:auto_route/auto_route.dart' as _i9;
import 'package:flutter/material.dart' as _i10;
import 'package:wetland_example/pages/contacts_page.dart' as _i1;
import 'package:wetland_example/pages/detail_page.dart' as _i2;
import 'package:wetland_example/pages/home_page.dart' as _i3;
import 'package:wetland_example/pages/list_page.dart' as _i4;
import 'package:wetland_example/pages/login_page.dart' as _i5;
import 'package:wetland_example/pages/messages_page.dart' as _i6;
import 'package:wetland_example/pages/mine_page.dart' as _i7;
import 'package:wetland_example/pages/placeholder_page.dart' as _i8;

/// generated route for
/// [_i1.ContactsPage]
class ContactsRoute extends _i9.PageRouteInfo<ContactsRouteArgs> {
  ContactsRoute({
    String title = 'Contacts',
    _i10.Key? key,
    List<_i9.PageRouteInfo>? children,
  }) : super(
         ContactsRoute.name,
         args: ContactsRouteArgs(title: title, key: key),
         rawPathParams: {'title': title},
         initialChildren: children,
       );

  static const String name = 'ContactsRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<ContactsRouteArgs>(
        orElse: () =>
            ContactsRouteArgs(title: pathParams.getString('title', 'Contacts')),
      );
      return _i1.ContactsPage(title: args.title, key: args.key);
    },
  );
}

class ContactsRouteArgs {
  const ContactsRouteArgs({this.title = 'Contacts', this.key});

  final String title;

  final _i10.Key? key;

  @override
  String toString() {
    return 'ContactsRouteArgs{title: $title, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ContactsRouteArgs) return false;
    return title == other.title && key == other.key;
  }

  @override
  int get hashCode => title.hashCode ^ key.hashCode;
}

/// generated route for
/// [_i2.DetailPage]
class DetailRoute extends _i9.PageRouteInfo<DetailRouteArgs> {
  DetailRoute({
    String title = 'Detail',
    _i10.Key? key,
    List<_i9.PageRouteInfo>? children,
  }) : super(
         DetailRoute.name,
         args: DetailRouteArgs(title: title, key: key),
         rawPathParams: {'title': title},
         initialChildren: children,
       );

  static const String name = 'DetailRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<DetailRouteArgs>(
        orElse: () =>
            DetailRouteArgs(title: pathParams.getString('title', 'Detail')),
      );
      return _i2.DetailPage(title: args.title, key: args.key);
    },
  );
}

class DetailRouteArgs {
  const DetailRouteArgs({this.title = 'Detail', this.key});

  final String title;

  final _i10.Key? key;

  @override
  String toString() {
    return 'DetailRouteArgs{title: $title, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DetailRouteArgs) return false;
    return title == other.title && key == other.key;
  }

  @override
  int get hashCode => title.hashCode ^ key.hashCode;
}

/// generated route for
/// [_i3.HomePage]
class HomeRoute extends _i9.PageRouteInfo<void> {
  const HomeRoute({List<_i9.PageRouteInfo>? children})
    : super(HomeRoute.name, initialChildren: children);

  static const String name = 'HomeRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      return const _i3.HomePage();
    },
  );
}

/// generated route for
/// [_i4.ListPage]
class ListRoute extends _i9.PageRouteInfo<ListRouteArgs> {
  ListRoute({
    String title = 'List',
    _i10.Key? key,
    List<_i9.PageRouteInfo>? children,
  }) : super(
         ListRoute.name,
         args: ListRouteArgs(title: title, key: key),
         rawPathParams: {'title': title},
         initialChildren: children,
       );

  static const String name = 'ListRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<ListRouteArgs>(
        orElse: () =>
            ListRouteArgs(title: pathParams.getString('title', 'List')),
      );
      return _i4.ListPage(title: args.title, key: args.key);
    },
  );
}

class ListRouteArgs {
  const ListRouteArgs({this.title = 'List', this.key});

  final String title;

  final _i10.Key? key;

  @override
  String toString() {
    return 'ListRouteArgs{title: $title, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ListRouteArgs) return false;
    return title == other.title && key == other.key;
  }

  @override
  int get hashCode => title.hashCode ^ key.hashCode;
}

/// generated route for
/// [_i5.LoginPage]
class LoginRoute extends _i9.PageRouteInfo<void> {
  const LoginRoute({List<_i9.PageRouteInfo>? children})
    : super(LoginRoute.name, initialChildren: children);

  static const String name = 'LoginRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      return const _i5.LoginPage();
    },
  );
}

/// generated route for
/// [_i6.MessagesPage]
class MessagesRoute extends _i9.PageRouteInfo<MessagesRouteArgs> {
  MessagesRoute({
    String title = 'Messages',
    _i10.Key? key,
    List<_i9.PageRouteInfo>? children,
  }) : super(
         MessagesRoute.name,
         args: MessagesRouteArgs(title: title, key: key),
         rawPathParams: {'title': title},
         initialChildren: children,
       );

  static const String name = 'MessagesRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<MessagesRouteArgs>(
        orElse: () =>
            MessagesRouteArgs(title: pathParams.getString('title', 'Messages')),
      );
      return _i6.MessagesPage(title: args.title, key: args.key);
    },
  );
}

class MessagesRouteArgs {
  const MessagesRouteArgs({this.title = 'Messages', this.key});

  final String title;

  final _i10.Key? key;

  @override
  String toString() {
    return 'MessagesRouteArgs{title: $title, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MessagesRouteArgs) return false;
    return title == other.title && key == other.key;
  }

  @override
  int get hashCode => title.hashCode ^ key.hashCode;
}

/// generated route for
/// [_i7.MinePage]
class MineRoute extends _i9.PageRouteInfo<void> {
  const MineRoute({List<_i9.PageRouteInfo>? children})
    : super(MineRoute.name, initialChildren: children);

  static const String name = 'MineRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      return const _i7.MinePage();
    },
  );
}

/// generated route for
/// [_i8.PlaceholderPage]
class PlaceholderRoute extends _i9.PageRouteInfo<void> {
  const PlaceholderRoute({List<_i9.PageRouteInfo>? children})
    : super(PlaceholderRoute.name, initialChildren: children);

  static const String name = 'PlaceholderRoute';

  static _i9.PageInfo page = _i9.PageInfo(
    name,
    builder: (data) {
      return const _i8.PlaceholderPage();
    },
  );
}
