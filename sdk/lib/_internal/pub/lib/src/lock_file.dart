// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library lock_file;

import 'dart:json' as json;
import 'dart:collection';

import 'package:yaml/yaml.dart';

import 'io.dart';
import 'package.dart';
import 'source_registry.dart';
import 'utils.dart';
import 'version.dart';

/// A parsed and validated `pubspec.lock` file.
class LockFile {
  /// The packages this lockfile pins.
  Map<String, PackageId> packages;

  LockFile._(this.packages);

  LockFile.empty()
    : packages = <String, PackageId>{};

  /// Loads a lockfile from [filePath].
  factory LockFile.load(String filePath, SourceRegistry sources) {
    return LockFile._parse(filePath, readTextFile(filePath), sources);
  }

  /// Parses a lockfile whose text is [contents].
  factory LockFile.parse(String contents, SourceRegistry sources) {
    return LockFile._parse(null, contents, sources);
  }

  /// Parses the lockfile whose text is [contents].
  static LockFile _parse(String filePath, String contents,
      SourceRegistry sources) {
    var packages = <String, PackageId>{};

    if (contents.trim() == '') return new LockFile.empty();
    var parsed = loadYaml(contents);

    if (parsed.containsKey('packages')) {
      var packageEntries = parsed['packages'];

      packageEntries.forEach((name, spec) {
        // Parse the version.
        if (!spec.containsKey('version')) {
          throw new FormatException('Package $name is missing a version.');
        }
        var version = new Version.parse(spec['version']);

        // Parse the source.
        if (!spec.containsKey('source')) {
          throw new FormatException('Package $name is missing a source.');
        }
        var sourceName = spec['source'];

        if (!spec.containsKey('description')) {
          throw new FormatException('Package $name is missing a description.');
        }
        var description = spec['description'];

        // Parse the description if we know the source.
        if (sources.contains(sourceName)) {
          var source = sources[sourceName];
          description = source.parseDescription(filePath, description,
              fromLockFile: true);
        }

        var id = new PackageId(name, sourceName, version, description);

        // Validate the name.
        if (name != id.name) {
          throw new FormatException(
            "Package name $name doesn't match ${id.name}.");
        }

        packages[name] = id;
      });
    }

    return new LockFile._(packages);
  }

  /// Returns the serialized YAML text of the lock file.
  String serialize() {
    var packagesObj = new LinkedHashMap<String, Map>();

    // Sort the packages by name.
    var sortedKeys = packages.keys.toList();
    sortedKeys.sort();
    sortedKeys.forEach((name) {
      packagesObj[name] = {
        'version': packages[name].version.toString(),
        'source': packages[name].source,
        'description': packages[name].description
      };
    });

    // TODO(nweiz): Serialize using the YAML library once it supports
    // serialization. For now, we use JSON, since it's a subset of YAML anyway.
    return
        '# Generated by pub\n'
        '# See http://pub.dartlang.org/doc/glossary.html#lockfile\n'
        '\n'
        '${json.stringify({'packages': packagesObj})}\n';
  }
}
